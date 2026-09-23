{
  plugins.lsp.servers.jsonls = {
    enable = true;

    settings = {
      json = {
        schemas = {
          __raw = "require('schemastore').json.schemas()";
        };
        validate.enable = true;
      };
    };
  };

  plugins.schemastore.json.enable = true;

  plugins.treesitter.settings.ensure_installed = [ "json" ];

  plugins.conform-nvim.settings.formatters_by_ft = {
    json = [ "prettier" ];
  };
}
