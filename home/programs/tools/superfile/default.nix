{ base, lib, ... }:
{
  programs.superfile = {
    enable = true;

    firstUseCheck = true;

    settings = {
      # Cấu hình chính từ bản mẫu của bạn
      theme = "catppuccin";
      editor = "${lib.getExe base.tools.editor}";
      dir_editor = "";
      auto_check_update = false;
      cd_on_quit = false;
      default_open_file_preview = true;
      show_image_preview = true;
      show_panel_footer_info = true;
      default_directory = base.abs.workspaces;
      file_size_use_si = false;
      default_sort_type = 0;
      sort_order_reversed = false;
      case_sensitive_sort = false;
      shell_close_on_success = false;
      debug = false;
      ignore_missing_fields = false;

      nerdfont = true;
      transparent_background = true;
      file_preview_width = 0;
      syntax_highlight = "bat";

      metadata = true;
      zoxide_support = true;
      code_previewer = "bat";

      # sidebar_width = 30;
      border_top = "─";
      border_bottom = "─";
      border_left = "│";
      border_right = "│";
      border_top_left = "╭";
      border_top_right = "╮";
      border_bottom_left = "╰";
      border_bottom_right = "╯";
      border_middle_left = "├";
      border_middle_right = "┤";
      enable_md5_checksum = false;
      sidebar_width = 20;
    };

    pinnedFolders = [
      {
        name = "Dotfiles";
        location = base.abs.dotfiles;
      }
      {
        name = "Workspaces";
        location = base.abs.workspaces;
      }
    ];
  };
}
