# AGENTS.md — `settings.nix` (Hyprland Lua-config Nix wrapper)

Read this file **before** modifying, extending, or debugging `settings.nix`.
It exists so that any AI (or human) picking this file up later understands
the design intent instead of guessing from the code alone.

---

## 0. What this file targets

`settings.nix` does **not** generate the classic `hyprland.conf` syntax
(`bind = SUPER, Q, exec, kitty`). It targets **hyprland-lua**, the Lua-based
configuration system used by Hyprland since v0.55 (`hl.bind`, `hl.dsp.*`,
`hl.config`, `hl.monitor`, `hl.define_submap`, `hl.layout.register`,
`hl.layer_rule`, `hl.window_rule`, `hl.workspace_rule`, `hl.curve`,
`hl.animation`, `hl.on`, `hl.exec_cmd`, `hl.dispatch`, `hl.env`, etc.).

If you are an AI reading this and you're only familiar with the old
`hyprlang`/`.conf` syntax, **stop and read §14 (Sources) first** —
assumptions from the old syntax will make you write wrong code here.

---

## 1. Core mechanism: this is a text-templating module, not a settings-tree module

home-manager's usual Hyprland module lets
`wayland.windowManager.hyprland.settings` serialize a Nix attrset into
config syntax automatically. **`settings.nix` does not use that path.**

```
Nix option (typed attrset)
   → a `mk*Line` / `mk*Table` helper function
   → a plain Lua source string
   → all strings joined with "\n"
   → assigned to wayland.windowManager.hyprland.extraConfig (via lib.mkAfter)
```

Any new feature added to this file must follow the same pattern: define a
typed Nix option, write a pure function turning a value of that option into
a Lua source string, and append that string to the list inside
`config.wayland.windowManager.hyprland.extraConfig`.

### Emission order

Inside `config.wayland.windowManager.hyprland.extraConfig = lib.mkAfter (...)`:

1. `programs.hyprland.monitors.*` → `hl.monitor({...})`
2. `programs.hyprland.extraConfig` → one batched `hl.config({ ["a.b"] = v, ... })` call
3. `programs.hyprland.settings.layouts.*` → `hl.config({ dwindle/master/scrolling/monocle = {...} })`
4. `programs.hyprland.settings.animations` → `hl.curve(...)` lines, then `hl.animation({...})` lines
5. `programs.hyprland.settings.rules.layer` → `hl.layer_rule({...})`
6. `programs.hyprland.settings.rules.win` → `hl.window_rule({...})`
7. `programs.hyprland.settings.rules.workspaces` → `hl.workspace_rule({...})`
8. `programs.hyprland.settings.customLayouts.*` → `hl.layout.register(name, ...)`
9. `programs.hyprland.settings.binds.*` → `hl.bind(...)`
10. `programs.hyprland.settings.submaps.*` → `hl.define_submap(name, function() ... end)`
11. `programs.hyprland.settings.startWith` → `hl.on("hyprland.start", function() ... end)` (kept last on purpose)

If you need a different order, edit the list literal in that `config`
block — the `let`-bound helper definitions are independent of ordering.

---

## 2. Options this file defines

```
programs.hyprland.settings.mainMod           : str, default "SUPER"
programs.hyprland.settings.binds             : attrsOf bindType
programs.hyprland.settings.submaps           : attrsOf submapType
programs.hyprland.settings.layouts.dwindle    : nullOr dwindleType,   default null
programs.hyprland.settings.layouts.master     : nullOr masterType,    default null
programs.hyprland.settings.layouts.scrolling  : nullOr scrollingType, default null
programs.hyprland.settings.layouts.monocle    : nullOr (attrsOf [bool str number]), default null
programs.hyprland.settings.customLayouts     : attrsOf { __raw :: str }
programs.hyprland.settings.rules.layer       : listOf layerRuleType, default []
programs.hyprland.settings.rules.win         : listOf winRuleType,   default []
programs.hyprland.settings.rules.workspaces  : listOf workspaceRuleType, default []
programs.hyprland.settings.animations        : nullOr { curves :: attrsOf curveType; entries :: listOf animEntryType; }, default null
programs.hyprland.settings.startWith         : nullOr { actions :: listOf actionType; apps :: listOf appType; }, default null
programs.hyprland.monitors                   : attrsOf monitorType
programs.hyprland.extraConfig                : attrsOf extraConfigValueType, default {}
```

`layouts.*`, `animations`, and `startWith` all default to `null` (not an
empty attrset) on purpose — if the user never touches them, no
corresponding Lua block is emitted at all. Don't change these to `{}`
defaults; that would silently start emitting no-op calls.

---

## 3. `binds` — rules that MUST be understood correctly before editing

### 3.1 Key string transformation (`mkKeyExpr`)

Split on `+`, strip whitespace per token, uppercase every token, and
substitute any token that case-insensitively equals `"mod"` with
`cfg.mainMod` (also uppercased). This is a **literal, static Nix-side
substitution**, not a Lua `mod .. " + Q"` concatenation — that alternative
was explicitly considered and rejected.

### 3.2 `dsp` — the dispatcher field

`dsp` accepts a single attrset or a list of attrsets. Each entry must have
**exactly one key** (enforced with `throw`). The key maps to
`hl.dsp.<key>(...)`.

**Frequent mistake:** `dsp.window.close = true;` parses as nested attrsets
in Nix, NOT a flat key. Always use a quoted dotted key:
`dsp."window.close" = true;`.

Value handling (`mkDspCallExpr`):

| value | rendered as |
|---|---|
| `true` | `hl.dsp.name()` |
| `false` | `throw` |
| string | `hl.dsp.name("x")` |
| list of strings | `hl.dsp.name("a","b")` |
| attrset (not `{__raw=...}`) | `hl.dsp.name({ k = v })` |
| `{ __raw = "..."; }` | raw, unquoted arg |

Two distinct `__raw` mechanisms — don't confuse them:
- **top-level `dsp.__raw`** replaces the entire dispatcher call.
- **per-arg `dsp.<name>.__raw`** replaces only that dispatcher's argument.

### 3.3 Macro binds (multiple `dsp` entries)

Multiple entries become `function() hl.dsp.a(...)(); hl.dsp.b(...)() end`
— an **unverified assumption** that `hl.dsp.x(...)` returns a callable
rather than executing immediately (see §13).

### 3.4 `flags`

Plain Lua table via `mkFilteredTable { } [ ] b.flags`. Matches
`hl.bind(keys, dispatcher, { flag1 = true, flag2 = true })`.

### 3.5 `submaps`

`submaps.<name>.binds` uses the same `bindType`/`mkBindLine` as top-level
`binds`, wrapped in `hl.define_submap("<name>", function() ... end)`. Not
implemented: `hl.define_submap`'s optional auto-close-to-another-submap
argument, `catchall` binds, nested submaps.

---

## 4. `monitors` (`programs.hyprland.monitors`)

Keyed by output name; `output` field defaults to the attribute name.
All fields have Nix-side defaults matching `hl.monitor({...})` docs; only
fields differing from default are emitted (`mkFilteredTable`, keeping
`"output"` unconditionally).

**Gotcha already hit once:** numeric fields that can be int or float
(`scale`, `sdrbrightness`, `sdrsaturation`, `sdr_min_luminance`,
`min_luminance`) use `numberType = oneOf [int float]`, NOT plain
`types.float` — nixpkgs' `types.float` does not coerce Nix int literals
(e.g. `-1`), and using it produces `is not of type 'floating point
number'`. Don't reintroduce this bug.

`reserved_area` accepts either plain `int` or `{ top; right; bottom;
left; }`.

---

## 5. `layouts` (`programs.hyprland.settings.layouts`)

Four fixed sub-options (not a generic `attrsOf`) because each layout
category has a distinct, documented field set.

- `dwindle` — 11 fields; the wiki page has a **literal
  `hl.config({ dwindle = {...} })` example with every default spelled
  out** — trust that block over prose descriptions elsewhere on the page.
- `master` — 13 fields. Older/versioned wiki snapshots list different
  fields (`new_is_master`, `no_gaps_when_only`, `inherit_fullscreen`,
  `always_center_master`, `center_master_slaves_on_right`) — these are
  **legacy and superseded**. Always match the current, non-versioned
  `wiki.hypr.land` page, not a `/0.NN.0/` snapshot.
- `scrolling` — 9 fields.
- `monocle` — **deliberately free-form** (`attrsOf [bool str number]`):
  as of the last check, the Monocle Layout page has no config table at
  all, only the `cyclenext`/`cycleprev` dispatcher messages. Replace with
  a typed submodule if Hyprland adds real config fields later.

Each category is only emitted when non-null, and only fields differing
from documented defaults are included.

### 5.1 `layoutNames` (read-only, derived)

`programs.hyprland.settings.layoutNames` is a `readOnly` option, not
something the user sets — its `default` is computed as
`[ "dwindle" "master" "scrolling" "monocle" ] ++ (lib.attrNames
cfg.customLayouts)`. It exists so a bind defined *outside* this module
(e.g. a "cycle through every layout" keybind) can reference the full,
always-up-to-date set of layout names via
`config.programs.hyprland.settings.layoutNames` instead of hand-listing
them and letting the list drift out of sync with `customLayouts`. The 4
built-ins are always included unconditionally — they exist in Hyprland
regardless of whether `layouts.dwindle`/`layouts.master`/etc are
configured (those only override a layout's *config*, not its existence).
This is the first `readOnly`-style derived option in the file; if more
show up, consider grouping them under their own comment block rather than
scattering them among the Lua-emitting options.

---

## 6. `customLayouts`

```nix
customLayouts."<name>".__raw = ''
  { ... }
'';
```
→ `hl.layout.register("<name>", <verbatim __raw content>)`.

**Unverified**: the exact `hl.layout.register(name, tableOrExpr)`
signature was inferred from the user's own example; no dedicated
"custom layout" wiki page was found. Verify before trusting deeply.

---

## 7. `rules.layer` / `rules.win` / `rules.workspaces`

Source: `content/configuring/core/rules/{layer,window,workspace}-rules.md`
in the hyprland-wiki repo (raw GitHub URLs — see §14).

### 7.1 `rules.layer` → `hl.layer_rule({...})`

Fully typed: `name` (optional), `match.namespace` (RegEx string), and all
10 documented effects (`above_lock`, `animation`, `blur`, `blur_popups`,
`dim_around`, `ignore_alpha`, `no_anim`, `no_screen_share`, `order`,
`xray`) as `nullOr` fields, default `null`. Only non-null fields are
emitted (`mkSetFields`). Small, stable list — safe to keep fully typed.

### 7.2 `rules.win` → `hl.window_rule({...})`

**Deliberate design deviation from "enumerate every docs field":** the
window-rules page lists **~70 effects** (static + dynamic + group/tag/
border_color specials) and the set changes across Hyprland releases.
Enumerating all of them as typed Nix options would be a large maintenance
burden for little benefit (most effects are simple scalars anyway).

Instead:
- `match` is **fully typed** (19 documented props: `class`, `content`,
  `focus`, `fullscreen`, `fullscreen_state_client`,
  `fullscreen_state_internal`, `float`, `group`, `initial_class`,
  `initial_title`, `modal`, `pin`, `tag`, `title`, `workspace`,
  `xdg_tag`, `xwayland`) — this is the part users query/get typo-checked
  against most often.
- Effects are **free-form**, via NixOS's `freeformType` mechanism on the
  `winRuleType` submodule: any top-level key besides `name`/`match` is
  treated as an effect and passed straight into
  `hl.window_rule({ ..., <key> = <value> })`.
- `winEffectValueType` supports bool/string/number, a flat list (for
  `move`/`size`/`max_size`/`min_size`-style vec2/expression lists), a
  flat attrset of leaves (for e.g. `border_color = { colors = [...]; angle
  = 45; }`), and `{ __raw = "..."; }` for anything else (an expression,
  a gradient string with named colors, etc).
- Rendering effect values goes through `renderRawOrVal`, which checks for
  the single-key `{ __raw = ...; }` shape before falling back to the
  general `toLuaVal` renderer.

If a future request wants full static typing for the effect list, that's
a legitimate ask — it would mean replacing `freeformType` with ~70
explicit `nullOr` options and rewriting `mkWinRuleLine`'s effect
collection accordingly. Flag this tradeoff to the user rather than
silently expanding it.

### 7.3 `rules.workspaces` → `hl.workspace_rule({...})`

Fully typed: `workspace` (required selector string) + 15 optional rule
fields (`animation`, `border_size`, `decorate`, `default_name`,
`float_gaps`, `gaps_in`, `gaps_out`, `layout`, `layout_opts`, `monitor`,
`default`, `no_border`, `no_rounding`, `no_shadow`, `on_created_empty`,
`persistent`). `float_gaps`/`gaps_in`/`gaps_out` use `cssGapsType = oneOf
[int str]` since "css_gaps" can be a bare number or a `"top right bottom
left"`-style string.

---

## 8. `animations` (`programs.hyprland.settings.animations`)

**This section was explicitly left to this file's own design** — the user
said they had no design direction and to read the docs and decide. Source:
`content/configuring/core/animations.md` plus `wiki.hypr.land/.../Animations/`
(current, non-versioned page).

Chosen shape:

```nix
animations = {
  curves = {
    "<curveName>" = { type = "bezier"; points = [ [x0 y0] [x1 y1] ]; };
    # or:
    "<curveName>" = { type = "spring"; mass = ...; stiffness = ...; dampening = ...; };
  };
  entries = [
    { leaf = "windows"; enabled = true; speed = 10; bezier = "curveName"; style = "slide"; }
  ];
};
```

- `curves.*` → `hl.curve(name, { type = "bezier", points = {...} })` or
  `hl.curve(name, { type = "spring", mass = ..., stiffness = ...,
  dampening = ... })`. `mkCurveLine` throws if the required fields for
  the declared `type` are missing.
- `entries[]` → `hl.animation({ leaf = ..., enabled = ..., ... })`.
  `mkAnimLine` throws if both `bezier` and `spring` are set, or if
  `enabled = true` with neither set (docs: "if it's false, you can omit
  further args" implies enabled=true needs a curve).
- Curves are emitted before animation entries (definitions before use).

**Naming inconsistency in the docs, noted but not resolved:** most pages
(and a real working example config found during research) spell the
spring damping field `dampening`; at least one current wiki page variant
spells it `damping`. This file uses `dampening` because that's what
appears in an actual user's working `hyprland.lua`. If Hyprland rejects
`dampening` at runtime, rename the field to `damping` in `curveType` and
`mkCurveLine`.

---

## 9. `startWith` (`programs.hyprland.settings.startWith`)

Source: `content/configuring/core/autostart.md` — this only documents the
plain `hl.on("hyprland.start", function() hl.exec_cmd(...) end)` pattern.
Everything beyond that (`actions`, per-app `dsp`, `workspaces`,
`desktopFile`, arbitrary env-var fields) is **this file's own design**,
built from the user's sketch, not verified against a dedicated wiki page
(none exists for structured per-app autostart). Treat every point below
as a hypothesis to confirm against real behavior, not settled fact.

Shape:

```nix
startWith = {
  actions = [
    { __raw = "..."; }           # raw Lua statement, inserted verbatim
    { dsp.exec_cmd = "hello"; }  # -> hl.dispatch(hl.dsp.exec_cmd("hello"))
  ];
  apps = [
    {
      cmd = "vivaldi";            # XOR desktopFile
      workspaces = 2;             # prefixes cmd with "[workspace 2 silent] "
      dsp = [ ];                  # dispatcher(s) applied via hl.dispatch right after hl.exec_cmd
      SOME_ENV_VAR = "value";     # freeform extra keys -> hl.env("SOME_ENV_VAR", "value") before exec
    }
  ];
};
```

Renders as:

```lua
hl.on("hyprland.start", function()
  <action lines, in order>
  <app lines, in order>
end)
```

**Actions always render before apps** — this was explicit in the user's
own spec ("actions luôn chạy trước apps"), not inferred.

Per-item design notes (all in `mkAppLines`):

1. **`cmd` vs `desktopFile`**: mutually exclusive, enforced by `throw`.
   `desktopFile` launches via `gtk-launch <basename-without-.desktop>` —
   a common freedesktop convention, but **not** a documented `hl.*`
   function. If the real hyprland-lua ecosystem has a native way to
   launch `.desktop` files, switch to that instead.
2. **`workspaces`**: when non-null and non-zero, prefixes the launch
   command with `"[workspace N silent] "` — this is the old
   `exec-once = [workspace N silent] app` dispatcher-rules prefix syntax
   referenced in the workspace-rules wiki page's `on_created_empty`
   examples; assumed to still work with `hl.exec_cmd`. Unverified for
   this exact call.
3. **`dsp`**: rendered as `hl.dispatch(hl.dsp.<name>(...))` calls placed
   immediately after the `hl.exec_cmd(...)` line. The assumption is that
   this ends up applying to the window that was just spawned — but
   nothing in `startWith` actually scopes the dispatch to *this specific*
   app; it will simply run in sequence during startup. If this doesn't
   behave as expected (e.g. dispatcher fires before the app's window
   exists), rework into a proper `hl.on("window.*", ...)` listener keyed
   by the app's expected class instead.
4. **Freeform extra fields** (anything besides `desktopFile`/`cmd`/
   `workspaces`/`dsp`) are treated as env vars and rendered as
   `hl.env("<exact field name>", "<value>")` calls before the exec line.
   Inferred from the user's own example (`fictx5 = "bamboo";`, described
   as "default is not setting anything; if you can't do it, dropping this
   field is fine too") — treat as optional best-effort sugar, not a hard
   requirement. Field name casing is passed through exactly as written by
   the user.

---

## 10. `programs.hyprland.extraConfig`

Source: `content/configuring/core/config-options.md` — the huge page
listing every `hl.config` category (general, decoration [+ 10 blur
variant sub-categories], animations, input [+ touchpad/touchdevice/
virtualkeyboard/tablet/tablettool], gestures, group [+ col/groupbar],
misc, layout, binds, xwayland, opengl, render, cursor, ecosystem, quirks,
input-capture, debug, experimental).

**Deliberately not enumerated as typed Nix options** — the user
explicitly asked for this (`đừng liệt kê tất cả options ở đây`). Instead:

```nix
programs.hyprland.extraConfig = {
  "general.allow_tearing" = false;
  "decoration.blur.enabled" = true;
  abc.__raw = "{'xyz',...}";
};
```

renders as **one batched call** using the wiki's own documented shortcut
syntax:

```lua
hl.config({ ["general.allow_tearing"] = false, ["decoration.blur.enabled"] = true, ["abc"] = {'xyz',...} })
```

**Design deviation from the user's literal example, done deliberately:**
the user's sketch wrote `allow_tearing = false;` with no category prefix.
This file instead requires the **attribute name to be the full dotted
path** (`"general.allow_tearing"`), because that's what
`hl.config({ ["category.option"] = value })` actually needs — many option
names (`enabled`, `speed`, `size`, ...) repeat across categories, so a
bare name would be ambiguous. If a future request wants automatic
category inference for bare names, that needs a lookup table built from
the config-options page's full category list (~200+ fields) — flag the
size of that undertaking before attempting it.

`extraConfigValueType` supports bool/string/number, a flat list, a flat
attrset of leaves, and `{ __raw = "..."; }` for anything deeper (nested
tables, gradients with an `angle`, etc) — same pattern as the win-rule
effects in §7.2.

---

## 11. Shared helpers — reuse them, don't duplicate

- **`toLuaVal`** — bool/string/number/list/nested-attrset → Lua literal.
  Numbers use `toString`, strings use `builtins.toJSON`, lists render as
  positional Lua arrays (`{ a, b, c }`), attrsets render as named tables
  (`{ k = v, ... }`), recursively.
- **`renderRawOrVal`** — wraps `toLuaVal` but special-cases the single-key
  shape `{ __raw = "..."; }`, inserting that string verbatim instead.
  Used wherever a field needs an escape hatch for values Nix's plain
  types can't express (window-rule effects, `extraConfig` values). This
  is a *different* `__raw` convention from the per-arg dsp `__raw`
  (§3.2) and the top-level dsp/action `__raw` (§3.2, §9) — all three
  exist because they sit at different points in the render pipeline, but
  they all follow the same "single key named `__raw`, value inserted
  verbatim" idea. Keep that idea consistent if you add a fourth spot.
- **`mkFilteredTable defaults keep m`** — Lua table string with only the
  keys differing from `defaults`, plus anything in `keep`. Used by
  monitors and `layouts.*`.
- **`mkSetFields m renderer`** — list of `"k = v"` fragments (no braces)
  for every non-null value in `m`. Used by layer/window/workspace rules
  and animation entries, wherever a struct has many optional fields that
  need to be spliced into a larger table alongside other fields (like
  `name`/`match`) rather than nested under their own key.
- **`luaStr`** — thin `builtins.toJSON` wrapper for a bare Lua string
  literal (bind keys, submap/curve/custom-layout names).

When adding a new feature, prefer extending these helpers over writing
parallel ad-hoc string-building logic.

---

## 12. `freeformType` — how the free-form parts are actually implemented

Several types in this file (`winRuleType`, `appType`) use NixOS's
**`freeformType`** submodule mechanism: declare a few strongly-typed
`options`, and set `freeformType = types.attrsOf SomeType;` so that *any
other* top-level attribute the user provides is accepted, typechecked
against `SomeType`, and merged into the final value alongside the
declared options. This is what lets `rules.win` entries mix a typed
`match` with arbitrary effect keys, and what lets `startWith.apps` entries
mix typed `cmd`/`desktopFile`/`workspaces`/`dsp` with arbitrary env-var
keys.

When rendering such a value, the pattern is: build a `reserved` list of
the declared option names, `filterAttrs` them out, and treat everything
left over as the free-form part (see `mkWinRuleLine`'s `effectAttrs` and
`mkAppLines`' `extraEnv`).

---

## 13. Known unverified assumptions (check before trusting blindly)

These were adopted based on the user's stated preference or best-effort
reasoning, not confirmed against a definitive upstream spec. Flagged here
so a future agent doesn't treat them as ground truth. Update this list
whenever you resolve one or add a new one.

1. **Macro bind lambda semantics** (§3.3) — whether `hl.dsp.x(...)` needs
   a trailing `()` when combined in a lambda.
2. **`hl.layout.register` signature** (§6) — exact call shape for custom
   layouts.
3. **`layouts.monocle` having no config fields at all** (§5) — confirmed
   as of the last check; Hyprland's Lua config surface is still evolving.
4. **Spring curve field name: `dampening` vs `damping`** (§8) — the docs
   are internally inconsistent; this file uses `dampening`.
5. **`startWith.apps[].desktopFile` launching via `gtk-launch`** (§9.1) —
   not a documented `hl.*` API, a generic freedesktop convention.
6. **`startWith.apps[].workspaces` prefixing with `"[workspace N
   silent] "`** (§9.2) — old dispatcher-rules prefix syntax, assumed
   (not confirmed) to still work with `hl.exec_cmd` under hyprland-lua.
7. **`startWith.apps[].dsp` actually targeting the just-spawned window**
   (§9.3) — likely the weakest assumption in the whole file; may need a
   rework using an `hl.on("window.*", ...)` listener instead.
8. **Freeform env-var fields in `startWith.apps`** (§9.4) — inferred
   convenience from the user's own sketch, explicitly described by the
   user as optional/best-effort.
9. **`extraConfig` requiring full dotted-path keys** (§10) — a
   deliberate, documented deviation from the user's shorthand example.

---

## 14. Sources consulted while building this file

- Binds & flags: `wiki.hypr.land/Configuring/Binds/Flags/` (or the
  equivalent `Configuring/Binds/` path) — `hl.bind(keys, dispatcher,
  { flags })` syntax and the full flags table.
- Submaps:
  `https://raw.githubusercontent.com/hyprwm/hyprland-wiki/refs/heads/main/content/configuring/core/submaps.md`
- Monitors: `wiki.hypr.land/Configuring/Basics/Monitors/`
- Dwindle/Master/Scrolling/Monocle layouts:
  `wiki.hypr.land/Configuring/Layouts/{Dwindle,Master,Scrolling,Monocle}-Layout/`
  (current, non-versioned pages — versioned `/0.NN.0/` snapshots show
  older/renamed fields, see §5).
- Layer rules:
  `https://raw.githubusercontent.com/hyprwm/hyprland-wiki/refs/heads/main/content/configuring/core/rules/layer-rules.md`
- Window rules:
  `https://raw.githubusercontent.com/hyprwm/hyprland-wiki/refs/heads/main/content/configuring/core/rules/window-rules.md`
- Workspace rules:
  `https://raw.githubusercontent.com/hyprwm/hyprland-wiki/refs/heads/main/content/configuring/core/rules/workspace-rules.md`
- Config options (the `programs.hyprland.extraConfig` source of truth):
  `https://raw.githubusercontent.com/hyprwm/hyprland-wiki/refs/heads/main/content/configuring/core/config-options.md`
  — includes the `hl.config({ category = {...} })` and
  `hl.config({ ["category.option"] = value })` syntax this file's
  `extraConfig` option is built around.
- Animations: `wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/`
  and `wiki.hypr.land/configuring/core/animations/` (current pages;
  inconsistent on the spring `dampening`/`damping` field name, see §8/§13).
- Autostart: `wiki.hypr.land/Configuring/Basics/Autostart/` —
  `hl.on("hyprland.start", function() hl.exec_cmd(...) end)`. Everything
  in `startWith` beyond this bare pattern is this file's own design (§9).
- Submodule mechanics used throughout (`freeformType`, `types.oneOf`,
  `types.either`, `mkOption`/`types` generally): standard nixpkgs
  `lib/types.nix` / NixOS module system behavior, not Hyprland-specific
  — no external doc link, just general Nix module-system knowledge.

When re-verifying any of the above, always prefer the **current,
non-versioned** `wiki.hypr.land/...` URL over a `/0.NN.0/...` snapshot.

---

## 15. Code style rules

- **Formatting**: `nixfmt`-compatible style — 2-space indent, trailing
  semicolons on every binding, one attribute per line inside multi-field
  `mkOption { ... }` calls once a submodule has more than ~4 short
  fields, otherwise short single-line `mkOption { type = ...; default =
  ...; }` is fine (see `monitorType`/rule-match fields for the compact
  style, `bindType`/`appType` for the expanded style). Match whichever
  style already dominates the section you're editing rather than mixing
  both within one submodule's `options`.
- **Value rendering**: prefer string interpolation (`"...${expr}..."`)
  over `+` string concatenation wherever possible — it reads closer to
  the final Lua output and avoids the Nix list-literal gotcha below.
  Reserve `+` for genuinely building a string piece-by-piece across
  several `let`-bound intermediate values outside of a list literal
  (e.g. `mkDispatcherExpr`'s macro-lambda assembly).
- **⚠️ Nix list-literal gotcha (hit once, do not reintroduce):** inside a
  list literal `[ ... ]`, each element must be a single application-level
  expression — a bare binary operator chain like
  `[ "a" + f x + "b" ]` is a **syntax error** (Nix parses `"a"` as a
  complete element, then chokes on the leading `+`). Either wrap the
  whole chain in parens — `[ ("a" + f x + "b") ]` — or, preferably,
  rewrite it as a single interpolated string —
  `[ "a${toString (f x)}b" ]` / `"...${expr}..."`. This bit
  `extraConfigLines` in an earlier revision; the fix is already applied,
  but watch for the same pattern (`[ "literal" + something ]`) anywhere
  new code builds a list of Lua lines.
- **Builtins**: use the un-prefixed global form when Nix exposes one
  (`baseNameOf`, `dirOf`, `toString`, `map`, `removeAttrs`, `import`, ...)
  — `builtins.<name>` is only needed for functions that are *not*
  aliased into the global scope (`builtins.toJSON`, `builtins.attrNames`,
  `builtins.elem`, `builtins.isAttrs`, `builtins.isList`,
  `builtins.isString`, `builtins.isBool`, `builtins.head` has a `lib`
  equivalent `lib.head` which this file prefers — generally prefer `lib.*`
  helpers over raw `builtins.*` when both exist, since `lib` names tend
  to be more descriptive and this file already leans on `lib` throughout
  (`lib.concatStringsSep`, `lib.mapAttrsToList`, `lib.filterAttrs`,
  `lib.optional`, `lib.imap0`, `lib.flatten`, etc). Exception: comparisons
  like `builtins.isAttrs`/`builtins.isList`/`builtins.isString`/
  `builtins.isBool` are used directly throughout this file (no `lib`
  equivalent is shorter) — stay consistent with that existing choice
  rather than introducing `lib.isAttrs`-style calls for some and
  `builtins.isAttrs` for others.
- **Validation philosophy**: prefer `throw` with a descriptive, prefixed
  message (`throw "${label}: <what's wrong>"`) over silently accepting
  malformed input or producing broken Lua. Every `mk*Line`/`mk*Expr`
  helper that has a "must have exactly one of X or Y" or "must have all
  of X, Y, Z when condition C" invariant should enforce it with `throw`,
  not a comment. Build a `label` string identifying *which* entry failed
  (e.g. `"startWith.apps[${toString i}]"`, `"bind \"${name}\""`) so the
  error is traceable to the specific user-written entry, not just the
  function name.
- **Defaults**: any option representing a Hyprland field that has a
  documented default should carry that exact default in Nix (see
  `monitorDefaults`, `dwindleDefaults`, `masterDefaults`,
  `scrollingDefaults`) and use `mkFilteredTable`/`mkSetFields` so the
  generated Lua only mentions what the user actually changed — never
  hardcode a default into the render function itself; always source it
  from the corresponding `*Defaults` attrset so it can be found/updated
  in one place.
- **Naming**: `mk<Thing>Line` returns a single Lua source line (string).
  `mk<Thing>Lines` (plural) returns a *list* of lines (used when one Nix
  entry expands to several Lua statements, e.g. `mkAppLines`,
  `mkBindLines`). `mk<Thing>Expr`/`mk<Thing>Val` return a fragment meant
  to be embedded inside a larger line, not a standalone statement. Keep
  this distinction when naming new helpers — it's how you can tell at a
  glance whether a helper's result needs further wrapping or can go
  straight into the emission list.
- **No local Nix toolchain in this environment**: there is no `nix`/
  `nix-instantiate` available to test-parse this file in the sandbox this
  file has been edited in. After any nontrivial edit, at minimum
  eyeball-check brace/paren/bracket balance (`grep -o '[{}]' file | sort |
  uniq -c`-style counting caught the one real bug found so far) and
  re-read the diff slowly for the list-literal gotcha above. Don't claim
  a change is "verified correct" — say it's "balanced/structurally
  consistent, not run through a real Nix parser" and let the user run
  `home-manager switch`/`nixos-rebuild` for the real check. Report exact
  file/line/column from their error output back against this file's
  content rather than guessing blind.

---

## 16. Rules for editing AGENTS.md itself

- **One numbered section per feature/topic**, in the same order as the
  emission order in §1 where it makes sense (rules/animations/startWith/
  extraConfig were appended in the order they were requested — that's
  fine, §1's emission-order list is the canonical ordering reference,
  this file's section order doesn't have to match it exactly, but should
  stay roughly topic-grouped).
- **When you add a new option/feature to `settings.nix`**, add or extend
  a section here in the same turn — don't let the two drift apart. At
  minimum: what the option looks like (a short Nix snippet), what Lua it
  renders to, and whether the design came from documented Hyprland
  behavior or was invented to fill a gap the user left open.
- **Distinguish sourced fact from invented design** explicitly, every
  time. If something is "the user described roughly this, and I chose
  the details" — say so, and say which details were chosen and why, the
  way §8 (animations) and §9 (startWith) do. Don't blend inferred
  behavior into a section as if it were confirmed from docs.
- **§13 (Known unverified assumptions) is a living list** — append to it
  whenever new code makes an unverified guess about `hl.*` runtime
  behavior; remove/update an entry once it's actually confirmed (say how
  it was confirmed — a working config someone ran, an upstream doc
  update, etc). Don't let it go stale by leaving a resolved assumption
  phrased as still-open.
- **§14 (Sources) gets a new bullet whenever a new wiki page or doc is
  consulted** — include the exact URL used (prefer the raw GitHub
  markdown URL when one was fetched, since those are stable and
  copy-pasteable; note the `wiki.hypr.land` rendered-page URL too when
  that's what was actually read, since raw markdown and rendered pages
  sometimes differ slightly in wording/organization).
- **§15 (Code style) is where a real bug's root cause goes**, generalized
  into a rule, once it's been hit and fixed — not just fixed silently in
  `settings.nix`. The Nix list-literal gotcha entry is the template: name
  the mistake, show the broken shape, show the fix, say where it was
  actually hit.
- **Keep this file readable top-to-bottom for someone who has never seen
  `settings.nix`** — don't assume the reader already has the code open
  side-by-side. Quote small Nix/Lua snippets inline rather than saying
  "see the function" with no context.
- **Don't delete history to save space.** If a design later gets
  superseded, say so in place ("X used to work like Y; changed to Z
  because ...") rather than silently rewriting the section as if Z was
  always the design — the same principle the memory-filesystem rules use
  for editing stored facts applies here: preserve the trail of *why*
  something changed, future-you may need it when the user asks to revert.
- **File is currently a single flat document.** If it grows past a size
  where a future agent would rather jump straight to one topic (a rough
  signal: once it's hard to `Ctrl+F` a section within a couple screens),
  consider splitting into `AGENTS.md` (this overview + §0–§2, §11–§16)
  plus per-topic files (`AGENTS-binds.md`, `AGENTS-rules.md`, etc.) linked
  from here — but don't split preemptively; a single file that's easy to
  search beats a maze of small files for a project this size.
