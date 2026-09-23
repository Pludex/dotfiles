{ inputs, config, ... }:
{
  programs.ghostty = {
    enable = true;

    settings = {
      scrollbar = "never";
      custom-shader = [ "${inputs.ghostty-cursor}/boo-cursor.glsl" ];
      custom-shader-animation = "always";

      window-padding-x = 5;
      window-padding-y = 5;
      window-padding-balance = true;
      window-decoration = true;
      window-show-tab-bar = "never";

      scrollback-limit = 50000000;

      font-family = config.stylix.fonts.monospace.name;
      font-size = config.stylix.fonts.sizes.terminal;

      keybind = [
        "alt+shift+a=new_tab"
        "alt+shift+s=close_surface"
        "alt+1=goto_tab:1"
        "alt+2=goto_tab:2"
        "alt+3=goto_tab:3"
        "alt+4=goto_tab:4"
        "alt+5=goto_tab:5"
        "alt+6=goto_tab:6"
        "alt+7=goto_tab:7"
        "alt+8=goto_tab:8"
        "alt+9=goto_tab:9"
        "ctrl+l=clear_screen"
      ];
    };

    # clearDefaultKeybinds = true;
    installVimSyntax = true;
    installBatSyntax = true;
    systemd.enable = true;
  };

  stylix.targets.ghostty = {
    enable = true;
    fonts.enable = false;
  };
}
