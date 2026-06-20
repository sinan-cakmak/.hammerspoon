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
- **Snapping**: halves, corner quarters, and vertical thirds.
- **Cycling presets**: one key steps through corners (clockwise) or thirds
  (left→right), starting from whichever slot is nearest.
- **Revert / toggle**: undo the last snap, press again to toggle back.
- **Quick throw**: hold `Cmd+Option`, a white dot locks onto the cursor, flick
  the mouse toward a zone, release to drop the window there — with a live
  preview overlay.
- **Recenter** a window without changing its size.
- **Paired-edge resizing**: drag the shared edge between two adjacent windows and
  the neighbour resizes too, keeping the seam glued (tiling-style).
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
git clone https://github.com/sinan-cakmak/.hammerspoon/tree/main ~/.hammerspoon
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
| `Ctrl+Shift + *`                 | Grow (centered)                           |
| `Ctrl+Shift + -`                 | Shrink (centered)                         |
| `Ctrl+Shift + ı / k / j / l`     | Expand toward top / bottom / left / right |
| `Ctrl+Shift+Alt + ı / k / j / l` | Shrink from top / bottom / left / right   |

### Snapping & cycling — `Ctrl + Option`

| Keys                    | Action                                                         |
| ----------------------- | -------------------------------------------------------------- |
| `Ctrl+Option + ← → ↑ ↓` | Fill the left / right / top / bottom half                      |
| `Ctrl+Option + U`       | Cycle corner quarters, clockwise from the nearest              |
| `Ctrl+Option + D`       | Cycle vertical thirds (left → center → right) from the nearest |
| `Ctrl+Option + C`       | Recenter the window (keeps its current size)                   |
| `Ctrl+Option + Delete`  | Revert the last snap (press again to toggle back)              |

**Cycling behavior:** if the window isn't already in one of the cycle's slots, it
snaps to the nearest one; if it already is, it advances to the next.

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
| `Cmd+Shift + M`      | Unminimize the frontmost app's first minimized window |
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
│   └── util.lua          # Shared helpers (color, logger)
└── modules/
    ├── window_move.lua   # Held-arrow move / resize engine
    ├── window_snap.lua   # Halves, corner/third cycling, recenter, revert
    ├── window_throw.lua  # Cmd+Option quick throw
    ├── window_tile_resize.lua # Paired-edge resizing of adjacent windows
    └── app_control.lua   # Unminimize, app utilities
```

Each module returns a table with a `start()` function; `init.lua` requires and
starts them, isolating failures so one broken module won't take down the rest.

---

## Configuration

All tunables live in [`config.lua`](config.lua):

- **`mods`** — the modifier combos for each feature group.
- **`accent`** — the overlay color (azure by default).
- **`move`** — step sizes, acceleration, timer interval, minimum window size.
- **`throw`** — the cursor deadzone, drop animation, and target zones.
- **`tile`** — paired-edge resizing: toggle, edge tolerance, neighbour min size.
- **`debug`** — set `true` to write logs to `/tmp/hs.log`.

### Customizing throw zones

The throw `zones` in `config.lua` are absolute screen coordinates
(`x, y, w, h`) and are specific to the display they were captured on. To set
your own, position a window exactly where you want a zone, then read its frame.

With Hammerspoon running, open the **Console** (menu-bar icon → Console) and run:

```lua
hs.inspect(hs.window.focusedWindow():frame())
```

Repeat for each direction (left / right / up / down) and paste the values into
`config.throw.zones`. Coordinates are global across all displays, so zones can
live on any monitor.

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
