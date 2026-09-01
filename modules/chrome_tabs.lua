-- Chrome vertical-tab navigation.
--
-- Chrome extensions reject Command+Option shortcuts, so Hammerspoon owns the
-- requested keys. Plain traversal is translated to Chrome's native horizontal
-- shortcuts; Shift traversal is forwarded to private, valid extension commands
-- that perform multi-tab selection through chrome.tabs.highlight().

local cfg         = require("config")
local windowThrow = require("modules.window_throw")

local M = {}

local chromeBundleIDs = {
    ["com.google.Chrome"]        = true,
    ["com.google.Chrome.beta"]   = true,
    ["com.google.Chrome.dev"]    = true,
    ["com.google.Chrome.canary"] = true,
}

local function isChrome(app)
    return app and chromeBundleIDs[app:bundleID()] == true
end

local function addingShift(mods)
    local result = {}
    for _, modifier in ipairs(mods) do result[#result + 1] = modifier end
    result[#result + 1] = "shift"
    return result
end

function M.start()
    local hotkeys = {}
    local selectMods = addingShift(cfg.mods.chromeTabs)

    local function sendChromeShortcut(modifiers, key)
        local chrome = hs.application.frontmostApplication()
        if not isChrome(chrome) then return end

        windowThrow.cancel()
        hs.eventtap.keyStroke(modifiers, key, 0, chrome)
    end

    local function bind(modifiers, key, outputModifiers, outputKey)
        local callback = function()
            sendChromeShortcut(outputModifiers, outputKey)
        end
        local hotkey = hs.hotkey.new(modifiers, key, callback, nil, callback)
        hotkeys[#hotkeys + 1] = hotkey
    end

    -- Chrome's native previous/next tab shortcuts.
    bind(cfg.mods.chromeTabs, "Up", cfg.mods.chromeTabs, "Left")
    bind(cfg.mods.chromeTabs, "Down", cfg.mods.chromeTabs, "Right")

    -- Private extension shortcuts declared in manifest.json. Chrome treats Alt
    -- as Option on macOS; PageUp/PageDown keep the bridge bindings unobtrusive.
    bind(selectMods, "Up", {"alt", "shift"}, "PageUp")
    bind(selectMods, "Down", {"alt", "shift"}, "PageDown")

    local function updateHotkeys()
        local enabled = isChrome(hs.application.frontmostApplication())
        for _, hotkey in ipairs(hotkeys) do
            if enabled then hotkey:enable() else hotkey:disable() end
        end
    end

    local watcher = hs.application.watcher.new(function(_, eventType)
        if eventType == hs.application.watcher.activated
            or eventType == hs.application.watcher.deactivated then
            hs.timer.doAfter(0, updateHotkeys)
        end
    end)
    watcher:start()
    updateHotkeys()

    M.hotkeys = hotkeys
    M.watcher = watcher
end

return M
