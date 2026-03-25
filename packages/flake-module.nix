{inputs, ...}: {
  imports = [];

  perSystem = {
    system,
    pkgs,
    ...
  }: {
    packages = {
      studio = pkgs.callPackage ./studio {erosanix = inputs.erosanix.lib.${system};};
      vaultwarden = pkgs.callPackage ./vaultwarden {};
    };
  };
}
