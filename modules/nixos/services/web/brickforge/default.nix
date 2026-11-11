{
  config,
  lib,
  namespace,
  inputs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types;

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

    # Only on the LAN and the VPN for now, brickforge.kruining.eu gets a caddy host once it is public
    networking.firewall.allowedTCPPorts = [cfg.port];
  };
}
