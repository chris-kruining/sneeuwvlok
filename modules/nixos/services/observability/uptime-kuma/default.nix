{ pkgs, config, lib, namespace, ... }:
let
  inherit (builtins) toString;
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.observability.uptime-kuma;
in
{
  options.${namespace}.services.observability.uptime-kuma = {
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
    
    networking.firewall.allowedTCPPorts = [ 9006 ];
  };
}
