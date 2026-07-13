{
  clanLib,
  lib,
  self,
  ...
}: {
  _file = ./default.nix;
  _class = "clan.service";
  manifest = {
    name = "network";
    description = "Machine-local endpoint allocation and public ingress";
    categories = ["Service" "Network"];
    readme = builtins.readFile ./README.md;
    exports = {
      inputs = ["ports"];
      out = ["ports"];
    };
  };

  # Keep allocation and ingress in separate role files; gateway exports must not feed allocation.
  roles.default = import ./roles/default.nix {inherit clanLib lib;};
  roles.gateway = import ./roles/gateway.nix {inherit lib self;};
}
