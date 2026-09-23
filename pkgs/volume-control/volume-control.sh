get_volume() {
  volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2}')
  volume=$(printf "%.0f" "$(echo "$volume * 100" | bc)")
  echo "$volume"
}

is_muted() {
  wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "MUTED"
}

is_mic_muted() {
  wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q "MUTED"
}

get_icon() {
  current=$(get_volume)
  if [[ $current -eq 0 ]]; then
    echo "$iDIR/volume-mute.png"
  elif [[ $current -le 30 ]]; then
    echo "$iDIR/volume-low.png"
  elif [[ $current -le 60 ]]; then
    echo "$iDIR/volume-mid.png"
  else
    echo "$iDIR/volume-high.png"
  fi
}

notify_user() {
  notify-send -h string:x-canonical-private-synchronous:sys-notify \
    -h string:transient:true \
    -u low \
    -i "$(get_icon)" \
    -a "volume-control" \
    "Volume : $(get_volume) %"
}

inc_volume() {
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && notify_user
}

dec_volume() {
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && notify_user
}

toggle_mute() {
  if ! is_muted; then
    wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 &&
      notify-send -h string:x-canonical-private-synchronous:sys-notify \
        -h string:transient:true \
        -u low \
        -a "volume-control" \
        -i "$iDIR/volume-mute.png" \
        "Volume Switched OFF"
  else
    wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 &&
      notify-send -h string:x-canonical-private-synchronous:sys-notify \
        -h string:transient:true \
        -u low \
        -a "volume-control" \
        -i "$(get_icon)" \
        "Volume Switched ON"
  fi
}

toggle_mic() {
  if ! is_mic_muted; then
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1 &&
      notify-send -h string:x-canonical-private-synchronous:sys-notify \
        -h string:transient:true \
        -u low \
        -a "volume-control" \
        -i "$iDIR/microphone-mute.png" \
        "Microphone Switched OFF"
  else
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0 &&
      notify-send -h string:x-canonical-private-synchronous:sys-notify \
        -h string:transient:true \
        -u low \
        -a "volume-control" \
        -i "$iDIR/microphone.png" \
        "Microphone Switched ON"
  fi
}

get_mic_icon() {
  current=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{print $2}')
  current=$(printf "%.0f" "$(echo "$current * 100" | bc)")

  if [[ $current -eq 0 ]]; then
    echo "$iDIR/microphone.png"
  elif [[ $current -le 30 ]]; then
    echo "$iDIR/microphone.png"
  elif [[ $current -le 60 ]]; then
    echo "$iDIR/microphone.png"
  else
    echo "$iDIR/microphone.png"
  fi
}

notify_mic_user() {
  current=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{print $2}')
  current=$(printf "%.0f" "$(echo "$current * 100" | bc)")
  notify-send -h string:x-canonical-private-synchronous:sys-notify \
    -h string:transient:true \
    -u low \
    -a "volume-control" \
    -i "$(get_mic_icon)" \
    "Mic-Level : $current %"
}

inc_mic_volume() {
  wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+ && notify_mic_user
}

dec_mic_volume() {
  wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%- && notify_mic_user
}

# Execute accordingly
case "${1:-}" in
--get)
  get_volume
  ;;
--inc)
  inc_volume
  ;;
--dec)
  dec_volume
  ;;
--toggle)
  toggle_mute
  ;;
--toggle-mic)
  toggle_mic
  ;;
--get-icon)
  get_icon
  ;;
--get-mic-icon)
  get_mic_icon
  ;;
--mic-inc)
  inc_mic_volume
  ;;
--mic-dec)
  dec_mic_volume
  ;;
*)
  get_volume
  ;;
esac
