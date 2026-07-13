{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    claims = mkOption {
      type = types.attrsOf (types.submodule {options = {};});
      default = {};
    };

    assigned = mkOption {
      type = types.attrsOf types.port;
      default = {};
    };
  };
}
