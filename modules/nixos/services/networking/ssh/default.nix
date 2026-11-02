{ config, lib, namespace, inputs, system, ... }:
let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.types) listOf str;
  inherit (lib.attrsets) genAttrs attrNames mapAttrs filterAttrs;

  cfg = config.${namespace}.services.networking.ssh;

  # Every machine whose public host key is in the repo, next to its config
  machines = inputs.self + "/systems/${system}";
  hostKeys = filterAttrs (name: type: type == "directory" && builtins.pathExists (machines + "/${name}/ssh_host_ed25519_key.pub")) (builtins.readDir machines);
in
{
  options.${namespace}.services.networking.ssh = {
    enable = mkEnableOption "enable ssh";

    authorizedKeys = mkOption {
      type = listOf str;
      default = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICE+TFkjJ8p8fMOddvg/waKAjKJ6DRvvouj1MdXc1Taj chris"
      ];
      description = ''
        Public keys that may log in on every machine, as root and as each user snowfall creates.
        Adding or revoking a device is a change here and a rebuild.
      '';
    };
  };

  config = mkMerge [
    {
      # So `ssh <machine>` trusts the machine without asking, on every machine
      programs.ssh.knownHosts = mapAttrs (name: _: {
        publicKeyFile = machines + "/${name}/ssh_host_ed25519_key.pub";
      }) hostKeys;
    }

    (mkIf cfg.enable {
      services.openssh = {
        enable = true;
        openFirewall = true;
        ports = [ 22 ];
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          AllowUsers = [ "chris" "root" ];
          UseDns = true;
          UsePAM = true;
          PermitRootLogin = "prohibit-password";
          PermitEmptyPasswords = "no";
        };
      };

      users.users = genAttrs ([ "root" ] ++ attrNames config.snowfallorg.users) (_: {
        openssh.authorizedKeys.keys = cfg.authorizedKeys;
      });
    })
  ];
}
