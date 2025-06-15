{ inputs, lib, pkgs, self, ... }: let
  inherit (inputs.nixpkgs.lib) nixosSystem;
  inherit (builtins) baseNameOf elem map listToAttrs pathExists;
  inherit (lib) filterAttrs nameValuePair attrNames;
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.strings) removeSuffix;
  inherit (self.modules) mapModules mapModulesRec';
  inherit (self) mkSysUser;
in rec
{
  mkHost = path: attrs @ {system ? "x86_64-linux", ...}:
    nixosSystem {
      inherit system;

      specialArgs = {inherit lib inputs system; };

      modules = let
        stateVersion = "23.11";
        users = if (pathExists "${path}/users") then attrNames (mapModules "${path}/users" (p: p)) else [];
      in [
        inputs.nixos-boot.nixosModules.default
        ({ ... }: {
          nixpkgs.pkgs = pkgs;

          networking.hostName = mkDefault (removeSuffix ".nix" (baseNameOf path));

          system = {
            inherit stateVersion;
            configurationRevision = mkIf (self ? rev) self.rev;
          };

          imports = [
            inputs.home-manager.nixosModules.home-manager
            "${path}/hardware.nix"
          ]
          ++ (mapModulesRec' ../modules/system import);

          users = {
            mutableUsers = true; # Set this to false when I get sops with passwords set up properly
            users = mkIf (pathExists "${path}/users") (mapModules "${path}/users" mkSysUser);
          };
        })
        (filterAttrs (n: v: !elem n ["system"]) attrs)
        (import path)
        (args@{ inputs, lib, pkgs, config, options, ... }: {
          imports = mapModulesRec' ../modules/home (file: (import file (args // { user = "root"; })));
        })
        ({...}: {
          imports = [];

          config = {
            home-manager = {
              backupFileExtension = "bak";
              useGlobalPkgs = true;
              sharedModules = [
                inputs.plasma-manager.homeManagerModules.plasma-manager
              ];

              users = listToAttrs (map (user: (nameValuePair user { home = { inherit stateVersion; }; })) (users ++ ["root"]));
            };
          };
        })
      ]
      ++ (map (user: (args@{ inputs, lib, pkgs, config, options, ... }: {
        imports = mapModulesRec' ../modules/home (file: (import file (args // { inherit user; })));

        config.modules.${user} = (import "${path}/users/${user}/default.nix" args);
      })) users);
    };

  mapHosts = dir: attrs @ {system ? system, ...}:
    mapModules dir (hostPath: mkHost hostPath attrs);
}
