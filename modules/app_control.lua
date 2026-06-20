-- App / window utilities.
--   Cmd+Shift + M -> unminimize the frontmost app's first minimized window

local M = {}

-- Unminimize the frontmost app's first minimized window and focus it.
local function unminimizeFrontmostApp()
    local app = hs.application.frontmostApplication()
    if not app then return end
    for _, win in ipairs(app:allWindows()) do
        if win:isMinimized() then
            win:unminimize()
            win:focus()
            break
        end
    end
end

function M.start()
    hs.hotkey.bind({"cmd", "shift"}, "m", unminimizeFrontmostApp)
end

return M
