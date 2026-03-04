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

      package = pkgs.caddy.withPlugins {
        plugins = ["https://github.com/corazawaf/coraza-caddy@2.1.0"];
        hash = lib.fakeHash;
      };

      virtualHosts =
        cfg.hosts
        |> mapAttrs (host: extraConfig: {inherit extraConfig;});
    };
  };
}
