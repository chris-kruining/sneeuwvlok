{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    driver = mkOption {
      type = types.enum ["jellyfin"];
      default = "jellyfin";
    };

    mediaPath = mkOption {
      type = types.path;
    };

    identity = mkOption {
      type = types.submoduleWith {
        modules = [../../clan/interfaces/identity.nix];
      };
      default = {};
    };
  };
}
