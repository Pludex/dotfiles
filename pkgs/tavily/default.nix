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
  pname = "tavily-client";
  version = "0.1.0";
  pyproject = true;

  src = lib.cleanSource ./.;
  build-system = [ setuptools ];
  dependencies = [
    requests
  ];

  # Bake the URL into the module so both the CLI and library use get it.
  postPatch = ''
    substituteInPlace src/tavily_client/client.py \
      --replace-fail 'DEFAULT_BASE_URL = "http://localhost:20128"' \
                     'DEFAULT_BASE_URL = ${builtins.toJSON omnirouteUrl}'
  '';

  doCheck = false;
  pythonImportsCheck = [ "tavily_client" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/tavily --help > /dev/null
    $out/bin/tavily --help-python > /dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Tavily web search via OmniRoute (CLI + Python library)";
    mainProgram = "tavily";
  };
}
