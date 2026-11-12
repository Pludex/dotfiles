{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
  wl-clipboard,
  file,
}:
stdenvNoCC.mkDerivation {
  pname = "clipboard";
  version = "1.0";

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    install -Dm644 ${./clip.py} $out/libexec/clip.py
    for b in c p; do
      makeWrapper ${lib.getExe python3} $out/bin/$b \
        --add-flags "$out/libexec/clip.py $b" \
        --prefix PATH : ${
          lib.makeBinPath [
            wl-clipboard
            file
          ]
        }
    done
  '';

  meta = {
    description = "Tiny copy (c) and paste (p) commands for the Wayland clipboard";
    mainProgram = "c";
    platforms = lib.platforms.linux;
  };
}
