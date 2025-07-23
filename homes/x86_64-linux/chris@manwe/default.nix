{ lib, ... }:
let
    inherit (lib);
in
{
    sneeuwvlok = {
        series = {
            media.enable = true;
        };
    };
}