{ config, lib, ... }:

let
  cfg = config.programs.hyprland.settings;

  inherit (lib) mkOption types;

  # Same story as before: exactly one attr per dsp entry.
  # - "__raw" -> raw Lua expression, used as-is (must itself be a full hl.dsp.xxx(...) call)
  # - anything else -> hl.dsp.<name>(<args>)
  dspValueType = types.oneOf [
    types.str
    types.bool
    (types.listOf types.str)
  ];
  dspItemType = types.attrsOf dspValueType;

  flagsType = types.attrsOf (
    types.oneOf [
      types.bool
      types.str
    ]
  );

  bindType = types.submodule {
    options = {
      dsp = mkOption {
        type = types.listOf dspItemType;
        default = [ ];
        description = "One or more dispatchers; more than one is combined into a macro lambda";
      };
      flags = mkOption {
        type = flagsType;
        default = { };
      };
    };
  };

  submapType = types.submodule {
    options = {
      binds = mkOption {
        type = types.attrsOf bindType;
        default = { };
      };
    };
  };

  luaStr = s: builtins.toJSON s;
  luaVal = v: if builtins.isBool v then (if v then "true" else "false") else luaStr v;
  luaTable =
    attrs:
    "{ " + lib.concatStringsSep ", " (lib.mapAttrsToList (k: v: "${k} = ${luaVal v}") attrs) + " }";

  mkKeyExpr = key: luaStr (lib.replaceStrings [ "Mod" ] [ cfg.mainMod ] key);

  # One dsp item -> "hl.dsp.<name>(<args>)" or the raw expression for __raw.
  mkDspCallExpr =
    name: item:
    let
      keys = lib.attrNames item;
    in
    if keys == [ ] then
      throw "bind \"${name}\": each dsp entry must have exactly one attr"
    else if lib.length keys > 1 then
      throw "bind \"${name}\": each dsp entry must have only one attr (got: ${toString keys})"
    else
      let
        dspName = lib.head keys;
        val = item.${dspName};
      in
      if dspName == "__raw" then
        if !(builtins.isString val) then throw "bind \"${name}\": __raw must be a string" else val
      else
        let
          args =
            if val == true then
              ""
            else if val == false then
              throw "bind \"${name}\": dsp.${dspName} = false has no meaning"
            else if builtins.isString val then
              luaStr val
            else
              lib.concatMapStringsSep ", " luaStr val;
        in
        "hl.dsp.${dspName}(${args})";

  # Single dsp -> used directly as the dispatcher argument.
  # Multiple dsp (macro) -> wrapped in a lambda that invokes each in order.
  mkDispatcherExpr =
    name: b:
    if b.dsp == [ ] then
      throw "bind \"${name}\": dsp must have at least one entry"
    else if lib.length b.dsp == 1 then
      mkDspCallExpr name (lib.head b.dsp)
    else
      let
        calls = map (item: (mkDspCallExpr name item) + "()") b.dsp;
      in
      "function()\n  " + lib.concatStringsSep "\n  " calls + "\nend";

  mkBindLine =
    name: b:
    let
      parts = [
        (mkKeyExpr name)
        (mkDispatcherExpr name b)
      ]
      ++ lib.optional (b.flags != { }) (luaTable b.flags);
    in
    "hl.bind(${lib.concatStringsSep ", " parts})";

  mkBindLines = binds: lib.mapAttrsToList mkBindLine binds;

  indent = lines: map (l: "  " + l) lines;

  mkSubmapBlock =
    submapName: s:
    lib.concatStringsSep "\n" (
      [ "hl.define_submap(${luaStr submapName}, function()" ]
      ++ indent (mkBindLines s.binds)
      ++ [ "end)" ]
    );
in
{
  options.programs.hyprland.settings = {
    mainMod = mkOption {
      type = types.str;
      default = "SUPER";
      description = "Modifier substituted for the literal \"Mod\" token in bind keys";
    };

    binds = mkOption {
      type = types.attrsOf bindType;
      default = { };
    };

    submaps = mkOption {
      type = types.attrsOf submapType;
      default = { };
      description = "Submaps, each rendered as hl.define_submap(name, function() ... end)";
    };
  };

  config = {
    wayland.windowManager.hyprland.extraConfig = lib.mkAfter (
      lib.concatStringsSep "\n" (
        (mkBindLines cfg.binds) ++ (lib.mapAttrsToList mkSubmapBlock cfg.submaps)
      )
      + "\n"
    );
  };
}
