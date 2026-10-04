{ base, ... }:
{
  imports = [
    "${base.paths.commonDesktop}/swaync.nix"
  ];

  programs.hyprland.settings = {
    rules.layer = [
      {
        match.namespace = "swaync-control-center";
        blur = true;
        ignore_alpha = 0.3;
      }
      {
        match.namespace = "swaync-notification-window";
        blur = true;
        ignore_alpha = 0.3;
      }
    ];

    binds = {
      "Mod+N".dsp.exec_cmd = "swaync-client -t -sw";
      "Mod+Shift+N".dsp.exec_cmd = "swaync-client -d -sw";
    };
  };
}
