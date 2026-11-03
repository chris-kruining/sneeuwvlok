{lib, ...}: {
  sops.secrets = {
    "menicon/device_cert" = lib.mkIf (builtins.pathExists ./menicon-device-cert.sops) {
      sopsFile = ./menicon-device-cert.sops;
      format = "binary";
      owner = "chris";
    };

    "menicon/device_cert_password".owner = "chris";
  };
}
