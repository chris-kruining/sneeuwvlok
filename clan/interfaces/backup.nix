{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    targets = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          paths = mkOption {
            type = types.listOf types.path;
            default = [];
          };

          excludes = mkOption {
            type = types.listOf types.str;
            default = [];
          };

          preBackup = mkOption {
            type = types.lines;
            default = "";
          };

          postBackup = mkOption {
            type = types.lines;
            default = "";
          };

          repository = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
        };
      }));
      default = {};
    };
  };
}
