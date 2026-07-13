{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  options = {
    driver = mkOption {
      type = types.enum ["forgejo"];
      default = "forgejo";
    };

    forgejo = mkOption {
      type = types.submodule {
        options = {
          domain = mkOption {
            type = types.str;
          };

          appName = mkOption {
            type = types.str;
            default = "Forgejo";
          };

          appSlogan = mkOption {
            type = types.str;
            default = "";
          };

          allowedCorsDomains = mkOption {
            type = types.listOf types.str;
            default = [];
          };

          mailer = mkOption {
            type = types.submodule {
              options = {
                enable = mkEnableOption "Forgejo mailer";
                smtpAddress = mkOption {
                  type = types.str;
                  default = "localhost";
                };
                smtpPort = mkOption {
                  type = types.port;
                  default = 587;
                };
                from = mkOption {
                  type = types.str;
                  default = "";
                };
                user = mkOption {
                  type = types.str;
                  default = "";
                };
                passwordFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                };
              };
            };
            default = {};
          };

          runner = mkOption {
            type = types.submodule {
              options = {
                enable = mkEnableOption "Forgejo actions runner";
                tokenFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                };
                labels = mkOption {
                  type = types.listOf types.str;
                  default = [];
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
