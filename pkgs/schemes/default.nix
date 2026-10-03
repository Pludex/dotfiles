{
  lib,
  stdenvNoCC,
  inputs,
}:
let
  scheme = inputs.schemes;

  install =
    dir: files: lib.concatMapStringsSep "\n" (f: "ln -sf ${f} $out/${dir}/${baseNameOf f}") files;

  isScheme = name: lib.hasSuffix ".yaml" name || lib.hasSuffix ".yml" name;

  upstream = dir: lib.filter isScheme (builtins.attrNames (builtins.readDir "${scheme}/${dir}"));

  base16 = [
    ./base16/carbonfox.yaml
  ];
  base24 = [ ];
  tinted8 = [ ];
  tools = [ ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tinted-schemes";
  version = "spec-0.11";

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{base16,base24,tinted8,tools}
    ln -s ${scheme}/base16/* $out/base16/
    ln -s ${scheme}/base24/* $out/base24/
    ln -s ${scheme}/tinted8/* $out/tinted8/

    ${install "base16" base16}
    ${install "base24" base24}
    ${install "tinted8" tinted8}
    ${install "tools" tools}

    runHook postInstall
  '';

  passthru =
    let
      out = finalAttrs.finalPackage;
      list = dir: extra: map (n: "${out}/${dir}/${n}") (upstream dir ++ map baseNameOf extra);
    in
    {
      base16 = list "base16" base16;
      base24 = list "base24" base24;
      tinted8 = list "tinted8" tinted8;
      tools = map (f: "${out}/tools/${baseNameOf f}") tools;
    };

  meta = {
    description = "Tinted theming color schemes (base16, base24, tinted8)";
    homepage = "https://github.com/tinted-theming/schemes";
    license = lib.licenses.mit;
  };
})
