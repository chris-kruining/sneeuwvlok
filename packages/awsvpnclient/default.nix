{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  buildFHSEnv,
  writeShellScript,
  makeDesktopItem,
  ...
}: let
  version = "6.2.0";

  # AWS's own .deb, left as it is: the binaries run in an fhs env with the /opt and /sbin/ip they expect
  unpacked = stdenvNoCC.mkDerivation {
    pname = "awsvpnclient-unpacked";
    inherit version;

    src = fetchurl {
      url = "https://d20adtppz83p9s.cloudfront.net/GTK/${version}/awsvpnclient_amd64.deb";
      hash = "sha256-J3mor3SK3cLm9QYcjqieyffLAKb0Va86PaF9z4tAq7c=";
    };

    nativeBuildInputs = [dpkg];

    unpackPhase = "dpkg-deb -x $src root";

    # The .deb ships its binaries without the executable bit, its postinst sets that
    installPhase = ''
      mkdir -p $out
      cp -r root/opt $out/opt

      cd $out/opt/awsvpnclient
      chmod 755 aws-client-vpn-daemon aws-vpn-client aws-vpn-client-agent "AWS VPN Client" chrome_crashpad_handler launch-vpn-client.sh dns/configure-dns
    '';

    dontPatchELF = true;
    dontStrip = true;

    meta.license = lib.licenses.unfree;
  };

  opt = ["--ro-bind" "${unpacked}/opt/awsvpnclient" "/opt/awsvpnclient"];

  # The root service. It has openvpn built in, sets up the tun device and routes with /sbin/ip and dns with resolvectl
  daemon = buildFHSEnv {
    name = "aws-client-vpn-daemon";
    targetPkgs = pkgs: with pkgs; [stdenv.cc.cc.lib iproute2 systemd coreutils bash];

    # bwrap drops all capabilities by default, even for root
    extraBwrapArgs = opt ++ ["--cap-add" "ALL"];

    runScript = "/opt/awsvpnclient/aws-client-vpn-daemon";
  };

  desktopItem = makeDesktopItem {
    name = "awsvpnclient";
    desktopName = "AWS VPN Client";
    comment = "AWS VPN Client provides secure VPN connectivity";
    exec = "awsvpnclient %U";
    icon = "awsvpnclient";
    categories = ["Network"];
    keywords = ["vpn" "aws" "amazon"];
    startupWMClass = "AWS VPN Client";
  };
in
  # The electron app, started the way AWS's launch-vpn-client.sh does. The daemon knows its clients by process name, so it keeps it
  buildFHSEnv {
    name = "awsvpnclient";
    inherit version;

    targetPkgs = pkgs:
      with pkgs; [
        stdenv.cc.cc.lib
        glib
        nspr
        nss
        dbus
        atk
        at-spi2-atk
        at-spi2-core
        cups
        cairo
        gtk3
        pango
        expat
        libxkbcommon
        libgbm
        libdrm
        systemd
        alsa-lib
        libnotify
        libx11
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
        libxcb
        libxscrnsaver
        libxtst
      ];

    extraBwrapArgs = opt;

    runScript = writeShellScript "awsvpnclient" ''
      exec "/opt/awsvpnclient/AWS VPN Client" --no-sandbox --ozone-platform=x11 --disable-gpu "$@"
    '';

    extraInstallCommands = ''
      install -Dm644 ${desktopItem}/share/applications/awsvpnclient.desktop $out/share/applications/awsvpnclient.desktop
      install -Dm644 ${unpacked}/opt/awsvpnclient/resources/app.png $out/share/icons/hicolor/512x512/apps/awsvpnclient.png
    '';

    passthru = {inherit daemon unpacked;};

    meta = {
      description = "AWS Client VPN, the official client";
      license = lib.licenses.unfree;
      platforms = ["x86_64-linux"];
      mainProgram = "awsvpnclient";
    };
  }
