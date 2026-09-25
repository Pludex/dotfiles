{ desktop }:
let
  resolvePath =
    subpath:
    let
      filePath = ./${desktop} + "/${subpath}.nix";
      dirPath = ./${desktop} + "/${subpath}";
    in
    if builtins.pathExists filePath then
      filePath
    else if builtins.pathExists dirPath then
      dirPath
    else
      throw "Neither ${subpath}.nix nor directory ${subpath} exists in ./${desktop}";
in
{
  nixos = resolvePath "nixos";
  home = resolvePath "home";
}
