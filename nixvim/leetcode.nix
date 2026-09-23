{
  plugins.nui.enable = true;

  plugins.leetcode = {
    enable = true;
    settings = {
      lang = "csharp";

      storage = {
        home = "/workspaces/leetcode";
        kaggle = false;
      };

      console = {
        open_on_runcode = true;
        size = {
          width = "75%";
          height = "75%";
        };
      };
      image_support = true;
    };
  };
}
