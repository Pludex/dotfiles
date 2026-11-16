{
  lib,
  stdenvNoCC,
  python3,
}:

stdenvNoCC.mkDerivation {
  pname = "hermes-prompt-filter";
  version = "0.1.0";

  src = ./prompt-filter.py;
  dontUnpack = true;

  buildInputs = [ python3 ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/hermes-prompt-filter
    runHook postInstall
  '';

  meta = {
    description = "OpenAI-compatible proxy that strips system prompts and tool fields";
    mainProgram = "hermes-prompt-filter";
    platforms = lib.platforms.all;
  };
}
