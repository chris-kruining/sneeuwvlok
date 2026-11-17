{ inputs, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkMerge mkOption mkEnableOption types attrValues mapAttrs' mapAttrsToList nameValuePair
    concatStringsSep concatStrings optionalString;

  cfg = config.${namespace}.themes;

  font = default: mkOption {
    type = types.submodule {
      options = {
        package = mkOption { type = types.package; };
        name = mkOption { type = types.str; };
      };
    };
    inherit default;
  };

  size = default: mkOption { type = types.int; inherit default; };

  # The named colours every scheme has, made from base16 the same way the wallpaper generator makes them from
  # matugen's palette (see the plasma module's wallpaper-themes.py)
  fromBase16 = b: b // {
    scheme-name = "Sneeuwvlok";
    scheme-author = "sneeuwvlok";
    scheme-variant = "dark";
    background = b.base00;
    surface = b.base01;
    surface-high = b.base02;
    outline = b.base03;
    foreground-dim = b.base04;
    foreground = b.base05;
    accent = b.base0D;
    accent-container = b.base02;
    on-accent = b.base00;
    on-accent-container = b.base05;
    error = b.base08;
    red = b.base08;
    orange = b.base09;
    yellow = b.base0A;
    green = b.base0B;
    cyan = b.base0C;
    blue = b.base0D;
    magenta = b.base0E;
  };

  follows = cfg.schemes != { };
  schemes = if follows then cfg.schemes else {
    fallback = pkgs.writeText "fallback-tokens.json" (builtins.toJSON (fromBase16 cfg.fallback));
  };

  rendered = pkgs.runCommand "themes" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 ${./render.py} ${pkgs.writeText "theme-targets.json" (builtins.toJSON (lib.mapAttrs (_: t: t.text) cfg.targets))} \
      $out ${concatStringsSep " " (mapAttrsToList (n: p: "${n}=${p}") schemes)}
  '';

  state = "${config.xdg.stateHome}/sneeuwvlok/theme";

  apply = pkgs.writeShellApplication {
    name = "sneeuwvlok-theme-apply";
    runtimeInputs = with pkgs; [ coreutils procps systemd ];
    text = ''
      # usage: sneeuwvlok-theme-apply <scheme>
      # Points every theme target at the scheme's files and has the apps that need it reload them
      dir="${rendered}/$1"
      if [ ! -d "$dir" ]; then
        echo "unknown colour scheme '$1', pick one of: ${concatStringsSep " " (builtins.attrNames schemes)}" >&2
        exit 1
      fi
      ${concatStrings (mapAttrsToList (n: t: ''
        mkdir -p "$HOME/${dirOf t.path}"
        ln -sfn "$dir/${n}" "$HOME/${t.path}"
      '') cfg.targets)}
      mkdir -p "${dirOf state}"
      echo "$1" > "${state}"
      ${concatStrings (mapAttrsToList (_: t: optionalString (t.reload != null) ''
        { ${t.reload}
        } || true
      '') cfg.targets)}
    '';
  };
in {
  options.${namespace}.themes = {
    enable = mkEnableOption "the fonts and colours every app gets";

    fonts = {
      serif = font { package = pkgs.dejavu_fonts; name = "DejaVu Serif"; };
      sansSerif = font { package = pkgs.dejavu_fonts; name = "DejaVu Sans"; };
      monospace = font { package = pkgs.nerd-fonts.jetbrains-mono; name = "JetBrainsMono Nerd Font Mono"; };
      emoji = font { package = pkgs.noto-fonts-color-emoji; name = "Noto Color Emoji"; };

      # in points
      sizes = {
        applications = size 12;
        terminal = size 12;
        desktop = size 10;
      };
    };

    token = mkOption {
      type = types.functionTo types.str;
      readOnly = true;
      default = name: "{{${name}}}";
      description = ''
        Where a colour goes in a target's text, filled in per colour scheme when the targets are built. The tokens:
        base16's `base00` to `base0F`, `background`, `surface`, `surface-high`, `outline`, `foreground`,
        `foreground-dim`, `accent`, `accent-container`, `on-accent`, `on-accent-container`, `error`, `red`, `orange`,
        `yellow`, `green`, `cyan`, `blue`, `magenta` (all `#rrggbb`, `<token>-hex` without the `#` and `<token>-rgb` as
        `r, g, b`), and
        `scheme-name`, `scheme-author`, `scheme-variant`
      '';
    };

    targets = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          path = mkOption {
            type = types.str;
            example = ".config/ghostty/colors";
            description = "Where the file goes, relative to the home directory";
          };
          text = mkOption {
            type = types.lines;
            description = "The file, with tokens (`themes.token`) for its colours";
          };
          reload = mkOption {
            type = types.nullOr types.lines;
            default = null;
            description = "Run after switching colour schemes, for apps that don't notice the file changed. Must not block";
          };
        };
      });
      default = { };
      description = "Files with colours in them, written for every colour scheme";
    };

    schemes = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = ''
        Token files (json) of the colour schemes `sneeuwvlok-theme-apply <name>` switches between, the desktop sets
        these (one per wallpaper). Without any the targets get the fallback, as plain files
      '';
    };

    fallback = mkOption {
      type = types.attrsOf types.str;
      description = "The base16 scheme for when nothing switches colour schemes";
      default = {
        # everforest dark
        base00 = "#2d353b"; base01 = "#343f44"; base02 = "#475258"; base03 = "#859289";
        base04 = "#9da9a0"; base05 = "#d3c6aa"; base06 = "#e6e2cc"; base07 = "#fdf6e3";
        base08 = "#e67e80"; base09 = "#e69875"; base0A = "#dbbc7f"; base0B = "#a7c080";
        base0C = "#83c092"; base0D = "#7fbbb3"; base0E = "#d699b6"; base0F = "#9da9a0";
      };
    };

    apply = mkOption {
      type = types.package;
      readOnly = true;
      default = apply;
      description = "`sneeuwvlok-theme-apply <scheme>`, switches every target to that colour scheme";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = map (f: f.package) (attrValues (removeAttrs cfg.fonts [ "sizes" ]));
    }

    (mkIf (!follows) {
      home.file = mapAttrs' (n: t: nameValuePair t.path { source = "${rendered}/fallback/${n}"; }) cfg.targets;
    })

    # A rebuild makes new files, this points the targets at them, in the scheme that was on
    (mkIf follows {
      home.packages = [ apply ];
      home.activation.sneeuwvlokTheme = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -f "${state}" ]; then
          run ${lib.getExe apply} "$(cat "${state}")" || true
        fi
      '';
    })
  ]);
}
