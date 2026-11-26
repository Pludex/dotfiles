{
  modules.nixvim = {
    commons = [
      ({ pkgs, ... }: {
        extraPlugins = with pkgs.vimPlugins; [
          plenary-nvim
        ];
      })

      ./diagnostic.nix
      ./keymaps.nix
      ./options.nix
      ./window.nix
    ];
  };

  imports = [
    ./languages/data.nix
    ./languages/docs.nix
    ./languages/dotnet.nix
    ./languages/scripting.nix
    ./languages/system.nix
    ./languages/web.nix

    ./themes
    ./plugins
  ];
}
