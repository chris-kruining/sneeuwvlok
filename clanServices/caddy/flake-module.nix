{...}: let
  module = ./default.nix;
in {
  clan.modules.caddy = module;

  # perSystem = {...}: {
  #   clan.nixosTests.caddy = {
  #     imports = [];

  #     clan.modules."@arda/caddy" = module;
  #   };
  # };
}
