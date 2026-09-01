-- Give Spotify a fullscreen-like Space without making its window fullscreen.
--   Fn + F              -> enter/leave Spotify's centered Space
--   Ctrl + Cmd + F      -> same behavior (legacy macOS fullscreen shortcut)

local spaces = require("hs.spaces")
local coupling = require("lib.coupling")

local SETTINGS_KEY = "spotify_space.session"
local MOVE_HELPER = hs.configdir .. "/bin/move-window-to-space"
local savedSession = hs.settings.get(SETTINGS_KEY)

local M = {
    session = type(savedSession) == "table" and savedSession or {},
    busy = false,
}

local SPOTIFY_BUNDLE_ID = "com.spotify.client"
local SETTLE_DELAY = 0.7
local SPACE_POLL_DELAY = 0.1
local SPACE_POLL_ATTEMPTS = 20

local function logError(message, detail)
    hs.alert.show(message)
    hs.printf("[spotify_space] %s: %s", message, tostring(detail))
end

local function isSpotify(app)
    return app and app:bundleID() == SPOTIFY_BUNDLE_ID
end

local function saveSession()
    hs.settings.set(SETTINGS_KEY, M.session)
end

local function windowID(win)
    if not win then return nil end
    local ok, id = pcall(function() return win:id() end)
    return ok and id or nil
end

local function contains(list, wanted)
    for _, value in ipairs(list or {}) do
        if value == wanted then return true end
    end
    return false
end

local function spaceExists(spaceID)
    if not spaceID then return false end
    local ok, spaceType = pcall(spaces.spaceType, spaceID)
    return ok and spaceType == "user"
end

local function centeredFrame(size, screen)
    local bounds = screen:frame()
    local width = math.min(size.w, bounds.w)
    local height = math.min(size.h, bounds.h)

    return {
        x = bounds.x + (bounds.w - width) / 2,
        y = bounds.y + (bounds.h - height) / 2,
        w = width,
        h = height,
    }
end

-- Keep the exact window size when it fits. On a smaller display, shrink only
-- enough to keep the whole Spotify window usable, then center it.
local function centerWindow(win, size, screen)
    if not windowID(win) then return end
    screen = screen or win:screen() or hs.screen.mainScreen()
    size = size or win:frame()
    coupling.suspend(windowID(win))
    win:setFrame(centeredFrame(size, screen), 0)
end

local function finishMove(win, size)
    M.settleTimer = hs.timer.doAfter(SETTLE_DELAY, function()
        if windowID(win) then
            centerWindow(win, size)
            win:raise():focus()
        end
        M.busy = false
    end)
end

local function moveToSpace(win, targetSpace, size, missionControlIsOpen)
    local id = windowID(win)
    if not id then
        if missionControlIsOpen then spaces.closeMissionControl() end
        M.busy = false
        logError("Could not move Spotify to its Desktop", "Spotify window disappeared")
        return
    end

    local function startVerifiedMove()
        M.moveTask = hs.task.new(
            MOVE_HELPER,
            function(exitCode, stdout, stderr)
                if exitCode ~= 0 then
                    local detail = stderr and stderr:gsub("%s+$", "") or ""
                    if detail == "" then detail = "helper exited with status " .. exitCode end
                    M.busy = false
                    logError("Could not move Spotify to its Desktop", detail)
                    return
                end

                hs.printf("[spotify_space] %s", (stdout or "move verified"):gsub("%s+$", ""))

                local switched, started, switchError = pcall(spaces.gotoSpace, targetSpace)
                if not switched or not started then
                    M.busy = false
                    logError(
                        "Spotify moved, but its Desktop could not be opened",
                        switchError or started
                    )
                    return
                end

                finishMove(win, size)
            end,
            {tostring(id), tostring(targetSpace)}
        )

        if not M.moveTask or not M.moveTask:start() then
            M.busy = false
            logError("Could not start Spotify's Desktop move", MOVE_HELPER)
        end
    end

    if missionControlIsOpen then
        spaces.closeMissionControl()
        M.moveDelayTimer = hs.timer.doAfter(0.35, startVerifiedMove)
    else
        startVerifiedMove()
    end
end

local function firstOtherUserSpace(screen, excludedSpace)
    local screenSpaces = spaces.spacesForScreen(screen) or {}
    for _, spaceID in ipairs(screenSpaces) do
        if spaceID ~= excludedSpace and spaces.spaceType(spaceID) == "user" then
            return spaceID
        end
    end
    return nil
end

local function leaveSpotifySpace(win, session)
    local destination = session.homeSpace
    if not spaceExists(destination) then
        destination = firstOtherUserSpace(win:screen(), session.spotifySpace)
    end

    if not destination then
        M.busy = false
        logError("Could not find a Desktop to return Spotify to", "no user Space available")
        return
    end

    moveToSpace(win, destination, win:frame(), false)
end

local function findNewSpace(screen, knownSpaces)
    local currentSpaces = spaces.spacesForScreen(screen)
    if not currentSpaces then return nil end

    -- addSpaceToScreen appends at the far-right edge, so search backwards.
    for index = #currentSpaces, 1, -1 do
        local spaceID = currentSpaces[index]
        if not knownSpaces[spaceID] and spaces.spaceType(spaceID) == "user" then
            return spaceID
        end
    end
    return nil
end

local function waitForNewSpace(win, screen, knownSpaces, session, size, attemptsLeft)
    local newSpace = findNewSpace(screen, knownSpaces)
    if newSpace then
        session.spotifySpace = newSpace
        M.session = session
        saveSession()
        moveToSpace(win, newSpace, size, true)
        return
    end

    if attemptsLeft <= 0 then
        spaces.closeMissionControl()
        M.busy = false
        logError("Could not identify Spotify's new Desktop", "new Space did not appear")
        return
    end

    M.spacePollTimer = hs.timer.doAfter(SPACE_POLL_DELAY, function()
        waitForNewSpace(win, screen, knownSpaces, session, size, attemptsLeft - 1)
    end)
end

local function enterSpotifySpace(win, session)
    local screen = win:screen() or hs.screen.mainScreen()
    local size = win:frame()
    local homeSpace = spaces.activeSpaceOnScreen(screen)

    session = session or {}
    session.homeSpace = homeSpace

    -- Reuse the remembered Desktop instead of accumulating a new blank Desktop
    -- every time the shortcut is toggled or Hammerspoon is reloaded.
    if spaceExists(session.spotifySpace)
        and spaces.spaceDisplay(session.spotifySpace) == screen:getUUID() then
        M.session = session
        saveSession()
        moveToSpace(win, session.spotifySpace, size, false)
        return
    end

    local existingSpaces, listError = spaces.spacesForScreen(screen)
    if not existingSpaces then
        M.busy = false
        logError("Could not read the current Desktops", listError)
        return
    end

    local knownSpaces = {}
    for _, spaceID in ipairs(existingSpaces) do knownSpaces[spaceID] = true end

    -- Leave Mission Control open so gotoSpace can finish the operation with a
    -- single visual transition.
    local added, addError = spaces.addSpaceToScreen(screen, false)
    if not added then
        spaces.closeMissionControl()
        M.busy = false
        logError("Could not create a Desktop for Spotify", addError)
        return
    end

    waitForNewSpace(win, screen, knownSpaces, session, size, SPACE_POLL_ATTEMPTS)
end

local function toggleSpotifySpace()
    if M.busy then return end

    local win = hs.window.frontmostWindow()
    if not win or not isSpotify(win:application()) then return end

    M.busy = true

    -- If Spotify was already in native fullscreen before this module loaded,
    -- leave fullscreen first and retry after macOS finishes the transition.
    if win:isFullScreen() then
        win:setFullScreen(false)
        M.fullscreenTimer = hs.timer.doAfter(1.2, function()
            M.busy = false
            toggleSpotifySpace()
        end)
        return
    end

    if not spaces.screensHaveSeparateSpaces() then
        M.busy = false
        logError(
            "Spotify Spaces needs ‘Displays have separate Spaces’ enabled",
            "System Settings > Desktop & Dock > Mission Control"
        )
        return
    end

    local session = M.session
    local windowSpaces = spaces.windowSpaces(win) or {}

    if session and contains(windowSpaces, session.spotifySpace) then
        leaveSpotifySpace(win, session)
    else
        enterSpotifySpace(win, session)
    end
end

local function setHotkeysEnabled(app)
    for _, hotkey in ipairs(M.hotkeys) do
        if isSpotify(app) then
            hotkey:enable()
        else
            hotkey:disable()
        end
    end
end

-- hs.hotkey does not support Fn as a modifier, so catch Fn+F at the event level.
-- Dispatch asynchronously so the event callback returns before Mission Control
-- begins its animation.
local function handleFnFullScreen(event)
    local eventType = event:getType()
    local keyCode = event:getKeyCode()

    if M.swallowFnF and keyCode == hs.keycodes.map.f then
        if eventType == hs.eventtap.event.types.keyUp then
            M.swallowFnF = false
            if M.fnResetTimer then M.fnResetTimer:stop() end
        end
        return true
    end

    if eventType ~= hs.eventtap.event.types.keyDown or keyCode ~= hs.keycodes.map.f then
        return false
    end

    local flags = event:getFlags()
    if not flags.fn or flags.cmd or flags.ctrl or flags.alt or flags.shift then
        return false
    end

    if not isSpotify(hs.application.frontmostApplication()) then return false end

    M.swallowFnF = true
    M.fnResetTimer = hs.timer.doAfter(1, function() M.swallowFnF = false end)
    M.fnDispatchTimer = hs.timer.doAfter(0, toggleSpotifySpace)
    return true
end

local function recenterSpotifyWindows()
    local app = hs.application.get(SPOTIFY_BUNDLE_ID)
    if not app then return end

    for _, win in ipairs(app:allWindows()) do
        if win:isStandard() and not win:isFullScreen() then
            centerWindow(win, win:frame())
        end
    end
end

function M.start()
    M.hotkeys = {
        hs.hotkey.new({"ctrl", "cmd"}, "f", toggleSpotifySpace),
    }

    M.appWatcher = hs.application.watcher.new(function(_, event, app)
        if event == hs.application.watcher.activated then
            setHotkeysEnabled(app)
        end
    end)
    M.appWatcher:start()
    setHotkeysEnabled(hs.application.frontmostApplication())

    M.fnTap = hs.eventtap.new({
        hs.eventtap.event.types.keyDown,
        hs.eventtap.event.types.keyUp,
    }, handleFnFullScreen)
    M.fnTap:start()

    M.screenWatcher = hs.screen.watcher.new(function()
        if M.screenTimer then M.screenTimer:stop() end
        M.screenTimer = hs.timer.doAfter(1.25, recenterSpotifyWindows)
    end)
    M.screenWatcher:start()
end

return M
