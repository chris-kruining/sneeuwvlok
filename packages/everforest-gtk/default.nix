{
  lib,
  stdenv,
  fetchFromGitHub,
  gtk-engine-murrine,
  jdupes,
  sassc,
  accent ? ["default"],
  shade ? "dark",
  size ? "standard",
}: let
  validAccents = ["default" "purple" "pink" "red" "orange" "yellow" "green" "teal" "grey"];
  validShades = ["light" "dark"];
  validSizes = ["standard" "compact"];

  single = x: lib.optional (x != null) x;
  pname = "Everforest";
in
  lib.checkListOfEnum "${pname} Valid theme accent(s)" validAccents accent
  lib.checkListOfEnum "${pname} Valid shades" validShades (single shade)
  lib.checkListOfEnum "${pname} Valid sizes" validSizes (single size)

  stdenv.mkDerivation {
    pname = "${pname}";
    version = "0-unstable-2024-06-27";

    src = fetchFromGitHub {
      owner = "Fausto-Korpsvart";
      repo = "Everforest-GTK-Theme";
      rev = "bb3fc27a2468f0965a738d9d3b30c52a799572d2";
      hash = "sha256-sTHyH1pCq/d2JMmEppdQAc+P8a3y1lM+WQcW7nXEoPE=";
    };

    nativeBuildInputs = [jdupes sassc];

    propagatedUserEnvPkgs = [gtk-engine-murrine];

    postPatch = ''
      find -name "*.sh" -print0 | while IFS= read -r -d ''' file; do
        patchShebangs "$file"
      done
    '';

    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/themes

      ./themes/install.sh \
        --name ${pname} \
        ${toString (map (x: "--theme " + x) accent)} \
        ${lib.optionalString (shade != null) ("--color " + shade)} \
        ${lib.optionalString (size != null) ("--size " + size)} \
        --dest $out/share/themes

      jdupes --quiet --link-soft --recurse $out/share

      runHook postInstall
    '';

    meta = with lib; {
      description = "A GTK theme based on the Everforest colour palette";
      homepage = "https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme";
      license = licenses.gpl3Only;
      platforms = platforms.all;
    };
  }
