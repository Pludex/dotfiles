{ base, lib, ... }: {
  programs.gh = {
    enable = true;
    settings = {
      version = 1;
      git_protocol = "https";
      editor = lib.getExe base.tools.editor;
      prompt = "enabled";
      prefer_editor_prompt = "disabled";
      pager = lib.getExe base.tools.pager;
      browser = lib.getExe base.tools.browser;

      color_labels = "disabled";
      accessible_colors = "disabled";
      accessible_prompter = "disabled";
      spinner = "enabled";
    };
  };
}
