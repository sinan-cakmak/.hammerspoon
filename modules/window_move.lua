-- Held-arrow window movement and resizing, with acceleration.
--   Move:               Ctrl+Shift + Arrows
--   Centered resize:    Ctrl+Shift + (-)  /  (*)
--   Directional expand: Ctrl+Shift + ı/k/j/l   (top/bottom/left/right)
--   Directional shrink: Ctrl+Shift+Alt + ı/k/j/l

local cfg = require("config")

local M = {}

function M.start()
    local s = cfg.move
    local baseStep, maxStep, accelRate, interval, minSize =
        s.baseStep, s.maxStep, s.accelRate, s.interval, s.minSize

    local directions = {up = false, down = false, left = false, right = false}
    local actions = {
        grow = false, shrink = false,
        growTop = false, growBottom = false, growLeft = false, growRight = false,
        shrinkTop = false, shrinkBottom = false, shrinkLeft = false, shrinkRight = false,
    }
    local timer = nil
    local step = baseStep

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
            f.x = f.x - baseStep / 2; f.y = f.y - baseStep / 2
            f.w = f.w + baseStep; f.h = f.h + baseStep
        end
        if actions.shrink then
            f.x = f.x + baseStep / 2; f.y = f.y + baseStep / 2
            f.w = math.max(minSize, f.w - baseStep)
            f.h = math.max(minSize, f.h - baseStep)
        end

        -- Directional expanding
        if actions.growTop    then f.y = f.y - baseStep; f.h = f.h + baseStep end
        if actions.growBottom then f.h = f.h + baseStep end
        if actions.growLeft   then f.x = f.x - baseStep; f.w = f.w + baseStep end
        if actions.growRight  then f.w = f.w + baseStep end

        -- Directional shrinking
        if actions.shrinkTop    then f.y = f.y + baseStep; f.h = math.max(minSize, f.h - baseStep) end
        if actions.shrinkBottom then f.h = math.max(minSize, f.h - baseStep) end
        if actions.shrinkLeft   then f.x = f.x + baseStep; f.w = math.max(minSize, f.w - baseStep) end
        if actions.shrinkRight  then f.w = math.max(minSize, f.w - baseStep) end

        win:setFrame(f)
    end

    local function anyActive()
        for _, v in pairs(directions) do if v then return true end end
        for _, v in pairs(actions) do if v then return true end end
        return false
    end

    local function startAction(key)
        if directions[key] ~= nil then
            directions[key] = true
            if not timer then
                step = baseStep
                timer = hs.timer.doEvery(interval, updateWindow)
            end
        elseif actions[key] ~= nil then
            actions[key] = true
            if not timer then
                timer = hs.timer.doEvery(interval, updateWindow)
            end
        end
    end

    local function stopAction(key)
        if directions[key] ~= nil then directions[key] = false end
        if actions[key] ~= nil then actions[key] = false end
        if not anyActive() and timer then
            timer:stop(); timer = nil
        end
    end

    -- Bind a press/release pair that drives one action key.
    local function bindHold(mods, hotkey, action)
        hs.hotkey.bind(mods,
            hotkey,
            function() startAction(action) end,
            function() stopAction(action) end)
    end

    local move      = cfg.mods.move
    local shrinkDir = cfg.mods.shrinkDir

    -- Movement
    bindHold(move, "Up",    "up")
    bindHold(move, "Down",  "down")
    bindHold(move, "Left",  "left")
    bindHold(move, "Right", "right")

    -- Centered resizing
    bindHold(move, "-", "shrink")
    bindHold(move, "*", "grow")

    -- Directional expanding (ı/k/j/l = top/bottom/left/right)
    bindHold(move, "ı", "growTop")
    bindHold(move, "k", "growBottom")
    bindHold(move, "j", "growLeft")
    bindHold(move, "l", "growRight")

    -- Directional shrinking
    bindHold(shrinkDir, "ı", "shrinkTop")
    bindHold(shrinkDir, "k", "shrinkBottom")
    bindHold(shrinkDir, "j", "shrinkLeft")
    bindHold(shrinkDir, "l", "shrinkRight")
end

return M
