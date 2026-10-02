{ inputs, ... }:
(final: prev: {
  hyprland = inputs.hyprland.packages.${final.stdenv.system}.hyprland;

  hyprlandPlugins =
    prev.hyprlandPlugins
    // inputs.hyprland-plugins.packages.${final.stdenv.system}
    // {
      hyprexpo = inputs.hyprexpo.packages.${final.stdenv.system}.default;
    };
})
