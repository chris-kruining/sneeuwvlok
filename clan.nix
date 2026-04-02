{
  meta = {
    name = "arda";
    domain = "arda";
    description = "My personal machines at home";
  };

  directory = ./.;

  exportInterfaces = {
    persistence = import ./interfaces/persistence.nix;
    servarr = import ./interfaces/servarr.nix;
  };

  inventory.machines = {
    aule = {
      name = "aule";
      description = "Planned build server.";
      machineClass = "nixos";
      tags = ["planned" "build"];
    };
    mandos = {
      name = "mandos";
      description = "Living room Steam box.";
      machineClass = "nixos";
      tags = ["gaming" "living-room"];
    };
    manwe = {
      name = "manwe";
      description = "Main desktop.";
      machineClass = "nixos";
      tags = ["desktop"];
    };
    melkor = {
      name = "melkor";
      description = "Planned machine with no defined role yet.";
      machineClass = "nixos";
      tags = [];
    };
    orome = {
      name = "orome";
      description = "Work laptop.";
      machineClass = "nixos";
      tags = ["laptop" "work"];
    };
    tulkas = {
      name = "tulkas";
      description = "Steam Deck.";
      machineClass = "nixos";
      tags = ["gaming" "handheld"];
    };
    ulmo = {
      name = "ulmo";
      description = "Primary self-hosted services machine.";
      machineClass = "nixos";
      tags = ["server" "services"];
    };
    varda = {
      name = "varda";
      description = "Planned machine with no defined role yet.";
      machineClass = "nixos";
      tags = [];
    };
    yavanna = {
      name = "yavanna";
      description = "Planned machine with no defined role yet.";
      machineClass = "nixos";
      tags = [];
    };
  };

  inventory.instances = {
    users-chris = {
      module = {
        name = "users";
        input = "clan-core";
      };

      roles.default.machines.mandos.settings = {};
      roles.default.machines.manwe.settings = {};
      roles.default.machines.orome.settings = {};
      roles.default.machines.tulkas.settings = {};

      roles.default.settings = {
        user = "chris";
        groups = ["wheel"];
        prompt = true;
        share = true;
      };
    };

    persistence = {
      module = {
        name = "persistence";
        input = "self";
      };

      # TODO :: Convert to use tags instead
      roles.default.machines.ulmo.settings = {};
    };

    servarr = {
      module = {
        name = "servarr";
        input = "self";
      };

      # TODO :: Convert to use tags instead
      roles.default = {
        machines.ulmo.settings = {};

        settings = {
          enable = true;
          services = {
            sonarr = {
              rootFolders = [
                "/var/media/series"
              ];
            };
            radarr = {
              rootFolders = [
                "/var/media/movies"
              ];
            };
            lidarr = {
              rootFolders = [
                "/var/media/music"
              ];
            };
            prowlarr = {};
          };
        };
      };
    };
  };
}
