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
  pname = "firecrawl-cli";
  version = "0.1.0";
  pyproject = true;

  src = lib.cleanSource ./.;
  build-system = [ setuptools ];
  dependencies = [
    requests
  ];

  postPatch = ''
    substituteInPlace src/firecrawl_client/client.py \
      --replace-fail 'DEFAULT_BASE_URL = "http://localhost:20128"' \
                     'DEFAULT_BASE_URL = ${builtins.toJSON omnirouteUrl}'
  '';

  doCheck = false;
  pythonImportsCheck = [ "firecrawl_client" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/firecrawl --help > /dev/null
    $out/bin/firecrawl --help-python > /dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Firecrawl web search and page reader via OmniRoute (CLI + Python library)";
    mainProgram = "firecrawl";
  };
}
