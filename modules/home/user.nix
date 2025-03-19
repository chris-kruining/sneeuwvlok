{ options, config, lib, pkgs, user, ... }:
let
  inherit (lib.attrsets) attrValues;
  inherit (lib.modules) mkIf mkMerge;

  cfg = config.modules.${user}.user;
in
{
  options.modules.${user}.user = let
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.types) nullOr enum;
  in with lib.types; {
    full_name = mkOption {
        type = nullOr str;
        default = null;
        example = "John Doe";
        description = "Full name of the user, this is used as the kde plasma display name for example";
    };

    is_trusted = mkOption {
        type = bool;
        default = false;
        example = true;
        description = "this is used to grant sudo priviledges for the user";
    };

    groups = mkOption {
        type = listOf str;
        default = [];
        example = [ "some" "group" "names" ];
        description = "groups to add the user to";
    };
  };

  config = {
    users.users.${user} = {
      description = (cfg.full_name or user);
      extraGroups = cfg.groups ++ (if cfg.is_trusted then [ "wheel" ] else []);
    };
  };
}
