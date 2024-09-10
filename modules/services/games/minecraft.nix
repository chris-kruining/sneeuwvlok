{ config, options, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.services.games.minecraft = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Minecraft";
  };

  config = mkIf config.modules.services.auth.enable {
    services.minecraft = {
      enable = true;
      eula = true;
    };
  };
}
