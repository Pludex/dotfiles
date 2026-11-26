{
  plugins.auto-session = {
    enable = true;

    settings = {
      auto_save_enabled = true;
      auto_restore_enabled = true;

      suppressed_dirs = [
        "/"
        "~/"
        "/tmp"
      ];
    };
  };
}
