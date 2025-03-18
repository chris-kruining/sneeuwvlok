{ inputs, config, options, lib, pkgs, user, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;

  cfg = config.modules.${user}.desktop.editors.nvim;
in
{
  options.modules.${user}.desktop.editors.nvim = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "neo-vim (nixvim)";
  };

  config = mkIf cfg.enable {
    modules.desktop.editors.nvim.enable = true;

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
