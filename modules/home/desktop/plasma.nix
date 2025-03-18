{ config, options, lib, pkgs, user, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;

  cfg = config.modules.${user}.desktop.plasma;
in
{
  options.modules.${user}.desktop.plasma = let
    inherit (lib.options) mkEnableOption mkOption;
  in {
    enable = mkEnableOption "plasma 6";

    autoLogin = mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Enable plasma's auto login feature.";
    };
  };

  config = mkIf cfg.enable {
    services = {
      desktopManager.plasma6.enable = true;

      displayManager = {
        sddm = {
          enable = true;
          wayland.enable = true;
        };
        autoLogin = mkIf cfg.autoLogin {
          enable = true;
          inherit user;
        };
      };
    };

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      konsole
    ];

    # should enable theme integration with gtk apps (i.e. firefox, thunderbird)
    programs.dconf.enable = true;

    home-manager.users.${user}.programs = {
      plasma = {
        enable = true;

        kwin = {
          edgeBarrier = 0;
          cornerBarrier = false;
        };

        spectacle.shortcuts = {
          captureRectangularRegion = "Meta+Shift+S";
        };
      };
    };
  };
}
