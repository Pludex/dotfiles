{
  inputs,
  args,
  ...
}:
[
  (final: prev: {
    myPkgs = rec {
      audio-manager = final.callPackage ./audio-manager { };
      brightness-control = final.callPackage ./brightness-control { };
      msbuild-ls = final.callPackage ./msbuild-ls { };
      patchy-cnb = final.callPackage ./patchy-cnb { };
      vaultwarden-sync = final.callPackage ./vaultwarden-sync { };
      vivaldi-sync = final.callPackage ./vivaldi-sync { };
      volume-control = final.callPackage ./volume-control { };
      wallpapers = final.callPackage ./wallpapers { };
      wps = final.callPackage ./wps { };

      claude-desktop = final.callPackage ./claude-desktop.nix { inherit patchy-cnb; };
      screenshot = final.callPackage ./screenshot.nix { };
      sklauncher = final.callPackage ./sklauncher.nix { };
      screenrecord = final.callPackage ./sreenrecord.nix { };
      waycal = final.callPackage ./waycal.nix { };

      waybar = inputs.waybar.packages.${final.stdenv.system}.waybar;
    }
    // (import ./nixvim.nix (args // { pkgs = final; }));

    nixos-live = inputs.self.nixosConfigurations.nixos-live.config.system.build.isoImage;
  })
]
