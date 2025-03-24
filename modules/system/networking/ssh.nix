{ config, lib, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.modules.networking.ssh;
in
{
  options.modules.networking.ssh = {
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
