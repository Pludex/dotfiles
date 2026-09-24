{ base, lib, ... }:
{
  programs.niri.settings.binds = {
    "Mod+Shift+E".action.quit = { };
    "Mod+grave".action.spawn = lib.getExe base.tools.term;
    "Mod+Tab".action.toggle-overview = { };
  };
}
