{
  lib,
  pkgs,
  base,
  config,
  ...
}:
{
  config.programs.mango.settings = {
    wallpaper = "${base.assets}/kawaii-cat-girl.png";
    wallpaperStart = ''
      ${pkgs.awww}/bin/awww-daemon --namespace backdrop-mango &
      ${lib.getExe pkgs.awww} img --namespace backdrop-mango ${config.programs.mango.settings.wallpaper} &
    '';
  };

  options.programs.mango.settings.wallpaper = lib.mkOption {
    type = lib.types.path;
  };

  options.programs.mango.settings.wallpaperStart = lib.mkOption {
    type = lib.types.lines;
  };
}
