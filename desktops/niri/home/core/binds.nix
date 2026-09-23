{ base, ... }:
{
  programs.niri.settings.binds = {
    "Mod+Shift+E".action.quit = { };
    "Mod+grave".action.spawn = base.tools.term;
    "Mod+Tab".action.toggle-overview = { };
  };
}
