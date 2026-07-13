{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    driver = mkOption {
      type = types.nullOr (types.enum ["postgresql"]);
      default = null;
    };

    endpoints = mkOption {
      type = types.attrsOf (types.submoduleWith {
        modules = [
          ../types/endpoint.nix
        ];
      });
      default = {};
    };

    databases = mkOption {
      type = types.listOf types.str;
      default = [];
    };
  };
}
