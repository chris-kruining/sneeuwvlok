{ config, options, lib, pkgs, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
in
{
  options.modules.desktop.editors.nvim = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "neo-vim (nixvim)"; };

  config = mkIf config.modules.desktop.editors.nvim.enable {
    programs.nixvim = {
      enable = true;

      options = {
        number = true;

        shiftwidth = 2;
      };

#       colorschemes.gruvbox.enable = true;

      plugins = {
        lualine.enable = true;
        lightline.enable = true;

        lsp = {
          enable = true;
          servers = {
            tsserver.enable = true;
            lua-ls.enable = true;
            rust-analyzer.enable = true;
          };
        };

        nvim-cmp = {
          enable = true;
          autoEnableSources = true;
          sources = [
            {name = "nvim_lsp";}
            {name = "path";}
            {name = "buffer";}
          ];
        };
      };
    };
  };
}
