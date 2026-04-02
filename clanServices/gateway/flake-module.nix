{...}: let
  module = ./default.nix;
in {
  clan.modules.gateway = module;

  # perSystem = {...}: {
  #   clan.nixosTests.gateway = {
  #     imports = [];

  #     clan.modules."@arda/gateway" = module;
  #   };
  # };
}
