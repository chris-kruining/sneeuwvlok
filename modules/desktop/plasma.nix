{ config, options, lib, pkgs, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
in
{
  options.modules.desktop.plasma = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "plasma 6"; };

  config = mkIf config.modules.desktop.plasma.enable {
    services = {
      xserver.enable = true;

      displayManager = {
        sddm = {
          enable = true;
          wayland.enable = true;
        };
        autoLogin = {
          enable = true;
          user = "chris";
        };
      };

      desktopManager.plasma6.enable = true;
    };

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      konsole
    ];

    # should enable theme integration with gtk apps (i.e. firefox, thunderbird)
    programs.dconf.enable = true;
  };
}
