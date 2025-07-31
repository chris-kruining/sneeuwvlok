{ pkgs, lib, namespace, config, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.nix;
in
{
  options.${namespace}.nix = {
    enable = mkEnableOption "Enable nix command";
  };

  config = mkIf cfg.enable {
    programs.git.enable = true;

    nix = {
      package = pkgs.nixVersions.latest;

      extraOptions = "experimental-features = nix-command flakes";

      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        allowed-users = [ "@wheel" ];
        trusted-users = [ "@wheel" ];

        auto-optimise-store = true;
        connect-timeout = 5;
        http-connections = 50;
        log-lines = 50; # more log lines in case of error
        min-free = 1 * (1024 * 1024 * 1024); # GiB # start garbage collector
        max-free = 50 * (1024 * 1024 * 1024); # GiB # until
        warn-dirty = false;
      };

      gc = {
        automatic = true;
        dates = "monthly";
        options = "--delete-older-than 45d";
      };

      # disable nix-channel, we use flakes instead.
      channel.enable = false;
    };
  };
}
