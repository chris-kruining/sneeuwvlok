args@{ self, inputs, lib, pkgs, system ? "", config, options, ... }: let
  inherit (lib.my) mapModulesRec';
in
{
  imports = [
    # (import ../modules/home/shell/default.nix (args // { user = "root"; }))
  ]
  ++(mapModulesRec' ../modules/home (file: (import file (args // { user = "root"; }))));

  config = {
    modules.root = {
      user = {
        full_name = "__ROOT__";
        email = "__ROOT__@${config.networking.hostName}";
      };

      shell = {
        default = "zsh";
      };
    };
  };
}
