{
  programs.lazygit = {
    enable = true;

    settings = {
      gui = {
        language = "en";
        showIcons = true;
      };

      git = {
        autoFetch = true;
        diffRenderers = [
          {
            colorArg = "always";
            command = "delta --dark --paging=never --line-numbers";
          }
        ];
      };
    };
  };

  stylix.targets.lazygit.enable = true;
}
