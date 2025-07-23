{ config, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf;

  cfg = config.modules.${user}.shell.toolset.gnupg;
in
{
  options.modules.${user}.shell.toolset.gnupg = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "cryptographic suite";
  };

  config = mkIf cfg.enable {
    user.package = with pkgs; [ gnupg ];

    environment.variables.GNUPGHOME = "$XDG_CONFIG_HOME/gnupg";

    home-manager.users.${user}.programs.gnupg = {
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
