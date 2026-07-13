{lib, ...}: let
  inherit (lib) mkOption types;
in {
  imports = [
    ../../clan/interfaces/backup.nix
  ];

  options = {
    driver = mkOption {
      type = types.enum ["borg"];
      default = "borg";
    };

    borg = mkOption {
      type = types.submodule {
        options = {
          repositories = mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                repo = mkOption {
                  type = types.str;
                };

                startAt = mkOption {
                  type = types.str;
                  default = "daily";
                };

                compression = mkOption {
                  type = types.str;
                  default = "auto,zstd";
                };

                encryptionMode = mkOption {
                  type = types.str;
                  default = "repokey-blake2";
                };

                environment = mkOption {
                  type = types.attrsOf types.str;
                  default = {};
                };

                sshConfig = mkOption {
                  type = types.lines;
                  default = "";
                };
              };
            });
            default = {};
          };
        };
      };
      default = {};
    };
  };
}
