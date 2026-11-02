{ lib, pkgs, config, namespace, inputs, system, ... }:
let
  cfg = config.${namespace}.system.security.sops;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  options.${namespace}.system.security.sops = {};

  config = {
    # Only where there are secrets to look at
    environment.systemPackages = lib.mkIf (config.sops.secrets != {}) [ pkgs.sops ];

    sops = {
      defaultSopsFormat = "yaml";
      defaultSopsFile = inputs.self + "/systems/${system}/${config.networking.hostName}/secrets.yml";

      age = {
        # keyFile = "~/.config/sops/age/keys.txt";
        # sshKeyPaths = [ "~/.ssh/id_ed25519" ];
        # generateKey = true;
      };
    };
  };
}