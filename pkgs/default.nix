{ inputs, argv, ... }: [
  (final: prev: {
    myPkgs = {
      audio-manager = final.callPackage ./audio-manager { };
      brightness-control = final.callPackage ./brightness-control { };
      vaultwarden-sync = final.callPackage ./vaultwarden-sync { };
      vivaldi-sync = final.callPackage ./vivaldi-sync { };
      volume-control = final.callPackage ./volume-control { };
      wps = final.callPackage ./wps { };
      nixvim = final.callPackage ./nixvim.nix { };
      sklauncher = final.callPackage ./sklauncher.nix { };
      waycal = final.callPackage ./waycal.nix { };
    }
    // (import ./nixvim.nix (argv // { pkgs = final; }));

    nixos-live = inputs.self.nixosConfigurations.nixos-live.config.system.build.isoImage;
  })
]
