-- Click a fixed spot on screen from a hotkey.
--   Fn+F1              -> click the point configured as "f1" (left tab)
--   Fn+F2              -> click the point configured as "f2" (right tab)
--   Ctrl+Shift+Alt + C -> calibration: show/log the rx/ry under the cursor
--
-- Binding is to bare "f1"/"f2" with no modifiers on purpose. With default macOS
-- settings the top row sends media/brightness events and only Fn+F1 delivers a
-- real F1 keycode -- which is exactly the chord we want. (If "Use F1, F2 as
-- standard function keys" is enabled, plain F1 fires it instead.) hs.hotkey has
-- no "fn" modifier, so this is the way to express it.

local cfg  = require("config")
local util = require("lib.util")

local log = util.logger("click")

local M = {}

-- Resolve a configured point to absolute screen coordinates.
-- Absolute x/y wins; otherwise rx/ry are taken as fractions of the main display.
-- fullFrame (not frame) is used so the menu-bar strip is included -- these points
-- are measured off fullscreen apps that cover it.
local function resolve(p)
    if not p then return nil end
    if p.x and p.y then return {x = p.x, y = p.y} end
    if p.rx and p.ry then
        local f = hs.screen.mainScreen():fullFrame()
        return {x = f.x + f.w * p.rx, y = f.y + f.h * p.ry}
    end
    return nil
end

local function clickPoint(name)
    local conf = cfg.clicks or {}
    local pt = resolve((conf.points or {})[name])
    if not pt then
        log("no point configured for '%s'", name)
        return
    end

    local origin = hs.mouse.absolutePosition()
    hs.eventtap.leftClick(pt)
    log("clicked '%s' at (%.0f, %.0f)", name, pt.x, pt.y)

    -- Put the pointer back, so the hotkey doesn't yank the cursor across the
    -- screen. Deferred: the click has to be delivered before we move away.
    if conf.restoreCursor then
        hs.timer.doAfter(0.05, function()
            hs.mouse.absolutePosition(origin)
        end)
    end
end

-- Calibration helper: park the cursor over the target and press the hotkey to
-- read off the rx/ry to paste into config.lua.
local function calibrate()
    local pt = hs.mouse.absolutePosition()
    local f  = hs.screen.mainScreen():fullFrame()
    local rx = (pt.x - f.x) / f.w
    local ry = (pt.y - f.y) / f.h
    log("calibrate: x=%.0f y=%.0f -> rx=%.4f ry=%.4f (screen %.0fx%.0f)",
        pt.x, pt.y, rx, ry, f.w, f.h)
    hs.alert.show(string.format("rx = %.4f\nry = %.4f\n(%.0f, %.0f on %.0fx%.0f)",
        rx, ry, pt.x, pt.y, f.w, f.h), 4)
end

function M.start()
    hs.hotkey.bind({}, "f1", function() clickPoint("f1") end)
    hs.hotkey.bind({}, "f2", function() clickPoint("f2") end)
    hs.hotkey.bind(cfg.mods.debugKey, "c", calibrate)
end

return M
