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
      defaultSopsFile = ../../../../../_secrets/secrets.yaml;
      defaultSopsFormat = "yaml";

      age.keyFile = "/home/";
    };
  };
}