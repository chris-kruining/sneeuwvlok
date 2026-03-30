{
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.sneeuwvlok.services.authentication.himmelblau;
in {
  options.sneeuwvlok.services.authentication.himmelblau = {
    enable = mkEnableOption "enable azure entra ID authentication";
  };

  config = mkIf cfg.enable {
    services.himmelblau = {
      enable = true;
      settings = {
        domain = "";
        pam_allow_groups = [];
        local_groups = [];
      };
    };
  };
}
