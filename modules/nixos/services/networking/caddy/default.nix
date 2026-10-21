{
  config,
  pkgs,
  lib,
  namespace,
  ...
}: let
  inherit (builtins) length;
  inherit (lib) mkIf mkEnableOption mkOption types attrNames mapAttrs replaceStrings optionalString elem;

  cfg = config.${namespace}.services.networking.caddy;
  hasHosts = (cfg.hosts |> attrNames |> length) > 0;

  # The OWASP core rule set, its matches end up in caddy's log and from there in loki.
  # Coraza wraps the response and loses the 101 of a websocket upgrade, the client then gets the first frame where it
  # expects the handshake and gives up. Upgrades are a GET without a body and coraza doesn't read the frames after it,
  # so they skip the waf. Only a real upgrade: a bare `Upgrade` header is something any request can carry
  waf = ''
    @waf not {
      method GET
      header_regexp Connection (?i)\bupgrade\b
      header_regexp Upgrade (?i)^websocket$
      not header Content-Length *
      not header Transfer-Encoding *
    }
    coraza_waf @waf {
      load_owasp_crs
      directives `
        Include @coraza.conf-recommended
        Include @crs-setup.conf.example

        # The apis behind caddy use more than the methods and content types of plain forms
        SecAction "id:900200,phase:1,pass,t:none,nolog,setvar:'tx.allowed_methods=GET HEAD POST OPTIONS PUT PATCH DELETE'"
        SecAction "id:900220,phase:1,pass,t:none,nolog,setvar:'tx.allowed_request_content_type=|application/x-www-form-urlencoded| |multipart/form-data| |multipart/related| |text/xml| |application/xml| |application/soap+xml| |application/json| |application/cloudevents+json| |application/cloudevents-batch+json| |application/grpc| |application/grpc-web| |application/proto| |application/connect+proto| |application/octet-stream|'"

        # Protobuf (zitadel's grpc, forgejo's runners) is binary, read as a form it is full of null bytes and line breaks
        SecRule REQUEST_HEADERS:Content-Type "@rx ^application/(?:grpc|proto|connect\+proto)(?:[+;]|$)" "id:10000,phase:1,pass,t:none,nolog,ctl:requestBodyAccess=Off"
        # Jellyfin's clients send application/json; profile="PascalCase"
        SecRule REQUEST_HEADERS:Content-Type "@rx ^application/json; profile=\"?[A-Za-z]+\"?$" "id:10001,phase:1,pass,t:none,nolog,ctl:ruleRemoveById=920470"
        # Uploads to matrix carry the type of the uploaded file
        SecRule REQUEST_FILENAME "@beginsWith /_matrix/media/" "id:10002,phase:1,pass,t:none,nolog,ctl:ruleRemoveById=920420"
        # Sliding sync asks for the extension org.matrix.msc4262.profiles, which looks like a request for .profile
        SecRule REQUEST_FILENAME "@rx ^/_matrix/client/[^/]+/org\.matrix\.simplified_msc3575/sync$" "id:10003,phase:1,pass,t:none,nolog,ctl:ruleRemoveTargetById=930120;ARGS_NAMES"

        Include @owasp_crs/*.conf
        SecRuleEngine ${if cfg.waf.block then "On" else "DetectionOnly"}
        # Only the start of large uploads is inspected, the rest is passed on as is
        SecRequestBodyLimitAction ProcessPartial
        # Responses would have to be buffered, which breaks streaming
        SecResponseBodyAccess Off
        # The matched rules are logged already, the audit log adds nothing
        SecAuditEngine Off
      `
    }
  '';

  hasWaf = host: cfg.waf.enable && !(elem host cfg.waf.exclude);
in {
  options.${namespace}.services.networking.caddy = {
    enable = mkEnableOption "enable caddy" // {default = true;};

    hosts = mkOption {
      type = types.attrsOf types.str;
    };

    extraConfig = mkOption {
      type = types.str;
    };

    waf = {
      enable = mkEnableOption "inspecting the requests of every host with the OWASP core rule set, by coraza";

      block = mkEnableOption ''
        blocking the requests the rules match, instead of only logging them. Watch the matches for false positives
        before turning this on
      '';

      exclude = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["example.com"];
        description = ''
          Hosts, as they appear in `hosts`, the waf leaves alone.
        '';
      };
    };
  };

  config = mkIf hasHosts {
    networking.firewall.allowedTCPPorts = [80 443];

    services.caddy = {
      enable = cfg.enable;

      package = pkgs.caddy.withPlugins {
        plugins = ["github.com/corazawaf/coraza-caddy/v2@v2.1.0"];
        hash = "sha256-LhCmRyJtJw5GFXtMajZI8+Q0V4nbzvUEuARSdnpoax4=";
      };

      # Request metrics per host, scraped by prometheus on the admin endpoint
      globalConfig = ''
        metrics {
          per_host
        }
      ''
      + optionalString cfg.waf.enable ''

        # The waf sees every request before anything else handles it
        order coraza_waf first
      '';

      virtualHosts =
        cfg.hosts
        |> mapAttrs (host: extraConfig: {
          extraConfig = optionalString (hasWaf host) waf + extraConfig;

          # Same as the default, but readable by the caddy group so alloy can ship them to loki
          logFormat = ''
            output file ${config.services.caddy.logDir}/access-${replaceStrings ["/" " "] ["_" "_"] host}.log {
              mode 0640
            }
          '';
        });
    };

    # Caddy keeps the mode of log files that already exist
    systemd.tmpfiles.rules = ["z ${config.services.caddy.logDir}/access-*.log 0640 caddy caddy -"];
  };
}
