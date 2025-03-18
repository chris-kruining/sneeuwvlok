{ lib, user, config, ... }:
{
  options = let
    inherit (lib) mkOption;
  in
  {
    kaas = mkOption {
      type = lib.types.bool;
      default = true;
      example = true;
      description = "";
    };
  };

  config = {
    modules.${user}.themes.enable = config.kaas;
  };
}
