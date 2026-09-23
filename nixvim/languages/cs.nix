{ pkgs, ... }:
{

  plugins.lsp.servers.roslyn_ls = {
    enable = true;
    package = pkgs.roslyn-ls;
  };

  plugins.conform-nvim.settings.formatters_by_ft = {
    cs = "csharpier";
  };

  plugins.treesitter.settings.ensure_installed = [ "c_sharp" ];
  extraPackages = with pkgs; [ dotnet.sdk ];
}
