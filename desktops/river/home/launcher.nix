{
  base,
  lib,
  config,
  ...
}:
{
  imports = [
    "${base.paths.commonDesktop}/fuzzel.nix"
  ];

  programs.river.settings = {
    keymaps = {
      normal = [
        {
          modifiers = "Mod";
          keysym = "a";
          command = "spawn ${lib.getExe config.programs.fuzzel.package}";
        }
      ];

      control = [
        {
          keysym = "a";
          command = "spawn ${lib.getExe config.programs.fuzzel.package}";
        }
      ];
    };
  };
}
