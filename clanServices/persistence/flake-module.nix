{...}: let
  module = ./default.nix;
in {
  clan.modules.persistence = module;

  # perSystem = {...}: {
  #   clan.nixosTests.persistence = {
  #     imports = [];

  #     clan.modules.persistence = module;
  #   };
  # };
}
