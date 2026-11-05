{
  lib,
  pkgs,
  namespace,
  config,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.hardware.has.fingerprint;

  stateDir = "/var/lib/fprint-unlock";

  pamFprintUnlock = pkgs.stdenv.mkDerivation {
    pname = "pam-fprint-unlock";
    version = "0.1.0";

    src = ./pam_fprint_unlock.c;
    dontUnpack = true;

    buildInputs = [pkgs.linux-pam pkgs.libxcrypt];

    buildPhase = ''
      $CC -shared -fPIC -O2 -Wall -Wextra -Werror \
        -DSYSTEMD_CREDS='"${config.systemd.package}/bin/systemd-creds"' \
        -DSTATE_DIR='"${stateDir}"' \
        -o pam_fprint_unlock.so $src -lpam -lcrypt
    '';

    installPhase = ''
      install -Dm444 pam_fprint_unlock.so $out/lib/security/pam_fprint_unlock.so
    '';
  };

  unlock = "${pamFprintUnlock}/lib/security/pam_fprint_unlock.so";
in {
  options.${namespace}.hardware.has.fingerprint = mkEnableOption "Enable the fingerprint reader";

  config = mkIf cfg {
    # Every pam service gets fprintAuth by default once fprintd is on
    services.fprintd.enable = true;

    security.pam.services = {
      # The login password is what unlocks kwallet, so plain fingerprint logins are off.
      # On sddm a fingerprint prompt also holds up the password field until it times out
      login.fprintAuth = false;

      # The lock screen runs this one next to the password one, finger only. With pam_unix behind it, a timed out finger
      # waits on a password prompt forever, so the lock screen never hears it failed and can't arm it again
      kde-fingerprint.unixAuth = false;

      # Instead sddm gets its own fingerprint path, in front of the regular `login` substack (order 10100):
      # an empty password plus a finger logs in, and the password sealed to the tpm then unlocks kwallet.
      # Every password login (re)seals the password, when it changed.
      sddm = {
        fprintAuth = false;

        rules.auth = {
          fprint-unlock-typed = {
            order = 10000;
            # a typed password skips the 5 fingerprint rules below, straight to `login`
            control = "[success=5 default=ignore]";
            modulePath = unlock;
            args = ["typed"];
          };
          fprint-unlock-finger = {
            order = 10010;
            control = "[success=1 default=ignore]";
            modulePath = "${config.services.fprintd.package}/lib/security/pam_fprintd.so";
          };
          fprint-unlock-deny = {
            order = 10020;
            control = "requisite";
            modulePath = "pam_deny.so";
          };
          fprint-unlock-release = {
            order = 10030;
            control = "optional";
            modulePath = unlock;
            args = ["release"];
          };
          fprint-unlock-kwallet = {
            order = 10040;
            control = "optional";
            modulePath = config.security.pam.services.login.rules.auth.kwallet.modulePath;
          };
          fprint-unlock-permit = {
            order = 10050;
            control = "sufficient";
            modulePath = "pam_permit.so";
          };
          fprint-unlock-store = {
            order = 10200;
            control = "optional";
            modulePath = unlock;
            args = ["store"];
          };
        };
      };
    };

    systemd.tmpfiles.rules = ["d ${stateDir} 0700 root root -"];
  };
}
