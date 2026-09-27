{ host }:
let
  file = ./${host}.nix;
  dir = ./${host};
in
if builtins.pathExists file then
  import file
else if builtins.pathExists dir then
  import dir
else
  throw "Host configuration for '${host}' not found (checked ${host}.nix and ${host}/default.nix)"
