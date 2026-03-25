{
  meta = {
    name = "arda";
    domain = "arda";
    description = "My personal machines at home";
  };

  directory = ./.;

  inventory.machines = {
    # aule = {
    #   name = "aule";
    #   description = "Planned build server.";
    #   machineClass = "nixos";
    #   tags = ["planned" "build"];
    # };
    # mandos = {
    #   name = "mandos";
    #   description = "Living room Steam box.";
    #   machineClass = "nixos";
    #   tags = ["gaming" "living-room"];
    # };
    # manwe = {
    #   name = "manwe";
    #   description = "Main desktop.";
    #   machineClass = "nixos";
    #   tags = ["desktop"];
    # };
    # melkor = {
    #   name = "melkor";
    #   description = "Planned machine with no defined role yet.";
    #   machineClass = "nixos";
    #   tags = [];
    # };
    # orome = {
    #   name = "orome";
    #   description = "Work laptop.";
    #   machineClass = "nixos";
    #   tags = ["laptop" "work"];
    # };
    # tulkas = {
    #   name = "tulkas";
    #   description = "Steam Deck.";
    #   machineClass = "nixos";
    #   tags = ["gaming" "handheld"];
    # };
    ulmo = {
      name = "ulmo";
      description = "Primary self-hosted services machine.";
      machineClass = "nixos";
      tags = ["server" "services"];
    };
    # varda = {
    #   name = "varda";
    #   description = "Planned machine with no defined role yet.";
    #   machineClass = "nixos";
    #   tags = [];
    # };
    # yavanna = {
    #   name = "yavanna";
    #   description = "Planned machine with no defined role yet.";
    #   machineClass = "nixos";
    #   tags = [];
    # };
  };

  inventory.instances = {
    user-chris = {
      module.name = "users";
      module.input = "clan-core";

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
  };

  machines = {
    # mandos = {};
    # manwe = {};
    # orome = {};
    # tulkas = {};
    ulmo = {};
  };
}
