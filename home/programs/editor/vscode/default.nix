{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = with pkgs.nix-vscode-extensions.vscode-marketplace; [
        pkief.material-icon-theme
        enkia.tokyo-night

        # nix
        jnoortheen.nix-ide
        brettm12345.nixfmt-vscode
        editorconfig.editorconfig
        vancoding.vscode-treefmt-nix
        mkhl.direnv
      ];

      userSettings = {
        "window.titleBarStyle" = "custom";

        "workbench.activityBar.compact" = true;
        "workbench.sideBar.location" = "right";
        "workbench.activityBar.location" = "bottom";
        "workbench.iconTheme" = "catppuccin-mocha";

        "files.autoSave" = "afterDelay";

        "git.autofetch" = true;
        "git.confirmSync" = false;

        "terminal.integrated.minimumContrastRatio" = 1;

        "editor.fontLigatures" = true;
        "editor.semanticHighlighting.enabled" = true;
      };

      keybindings = [
        {
          key = "alt+a";
          command = "workbench.action.quickOpen";
        }
        {
          key = "alt+s";
          command = "workbench.action.closeActiveEditor";
        }
        {
          key = "alt+d";
          command = "workbench.action.quickOpenNavigateNextInEditorPicker";
          when = "inEditorsPicker";
        }
        {
          key = "alt+d";
          command = "workbench.action.showAllEditors";
        }
        {
          key = "alt+f";
          command = "workbench.action.quickOpenNavigatePreviousInEditorPicker";
          when = "inEditorsPicker";
        }
        {
          key = "alt+f";
          command = "workbench.action.showAllEditors";
        }
      ];
    };
  };
  stylix.targets.vscode.enable = true;
}
