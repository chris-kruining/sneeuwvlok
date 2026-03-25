{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.application.steam;
in {
  options.sneeuwvlok.application.steam = {
    enable = mkEnableOption "enable steam";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [steam];

    programs = {
      steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];
      };
    };
  };
}
