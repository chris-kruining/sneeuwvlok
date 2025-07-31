{ config, namespace, ... }:
let
  cfg = config.${namespace}.system.security.sudo;
in
{
  options.${namespace}.system.security.sudo = {};

  config = {
    security = {
      sudo = {
        enable = false;
        execWheelOnly = true;
      };
      
      sudo-rs = {
        enable = true;
        extraConfig = ''
          Defaults env_keep += "EDITOR PATH DISPLAY"
        '';
      };
    };
  };
}