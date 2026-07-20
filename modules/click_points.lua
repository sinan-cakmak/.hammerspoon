-- Click a fixed spot on screen from a hotkey.
--   Cmd+F1             -> click the point configured as "f1" (left tab)
--   Cmd+F2             -> click the point configured as "f2" (right tab)
--   Ctrl+Shift+Alt + C -> calibration: show/log the rx/ry under the cursor
--
-- The top row is dual-purpose. With the default macOS setting ("Use F1, F2 as
-- standard function keys" OFF), F1/F2 emit brightness signals, not F1/F2
-- keycodes -- so hs.hotkey never sees them unless Fn is also held. We therefore
-- bind BOTH ways so plain Cmd+F1/F2 works regardless of that setting:
--   1. hs.hotkey on Cmd+F1/F2   -- fires when F-keys ARE standard keycodes.
--   2. a systemDefined event tap -- catches the brightness keys directly (the
--      default), fires when Cmd is held, and swallows the event so brightness
--      doesn't change.

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

    -- Post the click with modifier flags explicitly cleared. The hotkey uses
    -- Cmd, and Cmd is still physically held when this runs -- a plain
    -- hs.eventtap.leftClick would inherit that and deliver a Cmd+click, which a
    -- web page treats very differently from a normal click (e.g. open-in-new-tab
    -- instead of selecting). setFlags({}) makes it a real, unmodified click.
    local ev = hs.eventtap.event
    ev.newMouseEvent(ev.types.leftMouseDown, pt):setFlags({}):post()
    ev.newMouseEvent(ev.types.leftMouseUp, pt):setFlags({}):post()
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

-- Brightness key (systemKey name) -> configured click point.
-- On MacBooks F1 is brightness-down and F2 is brightness-up.
local BRIGHTNESS_TO_POINT = {
    BRIGHTNESS_DOWN = "f1",
    BRIGHTNESS_UP   = "f2",
}

-- Kept at module scope so the event tap isn't garbage-collected after start().
local brightnessTap = nil

function M.start()
    -- Path 1: real F1/F2 keycodes (standard-function-keys mode, or Fn held).
    hs.hotkey.bind({"cmd"}, "f1", function() clickPoint("f1") end)
    hs.hotkey.bind({"cmd"}, "f2", function() clickPoint("f2") end)
    hs.hotkey.bind(cfg.mods.debugKey, "c", calibrate)

    -- Path 2: the default media-key behaviour. Catch Cmd + brightness-down/up
    -- and fire the click instead, swallowing the event so brightness is
    -- unaffected. When Cmd isn't held we return false, leaving brightness normal.
    brightnessTap = hs.eventtap.new({hs.eventtap.event.types.systemDefined}, function(e)
        local d = e:systemKey()
        if not d or not d.down then return false end
        local point = BRIGHTNESS_TO_POINT[d.key]
        if not point then return false end
        if not e:getFlags().cmd then return false end
        clickPoint(point)
        return true  -- consume: don't also change screen brightness
    end)
    brightnessTap:start()
end

return M
