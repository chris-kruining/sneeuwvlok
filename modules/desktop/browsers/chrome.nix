{ inputs, options, config, lib, pkgs, ... }:
let
  inherit (builtins) toJSON;
  inherit (lib.attrsets) attrValues mapAttrsToList;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.strings) concatStrings;

  cfg = config.modules.desktop.browsers.chrome;
in {
  options.modules.desktop.browsers.chrome = let
    inherit (lib.options) mkEnableOption;
    inherit (lib.types) attrsOf oneOf bool int lines str;
    inherit (lib.my) mkOpt mkOpt';
  in {
    enable = mkEnableOption "Enable Chrome";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (ungoogled-chromium.override {
        commandLineArgs = [
          "--enable-features=AcceleratedVideoEncoder"
          "--ignore-gpu-blocklist"
          "--enable-zero-copy"
          "--ozone-platform-hint=auto"
        ];
      })
    ];

    programs.chromium = {
      enable = true;
      enablePlasmaBrowserIntegration = true;
      extensions = [
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # UBlock origin
        "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark reader
        "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
      ];
      defaultSearchProviderEnabled = true;
      defaultSearchProviderSearchURL = "https://duckduckgo.com?q={searchTerms}";
      extraOpts = {
        "BrowserSignin" = 0;
        "SyncDisabled" = true;
        "PasswordManagerEnabled" = false;
        "SpellcheckEnabled" = true;
        "SpellcheckLanguage" = [
          "nl-NL"
          "en-GB"
        ];
      };
    };
  };
}
