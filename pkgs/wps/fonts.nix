{ pkgs, sources }:

pkgs.stdenv.mkDerivation {
  pname = "wpsoffice-fonts";
  version = "2.0";

  # Source path provided via Flake inputs
  src = sources.wps-fonts;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    fontDir="$out/share/fonts/truetype"
    mkdir -p "$fontDir"

    # Find and copy all font files (.ttf and .otf)
    find . -type f \( -iname "*.ttf" -o -iname "*.otf" \) -exec cp -t "$fontDir" {} +

    # Sanity check: abort if no fonts were copied
    if [ -z "$(ls -A "$fontDir")" ]; then
      echo "ERROR: No font files (.ttf/.otf) found in Flake input!"
      exit 1
    fi

    runHook postInstall
  '';

  meta = {
    description = "Symbol fonts required by WPS Office for math formulas";
    homepage = "https://github.com/ferion11/ttf-wps-fonts";
    priority = 5;
  };
}
