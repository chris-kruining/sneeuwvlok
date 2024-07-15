{ config, pkgs, options, ... }:
{
  environment.systemPackages = with pkgs; [
    ladybird
  ];
}
