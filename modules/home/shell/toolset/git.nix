{ config, lib, pkgs, user, ... }:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf;
in
{
  options.modules.${user}.shell.toolset.git = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "version-control system"; };

  config = mkIf config.modules.${user}.shell.toolset.git.enable {
    environment.sessionVariables.GITHUB_TOKEN = "$(cat /run/agenix/tokenGH)";

    home-manager.users.${user} = {
      home.packages = attrValues {
        inherit (pkgs) act dura lazygit;
        inherit (pkgs.gitAndTools) gh git-open git-crypt;
      };

      programs = {
        zsh.initExtra = ''
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
          difftastic = {
            enable = true;
            background = "dark";
            color = "always";
            display = "inline";
          };

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

          extraConfig = {
            init.defaultBranch = "main";
            core = {
              editor = "nvim";
              whitespace = "trailing-space,space-before-tab";
            };
            credential.helper = "${pkgs.gitFull}/bin/git-credential-libsecret";

            user = {
              name = config.modules.${user}.user.full_name;
              email = config.modules.${user}.user.email;
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
      };
    };
  };
}
