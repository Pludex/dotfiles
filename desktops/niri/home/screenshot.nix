{ pkgs, ... }:
let
  sattyShot = pkgs.writeShellApplication {
    name = "satty-shot";
    runtimeInputs = with pkgs; [
      grim
      satty
      slurp
    ];
    text = ''
      FILENAME="$HOME/Pictures/Screenshots/satty-$(date '+%Y%m%d-%H:%M:%S').png"
      mkdir -p "$(dirname "$FILENAME")"

      grim -g "$(slurp -o -r -c '#ff0000ff')" -t ppm - | \
        satty --filename - --fullscreen --output-filename "$FILENAME"
    '';
  };
in
{
  programs.niri.settings = {
    binds = {
      "Mod+Shift+S" = {
        allow-when-locked = false;
        action.spawn = [ "${sattyShot}/bin/satty-shot" ];
      };
    };
  };
}
