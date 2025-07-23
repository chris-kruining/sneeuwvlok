{ lib, config, ... }:let
  inherit (lib) mkForce;
in
{
  modules = {
    system.audio.enable = true;

    desktop.gaming.enable = true;

    root = {
      user = {
        full_name = "__ROOT__";
        email = "__ROOT__@${config.networking.hostName}";
      };

      shell = {
        default = "zsh";
        toolset.git.enable = mkForce false;
      };
    };
  };
}
