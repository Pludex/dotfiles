let
  openFloat = prefills: ''
    function()
      local width = math.floor(vim.o.columns * 0.8)
      local height = math.floor(vim.o.lines * 0.8)
      local prefills = ${prefills}
      local buf = vim.api.nvim_create_buf(false, true)

      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
      })

      vim.wo[win].winhighlight = table.concat({
        "Normal:GrugFarFloat",
        "NormalFloat:GrugFarFloat",
        "EndOfBuffer:GrugFarFloat",
        "FloatBorder:GrugFarBorder",
        "FloatTitle:GrugFarBorder",
      }, ",")

      require("grug-far").open({
        windowCreationCommand = "enew",
        transient = true,
        prefills = prefills,
      })
    end
  '';
in
{
  plugins.grug-far = {
    enable = true;

    settings = {
      engine.ripgrep = {
        enable = true;

        placeholders = {
          search.placeholder = "Enter the search word...";
          replacement.placeholder = "Enter replacement word...";
        };
      };

      headerMaxWidth = 80;
      minSearchChars = 2;
      debounceMs = 500;

      icons = {
        enabled = true;
        actionEntryBullet = " ";
        searchInputPrefix = " ";
        replaceInputPrefix = " ";
        filesFilterInputPrefix = "󰈲 ";
        pathsInputPrefix = "󰴠 ";
        flagsInputPrefix = " ";
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
        replace = {
          n = "<localleader>r";
        };
        qflist = {
          n = "<localleader>q";
        };
        syncLocations = {
          n = "<localleader>s";
        };
        syncLine = {
          n = "<localleader>l";
        };
        close = {
          n = "q";
        };
        historyOpen = {
          n = "<localleader>h";
        };
        historyAdd = {
          n = "<localleader>a";
        };
        refresh = {
          n = "<localleader>f";
        };
        openLocation = {
          n = "<enter>";
        };
        openNextLocation = {
          n = "<down>";
        };
        openPrevLocation = {
          n = "<up>";
        };
        gotoLocation = {
          n = "<localleader>g";
        };
        pickHistoryEntry = {
          n = "<enter>";
        };
        abort = {
          n = "<localleader>b";
        };
        help = {
          n = "g?";
        };
        toggleShowCommand = {
          n = "<localleader>p";
        };
        swapEngine = {
          n = "<localleader>e";
        };
        applyNext = {
          n = "<localleader>n";
        };
        applyPrev = {
          n = "<localleader>N";
        };
        previewLocation = {
          n = "<localleader>i";
        };
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>fr";
      action.__raw = openFloat "{}";
      options = {
        desc = "Search and replace in repo (float)";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>fb";
      action.__raw = openFloat ''{ paths = vim.fn.expand("%") }'';
      options = {
        desc = "Search and replace in current buffer (float)";
        silent = true;
      };
    }
  ];
}
