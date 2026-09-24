{
  myPkgs = {
    assets = {
      path = ./assets;
    };
    audio-manager = {
      path = ./audio-manager;
    };
    brightness-control = {
      path = ./brightness-control;
    };
    claude-desktop = {
      path = ./claude-desktop;
    };
    msbuild-ls = {
      path = ./msbuild-ls;
    };
    patchy-cnb = {
      path = ./patchy-cnb;
    };
    treesitter-kanata-vimPlugin = {
      path = ./treesitter-kanata;
    };
    vaultwarden-sync = {
      path = ./vaultwarden-sync;
    };
    vivaldi-sync = {
      path = ./vivaldi-sync;
    };
    volume-control = {
      path = ./volume-control;
    };
    warp = {
      path = ./warp;
    };
    wps = {
      path = ./wps;
    };
    zalo-for-linux = {
      path = ./zalo-for-linux;
    };

    icons = {
      path = ./icons.nix;
    };
    screenshot = {
      path = ./screenshot.nix;
    };
    sklauncher = {
      path = ./sklauncher.nix;
    };
    wallpapers = {
      path = ./wallpapers.nix;
    };
    screenrecord = {
      path = ./sreenrecord.nix;
    };
    waycal = {
      path = ./waycal.nix;
    };
  };

  perSystem =
    {
      inputs',
      config,
      ...
    }:
    {
      packagesOfInputs.waybar = inputs'.waybar.packages.default;
      ciPackages.waybar = config.packagesOfInputs.waybar;
    };
}
