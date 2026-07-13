{...}: let
  module = ./default.nix;
in {
  clan.modules.network = module;
}
