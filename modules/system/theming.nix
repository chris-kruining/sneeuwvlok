{ inputs, config, options, lib, pkgs, ... }:
let
  inherit (lib) mkIf;

  cfg = config.modules.theming;
in
{
  imports = [
      inputs.stylix.nixosModules.stylix
    ];

  options.modules.theming = let
    inherit (lib.options) mkEnableOption;
  in
  {
    enable = mkEnableOption "enable theming";
  };

  config = mkIf cfg.enable {

  };
}
