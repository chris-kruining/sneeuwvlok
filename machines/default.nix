{baseNixosModules, lib, sharedContext, ...}: {
  clan =
    (import ../clan.nix {
      inherit baseNixosModules lib;
    })
    // {
      specialArgs = sharedContext;
    };
}
