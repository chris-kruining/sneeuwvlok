{ inputs, config, options, lib, pkgs, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
in
{
  imports = [
    inputs.nvf.nixosModules.default
  ];

  options.modules.desktop.editors.nvim = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "neo-vim (nixvim)"; };

  config = mkIf config.modules.desktop.editors.nvim.enable {
    programs.nvf = {
      enable = true;
      settings = {
        vim = {
          statusline.lualine.enable = true;
          telescope.enable = true;
          autocomplete.nvim-cmp.enable = true;

          languages = {
            enableLSP = true;
            enableTreesitter = true;

            nix.enable = true;
            ts.enable = true;
            rust.enable = true;
          };
        };
      };
    };
  };
}
