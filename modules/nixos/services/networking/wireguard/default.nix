{
  config,
  pkgs,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkMerge mkDefault mkEnableOption mkOption types filterAttrs mapAttrs' mapAttrsToList nameValuePair unique toUpper replaceStrings concatStringsSep concatMapStrings optionalAttrs;

  cfg = config.${namespace}.services.networking.wireguard;
  tunnels = filterAttrs (_: t: t.enable) cfg.tunnels;
  nmcli = "${config.networking.networkmanager.package}/bin/nmcli";

  keyVariable = name: "WG_${toUpper (replaceStrings ["-"] ["_"] name)}_PRIVATE_KEY";
  restartUnits = ["NetworkManager-ensure-profiles.service"];

  # Brings the tunnel up whenever the machine is online but not on one of the `awayFrom` networks, and down when it is
  awayScript = name: t:
    pkgs.writeShellScript "wireguard-${name}-when-away" ''
      interface=$1
      action=$2

      case "$interface" in ${t.interface} | lo) exit 0 ;; esac
      case "$action" in up | down | connectivity-change) ;; *) exit 0 ;; esac

      active=false
      ${nmcli} -t -f NAME connection show --active | grep -qxF '${t.displayName}' && active=true

      home=false
      ssid=$(${nmcli} -t -f active,ssid device wifi | sed -n 's/^yes://p')
      ${concatMapStrings (s: "[ \"$ssid\" = '${s}' ] && home=true\n") t.autoConnect.awayFrom}
      if [ "$home" = true ]; then
        [ "$active" = true ] && ${nmcli} connection down '${t.displayName}'
      elif [ "$active" = false ] && [ "$(${nmcli} networking connectivity)" = full ]; then
        # Only with full connectivity, behind a captive portal the endpoint isn't reachable yet
        ${nmcli} connection up '${t.displayName}'
      fi
      exit 0
    '';
in {
  options.${namespace}.services.networking.wireguard = {
    tunnels = mkOption {
      default = {};
      description = "Wireguard tunnels to other networks, as networkmanager profiles so they also show in plasma's network applet";
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          enable = mkEnableOption "the ${name} tunnel";

          displayName = mkOption {
            type = types.str;
            default = name;
            description = "The connection's name in networkmanager";
          };

          interface = mkOption {
            type = types.str;
            default = "wg-${name}";
            description = "The tunnel's network interface";
          };

          address = mkOption {
            type = types.str;
            example = "192.168.2.3/32";
            description = "This machine's address inside the tunnel, every machine needs its own";
          };

          privateKey = mkOption {
            type = types.str;
            default = "wireguard/private_key";
            description = "The sops secret with this machine's wireguard private key";
          };

          peer = {
            publicKey = mkOption {
              type = types.str;
              description = "The other end's public key";
            };

            endpoint = mkOption {
              type = types.str;
              example = "203.0.113.1:51820";
              description = "Where the other end listens";
            };

            allowedIPs = mkOption {
              type = types.listOf types.str;
              description = "The networks routed through the tunnel";
            };
          };

          dns = {
            servers = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "DNS servers to use while the tunnel is up";
            };

            domains = mkOption {
              type = types.listOf types.str;
              default = [];
              description = ''
                Domains resolved through the tunnel's dns servers. resolved also only asks dns for bare names when
                there is a search domain, so these double as the search domains for bare names
              '';
            };

            # Negative: only the tunnel's servers answer while it's up, so its names resolve
            priority = mkOption {
              type = types.int;
              default = -50;
              description = "Networkmanager's dns-priority, negative to make the tunnel's servers the only ones used";
            };
          };

          autoConnect.awayFrom = mkOption {
            type = types.listOf types.str;
            default = [];
            example = ["Home wifi"];
            description = ''
              Wifi networks (ssids) the tunnel leads to. When set, the tunnel comes up by itself while online
              anywhere else and goes down on these. Empty leaves connecting to you
            '';
          };
        };
      }));
    };
  };

  config = mkMerge [
    {
      # The home network, through the router's wireguard server. Machines enable it and set their own address
      ${namespace}.services.networking.wireguard.tunnels.thuis = {
        displayName = mkDefault "Thuis";
        peer = {
          publicKey = mkDefault "fSVwNAtCleCcxfn/dy47KIXpFZnIDS3kRHFF+F/IFBo=";
          endpoint = mkDefault "192.145.59.8:51820";
          allowedIPs = mkDefault ["192.168.0.0/20"];
        };
        dns = {
          servers = mkDefault ["192.168.2.1"];
          # `amarth.cloud` too: the router answers with ulmo's home address, its public one doesn't answer from inside every network
          domains = mkDefault ["arda" "amarth.cloud"];
        };
        autoConnect.awayFrom = mkDefault ["Varkensstal"];
      };
    }

    (mkIf (tunnels != {}) {
      sops = {
        secrets = lib.genAttrs (unique (mapAttrsToList (_: t: t.privateKey) tunnels)) (_: {inherit restartUnits;});

        templates."wireguard/tunnels.env" = {
          inherit restartUnits;
          content = concatStringsSep "\n" (mapAttrsToList (name: t: "${keyVariable name}=${config.sops.placeholder.${t.privateKey}}") tunnels) + "\n";
        };
      };

      networking.networkmanager.ensureProfiles = {
        environmentFiles = [config.sops.templates."wireguard/tunnels.env".path];

        profiles = mapAttrs' (name: t:
          nameValuePair name ({
              connection = {
                id = t.displayName;
                type = "wireguard";
                interface-name = t.interface;
                autoconnect = false;
              };

              wireguard.private-key = "$" + keyVariable name;

              "wireguard-peer.${t.peer.publicKey}" = {
                inherit (t.peer) endpoint;
                allowed-ips = concatMapStrings (ip: "${ip};") t.peer.allowedIPs;
              };

              ipv4 = {
                method = "manual";
                address1 = t.address;
              }
              // optionalAttrs (t.dns.servers != []) {
                dns = concatMapStrings (s: "${s};") t.dns.servers;
                dns-priority = t.dns.priority;
              }
              // optionalAttrs (t.dns.domains != []) {
                dns-search = concatMapStrings (d: "${d};") t.dns.domains;
              };

              ipv6.method = "disabled";
            }))
        tunnels;
      };

      networking.networkmanager.dispatcherScripts =
        mapAttrsToList (name: t: {source = awayScript name t;})
        (filterAttrs (_: t: t.autoConnect.awayFrom != []) tunnels);
    })
  ];
}
