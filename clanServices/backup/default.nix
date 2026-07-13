{lib, ...}: {
  _class = "clan.service";
  manifest = {
    name = "backup";
    description = "Foundational backup service";
    categories = ["Service" "Backup"];
    readme = builtins.readFile ./README.md;
    exports = {
      inputs = ["backup"];
      out = ["backup"];
    };
  };

  roles.default = {
    description = "Borg backup service";
    interface = import ./interface.nix;

    perInstance = {
      settings,
      ...
    }: {
      nixosModule = {lib, ...}: let
        targetJobs =
          settings.targets
          |> lib.mapAttrs (name: target: let
            repository =
              if target.repository != null
              then settings.borg.repositories.${target.repository}
              else settings.borg.repositories.${name};
          in {
            paths = target.paths;
            exclude = target.excludes;
            repo = repository.repo;
            compression = repository.compression;
            startAt = repository.startAt;
            environment = repository.environment;
            encryption.mode = repository.encryptionMode;
            preHook = target.preBackup;
            postHook = target.postBackup;
          });
      in {
        config = lib.mkIf (settings.driver == "borg") {
          programs.ssh.extraConfig =
            settings.borg.repositories
            |> lib.mapAttrsToList (_: repository: repository.sshConfig)
            |> lib.concatStringsSep "\n";

          services.borgbackup.jobs = targetJobs;
        };
      };
    };
  };
}
