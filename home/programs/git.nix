{
  modules.home.programs = {
    delta = {
      programs.delta = {
        enable = true;
        options = {
          line-numbers = true;
          side-by-side = true;
          dark = true;
        };
      };
    };

    gh = { base, lib, ... }: {
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
    };

    lazygit = {
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
    };
  };
}
