{lib, stdenv, rustPlatform, fetchFromGitHub, openssl, pkg-config, postgresql, dbBackend ? "postgresql", ...}:
rustPlatform.buildRustPackage rec {
  pname = "vaultwarden";
  version = "1.34.3";

  src = fetchFromGitHub {
    owner = "Timshel";
    repo = "vaultwarden";
    rev = "1.34.3";
    hash = "sha256-Dj0ySVRvBZ/57+UHas3VI8bi/0JBRqn0IW1Dq+405J0=";
  };

  cargoHash = "sha256-4sDagd2XGamBz1XvDj4ycRVJ0F+4iwHOPlj/RglNDqE=";

  env.VW_VERSION = version;

  nativeBuildInputs = [pkg-config];
  buildInputs =
    [openssl]
    ++ lib.optional (dbBackend == "postgresql") postgresql;

  buildFeatures = dbBackend;

  meta = with lib; {
    license = licenses.agpl3Only;
    mainProgram = "vaultwarden";
  };
}
