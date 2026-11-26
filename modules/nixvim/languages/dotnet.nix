{
  modules.nixvim.languages = {
    cs =
      { pkgs, ... }:
      {
        plugins.lsp.servers.roslyn_ls = {
          enable = true;
          package = pkgs.roslyn-ls;
        };

        plugins.conform-nvim.settings.formatters_by_ft = {
          cs = [ "csharpier" ];
        };

        plugins.treesitter.settings.ensure_installed = [ "c_sharp" ];
        extraPackages = with pkgs; [ dotnet.sdk ];
      };

    fs = {
      plugins.lsp.servers.fsautocomplete = {
        enable = true;
      };

      plugins.conform-nvim.settings.formatters_by_ft = {
        fs = [ "fsharp" ];
      };

      plugins.treesitter.settings.ensure_installed = [ "fsharp" ];
    };

    msbuild =
      { pkgs, ... }:
      {
        plugins.lsp.servers.msbuild_project_tools_server = {
          enable = true;
          package = pkgs.myPkgs.msbuild-ls;
          cmd = [
            "${pkgs.coreutils}/bin/env"
            "DOTNET_ROOT=${pkgs.dotnet-sdk}"
            "${pkgs.dotnet-sdk}/bin/dotnet"
            "${pkgs.myPkgs.msbuild-ls}/lib/msbuild-project-tools-server/MSBuildProjectTools.LanguageServer.Host.dll"
          ];
        };

        filetype = {
          extension = {
            props = "msbuild";
            tasks = "msbuild";
            targets = "msbuild";
          };

          pattern = {
            ".*\\..*proj" = "msbuild";
          };
        };

        extraConfigLua = "vim.treesitter.language.register('xml', { 'msbuild' })";
        plugins.conform-nvim.settings.formatters_by_ft.msbuild = [ "xmllint" ];
        extraPackages = [ pkgs.libxml2 ];
      };
  };
}
