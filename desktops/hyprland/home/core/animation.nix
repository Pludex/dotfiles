{
  programs.hyprland.settings = {
    animations = {
      curves = {
        easeOutQuint = {
          type = "bezier";
          points = [
            [
              0.22
              1.0
            ]
            [
              0.36
              1.0
            ]
          ];
        };
        easeOutExpo = {
          type = "bezier";
          points = [
            [
              0.16
              1.0
            ]
            [
              0.3
              1.0
            ]
          ];
        };
        easeInOutCubic = {
          type = "bezier";
          points = [
            [
              0.65
              0.0
            ]
            [
              0.35
              1.0
            ]
          ];
        };
        linear = {
          type = "bezier";
          points = [
            [
              0.0
              0.0
            ]
            [
              1.0
              1.0
            ]
          ];
        };
      };

      entries = [
        # Windows
        {
          leaf = "windowsIn";
          enabled = true;
          speed = 5;
          bezier = "easeOutExpo";
          style = "popin 85%";
        }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 4;
          bezier = "easeOutQuint";
          style = "popin 85%";
        }
        {
          leaf = "windowsMove";
          enabled = true;
          speed = 5;
          bezier = "easeOutQuint";
        }

        # Fade
        {
          leaf = "fadeIn";
          enabled = true;
          speed = 4;
          bezier = "easeOutQuint";
        }
        {
          leaf = "fadeOut";
          enabled = true;
          speed = 3;
          bezier = "easeOutQuint";
        }
        {
          leaf = "fadeSwitch";
          enabled = true;
          speed = 4;
          bezier = "easeOutQuint";
        }

        # Workspaces
        {
          leaf = "workspaces";
          enabled = true;
          speed = 6;
          bezier = "easeOutExpo";
          style = "slide";
        }
        {
          leaf = "specialWorkspace";
          enabled = true;
          speed = 5;
          bezier = "easeOutExpo";
          style = "slidevert";
        }

        # Border
        {
          leaf = "border";
          enabled = true;
          speed = 8;
          bezier = "easeOutQuint";
        }
        {
          leaf = "borderangle";
          enabled = true;
          speed = 40;
          bezier = "linear";
          style = "loop";
        }

        # Layers (bars, launchers, notifications)
        {
          leaf = "layers";
          enabled = true;
          speed = 4;
          bezier = "easeOutQuint";
          style = "fade";
        }

        {
          leaf = "workspaces";
          enabled = true;
          speed = 3;
          bezier = "easeOutQuint";
          style = "slide";
        }

        {
          leaf = "specialWorkspace";
          enabled = true;
          speed = 3;
          bezier = "easeOutQuint";
          style = "slidevert";
        }
      ];
    };
  };
}
