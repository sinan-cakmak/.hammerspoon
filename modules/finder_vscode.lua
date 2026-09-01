-- Open the active Finder or Warp directory in Visual Studio Code.
--   Ctrl+Alt+Cmd + V -> open directory (only active in Finder and Warp)

local cfg = require("config")

local M = {}

local WARP_BUNDLE_ID = "dev.warp.Warp-Stable"
local WARP_DATABASE = os.getenv("HOME")
    .. "/Library/Group Containers/2BBY89MBSN.dev.warp/Library/Application Support/"
    .. WARP_BUNDLE_ID
    .. "/warp.sqlite"

-- Warp persists its active window/tab/focused pane and the pane's cwd here.
-- Reading this state avoids typing `code .` into a pane that may be running a
-- server or another foreground process.
local WARP_CWD_QUERY = [[
    WITH ordered_tabs AS (
        SELECT
            id,
            window_id,
            ROW_NUMBER() OVER (PARTITION BY window_id ORDER BY id) - 1 AS tab_index
        FROM tabs
    ),
    active_window AS (
        SELECT COALESCE(
            (SELECT active_window_id FROM app WHERE active_window_id IS NOT NULL LIMIT 1),
            (SELECT id FROM windows ORDER BY id DESC LIMIT 1)
        ) AS id
    )
    SELECT terminal_panes.cwd
    FROM active_window
    JOIN windows ON windows.id = active_window.id
    JOIN ordered_tabs
        ON ordered_tabs.window_id = windows.id
        AND ordered_tabs.tab_index = windows.active_tab_index
    JOIN pane_nodes ON pane_nodes.tab_id = ordered_tabs.id
    JOIN pane_leaves ON pane_leaves.pane_node_id = pane_nodes.id
    JOIN terminal_panes ON terminal_panes.id = pane_nodes.id
    WHERE terminal_panes.cwd IS NOT NULL AND terminal_panes.cwd <> ''
    ORDER BY pane_leaves.is_focused DESC, terminal_panes.is_active DESC, pane_nodes.id
    LIMIT 1;
]]

local function openInVSCode(path)
    if not path or hs.fs.attributes(path, "mode") ~= "directory" then
        hs.alert.show("Could not find the active directory")
        hs.printf("[finder_vscode] Invalid directory: %s", tostring(path))
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

    openInVSCode(path)
end

local function openWarpDirectory()
    local task = hs.task.new(
        "/usr/bin/sqlite3",
        function(exitCode, stdout, stderr)
            local path = stdout and stdout:gsub("[\r\n]+$", "") or ""
            if exitCode ~= 0 or path == "" then
                hs.alert.show("Could not read Warp's active directory")
                hs.printf("[finder_vscode] Warp cwd query failed: %s", tostring(stderr))
                return
            end

            openInVSCode(path)
        end,
        {"-noheader", WARP_DATABASE, WARP_CWD_QUERY}
    )

    if not task or not task:start() then
        hs.alert.show("Could not query Warp's active directory")
    end
end

local function openActiveDirectory()
    local app = hs.application.frontmostApplication()
    local bundleID = app and app:bundleID()

    if bundleID == "com.apple.finder" then
        openFinderDirectory()
    elseif bundleID == WARP_BUNDLE_ID then
        openWarpDirectory()
    end
end

local function updateHotkey(app)
    local bundleID = app and app:bundleID()
    if bundleID == "com.apple.finder" or bundleID == WARP_BUNDLE_ID then
        M.hotkey:enable()
    else
        M.hotkey:disable()
    end
end

function M.start()
    M.hotkey = hs.hotkey.new(cfg.mods.openCode, "v", openActiveDirectory)

    M.watcher = hs.application.watcher.new(function(_, event, app)
        if event == hs.application.watcher.activated then
            updateHotkey(app)
        end
    end)

    M.watcher:start()
    updateHotkey(hs.application.frontmostApplication())
end

return M
