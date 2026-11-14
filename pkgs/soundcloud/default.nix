{
  lib,
  fetchurl,
  runCommand,
  unzip,
  symlinkJoin,
  makeDesktopItem,
  writeShellScriptBin,
  python3,
  chromium,
  baseBrowser ? chromium,
}:

let
  source = lib.importJSON ./sources.json;

  python = python3.withPackages (ps: [ ps.dbus-fast ]);

  uboLite =
    runCommand "ubolite-${source.version}"
      {
        nativeBuildInputs = [ unzip ];
        src = fetchurl { inherit (source) url hash; };
      }
      ''
        mkdir $out
        unzip -q $src -d $out
      '';

  launcher = writeShellScriptBin "soundcloud" ''
    data="''${XDG_DATA_HOME:-$HOME/.local/share}/soundcloud"
    ext="$data/ubol"
    profile="$data/profile"
    rm -rf "$ext"
    mkdir -p "$ext" "$profile"
    cp -r --no-preserve=mode ${uboLite}/. "$ext"

    ${python}/bin/python ${./mpris-proxy.py} --profile "$profile" &
    proxy_pid=$!
    trap 'kill "$proxy_pid" 2>/dev/null' EXIT

    ${lib.getExe baseBrowser} \
      --app=https://soundcloud.com \
      --class=SoundCloud \
      --user-data-dir="$profile" \
      --load-extension="$ext" \
      --no-first-run \
      --no-default-browser-check \
      --ozone-platform-hint=auto \
      "$@"
  '';

  desktopItem = makeDesktopItem {
    name = "soundcloud";
    desktopName = "SoundCloud";
    exec = "soundcloud %U";
    icon = "soundcloud";
    categories = [
      "AudioVideo"
      "Audio"
      "Player"
    ];
    startupWMClass = "SoundCloud";
  };
in
symlinkJoin {
  name = "soundcloud";
  paths = [
    launcher
    desktopItem
  ];
  meta.mainProgram = "soundcloud";
}
