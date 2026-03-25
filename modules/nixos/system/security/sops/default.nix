{ pkgs, config, namespace, repoRoot, ... }:
let
  cfg = config.${namespace}.system.security.sops;
in
{
  options.${namespace}.system.security.sops = {};

  config = {
    environment.systemPackages = with pkgs; [ sops ];

    sops = {
      defaultSopsFormat = "yaml";
      defaultSopsFile = repoRoot + "/systems/${pkgs.stdenv.hostPlatform.system}/${config.networking.hostName}/secrets.yml";

      age = {
        # keyFile = "~/.config/sops/age/keys.txt";
        # sshKeyPaths = [ "~/.ssh/id_ed25519" ];
        # generateKey = true;
      };
    };
  };
}
