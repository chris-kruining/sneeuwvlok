{ lib, namespace, config, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.hardware.has.bluetooth;
in
{
  options.${namespace}.hardware.has.bluetooth = mkEnableOption "Enable bluetooth";

  config = mkIf cfg {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General.Experimental = true; # Show battery charge of Bluetooth devices
      };
    };

    services.pipewire.wireplumber.extraConfig.bluetoothEnhancements = {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        # a2dp is the stereo music profile, without it headsets only get mono hsp/hfp
        "bluez5.roles" = [ "a2dp_sink" "a2dp_source" "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
      };

      # A connected headset always becomes the default in- and output: it gets the highest priority
      # and remembered/manual defaults are dropped so they can't outrank it.
      "monitor.bluez.rules" = [
        {
          matches = [ { "node.name" = "~bluez_output.*"; } ];
          actions.update-props."priority.session" = 3000;
        }
      ];

      # the headset mic (bluez_input loopback) is hardcoded at 2010, keep usb mics just below it
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_input.usb-*"; } ];
          actions.update-props."priority.session" = 2005;
        }
      ];

      "wireplumber.settings"."node.restore-default-targets" = false;

      "wireplumber.components" = [
        {
          name = "sneeuwvlok/bluez-take-default.lua";
          type = "script/lua";
          provides = "custom.bluez-take-default";
        }
      ];
      "wireplumber.profiles".main."custom.bluez-take-default" = "required";
    };

    services.pipewire.wireplumber.extraScripts."sneeuwvlok/bluez-take-default.lua" = ''
      -- forget manually picked defaults when a bluetooth device appears so priority decides
      SimpleEventHook {
        name = "sneeuwvlok/bluez-take-default",
        interests = {
          EventInterest {
            Constraint { "event.type", "=", "node-added" },
            Constraint { "node.name", "#", "bluez_*", type = "pw-global" },
            Constraint { "media.class", "#", "Audio/S*", type = "pw-global" },
          },
        },
        execute = function (event)
          local om = event:get_source ():call ("get-object-manager", "metadata")
          local metadata = om:lookup { Constraint { "metadata.name", "=", "default" } }
          if metadata then
            metadata:set (0, "default.configured.audio.sink", nil, nil)
            metadata:set (0, "default.configured.audio.source", nil, nil)
          end
        end
      }:register ()
    '';
  };
}
