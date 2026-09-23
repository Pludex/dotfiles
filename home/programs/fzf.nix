{
  programs.fzf = {
    enable = true;

    defaultCommand = "fd --type f --strip-cwd-prefix --hidden";
    fileWidget.command = "fd --type f --strip-cwd-prefix --hidden";
  };

  stylix.targets.fzf.enable = true;
}
