{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    services = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          name = mkOption {
            type = types.str;
            default = name;
          };

          endpoint = mkOption {
            type = types.submoduleWith {
              modules = [../types/endpoint.nix];
            };
            default = {};
            apply = attrs:
              attrs
              // {
                __toString = self: let
                  protocol =
                    if self.protocol != null
                    then "${self.protocol}://"
                    else "";

                  port =
                    if self.port != null
                    then ":${toString self.port}"
                    else "";

                  path =
                    if self.path != null
                    then "/${self.path}"
                    else "";

                  query =
                    if self.query != null
                    then "?${toString self.query
                      |> lib.attrsToList
                      |> lib.map ({
                        name,
                        value,
                      }: "${name}=${value}")}"
                    else "";

                  hash =
                    if self.hash != null
                    then "#${toString self.hash
                      |> lib.attrsToList
                      |> lib.map ({
                        name,
                        value,
                      }: "${name}=${value}")}"
                    else "";
                in "${protocol}${self.host}${port}${path}${query}${hash}";
              };
          };

          # protocol = mkOption {
          #   type = types.str;
          #   default = "http";
          # };

          # host = mkOption {
          #   type = types.str;
          #   default = "[::1]";
          # };

          # port = mkOption {
          #   type = types.port;
          # };
        };
      }));
      default = {};
    };

    functions = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          name = mkOption {
            type = types.str;
            default = name;
          };

          body = mkOption {
            type = types.str;
          };
        };
      }));
      default = {};
    };
  };
}
