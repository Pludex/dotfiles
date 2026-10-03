{
  programs.hyprland.settings.animations = {
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
      easeInCubic = {
        type = "bezier";
        points = [
          [
            0.32
            0.0
          ]
          [
            0.67
            0.0
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
      {
        leaf = "windowsIn";
        enabled = true;
        speed = 5;
        bezier = "easeOutExpo";
        style = "popin 80%";
      }
      {
        leaf = "windowsOut";
        enabled = true;
        speed = 3;
        bezier = "easeInCubic";
        style = "popin 90%";
      }
      {
        leaf = "windowsMove";
        enabled = true;
        speed = 4;
        bezier = "easeOutQuint";
      }

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

      {
        leaf = "layers";
        enabled = true;
        speed = 4;
        bezier = "easeOutQuint";
        style = "fade";
      }
    ];
  };
}
