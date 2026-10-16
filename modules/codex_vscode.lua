-- Cmd+Option+O opens the selected Codex project's primary source in VS Code.
-- The shortcut is enabled only while the Codex/ChatGPT desktop app is focused.
local cfg = require("config")
local M = {}
local CODEX_BUNDLE_ID = "com.openai.codex"
local STATE_PATH = (os.getenv("CODEX_HOME") or (os.getenv("HOME") .. "/.codex"))
    .. "/.codex-global-state.json"

-- Keep project selection strict: a missing/remote selection must not fall back
-- to an old workspace and open the wrong project.
function M.projectPathFromState(state)
    local selected = type(state) == "table" and state["selected-project"]
    if type(selected) ~= "table" or selected.type ~= "local" then
        return nil, "Select a local Codex project first"
    end
    local projects = state["local-projects"]
    local project = type(projects) == "table" and projects[selected.projectId]
    local roots = type(project) == "table" and project.rootPaths
    local path = type(roots) == "table" and roots[1]
    if type(path) ~= "string" or path:sub(1, 1) ~= "/" then
        return nil, "Could not find the selected project's main folder"
    end
    return path
end

function M.currentProjectPath()
    local file = io.open(STATE_PATH, "r")
    if not file then return nil, "Could not read Codex's project selection" end
    local raw = file:read("*a")
    file:close()
    local ok, state = pcall(hs.json.decode, raw)
    if not ok or type(state) ~= "table" then
        return nil, "Could not read Codex's project selection"
    end
    return M.projectPathFromState(state)
end

local function isCodex(app)
    return app ~= nil and app:bundleID() == CODEX_BUNDLE_ID
end

function M.openProject()
    if not isCodex(hs.application.frontmostApplication()) then return end
    local path, err = M.currentProjectPath()
    if not path then hs.alert.show(err); return end
    if hs.fs.attributes(path, "mode") ~= "directory" then
        hs.alert.show("The Codex project's main folder is unavailable")
        return
    end
    local task
    task = hs.task.new("/usr/bin/open", function(exitCode, _, stderr)
        M.task = nil
        if exitCode ~= 0 then
            hs.alert.show("Could not open the project in Visual Studio Code")
            hs.printf("[codex_vscode] open failed: %s", tostring(stderr))
        end
    end, {"-a", "Visual Studio Code", path})
    M.task = task
    if not task or not task:start() then
        M.task = nil
        hs.alert.show("Could not launch Visual Studio Code")
    end
end

function M.start()
    if M.hotkey then return end
    M.hotkey = hs.hotkey.new(cfg.mods.codexOpenCode or {"cmd", "alt"}, "o", M.openProject)
    local function updateHotkey()
        if isCodex(hs.application.frontmostApplication()) then
            M.hotkey:enable()
        else
            M.hotkey:disable()
        end
    end
    M.watcher = hs.application.watcher.new(function(_, event)
        if event == hs.application.watcher.activated
            or event == hs.application.watcher.deactivated then
            hs.timer.doAfter(0, updateHotkey)
        end
    end)
    M.watcher:start()
    updateHotkey()
end

return M
