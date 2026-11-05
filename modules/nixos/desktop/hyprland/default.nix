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

    programs.hyprland = {
      enable = true;

      # hyprland ships a `Hyprland (uwsm)` session as well, home-manager's hyprland-session.target already does what uwsm would
      package = pkgs.symlinkJoin {
        inherit (pkgs.hyprland) pname version meta;
        paths = [pkgs.hyprland];
        postBuild = ''
          rm $out/share/wayland-sessions/hyprland-uwsm.desktop
        '';
        passthru = {
          providedSessions = ["hyprland"];
          inherit (pkgs.hyprland) man dev;
          # the module probes override for enableXWayland, which hyprland's default (true) already covers
          override = _: throw "the hyprland session wrapper can't be overridden";
        };
      };
    };

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
