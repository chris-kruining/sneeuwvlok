{ pkgs, lib, namespace, config, ... }:
let
  cfg = config.${namespace}.nix;
in
{
  options.${namespace}.nix = {};

  config = {
    programs.git.enable = true;

    nix = {
      package = pkgs.nixVersions.latest;

      extraOptions = "experimental-features = nix-command flakes pipe-operators";

      settings = {
        experimental-features = [ "nix-command" "flakes" "pipe-operators" ];
        allowed-users = [ "@wheel" ];
        trusted-users = [ "@wheel" ];

        auto-optimise-store = true;
        connect-timeout = 5;
        http-connections = 50;
        log-lines = 50; # more log lines in case of error
        min-free = 1 * (1024 * 1024 * 1024); # GiB # start garbage collector
        max-free = 50 * (1024 * 1024 * 1024); # GiB # until
        warn-dirty = false;
      } // lib.optionalAttrs (!config.${namespace}.services.development.nix-cache.enable) {
        # The cache on ulmo, built every night from this flake
        substituters = [ "http://ulmo:5000" ];
        trusted-public-keys = [ "sneeuwvlok-cache-1:sVizUQcjQ5rygvbX7u8Z324aonsWp4J++db2U55ohvw=" ];
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
