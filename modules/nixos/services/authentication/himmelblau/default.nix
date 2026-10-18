{
  inputs,
  lib,
  pkgs,
  config,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkForce types mapAttrsToList concatLines genAttrs;

  cfg = config.${namespace}.services.authentication.himmelblau;
  himmelblau = inputs.himmelblau.packages.${pkgs.stdenv.hostPlatform.system};
in {
  imports = [inputs.himmelblau.nixosModules.himmelblau];

  options.${namespace}.services.authentication.himmelblau = {
    enable = mkEnableOption "enable azure entra ID authentication";

    domains = mkOption {
      type = types.listOf types.str;
      example = ["example.com"];
      description = "Entra ID domains of the tenant.";
    };

    userMap = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = {chris = "chris@example.com";};
      description = ''
        Local users and the Entra account (UPN) they are.
        They keep logging in locally, their apps get single sign-on through the broker.
        Sign in once per machine with `sudo aad-tool auth-test --name <upn>`.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.himmelblau = {
      enable = true;

      # Logging in stays local, so himmelblau stays out of pam. With a mapped user pam_himmelblau
      # would start an entra flow for that local user before pam_unix gets a chance
      pamServices = [];

      settings = {
        domain = cfg.domains;
      };
    };

    # The module adds polkit-1 on its own when polkit is on
    security.pam.services.polkit-1.rules = genAttrs ["auth" "account" "session"] (_: {
      himmelblau.enable = mkForce false;
    });

    # Default path of `user_map_file`
    environment.etc."himmelblau/user-map".text = concatLines (mapAttrsToList (user: upn: "${user}:${upn}") cfg.userMap);

    environment.systemPackages = [himmelblau.aad-tool];

    # After a reboot the broker asks for the hello pin to unseal the token, through pinentry
    systemd.user.services.himmelblau-broker.path = [pkgs.pinentry-qt];

    # Only writes policy to /etc/chromium, which helium and other chromium browsers read.
    # Himmelblau force-installs its sso extension through it
    programs.chromium.enable = true;
  };
}
