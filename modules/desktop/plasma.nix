{ pkgs, ... }:
{
  services = {
    xserver.enable = true;

    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
      autoLogin = {
        enable = true;
        user = "chris";
      };
    };

    desktopManager.plasma6.enable = true;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    konsole
  ];

  # should enable theme integration with gtk apps (i.e. firefox, thunderbird)
  programs.dconf.enable = true;
}
