{ pkgs, options, config, lib, ... }:
let
  inherit (builtins) getEnv;
  inherit (lib.modules) mkIf mkMerge;
in
{
  options.modules.networking.samba = let
    inherit (lib.options) mkEnableOption;
  in {
    sharing.enable = mkEnableOption "Samba: enable NixOs -> external file-transfer";
    receicing.enable = mkEnableOption "Samba: enable external -> NixOs file-transfer";
  };

  config = mkMerge [
    (mkIf config.modules.networking.samba.sharing.enable {
      users = {
        groups.samba-guest = {};
        users.samba-guest = {
          isSystemUser = true;
          description = "Residence of our Samba guest users";
          group = "samba-guest";
          home = "/var/empty";
          createHome = false;
          shell = pkgs.shadow;
        };
      };
      user.extraGroups = [ "samba-guest" ];

      networking.firewall = {
        allowPing = true;
        allowedTCPPorts = [ 5327 ];
        allowedUDPPorts = [ 3702 ];
      };

      services.samba-wsdd.enable = true;

      services.samba = {
        enable = true;
        openFirewall = true;
        extraConfig = ''
          server string = ${config.networking.hostName}
          netbios name = ${config.networking.hostName}
          workgroup = WORKGROUP
          security = user

          create mask 0664
          force create mode 0664
          directory mask 0775
          force directory mode 0775
          follow symlink = yes

          hosts allow = 192.168.1.0/24 localhost
          hosts deny = 0.0.0.0/0
          guest account = nobody
          map to guest = bad user
        '';
        shares = {
          Public = {
            path = (getEnv "HOME") + "/Public";
            browseable = "yes";
            "read only" = "yes";
            "guest ok" = "yes";
            "forse user" = "${config.user.name}";
            "force group" = "samba-guest";
            "write list" = "${config.user.name}";
          };
        };
      };
    })
  ];
}
