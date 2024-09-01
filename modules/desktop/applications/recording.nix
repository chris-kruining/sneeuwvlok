{ options, config, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf mkForce mkMerge;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.desktop.applications.recording;
in
{
  options.modules.desktop.applications.recording = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Enable recording software (OBS Studio)";
  };

  config = mkIf cfg.enable
  {
    user.packages = attrValues {
      inherit (pkgs) obs-studio obs-stuio-plugins.wlrobs;
    };
  };
}
