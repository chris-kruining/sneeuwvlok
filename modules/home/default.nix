{ pkgs, config, lib, namespace, ... }:
let
  inherit (lib) mkOption genAttrs;
  inherit (lib.types) enum;

  cfg = config.${namespace}.defaults;

  browserDesktopId = {
    chrome = "chromium-browser.desktop";
    helium = "helium.desktop";
    ladybird = "org.ladybird.Ladybird.desktop";
    zen = "zen-beta.desktop";
  }.${cfg.browser};

  terminalDesktopId = {
    ghostty = "com.mitchellh.ghostty.desktop";
    alacritty = "Alacritty.desktop";
  }.${cfg.terminal};

  fileManagerDesktopId = {
    dolphin = "org.kde.dolphin.desktop";
    yazi = "yazi.desktop";
  }.${cfg.fileManager};

  mailClientDesktopId = {
    thunderbird = "thunderbird.desktop";
  }.${cfg.mailClient};
in {
  options.${namespace}.defaults = {
    editor = mkOption {
      type = enum [ "nano" "nvim" "zed" ];
      default = "nano";
      description = "Default editor for text manipulation";
      example = "nvim";
    };

    shell = mkOption {
      type = enum [ "fish" "zsh" "bash" ];
      default = "zsh";
      description = "Default shell";
      example = "zsh";
    };

    terminal = mkOption {
      type = enum [ "ghostty" "alacritty" ];
      default = "ghostty";
      description = "Default terminal";
      example = "ghostty";
    };

    browser = mkOption {
      type = enum [ "chrome" "helium" "ladybird" "zen" ];
      default = "zen";
      description = "Default browser";
      example = "zen";
    };

    fileManager = mkOption {
      type = enum [ "dolphin" "yazi" ];
      default = "dolphin";
      description = "Default (graphical) file manager";
      example = "dolphin";
    };

    mailClient = mkOption {
      type = enum [ "thunderbird" ];
      default = "thunderbird";
      description = "Default mail client, for mailto: links";
      example = "thunderbird";
    };
  };

  config = {
    home.sessionVariables = {
      SHELL = cfg.shell;
      EDITOR = cfg.editor;
      TERMINAL = cfg.terminal;
      BROWSER = cfg.browser;
    };

    xdg.mimeApps = {
      enable = true;
      defaultApplications =
        genAttrs [ "text/html" "application/xhtml+xml" "x-scheme-handler/http" "x-scheme-handler/https" ] (_: browserDesktopId)
        // genAttrs [ "application/x-terminal-emulator" "x-scheme-handler/terminal" ] (_: terminalDesktopId)
        // { "inode/directory" = fileManagerDesktopId; }
        // { "x-scheme-handler/mailto" = mailClientDesktopId; };
    };

    # users.defaultUserShell = pkgs.${cfg.shell};
  };
}
