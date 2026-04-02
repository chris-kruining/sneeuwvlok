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
    name = "arda/persistence";
    description = ''
      Configuration of persistence resrouce(s)
      (for now this means a database. and specifically it means postgres)
    '';
    readme = builtins.readFile ./README.md;
    exports = {
      inputs = ["persistence"];
      out = ["persistence"];
    };
  };

  roles.default = {
    description = '''';

    interface = {lib, ...}: let
      inherit (lib) mkOption types;
    in {
      options = {
        port = mkOption {
          type = types.port;
          default = 5432;
        };
      };
    };

    perInstance = {
      mkExports,
      machine,
      settings,
      ...
    }: let
      requested_databases =
        exports
        |> clanLib.selectExports (_scope: true)
        |> lib.mapAttrsToList (_: value: value.persistence.databases or [])
        |> lib.concatLists;
    in {
      exports = mkExports {
        persistence = {
          main = "postgresql";
          driver.postgresql = {
            host = "localhost";
            port = settings.port;
            databases = requested_databases;
          };
        };
      };

      nixosModule = {
        lib,
        pkgs,
        config,
        ...
      }: {
        clan.core.vars.generators.postgresql = let
          password_files =
            requested_databases
            |> lib.map (db: [
              {
                name = "${db}_password";
                value = {
                  secret = true;
                  deploy = false;
                };
              }
            ])
            |> lib.concatLists
            |> lib.listToAttrs;
        in {
          files =
            {
              "server.crt" = {
                secret = true;
                deploy = true;
              };
              "server.key" = {
                secret = true;
                deploy = true;
              };
              ".pgpass" = {
                secret = true;
                deploy = true;

                owner = "postgres";
                group = "postgres";
                mode = "0600";
                restartUnits = ["service.postgresql"];
              };
            }
            // password_files;

          runtimeInputs = with pkgs; [openssl_3_5 pwgen];
          script = ''
            openssl req \
            -new -x509 -days 365 -nodes -text \
            -out $out/server.crt \
            -keyout $out/server.key \
            -subj "/CN=db.${config.networking.fqdn}"

            ${requested_databases
              |> lib.map (db: "pwgen -s 128 1 > $out/${db}_password")
              |> lib.join "\n"}

            cat << EOL > $out/.pgpass
            #host:port:database:user:password
            ${requested_databases
              |> lib.map (db: "*:${toString settings.port}:${db}:${db}:$(cat $out/${db}_password)")
              |> lib.join "\n"}
            EOL
          '';
        };

        systemd.services.postgresql.environment.PGPASSFILE = config.clan.core.vars.generators.postgresql.files.".pgpass".path;

        services = {
          postgresql = {
            enable = true;
            # enableTCPIP = true;

            settings = {
              port = settings.port;
              ssl = true;
            };

            ensureDatabases = requested_databases;
            ensureUsers =
              requested_databases
              |> lib.map (db: {
                name = db;
                ensureDBOwnership = true;
                ensureClauses = {
                  login = true;
                  connection_limit = 5;
                };
              });

            identMap = ''
              #map            sys user    db user
              superuser_map   root        postgres
              superuser_map   postgres    postgres
              superuser_map   /^(.+)$     \1
            '';

            authentication = ''
              # Generated file, do not edit!
              # type    database  user  auth-method   optional_ident_map
                local   sameuser  all   peer          map=superuser_map

              # TYPE    DATABASE  USER  ADDRESS       METHOD
              # local   all       all                 trust
                host    all       all   127.0.0.1/32  scram-sha-256
                host    all       all   ::1/128       scram-sha-256
            '';
          };
        };
      };
    };
  };
}
