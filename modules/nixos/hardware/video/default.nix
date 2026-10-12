{
  lib,
  config,
  namespace,
  ...
}: let
  inherit (lib) mkOption length head;
  inherit (lib.types) nullOr listOf submodule enum path bool;

  cfg = config.${namespace}.hardware.video;

  acceleration = submodule {
    options = {
      api = mkOption {
        type = enum ["qsv" "vaapi" "nvenc" "amf"];
        description = "The API through which the hardware is used.";
      };

      device = mkOption {
        type = path;
        description = "The device node that gives access to the hardware.";
      };

      decode = mkOption {
        type = listOf (enum ["mpeg2" "vc1" "h264" "hevc" "hevc-10bit" "hevc-rext-10bit" "hevc-rext-12bit" "vp8" "vp9" "vp9-10bit" "av1"]);
        description = "Codecs the hardware can decode.";
      };

      encode = mkOption {
        type = listOf (enum ["h264" "hevc" "vp9" "av1"]);
        description = "Codecs the hardware can encode.";
      };

      lowPower = mkOption {
        type = bool;
        description = "Whether the hardware supports low-power encoding.";
      };

      toneMapping = mkOption {
        type = bool;
        description = "Whether the hardware can tone-map HDR video to SDR.";
      };
    };
  };
in {
  options.${namespace}.hardware.video = {
    providers = mkOption {
      type = listOf acceleration;
      default = [];
      internal = true;
      description = "Video acceleration offered by the hardware modules, collected into `acceleration`.";
    };

    acceleration = mkOption {
      type = nullOr acceleration;
      readOnly = true;
      description = ''
        Hardware video acceleration of this machine, derived from its hardware.
        `null` when the machine has none. Services use this instead of knowing about hardware vendors.
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion = length cfg.providers <= 1;
        message = "Multiple hardware modules offer video acceleration, choosing between them is not supported yet.";
      }
    ];

    ${namespace}.hardware.video.acceleration =
      if cfg.providers == []
      then null
      else head cfg.providers;
  };
}
