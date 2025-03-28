{ config, lib, pkgs, user, ... }:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.types) nullOr enum;

  cfg = config.modules.${user}.shell;
in
{
  options.modules.${user}.shell = {
    default = mkOption {
      type = nullOr (enum ["fish" "zsh" "bash"]);
      default = null;
      description = "Default system shell";
    };

    corePkgs.enable = mkEnableOption "core shell packages";
  };

  config = mkMerge [
    (mkIf (cfg.default != null) {
      users.defaultUserShell = pkgs."${cfg.default}";

      # modules.${user}.shell.toolset.gnupg.enable = true;
    })

    (mkIf cfg.corePkgs.enable {
      modules.${user}.shell.toolset = {
        btop.enable = true;
        fzf.enable = true;
        starship.enable = true;
        tmux.enable = true;
        yazi.enable = true;
        eza.enable = true;
        git.enable = true;
        zoxide.enable = true;
      };

      home-manager.users.${user} = {
        home.packages = attrValues {
          inherit (pkgs) any-nix-shell pwgen yt-dlp ripdrag;
          inherit (pkgs) fd;

          rgFull = pkgs.ripgrep.override {withPCRE2 = true;};
        };

        home.shellAliases = {
          ls = "eza -a";
          cat = "bat -pp";
          y = "yazi";
          zed = "zeditor .";
        };

        programs = {
          direnv = {
            enable = true;
            config.global = {
              load_dotenv = true;
              strict_env = true;
              hide_env_diff = true;
            };
            nix-direnv.enable = true;
            config.whitelist.prefix = ["/home"];
          };
        };
      };
    })
  ];
}
