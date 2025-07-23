{ config, lib, pkgs, ... }:
let
  inherit (lib) mkMerge mkIf mkEnableOption mkDefault mkForce;

  cfg = config.modules.boot;
in
{
  options.modules.boot =
  {
    silentBoot = mkEnableOption "Enable silent boot";
    animatedBoot = mkEnableOption "Enable boot animation";
  };

  config = mkMerge [
    ({
      boot.loader = {
        efi.canTouchEfiVariables = true;

        systemd-boot.enable = true;

        timeout = mkDefault 0;
      };

      time.timeZone = "Europe/Amsterdam";
    })

    (mkIf (cfg.silentBoot == true) {
      boot = {
        consoleLogLevel = 0;
        initrd.verbose = false;
        kernelParams = [ "quiet" "splash" "boot.shell_on_fail" "udev.log_priority=3" "rd.systemd.show_status=auto" ];
        loader.timeout = mkDefault 0;
      };
    })

    (mkIf (cfg.animatedBoot == true) {
      boot.plymouth = {
        enable = true;
        theme = mkForce "pixels";
        themePackages = with pkgs; [
          (adi1090x-plymouth-themes.override {
            selected_themes = [ "pixels" ];
          })
        ];
      };
    })
  ];
}
