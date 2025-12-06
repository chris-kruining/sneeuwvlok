{
  inputs,
  lib,
  config,
  namespace,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.services.authentication.himmelblau;
in {
  imports = [inputs.himmelblau.nixosModules.himmelblau];

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
