{
  lib,
  stdenvNoCC,
  inputs,
}: let
  src = inputs.jellyfin-plugin-sso;

  # The release zip carries jellyfin's own plugin manifest, so the url in flake.nix stays the only place to bump the version
  manifest = src + "/meta.json" |> builtins.readFile |> builtins.fromJSON;
in
  stdenvNoCC.mkDerivation {
    pname = "jellyfin-plugin-sso";
    inherit (manifest) version;
    inherit src;

    installPhase = ''
      runHook preInstall

      cp -r . $out

      runHook postInstall
    '';

    passthru = {
      # Jellyfin loads plugins from `<plugins dir>/<this>`, and only keeps the newest version of a plugin
      directory = "${manifest.name}_${manifest.version}";
      inherit (manifest) guid targetAbi;
    };

    meta = {
      description = manifest.overview;
      homepage = "https://github.com/MaxRink/jellyfin-plugin-sso";
      license = lib.licenses.gpl3Only;
      sourceProvenance = [lib.sourceTypes.binaryBytecode];
      platforms = lib.platforms.all;
    };
  }
