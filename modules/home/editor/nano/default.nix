{ config, options, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.editor.nano;
in
{
  options.${namespace}.editor.nano = {
    enable = mkEnableOption "nano";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ nano ];

    # programs.nano = {
    #   enable = true;
    #   syntaxHighlight = true;
    #   nanorc = ''
    #     set autoindent
    #     set jumpyscrolling
    #     set linenumbers
    #     set mouse
    #     set saveonexit
    #     set smarthome
    #     set tabstospaces
    #     set tabsize 2
    #   '';
    # };
  };
}
