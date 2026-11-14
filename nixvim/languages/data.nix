{
  modules.nixvim.languages = {
    json = {
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
    };

    xml = {
      plugins.lsp.servers.lemminx = {
        enable = true;
      };

      plugins.treesitter.settings.ensure_installed = [ "xml" ];

      plugins.conform-nvim.settings.formatters_by_ft = {
        xml = [ "xmlformatter" ];
      };
    };

    yml-yaml = {
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
    };
  };
}
