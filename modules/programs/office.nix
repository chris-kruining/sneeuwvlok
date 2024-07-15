{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    onlyoffice-bin
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "corefonts" ];

  fonts.packages = with pkgs; [
    corefonts
  ];
}
