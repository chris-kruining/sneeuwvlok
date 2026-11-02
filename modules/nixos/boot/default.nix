{ lib, namespace, config, pkgs, inputs, ... }:
let
  inherit (lib) mkIf mkMerge mkDefault mkOption mkForce mkEnableOption;
  inherit (lib.types) enum bool;

  cfg = config.${namespace}.boot;
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  options.${namespace}.boot = {
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

    secureBoot = mkEnableOption ''
      secure boot with lanzaboote, which boots through systemd-boot instead of grub. It makes and enrolls its own keys,
      see orome's readme for the steps in the firmware
    '';
  };

  config = mkMerge [
    ({
      boot = {
        kernelPackages = pkgs.linuxPackages_latest;

        loader = {
          systemd-boot.enable = false;
          grub.enable = mkDefault true;

          grub2-theme = {
            enable = true;
            theme = "vimix";
            footer = true;
          };
        };

        supportedFilesystems = [ "nfs" ];
      };
    })

    (mkIf (cfg.type == "bios") {
      boot.loader.grub.efiSupport = false;
    })

    (mkIf (cfg.type == "uefi") {
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

    (mkIf cfg.secureBoot {
      boot = {
        loader = {
          # lanzaboote takes the place of both
          grub.enable = mkForce false;
          grub2-theme.enable = mkForce false;
          systemd-boot.enable = mkForce false;
        };

        lanzaboote = {
          enable = true;
          pkiBundle = "/var/lib/sbctl";

          # Keys are made on the first boot. They get enrolled by systemd-boot, with microsoft's next to them for option roms,
          # as soon as the firmware is in setup mode
          autoGenerateKeys.enable = true;
          autoEnrollKeys.enable = true;
        };

        # systemd in the initrd, so luks can be unlocked with the tpm
        initrd.systemd.enable = true;
      };

      environment.systemPackages = [ pkgs.sbctl ];
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
