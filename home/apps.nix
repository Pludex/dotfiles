{ inputs, base, ... }:
let
  zaloPkg =
    pkgs: inputs:
    inputs.zalo-for-linux.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      dwarfs = pkgs.dwarfs.overrideAttrs {
        checkPhase = ''
          runHook preCheck
          ctest -j$NIX_BUILD_CORES -E 'dwarfsextract_format_test\.basic/\((pwb|raw|xar), (false|true)\)'
          runHook postCheck
        '';
      };
    };

in
{
  modules.home.apps = {
    bitwarden = { pkgs, ... }: {
      home.packages = [ pkgs.stable.bitwarden-desktop ];
    };

    discord = { pkgs, ... }: {
      home.packages = [ pkgs.discord ];
    };

    obsidian = { pkgs, ... }: {
      programs.obsidian = {
        enable = true;
        package = pkgs.stable.obsidian;
        cli.enable = true;

        defaultSettings = {
          communityPlugins = with pkgs.stable.obsidianPlugins; [
            dataview
            obsidian-git
            obsidian-vimrc-support
          ];

          hotkeys = { };
        };

        vaults.main = {
          enable = true;
          target = "${base.abs.workspaces}/vaults/main";
        };
      };

      stylix.targets.obsidian.enable = true;
    };

    sklauncher = { pkgs, ... }: {
      home.packages = with pkgs; [
        myPkgs.sklauncher
      ];
    };

    soundcloud = { pkgs, ... }: {
      home.packages = [
        pkgs.myPkgs.soundcloud-desktop
      ];
    };

    spotify = { pkgs, ... }: {
      home.packages = [
        (pkgs.spotify.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
          postFixup = (old.postFixup or "") + ''
            wrapProgram $out/bin/spotify \
              --add-flags "--enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3"
          '';
        }))
      ];
    };

    steam = { pkgs, ... }: {
      home.packages = [
        pkgs.steam
      ];
    };

    vivaldi = { pkgs, ... }: {
      home.packages = with pkgs; [
        vivaldi
        vivaldi-ffmpeg-codecs

        myPkgs.vivaldi-sync
      ];
    };

    wps = { pkgs, ... }: {
      home.packages = [
        pkgs.myPkgs.wps
      ];
    };

    zalo = { inputs, pkgs, ... }: {
      imports = [ inputs.zalo-for-linux.homeManagerModules.default ];

      programs.zalo = {
        enable = true;
        package = zaloPkg pkgs inputs;
      };
    };
  };

  perSystem = { pkgs, ... }: {
    ciPackages.zalo = zaloPkg pkgs inputs;
  };
}
