{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.sneeuwvlok.shell.toolset.git;
in {
  options.sneeuwvlok.shell.toolset.git = {
    enable = mkEnableOption "version-control system";
  };

  config = mkIf cfg.enable {
    home.sessionVariables.GITHUB_TOKEN = "$(cat /run/agenix/tokenGH)";

    home.packages = with pkgs; [lazygit lazyjj jujutsu];

    programs = {
      zsh.initContent = ''
        # -------===[ Helpful Git Fn's ]===------- #
        gitignore() {
          curl -s -o .gitignore https://gitignore.io/api/$1
        }
      '';

      fish.functions = {
        gitignore = "curl -sL https://www.gitignore.io/api/$argv";
      };

      git = {
        enable = true;
        package = pkgs.gitFull;

        ignores = [
          # General:
          "*.bloop"
          "*.bsp"
          "*.metals"
          "*.metals.sbt"
          "*metals.sbt"
          "*.direnv"
          "*.envrc"
          "*hie.yaml"
          "*.mill-version"
          "*.jvmopts"

          # OS-related:
          ".DS_Store?"
          ".DS_Store"
          ".CFUserTextEncoding"
          ".Trash"
          ".Xauthority"
          "thumbs.db"
          "Thumbs.db"
          "Icon?"

          # Compiled residues:
          "*.class"
          "*.exe"
          "*.o"
          "*.pyc"
          "*.elc"
        ];

        settings = {
          init.defaultBranch = "main";
          core = {
            editor = "nvim";
            whitespace = "trailing-space,space-before-tab";
          };
          credential.helper = "${pkgs.gitFull}/bin/git-credential-libsecret";

          user = {
            signingKey = "~/.ssh/id_rsa.pub";
          };

          gpg.format = "ssh";
          commit.gpgSign = true;
          tag.gpgSign = true;

          push = {
            autoSetupRemote = true;
            default = "current";
            gpgSign = "if-asked";
            autoSquash = true;
          };
          pull.rebase = true;

          filter = {
            required = true;
            smudge = "git-lfs smudge -- %f";
            process = "git-lfs filter-process";
            clean = "git-lfs clean -- %f";
          };

          url = {
            "https://github.com/".insteadOf = "gh:";
            "git@github.com:".insteadOf = "ssh+gh:";
          };
        };
      };

      difftastic = {
        enable = true;
        git.enable = true;
        options = {
          background = "dark";
          color = "always";
          display = "inline";
        };
      };
    };
  };
}
