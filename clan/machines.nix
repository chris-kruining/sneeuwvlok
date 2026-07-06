{...}: {
  clan.inventory.machines = {
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
}
