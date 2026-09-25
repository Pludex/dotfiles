# AGENTS.md - Riverctl Reference & Guidelines for AI Agents

## ⚠️ Critical AI Pitfalls & Syntax Rules

1. **`spawn` Shell Command Constraints**:
   - `spawn` takes **exactly one argument**.
   - If a command includes arguments/flags, it **MUST** be quoted.
   - ✅ Correct: `riverctl map normal Mod4 Return spawn "foot -e btop"`
   - ❌ Incorrect: `riverctl map normal Mod4 Return spawn foot -e btop`

2. **Tag Bitmask Calculations (Base-10 Integers)**:
   - River tags use bitmasks represented as base-10 integers.
   - Tag $N$ corresponds to bit position $N-1$, value $2^{(N-1)}$.
   - ⚠️ **Common AI Error**: Passing `3` to target Tag 3. `3` in binary is `011` (Tag 1 AND Tag 2). Tag 3 alone is `4` ($2^2$).

3. **Floating Prerequisites for Window Geometry**:
   - `position` and `dimensions` rules **ONLY** apply if the view is explicitly set to floating via a matching `float` rule.

4. **Rule Specificity Priority**:
   - `app-id` matching always takes precedence over `title` matching (`app-id` > `title`).
   - Opposing rules (e.g., `float` vs `no-float`, `ssd` vs `csd`) with identical arguments overwrite each other in the rule list.

5. **Modifier Key Syntax**:
   - Chain multiple modifiers using `+` (e.g., `Mod4+Shift`, `Mod1+Control`).
   - Use `None` for no modifiers.
   - Key aliases: `Mod4` = Super / Windows, `Mod1` = Alt.

---

## 🏷️ Tag Bitmask Quick Reference

| Tag Index | Binary | Base-10 Integer | Combination Example | Base-10 Integer |
| :--- | :--- | :--- | :--- | :--- |
| **Tag 1** | `000000001` | `1` | Tags 1 & 2 | `3` |
| **Tag 2** | `000000010` | `2` | Tags 1, 2, 3 | `7` |
| **Tag 3** | `000000100` | `4` | Tags 1, 3, 4, 9 | `269` |
| **Tag 4** | `000001000` | `8` | All Tags (1–9) | `511` |
| **Tag 5** | `000010000` | `16` | | |
| **Tag 6** | `000100000` | `32` | | |
| **Tag 7** | `001000000` | `64` | | |
| **Tag 8** | `010000000` | `128` | | |
| **Tag 9** | `100000000` | `256` | | |

---

## ⌨️ Key & Pointer Mappings Syntax

### Commands
- `declare-mode <mode>`
- `enter-mode <mode>`
- `map [-release|-repeat|-layout <index>] <mode> <modifiers> <keysym> <command>`
- `map-pointer <mode> <modifiers> <button> move-view|resize-view|<command>`
- `map-switch <mode> lid|tablet open|close|on|off <command>`
- `unmap [-release] <mode> <modifiers> <keysym>`
- `unmap-pointer <mode> <modifiers> <button>`
- `unmap-switch <mode> lid|tablet <state>`

### Accepted Options
- **Modifiers**: `Shift`, `Control`, `Mod1` (Alt), `Mod3`, `Mod4` (Super), `Mod5`, `None`
- **Keysyms**: XKB keysym names (e.g., `Return`, `space`, `Print`, `J`)
- **Buttons**: Linux input event codes (`BTN_LEFT`, `BTN_RIGHT`, `BTN_MIDDLE`)

---

## 📐 Window Rules (`rule-add` / `rule-del`)

### Command Structure
- `riverctl rule-add [-app-id <glob>] [-title <glob>] <action> [<args>]`
- `riverctl rule-del [-app-id <glob>] [-title <glob>] <action>`
- `riverctl list-rules float|ssd|tags|position|dimensions|fullscreen`

### Supported Actions
| Action | Parameters | Requires `float`? | Target Scope |
| :--- | :--- | :--- | :--- |
| `float` / `no-float` | None | N/A | New views |
| `ssd` / `csd` | None | No | New & existing views |
| `tags` | `<tags_bitmask>` | No | New views |
| `output` | `<connector\|identifier>` | No | New views |
| `position` | `<x> <y>` | **YES** | New views |
| `dimensions` | `<w> <h>` | **YES** | New views |
| `fullscreen` / `no-fullscreen` | None | No | New views |
| `tearing` / `no-tearing` | None | No | New & existing views |

---

## ⚙️ Core Actions & Window Management

### Actions
- **View Focus**: `focus-view [-skip-floating] next|previous|up|down|left|right`
- **Output Focus**: `focus-output next|previous|up|right|down|left|<name>`
- **View Operations**: `close`, `toggle-float`, `toggle-fullscreen`, `zoom`, `swap next|previous|up|down|left|right`
- **Floating Controls**:
  - `move up|down|left|right <delta_px>`
  - `resize horizontal|vertical <delta_px>`
  - `snap up|down|left|right`
- **Output Transfer**: `send-to-output [-current-tags] next|previous|up|right|down|left|<name>`
- **System**: `spawn <shell_command>`, `exit`

### Layout Management
- `default-layout <namespace>`
- `output-layout <namespace>`
- `send-layout-cmd <namespace> <command>` (e.g., `riverctl send-layout-cmd rivertile "main-ratio 0.5"`)

### Tag Operations
- `set-focused-tags <tags_bitmask>`
- `set-view-tags <tags_bitmask>`
- `toggle-focused-tags <tags_bitmask>`
- `toggle-view-tags <tags_bitmask>`
- `spawn-tagmask <tagmask_bitmask>`
- `focus-previous-tags`
- `send-to-previous-tags`

### Visual & Behavior Configuration
- `default-attach-mode top|bottom|above|below|after <N>`
- `output-attach-mode top|bottom|above|below|after <N>`
- `allow-tearing enabled|disabled`
- `background-color 0xRRGGBB|0xRRGGBBAA`
- `border-color-focused 0xRRGGBB|0xRRGGBBAA`
- `border-color-unfocused 0xRRGGBB|0xRRGGBBAA`
- `border-color-urgent 0xRRGGBB|0xRRGGBBAA`
- `border-width <pixels>`
- `focus-follows-cursor disabled|normal|always`
- `hide-cursor <timeout_ms>`
- `hide-cursor when-typing enabled|disabled`
- `set-cursor-warp disabled|on-output-change|on-focus-change`
- `set-repeat <rate> <delay>`
- `xcursor-theme <theme_name> [<size>]`

---

## 🎛️ Input Device Configuration

### Global Commands
- `list-inputs`
- `list-input-configs`
- `keyboard-layout [-rules <r>] [-model <m>] [-variant <v>] [-options <o>] <layout>`
- `keyboard-layout-file <path>`

### Input Device Properties (`input <device_name> <property> <value>`)
*Device name format: `type-vendor_id-product_id-name` or glob pattern.*

- `events enabled|disabled|disabled-on-external-mouse`
- `accel-profile none|flat|adaptive`
- `pointer-accel <factor>` (float between `-1.0` and `1.0`)
- `click-method none|button-areas|clickfinger`
- `drag enabled|disabled`
- `drag-lock enabled|disabled`
- `disable-while-typing enabled|disabled`
- `disable-while-trackpointing enabled|disabled`
- `middle-emulation enabled|disabled`
- `natural-scroll enabled|disabled`
- `scroll-factor <factor>` (float > `0`)
- `left-handed enabled|disabled`
- `tap enabled|disabled`
- `tap-button-map left-right-middle|left-middle-right`
- `scroll-method none|two-finger|edge|button`
- `scroll-button <button>`
- `scroll-button-lock enabled|disabled`
- `map-to-output <output>|disabled`
