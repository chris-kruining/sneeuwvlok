{ lib, namespace, config, pkgs, inputs, ... }:
let
  inherit (lib) mkIf mkMerge mkDefault mkOption mkForce mkEnableOption toUpper removePrefix;
  inherit (lib.types) enum bool str;

  cfg = config.${namespace}.boot;

  anurati = "${pkgs.${namespace}.anurati}/share/fonts/opentype/Anurati-Regular.otf";
  poppins = "${pkgs.poppins}/share/fonts/truetype/Poppins-Light.ttf";

  # The lock screen's clock, the host's name in its place. Plymouth has a single font and nothing like letter spacing, so
  # all text is drawn here
  splashTheme = pkgs.runCommand "plymouth-theme-sneeuwvlok" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    dir=$out/share/plymouth/themes/sneeuwvlok
    mkdir -p $dir
    cd $dir

    # <file> <font> <size> <spacing> <text>, white with the lock screen's shadow
    text() {
      magick -background none -fill white -font "$2" -pointsize "$3" -kerning "$4" label:"$5" \
        \( +clone -background black -shadow 60x12+0+2 \) +swap -background none -layers merge +repage "$1"
    }
    text name.png ${anurati} 110 26 ${toUpper config.networking.hostName}
    text starting.png ${poppins} 26 4 STARTING
    text shutting-down.png ${poppins} 26 4 'SHUTTING DOWN'
    text restarting.png ${poppins} 26 4 RESTARTING
    text updating.png ${poppins} 26 4 UPDATING
    text passphrase.png ${poppins} 18 4 PASSPHRASE
    magick -size 16x16 xc:none -fill white -draw 'circle 8,8 8,2' dot.png

    # the wallpaper darkened in an ellipse around the text, solid up to a quarter and gone at its edge
    w=$(( $(magick identify -format %w name.png) * 17 / 10 ))
    h=$(( ($(magick identify -format %h name.png) + $(magick identify -format %h starting.png)) * 28 / 10 ))
    magick -size 512x512 -define gradient:radii=256,256 radial-gradient:white-black -level 0%,76% \
      -evaluate multiply 0.45 -resize "''${w}x''${h}!" alpha.png
    magick -size "''${w}x''${h}" xc:black alpha.png -alpha off -compose CopyOpacity -composite halo.png
    rm alpha.png

    substitute ${./splash/splash.script} sneeuwvlok.script \
      --subst-var-by name sneeuwvlok \
      --subst-var-by wallpaper ${removePrefix "/" cfg.splash.wallpaper}
    cat > sneeuwvlok.plymouth <<EOF
    [Plymouth Theme]
    Name=Sneeuwvlok
    Description=The wallpaper of the day with the host's name, like the lock screen
    ModuleName=script

    [script]
    ImageDir=/
    ScriptFile=/etc/plymouth/themes/sneeuwvlok/sneeuwvlok.script
    EOF
  '';
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

    splash = {
      enable = mkEnableOption ''
        a boot and shutdown splash that looks like the lock screen, the host's name over the wallpaper of the day. The
        wallpaper shows once the real root is up, the initrd only has the name
      '';

      wallpaper = mkOption {
        type = str;
        default = "/var/lib/splash/wallpaper.png";
        description = "The png the splash shows behind the name, the desktop's wallpaper rotation copies it here";
      };
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
      };

      environment.systemPackages = [ pkgs.sbctl ];
    })

    (mkIf cfg.splash.enable {
      ${namespace}.boot.quiet = true;

      boot.plymouth = {
        enable = true;
        theme = "sneeuwvlok";
        themePackages = [ splashTheme ];
        # for the system's messages
        font = poppins;
      };

      # any user's wallpaper rotation may write it
      systemd.tmpfiles.rules = [ "d ${dirOf cfg.splash.wallpaper} 0775 root users -" ];
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
