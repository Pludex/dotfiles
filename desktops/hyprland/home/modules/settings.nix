{ config, lib, ... }:

let
  cfg = config.programs.hyprland.settings;
  monitorsCfg = config.programs.hyprland.monitors;

  inherit (lib) mkOption types;

  numberType = types.oneOf [
    types.int
    types.float
  ];

  # dsp value shapes:
  # - true                          -> no-arg call: hl.dsp.<name>()
  # - string                        -> single quoted arg: hl.dsp.<name>("...")
  # - list of string                -> multiple quoted args: hl.dsp.<name>("a", "b")
  # - { __raw = "..."; }            -> single raw (unquoted) arg: hl.dsp.<name>(<raw>)
  # - other attrset                 -> single table arg: hl.dsp.<name>({ k = v, ... })
  dspTableArgType = types.attrsOf (
    types.oneOf [
      types.bool
      types.str
      numberType
    ]
  );
  dspValueType = types.oneOf [
    types.str
    types.bool
    (types.listOf types.str)
    dspTableArgType
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
        # A single dsp entry, or a list of them for a macro.
        type = types.oneOf [
          dspItemType
          (types.listOf dspItemType)
        ];
        default = [ ];
        description = "One dispatcher attr, or a list of them; more than one is combined into a macro lambda";
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

  mkKeyExpr =
    key:
    let
      tokens = lib.splitString "+" key;
      mapped = map (
        t:
        let
          stripped = lib.replaceStrings [ " " ] [ "" ] t; # drop stray spaces around "+"
        in
        if lib.toLower stripped == "mod" then lib.toUpper cfg.mainMod else lib.toUpper stripped
      ) tokens;
    in
    luaStr (lib.concatStringsSep "+" mapped);

  # dsp option accepts a single attr or a list of attrs; normalize to a list.
  toDspList = v: if lib.isList v then v else [ v ];

  # One dsp item -> "hl.dsp.<name>(<args>)" or the raw expression for __raw (top-level).
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
      # Top-level __raw: the whole dispatcher expression, used as-is.
      if dspName == "__raw" then
        if !(builtins.isString val) then throw "bind \"${name}\": __raw must be a string" else val
      else
        let
          args =
            if val == true then
              ""
            else if val == false then
              throw "bind \"${name}\": dsp.${dspName} = false has no meaning"
            else if builtins.isAttrs val then
              let
                argKeys = lib.attrNames val;
              in
              # Per-arg __raw: single raw arg, used as-is (e.g. a Lua table literal).
              if argKeys == [ "__raw" ] then
                if !(builtins.isString val.__raw) then
                  throw "bind \"${name}\": dsp.${dspName}.__raw must be a string"
                else
                  val.__raw
              else
                luaTable val
            else if builtins.isString val then
              luaStr val
            else
              lib.concatMapStringsSep ", " luaStr val; # list of str
        in
        "hl.dsp.${dspName}(${args})";

  # Single dsp -> used directly as the dispatcher argument.
  # Multiple dsp (macro) -> wrapped in a lambda that invokes each in order.
  mkDispatcherExpr =
    name: b:
    let
      dspList = toDspList b.dsp;
    in
    if dspList == [ ] then
      throw "bind \"${name}\": dsp must have at least one entry"
    else if lib.length dspList == 1 then
      mkDspCallExpr name (lib.head dspList)
    else
      let
        calls = map (item: (mkDspCallExpr name item) + "()") dspList;
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

  # --- monitors ---

  monitorDefaults = {
    disabled = false;
    mode = "preferred";
    scale = "auto";
    transform = 0;
    position = "auto";
    mirror = "";
    bitdepth = 8;
    cm = "srgb";
    sdr_eotf = "default";
    sdrbrightness = 1.0;
    sdrsaturation = 1.0;
    vrr = 0;
    icc = "";
    reserved_area = 0;
    supports_wide_color = 0;
    supports_hdr = 0;
    sdr_min_luminance = 0.2;
    sdr_max_luminance = 80;
    min_luminance = (-1.0);
    max_luminance = (-1);
    max_avg_luminance = (-1);
  };

  reservedAreaType = types.oneOf [
    types.int
    (types.submodule {
      options = {
        top = mkOption {
          type = types.int;
          default = 0;
        };
        right = mkOption {
          type = types.int;
          default = 0;
        };
        bottom = mkOption {
          type = types.int;
          default = 0;
        };
        left = mkOption {
          type = types.int;
          default = 0;
        };
      };
    })
  ];

  monitorType = types.submodule (
    { name, ... }:
    {
      options = {
        output = mkOption {
          type = types.str;
          default = name;
          description = "Output name, or a desc:... description prefix";
        };
        disabled = mkOption {
          type = types.bool;
          default = monitorDefaults.disabled;
          description = "Removes the monitor from the layout";
        };
        mode = mkOption {
          type = types.str;
          default = monitorDefaults.mode;
          description = ''Resolution and refresh rate, e.g. "1920x1080@144"; also "preferred"/"highres"/"highrr"/"maxwidth"'';
        };
        scale = mkOption {
          type = types.either numberType types.str;
          default = monitorDefaults.scale;
          description = ''Scale factor (e.g. 1.5), or "auto" to use the monitor's PPI'';
        };
        transform = mkOption {
          type = types.ints.between 0 7;
          default = monitorDefaults.transform;
          description = "Rotation/flip transform (0-7)";
        };
        position = mkOption {
          type = types.str;
          default = monitorDefaults.position;
          description = ''Position in the virtual layout, e.g. "1920x0", or "auto"'';
        };
        mirror = mkOption {
          type = types.str;
          default = monitorDefaults.mirror;
          description = "Output name to mirror; empty to disable";
        };
        bitdepth = mkOption {
          type = types.enum [
            8
            10
          ];
          default = monitorDefaults.bitdepth;
        };
        cm = mkOption {
          type = types.enum [
            "auto"
            "srgb"
            "wide"
            "edid"
            "hdr"
            "hdredid"
          ];
          default = monitorDefaults.cm;
          description = "Color management preset";
        };
        sdr_eotf = mkOption {
          type = types.enum [
            "default"
            "gamma22"
            "srgb"
          ];
          default = monitorDefaults.sdr_eotf;
          description = "SDR transfer function";
        };
        sdrbrightness = mkOption {
          type = numberType;
          default = monitorDefaults.sdrbrightness;
          description = "SDR brightness in HDR mode";
        };
        sdrsaturation = mkOption {
          type = numberType;
          default = monitorDefaults.sdrsaturation;
          description = "SDR saturation in HDR mode";
        };
        vrr = mkOption {
          type = types.int;
          default = monitorDefaults.vrr;
          description = "VRR mode";
        };
        icc = mkOption {
          type = types.str;
          default = monitorDefaults.icc;
          description = "Absolute path to an ICC profile; empty to disable";
        };
        reserved_area = mkOption {
          type = reservedAreaType;
          default = monitorDefaults.reserved_area;
          description = "Reserved area: int for all sides, or { top, right, bottom, left }";
        };
        supports_wide_color = mkOption {
          type = types.ints.between (-1) 1;
          default = monitorDefaults.supports_wide_color;
          description = "Force wide color gamut (-1 = off, 0 = auto, 1 = on)";
        };
        supports_hdr = mkOption {
          type = types.ints.between (-1) 1;
          default = monitorDefaults.supports_hdr;
          description = "Force HDR support (-1 = off, 0 = auto, 1 = on)";
        };
        sdr_min_luminance = mkOption {
          type = numberType;
          default = monitorDefaults.sdr_min_luminance;
          description = "SDR minimum luminance for SDR->HDR mapping";
        };
        sdr_max_luminance = mkOption {
          type = types.int;
          default = monitorDefaults.sdr_max_luminance;
          description = "SDR maximum luminance";
        };
        min_luminance = mkOption {
          type = numberType;
          default = monitorDefaults.min_luminance;
          description = "Monitor minimum luminance";
        };
        max_luminance = mkOption {
          type = types.int;
          default = monitorDefaults.max_luminance;
          description = "Monitor maximum possible luminance";
        };
        max_avg_luminance = mkOption {
          type = types.int;
          default = monitorDefaults.max_avg_luminance;
          description = "Monitor maximum average luminance";
        };
      };
    }
  );

  monitorLuaVal =
    v:
    if builtins.isBool v then
      (if v then "true" else "false")
    else if builtins.isString v then
      luaStr v
    else if builtins.isAttrs v then
      "{ " + lib.concatStringsSep ", " (lib.mapAttrsToList (k: vv: "${k} = ${monitorLuaVal vv}") v) + " }"
    else
      toString v;

  # Drop fields still at their default; always keep `output`.
  mkMonitorTable =
    m:
    let
      set = lib.filterAttrs (
        k: v: k == "output" || (!(lib.hasAttr k monitorDefaults) || v != monitorDefaults.${k})
      ) m;
    in
    "{ "
    + lib.concatStringsSep ", " (lib.mapAttrsToList (k: v: "${k} = ${monitorLuaVal v}") set)
    + " }";

  mkMonitorLine = _: m: "hl.monitor(${mkMonitorTable m})";
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

  options.programs.hyprland.monitors = mkOption {
    type = types.attrsOf monitorType;
    default = { };
    description = "Monitors, each rendered as hl.monitor({...})";
  };

  config = {
    wayland.windowManager.hyprland.extraConfig = lib.mkAfter (
      lib.concatStringsSep "\n" (
        (mkBindLines cfg.binds)
        ++ (lib.mapAttrsToList mkSubmapBlock cfg.submaps)
        ++ (lib.mapAttrsToList mkMonitorLine monitorsCfg)
      )
      + "\n"
    );
  };
}
