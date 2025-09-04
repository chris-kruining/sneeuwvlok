{
  pkgs ? import <nixpkgs> {},
  pkgs_linux ? import <nixpkgs> { system = "x86_64-linux"; },
}:

with pkgs; 
dockerTools.buildImage {
  name = "default";
  tag = "latest";

  copyToRoot = buildEnv {
    name = "image-root";
    pathsToLink = [ "/bin" ];
    paths = [
      coreutils
      # u-root-cmds
      bash
      # nix
      # nodejs
      # podman
    ];
  };

  runAsRoot = ''
    #!${stdenv.shell}
    # ${dockerTools.shadowSetup}
    groupadd -r runner
    useradd -r -g runner -d /data -M runner
    mkdir /data
    chown runner:runner /data
  '';

  config = {
    User = "runner";
    Cmd = [ "${lib.getExe bashInteractive}" ];
    WorkingDir = "/data";
    Volumes = {
      "/data" = {};
    };
  };
}