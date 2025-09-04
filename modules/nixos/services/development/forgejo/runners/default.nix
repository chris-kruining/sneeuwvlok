{
  pkgs ? import <nixpkgs> {},
  pkgs_linux ? import <nixpkgs> { system = "x86_64-linux"; },
}:

pkgs.dockerTools.buildImage {
  name = "default";
  tag = "latest";

  config = {
    Cmd = [ "${pkgs_linux.hello}/bin/hello" ];
  };
}