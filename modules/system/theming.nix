{ inputs, config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.modules.theming;
in
{
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  options.modules.theming = {
    enable = mkEnableOption "enable theming";
  };

  config = mkIf cfg.enable {

  };
}
