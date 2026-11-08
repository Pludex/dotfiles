{
  lib,
  buildPythonPackage,
  setuptools,
  requests,
  base,
}:
let
  omnirouteUrl = (base.app "omniroute").internalUrl;
in
buildPythonPackage {
  pname = "context7-cli";
  version = "0.1.0";
  pyproject = true;

  src = lib.cleanSource ./.;
  build-system = [ setuptools ];
  dependencies = [
    requests
  ];

  postPatch = ''
    substituteInPlace src/context7_client/client.py \
      --replace-fail 'DEFAULT_BASE_URL = "http://localhost:20128"' \
                     'DEFAULT_BASE_URL = ${builtins.toJSON omnirouteUrl}'
  '';

  doCheck = false;
  pythonImportsCheck = [ "context7_client" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/context7 --help > /dev/null
    $out/bin/context7 --help-python > /dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Context7 library documentation search and fetch via OmniRoute (CLI + Python library)";
    mainProgram = "context7";
  };
}
