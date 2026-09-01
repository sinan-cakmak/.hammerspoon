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
        chromeTabs = {"cmd", "alt"},            -- Chrome tab traversal bridge
        display   = {"ctrl", "alt", "cmd"},     -- send window to another display
        search    = {"ctrl", "alt", "cmd"},     -- search selected text
        openCode  = {"ctrl", "alt", "cmd"},     -- open active directory in VS Code
        debugKey  = {"ctrl", "shift", "alt"},   -- diagnostics
    },

    -- Held-arrow move / resize engine
    move = {
        baseStep = 10,
        maxStep  = 30,
        accelRate = 1,
        interval = 0.02,
        minSize  = 100,
        -- Magnetic snapping while moving (Ctrl+Shift + arrows): when a window
        -- edge comes within this many px of another window's edge or a screen
        -- edge, it snaps flush. Keep pushing to break free. 0 disables.
        snapDistance = 24,
    },

    -- Hotkeys that click a fixed spot on screen (see modules/click_points.lua).
    --
    -- Points are stored as FRACTIONS of the main display (rx/ry, 0-1) rather
    -- than pixels, so they survive a change of resolution. They are still only
    -- as good as the display they were measured on -- a layout that is centered
    -- and letterboxed (like a fullscreen web app) shifts when the aspect ratio
    -- changes. Calibrate on the target machine with the calibrate hotkey, which
    -- prints the exact rx/ry under the cursor.
    --
    -- Set `x`/`y` on a point instead to pin it to absolute coordinates.
    clicks = {
        restoreCursor = true,  -- put the pointer back where it was after clicking
        points = {
            -- The two table tabs in the top-left toolbar, left then right. Same
            -- height (ry), different horizontal offset (rx).
            -- Measured off a 1280x800 screenshot -- CALIBRATE BEFORE RELYING ON THESE.
            f1 = {rx = 0.0516, ry = 0.1413},  -- left tab
            f2 = {rx = 0.0969, ry = 0.1413},  -- right tab
        },
    },

    -- Coupled edges: when you resize or move a window, every neighbouring
    -- window sharing one of its edges resizes to keep the common seam glued;
    -- this propagates through common neighbours at T-junctions.
    tile = {
        enabled = true,
        edgeTolerance = 12,  -- px gap still treated as a shared edge
        minSize = 80,        -- don't shrink a neighbour below this
    },

    -- Quick throw. Zones are grouped into per-display profiles: a throw only
    -- activates when the screen under the cursor matches a profile's resolution.
    -- This keeps the setup specific to the display it was designed for; add more
    -- profiles for other monitors later. Zones are absolute screen coordinates.
    throw = {
        deadzone = 40,   -- px the cursor must travel before a direction locks in
        animation = 0,   -- seconds for the drop animation (0 = instant, no glide)
        profiles = {
            {
                name = "ultrawide 32:9 (5120x1440)",
                screen = {w = 5120, h = 1440},  -- full display resolution to match
                zones = {
                    -- Cardinal directions
                    left  = {x = 0,    y = 30, w = 1069, h = 1410}, -- Arc (full height)
                    right = {x = 4102, y = 30, w = 1018, h = 1410}, -- Warp
                    up    = {x = 1070, y = 30, w = 1509, h = 1410}, -- Cursor
                    down  = {x = 2580, y = 30, w = 1521, h = 1410}, -- Conductor
                    -- Diagonal directions (corners)
                    topleft     = {x = 0,    y = 30,  w = 1069, h = 710}, -- Arc
                    bottomleft  = {x = 0,    y = 740, w = 1069, h = 700}, -- Slack
                    topright    = {x = 4102, y = 30,  w = 1018, h = 701}, -- WhatsApp
                    bottomright = {x = 4102, y = 731, w = 1018, h = 709}, -- Ghostty
                },
            },
        },
    },
}
