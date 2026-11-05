{
  inputs,
  system,
  lib,
  pkgs,
  config,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkForce types mapAttrsToList concatLines genAttrs;

  cfg = config.${namespace}.services.authentication.himmelblau;

  # TODO: drop once himmelblau links against the system aws-lc. nixpkgs' crate override now does that for aws-lc-sys,
  # and aws-lc's libcrypto.so then shadows openssl's when the broker is linked, so it gets its own aws-lc built in again
  himmelblau =
    (import inputs.himmelblau {
      inherit system;
      pkgs = pkgs.extend (final: prev: {
        defaultCrateOverrides =
          prev.defaultCrateOverrides
          // {
            aws-lc-sys = attrs: {
              nativeBuildInputs = [final.cmake];
              env.AWS_LC_SYS_CMAKE_BUILDER = 1;
            };
          };
      });
    }).packages;
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

      daemonPackage = himmelblau.daemon;
      aadToolPackage = himmelblau.aad-tool;
      ssoPackage = himmelblau.sso;
      brokerPackage = himmelblau.broker;
      pamPackage = himmelblau.pam;
      nssPackage = himmelblau.nss;

      # Logging in stays local, so himmelblau stays out of pam. With a mapped user pam_himmelblau
      # would start an entra flow for that local user before pam_unix gets a chance
      pamServices = [];

      settings = {
        domain = cfg.domains;
      };
    };

    # The module adds polkit-1 on its own when polkit is on, and sshd when the ssh server is
    security.pam.services = genAttrs ["polkit-1" "sshd"] (_: {
      rules = genAttrs ["auth" "account" "session"] (_: {
        himmelblau.enable = mkForce false;
      });
    });

    # Default path of `user_map_file`
    environment.etc."himmelblau/user-map".text = concatLines (mapAttrsToList (user: upn: "${user}:${upn}") cfg.userMap);

    environment.systemPackages = [
      himmelblau.aad-tool

      # Teams (teams-for-linux in intune mode, which gets its token from the broker) and launchers for outlook, onedrive, word, ...
      himmelblau.o365
    ];

    # After a reboot the broker asks for the hello pin to unseal the token, through pinentry
    systemd.user.services.himmelblau-broker = {
      path = [pkgs.pinentry-qt];
      wantedBy = ["default.target"];
    };

    # Only writes policy to /etc/chromium, which helium and other chromium browsers read.
    # Himmelblau force-installs its sso extension through it
    programs.chromium.enable = true;
  };
}
