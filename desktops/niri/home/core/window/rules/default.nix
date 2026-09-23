{
  programs.niri.settings = {
    prefer-no-csd = true;

    window-rules = [
      {
        matches = [ { } ];
        geometry-corner-radius = {
          top-left = 6.0;
          top-right = 6.0;
          bottom-left = 6.0;
          bottom-right = 6.0;
        };
        clip-to-geometry = true;
      }

      {
        matches = [ { title = "^Picture in picture$"; } ];
        open-floating = true;

        default-floating-position = {
          relative-to = "bottom-right";
          x = 20;
          y = 20;
        };
        default-column-width = {
          fixed = 400;
        };

        default-window-height = {
          fixed = 200;
        };

        # block-out-from = "screencast";
      }
    ];
  };

  programs.nsticky.settings.sticky = {
    pip.title = "^Picture in picture$";
  };

  imports = [
    ./nsticky.nix
  ];
}
