{lib, ...}: let
  inherit (lib) mkOption types;
in {
  mkUrlOptions = defaults: {
    host =
      mkOption {
        type = types.str;
        example = "host.tld";
        description = ''
          Hostname
        '';
      }
      // (defaults.host or {});

    port =
      mkOption {
        type = types.port;
        default = 1234;
        example = "1234";
        description = ''
          Port
        '';
      }
      // (defaults.port or {});

    protocol =
      mkOption {
        type = types.str;
        default = "https";
        example = "https";
        description = ''
          Which protocol to use when creating a url string
        '';
      }
      // (defaults.protocol or {});
  };
}
