{
  lib,
  rustPlatform,
  cargo-tauri,
  nodejs,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  pkg-config,
  wrapGAppsHook3,
  openssl,
  webkitgtk_4_1,
  libsoup_3,
  glib-networking,
  librsvg,
  alsa-lib,
  libayatana-appindicator,
  inputs,
  git,
  cmake,
  perl,
  go,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "soundcloud-desktop";
  version = "unstable-${builtins.substring 0 8 inputs.soundcloud-desktop.lastModifiedDate}";

  src = inputs.soundcloud-desktop;
  sourceRoot = "source/desktop";

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;
  dontUseCmakeConfigure = true;

  cargoLock = {
    allowBuiltinFetchGit = true;
    lockFile = "${inputs.soundcloud-desktop}/desktop/src-tauri/Cargo.lock";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      sourceRoot
      ;
    pnpm = pnpm_10;
    fetcherVersion = 5;
    hash = "sha256-jwKI3eD2Wf2wMLCG052XPNmy/9PJSjVkOpvt1ua8Uvw=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs
    pnpm_10
    pnpmConfigHook
    pkg-config
    wrapGAppsHook3
    git
    cmake
    perl
    go
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    openssl
    webkitgtk_4_1
    libsoup_3
    glib-networking
    librsvg
    alsa-lib
    libayatana-appindicator
  ];

  preFixup = ''
    gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]})
  '';

  doCheck = false;

  meta = {
    description = "Unofficial SoundCloud desktop client";
    homepage = "https://github.com/zxcloli666/SoundCloud-Desktop";
    license = lib.licenses.mit;
    mainProgram = "soundcloud-desktop";
    platforms = lib.platforms.linux;
  };
})
