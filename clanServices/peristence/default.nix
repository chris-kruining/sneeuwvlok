{...}: {
  _class = "clan.service";
  manifest = {
    name = "arda/persistence";
    description = ''
      Configuration of persistence resrouce(s)
      (for now this means a database. and specifically it means postgres)
    '';
    readme = builtins.readFile ./README.md;
    exports.out = ["persistence"];
  };

  roles.default = {
    description = '''';

    interface = {...}: {
      options = {};
    };

    perInstance = {mkExports, ...}: {
      exports = mkExports {
        persistence = {
          main = "postgresql";
          database.postgresql = {
            host = "";
            port = 5432;
          };
        };
      };

      nixosModule = {...}: {
      };
    };
  };
}
