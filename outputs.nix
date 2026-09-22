{ inputs, ... }:
{
  home = {
    default = {
      profile = "desktop";
      desktop = "niri";
      system = "x86_64-linux";
    };

    "pbcdev@dp7530" = {
      profile = "desktop";
      desktop = "MangoWM";
      system = "x86_64-linux";
    };
  };

  nixos = {
    default = {
      profile = "desktop";
      desktop = "niri";
      host = "dp7530";
      system = "x86_64-linux";
    };

    dp7530 = {
      profile = "desktop";
      desktop = "MangoWM";
      host = "dp7530";
      system = "x86_64-linux";
    };

    nixos-live = {
      profile = "live";
      desktop = "niri";
      host = "live";
      system = "x86_64-linux";
    };
  };

  nixvim = {
    ecode = { };
  };

  systems = [
    "x86_64-linux"
  ];

  overlaysOfInputs = with inputs; [
    chaotic.overlays.default
    vscode-extensions.overlays.default
    nix-firefox-addons.overlays.default
    nur.overlays.default
    treesitter-kanata.overlays.default
    obsidian-extensions.overlays.default
    emacs-overlays.overlays.default
  ];

  nixpkgsConfig = {
    allowUnfree = true;
    allowBroken = true;

    permittedInsecurePackages = [
      "electron-41.10.6"
    ];

    problems.handlers = {
      zfs.broken = "ignore";
    };
  };
}
