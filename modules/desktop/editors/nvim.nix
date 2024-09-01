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

      opts = {
        number = true;

        shiftwidth = 2;
      };

#       colorschemes.base16 = "${pkgs.base16-schemes}/share/themes/everforest.yaml";
      colorschemes.everforest.enable = true;

      plugins = {
        lualine.enable = true;
        lightline.enable = true;

        lsp = {
          enable = true;
          servers = {
            tsserver.enable = true;
            lua-ls.enable = true;
            rust-analyzer = {
              enable = true;
              installRustc = true;
              installCargo = true;
            };
          };
        };

        cmp = {
          enable = true;
          autoEnableSources = true;
        };
      };
    };
  };
}
