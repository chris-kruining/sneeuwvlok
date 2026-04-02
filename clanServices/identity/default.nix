{
  lib,
  clanLib,
  exports,
  ...
}: let
  inherit (builtins) toString;
in {
  _class = "clan.service";
  manifest = {
    name = "arda/identity";
    description = ''
    '';
    readme = builtins.readFile ./README.md;
    exports = {
      inputs = ["persistence"];
      out = ["gateway"];
    };
  };

  roles.default = {
    description = '''';

    interface = {lib, ...}: let
      inherit (lib) mkOption types;
    in {
      options = {
        driver = mkOption {
          type = types.enum ["zitadel"];
          default = "zitadel";
        };

        port = mkOption {
          type = types.port;
          default = 9092;
        };
      };
    };

    perInstance = {
      mkExports,
      settings,
      ...
    }: let
      database =
        exports
        |> clanLib.getExport {
          serviceName = "arda/persistence";
          roleName = "default";
          machineName = machine.name;
          instanceName = settings.persistence_instance;
        }
        |> (v: v.persistence.driver.postgresql);
    in {
      exports = mkExports {
        gateway.services.identity = {port = settings.port;};
      };

      nixosModule = {
        lib,
        pkgs,
        config,
        ...
      }: let
        inherit (lib) mkMerge mkIf;
      in {
        config = mkMerge [
          (lib.mkIf (settings.driver == "zitadel") {
            clan.core.vars.generators.zitadel = {
              dependencies = ["persistence"];

              files = {
                masterKey = {
                  deploy = true;
                  owner = "zitadel";
                  group = "zitadel";
                  restartUnits = ["zitadel.service"];
                };

                settings = {
                  deploy = true;
                  owner = "zitadel";
                  group = "zitadel";
                  restartUnits = ["zitadel.service"];
                };
              };

              runtimeInputs = with pkgs; [pwgen];
              script = ''
                pwgen -s 32 1 > $out/masterKey

                cat << EOL > $out/settings
                Database:
                  postgres:
                    User:
                      Password: $(cat $in/persistence/zitadel_password)
                    Admin:
                      Password: $(cat $in/persistence/zitadel_password)
                EOL
              '';
            };

            environment.systemPackages = with pkgs; [
              zitadel
            ];

            services.zitadel = {
              enable = true;
              masterKeyFile = config.clan.core.vars.generators.zitadel.files.masterKey.path;

              tlsMode = "external";

              extraSettingsPaths = [
                config.clan.core.vars.generators.zitadel.files.settings.path
              ];

              settings = {
                Port = settings.port;

                Database.postgres = {
                  Host = database.host;
                  Port = database.port;
                  Databae = "zitadel";
                  User = {
                    Username = "zitadel";
                  };
                  Admin = {
                    Username = "zitadel";
                  };
                };
              };
            };
          })
        ];
      };
    };
  };
}
