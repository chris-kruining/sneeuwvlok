{ inputs, system, config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.application.helium;
in
{
  options.${namespace}.application.helium = {
    enable = mkEnableOption "enable helium";
  };

  # Helium reads chromium's policy and native messaging dirs under /etc, the system side (e.g. himmelblau's sso extension) goes there
  config = mkIf cfg.enable {
    home.packages = [
      inputs.helium.packages.${system}.helium
    ];
  };
}
