-- Open the front Finder window's directory in Visual Studio Code.
--   Ctrl+Alt+Cmd + V -> open directory (only active while Finder is frontmost)

local cfg = require("config")

local M = {}

local function openFinderDirectory()
    local ok, path, err = hs.osascript.applescript([[
        tell application "Finder"
            if (count of windows) > 0 then
                set targetFolder to (target of front window) as alias
            else
                set targetFolder to (path to desktop) as alias
            end if
        end tell
        return POSIX path of targetFolder
    ]])

    if not ok or not path then
        hs.alert.show("Could not read the Finder directory")
        hs.printf("[finder_vscode] AppleScript failed: %s", tostring(err))
        return
    end

    local task = hs.task.new(
        "/usr/bin/open",
        function(exitCode, _, stderr)
            if exitCode ~= 0 then
                hs.alert.show("Could not open Visual Studio Code")
                hs.printf("[finder_vscode] open failed: %s", tostring(stderr))
            end
        end,
        {"-a", "Visual Studio Code", path}
    )

    if not task or not task:start() then
        hs.alert.show("Could not launch Visual Studio Code")
    end
end

local function updateHotkey(app)
    if app and app:bundleID() == "com.apple.finder" then
        M.hotkey:enable()
    else
        M.hotkey:disable()
    end
end

function M.start()
    M.hotkey = hs.hotkey.new(cfg.mods.finder, "v", openFinderDirectory)

    M.watcher = hs.application.watcher.new(function(_, event, app)
        if event == hs.application.watcher.activated then
            updateHotkey(app)
        end
    end)

    M.watcher:start()
    updateHotkey(hs.application.frontmostApplication())
end

return M
