{
  plugins.grug-far = {
    enable = true;

    settings = {
      engine.ripgrep = {
        enable = true;

        placeholders = {
          search = {
            placeholder = "Enter the search word...";
          };
          replacement = {
            placeholder = "Enter replacement word...";
          };
        };
      };

      headerMaxWidth = 80;
      minSearchChars = 2;

      debounceMs = 500;

      # searchFlags = "--hidden";

      icons = {
        enabled = true;
        actionEntryBullet = "▸ ";
        searchInputPrefix = "  ";
        replaceInputPrefix = "  ";
        filesFilterInputPrefix = "  ";
        pathsInputPrefix = "  ";
        flagsInputPrefix = "  ";
        resultsStatusReadyPrefix = "  ";
        resultsChangeIndicator = "┃";
        resultsAddedIndicator = "┃";
        resultsRemovedIndicator = "┃";
        resultsDiffSeparatorIndicator = "┊";
      };

      resultsHighlight.enabled = true;

      confirmAction = "y";

      history = {
        maxHistoryFiles = 100;
        autoSave = {
          enabled = true;
          onSearch = false;
          onReplace = true;
          onSyncAll = true;
        };
      };

      keymaps = {
        replace = "<localleader>r";
        qflist = "<localleader>q";
        syncLocations = "<localleader>s";
        syncLine = "<localleader>l";
        close = "<localleader>c";
        historyOpen = "<localleader>h";
        historyAdd = "<localleader>a";
        refresh = "<localleader>f";
        openLocation = "<enter>";
        openNextLocation = "<down>";
        openPrevLocation = "<up>";
        gotoLocation = "<localleader>g";
        pickHistoryEntry = "<enter>";
        abort = "<localleader>b";
        help = "g?";
        toggleShowCommand = "<localleader>p";
        swapEngine = "<localleader>e";
        applyNext = "<localleader>n";
        applyPrev = "<localleader>N";
        previewLocation = "<localleader>i";
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>fr";
      action = "<cmd>GrugFar<CR>";
      options = {
        desc = "Search and Replace (Float)";
        silent = true;
      };
    }
  ];
}
