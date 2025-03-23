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
        format = "[╭](bold green) $username@$hostname$nix_shell: $directory$cmd_duration$git_branch$git_commit$git_state$git_status$line_break[╰](green bold)$character";

        username = {
          format = "[$user]($style)";
          show_always = true;
        };

        hostname = {
          ssh_only = false;
          ssh_symbol = "🌐 ";
          format = "[$hostname](bold red)";
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
          tag_disabled = false;
        };

        git_state = {
          style = "magenta bold";
        };

        git_status = {
          format = "[$all_status $ahead_behind]($style) ";
          style = "bold green";
          conflicted = "🏳";
          up_to_date = "";
          untracked = " ";
          ahead = "⇡\${count}";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
          behind = "⇣\${count}";
          stashed = " ";
          modified = " ";
          staged = "[++\($count\)](green)";
          renamed = "襁 ";
          deleted = " ";
        };

        directory = {
          read_only = " 󰌾";
        };

        cmd_duration = {
          format = "[$duration]($style) ";
          style = "blue";
        };

        os = {
          format = "[$symbol](bold white)";
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

        fill = {
          symbol = " ";
        };
      };
    };
  };
}
