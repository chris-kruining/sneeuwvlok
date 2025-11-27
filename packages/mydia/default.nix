{
  lib,
  fetchFromGitHub,
  pkgs,
  stdenv,
  ...
}: let
  erlang = pkgs.beam.packagesWith pkgs.beam.interpreters.erlang;
  mix = "${erlang.elixir}/bin/mix";

  translatedPlatform =
    {
      aarch64-darwin = "macos-arm64";
      aarch64-linux = "linux-arm64";
      armv7l-linux = "linux-armv7";
      x86_64-darwin = "macos-x64";
      x86_64-linux = "linux-x64";
    }
    .${
      stdenv.hostPlatform.system
    };

  version = "v0.6.0";
  pname = "mydia";
  src = fetchFromGitHub {
    owner = "getmydia";
    repo = "mydia";
    rev = version;
    hash = "sha256-JGT52ulnqcx8o+3e0l50TLAwLIWXEI8nwFGUsA95vH0=";
  };
  mixFodDeps = erlang.fetchMixDeps {
    inherit version src;
    pname = "mix-deps-${pname}-${version}";
    hash = "sha256-19q56IZe8YjuUBXirFGgmBsewJ0cmdOoO1yfiMaWGWk=";

    DATABASE_TYPE = "postgres";
  };
  npmFodDeps = pkgs.fetchNpmDeps {
    src = "${src}/assets";
    hash = "sha256-0cz75pxhxvzo1RogsV8gTP6GrgLIboWQXcKpq42JZ6o=";
  };
in
  erlang.mixRelease {
    inherit pname version src mixFodDeps;

    enableDebugInfo = true;

    nativeBuildInputs = with pkgs; [
      ffmpeg_6
      fdk_aac
      sqlite
      postgresql
      pkg-config
    ];
    buildInputs = with pkgs; [
      ffmpeg_6
      fdk_aac
      sqlite
      postgresql
      pkg-config
    ];

    DATABASE_TYPE = "postgres";

    preInstall = ''
      ln -s ${pkgs.tailwindcss}/bin/tailwind _build/tailwind-${translatedPlatform}
      ln -s ${pkgs.esbuild}/bin/esbuild _build/esbuild-${translatedPlatform}
      ln -s ${npmFodDeps} assets/node_modules

      ${mix} assets.deploy
    '';

    meta = {
      description = "Your personal media companion, built with Phoenix LiveView";
      longDescription = ''
        A modern, self-hosted media management platform for tracking, organizing, and monitoring your media library.

        # ✨ Features

        - 📺 Unified Media Management – Track both movies and TV shows with rich metadata from TMDB/TVDB
        - 🤖 Automated Downloads – Background search and download with quality profiles and smart release ranking
        - ⬇️ Download Clients – qBittorrent, Transmission, SABnzbd, and NZBGet support
        - 🔎 Indexer Integration – Search via Prowlarr and Jackett for finding releases
        - 📚 Built-in Indexer Library – Native Cardigann support (experimental, limited testing)
        - 👥 Multi-User System – Built-in admin/guest roles with request approval workflow
        - 🔐 SSO Support – Local authentication plus OIDC/OpenID Connect integration
        - 🔔 Release Calendar – Track upcoming releases and monitor episodes
        - 🎨 Modern Real-Time UI – Phoenix LiveView with instant updates and responsive design
      '';

      homepage = "https://github.com/getmydia/mydia";
      changelog = "https://github.com/getmydia/mydia/releases";
      license = lib.licenses.agpl3Only;

      maintainers = [];

      platforms = lib.platforms.all;
      mainProgram = pname;
    };
  }
