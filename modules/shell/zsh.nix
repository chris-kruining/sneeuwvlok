{ config, options, pkgs, lib, ... }:
let
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.modules) mkIf;
  inherit (lib.strings) concatStrings escapeNixString;

  cfg = config.modules.shell;
in
{
  config = mkIf (cfg.default == "zsh") {
    modules.shell = {
      corePkgs.enable = true;
      toolset = {
        starship.enable = true;
      };
    };

    hm.programs.starship.enableZshIntegration = true;

    # Enable completion for sys-packages:
    environment.pathsToLink = ["/share/zsh"];

    programs.zsh.enable = true;

    hm.programs.zsh = {
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

#       syntaxHighlighting = let
#         inherit (config.modules.themes) active;
#       in
#         mkIf (active != null) {
#           enable = true;
#           highlighters = ["main" "brackets" "pattern" "cursor" "regexp" "root" "line"];
#           patterns = {
#             "sudo " = "fg=red,bold";
#             "rm -rf *" = "fg=red,bold";
#           };
#           styles = {
#             # -------===[ Comments ]===------- #
#             comment = "fg=black";
#
#             # -------===[ Functions/Methods ]===------- #
#             alias = "fg=magenta";
#             "suffix-alias" = "fg=magenta";
#             "global-alias" = "fg=magenta";
#             function = "fg=blue";
#             command = "fg=green";
#             precommand = "fg=green,italic";
#             autodirectory = "fg=yellow,italic";
#             "single-hyphen-option" = "fg=yellow";
#             "double-hyphen-option" = "fg=yellow";
#             "back-quoted-argument" = "fg=magenta";
#
#             # -------===[ Built-ins ]===------- #
#             builtin = "fg=blue";
#             "reserved-word" = "fg=green";
#             "hashed-command" = "fg=green";
#
#             # -------===[ Punctuation ]===------- #
#             commandseparator = "fg=brightRed";
#             "command-substitution-delimiter" = "fg=border";
#             "command-substitution-delimiter-unquoted" = "fg=border";
#             "process-substitution-delimiter" = "fg=border";
#             "back-quoted-argument-delimiter" = "fg=brightRed";
#             "back-double-quoted-argument" = "fg=brightRed";
#             "back-dollar-quoted-argument" = "fg=brightRed";
#
#             # -------===[ Strings ]===------- #
#             "command-substitution-quoted" = "fg=brightYellow";
#             "command-substitution-delimiter-quoted" = "fg=brightYellow";
#             "single-quoted-argument" = "fg=brightYellow";
#             "single-quoted-argument-unclosed" = "fg=red";
#             "double-quoted-argument" = "fg=brightYellow";
#             "double-quoted-argument-unclosed" = "fg=red";
#             "rc-quote" = "fg=brightYellow";
#
#             # -------===[ Variables ]===------- #
#             "dollar-quoted-argument" = "fg=highlight";
#             "dollar-quoted-argument-unclosed" = "fg=brightRed";
#             "dollar-double-quoted-argument" = "fg=highlight";
#             assign = "fg=highlight";
#             "named-fd" = "fg=highlight";
#             "numeric-fd" = "fg=highlight";
#
#             # -------===[ Non-Exclusive ]===------- #
#             "unknown-token" = "fg=red";
#             path = "fg=highlight,underline";
#             path_pathseparator = "fg=brightRed,underline";
#             path_prefix = "fg=highlight,underline";
#             path_prefix_pathseparator = "fg=brightRed,underline";
#             globbing = "fg=highlight";
#             "history-expansion" = "fg=magenta";
#             "back-quoted-argument-unclosed" = "fg=red";
#             redirection = "fg=highlight";
#             arg0 = "fg=highlight";
#             default = "fg=highlight";
#             cursor = "fg=highlight";
#           };
#         };
    };

    create.configFile.zsh-abbreviations = {
      target = "zsh/abbreviations";
      text = let
        abbrevs = import "${config.sneeuwvlok.configDir}/shell-abbr";
      in ''
        ${concatStrings (mapAttrsToList
          (k: v: "abbr ${k}=${escapeNixString v}")
          abbrevs
        )}
      '';
    };
  };
}
