{config, ...}: let
  cfg = config.sneeuwvlok.system.security.sudo;
in {
  options.sneeuwvlok.system.security.sudo = {};

  config = {
    security = {
      sudo = {
        enable = false;
        execWheelOnly = true;
      };

      sudo-rs = {
        enable = true;
        execWheelOnly = true;
        extraConfig = ''Defaults env_keep += "EDITOR PATH DISPLAY"'';
      };
    };
  };
}
