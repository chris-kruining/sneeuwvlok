{ lib, fetchurl, stdenvNoCC }:
# free for personal use, so it's fetched rather than vendored
stdenvNoCC.mkDerivation {
  pname = "anurati";
  version = "1.0";

  src = fetchurl {
    url = "https://media.githubusercontent.com/media/linnovs/taijipan/7aedfbf06506af54106be3a80a6705eb32f6e4b9/assets/fonts/Anurati/Anurati-Regular.otf";
    hash = "sha256-m2xBywieqfaC8XfSpdwh4YKMOebyC5pMEdmZ3pEuAMM=";
  };

  dontUnpack = true;
  installPhase = "install -Dm644 $src $out/share/fonts/opentype/Anurati-Regular.otf";

  meta = {
    description = "Anurati, the wide display font of the lock screen and boot splash";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
