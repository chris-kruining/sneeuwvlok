{ pkgs, config, lib, namespace, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) enum;

  cfg = config.${namespace}.defaults;
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
      type = enum [ "chrome" "ladybird" "zen" ];
      default = "zen";
      description = "Default terminal";
      example = "zen";
    };
  };

  config = {
    home.sessionVariables = {
      EDITOR = cfg.editor;
      TERMINAL = cfg.terminal;
      BROWSER = cfg.browser;
    };

    # home.shell = pkgs.${cfg.shell};
  };
}
