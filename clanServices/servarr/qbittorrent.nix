{
  config,
  pkgs,
  lib,
  settings,
  port,
  ...
}: {
  clan.core.vars.generators.qbittorrent = let
    hash_password = pkgs.writers.writePython3 "hashPassword" {} ''
      import base64
      import hashlib
      import sys
      import uuid

      password = sys.argv[1]
      salt = uuid.uuid4()
      salt_bytes = salt.bytes

      password = str.encode(password)
      hashed_password = hashlib.pbkdf2_hmac(
          "sha512",
          password,
          salt_bytes,
          100000,
          dklen=64
      )
      b64_salt = base64.b64encode(salt_bytes).decode("utf-8")
      b64_password = base64.b64encode(hashed_password).decode("utf-8")
      password_string = "@ByteArray({salt}:{password})".format(
          salt=b64_salt, password=b64_password
      )
      print(password_string)
    '';
  in {
    files = {
      "password" = {
        secret = true;
        deploy = true;
      };
      "password_hash" = {
        secret = true;
        deploy = true;
      };
      "qBittorrent.conf" = {
        secret = true;
        deploy = true;
        owner = "qbittorrent";
        group = "media";
        mode = "0660";
        restartUnits = ["qbittorrent.service"];
      };
    };

    runtimeInputs = with pkgs; [pwgen hash_password];

    script = ''
      pwgen -s 128 1 > $out/password

      ${hash_password} $(cat $out/password) > $out/password_hash

      cat << EOF > $out/qBittorrent.conf
      [LegalNotice]
      Accepted=true

      [Preferences]
      WebUI\AlternativeUIEnabled=true
      WebUI\RootFolder=${pkgs.vuetorrent}/share/vuetorrent
      WebUI\Username=admin
      WebUI\Password_PBKDF2=$(cat $out/password_hash)
      EOF
    '';
  };

  system.activationScripts.qbittorrent-config = {
    deps = lib.optional (!config.sops.useSystemdActivation) "setupSecrets";
    # TODO: If sops-nix is switched to systemd activation, add a systemd unit
    # for this install step that runs after sops-install-secrets.service,
    # because this activation-script dependency only orders against setupSecrets.
    text = ''
      install -Dm0600 -o ${config.services.qbittorrent.user} -g ${config.services.qbittorrent.group} \
        ${config.clan.core.vars.generators.qbittorrent.files."qBittorrent.conf".path} \
        ${config.services.qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf
    '';
  };

  services.qbittorrent = {
    enable = true;
    openFirewall = true;
    webuiPort = port;
    serverConfig = lib.mkForce {};

    user = "qbittorrent";
    group = "media";
  };
}
