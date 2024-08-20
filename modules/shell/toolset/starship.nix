{ config, options, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.shell.toolset.starship = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "minimal shell ricing"; };

  config = mkIf config.modules.shell.toolset.starship.enable {
    hm.programs.starship = {
      enable = true;
      settings = {
        scan_timeout = 10;
        add_newline = true;
        line_break.disabled = true;

        format = "$username$hostname$nix_shell$git_branch$git_commit$git_state$git_status$directory$jobs$cmd_duration$character";
        username = {
          style_user = "blue bold";
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
          symbol = "שׂ";
          style = "brightYellow bold";
        };

        git_commit = {
          only_detached = true;
          format = "[ﰖ$hash]($style) ";
          style = "brightYellow bold";
        };

        git_state = {
          style = "brightMagenta bold";
        };

        git_status = {
          style = "brightGreen bold";
        };

        directory = {
          read_only = " ";
          truncation_length = 0;
        };

        cmd_duration = {
          format = "[$duration]($style) ";
          style = "brightBlue";
        };

        jobs = {
          style = "brightGreen bold";
        };

        character = {
          success_symbol = "[\\$](brightGreen} bold)";
          error_symbol = "[\\$](brightRed bold)";
        };
      };
    };
  };
}
