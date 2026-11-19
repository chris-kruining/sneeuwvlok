{
  config,
  lib,
  namespace,
  inputs,
  ...
}: let
  inherit (lib) toString mkIf mkEnableOption mkOption types;

  cfg = config.${namespace}.services.web.brickforge;
in {
  imports = [
    inputs.brickforge.nixosModules.site
  ];

  options.${namespace}.services.web.brickforge = {
    enable = mkEnableOption "BrickForge's website";

    port = mkOption {
      type = types.port;
      default = 7000;
      description = ''
        The port the site listens on
      '';
    };
  };

  config = mkIf cfg.enable {
    # The site comes from the `brickforge` input, it goes live once that input is bumped in flake.lock
    services.brickforge-site = {
      enable = true;
      address = "0.0.0.0";
      inherit (cfg) port;
    };

    # Public as brickforge.kruining.eu, the port stays open for the LAN and the VPN
    networking.firewall.allowedTCPPorts = [cfg.port];

    ${namespace}.services.networking.caddy = {
      hosts = {
        # The site listens on ipv4 only
        "brickforge.kruining.eu" = ''
          reverse_proxy http://127.0.0.1:${toString cfg.port}
        '';
      };
    };
  };
}
