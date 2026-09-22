{
  inputs,
  ...
}:
[
  (final: prev: {
    myPkgs = (prev.myPkgs or { }) // {
      assets = final.callPackage ./assets { };
      audio-manager = final.callPackage ./audio-manager { };
      brightness-control = final.callPackage ./brightness-control { };
      claude-desktop = final.callPackage ./claude-desktop { };
      msbuild-ls = final.callPackage ./msbuild-ls { };
      patchy-cnb = final.callPackage ./patchy-cnb { };
      vaultwarden-sync = final.callPackage ./vaultwarden-sync { };
      vivaldi-sync = final.callPackage ./vivaldi-sync { };
      volume-control = final.callPackage ./volume-control { };
      warp = final.callPackage ./warp { };
      wps = final.callPackage ./wps { };
      zalo-for-linux = final.callPackage ./zalo-for-linux { };

      icons = final.callPackage ./icons.nix { };
      screenshot = final.callPackage ./screenshot.nix { };
      sklauncher = final.callPackage ./sklauncher.nix { };
      wallpapers = final.callPackage ./wallpapers.nix { };
      screenrecord = final.callPackage ./sreenrecord.nix { };
      waycal = final.callPackage ./waycal.nix { };

      waybar = inputs.waybar.packages.${final.stdenv.system}.waybar;
    };

    nixos-live = inputs.self.nixosConfigurations.nixos-live.config.system.build.isoImage;
  })
]
