{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types singleton genAttrs;

  cfg = config.${namespace}.services.development.llama-cpp;

  # One section per model, named after the model, which is also the name clients ask the router for.
  # llama.cpp downloads a model into its cache the first time it is asked for
  presets = pkgs.writeText "llama-cpp-models.ini" (lib.generators.toINIWithGlobalSection {} {
    globalSection.version = 1;
    sections =
      {
        "*" = {
          # The cpu's integrated gpu shows up as a second device, it would only slow the model down
          device = cfg.device;
          c = cfg.contextSize;
          # Leaves out the vision part, it costs vram and coding doesn't need it
          no-mmproj = true;
          # Gives the vram back, to games for example, while nothing asks for the model
          sleep-idle-seconds = cfg.idleSeconds;
        };
      }
      // genAttrs cfg.models (model: {hf-repo = model;});
  });
in {
  options.${namespace}.services.development.llama-cpp = {
    enable = mkEnableOption "a llama.cpp server for local models, with an OpenAI compatible api";

    models = mkOption {
      type = types.coercedTo types.str singleton (types.listOf types.str);
      default = [];
      example = ["unsloth/Qwen3.6-35B-A3B-GGUF:UD-IQ4_XS"];
      description = ''
        Models to serve, as Hugging Face `<repo>:<quantization>`. Each is downloaded the first time it is asked for
        and loaded on demand, one at a time. The first one is the default for clients
      '';
    };

    backend = mkOption {
      type = types.enum ["rocm" "vulkan"];
      default = "rocm";
      description = "How llama.cpp uses the (AMD) gpu";
    };

    device = mkOption {
      type = types.str;
      default =
        if cfg.backend == "rocm"
        then "ROCm0"
        else "Vulkan0";
      description = "The gpu to run on, `llama-server --list-devices` shows them";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "The port of the api";
    };

    contextSize = mkOption {
      type = types.ints.positive;
      default = 65536;
      description = "Tokens of context per model, coding agents want 64k or more";
    };

    idleSeconds = mkOption {
      type = types.ints.positive;
      default = 600;
      description = "Seconds without requests after which a model leaves the gpu";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Listen on the network instead of only on this machine, for the other machines at home and over the vpn";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.models != [];
        message = "${namespace}.services.development.llama-cpp.models needs at least one model";
      }
    ];

    services.llama-cpp = {
      enable = true;
      inherit (cfg) openFirewall;
      package =
        if cfg.backend == "rocm"
        then pkgs.llama-cpp-rocm
        else pkgs.llama-cpp-vulkan;

      settings = {
        host =
          if cfg.openFirewall
          then "0.0.0.0"
          else "127.0.0.1";
        inherit (cfg) port;
        models-preset = presets;
        # Two models don't fit in the vram together
        models-max = 1;
      };
    };

    systemd.services.llama-cpp.serviceConfig = {
      # For the gpu's render nodes, and for /proc/meminfo, which llama.cpp reads to fit a model in memory
      SupplementaryGroups = ["render"];
      ProcSubset = lib.mkForce "all";
    };
  };
}
