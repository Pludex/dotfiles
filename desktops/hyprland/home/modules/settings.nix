{ config, lib, ... }:

let
  cfg = config.programs.hyprland.settings;
  monitorsCfg = config.programs.hyprland.monitors;
  extraConfigCfg = config.programs.hyprland.extraConfig;

  inherit (lib) mkOption types;

  numberType = types.oneOf [ types.int types.float ];

  # ---------------------------------------------------------------------
  # shared lua-value rendering (bool / number / string / nested attrset / list)
  # ---------------------------------------------------------------------
  toLuaVal =
    v:
    if builtins.isBool v then
      (if v then "true" else "false")
    else if builtins.isString v then
      builtins.toJSON v
    else if builtins.isList v then
      "{ " + lib.concatMapStringsSep ", " toLuaVal v + " }"
    else if builtins.isAttrs v then
      "{ " + lib.concatStringsSep ", " (lib.mapAttrsToList (k: vv: "${k} = ${toLuaVal vv}") v) + " }"
    else
      toString v;

  # single-key { __raw = "..."; } escape hatch, used in several freeform/heterogeneous spots
  renderRawOrVal =
    v:
    if builtins.isAttrs v && (lib.attrNames v) == [ "__raw" ] then
      v.__raw
    else
      toLuaVal v;

  luaStr = s: builtins.toJSON s;

  # Emit only the fields that differ from `defaults`; always keep `keep`.
  mkFilteredTable =
    defaults: keep: m:
    let
      set = lib.filterAttrs (
        k: v: (builtins.elem k keep) || (!(lib.hasAttr k defaults) || v != defaults.${k})
      ) m;
    in
    "{ " + lib.concatStringsSep ", " (lib.mapAttrsToList (k: v: "${k} = ${toLuaVal v}") set) + " }";

  # Emit "k = v" fragments (no braces) for every non-null value in `m`, using `renderer`.
  mkSetFields =
    m: renderer:
    lib.mapAttrsToList (k: v: "${k} = ${renderer v}") (lib.filterAttrs (k: v: v != null) m);

  # ---------------------------------------------------------------------
  # binds / dsp / flags
  # ---------------------------------------------------------------------
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

  # "Mod+Shift+e" / "SUPER + return" -> "SUPER+SHIFT+RETURN", using cfg.mainMod for the Mod token.
  mkKeyExpr =
    key:
    let
      tokens = lib.splitString "+" key;
      mapped = map (
        t:
        let
          stripped = lib.replaceStrings [ " " ] [ "" ] t;
        in
        if lib.toLower stripped == "mod" then lib.toUpper cfg.mainMod else lib.toUpper stripped
      ) tokens;
    in
    luaStr (lib.concatStringsSep "+" mapped);

  toDspList = v: if lib.isList v then v else [ v ];

  # One dsp item -> "hl.dsp.<name>(<args>)" or the raw expression for top-level __raw.
  mkDspCallExpr =
    name: item:
    let
      keys = lib.attrNames item;
    in
    if keys == [ ] then
      throw "${name}: each dsp entry must have exactly one attr"
    else if lib.length keys > 1 then
      throw "${name}: each dsp entry must have only one attr (got: ${toString keys})"
    else
      let
        dspName = lib.head keys;
        val = item.${dspName};
      in
      if dspName == "__raw" then
        if !(builtins.isString val) then
          throw "${name}: __raw must be a string"
        else
          val
      else
        let
          args =
            if val == true then
              ""
            else if val == false then
              throw "${name}: dsp.${dspName} = false has no meaning"
            else if builtins.isAttrs val then
              let
                argKeys = lib.attrNames val;
              in
              # Per-arg __raw: single raw (unquoted) arg, e.g. dsp.focus.__raw = "{ direction = 'l' }"
              if argKeys == [ "__raw" ] then
                if !(builtins.isString val.__raw) then
                  throw "${name}: dsp.${dspName}.__raw must be a string"
                else
                  val.__raw
              else
                toLuaVal val
            else if builtins.isString val then
              luaStr val
            else
              lib.concatMapStringsSep ", " luaStr val; # list of str
        in
        "hl.dsp.${dspName}(${args})";

  mkDispatcherExpr =
    name: b:
    let
      dspList = toDspList b.dsp;
    in
    if dspList == [ ] then
      throw "bind \"${name}\": dsp must have at least one entry"
    else if lib.length dspList == 1 then
      mkDspCallExpr "bind \"${name}\"" (lib.head dspList)
    else
      let
        calls = map (item: (mkDspCallExpr "bind \"${name}\"" item) + "()") dspList;
      in
      "function()\n  " + lib.concatStringsSep "\n  " calls + "\nend";

  mkBindLine =
    name: b:
    let
      parts = [
        (mkKeyExpr name)
        (mkDispatcherExpr name b)
      ]
      ++ lib.optional (b.flags != { }) (mkFilteredTable { } [ ] b.flags);
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

  # ---------------------------------------------------------------------
  # monitors
  # ---------------------------------------------------------------------
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
        top = mkOption { type = types.int; default = 0; };
        right = mkOption { type = types.int; default = 0; };
        bottom = mkOption { type = types.int; default = 0; };
        left = mkOption { type = types.int; default = 0; };
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
        disabled = mkOption { type = types.bool; default = monitorDefaults.disabled; description = "Removes the monitor from the layout"; };
        mode = mkOption { type = types.str; default = monitorDefaults.mode; description = ''Resolution and refresh rate, e.g. "1920x1080@144"; also "preferred"/"highres"/"highrr"/"maxwidth"''; };
        scale = mkOption { type = types.either numberType types.str; default = monitorDefaults.scale; description = ''Scale factor (e.g. 1.5), or "auto" to use the monitor's PPI''; };
        transform = mkOption { type = types.ints.between 0 7; default = monitorDefaults.transform; description = "Rotation/flip transform (0-7)"; };
        position = mkOption { type = types.str; default = monitorDefaults.position; description = ''Position in the virtual layout, e.g. "1920x0", or "auto"''; };
        mirror = mkOption { type = types.str; default = monitorDefaults.mirror; description = "Output name to mirror; empty to disable"; };
        bitdepth = mkOption { type = types.enum [ 8 10 ]; default = monitorDefaults.bitdepth; };
        cm = mkOption { type = types.enum [ "auto" "srgb" "wide" "edid" "hdr" "hdredid" ]; default = monitorDefaults.cm; description = "Color management preset"; };
        sdr_eotf = mkOption { type = types.enum [ "default" "gamma22" "srgb" ]; default = monitorDefaults.sdr_eotf; description = "SDR transfer function"; };
        sdrbrightness = mkOption { type = numberType; default = monitorDefaults.sdrbrightness; description = "SDR brightness in HDR mode"; };
        sdrsaturation = mkOption { type = numberType; default = monitorDefaults.sdrsaturation; description = "SDR saturation in HDR mode"; };
        vrr = mkOption { type = types.int; default = monitorDefaults.vrr; description = "VRR mode"; };
        icc = mkOption { type = types.str; default = monitorDefaults.icc; description = "Absolute path to an ICC profile; empty to disable"; };
        reserved_area = mkOption { type = reservedAreaType; default = monitorDefaults.reserved_area; description = "Reserved area: int for all sides, or { top, right, bottom, left }"; };
        supports_wide_color = mkOption { type = types.ints.between (-1) 1; default = monitorDefaults.supports_wide_color; description = "Force wide color gamut (-1 = off, 0 = auto, 1 = on)"; };
        supports_hdr = mkOption { type = types.ints.between (-1) 1; default = monitorDefaults.supports_hdr; description = "Force HDR support (-1 = off, 0 = auto, 1 = on)"; };
        sdr_min_luminance = mkOption { type = numberType; default = monitorDefaults.sdr_min_luminance; description = "SDR minimum luminance for SDR->HDR mapping"; };
        sdr_max_luminance = mkOption { type = types.int; default = monitorDefaults.sdr_max_luminance; description = "SDR maximum luminance"; };
        min_luminance = mkOption { type = numberType; default = monitorDefaults.min_luminance; description = "Monitor minimum luminance"; };
        max_luminance = mkOption { type = types.int; default = monitorDefaults.max_luminance; description = "Monitor maximum possible luminance"; };
        max_avg_luminance = mkOption { type = types.int; default = monitorDefaults.max_avg_luminance; description = "Monitor maximum average luminance"; };
      };
    }
  );

  mkMonitorTable = m: mkFilteredTable monitorDefaults [ "output" ] m;
  mkMonitorLine = _: m: "hl.monitor(${mkMonitorTable m})";

  # ---------------------------------------------------------------------
  # layouts (dwindle / master / scrolling have known fields per the wiki;
  # monocle currently has no config category, only dispatcher messages)
  # ---------------------------------------------------------------------
  dwindleDefaults = {
    force_split = 0;
    preserve_split = false;
    smart_split = false;
    smart_resizing = true;
    permanent_direction_override = false;
    special_scale_factor = 1.0;
    split_width_multiplier = 1.0;
    use_active_for_splits = true;
    default_split_ratio = 1.0;
    split_bias = 0;
    precise_mouse_move = false;
  };

  dwindleType = types.submodule {
    options = {
      force_split = mkOption { type = types.ints.between 0 2; default = dwindleDefaults.force_split; description = "0 = split follows mouse, 1 = always left/top, 2 = always right/bottom"; };
      preserve_split = mkOption { type = types.bool; default = dwindleDefaults.preserve_split; description = "Keep the split side/top regardless of container changes"; };
      smart_split = mkOption { type = types.bool; default = dwindleDefaults.smart_split; description = "Determine split direction by cursor position (4 triangles); also enables preserve_split"; };
      smart_resizing = mkOption { type = types.bool; default = dwindleDefaults.smart_resizing; description = "Resize direction follows mouse position instead of tiling position"; };
      permanent_direction_override = mkOption { type = types.bool; default = dwindleDefaults.permanent_direction_override; description = "Make the preselect direction persist until changed"; };
      special_scale_factor = mkOption { type = numberType; default = dwindleDefaults.special_scale_factor; description = "Scale factor of windows on the special workspace [0-1]"; };
      split_width_multiplier = mkOption { type = numberType; default = dwindleDefaults.split_width_multiplier; description = "Auto-split width multiplier [0.1-3.0]"; };
      use_active_for_splits = mkOption { type = types.bool; default = dwindleDefaults.use_active_for_splits; description = "Prefer the active window over mouse position for splits"; };
      default_split_ratio = mkOption { type = numberType; default = dwindleDefaults.default_split_ratio; description = "Default split ratio on window open [0.1-1.9], 1 = even 50/50"; };
      split_bias = mkOption { type = types.ints.between 0 1; default = dwindleDefaults.split_bias; description = "0 = directional window gets the split ratio, 1 = current window"; };
      precise_mouse_move = mkOption { type = types.bool; default = dwindleDefaults.precise_mouse_move; description = "bindm movewindow drops the window more precisely based on mouse position"; };
    };
  };

  masterDefaults = {
    allow_small_split = false;
    special_scale_factor = 1.0;
    mfact = 0.55;
    new_status = "slave";
    new_on_top = false;
    new_on_active = "none";
    orientation = "left";
    slave_count_for_center_master = 2;
    center_master_fallback = "left";
    smart_resizing = true;
    drop_at_cursor = true;
    always_keep_position = false;
    focus_master_on_close = false;
  };

  masterType = types.submodule {
    options = {
      allow_small_split = mkOption { type = types.bool; default = masterDefaults.allow_small_split; description = "Enable adding additional master windows in a horizontal split style"; };
      special_scale_factor = mkOption { type = numberType; default = masterDefaults.special_scale_factor; description = "Scale of special workspace windows [0-1]"; };
      mfact = mkOption { type = numberType; default = masterDefaults.mfact; description = "Master window size as a fraction of the screen [0-1]"; };
      new_status = mkOption { type = types.enum [ "master" "slave" "inherit" ]; default = masterDefaults.new_status; description = "Where a new window is placed"; };
      new_on_top = mkOption { type = types.bool; default = masterDefaults.new_on_top; description = "Whether a new window goes on top of the stack"; };
      new_on_active = mkOption { type = types.enum [ "before" "after" "none" ]; default = masterDefaults.new_on_active; description = "Place new window relative to the focused window"; };
      orientation = mkOption { type = types.enum [ "left" "right" "top" "bottom" "center" ]; default = masterDefaults.orientation; description = "Default placement of the master area"; };
      slave_count_for_center_master = mkOption { type = types.ints.between 0 10; default = masterDefaults.slave_count_for_center_master; description = "Min slave windows before centering master with orientation=center (0 = always center)"; };
      center_master_fallback = mkOption { type = types.enum [ "left" "right" "top" "bottom" ]; default = masterDefaults.center_master_fallback; description = "Fallback orientation when centering conditions aren't met"; };
      smart_resizing = mkOption { type = types.bool; default = masterDefaults.smart_resizing; description = "Resize direction follows mouse position instead of tiling position"; };
      drop_at_cursor = mkOption { type = types.bool; default = masterDefaults.drop_at_cursor; description = "Drag-and-drop puts windows at the cursor position"; };
      always_keep_position = mkOption { type = types.bool; default = masterDefaults.always_keep_position; description = "Keep the master window's configured position even with no slave windows"; };
      focus_master_on_close = mkOption { type = types.bool; default = masterDefaults.focus_master_on_close; description = "Closing a window focuses the master window"; };
    };
  };

  scrollingDefaults = {
    fullscreen_on_one_column = true;
    column_width = 0.5;
    focus_fit_method = 1;
    follow_focus = true;
    follow_min_visible = 0.4;
    explicit_column_widths = "0.333, 0.5, 0.667, 1.0";
    wrap_focus = true;
    wrap_swapcol = true;
    direction = "right";
  };

  scrollingType = types.submodule {
    options = {
      fullscreen_on_one_column = mkOption { type = types.bool; default = scrollingDefaults.fullscreen_on_one_column; description = "A single column always spans the entire screen"; };
      column_width = mkOption { type = numberType; default = scrollingDefaults.column_width; description = "Default column width [0.1-1.0]"; };
      focus_fit_method = mkOption { type = types.ints.between 0 1; default = scrollingDefaults.focus_fit_method; description = "0 = center, 1 = fit"; };
      follow_focus = mkOption { type = types.bool; default = scrollingDefaults.follow_focus; description = "Layout moves to bring the focused window into view automatically"; };
      follow_min_visible = mkOption { type = numberType; default = scrollingDefaults.follow_min_visible; description = "Minimum visible fraction required for soft focus-follow [0.0-1.0]"; };
      explicit_column_widths = mkOption { type = types.str; default = scrollingDefaults.explicit_column_widths; description = "Comma-separated preconfigured widths for colresize +conf/-conf"; };
      wrap_focus = mkOption { type = types.bool; default = scrollingDefaults.wrap_focus; description = "hl.dsp.layout(\"focus l/r\") wraps around at the ends"; };
      wrap_swapcol = mkOption { type = types.bool; default = scrollingDefaults.wrap_swapcol; description = "hl.dsp.layout(\"swapcol l/r\") wraps around at the ends"; };
      direction = mkOption { type = types.enum [ "left" "right" "up" "down" ]; default = scrollingDefaults.direction; description = "Direction new windows appear and the layout scrolls"; };
    };
  };

  # monocle currently has no documented config fields (dispatcher-only layout);
  # kept as a free-form table so new fields don't require updating this module.
  monocleValueType = types.oneOf [ types.bool types.str numberType ];

  mkLayoutLine = catName: defaults: keep: v: "hl.config({ ${catName} = ${mkFilteredTable defaults keep v} })";

  layoutLines =
    lib.optional (cfg.layouts.dwindle != null) (mkLayoutLine "dwindle" dwindleDefaults [ ] cfg.layouts.dwindle)
    ++ lib.optional (cfg.layouts.master != null) (mkLayoutLine "master" masterDefaults [ ] cfg.layouts.master)
    ++ lib.optional (cfg.layouts.scrolling != null) (mkLayoutLine "scrolling" scrollingDefaults [ ] cfg.layouts.scrolling)
    ++ lib.optional (cfg.layouts.monocle != null) (mkLayoutLine "monocle" { } [ ] cfg.layouts.monocle);

  # ---------------------------------------------------------------------
  # customLayouts -> hl.layout.register("name", <raw lua table>)
  # ---------------------------------------------------------------------
  customLayoutType = types.submodule {
    options = {
      __raw = mkOption {
        type = types.str;
        description = "Raw Lua table literal (or expression) passed as the layout definition";
      };
    };
  };

  mkCustomLayoutLine = name: v: "hl.layout.register(${luaStr name}, ${v.__raw})";

  # ---------------------------------------------------------------------
  # rules: layer / window / workspace
  # ---------------------------------------------------------------------
  layerMatchType = types.submodule {
    options.namespace = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "RegEx matched against the layer namespace (see `hyprctl layers`)";
    };
  };

  layerRuleType = types.submodule {
    options = {
      name = mkOption { type = types.nullOr types.str; default = null; description = "Optional name; required to later set_enabled()/is_enabled()"; };
      match = mkOption { type = layerMatchType; default = { }; };
      above_lock = mkOption { type = types.nullOr types.int; default = null; description = "Non-zero renders above the lock screen; 2 = interactive on lock screen"; };
      animation = mkOption { type = types.nullOr types.str; default = null; description = "Animation style for this layer"; };
      blur = mkOption { type = types.nullOr types.bool; default = null; };
      blur_popups = mkOption { type = types.nullOr types.bool; default = null; };
      dim_around = mkOption { type = types.nullOr types.bool; default = null; };
      ignore_alpha = mkOption { type = types.nullOr numberType; default = null; description = "Blur ignores pixels with opacity <= this [0.0-1.0]"; };
      no_anim = mkOption { type = types.nullOr types.bool; default = null; };
      no_screen_share = mkOption { type = types.nullOr types.bool; default = null; };
      order = mkOption { type = types.nullOr types.int; default = null; description = "Space-reservation priority relative to other layers; can be negative"; };
      xray = mkOption { type = types.nullOr types.bool; default = null; description = "Blur xray mode for the layer"; };
    };
  };

  mkLayerRuleLine =
    r:
    let
      matchFields = mkSetFields { namespace = r.match.namespace; } toLuaVal;
      effectFields = mkSetFields {
        above_lock = r.above_lock;
        animation = r.animation;
        blur = r.blur;
        blur_popups = r.blur_popups;
        dim_around = r.dim_around;
        ignore_alpha = r.ignore_alpha;
        no_anim = r.no_anim;
        no_screen_share = r.no_screen_share;
        order = r.order;
        xray = r.xray;
      } toLuaVal;
      fields =
        lib.optional (r.name != null) "name = ${luaStr r.name}"
        ++ lib.optional (matchFields != [ ]) "match = { ${lib.concatStringsSep ", " matchFields} }"
        ++ effectFields;
    in
    "hl.layer_rule({ ${lib.concatStringsSep ", " fields} })";

  winMatchType = types.submodule {
    options = {
      class = mkOption { type = types.nullOr types.str; default = null; };
      content = mkOption { type = types.nullOr (types.enum [ "none" "photo" "video" "game" ]); default = null; };
      focus = mkOption { type = types.nullOr types.bool; default = null; };
      fullscreen = mkOption { type = types.nullOr types.bool; default = null; };
      fullscreen_state_client = mkOption { type = types.nullOr (types.ints.between 0 3); default = null; };
      fullscreen_state_internal = mkOption { type = types.nullOr (types.ints.between 0 3); default = null; };
      float = mkOption { type = types.nullOr types.bool; default = null; };
      group = mkOption { type = types.nullOr types.bool; default = null; };
      initial_class = mkOption { type = types.nullOr types.str; default = null; };
      initial_title = mkOption { type = types.nullOr types.str; default = null; };
      modal = mkOption { type = types.nullOr types.bool; default = null; };
      pin = mkOption { type = types.nullOr types.bool; default = null; };
      tag = mkOption { type = types.nullOr types.str; default = null; };
      title = mkOption { type = types.nullOr types.str; default = null; };
      workspace = mkOption { type = types.nullOr types.str; default = null; description = "Workspace selector"; };
      xdg_tag = mkOption { type = types.nullOr types.str; default = null; };
      xwayland = mkOption { type = types.nullOr types.bool; default = null; };
    };
  };

  # Effects are not individually enumerated (there are ~70, static + dynamic + group/tag/border_color
  # specials, and the set changes across Hyprland releases). Any top-level key besides `name`/`match`
  # is treated as an effect and passed straight through as `effect = value` inside hl.window_rule({...}).
  # Use { __raw = "..."; } as a value to insert something Nix's plain types can't express (e.g. a
  # gradient table with an angle, or a computed `move`/`size` expression list).
  winEffectLeafType = types.oneOf [
    types.bool
    types.str
    numberType
  ];
  winEffectValueType = types.oneOf [
    winEffectLeafType
    (types.listOf winEffectLeafType)
    (types.attrsOf winEffectLeafType)
    (types.submodule { options.__raw = mkOption { type = types.str; }; })
  ];

  winRuleType = types.submodule {
    freeformType = types.attrsOf winEffectValueType;
    options = {
      name = mkOption { type = types.nullOr types.str; default = null; };
      match = mkOption { type = winMatchType; default = { }; };
    };
  };

  mkWinRuleLine =
    r:
    let
      matchFields = mkSetFields {
        class = r.match.class;
        content = r.match.content;
        focus = r.match.focus;
        fullscreen = r.match.fullscreen;
        fullscreen_state_client = r.match.fullscreen_state_client;
        fullscreen_state_internal = r.match.fullscreen_state_internal;
        float = r.match.float;
        group = r.match.group;
        initial_class = r.match.initial_class;
        initial_title = r.match.initial_title;
        modal = r.match.modal;
        pin = r.match.pin;
        tag = r.match.tag;
        title = r.match.title;
        workspace = r.match.workspace;
        xdg_tag = r.match.xdg_tag;
        xwayland = r.match.xwayland;
      } toLuaVal;
      reserved = [
        "name"
        "match"
      ];
      effectAttrs = lib.filterAttrs (k: _: !(builtins.elem k reserved)) r;
      effectFields = lib.mapAttrsToList (k: v: "${k} = ${renderRawOrVal v}") effectAttrs;
      fields =
        lib.optional (r.name != null) "name = ${luaStr r.name}"
        ++ lib.optional (matchFields != [ ]) "match = { ${lib.concatStringsSep ", " matchFields} }"
        ++ effectFields;
    in
    "hl.window_rule({ ${lib.concatStringsSep ", " fields} })";

  cssGapsType = types.oneOf [ types.int types.str ];

  workspaceRuleType = types.submodule {
    options = {
      workspace = mkOption { type = types.str; description = "Workspace selector, e.g. \"3\", \"name:coding\", \"special:scratchpad\""; };
      animation = mkOption { type = types.nullOr types.str; default = null; };
      border_size = mkOption { type = types.nullOr types.int; default = null; };
      decorate = mkOption { type = types.nullOr types.bool; default = null; };
      default_name = mkOption { type = types.nullOr types.str; default = null; };
      float_gaps = mkOption { type = types.nullOr cssGapsType; default = null; };
      gaps_in = mkOption { type = types.nullOr cssGapsType; default = null; };
      gaps_out = mkOption { type = types.nullOr cssGapsType; default = null; };
      layout = mkOption { type = types.nullOr (types.enum [ "dwindle" "master" "scrolling" "monocle" ]); default = null; };
      layout_opts = mkOption { type = types.nullOr (types.attrsOf winEffectLeafType); default = null; description = "Layout-specific per-workspace options; keys/values depend on the layout"; };
      monitor = mkOption { type = types.nullOr types.str; default = null; };
      default = mkOption { type = types.nullOr types.bool; default = null; };
      no_border = mkOption { type = types.nullOr types.bool; default = null; };
      no_rounding = mkOption { type = types.nullOr types.bool; default = null; };
      no_shadow = mkOption { type = types.nullOr types.bool; default = null; };
      on_created_empty = mkOption { type = types.nullOr types.str; default = null; };
      persistent = mkOption { type = types.nullOr types.bool; default = null; };
    };
  };

  mkWorkspaceRuleLine =
    r:
    let
      fields =
        [ "workspace = ${toLuaVal r.workspace}" ]
        ++ mkSetFields {
          animation = r.animation;
          border_size = r.border_size;
          decorate = r.decorate;
          default_name = r.default_name;
          float_gaps = r.float_gaps;
          gaps_in = r.gaps_in;
          gaps_out = r.gaps_out;
          layout = r.layout;
          layout_opts = r.layout_opts;
          monitor = r.monitor;
          default = r.default;
          no_border = r.no_border;
          no_rounding = r.no_rounding;
          no_shadow = r.no_shadow;
          on_created_empty = r.on_created_empty;
          persistent = r.persistent;
        } toLuaVal;
    in
    "hl.workspace_rule({ ${lib.concatStringsSep ", " fields} })";

  # ---------------------------------------------------------------------
  # animations: hl.curve(...) + hl.animation({...})
  # ---------------------------------------------------------------------
  curveType = types.submodule {
    options = {
      type = mkOption { type = types.enum [ "bezier" "spring" ]; };
      points = mkOption {
        type = types.nullOr (types.listOf (types.listOf numberType));
        default = null;
        description = "bezier only: [[x0 y0] [x1 y1]] (two control points)";
      };
      mass = mkOption { type = types.nullOr numberType; default = null; description = "spring only"; };
      stiffness = mkOption { type = types.nullOr numberType; default = null; description = "spring only"; };
      dampening = mkOption {
        type = types.nullOr numberType;
        default = null;
        description = "spring only. Some wiki pages spell this field \"damping\" instead -- see AGENTS.md";
      };
    };
  };

  mkCurveLine =
    name: c:
    if c.type == "bezier" then
      (
        if c.points == null then
          throw "curve \"${name}\": type = \"bezier\" requires points"
        else
          "hl.curve(${luaStr name}, { type = \"bezier\", points = ${toLuaVal c.points} })"
      )
    else
      (
        if c.mass == null || c.stiffness == null || c.dampening == null then
          throw "curve \"${name}\": type = \"spring\" requires mass, stiffness and dampening"
        else
          "hl.curve(${luaStr name}, { type = \"spring\", mass = ${toLuaVal c.mass}, stiffness = ${toLuaVal c.stiffness}, dampening = ${toLuaVal c.dampening} })"
      );

  animEntryType = types.submodule {
    options = {
      leaf = mkOption { type = types.str; description = "Animation tree leaf, e.g. \"windows\", \"fade\", \"workspaces\", \"layers\""; };
      enabled = mkOption { type = types.bool; default = true; };
      speed = mkOption { type = types.nullOr numberType; default = null; description = "In deciseconds (1ds = 100ms)"; };
      bezier = mkOption { type = types.nullOr types.str; default = null; description = "name of a bezier curve declared in animations.curves"; };
      spring = mkOption { type = types.nullOr types.str; default = null; description = "name of a spring curve declared in animations.curves"; };
      style = mkOption { type = types.nullOr types.str; default = null; };
    };
  };

  mkAnimLine =
    a:
    if a.bezier != null && a.spring != null then
      throw "animation \"${a.leaf}\": set only one of bezier or spring"
    else if a.enabled && a.bezier == null && a.spring == null then
      throw "animation \"${a.leaf}\": enabled = true requires either bezier or spring"
    else
      let
        fields =
          [
            "leaf = ${luaStr a.leaf}"
            "enabled = ${toLuaVal a.enabled}"
          ]
          ++ mkSetFields {
            speed = a.speed;
            bezier = a.bezier;
            spring = a.spring;
            style = a.style;
          } toLuaVal;
      in
      "hl.animation({ ${lib.concatStringsSep ", " fields} })";

  animationsCfgType = types.nullOr (
    types.submodule {
      options = {
        curves = mkOption { type = types.attrsOf curveType; default = { }; };
        entries = mkOption { type = types.listOf animEntryType; default = [ ]; description = "list of hl.animation({...}) entries"; };
      };
    }
  );

  animationLines =
    if cfg.animations == null then
      [ ]
    else
      (lib.mapAttrsToList mkCurveLine cfg.animations.curves) ++ (map mkAnimLine cfg.animations.entries);

  # ---------------------------------------------------------------------
  # startWith: hl.on("hyprland.start", function() ... end)
  # ---------------------------------------------------------------------
  actionType = types.submodule {
    options = {
      __raw = mkOption { type = types.nullOr types.str; default = null; description = "Raw Lua statement, inserted verbatim"; };
      dsp = mkOption { type = types.nullOr dspItemType; default = null; description = "Rendered as hl.dispatch(hl.dsp.<name>(...))"; };
    };
  };

  mkActionLine =
    i: a:
    let
      keys = lib.filter (k: a.${k} != null) [ "__raw" "dsp" ];
      label = "startWith.actions[${toString i}]";
    in
    if lib.length keys != 1 then
      throw "${label}: set exactly one of __raw or dsp"
    else if a.__raw != null then
      a.__raw
    else
      "hl.dispatch(${mkDspCallExpr label a.dsp})";

  appType = types.submodule {
    # Extra keys besides the ones declared below are treated as env vars to set (via hl.env)
    # before launching this app -- e.g. `GTK_THEME = "Adwaita:dark";`. This is an inferred
    # convenience, not something documented for autostart specifically -- see AGENTS.md.
    freeformType = types.attrsOf types.str;
    options = {
      desktopFile = mkOption { type = types.nullOr types.str; default = null; description = "Mutually exclusive with cmd"; };
      cmd = mkOption { type = types.nullOr types.str; default = null; description = "Mutually exclusive with desktopFile"; };
      workspaces = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Target workspace number; prefixes the launch command with \"[workspace N silent]\". 0/unset = no prefix";
      };
      dsp = mkOption {
        type = types.oneOf [
          dspItemType
          (types.listOf dspItemType)
        ];
        default = [ ];
        description = "Dispatcher(s) applied right after launch, same shape as binds.<key>.dsp -- see AGENTS.md for the assumption behind this";
      };
    };
  };

  mkAppLines =
    i: a:
    let
      label = "startWith.apps[${toString i}]";
      reserved = [
        "desktopFile"
        "cmd"
        "workspaces"
        "dsp"
      ];
      extraEnv = lib.filterAttrs (k: _: !(builtins.elem k reserved)) a;
      envLines = lib.mapAttrsToList (k: v: "hl.env(${luaStr k}, ${luaStr v})") extraEnv;
      hasCmd = a.cmd != null;
      hasDesktop = a.desktopFile != null;
      baseCmd =
        if hasCmd && hasDesktop then
          throw "${label}: set only one of cmd or desktopFile"
        else if hasCmd then
          a.cmd
        else if hasDesktop then
          # Inferred launch method -- gtk-launch is a common freedesktop convention,
          # not a documented hl.* API. See AGENTS.md.
          "gtk-launch " + lib.removeSuffix ".desktop" (baseNameOf a.desktopFile)
        else
          throw "${label}: set one of cmd or desktopFile";
      finalCmd =
        if a.workspaces != null && a.workspaces != 0 then
          "[workspace ${toString a.workspaces} silent] " + baseCmd
        else
          baseCmd;
      execLine = "hl.exec_cmd(${luaStr finalCmd})";
      dspList = toDspList a.dsp;
      dspLines = map (item: "hl.dispatch(${mkDspCallExpr label item})") dspList;
    in
    envLines ++ [ execLine ] ++ dspLines;

  startWithCfgType = types.nullOr (
    types.submodule {
      options = {
        actions = mkOption { type = types.listOf actionType; default = [ ]; description = "Always rendered before apps"; };
        apps = mkOption { type = types.listOf appType; default = [ ]; };
      };
    }
  );

  startWithLines =
    if cfg.startWith == null then
      [ ]
    else
      let
        actionLines = lib.imap0 mkActionLine cfg.startWith.actions;
        appLines = lib.flatten (lib.imap0 mkAppLines cfg.startWith.apps);
        bodyLines = actionLines ++ appLines;
      in
      [
        (lib.concatStringsSep "\n" (
          [ "hl.on(\"hyprland.start\", function()" ] ++ indent bodyLines ++ [ "end)" ]
        ))
      ];

  # ---------------------------------------------------------------------
  # programs.hyprland.extraConfig -> a single hl.config({ ["a.b"] = v, ... }) call
  # ---------------------------------------------------------------------
  extraConfigLeafType = types.oneOf [
    types.bool
    types.str
    numberType
  ];
  extraConfigValueType = types.oneOf [
    extraConfigLeafType
    (types.listOf extraConfigLeafType)
    (types.attrsOf extraConfigLeafType)
    (types.submodule { options.__raw = mkOption { type = types.str; }; })
  ];

  extraConfigLines =
    if extraConfigCfg == { } then
      [ ]
    else
      [
        "hl.config({ ${lib.concatStringsSep ", " (
          lib.mapAttrsToList (k: v: "[${luaStr k}] = ${renderRawOrVal v}") extraConfigCfg
        )} })"
      ];
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

    layouts = {
      dwindle = mkOption {
        type = types.nullOr dwindleType;
        default = null;
        description = "dwindle layout config -> hl.config({ dwindle = {...} })";
      };
      master = mkOption {
        type = types.nullOr masterType;
        default = null;
        description = "master layout config -> hl.config({ master = {...} })";
      };
      scrolling = mkOption {
        type = types.nullOr scrollingType;
        default = null;
        description = "scrolling layout config -> hl.config({ scrolling = {...} })";
      };
      monocle = mkOption {
        type = types.nullOr (types.attrsOf monocleValueType);
        default = null;
        description = "monocle layout config (no documented fields yet) -> hl.config({ monocle = {...} })";
      };
    };

    customLayouts = mkOption {
      type = types.attrsOf customLayoutType;
      default = { };
      description = "Custom layouts, each rendered as hl.layout.register(name, <__raw>)";
    };

    # read-only: 4 built-in layouts + every registered customLayouts name, so a bind
    # (e.g. a "cycle layout" bind) can reference the full set without hand-listing it.
    layoutNames = mkOption {
      type = types.listOf types.str;
      readOnly = true;
      default = [ "dwindle" "master" "scrolling" "monocle" ] ++ (lib.attrNames cfg.customLayouts);
      description = "All layout names known to this config: the 4 built-ins plus every customLayouts key";
    };

    rules = {
      layer = mkOption {
        type = types.listOf layerRuleType;
        default = [ ];
        description = "hl.layer_rule({...}) entries";
      };
      win = mkOption {
        type = types.listOf winRuleType;
        default = [ ];
        description = "hl.window_rule({...}) entries. `match` is typed; any other top-level key is an effect passed through as-is";
      };
      workspaces = mkOption {
        type = types.listOf workspaceRuleType;
        default = [ ];
        description = "hl.workspace_rule({...}) entries";
      };
    };

    animations = mkOption {
      type = animationsCfgType;
      default = null;
      description = "curves (hl.curve) + entries (hl.animation); null emits nothing";
    };

    startWith = mkOption {
      type = startWithCfgType;
      default = null;
      description = "hl.on(\"hyprland.start\", function() actions...; apps... end); actions always render before apps";
    };
  };

  options.programs.hyprland.monitors = mkOption {
    type = types.attrsOf monitorType;
    default = { };
    description = "Monitors, each rendered as hl.monitor({...})";
  };

  options.programs.hyprland.extraConfig = mkOption {
    type = types.attrsOf extraConfigValueType;
    default = { };
    description = ''
      Flat, dotted-path Hyprland variables, rendered as a single
      hl.config({ ["a.b"] = value, ... }) call using the bracket-key syntax
      from the wiki. Use { __raw = "..."; } for values Nix's plain types
      can't express (nested tables, gradients, etc). Example:
        "general.allow_tearing" = false;
        "decoration.blur.enabled" = true;
    '';
  };

  config = {
    wayland.windowManager.hyprland.extraConfig = lib.mkAfter (
      lib.concatStringsSep "\n" (
        (lib.mapAttrsToList mkMonitorLine monitorsCfg)
        ++ extraConfigLines
        ++ layoutLines
        ++ animationLines
        ++ (map mkLayerRuleLine cfg.rules.layer)
        ++ (map mkWinRuleLine cfg.rules.win)
        ++ (map mkWorkspaceRuleLine cfg.rules.workspaces)
        ++ (lib.mapAttrsToList mkCustomLayoutLine cfg.customLayouts)
        ++ (mkBindLines cfg.binds)
        ++ (lib.mapAttrsToList mkSubmapBlock cfg.submaps)
        ++ startWithLines
      )
      + "\n"
    );
  };
}
