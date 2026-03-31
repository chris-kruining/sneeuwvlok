{
  config,
  lib,
  pkgs,
  settings,
  port,
  ...
}: {
  clan.core.vars.generators.sabnzbd = {
    files = {
      "api_key" = {
        secret = true;
        deploy = true;
      };
      "nzb_key" = {
        secret = true;
        deploy = true;
      };
      "config.ini" = {
        secret = true;
        deploy = true;
        owner = "sabnzbd";
        group = "media";
        mode = "0660";
      };
    };

    prompts = {
      username = {
        description = "usenet username";
        type = "hidden";
        persist = true;
      };
      password = {
        description = "usenet password";
        type = "hidden";
        persist = true;
      };
    };

    runtimeInputs = with pkgs; [pwgen];

    script = ''
      pwgen -s 128 1 > $out/api_key
      pwgen -s 128 1 > $out/nzb_key

      cat << EOF > $out/config.ini
      [misc]
      api_key = $(cat $out/api_key)
      nzb_key = $(cat $out/nzb_key)

      [servers]
      [[news.sunnyusenet.com]]
      username = $(cat $prompts/username)
      password = $(cat $prompts/password)
      EOF
    '';
  };

  services.sabnzbd = {
    enable = true;
    openFirewall = true;

    allowConfigWrite = false;
    configFile = lib.mkForce null;

    secretFiles = [
      config.clan.core.vars.generators.sabnzbd.files."config.ini".path
    ];

    settings = {
      misc = {
        host = "0.0.0.0";
        port = port;
        host_whitelist = "${config.networking.hostName}";

        download_dir = "/var/media/downloads/incomplete";
        complete_dir = "/var/media/downloads/done";
      };

      servers = {
        "news.sunnyusenet.com" = {
          name = "news.sunnyusenet.com";
          displayname = "news.sunnyusenet.com";
          host = "news.sunnyusenet.com";
          port = 563;
          timeout = 60;
        };
      };
    };

    user = "sabnzbd";
    group = "media";
  };
}
