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
  caddyBase = pkgs.callPackage "${pkgs.path}/pkgs/by-name/ca/caddy/package.nix" {
    buildGo125Module = pkgs.buildGo126Module;
    caddy = caddyBase;
  };
  caddyPackage =
    caddyBase.withPlugins {
      plugins = ["github.com/corazawaf/coraza-caddy/v2@v2.1.0"];
      hash = "sha256-pSXjLaZoRtKV3eFl2ySRSjl3yxi514G1Cb7pfrpxxtE=";
    };
in {
  options.${namespace}.services.networking.caddy = {
    enable = mkEnableOption "enable caddy" // {default = true;};

    hosts = mkOption {
      type = types.attrsOf types.str;
    };

    extraConfig = mkOption {
      type = types.str;
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
