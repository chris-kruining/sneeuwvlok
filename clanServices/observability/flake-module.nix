{...}: let
  module = ./default.nix;
in {
  clan.modules.observability = module;
}
