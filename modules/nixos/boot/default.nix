{ lib, namespace, config, ... }:
let
  inherit (lib) mkIf mkMerge mkDefault mkEnableOption;
  inherit (lib.types) enum;

  cfg = config.${namespace}.boot;
in
{
  config.${namespace}.boot = {
    type = mkOption {
      type = enum [ "bios" "uefi" ];
      default = "uefi";
    };

    quiet = mkOption {
      type = bool;
      default = false;
    };

    animated = mkOption {
      type = bool;
      default = false;
    };
  };

  config = mkMerge [
    ({
      boot.loader.grub.enable = mkDefault true;
    })

    (mkIf cfg.type == "bios" {
      boot.loader.grub.efiSupport = false;
    })

    (mkIf cfg.type == "uefi" {
      boot.loader = {
        efi.canTouchEfiVariables = true;
        grub = {
          efiSupport = true;
          efiInstallAsRemovable = mkDefault false;
          device = "nodev"; # INFO: https://discourse.nixos.org/t/question-about-grub-and-nodev
        };
      };
    })

    (mkIf cfg.quiet {
      boot = {
        consoleLogLevel = 0;

        initrd = {
          systemd.enable = true;
          verbose = false;
        };

        kernelParams = [ 
          "quiet"
          "loglevel=3"
          "systemd.show_status=auto"
          "udev.log_level=3"
          "rd.udev.log_level=3"
          "vt.global_cursor_default=0"
        ];

        loader.timeout = mkDefault 0;
      };
    })

    (mkIf cfg.animated {
      boot.plymouth = {
        enable = true;
        
        theme = mkDefault "pixels";
        themePackages = with pkgs; [
          (adi1090x-plymouth-themes.override {
            selected_themes = [ "pixels" ];
          })
        ];
      };
    })
  ];
}