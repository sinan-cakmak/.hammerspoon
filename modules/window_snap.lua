-- Window snapping: half-screen, centering, and cycling presets.
--   Ctrl+Alt + Left/Right/Down    -> fill that half of the screen
--   Ctrl+Alt + Up                 -> extend to full screen height (keep width/x)
--   Ctrl+Alt + C                  -> recenter (keeps current size)
--   Ctrl+Alt + Return             -> maximize to fill the whole display
--   Ctrl+Alt + U                  -> cycle corner quarters (clockwise from nearest)
--   Ctrl+Alt + D                  -> cycle vertical thirds (left -> center -> right, from nearest)
--   Ctrl+Alt + Delete             -> revert the last snap (press again to toggle back)
--
-- Cycle behaviour: if the window isn't already sitting in one of the cycle's
-- slots, it snaps to the nearest slot; if it already is, it advances to the next.

local cfg = require("config")

local M = {}

-- Compute the target frame for a named position on the window's screen.
local function frameFor(position, win)
    local max = win:screen():frame()
    local f = {x = max.x, y = max.y, w = max.w, h = max.h}

    if position == "left" then
        f.w = max.w / 2
    elseif position == "right" then
        f.x = max.x + max.w / 2
        f.w = max.w / 2
    elseif position == "up" then
        -- Keep the window's current width/x; extend it to fill the full
        -- screen height (top and bottom edges to the very ends).
        local cur = win:frame()
        f.x = cur.x
        f.w = cur.w
    elseif position == "down" then
        f.y = max.y + max.h / 2
        f.h = max.h / 2
    elseif position == "topleft" then
        f.w = max.w / 2
        f.h = max.h / 2
    elseif position == "topright" then
        f.x = max.x + max.w / 2
        f.w = max.w / 2
        f.h = max.h / 2
    elseif position == "bottomleft" then
        f.y = max.y + max.h / 2
        f.w = max.w / 2
        f.h = max.h / 2
    elseif position == "bottomright" then
        f.x = max.x + max.w / 2
        f.y = max.y + max.h / 2
        f.w = max.w / 2
        f.h = max.h / 2
    elseif position == "leftthird" then
        f.w = max.w / 3
    elseif position == "centerthird" then
        f.x = max.x + max.w / 3
        f.w = max.w / 3
    elseif position == "rightthird" then
        f.x = max.x + max.w * 2 / 3
        f.w = max.w / 3
    elseif position == "maximize" then
        -- Fill the whole screen (full work area, not macOS fullscreen mode).
        -- f already equals max, so nothing more to do.
    elseif position == "center" then
        -- Keep the window's current size; just recenter it on the screen
        local cur = win:frame()
        f.w = cur.w
        f.h = cur.h
        f.x = max.x + (max.w - cur.w) / 2
        f.y = max.y + (max.h - cur.h) / 2
    end

    return f
end

-- Remember each window's frame before we change it, so a snap can be reverted.
local prevFrames = {}

-- Set a window's frame, first stashing its current frame for revert/toggle.
-- The 0 duration disables the default ~0.2s slide animation, so snaps are instant.
local function applyFrame(win, newFrame)
    prevFrames[win:id()] = win:frame()
    win:setFrame(newFrame, 0)
end

-- Restore the focused window's pre-snap frame. Swaps current<->saved so
-- repeated presses toggle between the two.
local function revert()
    local win = hs.window.focusedWindow()
    if not win then return end
    local id = win:id()
    local saved = prevFrames[id]
    if not saved then return end
    prevFrames[id] = win:frame()
    win:setFrame(saved, 0)  -- 0 = instant, matching applyFrame
end

local function snapWindow(position)
    local win = hs.window.focusedWindow()
    if not win then return end
    applyFrame(win, frameFor(position, win))
end

-- True if two frames match within a tolerance (window managers round sizes).
local function framesMatch(a, b, tol)
    tol = tol or 15
    return math.abs(a.x - b.x) <= tol
        and math.abs(a.y - b.y) <= tol
        and math.abs(a.w - b.w) <= tol
        and math.abs(a.h - b.h) <= tol
end

local function frameCenter(f)
    return {x = f.x + f.w / 2, y = f.y + f.h / 2}
end

-- Per-window cycle progress: which slot we last placed the window in, plus the
-- frame it ACTUALLY ended up with. We compare new presses against that real
-- frame -- not the ideal slot frame -- so apps that clamp their size (e.g. Slack
-- refusing to shrink to a narrow third) are still recognised as "in this slot",
-- letting the next press advance instead of getting stuck re-snapping in place.
local cycleState = {}  -- winId -> {name = cycleName, index = i, frame = actualFrame}

-- Place the window in order[index] and record the resulting (possibly clamped) frame.
local function placeInCycle(win, name, order, index)
    applyFrame(win, frameFor(order[index], win))
    cycleState[win:id()] = {name = name, index = index, frame = win:frame()}
end

-- Cycle the focused window through an ordered list of named positions.
-- If the window is still sitting where we last placed it, advance to the next
-- (wrapping); otherwise jump to whichever slot's center is closest.
local function cycle(name, order)
    local win = hs.window.focusedWindow()
    if not win then return end
    local id = win:id()
    local cur = win:frame()

    -- Still where we left it? -> advance to the next slot. Comparing against the
    -- recorded real frame (rather than the ideal) is what makes clamped apps work.
    local st = cycleState[id]
    if st and st.name == name and framesMatch(cur, st.frame) then
        placeInCycle(win, name, order, (st.index % #order) + 1)
        return
    end

    -- Fresh entry (or the window was moved): snap to the nearest slot by center.
    local c = frameCenter(cur)
    local bestIndex, bestDist
    for i, pos in ipairs(order) do
        local pc = frameCenter(frameFor(pos, win))
        local d = (pc.x - c.x) ^ 2 + (pc.y - c.y) ^ 2
        if not bestDist or d < bestDist then
            bestDist, bestIndex = d, i
        end
    end
    placeInCycle(win, name, order, bestIndex)
end

function M.start()
    local mods = cfg.mods.snap
    hs.hotkey.bind(mods, "Left",  function() snapWindow("left") end)
    hs.hotkey.bind(mods, "Right", function() snapWindow("right") end)
    hs.hotkey.bind(mods, "Up",    function() snapWindow("up") end)
    hs.hotkey.bind(mods, "Down",  function() snapWindow("down") end)
    hs.hotkey.bind(mods, "c",     function() snapWindow("center") end)
    hs.hotkey.bind(mods, "Return", function() snapWindow("maximize") end)

    -- Corner quarters, cycled clockwise starting from the nearest corner.
    hs.hotkey.bind(mods, "u", function()
        cycle("quarters", {"topleft", "topright", "bottomright", "bottomleft"})
    end)

    -- Vertical thirds, cycled left -> center -> right starting from the nearest.
    hs.hotkey.bind(mods, "d", function()
        cycle("thirds", {"leftthird", "centerthird", "rightthird"})
    end)

    -- Revert the last snap (toggles between current and previous frame).
    hs.hotkey.bind(mods, "delete", revert)
end

return M
