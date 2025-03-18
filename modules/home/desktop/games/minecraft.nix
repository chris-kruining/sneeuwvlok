{ options, config, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf mkForce mkMerge;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.${user}.desktop.games.minecraft;
in
{
  options.modules.${user}.desktop.games.minecraft = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "minecraft (Modrinth)";
  };

  config = mkIf cfg.enable {
    # environment.systemPackages = [
    #   pkgs.minecract
    # ];
    user.packages = attrValues {
      inherit (pkgs) modrinth-app prismlauncher;
    };
  };
}
