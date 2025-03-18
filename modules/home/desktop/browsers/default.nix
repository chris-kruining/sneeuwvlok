{
  options,
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  inherit (lib.modules) mkIf;
  cfg = config.modules.${user}.desktop.browsers;
in {
  options.modules.${user}.desktop.browsers = let
    inherit (lib.options) mkOption;
    inherit (lib.types) nullOr str;
  in {
    default = mkOption {
      type = nullOr str;
      default = null;
      description = "Default system browser";
      example = "firefox";
    };
  };

  config = mkIf (cfg.default != null) {
    home-manager.users.${user}.home.sessionVariables.BROWSER = cfg.default;
  };
}
