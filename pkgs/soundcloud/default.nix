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
  myPkgs,
  pipewire,
  wireplumber,
}:

let
  source = lib.importJSON ./sources.json;

  python = python3.withPackages (ps: [ ps.dbus-fast ]);

  iconDir = runCommand "soundcloud-icon" { } ''
    mkdir -p $out
    cp ${myPkgs.icons}/share/pixmaps/soundcloud.png $out/soundcloud.svg
  '';

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
    export PATH=${
      lib.makeBinPath [
        pipewire
        wireplumber
      ]
    }:$PATH
    data="''${XDG_DATA_HOME:-$HOME/.local/share}/soundcloud"
    ext="$data/ubol"
    profile="$data/profile"
    rm -rf "$ext"
    mkdir -p "$ext" "$profile"
    cp -r --no-preserve=mode ${uboLite}/. "$ext"

    pw-loopback \
      --capture-props='media.class=Audio/Sink node.name=soundcloud node.description=SoundCloud node.nick=SoundCloud media.name=SoundCloud' \
      --playback-props='node.name=soundcloud-out node.description=SoundCloud node.nick=SoundCloud media.name=SoundCloud node.passive=true' &
    loop_pid=$!

    for _ in $(seq 50); do
      pw-dump | grep -q '"node.name": "soundcloud"' && break
      sleep 0.1
    done

    ${python}/bin/python ${./mpris-proxy.py} \
      --profile "$profile" \
      --icon-name soundcloud \
      --icon-dir ${iconDir} &
    proxy_pid=$!
    trap 'kill "$proxy_pid" "$loop_pid" 2>/dev/null' EXIT

    env \
      PULSE_SINK=soundcloud \
      "PULSE_PROP_application.name=SoundCloud" \
      "PULSE_PROP_application.icon_name=soundcloud" \
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
    icon = "${iconDir}/soundcloud.svg";
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
