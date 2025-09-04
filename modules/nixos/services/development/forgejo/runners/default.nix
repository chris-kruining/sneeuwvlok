{
  pkgs ? import <nixpkgs> {},
  pkgs_linux ? import <nixpkgs> { system = "x86_64-linux"; },
}:

with pkgs; 
let
  debian = dockerTools.pullImage {
    imageName = "debian";
    sha256 = "1e45698b8553ad4b2e074f59f14c579194aa9b003f5c7b4a3d8704087954909b";
  };
in
dockerTools.buildImage {
  name = "default";
  tag = "latest";
  fromImage = debian;

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