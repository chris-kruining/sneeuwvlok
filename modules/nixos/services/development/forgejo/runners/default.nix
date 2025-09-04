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
    paths = with pkgs_linux [
      coreutils
      u-root-cmds
      bash
      nix
      nodejs
      podman
    ];
  };

  config = {
    User = "runner";
    Cmd = [ "${lib.getExe bashInteractive}" ];
  };
}