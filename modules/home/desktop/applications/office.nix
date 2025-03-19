{ options, config, lib, pkgs, user, ... }:
let
  inherit (lib.modules) mkIf mkForce mkMerge;
  inherit (lib.attrsets) attrValues;

  cfg = config.modules.${user}.desktop.applications.office;
in
{
  options.modules.${user}.desktop.applications.office = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Enable office suite (only-office)";
  };

  config = mkIf cfg.enable
  {
    home-manager.users.${user}.home.packages = attrValues {
      inherit (pkgs) onlyoffice-bin;
    };

#     nixpkgs.config.allowUnfreePredicate = pkg:
#       builtins.elem (lib.getName pkg) [ "corefonts" ];

    fonts.packages = with pkgs; [
      corefonts
    ];
  };
}
