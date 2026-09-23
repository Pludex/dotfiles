{
  slurp,
  wf-recorder,
  libnotify,
  writeShellApplication,
}:
writeShellApplication {
  name = "screen-record";
  runtimeInputs = [
    slurp
    wf-recorder
    libnotify
  ];
  text = ''
    # Check if wf-recorder is already running (to use a single hotkey as a toggle)
    if pgrep -x "wf-recorder" > /dev/null; then
        pkill -INT wf-recorder
        notify-send "Screen Recorder" "Recording stopped and saved!"
        exit 0
    fi

    # Create the recording directory if it does not exist
    mkdir -p ~/Videos/Recordings
    FILENAME=~/Videos/Recordings/recording-$(date '+%Y%m%d-%H%M%S').mp4

    # Select a region using slurp and start recording with wf-recorder
    GEOM=$(slurp)
    if [ -z "$GEOM" ]; then
        exit 0
    fi

    notify-send "Screen Recorder" "Starting screen recording..."
    wf-recorder -g "$GEOM" -f "$FILENAME"
  '';
}
