{ config, lib, pkgs, user, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.shell.toolset.gnupg;
in
{
  options.${namespace}.shell.toolset.gnupg = {
    enable = mkEnableOption "cryptographic suite";
  };

  config = mkIf cfg.enable {
    user.package = with pkgs; [ gnupg ];

    environment.variables.GNUPGHOME = "$XDG_CONFIG_HOME/gnupg";

    programs.gnupg = {
      enable = true;

      agent = {
        enable = true;
        enableSSHSupport = true;
        pinentryPackage = pkgs.pinentry-gnome3;

        settings = let
          cacheTTL = 86400;
        in {
          default-cache-ttl = cacheTTL;
          default-cache-ttl-ssh = cacheTTL;
          max-cache-ttl = cacheTTL;
          max-cache-ttl-ssh = cacheTTL;
        };
      };
    };
  };
}
