args:
let
  dir = builtins.readDir ./.;
  names = builtins.sort builtins.lessThan (builtins.attrNames dir);

  nixFiles = builtins.filter (
    name: dir.${name} == "regular" && builtins.match ".*\\.nix$" name != null && name != "default.nix"
  ) names;

  subdirs = builtins.filter (
    name: dir.${name} == "directory" && builtins.pathExists (./. + "/${name}/default.nix")
  ) names;

  importFile = name: import (./. + "/${name}") args;
in
(map importFile nixFiles) ++ (map importFile subdirs)
