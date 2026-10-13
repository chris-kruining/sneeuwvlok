{
  pkgs,
  config,
  lib,
  namespace,
  inputs,
  system,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) mkIf mkMerge mkEnableOption mkOption types elem;

  cfg = config.${namespace}.services.media.jellyfin;
  acceleration = config.${namespace}.hardware.video.acceleration;
  decodes = codec: elem codec acceleration.decode;
  encodes = codec: elem codec acceleration.encode;

  pluginsDir = "${config.services.jellyfin.dataDir}/plugins";
  plugins = with pkgs.${namespace}; [
    jellyfin-plugin-sso
  ];

  domain = "jellyfin.kruining.eu";

  zitadel = config.${namespace}.services.authentication.zitadel;
  project = zitadel.organization.nix.project.ulmo;
  oidc = project.application.jellyfin;

  # The plugin's name for the provider, it's part of the redirect uri
  provider = "zitadel";
  # Every role of jellyfin's group may sign in, the `_admin` ones also make you an administrator
  roles = project.role |> lib.filterAttrs (_: role: role.group == "jellyfin") |> lib.attrNames;
  adminRoles = lib.filter (lib.hasSuffix "_admin") roles;
  rolesClaim = "urn:zitadel:iam:org:project:roles";

  # .NET's XmlSerializer writes a string[] as <string> elements
  strings = values: values |> lib.map (value: "<string>${value}</string>") |> lib.concatStrings;
in {
  options.${namespace}.services.media.jellyfin = {
    enable = mkEnableOption "Enable jellyfin server";
  };

  config = mkIf cfg.enable {
    ${namespace}.services = {
      networking.caddy = {
        hosts = {
          ${domain} = ''
            reverse_proxy http://[::1]:8096
          '';
        };
      };

      # SSO-Auth's configuration, rendered by tofu-zitadel so the client secret never leaves the machine
      authentication.zitadel.organization.nix.project.ulmo.application.jellyfin = {
        redirectUris = ["https://${domain}/sso/OID/redirect/${provider}"];
        restartUnits = ["jellyfin.service"];

        files."SSO-Auth.xml" = {
          clientId,
          clientSecret,
        }: ''
          <?xml version="1.0" encoding="utf-8"?>
          <PluginConfiguration>
            <SamlConfigs />
            <OidConfigs>
              <item>
                <key>
                  <string>${provider}</string>
                </key>
                <value>
                  <PluginConfiguration>
                    <OidEndpoint>${zitadel.issuer}</OidEndpoint>
                    <OidClientId>${clientId}</OidClientId>
                    <OidSecret>${clientSecret}</OidSecret>
                    <Enabled>true</Enabled>
                    <EnableAuthorization>true</EnableAuthorization>
                    <EnableAllFolders>true</EnableAllFolders>
                    <EnabledFolders />
                    <AdminRoles>${strings adminRoles}</AdminRoles>
                    <!-- Only ever grants admin, so a missing role claim can't lock out the admins -->
                    <PreserveAdminPermissions>true</PreserveAdminPermissions>
                    <Roles>${strings roles}</Roles>
                    <!-- Zitadel's own roles claim, an object keyed by the roles of the client's project -->
                    <RoleClaim>${rolesClaim}</RoleClaim>
                    <OidScopes>${strings ["openid" "email" "profile" rolesClaim]}</OidScopes>
                    <DefaultProvider>Jellyfin.Server.Implementations.Users.DefaultAuthenticationProvider</DefaultProvider>
                    <SchemeOverride>https</SchemeOverride>
                    <NewPath>true</NewPath>
                    <DefaultUsernameClaim>preferred_username</DefaultUsernameClaim>
                    <!-- Which jellyfin user someone signs in as, keyed by their username in zitadel.
                         The plugin rekeys them by `sub` on their next login. -->
                    <CanonicalLinks>
                      %{ for name, id in jsondecode(file("${config.sops.secrets."jellyfin/links".path}")) ~}
                      <item><key><string>''${name}</string></key><value><guid>''${id}</guid></value></item>
                      %{ endfor ~}
                    </CanonicalLinks>
                  </PluginConfiguration>
                </value>
              </item>
            </OidConfigs>
            <EnforceSsoOnly>false</EnforceSsoOnly>
          </PluginConfiguration>
        '';
      };
    };

    environment.systemPackages = with pkgs; [
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
      mediainfo
      id3v2
      yt-dlp
    ];

    services = {
      # port is harcoded in nixpkgs module
      jellyfin = mkMerge [
        {
          enable = true;
          openFirewall = true;
          user = "media";
          group = "media";
        }

        # Transcode with whatever the hardware offers. Nix owns the transcoding settings,
        # changes made to them in the dashboard are overwritten on restart.
        (mkIf (acceleration != null) {
          forceEncodingConfig = true;

          hardwareAcceleration = {
            enable = true;
            type = acceleration.api;
            device = acceleration.device;
          };

          transcoding = {
            enableHardwareEncoding = true;
            enableIntelLowPowerEncoding = acceleration.lowPower;
            enableToneMapping = acceleration.toneMapping;

            hardwareDecodingCodecs = {
              mpeg2 = decodes "mpeg2";
              vc1 = decodes "vc1";
              h264 = decodes "h264";
              hevc = decodes "hevc";
              hevc10bit = decodes "hevc-10bit";
              hevcRExt10bit = decodes "hevc-rext-10bit";
              hevcRExt12bit = decodes "hevc-rext-12bit";
              vp8 = decodes "vp8";
              vp9 = decodes "vp9";
              av1 = decodes "av1";
            };

            hardwareEncodingCodecs = {
              hevc = encodes "hevc";
              av1 = encodes "av1";
            };
          };
        })
      ];
    };

    systemd.services.jellyfin = {
      # Jellyfin writes its own state into a plugin's directory (meta.json), so they're copied in instead of linked.
      # Any other install of the same plugin (by guid, the directory name changed between forks) is removed.
      # Before nixpkgs' own preStart, which exits early when encoding.xml is unchanged.
      preStart = lib.mkBefore ''
        mkdir -p "${pluginsDir}/configurations"

        ${
          plugins
          |> lib.map (plugin: ''
              for dir in "${pluginsDir}"/*/; do
              dir="''${dir%/}"
              if [ "$dir" != "${pluginsDir}/${plugin.directory}" ] && grep -qs '"${plugin.guid}"' "$dir/meta.json"; then
                echo "removing $dir, it is replaced by ${plugin.directory}"
                rm -rf "$dir"
              fi
            done

            if [ ! -d "${pluginsDir}/${plugin.directory}" ]; then
              cp -r --no-preserve=mode ${plugin} "${pluginsDir}/${plugin.directory}"
            fi
          '')
          |> lib.join "\n"
        }

        # The plugin writes to its configuration itself, so it's installed instead of linked
        install -m 0600 "$CREDENTIALS_DIRECTORY/SSO-Auth.xml" "${pluginsDir}/configurations/SSO-Auth.xml"
      '';

      serviceConfig = {
        LoadCredential = ["SSO-Auth.xml:${oidc.directory}/SSO-Auth.xml"];
        killSignal = lib.mkForce "SIGKILL";
      };
    };

    # A JSON map of zitadel username to jellyfin user id, read by tofu-zitadel into SSO-Auth.xml
    sops.secrets."jellyfin/links" = {
      owner = "zitadel";
      group = "zitadel";
      restartUnits = ["tofu-zitadel.service"];
    };
  };
}
