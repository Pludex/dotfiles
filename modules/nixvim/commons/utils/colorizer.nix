{
  plugins.colorizer = {
    enable = true;

    settings = {
      filetypes = [ "*" ];
      user_default_options = {
        RGB = true;
        RRGGBB = true;
        names = true;
        RRGGBBAA = true;
        AARRGGBB = false;
        rgb_fn = true;
        hsl_fn = true;
        css = true;
        css_fn = true;

        mode = "virtualtext";
      };
    };
  };
}
