{
  plugins.auto-save = {
    enable = true;

    settings = {
      enabled = true;

      trigger_events = {
        immediate_save = [
          "BufLeave"
          "FocusLost"
        ];
        defer_save = [
          "InsertLeave"
          "TextChanged"
        ];
        cancel_defer = [ "InsertEnter" ];
      };
      debounce_delay = 1000;
    };
  };
}
