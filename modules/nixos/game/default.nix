{ config, lib, namespace, ... }:
let
  inherit (lib) any attrValues concatMapStrings mkIf mkMerge;

  # The games are home-manager modules, a user's home can't open the firewall, so it opens here when any user plays one
  playing = game: any (home: home.${namespace}.game.${game}.enable or false) (attrValues config.home-manager.users);
in
{
  config = mkMerge [
    # Games on 7777 and their queries on 7778. The LAN browser broadcasts to 8777-8786 from a random port, and the
    # servers answer from theirs to that port. The firewall doesn't take an answer to a broadcast for a reply, so
    # answers from the beacon ports on the local network are let in
    (mkIf (playing "ut1999") {
      networking.firewall = {
        allowedUDPPortRanges = [
          { from = 7777; to = 7778; }
          { from = 8777; to = 8786; }
        ];
        extraCommands = concatMapStrings (network: ''
          iptables -A nixos-fw -p udp -s ${network} --sport 8777:8786 -j nixos-fw-accept
        '') [ "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" ];
      };
    })

    # Games on 7777 and their queries on 7778, the LAN browser asks on 10777 and gets its answers on 11777
    (mkIf (playing "ut2004") {
      networking.firewall.allowedUDPPortRanges = [
        { from = 7777; to = 7778; }
      ];
      networking.firewall.allowedUDPPorts = [ 10777 11777 ];
    })
  ];
}
