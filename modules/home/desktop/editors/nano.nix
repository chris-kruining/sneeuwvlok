{ config, options, lib, pkgs, user, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;

  cfg = config.modules.${user}.desktop.editors.nano;
in
{
  options.modules.${user}.desktop.editors.nano = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "nano"; };

  config = mkIf cfg.enable {
    home-manager.users.${user}.home.packages = with pkgs; [
      nano
    ];

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
