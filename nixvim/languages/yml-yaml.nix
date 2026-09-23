{
  plugins.schemastore.yaml.enable = true;

  plugins.lsp.servers.yamlls = {
    enable = true;
    extraOptions = {
      settings = {
        yaml = {
          schemaStore = {
            enable = false;
            url = "";
          };
        };
      };
    };
  };

  plugins.treesitter.settings.ensure_installed = [
    "yaml"
  ];

  plugins.conform-nvim.settings.formatters_by_ft = {
    yaml = [ "prettier" ];
    yml = [ "prettier" ];
  };
}
