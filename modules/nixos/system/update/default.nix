{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types optionalString;

  cfg = config.${namespace}.system.update;
  state = "/run/nixos-upgrade";
  # ulmo's, the nix module puts it before cache.nixos.org
  cache = builtins.head config.nix.settings.substituters;

  notify = pkgs.writeShellScript "nixos-upgrade-notify" ''
    # Every user with a session bus gets the notification on their desktop
    for bus in /run/user/*/bus; do
      [ -S "$bus" ] || continue
      user=$(${pkgs.coreutils}/bin/stat -c %U "$bus")
      ${pkgs.util-linux}/bin/runuser -u "$user" -- \
        ${pkgs.coreutils}/bin/env DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
        ${pkgs.libnotify}/bin/notify-send --app-name=NixOS --icon=system-software-update "$1" "$2" || true
    done
  '';

  # A deploy from a working tree with changes, or of commits that aren't on main yet, would be reverted by main's build.
  # Until main has the running revision the update is skipped, the security module's UpdateHeld alert looks for the line
  # it logs
  held = pkgs.writeShellScript "nixos-upgrade-held" ''
    hold() {
      echo "holding the update: $1, push it to main and deploy again"
      ${optionalString cfg.notify ''${notify} "Update held" "$1, push it to main and deploy again."''}
      exit 1
    }

    rev=$(/run/current-system/sw/bin/nixos-version --configuration-revision 2>/dev/null) \
      || hold "the running configuration was deployed with uncommitted changes"

    # Only a revision that isn't on main stops the update, anything else (no network yet) is for the update to retry
    if ! out=$(${config.nix.package}/bin/nix --extra-experimental-features 'nix-command flakes' \
        flake metadata --refresh --json '${flake}&rev='"$rev" 2>&1 >/dev/null); then
      case "$out" in
        *"Cannot find Git revision"*) hold "the running configuration (''${rev:0:7}) isn't on main" ;;
      esac
    fi
    exit 0
  '';

  flake = config.${namespace}.services.development.nix-cache.flake;
in {
  options.${namespace}.system.update = {
    enable = mkEnableOption "daily updates from the nightly builds in ulmo's cache";

    operation = mkOption {
      type = types.enum ["switch" "boot"];
      default = "boot";
      description = ''
        `boot` activates the update on the next reboot, so nothing restarts while the machine is in use.
        `switch` activates it right away.
      '';
    };

    at = mkOption {
      type = types.str;
      default = "*-*-* 05:00:00";
      description = ''
        When to update, in systemd calendar format. After ulmo's nightly build, a machine that was off then updates as soon as it is on (not with `wake`).
      '';
    };

    notify = mkEnableOption "a desktop notification when there was an update";

    wake = mkEnableOption ''
      waking from suspend to update, and suspending again afterwards when it was this timer that woke the machine
    '';
  };

  config = mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      inherit flake;
      inherit (cfg) operation;
      dates = cfg.at;
      # No catching up when woken by hand, the five minute check would take that for this timer and suspend right away
      persistent = !cfg.wake;
      # For channels, which this repo turned off, the flake ref with `--refresh` already gets the latest main
      upgrade = false;

      # Never build anything here: what isn't in ulmo's cache (yet) means there is no update today
      flags = ["--max-jobs" "0" "-L"];
    };

    systemd.timers.nixos-upgrade.timerConfig.WakeSystem = cfg.wake;

    systemd.services.nixos-upgrade = {
      # Without a network yet, or before ulmo finished building, try again a little later
      serviceConfig = {
        Restart = mkIf (!cfg.wake) "on-failure";
        RestartSec = "30min";

        ExecStopPost = mkIf cfg.wake (toString (pkgs.writeShellScript "nixos-upgrade-sleep" ''
          if [ -e ${state}/woke ]; then
            rm ${state}/woke
            # Only when nothing holds it awake, like a video playing after it was woken by hand just before
            systemctl suspend --check-inhibitors=yes
          fi
        ''));
      };

      unitConfig = mkIf (!cfg.wake) {
        StartLimitIntervalSec = "12h";
        StartLimitBurst = 4;
      };

      preStart = ''
        mkdir -p ${state}
        readlink /nix/var/nix/profiles/system > ${state}/system
        ${optionalString cfg.wake ''
          # The timer fires the moment the machine resumes, before sleep.target is stopped and its timestamp is the new resume
          for _ in $(seq 30); do
            systemctl -q is-active sleep.target || break
            sleep 1
          done

          # This timer woke the machine when it resumed less than five minutes ago
          resumed=$(systemctl show sleep.target -P InactiveEnterTimestamp --timestamp=unix | tr -d @)
          if [ -n "$resumed" ] && [ $(($(date +%s) - resumed)) -lt 300 ]; then
            touch ${state}/woke

            # The network takes a moment after a resume, and there is no retry before it suspends again
            for _ in $(seq 24); do
              ${pkgs.curl}/bin/curl -sf -m 5 -o /dev/null ${cache}/nix-cache-info && break
              sleep 5
            done
          fi
        ''}
      '';

      # After preStart, which waits for the network when woken. Holding is a success, nothing to retry until a deploy
      script = lib.mkBefore ''
        ${held} || exit 0
      '';

      postStart = optionalString cfg.notify ''
        if [ "$(readlink /nix/var/nix/profiles/system)" != "$(cat ${state}/system)" ]; then
          ${
          if cfg.operation == "boot"
          then ''${notify} "Update ready" "Installed, it becomes active with the next reboot."''
          else ''${notify} "Updated" "The new configuration is active."''
        }
        fi
      '';
    };
  };
}
