{
  stdenvNoCC,
  myPkgs,
  imagemagick,
  lib,
  ...
}:

let
  srcDir = "${myPkgs.assets}/icons";

  # linked as-is
  keep = [
    "svg"
    "png"
  ];
  # converted to png
  convert = [
    "webp"
    "jpg"
    "jpeg"
    "gif"
    "bmp"
    "tif"
    "tiff"
    "ico"
  ];
  supported = keep ++ convert;

  entries = lib.attrNames (lib.filterAttrs (_: type: type == "regular") (builtins.readDir srcDir));

  iconFiles = lib.listToAttrs (
    lib.concatMap (
      file:
      let
        parts = lib.splitString "." file;
        ext = lib.toLower (lib.last parts);
        stem = lib.concatStringsSep "." (lib.init parts);
      in
      lib.optional (lib.elem ext supported) {
        name = stem;
        value = "${stem}.${if lib.elem ext keep then ext else "png"}";
      }
    ) entries
  );

in
stdenvNoCC.mkDerivation (finalAttrs: {
  name = "icons";

  src = srcDir;

  nativeBuildInputs = [ imagemagick ];

  dontUnpack = true;
  dontBuild = true;
  dontFixup = true; # only symlinks and converted images, nothing to patch or strip

  passthru = {
    inherit
      supported
      keep
      convert
      iconFiles
      ;
    iconPaths = lib.mapAttrs (_: file: "${finalAttrs.finalPackage}/share/pixmaps/${file}") iconFiles;
  };

  installPhase = ''
    runHook preInstall

    dest=$out/share/pixmaps
    mkdir -p "$dest"
    cd "$src"

    while IFS= read -r -d "" f; do
      f="''${f#./}"
      base=$(basename "$f")
      name="''${base%.*}"
      ext="''${base##*.}"
      ext="''${ext,,}"

      case "$ext" in
        ${lib.concatStringsSep "|" keep}) out="$dest/$name.$ext" ;;
        ${lib.concatStringsSep "|" convert}) out="$dest/$name.png" ;;
        *)
          echo "skip: $f (unsupported format)" >&2
          continue
          ;;
      esac

      if [ -e "$out" ]; then
        echo "error: output name collision $out (from $f)" >&2
        exit 1
      fi

      case "$ext" in
        ${lib.concatStringsSep "|" keep}) ln -s "$src/$f" "$out" ;;
        # [0] = first frame only (animated gif/webp, multi-size ico)
        *) magick "$f[0]" "$out" ;;
      esac
    done < <(find . -type f -print0)

    runHook postInstall
  '';

  meta = {
    description = "Icons package";
    platforms = lib.platforms.all;
  };
})
