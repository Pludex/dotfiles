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

  wayland.windowManager.mango.settings = {
    bind = [
      "SUPER,A,spawn,${lib.getExe config.programs.walker.package}"
    ];
  };
}
