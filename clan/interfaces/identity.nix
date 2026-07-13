{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options = {
    provider = mkOption {
      type = types.nullOr (types.submoduleWith {
        modules = [../types/identity-provider.nix];
      });
      default = null;
    };

    applications = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          displayName = mkOption {
            type = types.str;
            default = name;
          };

          provider = mkOption {
            type = types.nullOr (types.submoduleWith {
              modules = [../types/identity-provider.nix];
            });
            default = null;
          };

          redirectUris = mkOption {
            type = types.listOf types.str;
            default = [];
          };

          postLogoutRedirectUris = mkOption {
            type = types.listOf types.str;
            default = [];
          };

          grantTypes = mkOption {
            type = types.listOf (types.enum ["authorizationCode" "implicit" "refreshToken" "deviceCode" "tokenExchange"]);
            default = ["authorizationCode"];
          };

          responseTypes = mkOption {
            type = types.listOf (types.enum ["code" "idToken" "idTokenToken"]);
            default = ["code"];
          };

          scopes = mkOption {
            type = types.listOf types.str;
            default = ["openid" "profile" "email"];
          };

          exportMap = let
            strOpt = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
          in
            mkOption {
              type = types.submodule {
                options = {
                  client_id = strOpt;
                  client_secret = strOpt;
                };
              };
              default = {};
            };
        };
      }));
      default = {};
    };
  };
}
