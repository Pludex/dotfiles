{ config, ... }:
{
  wayland.windowManager.mango.autostart_sh = ''
    ${config.programs.mango.settings.wallpaperStart}
  '';
}
