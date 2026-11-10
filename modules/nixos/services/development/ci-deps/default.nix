{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types getExe;

  cfg = config.${namespace}.services.development.ci-deps;

  state = "/var/lib/ci-deps";
  # Served as is: the binary cache that jobs substitute from, and the status of every build next to it
  www = "${state}/www";
  queue = "${state}/queue";
  roots = "${state}/roots";
  store = "${state}/store";
  repositories = "${config.services.forgejo.stateDir}/repositories";
  signKey = config.sops.secrets."nix_cache/signing_key".path;

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

  build = pkgs.writeShellApplication {
    name = "ci-deps-build";
    runtimeInputs = [config.nix.package pkgs.git pkgs.coreutils pkgs.findutils pkgs.gnutar];
    text = ''
      shopt -s nullglob

      system=${pkgs.stdenv.hostPlatform.system}
      cache="file://${www}?compression=zstd&secret-key=${signKey}"
      # Builds are in a store of their own, so the system's garbage collection and the other builds do not meet
      nixflags=(--store ${store})

      status() { echo "$3" > "${www}/status/$1/$2"; }

      rm -rf ${state}/src.*

      # The queue file goes only once the build is over, so a build that is stopped halfway (a deploy, a
      # reboot) starts again instead of leaving its status at building forever
      while queued=(${queue}/*) && [ ''${#queued[@]} -gt 0 ]; do
        item=''${queued[0]}
        read -r repo sha < "$item"

        src=$(mktemp -d ${state}/src.XXXXXX)
        git -c safe.directory='*' -C "${repositories}/$repo.git" archive "$sha" | tar -x -C "$src"

        # Repositories that have no `deps` package are not for this, which is most of them
        if ! out=$(nix eval "''${nixflags[@]}" --raw "path:$src#packages.$system.deps.outPath" 2>/dev/null); then
          status "$repo" "$sha" "none"
          rm -rf "$src" "$item"
          continue
        fi

        status "$repo" "$sha" building
        mkdir -p "${roots}/$repo"
        echo "building $repo at $sha"

        # The out link is a gc root of the store, which keeps the build for the next push that does not change it
        if nix build "''${nixflags[@]}" --max-jobs 1 "path:$src#packages.$system.deps" --out-link "${roots}/$repo/$sha" \
          && nix copy --from ${store} --to "$cache" "$out"; then
          status "$repo" "$sha" "done"
        else
          status "$repo" "$sha" failed
        fi

        rm -rf "$src" "$item"
      done

      # Keep the last builds of every repository, the rest goes out of the store and the cache
      pruned=0
      for dir in ${roots}/*/*/; do
        while read -r old; do
          rm -v "$old"
          pruned=1
        done < <(find "$dir" -mindepth 1 -maxdepth 1 -type l -printf '%T@ %p\n' | sort -rn | tail -n +${toString (cfg.keep + 1)} | cut -d' ' -f2-)
      done

      # The cache is built again from what is left, there is no removing single paths from it
      if [ "$pruned" = 1 ]; then
        nix store gc "''${nixflags[@]}"
        rm -rf ${www}/nar ${www}/*.narinfo
        for root in ${roots}/*/*/*; do
          nix copy --from ${store} --to "$cache" "$(readlink "$root")"
        done
      fi
    '';
  };
in {
  options.${namespace}.services.development.ci-deps = {
    enable = mkEnableOption "building the dependencies of a repository's pipelines as soon as a commit is pushed, into a binary cache the runners use";

    port = mkOption {
      type = types.port;
      default = 5001;
      description = ''
        The port the cache and the build status are served on
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
        How many builds of every repository to keep in the cache
      '';
    };
  };

  config = mkIf cfg.enable {
    # Opt in per repository by having `packages.<system>.deps` in its flake. The hook is a system webhook of
    # forgejo (site administration) that sends push events to http://127.0.0.1:${toString cfg.webhookPort}/hooks/ci-deps
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

    systemd = {
      tmpfiles.rules = [
        "d ${state} 0755 root root -"
        "d ${www} 0755 root root -"
        "d ${www}/status 0755 webhook webhook -"
        "d ${queue} 0755 webhook webhook -"
        "d ${roots} 0755 root root -"
      ];

      # Starts as soon as the webhook queued something
      paths.ci-deps-build = {
        wantedBy = ["multi-user.target"];
        pathConfig.DirectoryNotEmpty = queue;
      };

      services.ci-deps-build = {
        description = "Build the dependencies of the pipelines into the cache";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        # A deploy would otherwise kill a build of hours, the new script is picked up by the next build
        restartIfChanged = false;

        serviceConfig = {
          Type = "oneshot";
          ExecStart = getExe build;
          # Several big rust builds next to the other services is too much, and the cache is not urgent
          Nice = 15;
          CPUSchedulingPolicy = "idle";
          IOSchedulingClass = "idle";
          # the chroot-store build runs in the client process, so Nice doesn't reach rustc; cgroup limits do
          CPUWeight = 5;
          CPUQuota = "200%";
          MemoryHigh = "5G";
          MemoryMax = "7G";
        };
      };
    };

    sops.secrets."nix_cache/signing_key" = {};
  };
}
