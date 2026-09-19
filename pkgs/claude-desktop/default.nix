{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  wrapGAppsHook3,
  myPkgs,
  # runtime deps typical of a standalone Electron/Chromium binary bundle
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libglvnd,
  libnotify,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxscrnsaver,
  libxtst,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
}:
let
  # `input.json` is produced by ./update.sh and has the shape:
  #   { "<arch>": { "url": "...", "version": "...", "sha256": "sha256-..." }, ... }
  inputJson = builtins.fromJSON (builtins.readFile ./input.json);

  archMap = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  };
  debArch =
    archMap.${stdenv.hostPlatform.system}
      or (throw "claude-desktop: unsupported system ${stdenv.hostPlatform.system}");

  entry =
    inputJson.${debArch}
      or (throw "claude-desktop: no entry for arch '${debArch}' in input.json - re-run get-claude-desktop-url.sh");

  version = entry.version;

  src = fetchurl {
    url = entry.url;
    hash = entry.sha256;
  };

  desktopItem = makeDesktopItem {
    name = "claude";
    exec = "claude-desktop %u";
    icon = "${myPkgs.assets}/icons/claude.png";
    type = "Application";
    terminal = false;
    desktopName = "Claude";
    genericName = "Claude Desktop";
    startupWMClass = "claude";
    categories = [
      "Office"
      "Utility"
    ];
    mimeTypes = [ "x-scheme-handler/claude" ];
  };
in
stdenv.mkDerivation {
  pname = "claude-desktop";
  inherit version src;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libglvnd
    libnotify
    libsecret
    libxkbcommon
    mesa
    nspr
    nss
    pango
    systemd
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
    libxscrnsaver
    libxtst
  ];

  dontConfigure = true;
  dontBuild = true;

  # `dpkg-deb -x` internally has tar try to restore the exact original file
  # modes, which includes the setuid bit on usr/lib/claude-desktop/chrome-sandbox.
  # The Nix build sandbox has no privilege to set that bit, so `dpkg-deb -x`
  # fails outright. Piping the fsys tarball through `tar --no-same-permissions`
  # avoids that: files land with normal (umask-based) permissions instead, and
  # we fix up the ones that actually matter (executable bits) below.
  unpackPhase = ''
    runHook preUnpack
    mkdir -p extracted
    dpkg-deb --fsys-tarfile "$src" | tar -x --no-same-permissions --no-same-owner -C extracted
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    # Mirror the package's /usr layout straight into $out (usr/bin -> $out/bin,
    # usr/lib -> $out/lib, usr/share -> $out/share, etc).
    if [ -d extracted/usr ]; then
      cp -r extracted/usr/. "$out/"
    else
      # Fallback in case a future release doesn't root everything under /usr.
      cp -r extracted/. "$out/"
    fi

    # --no-same-permissions extraction is umask-based; make sure the actual
    # executables kept their execute bit regardless.
    find "$out/bin" "$out/lib/claude-desktop" -maxdepth 1 -type f -exec chmod +x {} + 2>/dev/null || true

    # The .deb ships its own .desktop file pointing at an icon path that
    # doesn't exist in the Nix store. Replace it with ours, which points
    # at myPkgs.assets instead.
    mkdir -p "$out/share/applications"
    install -Dm644 "${desktopItem}/share/applications/claude.desktop" \
      "$out/share/applications/claude.desktop"

    runHook postInstall
  '';

  # autoPatchelfHook fixes up ELF binaries; postFixup wraps the launcher so
  # Wayland/Ozone flags and Nix-provided libraries are picked up correctly.
  #
  # NOTE on sandboxing: chrome-sandbox ships setuid-root in the upstream .deb
  # so Chromium can use its own process sandbox. The Nix build sandbox
  # refuses to create setuid binaries (by design), so the copy in $out is a
  # regular non-setuid executable and Chromium's sandbox init will fail at
  # startup unless we either (a) pass --no-sandbox, as below - simplest, but
  # loses that extra sandbox layer - or (b) set up a proper setuid wrapper via
  # NixOS's `security.wrappers.chrome-sandbox` pointing at
  # "''${out}/lib/claude-desktop/chrome-sandbox", owned by root with mode
  # 4755, and drop --no-sandbox here once that's configured.
  #
  # NOTE on EGL: ANGLE/Chromium dlopen()s libEGL.so.1 at runtime rather than
  # linking it at build time, so autoPatchelfHook's rpath patching (which
  # only covers DT_NEEDED entries) never sees it. We fix this by prefixing
  # LD_LIBRARY_PATH with mesa's (and libglvnd's) lib output instead.
  postFixup = ''
    if [ -f "$out/bin/claude-desktop" ]; then
      wrapProgram "$out/bin/claude-desktop" \
        --add-flags "--no-sandbox" \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
        --prefix LD_LIBRARY_PATH : "${
          lib.makeLibraryPath [
            mesa
            libglvnd
            libdrm
          ]
        }"
    fi
  '';

  # The bundled Electron binary links against a fair number of shared
  # libraries autoPatchelfHook won't find a match for by default (bundled
  # Chromium .so files, optional codecs, etc). Ignore those rather than
  # fail the build; genuinely missing required libs will still surface as
  # runtime errors you can add above.
  autoPatchelfIgnoreMissingDeps = true;

  meta = {
    description = "Claude desktop app for Linux (official .deb repackaged)";
    homepage = "https://claude.com/download";
    license = lib.licenses.unfree;
    platforms = builtins.attrNames archMap;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "claude-desktop";
  };
}
