{
  myPkgs,
  pkgs,
  stdenv,
  appimageTools,
  libx,
  ...
}:
let
  baseApp = appimageTools.wrapType2 rec {
    pname = "sklauncher";
    version = "4.0.47";
    src = builtins.fetchurl {
      url = "https://github.com/sklauncher/binaries/releases/download/v${version}/SKlauncher-${version}-${stdenv.hostPlatform.parsed.cpu.name}.AppImage";
      sha256 = "sha256:0xsgfsz2l7gzzrzhrkplv6g0fyfy40x8di28i7yrihf6sz71qjm1";
    };

    extraPkgs = p: [
      p.glfw
      p.openal
      p.libGL
      p.libglvnd
      p.vulkan-loader
      p.libX11
      p.libXext
      p.libXcursor
      p.libXrandr
      p.libXinerama
      p.libXi
      p.libXxf86vm
    ];
  };

  desktopItem = libx.makeDesktopItem {
    name = "sklauncher";
    desktopName = "SKlauncher";
    comment = "An alternative Minecraft launcher";
    exec = "${baseApp}/bin/sklauncher";
    icon = "sklauncher";
    categories = [ "Game" ];
    terminal = false;
  };
in
pkgs.symlinkJoin {
  name = "sklauncher";
  paths = [
    baseApp
    desktopItem
  ];

  postBuild = ''
    ln -sf ${baseApp}/bin/sklauncher $out/bin/sklauncher
  '';
}
