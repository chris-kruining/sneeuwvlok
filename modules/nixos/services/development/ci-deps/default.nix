{
  config,
  lib,
  pkgs,
  namespace,
  inputs,
  system,
  ...
}: let
  inherit (lib) mkIf mkMerge mkEnableOption mkOption types getExe escapeShellArgs mapAttrs' mapAttrsToList nameValuePair concatStringsSep attrValues;

  cfg = config.${namespace}.services.development.ci-deps;
  repos = attrValues cfg.repositories;

  state = "/var/lib/ci-deps";
  # Served as is: the status of every build, which jobs wait on
  www = "${state}/www";
  queue = "${state}/queue";
  # Per repository: `deps/<sha>` out links of its builds and `image/<id>` of the runner image's closure, the gc roots
  # of its store
  roots = "${state}/roots";
  # The sockets of the daemons, only root (podman) may reach them: they are bind mounted into the jobs of their
  # repository only
  run = "/run/ci-deps";
  repositories = "${config.services.forgejo.stateDir}/repositories";
  nix = config.nix.package;

  # The daemon does the writing, but the client reads what is in the store itself (sources, evaluated files) from
  # its real location, outside the chroot
  storeOfSh = ''"unix://${run}/$name.socket?root=/var/lib/private/ci-deps-store/$name"'';
  # Given as NIX_REMOTE, not `--store`: nix sends a `--store` along to the daemon as a setting of the client's, which
  # the daemon (root is trusted) then hands to its build hook, and that can't reach this socket as the daemon's user
  # Opening a store as root makes it the host's build users' (`build-users-group`), after which the daemon's user
  # can't write it anymore. Its builds run in the daemon, the clients don't need them
  clientEnv.NIX_CONFIG = "build-users-group =";

  # The key the stores' daemons log in on the builder with, decoded from its secret (base64, see script/ci_deps) into
  # each daemon's runtime directory. Relative to it, the builders setting is the same for all of them
  builderKey = name: "/run/ci-deps-store/${name}/builder_key";

  # A remote builder for the stores' daemons, see the `builder` option. Its host key comes from the repo (known_hosts
  # in NIX_SSHOPTS), so nothing is trusted on first use
  builders = name: let
    b = cfg.builder;
  in "ssh-ng://nix-ssh@${b.host} ${pkgs.stdenv.hostPlatform.system} ${builderKey name} ${toString b.maxJobs} ${toString b.speedFactor} ${concatStringsSep "," b.supportedFeatures}";

  builderKnownHosts = pkgs.writeText "ci-deps-builder-known-hosts" ''
    ${cfg.builder.host} ${builtins.readFile (inputs.self + "/systems/${system}/${cfg.builder.host}/ssh_host_ed25519_key.pub")}
  '';

  # Wakes the builder and waits a moment for it, the daemons fall back to building here when it doesn't come
  wakeBuilder = pkgs.writeShellApplication {
    name = "ci-deps-wake-builder";
    runtimeInputs = [pkgs.wakeonlan pkgs.netcat-openbsd pkgs.coreutils];
    text = ''
      nc -z -w 2 ${cfg.builder.host} 22 && exit 0

      echo "waking ${cfg.builder.host} to build on"
      wakeonlan -i ${lib.escapeShellArg cfg.builder.broadcastAddress} ${lib.escapeShellArg cfg.builder.macAddress}

      for _ in $(seq ${toString (cfg.builder.wakeTimeout / 5)}); do
        nc -z -w 2 ${cfg.builder.host} 22 && exit 0
        sleep 5
      done

      echo "${cfg.builder.host} didn't wake up, building here" >&2
    '';
  };

  # repository -> name of its store, for the scripts
  names = ''
    declare -A names=(${concatStringsSep " " (map (r: ''["${r.repository}"]="${r.name}"'') repos)})
  '';

  # What forgejo's push webhook runs: only queues the build, the builder does the work
  enqueue = pkgs.writeShellApplication {
    name = "ci-deps-enqueue";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      repo=$1 sha=$2

      # Both end up in paths, only what git and forgejo can name them is allowed through
      [[ $repo =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ && $repo != *..* ]] || exit 0
      [[ $sha =~ ^[0-9a-f]{40}$ && $sha != 0000000000000000000000000000000000000000 ]] || exit 0

      mkdir -p "${www}/status/$repo"
      echo queued > "${www}/status/$repo/$sha"
      echo "$repo $sha" > "${queue}/''${repo//\//_}_$sha"
    '';
  };

  # Drops the roots of a store beyond the last `keep`, but none younger than `keepFor` (a job may still use them),
  # then collects what nothing refers to anymore
  gc = pkgs.writeShellApplication {
    name = "ci-deps-gc";
    runtimeInputs = [nix pkgs.coreutils pkgs.findutils];
    text = ''
      shopt -s nullglob
      cutoff=$(( $(date +%s) - ${toString cfg.keepFor} * 3600 ))

      for dir in ${roots}/*/; do
        name=$(basename "$dir")
        [ -S "${run}/$name.socket" ] || continue

        pruned=0
        for kind in deps image; do
          while read -r time old; do
            if [ "''${time%.*}" -lt "$cutoff" ]; then
              rm -v "$old"
              pruned=1
            fi
          done < <(find "$dir$kind" -mindepth 1 -maxdepth 1 -type l -printf '%T@ %p\n' 2>/dev/null | sort -rn | tail -n +${toString (cfg.keep + 1)})
        done

        if [ "$pruned" = 1 ]; then
          NIX_REMOTE=${storeOfSh} nix store gc
        fi
      done
    '';
  };

  # Puts the runner image's closure into every store, as a root of its own. The image's store is hidden in the job by
  # the repository's, so the tools of the image have to be in that one
  image = pkgs.writeShellApplication {
    name = "ci-deps-image";
    runtimeInputs = [nix config.virtualisation.podman.package pkgs.coreutils];
    text = ''
      ${names}

      # Without the registry the image that is there already still goes into new stores
      podman pull --quiet ${cfg.image} > /dev/null || echo "pulling ${cfg.image} failed, using what is there" >&2
      id=$(podman image inspect --format '{{.Id}}' ${cfg.image})
      root=$(podman image inspect --format '{{index .Labels "nix.root"}}' ${cfg.image})
      if [ -z "$root" ]; then
        echo "${cfg.image} has no nix.root label, its closure can't be put in the stores" >&2
        exit 1
      fi

      mnt=$(podman image mount ${cfg.image})
      trap 'podman image unmount ${cfg.image} > /dev/null' EXIT

      for name in "''${names[@]}"; do
        [ -L "${roots}/$name/image/$id" ] && continue
        echo "copying the closure of $id into $name"
        mkdir -p "${roots}/$name/image"
        nix copy --extra-experimental-features read-only-local-store --no-check-sigs \
          --from "local?root=$mnt&read-only=true" --to ${storeOfSh} "$root"
        NIX_REMOTE=${storeOfSh} nix build "$root" --out-link "${roots}/$name/image/$id"
      done

      # Only now the runners get the new image: they run what this tag points at and never pull themselves
      podman tag "$id" ${cfg.localImage}
    '';
  };

  build = pkgs.writeShellApplication {
    name = "ci-deps-build";
    runtimeInputs = [nix pkgs.git pkgs.coreutils pkgs.gnutar];
    text = ''
      shopt -s nullglob
      ${names}

      system=${pkgs.stdenv.hostPlatform.system}

      status() { echo "$3" > "${www}/status/$1/$2"; }

      rm -rf ${state}/src.*

      # The queue file goes only once the build is over, so a build that is stopped halfway (a deploy, a
      # reboot) starts again instead of leaving its status at building forever
      while queued=(${queue}/*) && [ ''${#queued[@]} -gt 0 ]; do
        item=''${queued[0]}
        read -r repo sha < "$item"

        # Only the repositories with a store of their own are built, see the option
        name=''${names[$repo]-}
        if [ -z "$name" ]; then
          status "$repo" "$sha" "none"
          rm -f "$item"
          continue
        fi
        # Builds go through the daemon of the repository's store, so the build runs as its user and in its sandbox
        export NIX_REMOTE=${storeOfSh}

        src=$(mktemp -d ${state}/src.XXXXXX)
        git -c safe.directory='*' -C "${repositories}/$repo.git" archive "$sha" | tar -x -C "$src"

        # Repositories that have no `deps` package (anymore) have nothing to build
        if ! nix eval --raw "path:$src#packages.$system.deps.outPath" > /dev/null 2>&1; then
          status "$repo" "$sha" "none"
          rm -rf "$src" "$item"
          continue
        fi

        status "$repo" "$sha" building
        mkdir -p "${roots}/$name/deps"
        ${lib.optionalString cfg.builder.enable (getExe wakeBuilder)}
        echo "building $repo at $sha"

        # The out link is a gc root of the store, which keeps the build for the next push that does not change it
        if nix build --max-jobs 1 "path:$src#packages.$system.deps" --out-link "${roots}/$name/deps/$sha"; then
          status "$repo" "$sha" "done"
        else
          status "$repo" "$sha" failed
        fi

        rm -rf "$src" "$item"
      done
    '';
  };
in {
  options.${namespace}.services.development.ci-deps = {
    enable = mkEnableOption "building the dependencies of a repository's pipelines as soon as a commit is pushed, into a nix store of its own that its jobs use";

    repositories = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          repository = mkOption {
            type = types.str;
            default = name;
            readOnly = true;
            internal = true;
          };

          name = mkOption {
            type = types.strMatching "[A-Za-z0-9_.-]+";
            default = lib.replaceStrings ["/"] ["_"] name;
            description = ''
              The name of the repository's store, its daemon and its runner
            '';
          };

          capacity = mkOption {
            type = types.ints.positive;
            default = 3;
            description = ''
              How many jobs of the repository run at the same time, on its own runner
            '';
          };

          store = mkOption {
            type = types.str;
            default = "/var/lib/private/ci-deps-store/${lib.replaceStrings ["/"] ["_"] name}";
            readOnly = true;
            description = ''
              The root of the repository's store, its jobs get `<store>/nix/store` at /nix/store
            '';
          };

          socket = mkOption {
            type = types.str;
            default = "${run}/${lib.replaceStrings ["/"] ["_"] name}.socket";
            readOnly = true;
            description = ''
              The socket of the store's nix daemon, its jobs get it at /nix/var/nix/daemon-socket/socket
            '';
          };
        };
      }));
      default = {};
      example = {"chris/brickforge" = {};};
      description = ''
        The repositories (`owner/name`) whose `packages.<system>.deps` is built on every push, each into a store of
        its own that a runner of its own mounts into its jobs (see the forgejo module), the `nix` label
      '';
    };

    image = mkOption {
      type = types.str;
      default = "git.amarth.cloud/amarth/runners/default:latest";
      description = ''
        The image the repositories' runners run their jobs in, its closure (label nix.root) is put in every store
      '';
    };

    localImage = mkOption {
      type = types.str;
      default = "localhost/ci-deps-runner:latest";
      readOnly = true;
      description = ''
        The tag the repositories' runners use, moved to a newer `image` once its closure is in every store
      '';
    };

    port = mkOption {
      type = types.port;
      default = 5001;
      description = ''
        The port the build status is served on
      '';
    };

    webhookPort = mkOption {
      type = types.port;
      default = 9100;
      description = ''
        The port on localhost forgejo's push webhook goes to
      '';
    };

    keep = mkOption {
      type = types.ints.positive;
      default = 3;
      description = ''
        How many builds (and runner images) of every repository to keep in its store at least
      '';
    };

    keepFor = mkOption {
      type = types.ints.positive;
      default = 6;
      description = ''
        How many hours a build is kept at least, also when there are `keep` newer ones: a job may still be using it
      '';
    };

    builder = {
      enable = mkEnableOption ''
        building on another machine, which the builds are sent to over ssh (the builder's `ci-deps.builderFor`). It is
        woken first, and when it doesn't wake up they are built here
      '';

      host = mkOption {
        type = types.str;
        default = "manwe";
        description = "The machine to build on, its host key is the one next to its config";
      };

      macAddress = mkOption {
        type = types.strMatching "([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}";
        description = "The wired network adapter of the builder, to wake it with a magic packet";
      };

      broadcastAddress = mkOption {
        type = types.str;
        default = "255.255.255.255";
        description = "Where the magic packet goes, the builder has to be in this broadcast domain";
      };

      wakeTimeout = mkOption {
        type = types.ints.positive;
        default = 120;
        description = "Seconds to wait for the builder to answer after waking it";
      };

      maxJobs = mkOption {
        type = types.ints.positive;
        default = 4;
        description = "How many builds may run on the builder at the same time";
      };

      speedFactor = mkOption {
        type = types.ints.positive;
        default = 4;
        description = "How much faster the builder is than this machine, nix prefers the fastest";
      };

      supportedFeatures = mkOption {
        type = types.listOf types.str;
        default = ["big-parallel" "kvm" "nixos-test" "benchmark"];
        description = "The system features of the builder";
      };
    };

    builderFor = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["ulmo"];
      description = ''
        The machines whose ci-deps builds this machine takes, over ssh as nix-ssh with their key
        (`ci-deps/builder_key.pub`)
      '';
    };
  };

  config = mkMerge [
    (mkIf (cfg.builderFor != []) {
      # Its own user, which can only run `nix-daemon --stdio`. Trusted, or the builds coming in have to be signed
      nix.sshServe = {
        enable = true;
        write = true;
        trusted = true;
        protocol = "ssh-ng";
        keys = [(builtins.readFile ./builder_key.pub)];
      };
      services.openssh.settings.AllowUsers = ["nix-ssh"];
    })

    (mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.allUnique (map (r: r.name) repos);
        message = "ci-deps: two repositories have the same name, set `name` of one of them";
      }
    ];

    # Opt in per repository with the option above and `packages.<system>.deps` in its flake. The hook is a system
    # webhook of forgejo (site administration) that sends push events to
    # http://127.0.0.1:${toString cfg.webhookPort}/hooks/ci-deps
    services.webhook = {
      enable = true;
      ip = "127.0.0.1";
      port = cfg.webhookPort;
      hooks.ci-deps = {
        execute-command = getExe enqueue;
        pass-arguments-to-command = [
          {
            source = "payload";
            name = "repository.full_name";
          }
          {
            source = "payload";
            name = "after";
          }
        ];
      };
    };

    ${namespace}.services.networking.caddy = {
      hosts.":${toString cfg.port}" = ''
        root * ${www}
        file_server
      '';
      # Plain http on the lan, like the other cache
      waf.exclude = [":${toString cfg.port}"];
    };

    networking.firewall.allowedTCPPorts = [cfg.port];

    # Generated with `just vars generate ulmo`, see script/ci_deps/builder_key
    sops.secrets."ci_deps/builder_key" = mkIf cfg.builder.enable {};

    systemd = {
      tmpfiles.rules = [
        "d ${state} 0755 root root -"
        "d ${www} 0755 root root -"
        "d ${www}/status 0755 webhook webhook -"
        "d ${queue} 0755 webhook webhook -"
        "d ${roots} 0755 root root -"
        "d ${run} 0700 root root -"
      ];

      # A nix daemon per store, started by its first connection
      sockets = mapAttrs' (_: r:
        nameValuePair "ci-deps-store-${r.name}" {
          description = "The nix daemon of the store of ${r.repository}";
          wantedBy = ["sockets.target"];
          socketConfig = {
            ListenStream = r.socket;
            SocketMode = "0666";
            DirectoryMode = "0700";
            # nix only takes a socket of this name from systemd
            FileDescriptorName = "nix-daemon.socket";
          };
        })
      cfg.repositories;

      # Starts as soon as the webhook queued something
      paths.ci-deps-build = {
        wantedBy = ["multi-user.target"];
        pathConfig.DirectoryNotEmpty = queue;
      };

      timers.ci-deps-image = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "*:0/15";
          Persistent = true;
        };
      };

      services =
        mapAttrs' (_: r:
          nameValuePair "ci-deps-store-${r.name}" {
            description = "The nix daemon of the store of ${r.repository}";
            requires = ["ci-deps-store-${r.name}.socket"];
            # Like nix-daemon: a restart would kill the builds and the jobs' connections
            restartIfChanged = false;

            # ssh for the builder, which only trusts the builder's own host key, from the repo
            path = lib.optionals cfg.builder.enable [pkgs.openssh];
            environment = lib.optionalAttrs cfg.builder.enable {
              NIX_SSHOPTS = "-o UserKnownHostsFile=${builderKnownHosts} -o StrictHostKeyChecking=yes -o ConnectTimeout=10";
            };

            serviceConfig = {
              # The jobs' builds run here, as a user of this repository only, in nix's sandbox (user namespaces,
              # no build users)
              ExecStart = escapeShellArgs ([
                "${nix}/bin/nix"
                "daemon"
                "--store"
                "local?root=${r.store}"
                "--option"
                "build-users-group"
                ""
                "--option"
                "sandbox"
                "true"
                # The host's nix.conf only lets wheel in, here the socket decides who can connect
                "--option"
                "allowed-users"
                "*"
                "--option"
                "trusted-users"
                "root"
              ]
              ++ lib.optionals cfg.builder.enable [
                # The builder is much faster, nix sends the builds there and only builds here when it can't be reached
                "--option"
                "builders"
                (builders r.name)
                "--option"
                "builders-use-substitutes"
                "true"
              ]);
              KillMode = "process";
              DynamicUser = true;
              StateDirectory = "ci-deps-store/${r.name}";
              CacheDirectory = "ci-deps-store/${r.name}";
              # systemd mounts a dynamic user's state directory noexec, builds run from it
              ExecPaths = [r.store];
              Environment = "XDG_CACHE_HOME=/var/cache/ci-deps-store/${r.name}";
              LoadCredential = lib.optionals cfg.builder.enable ["builder_key:${config.sops.secrets."ci_deps/builder_key".path}"];
              RuntimeDirectory = "ci-deps-store/${r.name}";
              RuntimeDirectoryMode = "0700";
              ExecStartPre = lib.optionals cfg.builder.enable [
                (toString (pkgs.writeShellScript "ci-deps-builder-key" ''
                  umask 077
                  ${pkgs.coreutils}/bin/base64 -d "$CREDENTIALS_DIRECTORY/builder_key" > ${builderKey r.name}
                ''))
              ];

              # Several big rust builds next to the other services is too much, and the jobs wait for them anyway
              Nice = 15;
              IOSchedulingClass = "idle";
              CPUWeight = 5;
              CPUQuota = "200%";
              MemoryHigh = "5G";
              MemoryMax = "7G";
            };
          })
        cfg.repositories
        // {
          ci-deps-build = {
            description = "Build the dependencies of the pipelines into the repositories' stores";
            environment = clientEnv;
            after = ["network-online.target"];
            wants = ["network-online.target"];
            # A deploy would otherwise kill a build of hours, the new script is picked up by the next build
            restartIfChanged = false;

            serviceConfig = {
              Type = "oneshot";
              ExecStart = getExe build;
              ExecStartPost = getExe gc;
            };
          };

          # Before the runners start, and every 15 minutes: the runners don't pull the image themselves, so the
          # image they use always has its closure in the stores
          ci-deps-image = {
            description = "Put the closure of the runner image into the repositories' stores";
            environment = clientEnv;
            after = ["network-online.target" "podman.service"];
            wants = ["network-online.target"];

            serviceConfig = {
              Type = "oneshot";
              ExecStart = getExe image;
              ExecStartPost = getExe gc;
            };
          };
        };
    };
  })
  ];
}
