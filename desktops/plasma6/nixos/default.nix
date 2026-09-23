{ config, ... }:
{
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.sddm.enable = true;

  services.xserver = {
    enable = true;
    videoDrivers = config.host-config.gpuDrivers;
  };
}
