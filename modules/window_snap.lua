-- Half-screen snapping and centering.
--   Ctrl+Alt + Left/Right/Up/Down -> fill that half of the screen
--   Ctrl+Alt + C                  -> recenter (keeps current size)

local cfg = require("config")

local M = {}

local function snapWindow(position)
    local win = hs.window.focusedWindow()
    if not win then return end
    local max = win:screen():frame()
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
        -- Keep the window's current size; just recenter it on the screen
        local cur = win:frame()
        f.w = cur.w
        f.h = cur.h
        f.x = max.x + (max.w - cur.w) / 2
        f.y = max.y + (max.h - cur.h) / 2
    end

    win:setFrame(f)
end

function M.start()
    local mods = cfg.mods.snap
    hs.hotkey.bind(mods, "Left",  function() snapWindow("left") end)
    hs.hotkey.bind(mods, "Right", function() snapWindow("right") end)
    hs.hotkey.bind(mods, "Up",    function() snapWindow("up") end)
    hs.hotkey.bind(mods, "Down",  function() snapWindow("down") end)
    hs.hotkey.bind(mods, "c",     function() snapWindow("center") end)
end

return M
