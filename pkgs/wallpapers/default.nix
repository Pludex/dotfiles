{ pkgs, ... }:
let
  deps = with pkgs; [
    awww
    mpvpaper
    procps
    util-linux # setsid — needed so we can kill whole process groups, not just one PID
  ];

  wallpaperDirs = pkgs.runCommand "wallpapers" { } ''
    mkdir -p $out/static $out/live
    cp -r ${./static}/. $out/static/
    cp -r ${./live}/. $out/live/
  '';

  # Generic "pick a random file from a directory, avoiding an immediate
  # repeat of the last pick" wallpaper picker.
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
        mkdir -p "$STATE_DIR"

        if [ ! -d "$WALLPAPER_DIR" ] || [ -z "$(ls -A "$WALLPAPER_DIR")" ]; then
          echo "Error: No wallpapers found in $WALLPAPER_DIR" >&2
          exit 1
        fi

        mapfile -t CANDIDATES < <(find "$WALLPAPER_DIR" -type f \( ${findExpr} \))

        if [ ''${#CANDIDATES[@]} -eq 0 ]; then
          echo "Error: No valid wallpaper files found." >&2
          exit 1
        fi

        LAST=""
        [ -f "$LAST_FILE" ] && LAST=$(cat "$LAST_FILE")

        if [ ''${#CANDIDATES[@]} -gt 1 ] && [ -n "$LAST" ]; then
          FILTERED=()
          for f in "''${CANDIDATES[@]}"; do
            [ "$f" != "$LAST" ] && FILTERED+=("$f")
          done
          CANDIDATES=("''${FILTERED[@]}")
        fi

        SELECTED=$(printf '%s\n' "''${CANDIDATES[@]}" | shuf -n 1)

        echo "$SELECTED" > "$LAST_FILE"
        echo "$SELECTED"
      '';
    };

  randomStatic = mkRandomPicker {
    name = "random-static-wallpaper";
    subdir = "static";
    findExpr = ''-name "*.jpg" -o -name "*.png" -o -name "*.webp"'';
    stateFile = "last-static";
  };

  randomLive = mkRandomPicker {
    name = "random-live-wallpaper";
    subdir = "live";
    findExpr = ''-name "*.mp4" -o -name "*.mkv" -o -name "*.webm"'';
    stateFile = "last-live";
  };

  # Shared setup: where the PID files for each daemon live.
  pidSetup = ''
    STATE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/wallpaper-mode"
    # shellcheck disable=SC2034 # unused in scripts that only manage one daemon (e.g. toggle-wallpaper)
    AWWW_PID_FILE="$STATE_DIR/awww-daemon.pid"
    MPV_PID_FILE="$STATE_DIR/mpvpaper.pid"
    mkdir -p "$STATE_DIR"
  '';

  # True (exit 0) if the PID recorded in $1 belongs to a still-living process.
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

  # Kill the whole PROCESS GROUP recorded in $1 (not just the one PID),
  # wait for it to actually die, then remove the PID file. Both daemons are
  # started via `setsid`, which makes the spawned PID the process-group
  # leader, so `kill -- -"$pid"` signals it and every child it forked
  # (mpvpaper spawns one mpv per output with `'*'`, and killing only the
  # leader used to leave those orphaned and still holding the wallpaper
  # surface — the actual bug this fixes). Falls back to a plain PID kill
  # for robustness if the group-kill target somehow doesn't exist.
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
      # Still alive after 2s? Force-kill, group first then the lone PID.
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

      IMG=$(random-static-wallpaper)

      # mpvpaper must never be left running once we're in static mode.
      kill_pidfile "$MPV_PID_FILE"

      # Only start the daemon if it isn't already alive; if it's already
      # running we just swap the image below -> no flicker, no blind
      # kill+recreate.
      if ! is_alive_pidfile "$AWWW_PID_FILE"; then
        setsid awww-daemon > /dev/null 2>&1 &
        echo $! > "$AWWW_PID_FILE"
        disown
      fi

      for _ in $(seq 1 20); do
        if awww img "$IMG" --transition-type any --transition-duration 1 > /dev/null 2>&1; then
          break
        fi
        sleep 0.05
      done
    '';
  };

  setLive = pkgs.writeShellApplication {
    name = "set-live-wallpaper";
    runtimeInputs = deps ++ [ randomLive ];
    text = ''
      ${pidSetup}
      ${isAlivePidFile}
      ${killPidFile}

      VID=$(random-live-wallpaper)

      # awww-daemon has no business running while mpvpaper owns the surface.
      kill_pidfile "$AWWW_PID_FILE"

      # mpvpaper always has to be restarted, since a running instance can't
      # swap to a different video file. `setsid` puts it in its own process
      # group so kill_pidfile can reliably take down every mpv instance it
      # forks per output, not just the one PID we happen to capture.
      kill_pidfile "$MPV_PID_FILE"

      setsid mpvpaper -o "no-audio loop-file=inf hwdec=auto" '*' "$VID" > /dev/null 2>&1 &
      echo $! > "$MPV_PID_FILE"
      disown
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
      ;
  };
}
