{ pkgs, config, ... }:
{
  imports = [
    "${fetchTarball {
      url = "https://github.com/onny/nixos-nextcloud-testumgebung/archive/fa6f062830b4bc3cedb9694c1dbf01d5fdf775ac.tar.gz";
      sha256 = "0gzd0276b8da3ykapgqks2zhsqdv4jjvbv97dsxg0hgrhb74z0fs";}}/nextcloud-extras.nix"
  ];

  environment.etc."nextcloud-admin-pass".text = "KaasIsAwesome!";

  services.nextcloud = {
    enable = true;
    https = true;
    package = pkgs.nextcloud29;
    hostName = "localhost";
    webserver = "caddy";
    config = {
      adminpassFile = "/etc/nextcloud-admin-pass";
      dbtype = "sqlite";
    };

#    extraApps = {
#      inherit (config.services.nextcloud.package.packages.apps) contacts calendar;
#    };
#    extraAppsEnable = true;
  };
}
