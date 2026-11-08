{ lib, stdenvNoCC, python3, makeWrapper, base, }:
let
  py = python3.withPackages (ps: [ ps.requests ]);
  omnirouteUrl = (base.app "omniroute").internalUrl;
in
stdenvNoCC.mkDerivation {
  pname = "firecrawl";
  version = "0.1.0";

  src = ./client.py;
  dontUnpack = true;
  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm644 $src $out/libexec/firecrawl-web.py
    makeWrapper ${py}/bin/python3 $out/bin/firecrawl-web \
      --add-flags $out/libexec/firecrawl-web.py \
      --set-default OMNIROUTE_BASE_URL ${lib.escapeShellArg omnirouteUrl}
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/firecrawl-web --help > /dev/null
  '';

  meta = {
    description = "Firecrawl web search and page reader via OmniRoute";
    mainProgram = "firecrawl-web";
  };
}
