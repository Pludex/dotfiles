let
  plugin = name: isDefault: { modules.nixvim.plugins = [ name ]; };
in
{
  modules.nixvim = {
    commons = [
      ./autopairs
      ./conform
      ./gitsigns
      ./lsp
      ./lualine
      ./mini
      ./navic
      ./schemastore
      ./treesitter
      ./treesitter-context
      ./web-devicons
    ];

    plugins = {
      auto-save = ./auto-save;
      auto-session = ./auto-session;
      blink-cmp = ./blink-cmp;
      cmp = ./cmp;
      colorizer = ./colorizer;
      diffview = ./diffview;
      direnv = ./direnv;
      grug-far = ./grug-far;
      lazygit = ./lazygit;
      leetcode = ./leetcode;
      lspkind = ./lspkind;
      luasnip = ./luasnip;
      neo-tree = ./neo-tree;
      noice = ./noice;
      obsidian = ./obsidian;
      snacks-dashboard = ./snacks/dashboard.nix;
      snacks-explorer = ./snacks/explorer.nix;
      snacks-image = ./snacks/image.nix;
      snacks-notifier = ./snacks/notifier.nix;
      snacks-picker = ./snacks/picker.nix;
      suda = ./suda;
      telescope = ./telescope;
      toggleterm = ./toggleterm;
      trouble = ./trouble;
    };
  };

  # Slot names are prefixed with `nvim-` because they must be unique across all domains
  tools.nixvim = {
    completion = {
      blink-cmp = plugin "blink-cmp";
      cmp = {
        modules.nixvim.plugins = [
          "cmp"
          "lspkind"
        ];
      };
    };

    file-explorer = {
      neo-tree = plugin "neo-tree";
      snacks-explorer = plugin "snacks-explorer";
    };

    picker = {
      telescope = plugin "telescope";
      snacks-picker = plugin "snacks-picker";
    };

    notifier = {
      noice = plugin "noice";
      snacks-notifier = plugin "snacks-notifier";
    };

    dashboard = {
      snacks-dashboard = plugin "snacks-dashboard";
    };

    image = {
      snacks-image = plugin "snacks-image";
    };

    snippets = {
      luasnip = plugin "luasnip";
    };

    auto-save = {
      auto-save = plugin "auto-save";
    };

    session = {
      auto-session = plugin "auto-session";
    };

    colorizer = {
      colorizer = plugin "colorizer";
    };

    git-diff = {
      diffview = plugin "diffview";
    };

    git-client = {
      lazygit = plugin "lazygit";
    };

    search-replace = {
      grug-far = plugin "grug-far";
    };

    leetcode = {
      leetcode = plugin "leetcode";
    };

    sudo-write = {
      suda = plugin "suda";
    };

    terminal = {
      toggleterm = plugin "toggleterm";
    };

    diagnostics = {
      trouble = plugin "trouble";
    };
  };

  defaults.tools.nixvim = {
    completion = "blink-cmp";
    file-explorer = "neo-tree";
    picker = "telescope";
    notifier = "snacks-notifier";
    dashboard = "snacks-dashboard";
    image = "snacks-image";
    snippets = "luasnip";
    auto-save = "auto-save";
    session = "auto-session";
    colorizer = "colorizer";
    git-diff = "diffview";
    git-client = "lazygit";
    search-replace = "grug-far";
    leetcode = "leetcode";
    sudo-write = "suda";
    terminal = "toggleterm";
    diagnostics = "trouble";
  };
}
