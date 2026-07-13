{...}: let
  module = ./default.nix;
in {
  clan.modules.identity = module;

  # perSystem = {...}: {
  #   clan.nixosTests.identity = {
  #     imports = [];

  #     clan.modules.identity = module;
  #   };
  # };
}
