{lib, ...}: let
  inherit (lib) mkOption mkEnableOption types;
in {
  options = {
    enable = mkEnableOption "Enable configured *arr services";

    database = mkOption {
      type = types.anything; #ardaLib.types.endpoint;
    };

    services = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          enable = mkEnableOption "Enable ${name}" // {default = true;};
          debug = mkEnableOption "Use tofu plan instead of tofu apply for ${name} ";

          rootFolders = mkOption {
            type = types.listOf types.str;
            default = [];
          };
        };
      }));
      default = {};
      description = ''
        Settings foreach *arr service
      '';
    };
  };
}
