{...}: let
  module = ./default.nix;
in {
  clan.modules.backup = module;
}
