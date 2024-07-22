{ config, options, lib, pkgs, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.services.auth = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Media auth";
  };

  config = mkIf config.modules.services.auth.enable {
    environment.systemPackages = with pkgs; [
      authelia
    ];
  };
}
