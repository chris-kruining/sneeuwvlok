{ pkgs, security, ... }:
{
  environment.systemPackages = with pkgs; [
    kdePackages.kwallet-pam
    bitwarden
  ];

  security.pam.services.kwallet = {
    name = "kwallet";
    enableKwallet = true;
  };
}
