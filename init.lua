-- Hammerspoon entry point.
-- Keep this file thin: it just loads feature modules. Each module lives in
-- modules/, reads tunables from config.lua, and exposes a start() function.
-- To add a new feature: drop a file in modules/ and list it below.

local modules = {
    "modules.window_move",   -- held-arrow move / resize engine
    "modules.window_snap",   -- half-screen snapping + center
    "modules.window_throw",  -- Cmd+Alt quick throw
    "modules.window_display", -- Ctrl+Alt+Cmd send window between displays
    "modules.window_tile_resize", -- coupled movement/resizing of adjacent windows
    "modules.click_points",  -- Fn+F1 / Fn+F2 click fixed screen spots
    "modules.search_selection", -- search selected text in the default browser
    "modules.finder_vscode", -- open active Finder directory in VS Code
    "modules.spotify_space", -- centered Spotify window on its own Desktop
    "modules.chrome_tabs",   -- Cmd+Alt arrow navigation for Chrome tabs
    "modules.app_control",   -- unminimize, etc.
}

for _, name in ipairs(modules) do
    local ok, mod = pcall(require, name)
    if ok and type(mod) == "table" and mod.start then
        local started, err = pcall(mod.start)
        if not started then
            hs.printf("[init] module '%s' start() failed: %s", name, tostring(err))
        end
    else
        hs.printf("[init] failed to load module '%s': %s", name, tostring(mod))
    end
end

hs.alert.show("Hammerspoon config loaded")
