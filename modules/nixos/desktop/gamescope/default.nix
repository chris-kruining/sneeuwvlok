{ lib, config, namespace, inputs, ... }:
let
  inherit (lib) mkIf mkEnableOption mkForce mkAfter mkDefault elem;

  cfg = config.${namespace}.desktop.gamescope;

  # A Steam Deck reports itself in its nixos-facter report as Valve's Jupiter (LCD) or Galileo (OLED)
  system = config.hardware.facter.report.smbios.system or {};
  steamdeck = system.manufacturer or null == "Valve" && elem (system.product or null) ["Jupiter" "Galileo"];
in
{
  imports = [ inputs.jovian.nixosModules.default ];

  options.${namespace}.desktop.gamescope = {
    enable = mkEnableOption "Enable Steamdeck ui" // {
      default = (config.${namespace}.desktop.use == "gamescope");
    };
  };

  config = mkIf cfg.enable {
    ${namespace}.desktop.plasma.enable = true;

    services.displayManager.sddm.enable = mkForce false;
    services.displayManager.gdm.enable = mkForce false;

    jovian = {
      steam = {
        enable = true;
        autoStart = true;
        user = "chris";
        updater.splash = "steamos";
        desktopSession = "plasma";
      };
      steamos.useSteamOSConfig = true;

      # Its kernel, firmware, fan control and the udev rules that let Steam set the brightness
      devices.steamdeck.enable = mkDefault steamdeck;
    };

    # Steam asks `steamos-update check` whether an update waits for a reboot, and then shows it under Settings → Software Updates.
    # Jovian's stub only says so for a new kernel, this also says so for a new generation that becomes active on the next boot
    nixpkgs.overlays = mkAfter [
      (final: prev: {
        jovian-stubs = prev.jovian-stubs.overrideAttrs (old: let
          update = final.writeShellScript "holo-update" ''
            >&2 echo "[sneeuwvlok] $0: called with: $*"
            # Exit codes according to vendor: 0 update success, 1 update error, 7 no update available, 8 need reboot

            [ "$(readlink -f /run/current-system)" != "$(readlink -f /nix/var/nix/profiles/system)" ] && exit 8
            [ "$(readlink /run/booted-system/kernel)" != "$(readlink /run/current-system/kernel)" ] && exit 8

            exit 7
          '';
        in {
          buildCommand = old.buildCommand + ''
            install -m 755 ${update} $out/bin/holo-update
            install -m 755 ${update} $out/bin/steamos-polkit-helpers/steamos-update
          '';
        });
      })
    ];
  };
}
