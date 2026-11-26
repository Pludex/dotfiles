{
  opts = {
    number = true;
    relativenumber = true;
    modeline = false;

    conceallevel = 2;

    signcolumn = "yes";
    cursorline = true;

    shiftwidth = 2;
    tabstop = 2;
    expandtab = true;
    smartindent = true;

    ignorecase = true;
    smartcase = true;

    clipboard = "unnamedplus";
    undofile = true;

    updatetime = 300;
    mouse = "a";
    exrc = true;

    neovide_opacity = 1;

    neovide_normal_opacity = 0.4;
    neovide_floating_shadow = true;
    neovide_cursor_vfx_mode = "pixiedust";
    neovide_fullscreen = false;

    neovide_padding_top = 10;
    neovide_padding_bottom = 5;
    neovide_padding_left = 10;
    neovide_padding_right = 10;

    neovide_hide_mouse_when_typing = true;

    neovide_confirm_quit = true;
  };

  globals = {
    editorconfig.enable = true;
  };

  globals.mapleader = " ";

  keymaps = [
    {
      mode = "n";
      key = ";";
      action = ":";
    }
  ];

}
