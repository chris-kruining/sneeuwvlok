{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkMerge mkEnableOption mkOption types optionals;

  cfg = config.${namespace}.services.home-automation.matter;
  thread = cfg.thread.radio != null;
in {
  options.${namespace}.services.home-automation.matter = {
    enable = mkEnableOption "Matter, devices on the network are paired in home assistant through a local matter server";

    interface = mkOption {
      type = types.str;
      example = "enp2s0";
      description = ''
        The network interface to the LAN, matter finds its devices on it and thread routes its mesh to it
      '';
    };

    port = mkOption {
      type = types.port;
      default = 5580;
      description = ''
        The port the matter server listens on, only on localhost since home assistant runs on the same machine
      '';
    };

    thread.radio = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_...-if00-port0";
      description = ''
        The serial device of the thread radio, flashed with OpenThread RCP firmware. Prefer the /dev/serial/by-id
        path, the ttyUSB numbering changes with the order the sticks are found in. Without it there is no thread,
        and only matter devices on wifi or ethernet can be paired.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Matter.js is the successor of the python matter server, home assistant talks to it the same way
      services.matterjs-server = {
        enable = true;
        inherit (cfg) port;
        extraArgs = ["--primary-interface=${cfg.interface}"];
      };

      # Matter devices are found and announce themselves over mDNS, the multicast answers don't belong to a
      # connection the firewall knows
      networking.firewall.interfaces.${cfg.interface}.allowedUDPPorts = [5353];

      # The matter server is added once in the UI, at ws://127.0.0.1:<port>/ws
      services.home-assistant.extraComponents = ["matter"] ++ optionals thread ["thread" "otbr"];
    }

    (mkIf thread {
      # The border router is added once in the UI, at http://127.0.0.1:8081
      services.openthread-border-router = {
        enable = true;
        backboneInterfaces = [cfg.interface];
        radio.device = cfg.thread.radio;
      };
    })
  ]);
}
