{
  plugins.noice = {
    enable = true;

    settings = {
      cmdline = {
        enabled = true;
      };

      popupmenu = {
        enabled = false;
      };

      views = {
        cmdline_popup = {
          position = {
            row = "98%";
            col = "2%";
          };
          size = {
            width = 70;
            height = "auto";
          };
        };
        popupmenu = {
          relative = "editor";
          position = {
            row = 8;
            col = "50%";
          };
          size = {
            width = 70;
            height = 10;
          };
          border = {
            style = "rounded";
            padding = [
              0
              1
            ];
          };

          win_options.winhighlight = "Normal:Normal,FloatBorder:DiagnosticInfo";
        };
      };
    };
  };
}
