{
  config,
  pkgs,
  lib,
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

      package = pkgs.caddy.withPlugins {
        plugins = ["github.com/corazawaf/coraza-caddy/v2@v2.1.0"];
        hash = "sha256-R8x1gYjQh8vwZXV1HEMJWm9hHZknGk7STwWgEpXNO0Q=";
      };

      virtualHosts =
        cfg.hosts
        |> mapAttrs (host: extraConfig: {inherit extraConfig;});
    };
  };
}
