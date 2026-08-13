-- Search the actively selected text in the default browser.
--
-- Read AXSelectedText where the active application exposes it. Otherwise,
-- trigger Copy and wait for the pasteboard to change. The previous pasteboard
-- is restored with all of its available data types afterward, keeping this
-- shortcut from replacing whatever the user had copied before invoking it.

local cfg  = require("config")
local util = require("lib.util")

local log = util.logger("search")

local M = {}

function M.start()
    local busy = false

    local function normalized(text)
        if type(text) ~= "string" then return nil end
        text = text:match("^%s*(.-)%s*$")
        if text == "" then return nil end
        return text
    end

    local function openSearch(text)
        text = normalized(text)
        if not text then return false end

        local url = "https://www.google.com/search?q=" .. hs.http.encodeForQuery(text)
        if not hs.urlevent.openURL(url) then
            log("failed to open search URL")
        end
        return true
    end

    -- Native text controls often expose their selection directly, avoiding a
    -- synthetic copy and any clipboard timing entirely. Browsers and custom UI
    -- do not always provide AXSelectedText, so Cmd+C remains the fallback.
    local function accessibilitySelection()
        local ok, text = pcall(function()
            local system = hs.axuielement.systemWideElement()
            local focused = system:attributeValue("AXFocusedUIElement")
            return focused and focused:attributeValue("AXSelectedText") or nil
        end)
        return ok and normalized(text) or nil
    end

    local copySelection
    copySelection = function(saved, attempt)
        -- Register the waiter before sending Cmd+C so a very fast application
        -- cannot update the pasteboard before its old change count is captured.
        hs.pasteboard.callbackWhenChanged(0.4, function(changed)
            if not changed and attempt == 1 then
                -- Some applications discard a synthetic copy while the shortcut
                -- chord is settling. Retry internally instead of requiring the
                -- user to press G a second time.
                hs.timer.doAfter(0.05, function() copySelection(saved, 2) end)
                return
            end

            busy = false
            if not changed then
                log("no active text selection")
                return
            end

            local copiedCount = hs.pasteboard.changeCount()
            local text = hs.pasteboard.getContents()

            -- Do not overwrite a clipboard change made elsewhere while this
            -- asynchronous callback was running.
            if hs.pasteboard.changeCount() == copiedCount then
                hs.pasteboard.writeAllData(saved)
            end

            openSearch(text)
        end)

        hs.eventtap.keyStroke({"cmd"}, "c", 0)
    end

    local function searchSelection()
        if busy then return end

        local text = accessibilitySelection()
        if text then
            openSearch(text)
            return
        end

        busy = true
        copySelection(hs.pasteboard.readAllData(), 1)
    end

    -- Start after G is released, so the synthetic Cmd+C cannot be interpreted
    -- as part of the still-active Ctrl+Option+Cmd+G chord.
    hs.hotkey.bind(cfg.mods.search, "g", nil, function()
        hs.timer.doAfter(0.03, searchSelection)
    end)
end

return M
