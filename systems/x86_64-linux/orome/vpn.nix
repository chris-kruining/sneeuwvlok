{
  config,
  pkgs,
  ...
}: let
  nmcli = "${config.networking.networkmanager.package}/bin/nmcli";

  # Away from home the tunnel comes up by itself, at home it goes down
  homeWifi = "Varkensstal";
in {
  sops = {
    secrets."wireguard/private_key" = {
      restartUnits = ["NetworkManager-ensure-profiles.service"];
    };

    templates."wireguard/thuis.env" = {
      restartUnits = ["NetworkManager-ensure-profiles.service"];
      content = ''
        THUIS_PRIVATE_KEY=${config.sops.placeholder."wireguard/private_key"}
      '';
    };
  };

  # The home network's wireguard server, the router. A networkmanager profile so it also shows in plasma's network applet
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [config.sops.templates."wireguard/thuis.env".path];

    profiles.thuis = {
      connection = {
        id = "Thuis";
        type = "wireguard";
        interface-name = "wg-thuis";
        autoconnect = false;
      };

      wireguard.private-key = "$THUIS_PRIVATE_KEY";

      "wireguard-peer.fSVwNAtCleCcxfn/dy47KIXpFZnIDS3kRHFF+F/IFBo=" = {
        endpoint = "192.145.59.8:51820";
        allowed-ips = "192.168.0.0/20;";
      };

      ipv4 = {
        method = "manual";
        address1 = "192.168.2.3/32";
        dns = "192.168.2.1;";
        # Negative: only the router answers dns while the tunnel is up, so `ulmo` and friends resolve
        dns-priority = -50;
        # resolved only asks dns for bare names with a search domain, and away from home nothing else hands out `arda`
        dns-search = "arda;";
      };

      ipv6.method = "disabled";
    };
  };

  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeShellScript "thuis-when-away" ''
        interface=$1
        action=$2

        case "$interface" in wg-thuis | lo) exit 0 ;; esac
        case "$action" in up | down | connectivity-change) ;; *) exit 0 ;; esac

        active=false
        ${nmcli} -t -f NAME connection show --active | grep -qxF Thuis && active=true

        if ${nmcli} -t -f active,ssid device wifi | grep -qxF 'yes:${homeWifi}'; then
          [ "$active" = true ] && ${nmcli} connection down Thuis
        elif [ "$active" = false ] && [ "$(${nmcli} networking connectivity)" = full ]; then
          # Only with full connectivity, behind a captive portal the endpoint isn't reachable yet
          ${nmcli} connection up Thuis
        fi
        exit 0
      '';
    }
  ];
}
