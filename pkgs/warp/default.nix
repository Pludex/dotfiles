{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zstd,
  alsa-lib,
  curl,
  fontconfig,
  libglvnd,
  libxkbcommon,
  vulkan-loader,
  wayland,
  xdg-utils,
  libxi,
  libxcursor,
  libx11,
  libxcb,
  xz, # liblzma
  zlib,
  makeWrapper,
  waylandSupport ? false,
}:

let
  inputs = lib.importJSON ./input.json;
  arch = stdenv.hostPlatform.parsed.cpu.name; # "x86_64" | "aarch64"
  info = inputs.${arch} or (throw "warp-terminal: no entry for '${arch}' in input.json");
in
stdenv.mkDerivation {
  pname = "warp-terminal";
  inherit (info) version;

  src = fetchurl {
    inherit (info) url;
    hash = info.sha256;
  };

  passthru.updateScript = ./update.sh;

  sourceRoot = ".";

  postPatch = ''
    substituteInPlace usr/bin/warp-terminal \
      --replace-fail /opt/ $out/opt/
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    zstd
    makeWrapper
  ];

  buildInputs = [
    alsa-lib # libasound.so.2
    curl
    fontconfig
    (lib.getLib stdenv.cc.cc) # libstdc++.so libgcc_s.so
    zlib
    xz
  ];

  runtimeDependencies = [
    libglvnd # for libegl
    libxkbcommon
    stdenv.cc.libc
    vulkan-loader
    xdg-utils
    libx11
    libxcb
    libxcursor
    libxi
  ]
  ++ lib.optionals waylandSupport [ wayland ];

  installPhase = ''
    runHook preInstall

    mkdir $out
    cp -r opt usr/* $out

  ''
  + lib.optionalString waylandSupport ''
    wrapProgram $out/bin/warp-terminal --set WARP_ENABLE_WAYLAND 1
  ''
  + ''
    runHook postInstall
  '';

  postFixup = ''
    # Link missing libfontconfig to fix font discovery
    # https://github.com/warpdotdev/Warp/issues/5793
    patchelf \
      --add-needed libfontconfig.so.1 \
      $out/opt/warpdotdev/warp-terminal/warp
  '';

  meta = {
    description = "Rust-based terminal";
    homepage = "https://www.warp.dev";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "warp-terminal";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
