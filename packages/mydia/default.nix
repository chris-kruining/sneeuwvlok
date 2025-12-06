{ lib, inputs, fetchFromGitHub, pkgs, stdenv, ... }:
let
  erl = pkgs.beam.interpreters.erlang_28;
  erlangPackages = pkgs.beam.packagesWith erl;

  elixir = erlangPackages.elixir;
  mix = "${elixir}/bin/mix";
  rebar = erlangPackages.rebar;
  hex = erlangPackages.hex;

  bun = pkgs.bun;
  bun2nix = inputs.bun2nix.packages.${stdenv.hostPlatform.system}.default;

  translatedPlatform =
    {
      aarch64-darwin = "macos-arm64";
      aarch64-linux = "linux-arm64";
      armv7l-linux = "linux-armv7";
      x86_64-darwin = "macos-x64";
      x86_64-linux = "linux-x64";
    }
    .${stdenv.hostPlatform.system};
  
  version = "v0.6.0";
  pname = "mydia";
  src = fetchFromGitHub {
    owner = "getmydia";
    repo = "mydia";
    rev = version;
    hash = "sha256-JGT52ulnqcx8o+3e0l50TLAwLIWXEI8nwFGUsA95vH0=";
  };
  mixFodDeps = erlangPackages.fetchMixDeps {
    inherit version src;
    pname = "${pname}-mix-deps";
    hash = "sha256-19q56IZe8YjuUBXirFGgmBsewJ0cmdOoO1yfiMaWGWk=";
  };
  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
    overrides = {
      "phoenix" = pkg: pkgs.runCommandLocal "override-phoenix" {} ''
        mkdir $out
        echo "je moeder!" > $out/kaas.txt
      '';
      "phoenix_html" = pkg: pkgs.runCommandLocal "override-phoenix_html" {} ''
        mkdir $out
        echo "je moeder!" > $out/kaas.txt
      '';
      "phoenix_live_view" = pkg: pkgs.runCommandLocal "override-phoenix_live_view" {} ''
        mkdir $out
        echo "je moeder!" > $out/kaas.txt
      '';
      "phoenix_live_view/phoenix" = pkg: pkgs.runCommandLocal "override-phoenix_live_view__phoenix" {} ''
        mkdir $out
        echo "je moeder!" > $out/kaas.txt
      '';
    };
  };
in
erlangPackages.mixRelease {
  inherit pname version src mixFodDeps bunDeps;

  nativeBuildInputs = with pkgs; [ ffmpeg_7-headless pkg-config bun2nix.hook ];

  dontUseBunPatch = true;
  dontUseBunBuild = true;

  preInstall = ''
    ln -s ${pkgs.tailwindcss}/bin/tailwind _build/tailwind-${translatedPlatform}
    ln -s ${pkgs.esbuild}/bin/esbuild _build/esbuild-${translatedPlatform}
    ln -s ${bunDeps}/node_modules assets/node_modules

    ${mix} assets.deploy
  '';

  # nativeBuildInputs = with pkgs; [
  #   elixir 
  #   rebar
  #   hex
  #   git
  #   bun
  #   postgresql
  #   curl
  #   ffmpeg_7-headless
  #   fdk_aac
  #   pkg-config
  # ];

  # buildPhase = ''
  #   runHook preBuild

  #   # Prepare environment
  #   DATABASE_TYPE="postgres"
    
  #   # I don't think this is needed, but lets copy the dockerfile for now
  #   mkdir -p ./app
  #   cp mix.exs ./app
  #   cp mix.lock ./app
  #   cd ./app

  #   # Install dependencies
  #   ${mix} deps.get --only prod && ${mix} deps.compile
  #   pwd
  #   ls -al

  #   # Copy source
  #   echo "Copy source"
  #   cp -r ../config ./config
  #   cp -r ../priv ./priv
  #   cp -r ../lib ./lib
  #   cp -r ../assets ./assets

  #   # Compile app
  #   echo "Compile app"
  #   ${mix} compile

  #   # Build assets
  #   echo "Build assets"
  #   $(cd ./assets && bun i --silent --production --frozen-lockfile)
  #   ${mix} assets.deploy

  #   # Build executabe
  #   echo "Build executabe"
  #   ${mix} release
    
  #   bun run build --bun
    
  #   runHook postBuild
  # '';

  # installPhase = ''
  #   runHook preInstall

  #   mkdir -p $out
  #   cp -r ./.output/* $out

  #   makeWrapper ${lib.getExe pkgs.bun} $out/bin/${pname} \
  #   --chdir $out \
  #   --append-flags "server/index.mjs"
    
  #   runHook postInstall
  # '';

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