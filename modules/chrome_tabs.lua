-- Chrome tab navigation for vertical-tab layouts.
--   Cmd+Option + Up   -> previous tab
--   Cmd+Option + Down -> next tab

local cfg         = require("config")
local windowThrow = require("modules.window_throw")

local M = {}

-- Cover the regular release as well as the common Chrome preview channels.
local chromeBundleIDs = {
    ["com.google.Chrome"]        = true,
    ["com.google.Chrome.beta"]   = true,
    ["com.google.Chrome.dev"]    = true,
    ["com.google.Chrome.canary"] = true,
}

local function isChrome(app)
    return app and chromeBundleIDs[app:bundleID()] == true
end

function M.start()
    local hotkeys = {}

    local function selectTab(direction)
        local chrome = hs.application.frontmostApplication()
        if not isChrome(chrome) then return end

        -- Cmd+Option also arms quick throw. Cancel it before translating the
        -- vertical arrow to Chrome's native previous/next-tab shortcut.
        windowThrow.cancel()
        hs.eventtap.keyStroke(cfg.mods.chromeTabs, direction, 0, chrome)
    end

    local function bind(key, direction)
        local callback = function() selectTab(direction) end
        local hotkey = hs.hotkey.new(cfg.mods.chromeTabs, key, callback, nil, callback)
        hotkeys[#hotkeys + 1] = hotkey
    end

    bind("Up", "Left")
    bind("Down", "Right")

    local function updateHotkeys()
        local enabled = isChrome(hs.application.frontmostApplication())
        for _, hotkey in ipairs(hotkeys) do
            if enabled then hotkey:enable() else hotkey:disable() end
        end
    end

    -- Keep the bindings disabled outside Chrome so Cmd+Option+Up/Down remain
    -- available to macOS and other apps.
    local watcher = hs.application.watcher.new(function(_, eventType)
        if eventType == hs.application.watcher.activated
            or eventType == hs.application.watcher.deactivated then
            hs.timer.doAfter(0, updateHotkeys)
        end
    end)
    watcher:start()
    updateHotkeys()

    -- Retain these objects for the lifetime of the Hammerspoon config.
    M.hotkeys = hotkeys
    M.watcher = watcher
end

return M
