-- Hammerspoon entry point.
-- Keep this file thin: it just loads feature modules. Each module lives in
-- modules/, reads tunables from config.lua, and exposes a start() function.
-- To add a new feature: drop a file in modules/ and list it below.

local modules = {
    "modules.window_move",   -- held-arrow move / resize engine
    "modules.window_snap",   -- half-screen snapping + center
    "modules.window_throw",  -- Cmd+Alt quick throw
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
