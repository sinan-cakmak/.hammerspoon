-- === SETTINGS ===
local baseStep = 10
local maxStep = 30
local accelRate = 1
local interval = 0.02
local minSize = 100

-- State trackers
local directions = {up=false, down=false, left=false, right=false}
local actions = {
    grow=false, shrink=false,
    growTop=false, growBottom=false, growLeft=false, growRight=false,
    shrinkTop=false, shrinkBottom=false, shrinkLeft=false, shrinkRight=false
}
local timer = nil
local engine = nil
local step = baseStep

-- Load engine loop from Sounds folder
local soundPath = hs.configdir .. "/Sounds/engine_loop.aiff"

-- Update window movement and resizing
local function updateWindow()
    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:frame()

    -- Movement with acceleration
    if directions.up or directions.down or directions.left or directions.right then
        step = math.min(step + accelRate, maxStep)
    end
    if directions.up    then f.y = f.y - step end
    if directions.down  then f.y = f.y + step end
    if directions.left  then f.x = f.x - step end
    if directions.right then f.x = f.x + step end

    -- Centered resizing
    if actions.grow then
        f.x = f.x - baseStep/2; f.y = f.y - baseStep/2
        f.w = f.w + baseStep; f.h = f.h + baseStep
    end
    if actions.shrink then
        f.x = f.x + baseStep/2; f.y = f.y + baseStep/2
        f.w = math.max(minSize, f.w - baseStep)
        f.h = math.max(minSize, f.h - baseStep)
    end

    -- Directional expanding
    if actions.growTop then
        f.y = f.y - baseStep
        f.h = f.h + baseStep
    end
    if actions.growBottom then
        f.h = f.h + baseStep
    end
    if actions.growLeft then
        f.x = f.x - baseStep
        f.w = f.w + baseStep
    end
    if actions.growRight then
        f.w = f.w + baseStep
    end

    -- Directional shrinking
    if actions.shrinkTop then
        f.y = f.y + baseStep
        f.h = math.max(minSize, f.h - baseStep)
    end
    if actions.shrinkBottom then
        f.h = math.max(minSize, f.h - baseStep)
    end
    if actions.shrinkLeft then
        f.x = f.x + baseStep
        f.w = math.max(minSize, f.w - baseStep)
    end
    if actions.shrinkRight then
        f.w = math.max(minSize, f.w - baseStep)
    end

    win:setFrame(f)
end

-- Start engine sound (only for movement)
local function startEngine()
    if not engine then
        engine = hs.sound.getByFile(soundPath)
        if engine then
            engine:play()
            engine:setFinishedCallback(function()
                if engine then engine:play() end
            end)
        end
    end
end

-- Stop engine
local function stopEngine()
    if engine then
        engine:stop()
        engine = nil
    end
end

-- Start holding action
local function startAction(key)
    if directions[key] ~= nil then
        directions[key] = true
        if not timer then
            step = baseStep
            timer = hs.timer.doEvery(interval, updateWindow)
        end
        startEngine()
    elseif actions[key] ~= nil then
        actions[key] = true
        if not timer then
            timer = hs.timer.doEvery(interval, updateWindow)
        end
    end
end

-- Stop holding action
local function stopAction(key)
    if directions[key] ~= nil then directions[key] = false end
    if actions[key] ~= nil then actions[key] = false end

    if not (directions.up or directions.down or directions.left or directions.right
        or actions.grow or actions.shrink
        or actions.growTop or actions.growBottom or actions.growLeft or actions.growRight
        or actions.shrinkTop or actions.shrinkBottom or actions.shrinkLeft or actions.shrinkRight) then
        if timer then timer:stop(); timer = nil end
        stopEngine()
    elseif not (directions.up or directions.down or directions.left or directions.right) then
        stopEngine()
    end
end

-- Key bindings
local mods      = {"ctrl", "shift"}
local modsCtrl  = {"ctrl", "shift", "alt"}

-- Movement
hs.hotkey.bind(mods, "Up",    function() startAction("up") end,    function() stopAction("up") end)
hs.hotkey.bind(mods, "Down",  function() startAction("down") end,  function() stopAction("down") end)
hs.hotkey.bind(mods, "Left",  function() startAction("left") end,  function() stopAction("left") end)
hs.hotkey.bind(mods, "Right", function() startAction("right") end, function() stopAction("right") end)

-- Centered resizing
hs.hotkey.bind(mods, "-", function() startAction("shrink") end, function() stopAction("shrink") end)
hs.hotkey.bind(mods, "*", function() startAction("grow")   end, function() stopAction("grow") end)

-- Directional expanding
hs.hotkey.bind(mods, "ı", function() startAction("growTop") end,    function() stopAction("growTop") end)
hs.hotkey.bind(mods, "k", function() startAction("growBottom") end, function() stopAction("growBottom") end)
hs.hotkey.bind(mods, "j", function() startAction("growLeft") end,   function() stopAction("growLeft") end)
hs.hotkey.bind(mods, "l", function() startAction("growRight") end,  function() stopAction("growRight") end)

-- Directional shrinking
hs.hotkey.bind(modsCtrl, "ı", function() startAction("shrinkTop") end,    function() stopAction("shrinkTop") end)
hs.hotkey.bind(modsCtrl, "k", function() startAction("shrinkBottom") end, function() stopAction("shrinkBottom") end)
hs.hotkey.bind(modsCtrl, "j", function() startAction("shrinkLeft") end,   function() stopAction("shrinkLeft") end)
hs.hotkey.bind(modsCtrl, "l", function() startAction("shrinkRight") end,  function() stopAction("shrinkRight") end)


-----------------------------------------------------------------
-- Unminimize frontmost app's first minimized window and focus it
local function unminimizeFrontmostApp()
    local app = hs.application.frontmostApplication()
    if app then
        for _, win in ipairs(app:allWindows()) do
            if win:isMinimized() then
                win:unminimize()
                win:focus()
                break
            end
        end
    end
end

hs.hotkey.bind({"cmd", "shift"}, "m", unminimizeFrontmostApp)


-----------------------------------------------------------------
-- Window snapping (Ctrl+Option)
local function snapWindow(position)
    local win = hs.window.focusedWindow()
    if not win then return end
    local screen = win:screen()
    local max = screen:frame()
    local f = {x = max.x, y = max.y, w = max.w, h = max.h}

    if position == "left" then
        f.w = max.w / 2
    elseif position == "right" then
        f.x = max.x + max.w / 2
        f.w = max.w / 2
    elseif position == "up" then
        f.h = max.h / 2
    elseif position == "down" then
        f.y = max.y + max.h / 2
        f.h = max.h / 2
    elseif position == "center" then
        f.w = max.w / 2
        f.h = max.h / 2
        f.x = max.x + max.w / 4
        f.y = max.y + max.h / 4
    end

    win:setFrame(f)
end

local snapMods = {"ctrl", "alt"}
hs.hotkey.bind(snapMods, "Left",  function() snapWindow("left") end)
hs.hotkey.bind(snapMods, "Right", function() snapWindow("right") end)
hs.hotkey.bind(snapMods, "Up",    function() snapWindow("up") end)
hs.hotkey.bind(snapMods, "Down",  function() snapWindow("down") end)
hs.hotkey.bind(snapMods, "c",     function() snapWindow("center") end)


-----------------------------------------------------------------
-- Quick throw: hold Cmd+Option to lock the cursor (red dot), move the
-- mouse in a direction to fling the focused window into a target zone.
-- Zones were captured from these windows' positions (absolute coords):
--   left = Arc, right = Warp, up = Cursor, down = Conductor
local throwZones = {
    left  = {x = 0,    y = 30, w = 1069, h = 1410}, -- Arc
    right = {x = 4102, y = 30, w = 1018, h = 1410}, -- Warp
    up    = {x = 1070, y = 30, w = 1509, h = 1410}, -- Cursor
    down  = {x = 2580, y = 30, w = 1521, h = 1410}, -- Conductor
}

local throwDeadzone = 40   -- px the cursor must travel before a direction locks in

-- === DEBUG LOGGING ===========================================================
-- Appends to /tmp/hs_throw.log so the whole lifecycle can be inspected after a
-- repro. Includes a counter so we can see exactly which throw breaks things.
local throwLogPath = "/tmp/hs_throw.log"
local throwCount = 0
local function tlog(fmt, ...)
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = fmt end
    local f = io.open(throwLogPath, "a")
    if f then
        f:write(os.date("%H:%M:%S ") .. line .. "\n")
        f:close()
    end
    print("[throw] " .. line)
end
do local f = io.open(throwLogPath, "w"); if f then f:close() end end  -- fresh log per reload
tlog("=== init.lua loaded, throw module initialised ===")
-- =============================================================================

local throwActive  = false
local throwOrigin  = nil
local throwWindow  = nil
local throwDir     = nil

-- Persistent overlay canvases, created once and reused (never deleted/recreated
-- per throw, which is what caused Hammerspoon to lag/freeze after a few uses).
--
-- The cursor lock indicator is a small "reticle": a soft halo, a thin accent
-- ring, four directional ticks (hinting the four throw axes), and a glowing core.
local accent = {red = 0.04, green = 0.52, blue = 1.0}  -- azure
local function rgba(c, a)
    return {red = c.red, green = c.green, blue = c.blue, alpha = a}
end

local throwDotSize = 28
local throwDotC = throwDotSize / 2   -- center
local throwDot = hs.canvas.new({x = 0, y = 0, w = throwDotSize, h = throwDotSize})
throwDot:appendElements(
    -- soft white glow
    {
        type = "circle", action = "fill",
        center = {x = throwDotC, y = throwDotC}, radius = 9,
        fillColor = {red = 1, green = 1, blue = 1, alpha = 0.25},
    },
    -- white core
    {
        type = "circle", action = "fill",
        center = {x = throwDotC, y = throwDotC}, radius = 4.5,
        fillColor = {red = 1, green = 1, blue = 1, alpha = 0.98},
    }
)
throwDot:level(hs.canvas.windowLevels.overlay)

local throwPreview = hs.canvas.new({x = 0, y = 0, w = 100, h = 100})
throwPreview[1] = {
    type = "rectangle",
    action = "strokeAndFill",
    fillColor = rgba(accent, 0.18),
    strokeColor = rgba(accent, 0.9),
    strokeWidth = 4,
    roundedRectRadii = {xRadius = 12, yRadius = 12},
}
throwPreview:level(hs.canvas.windowLevels.overlay)

local function showDot(pt)
    throwDot:topLeft({x = pt.x - throwDotC, y = pt.y - throwDotC})
    throwDot:show()
end

local function showPreview(zone)
    if not zone then
        throwPreview:hide()
        return
    end
    throwPreview:frame(zone)
    throwPreview:show()
end

local function pickThrowDirection(pt)
    local dx = pt.x - throwOrigin.x
    local dy = pt.y - throwOrigin.y
    if math.abs(dx) < throwDeadzone and math.abs(dy) < throwDeadzone then
        return nil
    end
    if math.abs(dx) >= math.abs(dy) then
        return dx < 0 and "left" or "right"
    else
        return dy < 0 and "up" or "down"
    end
end

-- While a throw is active this timer both updates the preview and watches the
-- modifier keys, so release is detected reliably (rather than depending on
-- catching the exact flagsChanged event, which could be missed -> stuck throw).
local throwTimer = nil
local throwFlagsTap = nil   -- forward declaration (assigned after startThrow)

-- Topmost visible standard window whose frame contains the given point
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
    if not throwActive then return end
    throwActive = false
    if throwTimer then throwTimer:stop(); throwTimer = nil end
    if throwDir and throwWindow then
        local ok, err = pcall(function()
            throwWindow:setFrame(throwZones[throwDir])
            throwWindow:raise()   -- bring it above the other windows at that spot
            throwWindow:focus()   -- and make it the active window
        end)
        tlog("endThrow #%d: committed dir=%s setFrame_ok=%s err=%s",
            throwCount, tostring(throwDir), tostring(ok), tostring(err))
    else
        tlog("endThrow #%d: no commit (dir=%s win=%s)",
            throwCount, tostring(throwDir), tostring(throwWindow))
    end
    throwDot:hide()
    throwPreview:hide()
    throwOrigin, throwWindow, throwDir = nil, nil, nil
end

local function throwTick()
    if not throwActive then return end
    -- Commit the moment Cmd or Option is released (reliable, polled each tick)
    local mods = hs.eventtap.checkKeyboardModifiers()
    if not (mods.cmd and mods.alt) then
        endThrow()
        return
    end
    local dir = pickThrowDirection(hs.mouse.absolutePosition())
    if dir ~= throwDir then
        throwDir = dir
        showPreview(dir and throwZones[dir] or nil)
    end
end

local function startThrow()
    if throwActive then
        tlog("startThrow IGNORED: already active (count=%d) -- possible stuck state", throwCount)
        return
    end
    throwCount = throwCount + 1
    throwOrigin = hs.mouse.absolutePosition()
    throwWindow = windowUnderPoint(throwOrigin)
    if not throwWindow then
        tlog("startThrow #%d: no window under cursor at (%.0f,%.0f)",
            throwCount, throwOrigin.x, throwOrigin.y)
        return
    end
    throwActive = true
    throwDir = nil
    showDot(throwOrigin)
    showPreview(nil)
    throwTimer = hs.timer.doEvery(0.02, function()
        local ok, err = pcall(throwTick)
        if not ok then tlog("throwTick ERROR #%d: %s", throwCount, tostring(err)) end
    end)
    tlog("startThrow #%d: win=[%s] flagsTapEnabled=%s",
        throwCount, tostring(throwWindow:title()), tostring(throwFlagsTap and throwFlagsTap:isEnabled()))
end

-- Activate as soon as Cmd+Option (and nothing else) is held; the timer commits
-- on release, and this also catches release when the flagsChanged event arrives.
throwFlagsTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(e)
    local ok, err = pcall(function()
        local f = e:getFlags()
        if f.cmd and f.alt and not f.ctrl and not f.shift then
            startThrow()
        elseif throwActive and not (f.cmd and f.alt) then
            endThrow()
        end
    end)
    if not ok then tlog("flagsTap ERROR: %s", tostring(err)) end
    return false
end)
throwFlagsTap:start()
tlog("flagsTap started, enabled=%s", tostring(throwFlagsTap:isEnabled()))

-- Watchdog: if macOS disables the eventtap (the classic cause of "it stops
-- working after a few uses"), log it and re-enable so we can both detect AND
-- recover. Also reports orphaned timers / stuck active state.
local throwWatchdog = hs.timer.doEvery(1, function()
    if throwFlagsTap and not throwFlagsTap:isEnabled() then
        tlog("WATCHDOG: flagsTap was DISABLED (count=%d) -- re-enabling", throwCount)
        throwFlagsTap:start()
    end
end)

-- Manual state dump: Ctrl+Shift+Alt+D
hs.hotkey.bind({"ctrl", "shift", "alt"}, "d", function()
    tlog("STATE DUMP: count=%d active=%s timer=%s flagsTapEnabled=%s",
        throwCount, tostring(throwActive), tostring(throwTimer ~= nil),
        tostring(throwFlagsTap and throwFlagsTap:isEnabled()))
end)