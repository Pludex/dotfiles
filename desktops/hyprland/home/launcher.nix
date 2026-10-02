{
  base,
  lib,
  config,
  ...
}:
{
  imports = [
    "${base.paths.commonDesktop}/walker.nix"
  ];

  programs.hyprland.settings.binds = {
    "Mod+A".dsp.exec_cmd = "${lib.getExe config.programs.walker.package}";
  };
}
