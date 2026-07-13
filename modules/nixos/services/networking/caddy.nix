{
  config,
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (builtins) length;
  inherit (lib) mkIf mkEnableOption mkOption types attrNames mapAttrs;

  cfg = config.sneeuwvlok.services.networking.caddy;
  hasHosts = (cfg.hosts |> attrNames |> length) > 0;
in {
  options.sneeuwvlok.services.networking.caddy = {
    enable = mkEnableOption "enable caddy" // {default = true;};

    hosts = mkOption {
      type = types.attrsOf types.str;
      default = {};
    };

    extraConfig = mkOption {
      type = types.str;
      default = "";
    };
  };

  config = mkIf hasHosts {
    networking.firewall.allowedTCPPorts = [80 443];

    services.caddy = {
      enable = cfg.enable;

      package = self.packages.${pkgs.stdenv.hostPlatform.system}.caddy;

      virtualHosts =
        cfg.hosts
        |> mapAttrs (host: extraConfig: {inherit extraConfig;});
    };
  };
}
