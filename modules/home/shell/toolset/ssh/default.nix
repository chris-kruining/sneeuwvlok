{ config, lib, namespace, inputs, ... }:
let
  inherit (lib) mkEnableOption mkIf genAttrs attrNames;

  cfg = config.${namespace}.shell.toolset.ssh;
in
{
  options.${namespace}.shell.toolset.ssh = {
    enable = mkEnableOption "ssh client";
  };

  config = mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      # `ssh <machine>` for every machine in this flake, the name resolves through the router (at home or over the vpn).
      # As root, ulmo has no other user and deploys log in like this as well
      matchBlocks = genAttrs (attrNames inputs.self.nixosConfigurations) (_: { user = "root"; }) // {
        "*" = {
          # Keys come from bitwarden's agent first, and from the yubikey when the vault isn't available.
          # `ssh-keygen -K` saves the yubikey's resident key under this name
          identityAgent = mkIf config.${namespace}.application.bitwarden.enable "~/.bitwarden-ssh-agent.sock";
          identityFile = [ "~/.ssh/id_ed25519_sk_rk" ];

          # One connection per host, so a deploy asks for a single touch of the yubikey
          controlMaster = "auto";
          controlPath = "~/.ssh/control-%C";
          controlPersist = "10m";
        };
      };
    };
  };
}
