{ options, config, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf mkForce mkMerge;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.desktop.applications.office;
in
{
  options.modules.desktop.applications.office = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Enable office suite (only-office)";
  };

  config = mkIf cfg.enable
  {
    user.packages = attrValues {
      inherit (pkgs) webcord teamspeak_client;
    };

    fonts.packages = with pkgs; [
      corefonts
    ];
  };
}
