{...}: {
  _class = "clan.service";
  manifest = {
    name = "arda/persistance";
    description = ''
      Configuration of persistance resrouce(s)
      (for now this means a database. and specifically it means postgres)
    '';
    categories = [ "Service", "Peristance" ];
    readme = builtins.readFile ./README.md
  };

  roles.default = {
    description = '''';

    interface = {...}: {
      options = {};
    };

    perInstance = {...}: {
      nixosModule = {...}: {};
    };
  };
}
