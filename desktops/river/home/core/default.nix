{
  programs.river.settings = {
    keyMod = "Mod1";
    declareModes = [ "control" ];

    keymaps = {
      normal = [
        {
          modifiers = "Mod";
          keysym = "Escape";
          command = "enter-mode control";
        }

        {
          modifiers = "Mod";
          keysym = "e";
          command = "exit";
        }

        {
          modifiers = "Mod";
          keysym = "r";
          command = "spawn ~/.config/river/init";
        }
      ];

      control = [
        {
          modifiers = "Mod";
          keysym = "Escape";
          command = "enter-mode normal";
        }

        {
          keysym = "Escape";
          command = "enter-mode normal";
        }

        {
          keysym = "e";
          command = "exit";
        }

        {
          keysym = "r";
          command = "spawn ~/.config/river/init";
        }
      ];
    };
  };

  imports = [
    ./window.nix
  ];
}
