{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.editor.nvim;
in
{
  imports = [
    inputs.nvf.nixosModules.default
  ];

  options.${namespace}.editor.nvim = {
    enable = mkEnableOption "enable nvim via nvf on system level";
  };

  config = mkIf cfg.enable {
  };
}
