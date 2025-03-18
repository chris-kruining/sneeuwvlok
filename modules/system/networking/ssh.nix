{ config, options, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) attrValues;
in
{
  options.modules.networking.ssh = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "enable ssh";
  };

  config = mkIf config.modules.networking.ssh.enable {
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
