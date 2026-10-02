{
  pkgs,
  myPkgs,
  walker ? pkgs.walker,
  ...
}:
let
  deps = with pkgs; [
    awww
    mpvpaper
    procps
    util-linux # setsid, flock
  ];

  imageFind = ''-iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp"'';
  videoFind = ''-iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm"'';

  wallpaperDirs = pkgs.runCommand "wallpapers" { } ''
    mkdir -p $out
    ln -s ${myPkgs.assets}/wallpapers/static $out/static
    ln -s ${myPkgs.assets}/wallpapers/live $out/live
  '';

  # Shuffle-bag picker: every file is shown once per round, and the first
  # pick of a new round never equals the last pick of the previous one.
  mkRandomPicker =
    {
      name,
      subdir,
      findExpr,
      stateFile,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = deps;
      text = ''
        WALLPAPER_DIR="${wallpaperDirs}/${subdir}"
        STATE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/wallpaper-mode"
        LAST_FILE="$STATE_DIR/${stateFile}"
        BAG_FILE="$STATE_DIR/${stateFile}.bag"
        mkdir -p "$STATE_DIR"

        ALL=$(find -L "$WALLPAPER_DIR" -type f \( ${findExpr} \) 2>/dev/null | sort || true)
        if [ -z "$ALL" ]; then
          echo "Error: No valid wallpaper files found in $WALLPAPER_DIR" >&2
          exit 1
        fi

        LAST=""
        [ -f "$LAST_FILE" ] && LAST=$(cat "$LAST_FILE")

        BAG=""
        if [ -s "$BAG_FILE" ]; then
          BAG=$(grep -Fxf <(printf '%s\n' "$ALL") "$BAG_FILE" || true)
        fi

        if [ -z "$BAG" ]; then
          BAG=$(printf '%s\n' "$ALL" | shuf)
          if [ "$(printf '%s\n' "$BAG" | wc -l)" -gt 1 ] \
            && [ "$(printf '%s\n' "$BAG" | sed -n 1p)" = "$LAST" ]; then
            BAG=$(printf '%s\n' "$BAG" | { IFS= read -r first; cat; printf '%s\n' "$first"; })
          fi
        fi

        SELECTED=$(printf '%s\n' "$BAG" | sed -n 1p)
        printf '%s\n' "$BAG" | sed 1d > "$BAG_FILE"
        echo "$SELECTED" > "$LAST_FILE"
        echo "$SELECTED"
      '';
    };

  randomStatic = mkRandomPicker {
    name = "random-static-wallpaper";
    subdir = "static";
    findExpr = imageFind;
    stateFile = "last-static";
  };

  randomLive = mkRandomPicker {
    name = "random-live-wallpaper";
    subdir = "live";
    findExpr = videoFind;
    stateFile = "last-live";
  };

  # Per-session state (PID files, lock), keyed by WAYLAND_DISPLAY so that
  # concurrent WM sessions never touch each other's daemons.
  pidSetup = ''
    SESSION_ID="''${WAYLAND_DISPLAY:-default}"
    SESSION_ID="''${SESSION_ID##*/}"
    STATE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/wallpaper-mode/$SESSION_ID"
    # shellcheck disable=SC2034 # unused in scripts that only manage one daemon (e.g. toggle-wallpaper)
    AWWW_PID_FILE="$STATE_DIR/awww-daemon.pid"
    MPV_PID_FILE="$STATE_DIR/mpvpaper.pid"
    mkdir -p "$STATE_DIR"
  '';

  # Serialize setters. Only used by set-* scripts: toggle-wallpaper calls them,
  # so locking there too would deadlock.
  lockSetup = ''
    exec 9> "$STATE_DIR/lock"
    flock 9
  '';

  # Persistent, session-independent record of the last wallpaper.
  # Stored relative to the wallpaper root so it survives store path changes.
  persistSetup = ''
    PERSIST_FILE="''${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper-mode/current"

    save_current() {
      local mode="$1" file="$2" rel
      rel="''${file#${wallpaperDirs}/}"
      mkdir -p "$(dirname "$PERSIST_FILE")"
      printf '%s\n%s\n' "$mode" "$rel" > "$PERSIST_FILE.$$"
      mv -f "$PERSIST_FILE.$$" "$PERSIST_FILE"
    }
  '';

  isAlivePidFile = ''
    is_alive_pidfile() {
      local pidfile="$1"
      [ -f "$pidfile" ] || return 1
      local pid
      pid=$(cat "$pidfile" 2>/dev/null) || return 1
      [ -n "$pid" ] || return 1
      kill -0 "$pid" 2>/dev/null
    }
  '';

  # Kill the whole process group (daemons are started via setsid), wait for it
  # to die, escalate to SIGKILL after 2s, then remove the PID file.
  killPidFile = ''
    kill_pidfile() {
      local pidfile="$1"
      is_alive_pidfile "$pidfile" || { rm -f "$pidfile"; return 0; }
      local pid
      pid=$(cat "$pidfile")

      kill -TERM -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
      for _ in $(seq 1 40); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.05
      done
      if kill -0 "$pid" 2>/dev/null; then
        kill -KILL -- "-$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
      fi
      rm -f "$pidfile"
    }
  '';

  setStatic = pkgs.writeShellApplication {
    name = "set-static-wallpaper";
    runtimeInputs = deps ++ [ randomStatic ];
    text = ''
      ${pidSetup}
      ${isAlivePidFile}
      ${killPidFile}
      ${lockSetup}
      ${persistSetup}

      IMG="''${1:-$(random-static-wallpaper)}"
      [ -f "$IMG" ] || { echo "Error: not a file: $IMG" >&2; exit 1; }

      kill_pidfile "$MPV_PID_FILE"

      # 9>&- keeps the daemon from inheriting (and holding) the lock fd
      if ! is_alive_pidfile "$AWWW_PID_FILE"; then
        setsid awww-daemon > /dev/null 2>&1 9>&- &
        echo $! > "$AWWW_PID_FILE"
        disown
      fi

      for _ in $(seq 1 20); do
        if awww img "$IMG" --transition-type any --transition-duration 1 > /dev/null 2>&1; then
          break
        fi
        sleep 0.05
      done

      save_current static "$IMG"
    '';
  };

  setLive = pkgs.writeShellApplication {
    name = "set-live-wallpaper";
    runtimeInputs = deps ++ [ randomLive ];
    text = ''
      ${pidSetup}
      ${isAlivePidFile}
      ${killPidFile}
      ${lockSetup}
      ${persistSetup}

      VID="''${1:-$(random-live-wallpaper)}"
      [ -f "$VID" ] || { echo "Error: not a file: $VID" >&2; exit 1; }

      kill_pidfile "$AWWW_PID_FILE"

      # mpvpaper can't swap videos in place, so it is always restarted
      kill_pidfile "$MPV_PID_FILE"

      setsid mpvpaper -o "no-audio loop-file=inf hwdec=auto" '*' "$VID" > /dev/null 2>&1 9>&- &
      echo $! > "$MPV_PID_FILE"
      disown

      save_current live "$VID"
    '';
  };

  toggleWallpaper = pkgs.writeShellApplication {
    name = "toggle-wallpaper";
    runtimeInputs = [
      setStatic
      setLive
    ];
    text = ''
      ${pidSetup}
      ${isAlivePidFile}

      if is_alive_pidfile "$MPV_PID_FILE"; then
        set-static-wallpaper
      else
        set-live-wallpaper
      fi
    '';
  };

  restoreWallpaper = pkgs.writeShellApplication {
    name = "restore-wallpaper";
    runtimeInputs = [
      setStatic
      setLive
    ];
    text = ''
      ${persistSetup}

      MODE=""
      REL=""
      if [ -f "$PERSIST_FILE" ]; then
        { IFS= read -r MODE; IFS= read -r REL; } < "$PERSIST_FILE" || true
      fi

      FILE=""
      case "$REL" in
        "") ;;
        /*) FILE="$REL" ;;
        *) FILE="${wallpaperDirs}/$REL" ;;
      esac
      [ -f "$FILE" ] || FILE=""

      ARGS=()
      if [ -n "$FILE" ]; then
        ARGS+=("$FILE")
      fi

      case "$MODE" in
        live) exec set-live-wallpaper "''${ARGS[@]}" ;;
        *) exec set-static-wallpaper "''${ARGS[@]}" ;;
      esac
    '';
  };

  wallpaperPicker = pkgs.writeShellApplication {
    name = "pick-wallpaper";
    runtimeInputs = deps ++ [
      walker
      setStatic
      setLive
      pkgs.findutils
      pkgs.ffmpeg-headless
    ];
    text = ''
      ROOT="${wallpaperDirs}"
      CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-thumbs"
      PREVIEW="''${PICK_WALLPAPER_PREVIEW:-1}"
      ENTRY_ANY="🎲 Random (any)"
      ENTRY_STATIC="🖼 Random static"
      ENTRY_LIVE="🎞 Random live"

      MENU=$(mktemp)
      trap 'rm -f "$MENU"' EXIT
      mkdir -p "$CACHE_DIR"

      thumb_for() {
        local rel="$1" key out
        key=$(printf '%s' "$rel" | sha1sum | cut -d' ' -f1)
        out="$CACHE_DIR/$key.jpg"
        if [ ! -s "$out" ]; then
          ffmpeg -v error -y -ss 1 -i "$ROOT/$rel" -frames:v 1 -vf scale=320:-2 "$out" 2>/dev/null \
            || ffmpeg -v error -y -i "$ROOT/$rel" -frames:v 1 -vf scale=320:-2 "$out" 2>/dev/null \
            || { rm -f "$out"; return 1; }
        fi
        printf '%s' "$out"
      }

      emit() {
        local rel="$1" thumb
        if [ "$PREVIEW" = 1 ] && thumb=$(thumb_for "$rel"); then
          printf '%s\0icon\x1f%s\n' "$rel" "$thumb"
          return
        fi
        printf '%s\n' "$rel"
      }

      list_files() {
        cd "$ROOT"
        find -L static -type f \( ${imageFind} \) 2>/dev/null | sort || true
        find -L live -type f \( ${videoFind} \) 2>/dev/null | sort || true
      }

      {
        printf '%s\n' "$ENTRY_ANY" "$ENTRY_STATIC" "$ENTRY_LIVE"
        list_files | while IFS= read -r rel; do emit "$rel"; done
      } > "$MENU"

      CHOICE=$(walker --dmenu -p "Wallpaper" < "$MENU" || true)
      [ -n "$CHOICE" ] || exit 0

      case "$CHOICE" in
        "$ENTRY_ANY")
          N_STATIC=$(find -L "$ROOT/static" -type f \( ${imageFind} \) 2>/dev/null | wc -l || true)
          N_LIVE=$(find -L "$ROOT/live" -type f \( ${videoFind} \) 2>/dev/null | wc -l || true)
          TOTAL=$((N_STATIC + N_LIVE))
          [ "$TOTAL" -gt 0 ] || { echo "Error: no wallpapers found" >&2; exit 1; }
          if [ "$(shuf -i 1-"$TOTAL" -n 1)" -le "$N_STATIC" ]; then
            exec set-static-wallpaper
          else
            exec set-live-wallpaper
          fi
          ;;
        "$ENTRY_STATIC") exec set-static-wallpaper ;;
        "$ENTRY_LIVE") exec set-live-wallpaper ;;
        static/*)
          [ -f "$ROOT/$CHOICE" ] || { echo "Error: missing $CHOICE" >&2; exit 1; }
          exec set-static-wallpaper "$ROOT/$CHOICE"
          ;;
        live/*)
          [ -f "$ROOT/$CHOICE" ] || { echo "Error: missing $CHOICE" >&2; exit 1; }
          exec set-live-wallpaper "$ROOT/$CHOICE"
          ;;
        *)
          echo "Error: unknown selection: $CHOICE" >&2
          exit 1
          ;;
      esac
    '';
  };

in
pkgs.symlinkJoin {
  name = "wallpapers";
  paths = [
    wallpaperDirs
    randomStatic
    randomLive
    setStatic
    setLive
    toggleWallpaper
    restoreWallpaper
    wallpaperPicker
  ]
  ++ deps;

  passthru = {
    inherit
      wallpaperDirs
      randomStatic
      randomLive
      setStatic
      setLive
      toggleWallpaper
      restoreWallpaper
      wallpaperPicker
      ;
  };
}
