{ base, ... }:
{
  programs.superfile = {
    enable = true;

    firstUseCheck = true;

    settings = {
      file_editor = base.tools.editor;
      nerdfont = true;
      transparent_background = true;
    };

    pinnedFolders = [
      {
        name = "Nix Config";
        location = base.abs.dotfiles;
      }
      {
        name = "Projects";
        location = base.abs.workspaces;
      }
    ];
  };
}
