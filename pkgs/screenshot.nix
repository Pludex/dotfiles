{
  grim,
  satty,
  slurp,
  writeShellApplication,
}:
writeShellApplication {
  name = "screenshot";
  runtimeInputs = [
    grim
    satty
    slurp
  ];
  text = ''
    FILENAME=~/Pictures/Screenshots/$(date '+%Y%m%d-%H:%M:%S').png
    grim -g "$(slurp -o -r -c '#ff0000ff')" -t ppm - | \
      satty --filename - --fullscreen --output-filename "$FILENAME"
  '';
}
