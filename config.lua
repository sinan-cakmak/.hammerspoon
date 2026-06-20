-- Shared configuration for all modules.
-- Tweak values here; modules read from this table so behaviour stays in one place.

return {
    -- Set true to enable file logging (see lib/util.lua -> /tmp/hs.log)
    debug = true,

    -- Accent color used by overlays (azure)
    accent = {red = 0.04, green = 0.52, blue = 1.0},

    -- Modifier combos, named by intent
    mods = {
        move      = {"ctrl", "shift"},          -- move / grow / directional expand
        shrinkDir = {"ctrl", "shift", "alt"},   -- directional shrink
        snap      = {"ctrl", "alt"},            -- half-screen snapping + center
        throw     = {"cmd", "alt"},             -- quick throw (held)
        debugKey  = {"ctrl", "shift", "alt"},   -- diagnostics
    },

    -- Held-arrow move / resize engine
    move = {
        baseStep = 10,
        maxStep  = 30,
        accelRate = 1,
        interval = 0.02,
        minSize  = 100,
    },

    -- Quick throw: target zones captured from window positions (absolute coords).
    --   left = Arc, right = Warp, up = Cursor, down = Conductor
    throw = {
        deadzone = 40,   -- px the cursor must travel before a direction locks in
        animation = 0.08, -- seconds for the drop animation (0 = instant, no glide)
        zones = {
            left  = {x = 0,    y = 30, w = 1069, h = 1410}, -- Arc
            right = {x = 4102, y = 30, w = 1018, h = 1410}, -- Warp
            up    = {x = 1070, y = 30, w = 1509, h = 1410}, -- Cursor
            down  = {x = 2580, y = 30, w = 1521, h = 1410}, -- Conductor
        },
    },
}
