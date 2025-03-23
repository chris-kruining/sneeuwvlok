{ config, options, lib, pkgs, user, ... }: let
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.${user}.desktop.editors.zed;
in {
  options.modules.${user}.desktop.editors.zed = let
    inherit (lib.options) mkEnableOption;
  in {enable = mkEnableOption "zed";};

  config = mkIf cfg.enable {
    home-manager.users.${user} = {
      home.packages = with pkgs; [
        zed-editor nixd nil alejandra
      ];

      programs.zed-editor = {
        enable = true;

        extensions = ["nix" "toml" "html"];

        userSettings = {
          assistant.enabled = false;

          vim_mode = false;
          load_direnv = "shell_hook";
          base_keymap = "JetBrains";

          tabs = {
            file_icons = true;
            git_status = true;
          };
          project_panel.auto_reveal_entries = false;

          hour_format = "hour24";
          auto_update = false;

          lsp = {
            nixd = {};
            nil = {
              initialization_options = {
                autoArchive = true;
                formatting = {
                  command = ["alejandra" "--quiet" "--"];
                };
              };
              binary = {
                path_lookup = true;
              };
            };
          };

          languages = {
            "Nix" = {
              language_servers = ["nixd" "nil"];
              format_on_save = "on";
            };
          };
        };
      };
    };
  };
}
