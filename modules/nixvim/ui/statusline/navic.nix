{
  plugins.navic = {
    enable = true;
    settings = {
      highlight = true;
      click = true;
      lsp = {
        auto_attach = true;
      };

      icons.__raw = ''
        (function()
          local lspkind_icons = require("lspkind").symbol_map
          local navic_icons = {}
          for kind, icon in pairs(lspkind_icons) do
            navic_icons[kind] = icon .. " "
          end
          return navic_icons
        end)()
      '';
    };
  };

  lsp.onAttach = ''
    if client.server_capabilities.documentSymbolProvider then
      require("nvim-navic").attach(client, bufnr)
    end
  '';
}
