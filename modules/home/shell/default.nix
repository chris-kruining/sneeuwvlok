{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkMerge mkEnableOption mkDefault;

  cfg = config.${namespace}.shell;
in
{
  options.${namespace}.shell = {
    corePkgs.enable = mkEnableOption "core shell packages";
  };

  config = mkMerge [
    (mkIf (cfg.corePkgs.enable) {
      ${namespace}.shell.toolset = mkDefault {
        bat.enable = true;
        btop.enable = true;
        eza.enable = true;
        fzf.enable = true;
        git.enable = true;
        just.enable = true;
        starship.enable = true;
        tmux.enable = true;
        yazi.enable = true;
        zoxide.enable = true;
      };
    })

    ({
      home.packages = with pkgs; [ any-nix-shell pwgen yt-dlp ripdrag fd (ripgrep.override {withPCRE2 = true;}) ];

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
    })
  ];
}
