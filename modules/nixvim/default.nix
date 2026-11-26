{
  modules.nixvim = {
    commons = [
      ./edit
      ./file
      ./git
      ./languages
      ./terminal
      ./ui
      ./utils
      ./img.nix
      ./session.nix
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
  ];

  modules.nixvim = {
    root = {
      leetcode = ./leetcode.nix;
    };
  };
}
