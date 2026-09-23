{
  programs.atuin = {
    enable = true;
    settings = {
      keymap_mode = "vim-normal";
      search_mode = "prefix";
      style = "compact";
    };

    flags = [ "--disable-ctrl-r" ];
  };
}
