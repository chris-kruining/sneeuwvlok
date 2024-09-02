{ config, options, lib, pkgs, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;

  cfg = config.modules.desktop.editors.kate;
in
{
  options.modules.desktop.editors.kate = let
    inherit (lib.options) mkEnableOption;
  in { enable = mkEnableOption "kate"; };

  config = mkIf cfg.enable {
#     programs.kate = {
#       enable = true;
#
#       editor = {
#         brackets.highlightMatching = true;
#
#         indent = {
#           keepExtraSpaces = false;
#           replaceWithSpaces = true;
#           showLines = true;
#           undoByShiftTab = true;
#
#           width = 4;
#           tabWidth = 4;
#         };
#       };
#
#       lsp = {
#         typescript = {};
#       };
#     };
  };
}
