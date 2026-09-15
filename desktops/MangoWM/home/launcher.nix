{
  base,
  lib,
  config,
  ...
}:
{
  imports = [
    "${base.commonDesktop}/fuzzel.nix"
  ];

  programs.mango.settings.bind = [
    "SUPER,A,spawn,${lib.getExe config.programs.fuzzel.package}"
  ];
}
