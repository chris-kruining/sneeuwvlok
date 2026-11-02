{ inputs, system, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkMerge mkEnableOption genAttrs;

  cfg = config.${namespace}.application.helium;
in
{
  options.${namespace}.application.helium = {
    enable = mkEnableOption "enable helium";
  };

  # Helium reads chromium's policy and native messaging dirs under /etc, the system side (e.g. himmelblau's sso extension) goes there
  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = [
        inputs.helium.packages.${system}.helium
      ];
    }

    (mkIf (config.${namespace}.defaults.browser == "helium") {
      xdg.mimeApps = {
        enable = true;
        defaultApplications = genAttrs [
          "text/html"
          "application/xhtml+xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
        ] (_: "helium.desktop");
      };
    })
  ]);
}
