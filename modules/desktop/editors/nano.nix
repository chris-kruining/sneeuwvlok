{ config, options, lib, pkgs, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
in
{
  options.modules.desktop.editors.nano = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "nano"; };

  config = mkIf config.modules.desktop.editors.nano.enable {
    programs.nano = {
      enable = true;
      syntaxHighlight = true;
      nanorc = ''
        set autoindent
        set jumpyscrolling
        set linenumbers
        set mouse
        set saveonexit
        set smarthome
        set tabstospaces
        set tabsize 2
      '';
    };
  };
}
