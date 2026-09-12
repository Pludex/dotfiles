{ pkgs, ... }:
{
  plugins.lsp.servers.msbuild_project_tools_server = {
    enable = true;
    package = pkgs.myPkgs.msbuild-ls;
    cmd = [
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
}
