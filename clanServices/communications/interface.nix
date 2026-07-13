{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  options = {
    driver = mkOption {
      type = types.enum ["matrix"];
      default = "matrix";
    };

    matrix = mkOption {
      type = types.submodule {
        options = {
          domain = mkOption {
            type = types.str;
          };

          serverDomain = mkOption {
            type = types.str;
          };

          extraWellKnownDomains = mkOption {
            type = types.listOf types.str;
            default = [];
          };

          port = mkOption {
            type = types.port;
            default = 4001;
          };

          database = mkOption {
            type = types.str;
            default = "synapse";
          };

          adminUsers = mkOption {
            type = types.listOf types.str;
            default = [];
          };

          bridges = mkOption {
            type = types.attrsOf (types.submodule {
              options.enable = mkEnableOption "Matrix bridge" // {default = true;};
            });
            default = {};
          };

          livekit = mkOption {
            type = types.submodule {
              options = {
                enable = mkEnableOption "LiveKit Matrix calling";
                keyFile = mkOption {
                  type = types.path;
                  default = "/var/lib/element-call/key";
                };
                port = mkOption {
                  type = types.port;
                  default = 4002;
                };
                jwtPort = mkOption {
                  type = types.port;
                  default = 4003;
                };
              };
            };
            default = {};
          };

          turn = mkOption {
            type = types.submodule {
              options = {
                enable = mkEnableOption "TURN service";
                realm = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
                secretFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                };
                port = mkOption {
                  type = types.port;
                  default = 4004;
                };
              };
            };
            default = {};
          };
        };
      };
    };

    identity = mkOption {
      type = types.submoduleWith {
        modules = [../../clan/interfaces/identity.nix];
      };
      default = {};
    };
  };
}
