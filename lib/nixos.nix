args@{
  inputs,
  lib,
  pkgs,
  self,
  ...
}: let
  inherit (inputs.nixpkgs.lib) nixosSystem;
  inherit (builtins) baseNameOf elem map;
  inherit (lib) filterAttrs attrValues attrNames;
  inherit (lib.modules) mkAliasOptionModule mkDefault mkIf;
  inherit (lib.strings) removeSuffix;
  inherit (self.modules) mapModules mapModulesRec';
  inherit (self) mkSysUser mkHmUser;
in rec
{
  mkHost = path: attrs @ {system ? "x86_64-linux", ...}:
    nixosSystem {
      inherit system;

      specialArgs = {inherit lib inputs system; };

      modules = let
        stateVersion = "23.11";
        users = attrNames (mapModules "${path}/users" (p: p));
      in [
        inputs.nixos-boot.nixosModules.default
        {
          nixpkgs.pkgs = pkgs;
          networking.hostName = mkDefault (removeSuffix ".nix" (baseNameOf path));

          system = {
            inherit stateVersion;
            configurationRevision = with inputs; mkIf (self ? rev) self.rev;
          };

          imports = [
            inputs.home-manager.nixosModules.home-manager
            "${path}/hardware.nix"
          ]
          ++ (mapModulesRec' ../modules/system import);

          users = {
            mutableUsers = true; # Set this to false when I get sops with passwords set up properly
            users = mapModules "${path}/users" mkSysUser;
          };

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            sharedModules = [
              inputs.plasma-manager.homeManagerModules.plasma-manager
            ];

            users = mapModules "${path}/users" (p: mkHmUser p stateVersion);
          };
        }
        (filterAttrs (n: v: !elem n ["system"]) attrs)
        ../. # ../default.nix
        (import path)
      ]
      ++ (map (user: {
        _module.args.user = user;

        imports = []
        ++ (mapModulesRec' ../modules/home (file: file));

        modules.${user} = (import "${path}/users/${user}/default.nix" args);
      }) users);
    };

  mapHosts = dir: attrs @ {system ? system, ...}:
    mapModules dir (hostPath: mkHost hostPath attrs);
}
