{
  buildGoModule,
  lib,
}:
buildGoModule {
  pname = "mission-control";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  vendorHash = "sha256-NlD+bsW/GIUrI/dniCzitvKJoiZd1nZ399LFYShZ3h8=";

  # No --version/--help flag and no meaningful non-interactive behavior to
  # check: this is a full-screen TUI that just starts drawing frames the
  # instant it has a tty, so the usual versionCheckHook convention used by
  # other Go packages in this repo doesn't apply here.
  doInstallCheck = false;

  meta = {
    description = "Bubbletea mission-control dashboard for the netboot installer console";
    homepage = "https://github.com/chris-kruining/sneeuwvlok";
    license = lib.licenses.mit;
    maintainers = [];
    mainProgram = "mission-control";
  };
}
