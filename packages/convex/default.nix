{ 
  lib, 
  stdenv, 
  rustPlatform, 
  fetchFromGitHub, 
  
  # dependencies
  openssl, 
  pkg-config, 
  cmake,
  llvmPackages,
  postgresql, 
  sqlite, 
  
  #options
  dbBackend ? "postgresql", 

  ... 
}:
rustPlatform.buildRustPackage rec {
  pname = "convex";
  version = "2025-08-20-c9b561e";

  src = fetchFromGitHub {
    owner = "get-convex";
    repo = "convex-backend";
    rev = "c9b561e1b365c85ef28af35d742cb7dd174b5555";
    hash = "sha256-4h4AQt+rQ+nTw6eTbbB5vqFt9MFjKYw3Z7bGXdXijJ0=";
  };

  cargoHash = "sha256-pcDNWGrk9D0qcF479QAglPLFDZp27f8RueP5/lq9jho=";

  cargoBuildFlags = [
    "-p" "local_backend"
    "--bin" "convex-local-backend"
  ];

  env = {
    LIBCLANG_PATH = "${llvmPackages.libclang}/lib";
  };

  strictDeps = true;

  # Build-time dependencies
  nativeBuildInputs = [ pkg-config cmake rustPlatform.bindgenHook ];

  # Run-time dependencies
  buildInputs = 
    [ openssl ]
    ++ lib.optional (dbBackend == "sqlite") sqlite
    ++ lib.optional (dbBackend == "postgresql") postgresql;

  buildFeatures = "";

  meta = with lib; {
    license = licenses.fsl11Asl20;
    mainProgram = "convex";
  };
}