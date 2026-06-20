-- Quick throw: hold Cmd+Option to lock the cursor (white dot), move the mouse
-- in a direction to fling the window under the cursor into a target zone.
-- Release the modifiers to commit. Zones are defined in config.lua.

local cfg  = require("config")
local util = require("lib.util")

local log = util.logger("throw")

local M = {}

function M.start()
    local zones    = cfg.throw.zones
    local deadzone = cfg.throw.deadzone

    -- State
    local active = false
    local origin = nil
    local window = nil
    local dir    = nil
    local timer  = nil
    local flagsTap = nil
    local count  = 0

    -- Persistent overlay canvases, created once and reused (never recreated per
    -- throw -- doing that previously caused Hammerspoon to lag after a few uses).
    local dotSize = 28
    local dotC = dotSize / 2
    local dot = hs.canvas.new({x = 0, y = 0, w = dotSize, h = dotSize})
    dot:appendElements(
        {   -- soft white glow
            type = "circle", action = "fill",
            center = {x = dotC, y = dotC}, radius = 9,
            fillColor = {red = 1, green = 1, blue = 1, alpha = 0.25},
        },
        {   -- white core
            type = "circle", action = "fill",
            center = {x = dotC, y = dotC}, radius = 4.5,
            fillColor = {red = 1, green = 1, blue = 1, alpha = 0.98},
        }
    )
    dot:level(hs.canvas.windowLevels.overlay)

    local preview = hs.canvas.new({x = 0, y = 0, w = 100, h = 100})
    preview[1] = {
        type = "rectangle", action = "strokeAndFill",
        fillColor   = util.rgba(cfg.accent, 0.18),
        strokeColor = util.rgba(cfg.accent, 0.9),
        strokeWidth = 4,
        roundedRectRadii = {xRadius = 12, yRadius = 12},
    }
    preview:level(hs.canvas.windowLevels.overlay)

    local function showDot(pt)
        dot:topLeft({x = pt.x - dotC, y = pt.y - dotC})
        dot:show()
    end

    local function showPreview(zone)
        if not zone then preview:hide(); return end
        preview:frame(zone)
        preview:show()
    end

    local function pickDirection(pt)
        local dx = pt.x - origin.x
        local dy = pt.y - origin.y
        if math.abs(dx) < deadzone and math.abs(dy) < deadzone then
            return nil
        end
        if math.abs(dx) >= math.abs(dy) then
            return dx < 0 and "left" or "right"
        else
            return dy < 0 and "up" or "down"
        end
    end

    -- Topmost visible standard window whose frame contains the given point.
    local function windowUnderPoint(pt)
        for _, win in ipairs(hs.window.orderedWindows()) do
            if win:isStandard() and win:isVisible() then
                local f = win:frame()
                if pt.x >= f.x and pt.x <= f.x + f.w
                    and pt.y >= f.y and pt.y <= f.y + f.h then
                    return win
                end
            end
        end
        return nil
    end

    local function endThrow()
        if not active then return end
        active = false
        if timer then timer:stop(); timer = nil end
        if dir and window then
            local ok, err = pcall(function()
                window:setFrame(zones[dir])
                window:raise()   -- bring it above the other windows at that spot
                window:focus()   -- and make it the active window
            end)
            log("endThrow #%d: dir=%s ok=%s err=%s", count, tostring(dir), tostring(ok), tostring(err))
        else
            log("endThrow #%d: no commit (dir=%s win=%s)", count, tostring(dir), tostring(window))
        end
        dot:hide()
        preview:hide()
        origin, window, dir = nil, nil, nil
    end

    local function tick()
        if not active then return end
        -- Commit the moment Cmd or Option is released (polled, so never missed).
        local mods = hs.eventtap.checkKeyboardModifiers()
        if not (mods.cmd and mods.alt) then
            endThrow()
            return
        end
        local d = pickDirection(hs.mouse.absolutePosition())
        if d ~= dir then
            dir = d
            showPreview(d and zones[d] or nil)
        end
    end

    local function startThrow()
        if active then
            log("startThrow IGNORED: already active (count=%d)", count)
            return
        end
        count = count + 1
        origin = hs.mouse.absolutePosition()
        window = windowUnderPoint(origin)
        if not window then
            log("startThrow #%d: no window under cursor at (%.0f,%.0f)", count, origin.x, origin.y)
            return
        end
        active = true
        dir = nil
        showDot(origin)
        showPreview(nil)
        timer = hs.timer.doEvery(0.02, function()
            local ok, err = pcall(tick)
            if not ok then log("tick ERROR #%d: %s", count, tostring(err)) end
        end)
        log("startThrow #%d: win=[%s]", count, tostring(window:title()))
    end

    -- Activate as soon as Cmd+Option (and nothing else) is held; the timer
    -- commits on release. This also catches release via the flagsChanged event.
    flagsTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(e)
        local ok, err = pcall(function()
            local f = e:getFlags()
            if f.cmd and f.alt and not f.ctrl and not f.shift then
                startThrow()
            elseif active and not (f.cmd and f.alt) then
                endThrow()
            end
        end)
        if not ok then log("flagsTap ERROR: %s", tostring(err)) end
        return false
    end)
    flagsTap:start()
    log("flagsTap started, enabled=%s", tostring(flagsTap:isEnabled()))

    -- Watchdog: macOS will disable an eventtap if a callback ever stalls (the
    -- classic "stops working after a while"). Detect and re-enable it.
    hs.timer.doEvery(1, function()
        if flagsTap and not flagsTap:isEnabled() then
            log("WATCHDOG: flagsTap was DISABLED -- re-enabling")
            flagsTap:start()
        end
    end)

    -- Manual state dump
    hs.hotkey.bind(cfg.mods.debugKey, "d", function()
        log("STATE DUMP: count=%d active=%s timer=%s flagsTapEnabled=%s",
            count, tostring(active), tostring(timer ~= nil),
            tostring(flagsTap and flagsTap:isEnabled()))
    end)
end

return M
