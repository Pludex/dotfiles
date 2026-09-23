{ config, ... }:
{
  programs.niri.enable = true;

  services.displayManager.sddm.wayland.enable = true;

  imports = [
    ./dm
  ];

  services.xserver = {
    enable = true;
    videoDrivers = config.host-config.gpuDrivers;
  };

}
