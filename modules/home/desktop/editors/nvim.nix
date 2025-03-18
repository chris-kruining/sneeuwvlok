{ inputs, config, options, lib, pkgs, user, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;

  cfg = options.modules.${user}.desktop.editors.nvim;
in
{
  imports = [
    inputs.nvf.nixosModules.default
  ];

  options.modules.${user}.desktop.editors.nvim = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "neo-vim (nixvim)"; };

  config = mkIf cfg.enable {
    home-manager.users.${user}.programs.nvf = {
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
