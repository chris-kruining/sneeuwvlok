{lib, ...}: let
  inherit (lib) mkOption types;
in {
  imports = [
    ../../../clan/interfaces/gateway.nix
  ];

  options = {
    driver = mkOption {
      type = types.enum ["caddy"];
      default = "caddy";
    };

    hosts = mkOption {
      type = types.attrsOf types.lines;
      default = {};
    };
  };
}
