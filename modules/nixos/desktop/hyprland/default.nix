{
  lib,
  pkgs,
  config,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption any id attrValues optionalAttrs;

  cfg = config.${namespace}.desktop.hyprland;
in {
  options.${namespace}.desktop.hyprland = {
    enable = mkEnableOption "Enable Hyprland as an additional login session, alongside whatever `desktop.use` configures";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = any id (attrValues config.${namespace}.hardware.has.gpu);
        message = "Hyprland needs a GPU, but `${namespace}.hardware.has.gpu` lists none for this machine.";
      }
    ];

    services.displayManager.enable = true;

    programs.hyprland.enable = true;

    xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];

    security.pam.services =
      {
        passwd = {};
      }
      // optionalAttrs config.${namespace}.hardware.has.fingerprint {
        fprint = {};
      };
  };
}
