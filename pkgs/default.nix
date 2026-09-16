{
  inputs,
  args,
  ...
}:
[
  (final: prev: {
    myPkgs = {
      audio-manager = final.callPackage ./audio-manager { };
      brightness-control = final.callPackage ./brightness-control { };
      msbuild-ls = final.callPackage ./msbuild-ls { };
      vaultwarden-sync = final.callPackage ./vaultwarden-sync { };
      vivaldi-sync = final.callPackage ./vivaldi-sync { };
      volume-control = final.callPackage ./volume-control { };
      wps = final.callPackage ./wps { };
      sklauncher = final.callPackage ./sklauncher.nix { };
      waycal = final.callPackage ./waycal.nix { };

      waybar = inputs.waybar.packages.${final.stdenv.system}.waybar;
    }
    // (import ./nixvim.nix (args // { pkgs = final; }));

    nixos-live = inputs.self.nixosConfigurations.nixos-live.config.system.build.isoImage;
  })
]
