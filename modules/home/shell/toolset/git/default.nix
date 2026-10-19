{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.${namespace}.shell.toolset.git;
in {
  options.${namespace}.shell.toolset.git = {
    enable = mkEnableOption "version-control system";

    signingKey = mkOption {
      type = types.str;
      default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICE+TFkjJ8p8fMOddvg/waKAjKJ6DRvvouj1MdXc1Taj chris";
      description = ''
        Public ssh key commits and tags are signed with, the private key comes from the ssh agent (bitwarden).
      '';
    };
  };

  config = mkIf cfg.enable {
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
        lfs.enable = true;

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

          # The key itself instead of a file, ssh-keygen then asks the agent for the private key
          user.signingKey = "key::${cfg.signingKey}";

          gpg.format = "ssh";
          gpg.ssh.allowedSignersFile = toString (pkgs.writeText "allowed-signers" ''
            chris@kruining.eu,c.kruining@4dotnet.nl namespaces="git" ${cfg.signingKey}
          '');
          commit.gpgSign = true;
          tag.gpgSign = true;
          signing.format = "ssh";

          push = {
            autoSetupRemote = true;
            default = "current";
            gpgSign = "if-asked";
            autoSquash = true;
          };
          pull.rebase = true;

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
