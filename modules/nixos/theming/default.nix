{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.theming;
in
{
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  options.${namespace}.theming = {
    enable = mkEnableOption "enable theming" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    stylix = {
      enable = true;
      autoEnable = true;

      # base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.theme}.yaml";
      # image = ./${cfg.theme}.jpg;
      # polarity = cfg.polarity;

      fonts = {
        serif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Serif";
        };

        sansSerif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Sans";
        };

        monospace = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = "JetBrainsMono Nerd Font Mono";
        };

        emoji = {
          package = pkgs.noto-fonts-emoji;
          name = "Noto Color Emoji";
        };
      };
    };
  };
}
