{
  pkgs,
  config,
  lib,
  namespace,
  inputs,
  system,
  ...
}: let
  inherit (lib) mkOption types;

  cfg = config.${namespace}.services.tofu;

  # A provider is an unpacked release zip (a flake input, linux_amd64),
  # the version is read from the binary's name so the url in flake.nix stays the only place to bump it.
  provider = source: src: let
    binary =
      src
      |> builtins.readDir
      |> lib.attrNames
      |> lib.findFirst (lib.hasPrefix "terraform-provider-") (throw "no provider binary found for ${source}");
  in {
    inherit source src binary;
    name = source |> lib.splitString "/" |> lib.last;
    version = binary |> builtins.match "terraform-provider-[^_]+_v([^_]+).*" |> lib.head;
  };

  # An unpacked filesystem mirror, `tofu init -plugin-dir` installs from it without touching the network
  pluginDir = name: providers:
    providers
    |> lib.map (p: {
      name = "registry.opentofu.org/${p.source}/${p.version}/linux_amd64/${p.binary}";
      path = "${p.src}/${p.binary}";
    })
    |> pkgs.linkFarm "tofu-${name}-plugins";
in {
  options.${namespace}.services.tofu = {
    workspaces = mkOption {
      description = "OpenTofu configurations that are applied by a oneshot unit `tofu-<name>`";
      default = {};
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          description = mkOption {
            type = types.str;
            default = "${name} tofu apply";
          };

          modules = mkOption {
            type = types.listOf types.raw;
            default = [];
            description = "terranix modules that make up the configuration";
          };

          providers = mkOption {
            type = types.attrsOf types.path;
            default = {};
            example = lib.literalExpression ''{ "devopsarr/radarr" = inputs.tofu-provider-radarr; }'';
            description = "Providers the configuration uses, by source address, each one the flake input holding its release zip";
          };

          mode = mkOption {
            type = types.enum ["apply" "plan"];
            default = "apply";
            description = "`plan` only shows what would change, useful while debugging";
          };

          user = mkOption {
            type = types.str;
          };

          group = mkOption {
            type = types.str;
          };

          after = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Units that are pulled in and have to be started before tofu runs";
          };

          waitFor = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "URLs that have to answer with a 2xx before tofu runs";
          };

          varFiles = mkOption {
            type = types.listOf types.str;
            default = [];
          };

          environmentFiles = mkOption {
            type = types.listOf types.str;
            default = [];
          };

          legacyStateFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "State from before this module, adopted when the workspace has none yet";
          };

          attempts = mkOption {
            type = types.ints.positive;
            default = 3;
            description = "How often tofu is tried, to ride out services restarting around it";
          };
        };
      }));
    };
  };

  config = {
    systemd.services =
      cfg.workspaces
      |> lib.mapAttrs' (name: ws: let
        stateFile = "/var/lib/tofu/${name}/terraform.tfstate";
        providers = ws.providers |> lib.mapAttrsToList provider;

        configuration = inputs.terranix.lib.terranixConfiguration {
          inherit system;

          modules =
            ws.modules
            ++ [
              {
                terraform = {
                  backend.local.path = stateFile;

                  required_providers =
                    providers
                    |> lib.map (p: lib.nameValuePair p.name {inherit (p) source version;})
                    |> lib.listToAttrs;
                };
              }
            ];
        };

        tofu = lib.getExe pkgs.opentofu;
        curl = lib.getExe pkgs.curl;
      in
        lib.nameValuePair "tofu-${name}" {
          inherit (ws) description after;

          wantedBy = ["multi-user.target"];
          wants = ws.after;

          environment = {
            TF_IN_AUTOMATION = "1";
            TF_INPUT = "0";
          };

          script = ''
            set -euo pipefail

            echo "config location: ${configuration}"

            ${lib.optionalString (ws.legacyStateFile != null) ''
              if [ ! -e "${stateFile}" ] && [ -e "${ws.legacyStateFile}" ]; then
                echo "adopting state from ${ws.legacyStateFile}"
                cp "${ws.legacyStateFile}" "${stateFile}"
              fi
            ''}

            ${
              ws.waitFor
              |> lib.map (url: ''
                until ${curl} --silent --fail --output /dev/null --max-time 5 "${url}"; do
                  if (( SECONDS > 300 )); then
                    echo "${url} did not become ready"
                    exit 1
                  fi
                  sleep 2
                done
              '')
              |> lib.join "\n"
            }

            # The runtime directory is fresh every run, so nothing of a previous init (lock file, providers) lingers
            cd "$RUNTIME_DIRECTORY"
            cp ${configuration} config.tf.json

            ${tofu} init -no-color -plugin-dir=${pluginDir name providers}

            attempt=1
            until ${tofu} ${ws.mode} -no-color ${lib.optionalString (ws.mode == "apply") "-auto-approve"} ${
              ws.varFiles
              |> lib.map (f: "-var-file=${f}")
              |> lib.join " "
            }; do
              if (( attempt >= ${toString ws.attempts} )); then
                exit 1
              fi

              echo "attempt $attempt failed, retrying in $(( attempt * 15 ))s"
              sleep $(( attempt * 15 ))
              attempt=$(( attempt + 1 ))
            done
          '';

          serviceConfig = {
            Type = "oneshot";
            User = ws.user;
            Group = ws.group;

            StateDirectory = "tofu/${name}";
            StateDirectoryMode = "0700";
            RuntimeDirectory = "tofu/${name}";
            RuntimeDirectoryMode = "0700";

            EnvironmentFile = ws.environmentFiles;
            TimeoutStartSec = "15min";
          };
        });
  };
}
