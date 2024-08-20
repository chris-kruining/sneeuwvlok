{ config, options, lib, pkgs, ... }:
let
  inherit (builtins) getEnv map;
  inherit (lib.attrsets) attrValues mapAttrsToList;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.strings) concatStringsSep optionalString;

  cfg = config.modules.themes;
  desktop = config.modules.desktop;
in {
  options.modules.themes = let
    inherit (lib.options) mkOption mkPackageOption;
    inherit (lib.types) attrsOf int lines listOf nullOr path package str;
    inherit (lib.my) mkOpt toFilteredImage;
  in {
    active = mkOption {
      type = nullOr str;
      default = null;
      apply = v: let
        theme = getEnv "THEME";
      in
        if theme != ""
        then theme
        else v;
      description = ''
        Name of the theme which ought to be applied.
        Can be overridden by the `THEME` environment variable.
      '';
    };

    wallpaper = mkOpt (nullOr path) null;

    loginWallpaper = mkOpt (nullOr path) (
      if cfg.wallpaper != null
      then toFilteredImage cfg.wallpaper "-gaussian-blur 0x2 -modulate 70 -level 5%"
      else null
    );

    gtk = {
      name = mkOpt str "";
      package = mkPackageOption pkgs "gtk" {};
    };

    iconTheme = {
      name = mkOpt str "";
      package = mkPackageOption pkgs "icon" {};
    };

    pointer = {
      name = mkOpt str "";
      package = mkPackageOption pkgs "pointer" {};
      size = mkOpt int 0;
    };

    onReload = mkOpt (attrsOf lines) {};

    fontConfig = {
      packages = mkOpt (listOf package) [];
      mono = mkOpt (listOf str) [""];
      sans = mkOpt (listOf str) [""];
      emoji = mkOpt (listOf str) [""];
    };

    font = {
      mono = {
        family = mkOpt str "";
        weight = mkOpt str "Bold";
        weightAlt = mkOpt str "Bold";
        weightNum = mkOpt int 700;
        size = mkOpt int 13;
      };
      sans = {
        family = mkOpt str "";
        weight = mkOpt str "SemiBold";
        weightAlt = mkOpt str "DemiBold";
        weightNum = mkOpt int 600;
        size = mkOpt int 10;
      };
    };

    colors = {
      main = {
        normal = {
          black = mkOpt str "#000000"; # 0
          red = mkOpt str "#FF0000"; # 1
          green = mkOpt str "#00FF00"; # 2
          yellow = mkOpt str "#FFFF00"; # 3
          blue = mkOpt str "#0000FF"; # 4
          magenta = mkOpt str "#FF00FF"; # 5
          cyan = mkOpt str "#00FFFF"; # 6
          white = mkOpt str "#BBBBBB"; # 7
        };
        bright = {
          black = mkOpt str "#888888"; # 8
          red = mkOpt str "#FF8800"; # 9
          green = mkOpt str "#00FF80"; # 10
          yellow = mkOpt str "#FF8800"; # 11
          blue = mkOpt str "#0088FF"; # 12
          magenta = mkOpt str "#FF88FF"; # 13
          cyan = mkOpt str "#88FFFF"; # 14
          white = mkOpt str "#FFFFFF"; # 15
        };
        types = let
          inherit (cfg.colors.main.normal) black red white yellow;
          inherit (cfg.colors.main.types) bg fg;
        in {
          bg = mkOpt str black;
          fg = mkOpt str white;
          panelbg = mkOpt str bg;
          panelfg = mkOpt str fg;
          border = mkOpt str bg;
          error = mkOpt str red;
          warning = mkOpt str yellow;
          highlight = mkOpt str white;
        };
      };

      rofi = {
        bg = {
          main = mkOpt str "#FFFFFF";
          alt = mkOpt str "#FFFFFF";
          bar = mkOpt str "#FFFFFF";
        };
        fg = mkOpt str "#FFFFFF";
        ribbon = {
          outer = mkOpt str "#FFFFFF";
          inner = mkOpt str "#FFFFFF";
        };
        selected = mkOpt str "#FFFFFF";
        urgent = mkOpt str "#FFFFFF";
        transparent = mkOpt str "#FFFFFF";
      };
    };

    editor = {
      neovim = {
        light = mkOpt str "";
        dark = mkOpt str "";
      };
    };
  };

  config = mkIf (cfg.active != null) (mkMerge [
    (mkIf (desktop.type == "wayland") (mkMerge []))
  ]);
}
