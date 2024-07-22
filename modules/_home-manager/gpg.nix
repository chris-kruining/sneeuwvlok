{ home, pkgs, ... }:
{
  home.packages = with pkgs; [
    gnupg
  ];

  home.file = {
    ".gnupg/gpg-agent.conf".text = ''
      default-cache-ttl 34560000
      max-cache-ttl 34560000
      allow-loopback-pinentry
    '';
    ".gnupg/gpg.conf".text = ''
      pinentry-mode loopback
    '';
  };
}
