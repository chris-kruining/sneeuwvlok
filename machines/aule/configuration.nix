{
  pkgs,
  lib,
  self,
  ...
}: {
  _module.args = {
    pkgs = lib.mkForce (import self.inputs.nixpkgs {
      system = "x86_64-linux";

      overlays = with self.inputs; [
      ];

      config = {
        allowUnfree = true;
      };
    });
  };
}
