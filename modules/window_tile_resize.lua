-- Paired-edge resizing (tiling-style).
--
-- When two windows sit next to each other sharing an edge, dragging that edge
-- to resize one window also resizes the neighbour so the shared seam stays glued
-- together -- like i3 / Magnet's adjacent resize.
--
-- It works by watching window-moved/resized events: when exactly one edge of a
-- window moves (a pure move, where both opposite edges shift, is ignored), any
-- window whose opposite edge was touching it (within a tolerance) and overlaps
-- along that side has its shared edge moved to follow. Recursion is avoided by
-- recording the frames we set, so the neighbour's own event becomes a no-op.

local cfg  = require("config")
local util = require("lib.util")

local log = util.logger("tile")

local M = {}

function M.start()
    local conf = cfg.tile or {}
    if conf.enabled == false then return end

    local adj     = conf.edgeTolerance or 12  -- px: still "touching"
    local minSize = conf.minSize or 80
    local DTOL    = 2                          -- px: ignore sub-pixel jitter

    local frames = {}  -- winId -> last known frame

    local function near(a, b) return math.abs(a - b) <= adj end

    -- Do the two 1-D spans [a1,a2] and [b1,b2] overlap (with real overlap > 0)?
    local function spanOverlap(a1, a2, b1, b2)
        return math.min(a2, b2) - math.max(a1, b1) > 0
    end

    -- Apply a frame to a neighbour without re-triggering the coupling.
    local function applyNeighbor(win, f)
        if f.w < minSize then f.w = minSize end
        if f.h < minSize then f.h = minSize end
        win:setFrame(f, 0)               -- 0 = instant, so it tracks the drag
        frames[win:id()] = win:frame()   -- record actual -> its event no-ops
    end

    local function handleResize(win, old, new)
        local id = win:id()
        local oldL, oldR, oldT, oldB = old.x, old.x + old.w, old.y, old.y + old.h
        local newL, newR, newT, newB = new.x, new.x + new.w, new.y, new.y + new.h

        -- An edge "resized" only if it moved while its opposite edge stayed put.
        -- (If both opposite edges move together, that's a drag/move -> ignore.)
        local leftMoved   = math.abs(newL - oldL) > DTOL and math.abs(newR - oldR) <= DTOL
        local rightMoved  = math.abs(newR - oldR) > DTOL and math.abs(newL - oldL) <= DTOL
        local topMoved    = math.abs(newT - oldT) > DTOL and math.abs(newB - oldB) <= DTOL
        local bottomMoved = math.abs(newB - oldB) > DTOL and math.abs(newT - oldT) <= DTOL

        if not (leftMoved or rightMoved or topMoved or bottomMoved) then return end

        for _, n in ipairs(hs.window.visibleWindows()) do
            if n:id() ~= id and n:isStandard() then
                local nf = n:frame()
                local nL, nR, nT, nB = nf.x, nf.x + nf.w, nf.y, nf.y + nf.h
                local changed = false

                if rightMoved and near(nL, oldR) and spanOverlap(oldT, oldB, nT, nB) then
                    nf.x = newR; nf.w = nR - newR; changed = true   -- keep neighbour's right
                end
                if leftMoved and near(nR, oldL) and spanOverlap(oldT, oldB, nT, nB) then
                    nf.w = newL - nL; changed = true                -- keep neighbour's left
                end
                if bottomMoved and near(nT, oldB) and spanOverlap(oldL, oldR, nL, nR) then
                    nf.y = newB; nf.h = nB - newB; changed = true   -- keep neighbour's bottom
                end
                if topMoved and near(nB, oldT) and spanOverlap(oldL, oldR, nL, nR) then
                    nf.h = newT - nT; changed = true                -- keep neighbour's top
                end

                if changed and nf.w > 0 and nf.h > 0 then
                    applyNeighbor(n, nf)
                end
            end
        end
    end

    -- Watch every window for move/resize events.
    local wf = hs.window.filter.new(true)
    wf:subscribe(hs.window.filter.windowMoved, function(win)
        if not win then return end
        local ok, err = pcall(function()
            local id = win:id()
            local new = win:frame()
            local old = frames[id]
            frames[id] = new
            if old then handleResize(win, old, new) end
        end)
        if not ok then log("error: %s", tostring(err)) end
    end)

    -- Forget windows that close so the frame cache doesn't grow unbounded.
    wf:subscribe(hs.window.filter.windowDestroyed, function(win)
        if win then frames[win:id()] = nil end
    end)

    log("paired-edge resize enabled (tol=%dpx)", adj)
end

return M
