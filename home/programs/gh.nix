{ base, ... }: {
  programs.gh = {
    enable = true;
    settings = {
      version = 1;
      git_protocol = "https";
      editor = base.tools.editor;
      prompt = "enabled";
      prefer_editor_prompt = "disabled";
      pager = base.tools.pager;
      browser = base.tools.browser;

      color_labels = "disabled";
      accessible_colors = "disabled";
      accessible_prompter = "disabled";
      spinner = "enabled";
    };
  };
}
