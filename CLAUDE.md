# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal Hammerspoon window manager for macOS, written in Lua. This repo *is*
`~/.hammerspoon` — the live config Hammerspoon loads. There is no build step, no
package manager, and no test suite.

## Commands

There is no build/lint/test tooling. Verification is a two-step loop:

```bash
# 1. Syntax-check a file (luajit is available via Homebrew; `lua` is not installed)
luajit -bl modules/window_move.lua /dev/null && echo OK
```

2. Reload the config: Hammerspoon menu-bar icon → **Reload Config**. The `hs` CLI
   is installed but `hs -c "hs.reload()"` fails here — the `ipc` module isn't
   loaded — so reloading must be done by the user from the menu bar.

Debugging: set `debug = true` in `config.lua` and read `/tmp/hs.log` (truncated
on every reload). Modules log via `util.logger("tag")`. `Ctrl+Shift+Alt + D`
dumps quick-throw state to the log.

## Architecture

**Module contract.** `init.lua` is a thin loader holding a list of module names.
Each module returns `{ start = function() ... end }` and reads its tunables from
`require("config")`. `init.lua` wraps both the `require` and the `start()` in
`pcall`, so one broken module cannot take down the rest. Adding a feature means
dropping a file in `modules/` and adding its name to that list.

**`config.lua` is the single source of tunables** — modifier combos (named by
intent: `move`, `snap`, `throw`, `display`, `shrinkDir`, `debugKey`), step sizes,
snap distances, throw zones, colors. Prefer adding a config key over hardcoding.

### Cross-module coupling (the non-obvious part)

`modules/window_tile_resize.lua` subscribes to `windowMoved` events for *every*
window and resizes neighbours that share an edge with a resized or moved window.
Programmatic frame changes fire the same events, which would make unrelated
windows follow along.
`lib/coupling.lua` is the shared, time-based suppression flag that prevents this:
**any module that moves a window programmatically must call
`coupling.suspend(win:id())` first** (see `window_throw.lua`, `window_display.lua`).
It is time-based because the events arrive asynchronously, after the `setFrame`.

That module distinguishes a one-sided *resize* from a *move*: one moved edge
drives its neighbour during a resize, while two equally translated opposite
edges drive neighbours on both sides during a move. If both opposite edges move
by different amounts (such as a centred resize), coupling is ignored. Updates
are propagated synchronously through changed neighbours so every window along a
T-junction seam follows, rather than stopping after the first adjacent window.

### Two state-tracking patterns worth understanding before editing

**Magnetic snapping (`window_move.lua`)** uses a *virtual frame*. Keypresses
accumulate into `virtual` (the raw, unsnapped geometry) while the window is shown
a snapped copy. This separation is what lets a window stick to an edge yet break
free once the raw movement travels past `move.snapDistance` — reading the live
window frame back each tick instead would make it permanently stuck. Neighbour
and screen edges are snapshotted once per gesture into `snapCtx` (cheap, and
they don't move during a keyboard drive). `virtual` re-syncs to the live window
when focus changes or when the window moved by some other means.

Movement snaps the whole frame's position; a directional resize snaps only the
dragged edge(s). The centered grow/shrink is deliberately *not* snapped, since it
moves all four edges at once.

**Cycle progress (`window_snap.lua`)** is tracked in `cycleState` per window id,
recording the slot index and **the frame the window actually ended up with** —
not the frame that was requested. Comparing against the ideal slot frame breaks
for apps that clamp their minimum size (Slack): the window never matches any
slot, so the cycle re-snaps in place forever instead of advancing. Keep this
"compare against the real, post-clamp frame" property if you touch `cycle()`.

`frameFor(position, win)` is the single place that computes named slot geometry
(halves, thirds, quarters, `maximize`, `center`, full-height `up`). Add new
positions there rather than computing frames at the call site.

## Conventions

- Comments explain *why*, especially where a naive implementation would be wrong
  (the virtual frame, the coupling flag, persistent canvases). Match that density.
- `window_throw.lua` reuses two persistent `hs.canvas` overlays — recreating them
  per throw caused Hammerspoon to lag after a few uses. Don't "simplify" that.
  It also polls modifier state on a timer rather than trusting a single release
  event, and runs a watchdog that re-enables the event tap (macOS disables taps
  whose callback stalls — the classic "stops working after a while").
- Throw zones are absolute screen coordinates grouped into per-display
  `profiles`, matched by full display resolution, so a layout tuned for one
  monitor doesn't fire on another.
- Keyboard layout: bindings use `ı` (Turkish dotless i) alongside `j/k/l`.

## Keeping docs current

`README.md` is user-facing documentation of every shortcut and config key.
**Update it in the same change whenever you add, remove, or rebind a shortcut, or
add a config option** — the shortcut tables, Features list, project structure,
and Configuration section all go stale quickly otherwise.
