{
  pkgs,
  config,
  lib,
  namespace,
  inputs,
  system,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) mkIf mkMerge mkEnableOption mkOption types elem;

  cfg = config.${namespace}.services.media.jellyfin;
  acceleration = config.${namespace}.hardware.video.acceleration;
  decodes = codec: elem codec acceleration.decode;
  encodes = codec: elem codec acceleration.encode;
in {
  options.${namespace}.services.media.jellyfin = {
    enable = mkEnableOption "Enable jellyfin server";
  };

  config = mkIf cfg.enable {
    ${namespace}.services.networking.caddy = {
      hosts = {
        "jellyfin.kruining.eu" = ''
          reverse_proxy http://[::1]:8096
        '';
      };
    };

    environment.systemPackages = with pkgs; [
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
      mediainfo
      id3v2
      yt-dlp
    ];

    services = {
      # port is harcoded in nixpkgs module
      jellyfin = mkMerge [
        {
          enable = true;
          openFirewall = true;
          user = "media";
          group = "media";
        }

        # Transcode with whatever the hardware offers. Nix owns the transcoding settings,
        # changes made to them in the dashboard are overwritten on restart.
        (mkIf (acceleration != null) {
          forceEncodingConfig = true;

          hardwareAcceleration = {
            enable = true;
            type = acceleration.api;
            device = acceleration.device;
          };

          transcoding = {
            enableHardwareEncoding = true;
            enableIntelLowPowerEncoding = acceleration.lowPower;
            enableToneMapping = acceleration.toneMapping;

            hardwareDecodingCodecs = {
              mpeg2 = decodes "mpeg2";
              vc1 = decodes "vc1";
              h264 = decodes "h264";
              hevc = decodes "hevc";
              hevc10bit = decodes "hevc-10bit";
              hevcRExt10bit = decodes "hevc-rext-10bit";
              hevcRExt12bit = decodes "hevc-rext-12bit";
              vp8 = decodes "vp8";
              vp9 = decodes "vp9";
              av1 = decodes "av1";
            };

            hardwareEncodingCodecs = {
              hevc = encodes "hevc";
              av1 = encodes "av1";
            };
          };
        })
      ];
    };

    systemd.services.jellyfin.serviceConfig.killSignal = lib.mkForce "SIGKILL";
  };
}
