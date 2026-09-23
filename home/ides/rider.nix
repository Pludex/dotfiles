{ pkgs, inputs, ... }:
let
  extra-path = with pkgs; [
    dotnet.sdk
    msbuild
    roslyn
    omnisharp-roslyn
  ];

  extra-lib = with pkgs; [
    stdenv.cc.cc.lib
  ];

  p = inputs.jetbrains-plugins.plugins."${pkgs.stdenv.system}".rider."2026.2";
  plugins = [
    p."IdeaVIM"
    p."com.nightfox.theme"
  ];
  riderWithPlugins = pkgs.stable.jetbrains.plugins.addPlugins pkgs.stable.jetbrains.rider plugins;

  rider = riderWithPlugins.overrideAttrs (attrs: {
    postInstall = ''
      mv $out/bin/rider $out/bin/.rider-toolless
      makeWrapper $out/bin/.rider-toolless $out/bin/rider \
        --argv0 rider \
        --prefix PATH : "${pkgs.lib.makeBinPath extra-path}" \
        --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath extra-lib}"

      shopt -s extglob
      ln -s $out/rider/!(bin) $out/
      shopt -u extglob
    ''
    + attrs.postInstall or "";
  });
in
{
  home.packages = [ rider ];
}
