{ config, pkgs, ... }:
{
  fileSystems = {
    "/home/chris/media" = {
      device = "ulmo:/";
      fsType = "nfs";
    };
  };

  environment.systemPackages = [ pkgs.ventoy-full-qt ];
  permittedInsecurePackages = [ "ventoy-qt5-1.1.05"];
  boot.supportedFilesystems = [ "nfs" ];

  modules = {
    boot = {
      silentBoot = true;
      animatedBoot = true;
    };

    system.audio.enable = true;

    root = {
      user = {
        full_name = "__ROOT__";
        email = "__ROOT__@${config.networking.hostName}";
      };

      shell = {
        default = "zsh";
      };
    };
  };
}
