{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
  base,
}:
let
  py = python3.withPackages (ps: [ ps.requests ]);
  omnirouteUrl = (base.app "omniroute").internalUrl;

in
stdenvNoCC.mkDerivation {
  pname = "tavily";
  version = "0.1.0";

  src = ./client.py;
  dontUnpack = true;
  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm644 $src $out/libexec/tavily-search.py
    makeWrapper ${py}/bin/python3 $out/bin/tavily-search \
      --add-flags $out/libexec/tavily-search.py \
      --set-default PYTHONUTF8 1 \
      --set-default OMNIROUTE_BASE_URL ${lib.escapeShellArg omnirouteUrl}
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/tavily-search --help > /dev/null
  '';

  meta = {
    description = "Tavily web search via OmniRoute";
    mainProgram = "tavily-search";
  };
}
