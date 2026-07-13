{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    name = mkOption {
      type = types.str;
      default = "zitadel";
    };

    origin = mkOption {
      type = types.str;
    };
  };
}
