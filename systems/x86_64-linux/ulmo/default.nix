{ ... }:
let
in
{
    imports = [
        ./disks.nix
        ./hardware.nix
    ];

    sneeuwvlok = {
        preset = "server";

        services = {
            media.enable = true;
        };
    };

    system.stateVersion = "23.11";
}