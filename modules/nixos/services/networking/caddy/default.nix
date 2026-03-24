{
  config,
  pkgs,
  lib,
  namespace,
  ...
}: let
  inherit (builtins) length;
  inherit (lib) mkIf mkEnableOption mkOption types attrNames mapAttrs;

  cfg = config.${namespace}.services.networking.caddy;
  hasHosts = (cfg.hosts |> attrNames |> length) > 0;
  caddyPackage = pkgs.caddy.withPlugins {
    plugins = ["github.com/corazawaf/coraza-caddy/v2@v2.1.0"];
    hash = "sha256-rsDnTunR8C7hVOX5aKcba+iFYHbpWek65DZgbMxOdTs=";
  };
in {
  options.${namespace}.services.networking.caddy = {
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
    services.caddy = {
      enable = cfg.enable;

      package = caddyPackage;

      virtualHosts =
        cfg.hosts
        |> mapAttrs (host: extraConfig: {inherit extraConfig;});
    };
  };
}
