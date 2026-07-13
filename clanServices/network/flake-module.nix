{
  lib,
  self,
  ...
}: let
  module = lib.modules.importApply ./default.nix {inherit self;};
in {
  clan.modules.network = module;
}
