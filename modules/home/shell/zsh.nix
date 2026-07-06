{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.shell.zsh;
in {
  options.sneeuwvlok.shell.zsh = {
    enable = mkEnableOption "enable ZSH";
  };

  config = mkIf cfg.enable {
    # sneeuwvlok.shell = {
    #   zsh.enable = true;
    # };

    programs = {
      starship.enableZshIntegration = true;
      yazi.enableZshIntegration = true;
      zellij.enableZshIntegration = true;

      zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;

        history = {
          size = 10000;
          path = "$XDG_CONFIG_HOME/zsh/history";
        };

        oh-my-zsh = {
          enable = true;
          plugins = ["git" "docker-compose" "zoxide"];
        };

        plugins = let
          mkZshPlugin = {
            pkg,
            file ? "${pkg.pname}.plugin.zsh",
          }: {
            name = pkg.pname;
            src = pkg.src;
            inherit file;
          };
        in
          with pkgs; [
            (mkZshPlugin {pkg = zsh-abbr;})
            (mkZshPlugin {pkg = zsh-autopair;})
            (mkZshPlugin {pkg = zsh-you-should-use;})
            (mkZshPlugin {
              pkg = zsh-nix-shell;
              file = "nix-shell.plugin.zsh";
            })

            {
              name = "zsh-autosuggestion";
              src = pkgs.fetchFromGitHub {
                owner = "zsh-users";
                repo = "zsh-autosuggestions";
                rev = "v0.7.0";
                sha256 = "1g3pij5qn2j7v7jjac2a63lxd97mcsgw6xq6k5p7835q9fjiid98";
              };
            }
            {
              name = "zsh-completions";
              src = pkgs.fetchFromGitHub {
                owner = "zsh-users";
                repo = "zsh-completions";
                rev = "0.34.0";
                sha256 = "0jjgvzj3v31yibjmq50s80s3sqi4d91yin45pvn3fpnihcrinam9";
              };
            }
            {
              name = "zsh-syntax-highlighting";
              src = pkgs.fetchFromGitHub {
                owner = "zsh-users";
                repo = "zsh-syntax-highlighting";
                rev = "0.7.0";
                sha256 = "0s1z3whzwli5452h2yzjzzj27pf1hd45g223yv0v6hgrip9f853r";
              };
            }
          ];
      };
    };
  };
}
