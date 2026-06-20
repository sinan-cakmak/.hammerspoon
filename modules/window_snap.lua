-- Half-screen snapping, corner quarters, and centering.
--   Ctrl+Alt + Left/Right/Up/Down -> fill that half of the screen
--   Ctrl+Alt + U/I/K/L            -> top-left / top-right / bottom-left / bottom-right quarter
--   Ctrl+Alt + D/F/G              -> left / center / right third (full height)
--   Ctrl+Alt + E/T                -> left / right two-thirds (full height)
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
    elseif position == "topleft" then
        f.w = max.w / 2
        f.h = max.h / 2
    elseif position == "topright" then
        f.x = max.x + max.w / 2
        f.w = max.w / 2
        f.h = max.h / 2
    elseif position == "bottomleft" then
        f.y = max.y + max.h / 2
        f.w = max.w / 2
        f.h = max.h / 2
    elseif position == "bottomright" then
        f.x = max.x + max.w / 2
        f.y = max.y + max.h / 2
        f.w = max.w / 2
        f.h = max.h / 2
    elseif position == "leftthird" then
        f.w = max.w / 3
    elseif position == "centerthird" then
        f.x = max.x + max.w / 3
        f.w = max.w / 3
    elseif position == "rightthird" then
        f.x = max.x + max.w * 2 / 3
        f.w = max.w / 3
    elseif position == "lefttwothirds" then
        f.w = max.w * 2 / 3
    elseif position == "righttwothirds" then
        f.x = max.x + max.w / 3
        f.w = max.w * 2 / 3
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

    -- Corner quarters (u/i/k/l form a square matching the screen layout)
    hs.hotkey.bind(mods, "u",     function() snapWindow("topleft") end)
    hs.hotkey.bind(mods, "i",     function() snapWindow("topright") end)
    hs.hotkey.bind(mods, "k",     function() snapWindow("bottomleft") end)
    hs.hotkey.bind(mods, "l",     function() snapWindow("bottomright") end)

    -- Vertical thirds (d/f/g = left / center / right third, full height)
    hs.hotkey.bind(mods, "d",     function() snapWindow("leftthird") end)
    hs.hotkey.bind(mods, "f",     function() snapWindow("centerthird") end)
    hs.hotkey.bind(mods, "g",     function() snapWindow("rightthird") end)

    -- Vertical two-thirds (e/t = left / right two-thirds, full height)
    hs.hotkey.bind(mods, "e",     function() snapWindow("lefttwothirds") end)
    hs.hotkey.bind(mods, "t",     function() snapWindow("righttwothirds") end)
end

return M
