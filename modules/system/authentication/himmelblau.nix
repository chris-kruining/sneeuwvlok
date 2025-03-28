{ inputs, lib, pkgs, config, ... }: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.modules.authentication.himmelblau;
in
{
  imports = [ inputs.himmelblau.nixosModules.himmelblau ];

  options.modules.authentication.himmelblau = {
    enable = mkEnableOption "enable azure entra ID authentication";
  };

  config = mkIf cfg.enable {
    services.himmelblau = {
      enable = true;
      settings = {
        domains = [];
        pam_allow_groups = [];
        local_groups = [];
      };
    };
  };
}
