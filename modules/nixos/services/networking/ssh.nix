{ config, lib, namespace, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.${namespace}.services.networking.ssh;
in
{
  options.${namespace}.services.networking.ssh = {
    enable = mkEnableOption "enable ssh";
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      openFirewall = true;
      ports = [ 22 ];
      settings = {
        PasswordAuthentication = true;
        AllowUsers = [ "chris" "root" ];
        UseDns = true;
        UsePAM = true;
        PermitRootLogin = "prohibit-password";
        PermitEmptyPasswords = "no";
      };
    };
  };
}
