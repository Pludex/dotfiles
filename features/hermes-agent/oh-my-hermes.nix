{
  lib,
  inputs,
  python3Packages,
  nodejs,
  git
}:
let
  src =  inputs.oh-my-hermes;
  pyproject = lib.importTOML "${src}/pyproject.toml";
in
python3Packages.buildPythonApplication {
  pname = "oh-my-hermes";
  inherit (pyproject.project) version;
  inherit src;
  pyproject = true;
  build-system = [ python3Packages.setuptools ];
  doCheck = false;
  makeWrapperArgs = [
    "--prefix PATH : ${
      lib.makeBinPath [
        nodejs
        git
      ]
    }"
  ];
  meta.mainProgram = "omh";
}
