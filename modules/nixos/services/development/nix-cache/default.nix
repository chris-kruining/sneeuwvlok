{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption mkForce types concatStringsSep optional;

  cfg = config.${namespace}.services.development.nix-cache;
  update = optional config.${namespace}.system.update.enable "nixos-upgrade.service";
  roots = "/var/lib/nix-cache/roots";

  build = pkgs.writeShellApplication {
    name = "nix-cache-build";
    runtimeInputs = [config.nix.package pkgs.git pkgs.jq pkgs.coreutils];
    text = ''
      # Pin the commit once, so a push halfway through the run cannot mix two revisions
      rev=$(nix flake metadata --refresh --json '${cfg.flake}' | jq -r .revision)
      flake='${cfg.flake}'"&rev=$rev"
      stamp=$(date +%Y%m%d%H%M%S)

      ${
        if cfg.hosts == null
        then ''read -ra hosts <<< "$(nix eval --raw "$flake#nixosConfigurations" --apply 'c: builtins.concatStringsSep " " (builtins.attrNames c)')"''
        else ''hosts=(${concatStringsSep " " cfg.hosts})''
      }

      echo "building ''${hosts[*]} at $rev"

      failed=0
      for host in "''${hosts[@]}"; do
        mkdir -p "${roots}/$host"

        # The out link is a gc root, which is what keeps the closure in the store and thus in the cache
        if ! nix build "$flake#nixosConfigurations.$host.config.system.build.toplevel" --out-link "${roots}/$host/$stamp"; then
          echo "failed to build $host"
          failed=1
        fi
      done

      exit $failed
    '';
  };

  prune = pkgs.writeShellApplication {
    name = "nix-cache-prune";
    runtimeInputs = [pkgs.coreutils pkgs.findutils];
    text = ''
      shopt -s nullglob

      # Per host, so a host that failed to build tonight keeps its last good closures
      for dir in ${roots}/*/; do
        find "$dir" -mindepth 1 -maxdepth 1 -type l | sort -r | tail -n +${toString (cfg.keep + 1)} | xargs -r rm -v
      done
    '';
  };
in {
  options.${namespace}.services.development.nix-cache = {
    enable = mkEnableOption "a nix binary cache, served by harmonia, that is filled by building every host every night";

    port = mkOption {
      type = types.port;
      default = 5000;
      description = ''
        The port harmonia serves the cache on
      '';
    };

    flake = mkOption {
      type = types.str;
      default = "git+https://git.amarth.cloud/chris/sneeuwvlok?ref=main";
      description = ''
        The flake whose hosts are built into the cache, has to be a url that a revision can be appended to with `&rev=`
      '';
    };

    hosts = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = null;
      example = ["manwe" "ulmo"];
      description = ''
        The hosts to build, null builds every nixosConfiguration in the flake
      '';
    };

    buildAt = mkOption {
      type = types.str;
      default = "*-*-* 03:00:00";
      description = ''
        When to build the hosts, in systemd calendar format, garbage collection follows as soon as the build is done
      '';
    };

    keep = mkOption {
      type = types.ints.positive;
      default = 3;
      description = ''
        How many builds of every host to keep in the cache, older ones are garbage collected
      '';
    };
  };

  config = mkIf cfg.enable {
    services.harmonia = {
      cache = {
        enable = true;
        signKeyPaths = [config.sops.secrets."nix_cache/signing_key".path];

        # Only ipv4, which is behind the router's nat, ipv6 would put the cache on the internet
        settings.bind = "0.0.0.0:${toString cfg.port}";

        # Lower than cache.nixos.org's 40, so paths both have come over the lan
        settings.priority = 30;
      };

      # Not on a timer, the nightly build starts it once it is done
      gc = {
        enable = true;
        deleteOlderThan = "45d";
      };
    };

    # harmonia-gc takes over from the regular collector
    nix.gc.automatic = mkForce false;

    # Keep the other services on this machine responsive while the hosts are building
    nix.daemonCPUSchedPolicy = "idle";
    nix.daemonIOSchedClass = "idle";

    networking.firewall.allowedTCPPorts = [cfg.port];

    systemd.services = {
      nix-cache-build = {
        description = "Build every host into the nix cache";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        startAt = cfg.buildAt;

        # Also after a failure, the prune keeps the last good builds of a host that failed.
        # A machine that updates itself does so straight after, a failure can be another host
        onSuccess = ["harmonia-gc.service"] ++ update;
        onFailure = ["harmonia-gc.service"] ++ update;

        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe build;
          StateDirectory = "nix-cache";
        };
      };

      harmonia-gc.serviceConfig.ExecStartPre = lib.getExe prune;
    };

    systemd.timers.nix-cache-build.timerConfig.Persistent = true;

    sops.secrets."nix_cache/signing_key" = {};
  };
}
