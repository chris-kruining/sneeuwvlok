{ config, lib, pkgs, user, ... }:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  inherit (builtins) fetchurl;

  cfg = config.modules.${user}.desktop.browsers.chrome;
in {
  options.modules.${user}.desktop.browsers.chrome = {
    enable = mkEnableOption "Enable Chrome";
  };

  config = mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [
      pkgs.chromium
      # (pkgs.ungoogled-chromium.override {
      #   commandLineArgs = [
      #     "--enable-features=AcceleratedVideoEncoder"
      #     "--ignore-gpu-blocklist"
      #     "--enable-zero-copy"
      #     "--ozone-platform-hint=auto"
      #     "--password-store=basic"
      #   ];
      # })
    ];

    programs.chromium = {
      enable = true;
      enablePlasmaBrowserIntegration = true;
      extensions = let
        # create_extension_for = browserVersion: { id, sha256, version }: {
        #   inherit id;
        #   crxPath = fetchurl {
        #     url = "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=${browserVersion}&x=id%3D${id}%26installsource%3Dondemand%26uc";
        #     name = "${id}.crx";
        #     inherit sha256;
        #   };
        #   inherit version;
        # };
        # create_extension = create_extension_for (lib.versions.major pkgs.ungoogled-chromium.version);
      in [
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # UBlock origin
        "mnjggcdmjocbbbhaepdhchncahnbgone" # Sponsor block
        "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark reader
        "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
        # (create_extension {
        #   id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; # UBlock origin
        #   sha256 = "sha256:1lnk0k8zy0w33cxpv93q1am0d7ds2na64zshvbwdnbjq8x4sw5p6";
        #   version = "1.63.2";
        # })
        # (create_extension {
        #   id = "mnjggcdmjocbbbhaepdhchncahnbgone"; # Sponsor block
        #   sha265 = "";
        #   version = "";
        # })
        # (create_extension {
        #   id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; # Dark reader
        #   sha265 = "";
        #   version = "";
        # })
        # (create_extension {
        #   id = "nngceckbapebfimnlniiiahkandclblb"; # Bitwarden
        #   sha265 = "";
        #   version = "";
        # })
      ];
      defaultSearchProviderEnabled = true;
      defaultSearchProviderSearchURL = "https://duckduckgo.com?q={searchTerms}";
      extraOpts = {
        "ExtensionManifestV2Availability" = 2;
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
