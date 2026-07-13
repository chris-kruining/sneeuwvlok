{
  ardaLib,
  lib,
  ...
}: let
  inherit (lib) mkIf mkMerge;
in {
  _class = "clan.service";
  manifest = {
    name = "media";
    description = "Generic media service";
    categories = ["Service" "Media"];
    readme = builtins.readFile ./README.md;
    exports = {
      inputs = ["gateway" "identity" "observability" "ports"];
      out = ["gateway" "identity" "observability" "ports"];
    };
  };

  roles.default = {
    description = "Jellyfin media service";
    interface = import ./interface.nix;

    perInstance = {
      settings,
      mkExports,
      machine,
      instanceName,
      exports,
      ...
    }: let
      endpoints = ardaLib.endpoints.forService {
        serviceName = "media";
        inherit exports machine instanceName;
      };

      listeners = endpoints.internal ["jellyfin"];

      user = "media";
      group = "media";
    in {
      exports = mkExports (mkMerge [
        (mkIf (settings.driver == "jellyfin") {
          ports.claims = listeners.claims;

          gateway.services.jellyfin = {
            endpoint = listeners.jellyfin;
          };

          identity.applications.jellyfin = mkIf (settings.identity.provider != null) {
            redirectUris = ["${toString listeners.jellyfin}/sso/OID/redirect/zitadel"];
          };

          observability.metrics.jellyfin.targets = [
            listeners.jellyfin
          ];
        })
      ]);

      nixosModule = {
        config,
        lib,
        pkgs,
        ...
      }: {
        config = mkMerge [
          (mkIf (settings.driver == "jellyfin") {
            environment.systemPackages = with pkgs; [
              jellyfin
              jellyfin-web
              jellyfin-ffmpeg
              mediainfo
              id3v2
              yt-dlp
            ];

            users = {
              users.${user} = {
                isSystemUser = true;
                group = group;
              };
              groups.${group} = {};
            };

            services.jellyfin = {
              enable = true;
              openFirewall = false;
              user = user;
              group = group;
            };

            systemd.services.jellyfin = let
              jellyfinNetworkXml = pkgs.writeText "jellyfin-network.xml" ''
                <?xml version="1.0" encoding="utf-8"?>
                <NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
                  <BaseUrl />
                  <EnableHttps>false</EnableHttps>
                  <RequireHttps>false</RequireHttps>
                  <CertificatePath />
                  <CertificatePassword />
                  <InternalHttpPort>${toString listeners.jellyfin.port}</InternalHttpPort>
                  <InternalHttpsPort>8920</InternalHttpsPort>
                  <PublicHttpPort>${toString listeners.jellyfin.port}</PublicHttpPort>
                  <PublicHttpsPort>8920</PublicHttpsPort>
                  <AutoDiscovery>true</AutoDiscovery>
                  <EnableUPnP>false</EnableUPnP>
                  <EnableIPv4>true</EnableIPv4>
                  <EnableIPv6>true</EnableIPv6>
                  <EnableRemoteAccess>true</EnableRemoteAccess>
                  <LocalNetworkSubnets />
                  <LocalNetworkAddresses />
                  <KnownProxies />
                  <IgnoreVirtualInterfaces>true</IgnoreVirtualInterfaces>
                  <VirtualInterfaceNames>
                    <string>veth</string>
                  </VirtualInterfaceNames>
                  <EnablePublishedServerUriByRequest>false</EnablePublishedServerUriByRequest>
                  <PublishedServerUriBySubnet />
                  <RemoteIPFilter />
                  <IsRemoteIPFilterBlacklist>false</IsRemoteIPFilterBlacklist>
                </NetworkConfiguration>
              '';
            in {
              preStart = lib.mkBefore ''
                configDir=${lib.escapeShellArg config.services.jellyfin.configDir}
                networkXml="$configDir/network.xml"

                if [ -e "$networkXml" ] && ! cmp -s ${jellyfinNetworkXml} "$networkXml"; then
                  cp -p "$networkXml" "$networkXml.backup-$(date -u +"%FT%H_%M_%SZ")"
                fi

                cp -f ${jellyfinNetworkXml} "$networkXml"
                chmod u+w "$networkXml"
              '';

              serviceConfig.killSignal = lib.mkForce "SIGKILL";
            };
          })
        ];
      };
    };
  };
}
