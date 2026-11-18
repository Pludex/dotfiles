{ lib
, buildPythonPackage
, setuptools
, requests
, base
}:

let
  omnirouteUrl = (base.app "omniroute").internalUrl;
in
buildPythonPackage {
  pname = "omniroute-clients";
  version = "0.1.0";
  pyproject = true;

  src = lib.cleanSource ./.;

  build-system = [ setuptools ];

  dependencies = [
    requests
  ];

  # Bake the OmniRoute URL into all clients
  postPatch = ''
    substituteInPlace src/omniroute_common/constants.py \
      --replace-fail 'DEFAULT_BASE_URL = "http://localhost:20128"' \
                     'DEFAULT_BASE_URL = ${builtins.toJSON omnirouteUrl}'
  '';

  pythonImportsCheck = [
    "omniroute_common"
    "context7_client"
    "tavily_client"
    "firecrawl_client"
    "web_tools"
  ];

  doCheck = false;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/context7 --help > /dev/null
    $out/bin/tavily --help > /dev/null
    $out/bin/firecrawl --help > /dev/null
    $out/bin/web-tools --help > /dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "OmniRoute client tools: context7, tavily, firecrawl, web-tools";
    license = lib.licenses.mit;
    mainProgram = "web-tools";
  };
}
