{ pkgs, config, namespace, inputs, ... }:
let
  cfg = config.${namespace}.system.security.sops;
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  options.${namespace}.system.security.sops = {};

  config = {
    environment.systemPackages = with pkgs; [ sops ];

    sops = {
      age.keyFile = "/home/.sops-key.age";

      defaultSopsFile = ../../../../systems/x86_64-linux/${config.networking.hostName}/secrets.yaml;
      defaultSopsFormat = "yaml";

    };
  };
}