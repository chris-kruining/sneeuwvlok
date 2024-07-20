{ pkgs, ... }:
{
  sound.enable = false;
  hardware.pulseaudio.enable = false;

  users.extraGroups.audio.members = [ "chris" ];

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
    jack.enable = true;
  };
}
