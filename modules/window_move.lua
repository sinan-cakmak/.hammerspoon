-- Held-arrow window movement and resizing, with acceleration.
--   Move:               Ctrl+Shift + Arrows  (magnetically snaps to nearby
--                       window/screen edges; keep pushing to break free)
--   Centered resize:    Ctrl+Shift + (-)  /  (*)
--   Directional expand: Ctrl+Shift + ı/k/j/l   (top/bottom/left/right)
--   Directional shrink: Ctrl+Shift+Alt + ı/k/j/l
--   (the dragged edge also magnetically snaps to nearby window/screen edges)

local cfg = require("config")

local M = {}

function M.start()
    local s = cfg.move
    local baseStep, maxStep, accelRate, interval, minSize =
        s.baseStep, s.maxStep, s.accelRate, s.interval, s.minSize
    local snapDist = s.snapDistance or 0

    local directions = {up = false, down = false, left = false, right = false}
    local actions = {
        grow = false, shrink = false,
        growTop = false, growBottom = false, growLeft = false, growRight = false,
        shrinkTop = false, shrinkBottom = false, shrinkLeft = false, shrinkRight = false,
    }
    local timer = nil
    local step = baseStep

    -- Magnetic snapping state. `virtual` holds the raw, unsnapped frame that
    -- the keypresses accumulate into; the window is shown a snapped copy. This
    -- separation lets a window stick to an edge yet break free once the raw
    -- movement has travelled past the snap distance. `snapCtx` caches the
    -- neighbour/screen edges for the duration of one drive gesture. `lastSet`
    -- is what we last asked the window to be, used to notice external moves.
    local virtual  = nil   -- {id = winId, f = frame}
    local snapCtx  = nil   -- {others = {frames}, screen = frame}
    local lastSet  = nil   -- frame we last applied

    local function captureSnapCtx(win)
        local others, id = {}, win:id()
        for _, n in ipairs(hs.window.visibleWindows()) do
            if n:id() ~= id and n:isStandard() then
                others[#others + 1] = n:frame()
            end
        end
        snapCtx = {others = others, screen = win:screen():frame()}
    end

    -- Do the 1-D spans [a1,a2] and [b1,b2] genuinely overlap?
    local function spanOverlap(a1, a2, b1, b2)
        return math.min(a2, b2) - math.max(a1, b1) > 0
    end

    -- Pull frame `f`'s edges toward the nearest neighbour/screen edge within
    -- snapDist, independently per axis. Only neighbours that overlap on the
    -- perpendicular axis are considered, so we snap to windows actually beside us.
    local function applySnap(f)
        if not snapCtx or snapDist <= 0 then return end
        local L, R, T, B = f.x, f.x + f.w, f.y, f.y + f.h
        local sc = snapCtx.screen

        -- Horizontal: adjust f.x.
        local bestD, bestAbs = 0, snapDist + 1
        local function considerX(target, edge)
            local d = target - edge
            local a = d < 0 and -d or d
            if a < bestAbs then bestAbs, bestD = a, d end
        end
        considerX(sc.x, L)              -- left edge to screen left
        considerX(sc.x + sc.w, R)       -- right edge to screen right
        for _, nf in ipairs(snapCtx.others) do
            if spanOverlap(T, B, nf.y, nf.y + nf.h) then
                local nL, nR = nf.x, nf.x + nf.w
                considerX(nR, L)        -- our left flush to their right
                considerX(nL, R)        -- our right flush to their left
                considerX(nL, L)        -- align left edges
                considerX(nR, R)        -- align right edges
            end
        end
        if bestAbs <= snapDist then f.x = f.x + bestD end

        -- Vertical: adjust f.y.
        bestD, bestAbs = 0, snapDist + 1
        local function considerY(target, edge)
            local d = target - edge
            local a = d < 0 and -d or d
            if a < bestAbs then bestAbs, bestD = a, d end
        end
        considerY(sc.y, T)              -- top edge to screen top
        considerY(sc.y + sc.h, B)       -- bottom edge to screen bottom
        for _, nf in ipairs(snapCtx.others) do
            if spanOverlap(L, R, nf.x, nf.x + nf.w) then
                local nT, nB = nf.y, nf.y + nf.h
                considerY(nB, T)        -- our top flush to their bottom
                considerY(nT, B)        -- our bottom flush to their top
                considerY(nT, T)        -- align top edges
                considerY(nB, B)        -- align bottom edges
            end
        end
        if bestAbs <= snapDist then f.y = f.y + bestD end
    end

    -- Nearest of `candidates` to `edgeVal` within snapDist; returns the delta
    -- to add to that edge, or nil if nothing is close enough.
    local function snapEdge(edgeVal, candidates)
        local bestD, bestAbs = nil, snapDist + 1
        for _, t in ipairs(candidates) do
            local d = t - edgeVal
            local a = d < 0 and -d or d
            if a < bestAbs then bestAbs, bestD = a, d end
        end
        if bestAbs <= snapDist then return bestD end
        return nil
    end

    -- Snap only the edge(s) currently being dragged by a directional resize to
    -- nearby neighbour/screen edges. `edges` flags which of top/bottom/left/right
    -- are moving. Like the move snap, this runs on the displayed copy while the
    -- raw `virtual` frame keeps accumulating, so the edge can break past.
    local function applyResizeSnap(f, edges)
        if not snapCtx or snapDist <= 0 then return end
        local sc = snapCtx.screen
        local L, R, T, B = f.x, f.x + f.w, f.y, f.y + f.h

        if edges.left then
            local cands = {sc.x}
            for _, nf in ipairs(snapCtx.others) do
                if spanOverlap(T, B, nf.y, nf.y + nf.h) then
                    cands[#cands + 1] = nf.x; cands[#cands + 1] = nf.x + nf.w
                end
            end
            local d = snapEdge(L, cands)
            if d then f.x = f.x + d; f.w = f.w - d end
        end
        if edges.right then
            local cands = {sc.x + sc.w}
            for _, nf in ipairs(snapCtx.others) do
                if spanOverlap(T, B, nf.y, nf.y + nf.h) then
                    cands[#cands + 1] = nf.x; cands[#cands + 1] = nf.x + nf.w
                end
            end
            local d = snapEdge(R, cands)
            if d then f.w = f.w + d end
        end
        if edges.top then
            local cands = {sc.y}
            for _, nf in ipairs(snapCtx.others) do
                if spanOverlap(L, R, nf.x, nf.x + nf.w) then
                    cands[#cands + 1] = nf.y; cands[#cands + 1] = nf.y + nf.h
                end
            end
            local d = snapEdge(T, cands)
            if d then f.y = f.y + d; f.h = f.h - d end
        end
        if edges.bottom then
            local cands = {sc.y + sc.h}
            for _, nf in ipairs(snapCtx.others) do
                if spanOverlap(L, R, nf.x, nf.x + nf.w) then
                    cands[#cands + 1] = nf.y; cands[#cands + 1] = nf.y + nf.h
                end
            end
            local d = snapEdge(B, cands)
            if d then f.h = f.h + d end
        end

        if f.w < minSize then f.w = minSize end
        if f.h < minSize then f.h = minSize end
    end

    local function updateWindow()
        local win = hs.window.focusedWindow()
        if not win then return end
        local live = win:frame()

        -- Sync the virtual frame to the live window when focus changes or the
        -- window moved by some other means since we last set it (e.g. a throw).
        if not virtual or virtual.id ~= win:id() then
            virtual = {id = win:id(), f = {x = live.x, y = live.y, w = live.w, h = live.h}}
        elseif lastSet and (math.abs(live.x - lastSet.x) > 2 or math.abs(live.y - lastSet.y) > 2
                         or math.abs(live.w - lastSet.w) > 2 or math.abs(live.h - lastSet.h) > 2) then
            virtual.f = {x = live.x, y = live.y, w = live.w, h = live.h}
        end

        local f = virtual.f
        local moving = directions.up or directions.down or directions.left or directions.right

        -- Movement with acceleration
        if moving then
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

        -- Show a snapped copy; the raw `virtual` frame keeps the true geometry
        -- so the window/edge can break past the magnet. Movement snaps the whole
        -- frame's position; a directional resize snaps only the dragged edge(s).
        local out = {x = f.x, y = f.y, w = f.w, h = f.h}
        if moving then
            applySnap(out)
        else
            local edges = {
                top    = actions.growTop    or actions.shrinkTop,
                bottom = actions.growBottom or actions.shrinkBottom,
                left   = actions.growLeft   or actions.shrinkLeft,
                right  = actions.growRight  or actions.shrinkRight,
            }
            if edges.top or edges.bottom or edges.left or edges.right then
                applyResizeSnap(out, edges)
            end
        end
        win:setFrame(out)
        lastSet = win:frame()
    end

    local function anyActive()
        for _, v in pairs(directions) do if v then return true end end
        for _, v in pairs(actions) do if v then return true end end
        return false
    end

    -- Snapshot neighbour/screen edges once, when a gesture begins.
    local function beginGesture()
        if timer then return end
        local win = hs.window.focusedWindow()
        if win then captureSnapCtx(win) end
        timer = hs.timer.doEvery(interval, updateWindow)
    end

    local function startAction(key)
        if directions[key] ~= nil then
            directions[key] = true
            if not timer then step = baseStep end
            beginGesture()
        elseif actions[key] ~= nil then
            actions[key] = true
            beginGesture()
        end
    end

    local function stopAction(key)
        if directions[key] ~= nil then directions[key] = false end
        if actions[key] ~= nil then actions[key] = false end
        if not anyActive() and timer then
            timer:stop(); timer = nil
            -- Drop per-gesture snapping state so the next drive starts fresh.
            virtual, snapCtx, lastSet = nil, nil, nil
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
