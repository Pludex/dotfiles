{ lib, config, ... }:
{

  programs.hyprland.settings = {
    binds = {
      "Mod+D".dsp.__raw =
        let
          layoutsLua =
            "{ "
            + lib.concatMapStringsSep ", " builtins.toJSON config.programs.hyprland.settings.layoutNames
            + " }";
        in
        ''
          (function()
            local layouts = ${layoutsLua}
            local current = 1
            return function()
              current = (current % #layouts) + 1
              hl.config({ general = { layout = layouts[current] } })
            end
          end)()
        '';
    };

    general = {
      gaps_in = 3;
      gaps_out = 5;
    };
  };
}
