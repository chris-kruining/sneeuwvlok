{ lib, namespace, config, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.hardware.has.fingerprint;
in
{
  options.${namespace}.hardware.has.fingerprint = mkEnableOption "Enable the fingerprint reader";

  config = mkIf cfg {
    # Every pam service gets fprintAuth by default once fprintd is on
    services.fprintd.enable = true;

    security.pam.services = {
      # Logging in keeps using the password, it is what unlocks kwallet.
      # On sddm a fingerprint prompt also holds up the password field until it times out
      sddm.fprintAuth = false;
      login.fprintAuth = false;
    };
  };
}
