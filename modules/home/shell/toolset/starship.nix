{ config, lib, user, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
in
{
  options.modules.${user}.shell.toolset.starship = {
    enable = mkEnableOption "fancy pansy shell prompt";
  };

  config = mkIf config.modules.${user}.shell.toolset.starship.enable {
    home-manager.users.${user}.programs.starship = {
      enable = true;
      settings = {
        scan_timeout = 10;

        # Inserts a blank line between shell prompts
        add_newline = true;

        line_break.disabled = true;

        format = "[┌ ](bold green)$os$username$hostname$nix_shell$git_branch$git_commit$git_state$git_status$directory$jobs$cmd_duration\n$character";

        username = {
          style_user = "cyan bold";
          style_root = "red bold";
          format = "[$user]($style) ";
          disabled = false;
          show_always = true;
        };

        hostname = {
          ssh_only = false;
          ssh_symbol = "🌐 ";
          format = "on [$hostname](bold red) ";
          trim_at = ".local";
          disabled = false;
        };

        nix_shell = {
          symbol = " ";
          format = "[$symbol$name]($style) ";
          style = "magenta bold";
        };

        git_branch = {
          only_attached = true;
          format = "[$symbol$branch]($style) ";
          symbol = " ";
          style = "yellow bold";
        };

        git_commit = {
          only_detached = true;
          format = "[ﰖ$hash]($style) ";
          style = "yellow bold";
        };

        git_state = {
          style = "magenta bold";
        };

        git_status = {
          style = "green bold";
        };

        directory = {
          read_only = " 󰌾";
          truncation_length = 0;
        };

        cmd_duration = {
          format = "[$duration]($style) ";
          style = "blue";
        };

        jobs = {
          style = "green bold";
        };

        os = {
          format = "[$symbol](bold white) ";
          disabled = false;

          symbols = {
            Windows = " ";
            Arch = "󰣇";
            Ubuntu = "";
            Macos = "󰀵";
            Manjaro = " ";
            Nobara = " ";
            Unknown = "󰠥";
          };
        };

        character = {
          success_symbol = "[└>](green bold)";
          error_symbol = "[└x](red bold)";
        };
      };
    };
  };
}
