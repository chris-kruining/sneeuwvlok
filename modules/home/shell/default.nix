{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) attrValues mkIf mkMerge mkOption mkEnableOption mkDefault;
  inherit (lib.types) nullOr enum;

  cfg = config.${namespace}.shell;
in
{
  options.${namespace}.shell = {
    default = mkOption {
      type = nullOr (enum ["fish" "zsh" "bash"]);
      default = null;
      description = "Default system shell";
    };
    
    corePkgs.enable = mkEnableOption "core shell packages";
  };

  config = mkMerge [
    # (if (cfg.default != null) then { 
    #   shell = pkgs."${cfg.default}";
    # } else {})

    (mkIf (cfg.corePkgs.enable) {
      ${namespace}.shell.toolset = mkDefault {
        bat.enable = true;
        btop.enable = true;
        eza.enable = true;
        fzf.enable = true;
        git.enable = true;
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