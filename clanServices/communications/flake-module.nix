{...}: let
  module = ./default.nix;
in {
  clan.modules.communications = module;
}
