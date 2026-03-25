{
  imports = [
    ./application/steam.nix
    ./boot/default.nix
    ./editor/nano/default.nix
    ./editor/nvim/default.nix
    ./hardware/audio/default.nix
    ./home-manager/default.nix
    ./services
    ./system/networking
    ./system/security/boot
    ./system/security/sops
    ./system/security/sudo
  ];
}
