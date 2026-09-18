{ inputs, base, ... }:
{
  programs.kitty = {
    enable = true;

    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;
      update_check_interval = 0;

      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      tab_title_template = "{title}{' :{}:'.format(num_windows) if num_windows > 1 else ''}";

      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      window_padding_width = 5;
      cursor_trail = 1;

      # background_image_layout = "scaled";
      # background_image_linear = true;
      background_tint = "1.0";
    };

    keybindings = {
      "alt+shift+a" = "new_tab";
      "alt+shift+s" = "close_tab";

      "alt+shift+f" = "previous_tab";
      "alt+shift+d" = "next_tab";

      "alt+1" = "goto_tab 1";
      "alt+2" = "goto_tab 2";
      "alt+3" = "goto_tab 3";
      "alt+4" = "goto_tab 4";
      "alt+5" = "goto_tab 5";
      "alt+6" = "goto_tab 6";
      "alt+7" = "goto_tab 7";
      "alt+8" = "goto_tab 8";
      "alt+9" = "goto_tab 9";
      "alt+0" = "goto_tab 10";
    };

    extraConfig = ''
      # include ${inputs.schemes}/tools/tokyonight/kitty.night.conf
      # include ${inputs.schemes}/tools/nightfox/kitty.carbonfox.conf
    '';
  };

  stylix.targets.kitty.enable = true;
}
