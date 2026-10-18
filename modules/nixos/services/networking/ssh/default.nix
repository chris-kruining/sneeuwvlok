{ config, lib, namespace, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.types) listOf str;
  inherit (lib.attrsets) genAttrs attrNames;

  cfg = config.${namespace}.services.networking.ssh;
in
{
  options.${namespace}.services.networking.ssh = {
    enable = mkEnableOption "enable ssh";

    authorizedKeys = mkOption {
      type = listOf str;
      default = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICE+TFkjJ8p8fMOddvg/waKAjKJ6DRvvouj1MdXc1Taj chris@chris-pc"
      ];
      description = ''
        Public keys that may log in on every machine, as root and as each user snowfall creates.
        Adding or revoking a device is a change here and a rebuild.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      openFirewall = true;
      ports = [ 22 ];
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        AllowUsers = [ "chris" "root" ];
        UseDns = true;
        UsePAM = true;
        PermitRootLogin = "prohibit-password";
        PermitEmptyPasswords = "no";
      };
    };

    users.users = genAttrs ([ "root" ] ++ attrNames config.snowfallorg.users) (_: {
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    });
  };
}
