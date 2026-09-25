{ config, lib, ... }:
{
  wayland.windowManager.mango.autostart_sh = ''
    ${config.programs.mango.settings.wallpaperStart}
    exec ${lib.getExe config.programs.mango._internal.startSessionWithApps-sh}
  '';
}
