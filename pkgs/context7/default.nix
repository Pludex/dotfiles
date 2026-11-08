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
  pname = "context7";
  version = "0.1.0";

  src = ./client.py;
  dontUnpack = true;
  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm644 $src $out/libexec/context7-docs.py
    makeWrapper ${py}/bin/python3 $out/bin/context7-docs \
      --add-flags $out/libexec/context7-docs.py \
      --set-default OMNIROUTE_BASE_URL ${lib.escapeShellArg omnirouteUrl}
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/context7-docs --help > /dev/null
  '';

  meta = {
    description = "Context7 library documentation search and fetch via OmniRoute";
    mainProgram = "context7-docs";
  };
}
