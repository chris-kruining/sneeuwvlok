{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (builtins) length;
  inherit (lib) mkIf mkEnableOption mkOption types attrNames attrsToList listToAttrs;

  cfg = config.sneeuwvlok.services.networking.wireguard;
  hasPeers = (cfg.peer |> attrNames |> length) > 0;
in {
  options.sneeuwvlok.services.networking.wireguard = {
    # enable = mkEnableOption "enable wireguard" // {default = true;};

    peer = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          port = mkOption {
            type = types.port;
            description = '''';
          };

          address = mkOption {
            type = types.listOf types.str;
            default = [];
            description = '''';
          };
        };
      });
      default = {};
    };
  };

  config = mkIf hasPeers {
    # networking.firewall.allowedUDPPorts = cfg.peer |> lib.attrValues |> lib.map (p: p.port);
    # networking.wq-quick = {
    #   # enable = cfg.enable;

    #   interfaces =
    #     cfg.peer
    #     |> attrsToList
    #     |> imap0 (i: { name, value }: (namevaluepair "wg${i}" (value // {})))
    #     |> listToAttrs;
    # };
  };
}
