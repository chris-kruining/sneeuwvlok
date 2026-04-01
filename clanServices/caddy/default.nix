{...}: {
  _class = "clan.service";
  manifest = {
    name = "arda/caddy";
    description = ''
      Configuration of reverse proxy.
    '';
    categories = [ "Service", "Media" ];
    readme = builtins.readFile ./README.md;
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
