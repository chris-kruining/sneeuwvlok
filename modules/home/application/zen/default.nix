{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.zen;
in
{
  options.${namespace}.application.zen = {
    enable = mkEnableOption "enable zen";
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
    };

    programs.zen-browser = {
      enable = true;

      policies = {
        AutofillAddressEnabled = true;
        AutofillCreditCardEnabled = false;

        AppAutoUpdate = false;
        DisableAppUpdate = true;
        ManualAppUpdateOnly = true;

        DisableFeedbackCommands = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;

        DontCheckDefaultBrowser = false;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };

        HttpAllowlist = [
          "http://ulmo"
        ];
      };

      policies.ExtensionSettings = let
        mkExtension = id: {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/${builtins.toString id}/latest.xpi";
          installation_mode = "force_installed";
        };
      in
      {
        ublock_origin = 4531307;
        ghostry = 4562168;
        bitwarden = 4562769;
        sponsorblock = 4541835;
      };
    };
  };
}
