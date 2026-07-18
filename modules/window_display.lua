-- Send the focused window to another display.
--   Ctrl+Alt+Cmd + Left/Right -> move the window to the previous/next display
--
-- Displays are ordered left-to-right by their physical x position, so Left and
-- Right match how the monitors actually sit on the desk (hs.screen.allScreens()
-- order does not). Wraps around at the ends, so two displays toggle back and
-- forth. A no-op when only one display is connected.

local cfg      = require("config")
local util     = require("lib.util")
local coupling = require("lib.coupling")

local log = util.logger("display")

local M = {}

-- All screens, ordered left-to-right by their physical position.
local function screensLeftToRight()
    local screens = hs.screen.allScreens()
    table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)
    return screens
end

-- Move the focused window `delta` displays along (-1 = left, +1 = right).
local function moveToAdjacentScreen(delta)
    local win = hs.window.focusedWindow()
    if not win then return end

    local screens = screensLeftToRight()
    if #screens < 2 then
        log("only one display connected -- ignoring")
        return
    end

    local cur = win:screen()
    if not cur then return end

    local index
    for i, s in ipairs(screens) do
        if s:id() == cur:id() then index = i break end
    end
    if not index then return end

    local target = screens[((index - 1 + delta) % #screens) + 1]

    -- Programmatic move: don't let paired-edge resizing drag neighbours along.
    coupling.suspend(win:id())

    -- Scale proportionally so the window keeps its relative place and size on a
    -- display of a different resolution, and stays fully on screen. 0 = instant.
    win:moveToScreen(target, false, true, 0)
    log("moved window to display %d/%d", ((index - 1 + delta) % #screens) + 1, #screens)
end

function M.start()
    local mods = cfg.mods.display
    hs.hotkey.bind(mods, "Left",  function() moveToAdjacentScreen(-1) end)
    hs.hotkey.bind(mods, "Right", function() moveToAdjacentScreen(1) end)
end

return M
