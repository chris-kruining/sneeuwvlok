{
  pkgs,
  lib,
  config,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkMerge mkOption filter length head findFirst elem toLower attrValues;
  inherit (lib.types) bool;

  # Intel GPU generations this repo knows, matched on the PCI device id from the nixos-facter report.
  # Device ids come from the kernel's include/drm/intel/pciids.h, codecs from the support table at
  # https://github.com/intel/media-driver#decodingencoding-features (Alder Lake falls under TGLx).
  # intel-compute-runtime provides OpenCL, which HDR tone-mapping needs.
  generations = {
    alder-lake-n = {
      ids = ["46d0" "46d1" "46d2" "46d3" "46d4"];
      packages = with pkgs; [intel-media-driver vpl-gpu-rt intel-compute-runtime];
      decode = ["mpeg2" "vc1" "h264" "hevc" "hevc-10bit" "hevc-rext-10bit" "hevc-rext-12bit" "vp9" "vp9-10bit" "av1"];
      encode = ["h264" "hevc" "vp9"];
    };

    # Meteor Lake dropped VC-1 and gained AV1 encode, all encoding goes through the low-power VDEnc path
    meteor-lake = {
      ids = ["7d40" "7d45" "7d55" "7d60" "7dd5"];
      packages = with pkgs; [intel-media-driver vpl-gpu-rt intel-compute-runtime];
      decode = ["mpeg2" "h264" "hevc" "hevc-10bit" "hevc-rext-10bit" "hevc-rext-12bit" "vp9" "vp9-10bit" "av1"];
      encode = ["h264" "hevc" "vp9" "av1"];
    };
  };

  gpus = filter (card: card.vendor.hex or null == "8086") (config.hardware.facter.report.hardware.graphics_card or []);
  gpu = head gpus;
  id = toLower gpu.device.hex;
  generation = findFirst (generation: elem id generation.ids) null (attrValues generations);
  detected = gpus != [];
in {
  options.${namespace}.hardware.has.gpu.intel = mkOption {
    type = bool;
    readOnly = true;
    description = "Whether the machine has an Intel GPU, detected from its nixos-facter report.";
  };

  config = mkMerge [
    {${namespace}.hardware.has.gpu.intel = detected;}

    (mkIf detected {
      assertions = [
        {
          assertion = length gpus == 1;
          message = "Machines with more than one Intel GPU are not supported yet by modules/nixos/hardware/gpu/intel.";
        }
        {
          assertion = generation != null;
          message = "The Intel GPU with PCI device id ${id} is not known, add its generation to modules/nixos/hardware/gpu/intel.";
        }
      ];

      hardware.graphics = {
        enable = true;
        extraPackages = mkIf (generation != null) generation.packages;
      };

      ${namespace}.hardware.video.providers = mkIf (generation != null) [
        {
          api = "qsv";
          device = "/dev/dri/by-path/pci-${gpu.sysfs_bus_id}-render";
          inherit (generation) decode encode;
          lowPower = true;
          toneMapping = true;
        }
      ];
    })
  ];
}
