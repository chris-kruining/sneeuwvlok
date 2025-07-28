{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkOption;
  inherit (lib.types) subModule;

  cfg = config.${namespace}.application;
in
{
  options.${namespace}.application = {
    defaults = mkOption {
      type = subModule {
        browser = mkOption {
          type = enum [ "ladybird" "zen" ];
          default = "zen";
          example = "ladybird";
        };
      };
    };
  };

  config = {
    home.sessionVariables = {
      BROWSER = cfg.defaults.browser;
    };
  };
}
