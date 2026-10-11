{
  lib,
  buildNpmPackage,
  fetchurl,
  appimageTools,
  makeDesktopItem,
  symlinkJoin,
  nodejs_22,
  inputs,
}:
let
  sources = lib.importJSON ./default.json;

  cli = buildNpmPackage {
    pname = "lobehub-cli";
    inherit (sources.cli) version npmDepsHash;

    src = fetchurl { inherit (sources.cli) url hash; };
    sourceRoot = "package";

    nodejs = nodejs_22;
    postPatch = ''
      cp --no-preserve=mode ${./package.json} package.json
      cp --no-preserve=mode ${./package-lock.json} package-lock.json
    '';
    dontNpmBuild = true;
    npmFlags = [ "--ignore-scripts" ];

    postInstall = ''
      if [ -d man ]; then
        mkdir -p $out/share/man
        cp -r man/* $out/share/man/
      fi
    '';

    meta.mainProgram = "lh";
  };

  desktopItem = makeDesktopItem {
    name = "lobehub";
    desktopName = "LobeHub";
    exec = "lobehub-desktop %U";
    icon = "lobehub";
    categories = [ "Utility" ];
    startupWMClass = "LobeHub";
  };

  desktop = appimageTools.wrapType2 {
    pname = "lobehub-desktop";
    inherit (sources.desktop) version;
    src = fetchurl { inherit (sources.desktop) url hash; };

    extraInstallCommands = ''
      install -Dm444 ${desktopItem}/share/applications/lobehub.desktop \
        $out/share/applications/lobehub.desktop
      install -Dm444 ${inputs.lobehub}/apps/desktop/build/icon.png \
        $out/share/pixmaps/lobehub.png
    '';

    meta.mainProgram = "lobehub-desktop";
  };
in
symlinkJoin {
  name = "lobehub-${sources.cli.version}";
  paths = [
    cli
    desktop
  ];

  passthru = { inherit cli desktop; };

  meta = {
    description = "LobeHub AI agent workspace: CLI tools and desktop app";
    homepage = "https://github.com/lobehub/lobehub";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
