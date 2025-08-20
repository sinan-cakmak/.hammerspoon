-- === SETTINGS ===
local baseStep = 10         -- starting speed
local maxStep = 30          -- max speed
local accelRate = 1         -- pixels added per tick
local interval = 0.02
local minSize = 100

-- State trackers
local directions = {up=false, down=false, left=false, right=false}
local actions = {grow=false, shrink=false}
local timer = nil
local engine = nil
local step = baseStep       -- dynamic step that accelerates

-- Load engine loop from Sounds folder
local soundPath = hs.configdir .. "/Sounds/engine_loop.aiff"

-- Update window movement and resizing
local function updateWindow()
    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:frame()

    -- Movement
    if directions.up or directions.down or directions.left or directions.right then
        -- Accelerate a little each tick while moving
        step = math.min(step + accelRate, maxStep)
    end

    if directions.up    then f.y = f.y - step end
    if directions.down  then f.y = f.y + step end
    if directions.left  then f.x = f.x - step end
    if directions.right then f.x = f.x + step end

    -- Resizing (no sound, no acceleration)
    if actions.grow then
        f.x = f.x - baseStep/2; f.y = f.y - baseStep/2
        f.w = f.w + baseStep; f.h = f.h + baseStep
    end
    if actions.shrink then
        f.x = f.x + baseStep/2; f.y = f.y + baseStep/2
        f.w = math.max(minSize, f.w - baseStep)
        f.h = math.max(minSize, f.h - baseStep)
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
        -- Only start engine if moving (not resizing)
        if not timer then
            step = baseStep
            timer = hs.timer.doEvery(interval, updateWindow)
            startEngine()
        end
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

    if not (directions.up or directions.down or directions.left or directions.right or actions.grow or actions.shrink) then
        if timer then timer:stop(); timer = nil end
        stopEngine()
    elseif not (directions.up or directions.down or directions.left or directions.right) then
        -- if only resizing is active, stop engine but keep timer
        stopEngine()
    end
end

-- Key bindings
local mods = {"cmd", "alt"}

-- Movement
hs.hotkey.bind(mods, "Up",    function() startAction("up") end,    function() stopAction("up") end)
hs.hotkey.bind(mods, "Down",  function() startAction("down") end,  function() stopAction("down") end)
hs.hotkey.bind(mods, "Left",  function() startAction("left") end,  function() stopAction("left") end)
hs.hotkey.bind(mods, "Right", function() startAction("right") end, function() stopAction("right") end)

-- Resizing (silent)
hs.hotkey.bind(mods, "-", function() startAction("shrink") end, function() stopAction("shrink") end)
hs.hotkey.bind(mods, "*", function() startAction("grow")   end, function() stopAction("grow") end)