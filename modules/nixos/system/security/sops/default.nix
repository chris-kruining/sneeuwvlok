{
  pkgs,
  config,
  self,
  ...
}: let
  cfg = config.sneeuwvlok.system.security.sops;
in {
  options.sneeuwvlok.system.security.sops = {};

  config = {
    environment.systemPackages = with pkgs; [sops];

    sops = {
      defaultSopsFormat = "yaml";
      defaultSopsFile = self + "/systems/${pkgs.stdenv.hostPlatform.system}/${config.networking.hostName}/secrets.yml";

      age = {
        # keyFile = "~/.config/sops/age/keys.txt";
        # sshKeyPaths = [ "~/.ssh/id_ed25519" ];
        # generateKey = true;
      };
    };
  };
}
