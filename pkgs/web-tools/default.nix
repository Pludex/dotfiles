{
  lib,
  buildPythonPackage,
  setuptools,
  tavily-client,
  firecrawl-client,
}:
buildPythonPackage {
  pname = "web-tools";
  version = "0.1.0";
  pyproject = true;

  src = lib.cleanSource ./.;
  build-system = [ setuptools ];
  dependencies = [
    tavily-client
    firecrawl-client
  ];

  doCheck = false;
  pythonImportsCheck = [ "web_tools" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    help="$($out/bin/web-tools --help)"
    grep -q Tavily <<<"$help"
    grep -q Firecrawl <<<"$help"
    pyhelp="$($out/bin/web-tools --help-python)"
    grep -q web_tools <<<"$pyhelp"
    runHook postInstallCheck
  '';

  meta = {
    description = "Web search (Tavily) and page fetch (Firecrawl) in one CLI";
    mainProgram = "web-tools";
  };
}
