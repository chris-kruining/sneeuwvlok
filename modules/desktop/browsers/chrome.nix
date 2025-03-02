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

  config =  mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (ungoogled-chromium.override {
        commandLineArgs = [
          "--enable-features=AcceleratedVideoEncoder"
          "--ignore-gpu-blocklist"
          "--enable-zero-copy"
        ];
      });
    ];

    programs.chromium = {
      enable = true;
      package = pkgs.ungoogled-chromium;
      extensions =
        let
          createChromiumExtensionFor = browserVersion: { id, sha256, version }:
            {
              inherit id;
              crxPath = builtins.fetchurl {
                url = "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=${browserVersion}&x=id%3D${id}%26installsource%3Dondemand%26uc";
                name = "${id}.crx";
                inherit sha256;
              };
              inherit version;
            };
          createChromiumExtension = createChromiumExtensionFor (lib.versions.major package.version);
        in
        [
          (createChromiumExtension {
            # ublock origin
            id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";
            sha256 = "sha256-u81DNkZw/LBVyjk5nmrrJEVjdc+GFCay+rQZGpDH3jA=";
            version = "1.62.0";
          })
          (createChromiumExtension {
            # dark reader
            id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
            sha256 = "sha256-JcM2Ki3cTWdskFEFs2jk6LQUTFOojkBf+6HqO1GPK90=";
            version = "4.9.34";
          })
        ];
    };
  };
}
