{ pkgs, config, ... }:
let
  inherit (lib.modules) mkIf;
in
{
  options.modules.programs.communication = let
    inherit (lib.options) mkEnableOption;
  in {
    enable = mkEnableOption "Discord and Teamspeak";
  };

  environment.systemPackages = with pkgs; [
    webcord
    teamspeak_client
  ];
}
