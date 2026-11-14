{ inputs, pkgs, ... }:
{
  imports = [ inputs.zalo-for-linux.homeManagerModules.default ];

  programs.zalo = {
    enable = true;
    package = inputs.zalo-for-linux.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      dwarfs = pkgs.dwarfs.overrideAttrs {
        checkPhase = ''
          runHook preCheck
          ctest -j$NIX_BUILD_CORES -E 'dwarfsextract_format_test\.basic/\((pwb|raw|xar), (false|true)\)'
          runHook postCheck
        '';
      };
    };
  };
}
