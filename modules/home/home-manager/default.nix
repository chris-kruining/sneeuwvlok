{ lib, osConfig ? { }, ... }:
let
  inherit (lib) mkDefault;
in
{
  systemd.user.startServices = "sd-switch";
  programs.home-manager = {
    enable = true;
  };

  home.stateVersion = mkDefault (osConfig.system.stateVersion or "25.05");
}
