{
  meta = {
    name = "arda";
    domain = "arda";
    description = "My personal machines at home";
  };

  directory = ./.;

  exportInterfaces = {
    persistence = import ./interfaces/persistence.nix;
    gateway = import ./interfaces/gateway.nix;
  };

  inventory.machines = {
    aule = {
      name = "aule";
      description = "Planned build server.";
      machineClass = "nixos";
      tags = [];
    };
    mandos = {
      name = "mandos";
      description = "Living room Steam box.";
      machineClass = "nixos";
      tags = [
        "capability:mobility:stationary"
        "operational:availability:wake-on-demand"
      ];
    };
    manwe = {
      name = "manwe";
      description = "Main desktop.";
      machineClass = "nixos";
      tags = [
        "capability:mobility:stationary"
        "operational:availability:manual"
      ];
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
      tags = [
        "capability:mobility:portable"
        "operational:availability:manual"
      ];
    };
    tulkas = {
      name = "tulkas";
      description = "Steam Deck.";
      machineClass = "nixos";
      tags = [
        "capability:mobility:portable"
        "operational:availability:manual"
      ];
    };
    ulmo = {
      name = "ulmo";
      description = "Primary self-hosted services machine.";
      machineClass = "nixos";
      tags = [
        "capability:mobility:stationary"
        "operational:availability:always-on"
        "operational:storage:large"
        "operational:role:gateway"
      ];
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

  inventory.tags = {
    config,
    machines,
    ...
  }: {
    # tag_name = [ "list" "of" "machines" ]
    "capability:hardware:gpu" = [""];
    "capability:hardware:audio" = [""];
    "capability:hardware:bluetooth" = [""];
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

    clanDns = {
      module = {
        name = "dm-dns";
        input = "clan-core";
      };

      roles.default.tags = ["all"];
    };

    gateway = {
      module = {
        name = "gateway";
        input = "self";
      };

      roles.default = {
        tags = ["operational:role:gateway"];

        settings = {
          driver = "caddy";
        };
      };
    };

    identity = {
      module = {
        name = "identity";
        input = "self";
      };

      roles.default = {
        tags = ["operational:availability:always-on"];

        settings = {
        };
      };
    };

    persistence = {
      module = {
        name = "persistence";
        input = "self";
      };

      # TODO :: Convert to use tags instead
      roles.default.tags = ["operational:availability:always-on" "operational:storage:large"];
    };

    servarr = {
      module = {
        name = "servarr";
        input = "self";
      };

      roles.default = {
        tags = ["operational:availability:always-on"];

        settings = {
          enable = true;

          persistence_instance = "persistence";

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
