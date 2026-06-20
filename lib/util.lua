-- Shared helpers used across modules.

local cfg = require("config")

local M = {}

-- Build an {r,g,b,a} color table from a base color + alpha.
function M.rgba(c, a)
    return {red = c.red, green = c.green, blue = c.blue, alpha = a}
end

-- Lightweight tagged logger. Prints to the Hammerspoon console and, when
-- cfg.debug is on, appends to /tmp/hs.log so a session can be inspected later.
local logPath = "/tmp/hs.log"
do
    -- Truncate once per reload so each session starts with a clean log.
    local f = io.open(logPath, "w")
    if f then f:close() end
end

function M.logger(tag)
    return function(fmt, ...)
        local ok, line = pcall(string.format, fmt, ...)
        if not ok then line = fmt end
        line = "[" .. tag .. "] " .. line
        print(line)
        if cfg.debug then
            local f = io.open(logPath, "a")
            if f then
                f:write(os.date("%H:%M:%S ") .. line .. "\n")
                f:close()
            end
        end
    end
end

return M
