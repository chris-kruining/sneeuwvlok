{ options, config, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf mkForce mkMerge;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.${user}.desktop.applications.communication;
in
{
  options.modules.${user}.desktop.applications.communication = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Enable office suite (only-office)";
  };

  config = mkIf cfg.enable
  {
    home-manager.users.${user}.home.packages = with pkgs; [vesktop teamspeak_client signal-desktop];
  };
}
