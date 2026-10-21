{ config, lib, ... }:
{
  config = lib.mkIf (!config.isContainer) {
    services.pulseaudio.enable = false;

    services.pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      wireplumber.enable = true;
      audio.enable = true;
    };

    security.rtkit.enable = true;
  };
}
