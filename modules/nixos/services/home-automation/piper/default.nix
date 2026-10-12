{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types;

  cfg = config.${namespace}.services.home-automation.piper;
in {
  options.${namespace}.services.home-automation.piper = {
    enable = mkEnableOption "Piper, local text to speech over the wyoming protocol";

    voice = mkOption {
      type = types.str;
      default = "nl_NL-mls-medium";
      description = ''
        The piper voice to speak with, samples of every voice are at https://rhasspy.github.io/piper-samples
      '';
    };

    port = mkOption {
      type = types.port;
      default = 10200;
      description = ''
        The port piper listens on, only on localhost since home assistant runs on the same machine
      '';
    };
  };

  config = mkIf cfg.enable {
    # The voice model is downloaded once on the first start, speech itself never leaves the machine
    services.wyoming.piper.servers.default = {
      enable = true;
      inherit (cfg) voice;
      uri = "tcp://127.0.0.1:${toString cfg.port}";
    };
  };
}
