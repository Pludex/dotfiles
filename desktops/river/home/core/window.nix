let
  movePx = "20";
  resizePx = "20";
in
{
  programs.river.settings = {
    keymaps = {
      normal = [
        {
          modifiers = "Mod";
          keysym = "q";
          command = "close";
        }

        # Focus
        {
          modifiers = "Mod";
          keysym = "h";
          command = "focus-view -skip-floating left";
        }
        {
          modifiers = "Mod";
          keysym = "j";
          command = "focus-view -skip-floating down";
        }
        {
          modifiers = "Mod";
          keysym = "k";
          command = "focus-view -skip-floating up";
        }
        {
          modifiers = "Mod";
          keysym = "l";
          command = "focus-view -skip-floating right";
        }

        # Move
        {
          repeat = true;
          modifiers = "Mod+Shift";
          keysym = "h";
          command = "move left ${movePx}";
        }
        {
          repeat = true;
          modifiers = "Mod+Shift";
          keysym = "j";
          command = "move down ${movePx}";
        }
        {
          repeat = true;
          modifiers = "Mod+Shift";
          keysym = "k";
          command = "move up ${movePx}";
        }
        {
          repeat = true;
          modifiers = "Mod+Shift";
          keysym = "l";
          command = "move right ${movePx}";
        }

        # Resize
        {
          repeat = true;
          modifiers = "Mod+Control";
          keysym = "h";
          command = "resize left ${resizePx}";
        }
        {
          repeat = true;
          modifiers = "Mod+Control";
          keysym = "j";
          command = "resize down ${resizePx}";
        }
        {
          repeat = true;
          modifiers = "Mod+Control";
          keysym = "k";
          command = "resize top ${resizePx}";
        }
        {
          repeat = true;
          modifiers = "Mod+Control";
          keysym = "l";
          command = "resize right ${resizePx}";
        }
      ];

      control = [
        # Focus
        {
          keysym = "h";
          command = "focus-view -skip-floating left";
        }
        {
          keysym = "j";
          command = "focus-view -skip-floating down";
        }
        {
          keysym = "k";
          command = "focus-view -skip-floating up";
        }
        {
          keysym = "l";
          command = "focus-view -skip-floating right";
        }

        # Move
        {
          repeat = true;
          modifiers = "Shift";
          keysym = "h";
          command = "move left ${movePx}";
        }
        {
          repeat = true;
          modifiers = "Shift";
          keysym = "j";
          command = "move down ${movePx}";
        }
        {
          repeat = true;
          modifiers = "Shift";
          keysym = "k";
          command = "move up ${movePx}";
        }
        {
          repeat = true;
          modifiers = "Shift";
          keysym = "l";
          command = "move right ${movePx}";
        }

        # Resize
        {
          repeat = true;
          modifiers = "Control";
          keysym = "h";
          command = "resize left ${resizePx}";
        }
        {
          repeat = true;
          modifiers = "Control";
          keysym = "j";
          command = "resize down ${resizePx}";
        }
        {
          repeat = true;
          modifiers = "Control";
          keysym = "k";
          command = "resize top ${resizePx}";
        }
        {
          repeat = true;
          modifiers = "Control";
          keysym = "l";
          command = "resize right ${resizePx}";
        }
      ];
    };
  };
}
