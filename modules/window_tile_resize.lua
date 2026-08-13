-- Coupled-edge movement and resizing (tiling-style).
--
-- When two windows sit next to each other sharing an edge, dragging that edge
-- to resize one window also resizes the neighbour so the shared seam stays glued
-- together -- like i3 / Magnet's adjacent resize. Moving a window does the same
-- for every neighbour touching any of its edges: neighbours behind the movement
-- shrink and neighbours on the opposite side extend to keep both seams attached.
-- Changes cascade through T-junctions, so two windows that share a common
-- neighbour keep their common seam aligned even when only one is manipulated.
--
-- It works by watching window-moved/resized events. For a resize, an edge drives
-- its neighbours when it moves while its opposite edge stays put. For a move,
-- both parallel edges drive their respective neighbours. Recursion is avoided
-- by recording the frames we set, so the neighbour's own event becomes a no-op.

local cfg      = require("config")
local util     = require("lib.util")
local coupling = require("lib.coupling")

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

    local function frameChanged(a, b)
        return math.abs(a.x - b.x) > DTOL or math.abs(a.y - b.y) > DTOL
            or math.abs(a.w - b.w) > DTOL or math.abs(a.h - b.h) > DTOL
    end

    -- Apply a frame to a neighbour without re-triggering the asynchronous
    -- coupling event. Return the actual before/after frames so this change can
    -- be propagated synchronously to windows that touch the neighbour.
    local function applyNeighbor(win, f)
        if f.w < minSize then f.w = minSize end
        if f.h < minSize then f.h = minSize end
        local old = win:frame()
        win:setFrame(f, 0)               -- 0 = instant, so it tracks the drag
        local new = win:frame()
        frames[win:id()] = new           -- record actual -> its event no-ops
        return old, new
    end

    local function movedEdges(old, new)
        local oldL, oldR, oldT, oldB = old.x, old.x + old.w, old.y, old.y + old.h
        local newL, newR, newT, newB = new.x, new.x + new.w, new.y, new.y + new.h

        -- A one-sided resize moves one edge while its opposite stays put. A move
        -- translates both opposite edges by the same amount, so both sides drive
        -- their touching neighbours. Moving both edges in different directions
        -- (for example a centred resize) remains uncoupled.
        local leftMoved   = math.abs(newL - oldL) > DTOL and math.abs(newR - oldR) <= DTOL
        local rightMoved  = math.abs(newR - oldR) > DTOL and math.abs(newL - oldL) <= DTOL
        local topMoved    = math.abs(newT - oldT) > DTOL and math.abs(newB - oldB) <= DTOL
        local bottomMoved = math.abs(newB - oldB) > DTOL and math.abs(newT - oldT) <= DTOL

        local movedX = math.abs(newL - oldL) > DTOL
            and math.abs(newR - oldR) > DTOL
            and math.abs((newL - oldL) - (newR - oldR)) <= DTOL
        local movedY = math.abs(newT - oldT) > DTOL
            and math.abs(newB - oldB) > DTOL
            and math.abs((newT - oldT) - (newB - oldB)) <= DTOL

        if movedX then leftMoved, rightMoved = true, true end
        if movedY then topMoved, bottomMoved = true, true end

        return {
            left = leftMoved, right = rightMoved,
            top = topMoved, bottom = bottomMoved,
        }
    end

    local function handleFrameChange(win, old, new)
        local sourceId = win:id()

        -- Placement operations such as quick throw explicitly suspend coupling;
        -- direct mouse and held-arrow moves should keep neighbours attached.
        if coupling.isSuspended(sourceId) then return end

        -- A programmatic neighbour update normally no-ops when its delayed event
        -- arrives because `frames` already contains its actual frame. The queue
        -- below performs that propagation now, while every old seam is still
        -- known. This is what carries a change across a T-junction.
        local queue = {{win = win, old = old, new = new}}
        local head = 1

        while head <= #queue do
            local change = queue[head]
            head = head + 1

            local edges = movedEdges(change.old, change.new)
            if not (edges.left or edges.right or edges.top or edges.bottom) then
                -- Nothing in this transition can drive a shared seam.
            else
                local oldL = change.old.x
                local oldR = change.old.x + change.old.w
                local oldT = change.old.y
                local oldB = change.old.y + change.old.h
                local newL = change.new.x
                local newR = change.new.x + change.new.w
                local newT = change.new.y
                local newB = change.new.y + change.new.h

                for _, n in ipairs(hs.window.visibleWindows()) do
                    local nid = n:id()
                    if nid ~= change.win:id() and nid ~= sourceId and n:isStandard() then
                        local nf = n:frame()
                        local nL, nR, nT, nB = nf.x, nf.x + nf.w, nf.y, nf.y + nf.h
                        local changed = false

                        if edges.right and near(nL, oldR) and spanOverlap(oldT, oldB, nT, nB) then
                            nf.x = newR; nf.w = nR - newR; changed = true -- keep neighbour's right
                        end
                        if edges.left and near(nR, oldL) and spanOverlap(oldT, oldB, nT, nB) then
                            nf.w = newL - nL; changed = true              -- keep neighbour's left
                        end
                        if edges.bottom and near(nT, oldB) and spanOverlap(oldL, oldR, nL, nR) then
                            nf.y = newB; nf.h = nB - newB; changed = true -- keep neighbour's bottom
                        end
                        if edges.top and near(nB, oldT) and spanOverlap(oldL, oldR, nL, nR) then
                            nf.h = newT - nT; changed = true              -- keep neighbour's top
                        end

                        if changed and nf.w > 0 and nf.h > 0 then
                            local before, after = applyNeighbor(n, nf)
                            if frameChanged(before, after) then
                                queue[#queue + 1] = {win = n, old = before, new = after}
                            end
                        end
                    end
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
            if old then handleFrameChange(win, old, new) end
        end)
        if not ok then log("error: %s", tostring(err)) end
    end)

    -- Prime the cache so the very first movement event can couple neighbours;
    -- otherwise a fast initial drag could move beyond the edge tolerance before
    -- there is an old frame to compare against.
    for _, win in ipairs(hs.window.visibleWindows()) do
        if win:isStandard() then frames[win:id()] = win:frame() end
    end

    wf:subscribe(hs.window.filter.windowCreated, function(win)
        if win and win:isStandard() then frames[win:id()] = win:frame() end
    end)

    -- Forget windows that close so the frame cache doesn't grow unbounded.
    wf:subscribe(hs.window.filter.windowDestroyed, function(win)
        if win then frames[win:id()] = nil end
    end)

    log("coupled-edge move/resize enabled (tol=%dpx)", adj)
end

return M
