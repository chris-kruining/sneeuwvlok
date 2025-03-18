{ inputs, config, options, lib, pkgs, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;

  cfg = options.modules.desktop.editors.nvim;
in
{
  imports = [
    inputs.nvf.nixosModules.default
  ];

  options.modules.desktop.editors.nvim = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "neo-vim (nixvim)";
  };

  config = mkIf cfg.enable {

  };
}
