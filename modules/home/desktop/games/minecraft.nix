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
    home-manager.users.${user}.home.packages = attrValues {
      inherit (pkgs) modrinth-app prismlauncher;
    };
  };
}
