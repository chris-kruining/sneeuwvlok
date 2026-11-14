{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types;

  cfg = config.${namespace}.services.home-automation.whisper;
in {
  options.${namespace}.services.home-automation.whisper = {
    enable = mkEnableOption "faster-whisper, local speech to text over the wyoming protocol";

    model = mkOption {
      type = types.str;
      default = "base.en";
      description = ''
        The whisper model to transcribe with. Ulmo transcribes on its cpu, so larger models answer slower:
        `small.en` is more accurate, `tiny.en` faster. The list is in the nixpkgs faster-whisper module
      '';
    };

    language = mkOption {
      type = types.str;
      default = "en";
      description = "The language spoken to the assistant";
    };

    port = mkOption {
      type = types.port;
      default = 10300;
      description = ''
        The port whisper listens on, only on localhost since home assistant runs on the same machine
      '';
    };
  };

  config = mkIf cfg.enable {
    # The model is downloaded once on the first start, speech itself never leaves the machine
    services.wyoming.faster-whisper.servers.default = {
      enable = true;
      # `auto` picks sherpa for english, this keeps whisper
      sttLibrary = "faster-whisper";
      inherit (cfg) model language;
      uri = "tcp://127.0.0.1:${toString cfg.port}";
    };
  };
}
