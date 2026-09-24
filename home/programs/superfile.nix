{ base, lib, ... }:
{
  programs.superfile = {
    enable = true;

    firstUseCheck = true;

    settings = {
      file_editor = lib.getExe base.tools.editor;
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
