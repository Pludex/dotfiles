{ config, pkgs, ... }:
let
  recDir = "${config.home.homeDirectory}/Videos/Recordings";

  recordToggle = pkgs.writeShellScript "record-toggle" ''
    if ${pkgs.procps}/bin/pkill -SIGINT -x wf-recorder; then
      ${pkgs.libnotify}/bin/notify-send "Screen recording" "Saved to ${recDir}"
      exit 0
    fi
    mkdir -p ${recDir}
    out=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name')
    ${pkgs.libnotify}/bin/notify-send "Screen recording" "Started on $out"
    exec ${pkgs.wf-recorder}/bin/wf-recorder -o "$out" -f "${recDir}/$(date +%F_%H-%M-%S).mp4"
  '';

  hyprshotBin = "${pkgs.hyprshot}/bin/hyprshot";

  # Leave the submap, then run the command
  resetAndRun = cmd: {
    dsp.__raw = ''
      function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.exec_cmd("${cmd}")
      end
    '';
  };
in
{
  home.packages = with pkgs; [
    hyprshot
    wf-recorder
    wl-clipboard
    slurp
    libnotify
  ];

  programs.hyprland.settings = {
    binds."Mod+Shift+S".dsp.submap = "Capture";

    submaps.Capture.binds = {
      "W" = resetAndRun "${hyprshotBin} -m window --clipboard-only";
      "O" = resetAndRun "${hyprshotBin} -m output --clipboard-only";
      "R" = resetAndRun "${hyprshotBin} -m region --clipboard-only";
      "Q" = resetAndRun "${recordToggle}";
      "Escape".dsp.submap = "reset";
    };
  };
}
