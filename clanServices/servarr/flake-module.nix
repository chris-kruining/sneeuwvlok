{...}: let
  module = ./default.nix;
in {
  clan.modules.servarr = module;

  # perSystem = {...}: {
  #   clan.nixosTests.servarr = {
  #     imports = [];

  #     clan.modules."@arda/servarr" = module;
  #   };
  # };
}
