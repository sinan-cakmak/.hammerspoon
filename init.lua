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