{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.editor.nvim;
in
{
  options.${namespace}.editor.nvim = {
    enable = mkEnableOption "enable nvim via nvf on user level";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ 
      imagemagick
      editorconfig-core-c
      sqlite
      deno
      pandoc
      nuspell
      hunspellDicts.nl_NL
      hunspellDicts.en_GB-ise
    ];

    programs.nvf = {
      enable = true;
      settings.vim = {
        statusline.lualine.enable = true;
        telescope.enable = true;
        autocomplete.nvim-cmp.enable = true;

        lsp.enable = true;

        languages = {
          enableTreesitter = true;

          nix.enable = true;
          ts.enable = true;
          rust.enable = true;
        };
      };
    };
  };
}
