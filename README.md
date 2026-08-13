# Hammerspoon Window Manager

A keyboard- and mouse-driven window manager for macOS, built on
[Hammerspoon](https://www.hammerspoon.org/). It provides smooth window
movement/resizing, half/quarter/third snapping with cycling, a one-key revert,
and a Rectangle-style "quick throw" where you fling the window under your cursor
into preset zones by holding a modifier and flicking the mouse.

The config is split into small, self-contained modules so it's easy to read,
tweak, and extend.

---

## Features

- **Held-arrow move & resize** with acceleration.
- **Magnetic edge-snapping**: while moving or resizing with the keyboard, edges
  snap flush to nearby window and screen edges so windows butt together instead
  of overlapping — keep pushing to break free.
- **Snapping**: halves, full height, maximize, corner quarters, vertical thirds.
- **Cycling presets**: one key steps through corners (clockwise) or thirds
  (left→right), starting from whichever slot is nearest.
- **Revert / toggle**: undo the last snap, press again to toggle back.
- **Quick throw**: hold `Cmd+Option`, a white dot locks onto the cursor, flick
  the mouse toward a zone, release to drop the window there — with a live
  preview overlay. Zones are defined per display profile.
- **Multi-display**: send the focused window to the previous/next display.
- **Click points**: `Fn+F1` / `Fn+F2` click a configured spot on screen, with a
  calibration hotkey for measuring the coordinates.
- **Search selected text**: send the active word or phrase to Google in the
  default browser without replacing the clipboard.
- **Recenter** a window without changing its size.
- **Coupled window edges**: resize or move a window and every adjacent window
  touching one of its edges resizes too. Changes propagate through shared
  neighbours, keeping every window along a T-junction seam aligned.
- **Unminimize** the frontmost app's minimized window.

---

## Requirements

- macOS
- [Hammerspoon](https://www.hammerspoon.org/) — install via
  [Homebrew](https://brew.sh/): `brew install --cask hammerspoon`, or download
  from the website.

Hammerspoon needs **Accessibility** permission to move windows:
**System Settings → Privacy & Security → Accessibility → enable Hammerspoon.**

---

## Installation

Your Hammerspoon config lives in `~/.hammerspoon`. Back up any existing config
first, then clone this repo into place:

```bash
# Back up an existing config, if you have one
[ -e ~/.hammerspoon ] && mv ~/.hammerspoon ~/.hammerspoon.backup

# Clone this repo as your Hammerspoon config
git clone https://github.com/sinan-cakmak/.hammerspoon/ ~/.hammerspoon
```

Then:

1. Launch **Hammerspoon**.
2. Grant **Accessibility** permission when prompted (see above).
3. Click the Hammerspoon menu-bar icon → **Reload Config** (or run
   `hs.reload()` in the console). You'll see a "Hammerspoon config loaded" alert.

> **Important:** the quick-throw zones are hard-coded to a specific display
> layout and **must be customized for your monitor** — see
> [Customizing throw zones](#customizing-throw-zones).

---

## Keyboard shortcuts

### Move & resize — `Ctrl + Shift` (hold)

| Keys                             | Action                                    |
| -------------------------------- | ----------------------------------------- |
| `Ctrl+Shift + ← ↑ → ↓`           | Move the window (accelerates while held)  |
| `Ctrl+Shift + ı / k / j / l`     | Expand toward top / bottom / left / right |
| `Ctrl+Shift+Alt + ı / k / j / l` | Shrink from top / bottom / left / right   |

Moving and directional resizing are **magnetic**: the moving edge snaps flush
when it comes within `move.snapDistance` (24px) of a neighbouring window's edge
or a screen edge. Keep holding the key to push past the magnet.

### Snapping & cycling — `Ctrl + Option`

| Keys                    | Action                                                         |
| ----------------------- | -------------------------------------------------------------- |
| `Ctrl+Option + ← →`     | Fill the left / right half                                     |
| `Ctrl+Option + ↑`       | Extend to full screen height (keeps width and x position)      |
| `Ctrl+Option + ↓`       | Fill the bottom half                                           |
| `Ctrl+Option + Return`  | Maximize to fill the whole display (not macOS fullscreen)      |
| `Ctrl+Option + *`       | Grow (centered)                                                |
| `Ctrl+Option + -`       | Shrink (centered)                                              |
| `Ctrl+Option + U`       | Cycle corner quarters, clockwise from the nearest              |
| `Ctrl+Option + D`       | Cycle vertical thirds (left → center → right) from the nearest |
| `Ctrl+Option + C`       | Recenter the window (keeps its current size)                   |
| `Ctrl+Option + Delete`  | Revert the last snap (press again to toggle back)              |

**Cycling behavior:** if the window isn't already in one of the cycle's slots, it
snaps to the nearest one; if it already is, it advances to the next. Cycle
progress is tracked against the frame the window *actually* ended up with, so
apps that refuse to shrink past a minimum size (e.g. Slack) still advance
through the slots instead of getting stuck.

### Multi-display — `Ctrl + Option + Cmd`

| Keys                      | Action                                       |
| ------------------------- | -------------------------------------------- |
| `Ctrl+Option+Cmd + ← →`   | Send the window to the previous / next display |

Displays are ordered left-to-right by their physical position, and the cycle
wraps around — so with two monitors this toggles back and forth. The window is
scaled proportionally onto the target display and kept fully on screen. A no-op
when only one display is connected.

### Quick throw — `Cmd + Option` (hold)

1. Hold `Cmd+Option`. A white dot locks onto the cursor and the window **under
   the cursor** is selected.
2. Move the mouse toward a direction — a highlighted preview shows the target
   zone.
3. Release the keys to drop the window into that zone (it's raised and focused).

Releasing without moving past the deadzone does nothing.

### Other

| Keys                 | Action                                                |
| -------------------- | ----------------------------------------------------- |
| `Cmd+F1` / `Cmd+F2`  | Click a fixed spot on screen (see [Click points](#click-points)) |
| `Cmd+Shift + M`      | Unminimize the frontmost app's first minimized window |
| `Ctrl+Option+Cmd + G` | Google the actively selected word or phrase |
| `Ctrl+Shift+Alt + C` | Calibration: show the `rx`/`ry` under the cursor      |
| `Ctrl+Shift+Alt + D` | Dump quick-throw diagnostics to the log               |

> **Keyboard layout note:** the move/resize bindings use the `ı` (dotless i)
> key from the Turkish layout alongside `j/k/l`. On other layouts the `ı`
> binding may not fire — change it in `modules/window_move.lua` to a key your
> layout has (e.g. `i`).

---

## Project structure

```
~/.hammerspoon/
├── init.lua              # Thin loader: lists and starts modules
├── config.lua            # All tunables (modifiers, accent, throw zones, steps)
├── lib/
│   ├── util.lua          # Shared helpers (color, logger)
│   └── coupling.lua      # Suppression flag so placement operations don't
│                         #   resize neighbours via coupled edges
└── modules/
    ├── window_move.lua   # Held-arrow move / resize engine + magnetic snapping
    ├── window_snap.lua   # Halves, maximize, corner/third cycling, recenter, revert
    ├── window_throw.lua  # Cmd+Option quick throw
    ├── window_display.lua # Send the window between displays
    ├── window_tile_resize.lua # Coupled movement/resizing of adjacent windows
    ├── click_points.lua  # Fn+F1 / Fn+F2 click fixed screen spots
    ├── search_selection.lua # Google selected text in the default browser
    └── app_control.lua   # Unminimize, app utilities
```

Each module returns a table with a `start()` function; `init.lua` requires and
starts them, isolating failures so one broken module won't take down the rest.

---

## Configuration

All tunables live in [`config.lua`](config.lua):

- **`mods`** — the modifier combos for each feature group.
- **`accent`** — the overlay color (azure by default).
- **`move`** — step sizes, acceleration, timer interval, minimum window size, and
  `snapDistance` (magnetic snap radius in px; `0` disables magnetism).
- **`throw`** — the cursor deadzone, drop animation, and per-display zone profiles.
- **`tile`** — coupled move/resizing: toggle, edge tolerance, neighbour min size.
- **`clicks`** — the `Fn+F1`/`Fn+F2` click targets and cursor-restore toggle.
- **`debug`** — set `true` to write logs to `/tmp/hs.log`.

### Click points

`Cmd+F1` and `Cmd+F2` click a fixed spot on the main display — useful for buttons
in a fullscreen app you hit constantly. Targets live in `config.clicks.points`
as **fractions** of the display (`rx`/`ry`, 0–1) so they survive a resolution
change; set `x`/`y` instead to pin absolute coordinates.

Fractions measured on one display are only approximate on another — a centered,
letterboxed layout shifts when the aspect ratio changes. **Calibrate on the
machine you'll actually use:** put the cursor over the target, press
`Ctrl+Shift+Alt + C`, and an alert shows the exact `rx`/`ry` to paste into
`config.lua`.

> Plain `Cmd+F1`/`Cmd+F2` works whether or not **Use F1, F2, etc. keys as
> standard function keys** is enabled: the module binds the real F1/F2 keycodes
> *and* intercepts the brightness keys (which is what the top row emits by
> default), firing on either. Brightness only changes when `Cmd` isn't held.

### Customizing throw zones

Throw zones are grouped into **per-display profiles**. A throw only activates
when the screen under the cursor matches a profile's resolution, so a layout
tuned for one monitor won't fire on another. Each profile looks like:

```lua
throw = {
    profiles = {
        {
            name = "ultrawide 32:9 (5120x1440)",
            screen = {w = 5120, h = 1440},  -- full display resolution to match
            zones = {
                left  = {x = 0, y = 30, w = 1069, h = 1410},
                -- ... right / up / down and the four corners
            },
        },
    },
},
```

Zone values are absolute screen coordinates (`x, y, w, h`). To capture your own,
position a window exactly where you want a zone, then with Hammerspoon running
open the **Console** (menu-bar icon → Console) and run:

```lua
hs.inspect(hs.window.focusedWindow():frame())
```

Repeat for each direction (left / right / up / down and the corners) and paste
the values into that profile's `zones`. To support another monitor, add a new
entry to `profiles` with its resolution and zones.

---

## Extending

To add a new feature:

1. Create `modules/your_feature.lua` that returns `{ start = function() ... end }`.
2. Read any settings from `require("config")`.
3. Add `"modules.your_feature"` to the `modules` list in `init.lua`.
4. Reload Hammerspoon.

---

## Troubleshooting

- **Nothing happens / windows don't move:** confirm Hammerspoon has
  **Accessibility** permission, then Reload Config.
- **A shortcut does nothing:** check for conflicts with macOS or other apps, and
  verify your keyboard layout has the key (see the layout note above).
- **Quick throw stops working:** a watchdog automatically re-enables the event
  tap if macOS disables it. Set `debug = true` in `config.lua` and inspect
  `/tmp/hs.log` for details.
