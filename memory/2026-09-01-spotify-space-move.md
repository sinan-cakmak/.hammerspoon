# Debug report: Spotify window did not move to its new Desktop

- **Symptom:** `Fn+F` created and opened a new Desktop, but Spotify remained on
  its original Desktop and was not centered/resized.
- **Root cause:** This Mac runs macOS 26.5.1 with Hammerspoon 1.0.0.
  `hs.spaces.moveWindowToSpace` uses the obsolete compatibility-ID mechanism;
  on macOS 15+ it can return `true` without moving the window. The module trusted
  that return value and switched Spaces before verifying Spotify's membership.
- **Fix:** `modules/spotify_space.lua` now invokes the local
  `bin/move-window-to-space` helper. The helper uses macOS 26's
  `SLSBridgedMoveWindowsToManagedSpaceOperation`, polls WindowServer until the
  target Space is confirmed, and only then lets Hammerspoon open that Space and
  center the window. Centering also suspends coupled-edge handling.
- **Evidence:** The live Spotify window (ID 15678) was moved from Space 2151 to
  Space 3 and back to Space 2151. Both moves were confirmed by
  `SLSCopySpacesForWindows`. It was then staged on Space 3 so the first shortcut
  press after reload exercises the enter flow; final membership was `(3)`.
- **Regression test:** `tests/spotify_space_helper.sh` syntax-checks the Lua
  module, rejects reintroduction of `hs.spaces.moveWindowToSpace`, probes the
  bridged macOS operation, and optionally performs and verifies a live move.
- **Related:** Hammerspoon issues #3636/#3698 document the false-success
  behavior. Yabai 7.1.25 adopted the macOS 26 bridged operation used here.
- **Status:** DONE_WITH_CONCERNS — the move primitive and integration syntax are
  verified; the complete hotkey path needs one Hammerspoon reload to execute.
