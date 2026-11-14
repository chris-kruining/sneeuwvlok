{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types singleton genAttrs escapeShellArg;

  cfg = config.${namespace}.services.development.llama-swap;
  upstream = "http://${cfg.host}:${toString cfg.upstreamPort}";

  wake = pkgs.writeShellApplication {
    name = "llama-swap-wake";
    runtimeInputs = with pkgs; [curl wakeonlan coreutils];
    text = ''
      if ! curl --noproxy '*' --fail --silent --show-error --max-time 2 \
        --output /dev/null ${escapeShellArg "${upstream}/health"}; then
        echo ${escapeShellArg "Waking ${cfg.host} for inference"} >&2
        wakeonlan -i ${escapeShellArg cfg.broadcastAddress} ${escapeShellArg cfg.macAddress}
      fi

      # llama-swap owns this local process, not the remote llama-server.
      exec sleep infinity
    '';
  };
in {
  options.${namespace}.services.development.llama-swap = {
    enable = mkEnableOption "an OpenAI compatible endpoint that wakes a remote llama.cpp server on demand";

    host = mkOption {
      type = types.str;
      description = "The machine running llama.cpp, reachable from this machine";
    };

    upstreamPort = mkOption {
      type = types.port;
      default = 8080;
      description = "The port of the remote llama.cpp model router";
    };

    macAddress = mkOption {
      type = types.strMatching "([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}";
      description = "The wired network adapter to wake with a magic packet";
    };

    broadcastAddress = mkOption {
      type = types.str;
      default = "255.255.255.255";
      description = "The IPv4 broadcast address used for Wake on LAN; the remote machine must be on the same broadcast domain";
    };

    models = mkOption {
      type = types.coercedTo types.str singleton (types.listOf types.str);
      default = [];
      description = "Model IDs advertised to clients, matching the presets on the remote llama.cpp router";
    };

    port = mkOption {
      type = types.port;
      default = 5010;
      description = "The port of the client-facing api";
    };

    wakeTimeout = mkOption {
      type = types.ints.between 15 3600;
      default = 180;
      description = "Seconds to wait for the remote server's health endpoint after waking it";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Listen on the network instead of only on this machine, for clients at home and over the vpn";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.models != [];
        message = "${namespace}.services.development.llama-swap.models needs at least one model";
      }
    ];

    services.llama-swap = {
      enable = true;
      inherit (cfg) port openFirewall;
      listenAddress =
        if cfg.openFirewall
        then "0.0.0.0"
        else "127.0.0.1";

      settings = {
        healthCheckTimeout = cfg.wakeTimeout;
        models = genAttrs cfg.models (model: {
          cmd = lib.getExe wake;
          proxy = upstream;
          checkEndpoint = "/health";
          useModelName = model;
          # Re-arm the wake check between bursts. This only stops the local sleep process;
          # model loading and VRAM idle unloading remain with the remote llama.cpp router.
          ttl = 1;
        });
      };
    };
  };
}
