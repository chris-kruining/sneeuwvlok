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

    thread.baudRate = mkOption {
      type = types.ints.positive;
      default = 460800;
      description = ''
        The baud rate of the thread radio, the OpenThread RCP builds for the sonoff and nabu casa sticks run at 460800.
        The firmware's file name says which it is, like `..._no_flow_460800.gbl`.
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
      # The thread devices sleep and only report when something happens, a subscription can be quiet for up to 30
      # minutes. The matter server listens on a random port, so after the firewall forgets the connection (2 minutes for
      # udp) a report like a button press was dropped. The device gives up on its subscription and its events are lost
      # until the server notices, a quarter of an hour later. The mesh is only reachable through the border router, so
      # everything coming in from it is trusted.
      networking.firewall.trustedInterfaces = [config.services.openthread-border-router.interfaceName];

      # The border router is added once in the UI, at http://127.0.0.1:8081
      services.openthread-border-router = {
        enable = true;
        backboneInterfaces = [cfg.interface];
        radio = {
          device = cfg.thread.radio;
          inherit (cfg.thread) baudRate;
        };
      };
    })
  ]);
}
