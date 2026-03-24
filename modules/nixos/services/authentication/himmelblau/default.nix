{
  lib,
  config,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.services.authentication.himmelblau;
in {
  options.${namespace}.services.authentication.himmelblau = {
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
