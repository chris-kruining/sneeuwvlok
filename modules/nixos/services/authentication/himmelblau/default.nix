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

    # A static user instead of DynamicUser. To allocate a dynamic one systemd first asks nss whether the name is free,
    # nss asks himmelblau, which is the daemon being started: boot (and the login screen) stalled for its 10s request
    # timeout. himmelblau-hsm-pin-init, without DynamicUser, also moved the shared state directory in and out of
    # /var/lib/private on every boot. The rest is what DynamicUser implied
    users.users.himmelblaud = {
      isSystemUser = true;
      group = "himmelblaud";
    };
    users.groups.himmelblaud = {};
    systemd.services.himmelblaud.serviceConfig = {
      DynamicUser = mkForce false;
      Group = "himmelblaud";
      ProtectHome = "read-only";
      RemoveIPC = true;
      RestrictSUIDSGID = true;
    };

    # Out of the way of booting and logging in: users are local and logging in stays local, so nothing needs himmelblau's
    # nss (it returns no one) and nothing has to wait for the daemon, which spends seconds on the tpm at start. In nss the
    # login screen's user list would still wait for it, through its socket. These are nixos' lists without it
    system.nssDatabases = {
      passwd = mkForce ["files" "systemd"];
      group = mkForce ["files" "[success=merge] systemd"];
      shadow = mkForce ["files" "systemd"];
    };
    systemd.services.himmelblaud.before = mkForce [];

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
