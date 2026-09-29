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

  programs.mango.settings.bind = [
    "SUPER,A,spawn,${lib.getExe config.programs.walker.package}"
  ];
}
