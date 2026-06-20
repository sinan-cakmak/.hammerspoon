-- Shared, short-lived suppression flag for paired-edge resizing.
--
-- Programmatic frame changes (e.g. quick throw) fire the same windowMoved
-- events as a manual drag, which would make the tile-resize module drag
-- neighbours along. Before such a change, the mover calls suspend(winId); the
-- tile module checks isSuspended(winId) and skips coupling for that window.
--
-- It is time-based because the windowMoved events arrive asynchronously, a
-- little after the setFrame call that triggered them.

local M = {}

local expiry = {}     -- winId -> time after which suppression lapses
local DEFAULT = 0.7   -- seconds

function M.suspend(winId, dur)
    if not winId then return end
    expiry[winId] = hs.timer.secondsSinceEpoch() + (dur or DEFAULT)
end

function M.isSuspended(winId)
    local t = expiry[winId]
    if not t then return false end
    if hs.timer.secondsSinceEpoch() > t then
        expiry[winId] = nil
        return false
    end
    return true
end

return M
