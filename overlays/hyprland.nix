{ inputs, ... }:
(final: prev: {
  hyprland = inputs.hyprland.packages.${final.stdenv.system}.hyprland.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ final.glaze ];
  });
})
