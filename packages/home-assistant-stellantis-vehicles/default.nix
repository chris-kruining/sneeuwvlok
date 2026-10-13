{
  lib,
  inputs,
  buildHomeAssistantComponent,
  python3Packages,
}: let
  src = inputs.home-assistant-stellantis-vehicles;

  # The integration's own manifest carries its version, so `nix flake update` is all an update takes
  manifest = src + "/custom_components/stellantis_vehicles/manifest.json" |> builtins.readFile |> builtins.fromJSON;
in
  buildHomeAssistantComponent {
    owner = "andreadegiovine";
    inherit (manifest) domain version;
    inherit src;

    dependencies = with python3Packages; [
      pillow
      pycryptodome
      paho-mqtt
    ];

    meta = {
      description = "Peugeot, Citroën, DS, Opel and Vauxhall cars in home assistant, through the api of their apps";
      homepage = "https://github.com/andreadegiovine/homeassistant-stellantis-vehicles";
      license = lib.licenses.mit;
    };
  }
