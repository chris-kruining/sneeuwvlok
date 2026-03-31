{...}: let
  module = ./default.nix;
in {
  clan.modules.peristance = module;

  # perSystem = {...}: {
  #   clan.nixosTests.peristance = {
  #     imports = [];

  #     clan.modules."@arda/peristance" = module;
  #   };
  # };
}
