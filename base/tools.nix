{
  extraBase.tools = rec {
    shell = "fish";
    editor = "nvim";
    browser = "vivaldi";
    pager = "bat --plain --pager='less -FR'";
    term = "kitty";

    alias = {
      cd = "z";
      cat = "bat";
      less = pager;
      nano = editor;
      grep = "rg";
      find = "fd";
      tree = "eza -T";
    };
  };
}
