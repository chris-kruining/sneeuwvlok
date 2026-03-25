{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.sneeuwvlok.shell.toolset.gnupg;
in {
  options.sneeuwvlok.shell.toolset.gnupg = {
    enable = mkEnableOption "cryptographic suite";
  };

  config = mkIf cfg.enable {
    # home.packages = with pkgs; [ gnupg ];

    # home.sessionVariables.GNUPGHOME = "$XDG_CONFIG_HOME/gnupg";

    # programs.gnupg = {
    #   enable = true;

    #   agent = {
    #     enable = true;
    #     enableSSHSupport = true;
    #     pinentryPackage = pkgs.pinentry-gnome3;

    #     settings = let
    #       cacheTTL = 86400;
    #     in {
    #       default-cache-ttl = cacheTTL;
    #       default-cache-ttl-ssh = cacheTTL;
    #       max-cache-ttl = cacheTTL;
    #       max-cache-ttl-ssh = cacheTTL;
    #     };
    #   };
    # };
  };
}
