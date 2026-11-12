{
  myPkgs = {
    assets.path = ./assets;
    audio-manager.path = ./audio-manager;
    brightness-control.path = ./brightness-control;
    claude-desktop.path = ./claude-desktop;
    clipboard.path = ./clipboard;
    lobehub.path = ./lobehub;
    msbuild-ls.path = ./msbuild-ls;
    patchy-cnb.path = ./patchy-cnb;
    schemes.path = ./schemes;
    vimPlugins.treesitter-kanata.path = ./treesitter-kanata;
    vaultwarden-sync.path = ./vaultwarden-sync;
    vivaldi-sync.path = ./vivaldi-sync;
    volume-control.path = ./volume-control;
    warp.path = ./warp;
    wps.path = ./wps;
    zalo-for-linux.path = ./zalo-for-linux;

    icons.path = ./icons.nix;
    openleetcode.path = ./openleetcode.nix;
    screenshot.path = ./screenshot.nix;
    sklauncher.path = ./sklauncher.nix;
    wallpapers.path = ./wallpapers.nix;
    screenrecord.path = ./sreenrecord.nix;
    waycal.path = ./waycal.nix;
  };

  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pyFinal: _: {
          tavily-client = pyFinal.callPackage ./tavily { };
          context7-client = pyFinal.callPackage ./context7 { };
          firecrawl-client = pyFinal.callPackage ./firecrawl { };
          web-tools = pyFinal.callPackage ./web-tools { };
        })
      ];
    })
  ];

  perSystem =
    { inputs', config, ... }:
    {
      inputPackages = {
        waybar = inputs'.waybar.packages.default;
        walker = inputs'.walker.packages.default;
      };

      ciPackages = {
        inherit (config.packageOfInputs) waybar walker;
      };
    };
}
