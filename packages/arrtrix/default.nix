{
  buildGoModule,
  lib,
  olm,
  versionCheckHook,
}:
buildGoModule rec {
  pname = "arrtrix";
  version = "0.1.0";
  tag = "v0.1.0";

  src = lib.cleanSource ./.;

  vendorHash = "sha256-FbatoXcxZcnqVUmoj/jeSMFO/iTmD8uga47MoTdGcRw=";
  subPackages = ["cmd/arrtrix"];

  buildInputs = [olm];

  ldflags = [
    "-X main.Tag=${tag}"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [versionCheckHook];

  meta = {
    description = "*arr-stack Matrix bridge";
    homepage = "https://github.com/chris-kruining/sneeuwvlok";
    license = lib.licenses.mit;
    maintainers = [];
    mainProgram = "arrtrix";
  };
}
