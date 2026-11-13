-- MouseShift
-- Copyright (c) 2026 Mike Bronka - https://www.mikebronka.com
-- Released under the MIT License.
--
-- UnitFrames: lets the assigned mouse buttons pass through unit frames.
--
-- Unit frames (the player, target, party and raid frames, from the game or
-- from addons) take every mouse button that is pressed over them. A mouse
-- button assigned as a modifier would then never reach its keybinding while
-- the cursor is over a frame, so mouseover casting on frames would get the
-- plain keybind instead of the modified one.
--
-- The game can tell a frame to pass chosen mouse buttons on to what lies
-- below it (SetPassThroughButtons). MouseShift does that for the mouse
-- buttons assigned as modifiers, and only for those. The game allows this
-- out of combat only, so it is done after login, after loading screens,
-- when the group changes and when combat ends.

local _, ns = ...

-- The mouse buttons SetPassThroughButtons accepts. The left and right
-- buttons are never assigned, and higher buttons cannot be passed through.
local SUPPORTED = {
    MiddleButton = true,
    Button4 = true,
    Button5 = true,
}

-- Frames whose pass-through buttons MouseShift has set.
local changed = setmetatable({}, { __mode = "k" })

local updatePending = false
local updateQueued = false

local function AssignedMouseButtons()
    local buttons = {}
    for _, modifier in ipairs(ns.MODIFIERS) do
        local key = ns.GetTrigger(modifier)
        local button = key and ns.KeyToMouseButton(key)
        if button and SUPPORTED[button] then
            buttons[#buttons + 1] = button
        end
    end
    table.sort(buttons)
    return buttons
end

-- A unit frame is a clickable button that shows a unit, such as "player",
-- "party1" or "raid12". Every unit frame addon sets this "unit" attribute.
local function IsUnitFrame(frame)
    if frame.IsForbidden and frame:IsForbidden() then
        return false
    end
    if not (frame.IsObjectType and frame:IsObjectType("Button")) then
        return false
    end
    if not (frame.SetPassThroughButtons and frame:IsMouseEnabled()) then
        return false
    end
    return frame:GetAttribute("unit") ~= nil
end

function ns.UpdatePassThrough()
    if not ns.db or not EnumerateFrames then
        return
    end
    if InCombatLockdown() then
        updatePending = true
        return
    end
    updatePending = false

    local buttons = AssignedMouseButtons()
    local frame = EnumerateFrames()
    while frame do
        local ok, isUnitFrame = pcall(IsUnitFrame, frame)
        if ok and isUnitFrame then
            if #buttons > 0 then
                if pcall(frame.SetPassThroughButtons, frame, unpack(buttons)) then
                    changed[frame] = true
                end
            elseif changed[frame] then
                -- No mouse button is assigned any more: give the frame its
                -- clicks back.
                pcall(frame.SetPassThroughButtons, frame)
                changed[frame] = nil
            end
        end
        frame = EnumerateFrames(frame)
    end
end

-- Frames are often created in bursts (a raid forming, an addon loading), so
-- updates are gathered and run once, a moment later.
local function RequestUpdate()
    if updateQueued then
        return
    end
    updateQueued = true
    C_Timer.After(1, function()
        updateQueued = false
        ns.UpdatePassThrough()
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if updatePending then
            RequestUpdate()
        end
    else
        RequestUpdate()
    end
end)
