{
  pkgs,
  lib ? pkgs.lib,
  base,
}:

let
  # ===== Settings =====
  allowNetwork = false; # Network off by default
  fixIcons = true;
  package = pkgs.wpsoffice-cn; # WPS Office package to use
  scale = null; # QT_SCALE_FACTOR, e.g. "1.5"

  bwrapPackage = pkgs.bubblewrap;
  fontsPackage = pkgs.callPackage ./fonts.nix { };
  fcitx5Qt5 = pkgs.libsForQt5.fcitx5-qt;

  # ===== bwrap arguments =====
  # Filter out empty strings (from optionalString when disabled)
  bwrapArgs =
    lib.filter (s: s != "") [
      "--unshare-all"
      "--dev /dev"
      "--proc /proc"
      "--tmpfs /tmp"
      "--new-session"

      "--ro-bind /nix/store /nix/store"
      "--ro-bind /etc /etc"
      "--ro-bind /run/current-system/sw/bin /bin"
      "--bind \"$HOME\" \"$HOME\""
      "--setenv PATH /bin"

      # D-Bus
      "--bind \"/run/user/$(id -u)/bus\" \"/run/user/$(id -u)/bus\""

      # Wayland (preferred display protocol)
      "--ro-bind-try \"/run/user/$(id -u)/\${WAYLAND_DISPLAY:-wayland-0}\" \"/run/user/$(id -u)/\${WAYLAND_DISPLAY:-wayland-0}\""
      "--setenv WAYLAND_DISPLAY \"\${WAYLAND_DISPLAY:-wayland-0}\""
      "--setenv XDG_RUNTIME_DIR \"/run/user/$(id -u)\""
      "--setenv QT_QPA_PLATFORM \"wayland;xcb\"" # try wayland first, fall back to xcb
      "--setenv GDK_BACKEND \"wayland,x11\""
      "--setenv QT_WAYLAND_DISABLE_WINDOWDECORATION \"1\""

      # X11 fallback socket (only used if wayland is unavailable)
      "--ro-bind-try /tmp/.X11-unix /tmp/.X11-unix"
      "--setenv DISPLAY \"\${DISPLAY:-:0}\""

      # Icon theme / cursor
      "--ro-bind-try /run/current-system/sw/share/icons /run/current-system/sw/share/icons"
      "--ro-bind-try \"$HOME/.nix-profile/share/icons\" \"$HOME/.nix-profile/share/icons\""
      "--setenv XCURSOR_PATH \"/run/current-system/sw/share/icons:$HOME/.icons:$HOME/.local/share/icons\""
      "--setenv XCURSOR_THEME \"\${XCURSOR_THEME:-default}\""
      "--setenv XCURSOR_SIZE \"\${XCURSOR_SIZE:-24}\""

      "--setenv QT_IM_MODULE \"fcitx\""
      "--setenv GTK_IM_MODULE \"fcitx\""
      "--setenv XMODIFIERS \"@im=fcitx\""
      "--setenv QT_PLUGIN_PATH \"${fcitx5Qt5}/${pkgs.qt5.qtbase.qtPluginPrefix}:${package}/plugins\""

      # Fonts
      "--ro-bind ${fontsPackage}/share/fonts/truetype /usr/share/fonts/truetype"
    ]
    ++ lib.optional allowNetwork "--share-net"
    ++ lib.optional (scale != null) "--setenv QT_SCALE_FACTOR ${toString scale}";

  # ===== Generate a wrapped launcher for each app =====
  mkWrappedApp =
    exec:
    pkgs.writeShellScriptBin exec ''
      ${bwrapPackage}/bin/bwrap ${lib.concatStringsSep " " bwrapArgs} ${package}/bin/${exec} "$@"
      ${pkgs.procps}/bin/pkill -9 -f "office6" || true
    '';

  apps = [
    "wps"
    "wpspdf"
    "wpp"
    "et"
  ];
  wrappedApps = map mkWrappedApp apps;
in
pkgs.stdenv.mkDerivation {
  pname = "wpsoffice-sandboxed";
  version = package.version;

  dontBuild = true;
  dontUnpack = true;

  buildInputs = [
    package
    bwrapPackage
  ]
  ++ wrappedApps;

  installPhase = ''
    mkdir -p $out/bin
    ${lib.concatMapStringsSep "\n" (app: ''
      ln -s ${app}/bin/${app.name} $out/bin/${app.name}
    '') wrappedApps}

    mkdir -p $out/share/applications
    for file in "${package}/share/applications"/*.desktop; do
      [ -f "$file" ] || continue
      newfile="$out/share/applications/$(basename "$file")"
      cp "$file" "$newfile"
      sed -i "s|${package}|$out|g" "$newfile"
      ${lib.optionalString fixIcons ''
        sed -i "s|^Icon=.*|Icon=${base.assets}/icons/wpsoffice.webp|g" "$newfile"
      ''}
    done
  '';

  meta = {
    description = "WPS Office flake featuring bwrap and useful options";
    mainProgram = "wps";
  };
}
