{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.services.observability.uptime-kuma;
in {
  options.sneeuwvlok.services.observability.uptime-kuma = {
    enable = mkEnableOption "enable uptime kuma";
  };

  config = mkIf cfg.enable {
    services.uptime-kuma = {
      enable = true;

      settings = {
        PORT = toString 9006;
        HOST = "0.0.0.0";
      };
    };

    networking.firewall.allowedTCPPorts = [9006];
  };
}
