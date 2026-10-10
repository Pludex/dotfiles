{ inputs, base, ... }:
(final: prev: {
  hyprland = inputs.hyprland.packages.${final.stdenv.system}.hyprland;

  hyprlandPlugins =
    prev.hyprlandPlugins
    // inputs.hyprland-plugins.packages.${final.stdenv.system}
    // {
      hyprexpo = inputs.hyprexpo.packages.${final.stdenv.system}.default;

      hyprsession = inputs.hyprsession.packages.${final.stdenv.system}.default.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ "${base.paths.patchs}/hyprsession-ignore.patch" ];
        meta.mainProgram = "hyprsession";
      });

      hyprdrover = final.callPackage (
        {
          lib,
          rustPlatform,
          makeWrapper,
          libnotify,
        }:

        rustPlatform.buildRustPackage {
          pname = "hyprdrover";
          version = (lib.importTOML "${inputs.hyprdrover}/Cargo.toml").package.version;

          src = inputs.hyprdrover;

          cargoLock.lockFile = "${inputs.hyprdrover}/Cargo.lock";

          nativeBuildInputs = [ makeWrapper ];

          postInstall = ''
            wrapProgram $out/bin/hyprdrover \
              --suffix PATH : ${lib.makeBinPath [ libnotify ]}
          '';

          meta = {
            description = "Lightweight session manager for Hyprland";
            homepage = "https://github.com/S-Sigdel/hyprdrover";
            mainProgram = "hyprdrover";
            platforms = lib.platforms.linux;
          };
        }
      ) { };
    };
})
