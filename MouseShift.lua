-- MouseShift
-- Copyright (c) 2026 Mike Bronka. Released under the MIT License.
--
-- SPIKE BUILD: proves that a mouse button can act as a modifier in combat.
-- The trigger button and the modifier are hard-coded below. While the trigger
-- is held, every <MODIFIER>-<key> binding is mirrored onto the plain <key>,
-- so pressing "2" behaves exactly like "SHIFT-2".
--
-- How it works: the trigger is bound to a click on a secure handler button
-- that is registered for both press and release. Its restricted snippet adds
-- override bindings on press and removes them on release. Snippets run by
-- secure handlers are allowed to change override bindings during combat.

local TRIGGER_KEY = "BUTTON4"
local MODIFIER = "SHIFT"

-- Actions that start on key press and stop on key release are never mirrored.
-- If the trigger were released before the key, the release event would reach
-- a different binding and the character would keep moving.
local EXCLUDED_ACTIONS = {
    MOVEFORWARD = true,
    MOVEBACKWARD = true,
    STRAFELEFT = true,
    STRAFERIGHT = true,
    TURNLEFT = true,
    TURNRIGHT = true,
    MOVEANDSTEER = true,
    PITCHUP = true,
    PITCHDOWN = true,
    JUMP = true,
    CAMERAORSELECTORMOVE = true,
    TURNORACTION = true,
}

-- Keys probed directly with GetBindingAction. This catches bindings that do
-- not show up in the key binding list, such as clicks set by action bar addons.
local CANDIDATE_KEYS = {}
do
    local function add(key) CANDIDATE_KEYS[#CANDIDATE_KEYS + 1] = key end
    for byte = string.byte("A"), string.byte("Z") do add(string.char(byte)) end
    for digit = 0, 9 do add(tostring(digit)) end
    for n = 1, 12 do add("F" .. n) end
    for n = 0, 9 do add("NUMPAD" .. n) end
    for n = 3, 31 do add("BUTTON" .. n) end
    for _, key in ipairs({
        "-", "=", "[", "]", ";", "'", ",", ".", "/", "`", "\\",
        "TAB", "SPACE", "CAPSLOCK", "BACKSPACE", "ENTER",
        "INSERT", "DELETE", "HOME", "END", "PAGEUP", "PAGEDOWN",
        "UP", "DOWN", "LEFT", "RIGHT",
        "NUMPADPLUS", "NUMPADMINUS", "NUMPADMULTIPLY", "NUMPADDIVIDE", "NUMPADDECIMAL",
        "MOUSEWHEELUP", "MOUSEWHEELDOWN",
    }) do
        add(key)
    end
end

local MODIFIER_PREFIXES = { "ALT-", "CTRL-", "SHIFT-", "META-" }

local function HasModifier(key)
    for _, prefix in ipairs(MODIFIER_PREFIXES) do
        if key:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Secure driver
---------------------------------------------------------------------------

local driver = CreateFrame("Button", "MouseShiftDriver", UIParent, "SecureHandlerClickTemplate")
driver:RegisterForClicks("AnyDown", "AnyUp")
driver:SetAttribute("mirror-count", 0)
driver:SetAttribute("_onclick", [=[
    local count = self:GetAttribute("mirror-count") or 0
    if down then
        for i = 1, count do
            self:SetBinding(true, self:GetAttribute("mirror-key" .. i), self:GetAttribute("mirror-action" .. i))
        end
    else
        for i = 1, count do
            self:ClearBinding(self:GetAttribute("mirror-key" .. i))
        end
    end
]=])

---------------------------------------------------------------------------
-- Mirror table
---------------------------------------------------------------------------

local lastSignature
local triggerBound = false
local rebuildPending = false

-- Returns an ordered list of { key = "2", action = "ACTIONBUTTON8" } entries.
local function CollectMirror()
    local prefix = MODIFIER .. "-"
    local found = {}

    local function consider(combo)
        if type(combo) ~= "string" or combo:sub(1, #prefix) ~= prefix then
            return
        end
        local base = combo:sub(#prefix + 1)
        if base == "" or base == TRIGGER_KEY or HasModifier(base) or found[base] then
            return
        end
        local action = GetBindingAction(combo, true)
        if action and action ~= "" and not EXCLUDED_ACTIONS[action] then
            found[base] = action
        end
    end

    -- Bindings listed in the key binding interface.
    for index = 1, GetNumBindings() do
        local results = { GetBinding(index) }
        for i = 2, #results do
            consider(results[i])
        end
    end

    -- Bindings that are not listed there (action bar addons, overrides).
    for _, key in ipairs(CANDIDATE_KEYS) do
        consider(prefix .. key)
    end

    local mirror = {}
    for key, action in pairs(found) do
        mirror[#mirror + 1] = { key = key, action = action }
    end
    table.sort(mirror, function(a, b) return a.key < b.key end)
    return mirror
end

local function Signature(mirror)
    local parts = {}
    for i, entry in ipairs(mirror) do
        parts[i] = entry.key .. "=" .. entry.action
    end
    return table.concat(parts, ";")
end

local function Rebuild()
    if InCombatLockdown() then
        rebuildPending = true
        return
    end
    rebuildPending = false

    if not triggerBound then
        SetOverrideBindingClick(driver, true, TRIGGER_KEY, driver:GetName(), "LeftButton")
        triggerBound = true
    end

    local mirror = CollectMirror()
    local signature = Signature(mirror)
    if signature == lastSignature then
        -- Nothing changed. Returning here also stops the UPDATE_BINDINGS
        -- event fired by our own binding changes from looping forever.
        return
    end
    lastSignature = signature

    -- Drop any mirrored key that is still active from the previous table.
    local oldCount = driver:GetAttribute("mirror-count") or 0
    for i = 1, oldCount do
        local key = driver:GetAttribute("mirror-key" .. i)
        if key then
            SetOverrideBinding(driver, true, key, nil)
        end
        driver:SetAttribute("mirror-key" .. i, nil)
        driver:SetAttribute("mirror-action" .. i, nil)
    end

    for i, entry in ipairs(mirror) do
        driver:SetAttribute("mirror-key" .. i, entry.key)
        driver:SetAttribute("mirror-action" .. i, entry.action)
    end
    driver:SetAttribute("mirror-count", #mirror)
end

local function RequestRebuild()
    if rebuildPending then
        return
    end
    rebuildPending = true
    -- Bindings often change in bursts; wait a moment and rebuild once.
    C_Timer.After(0.2, Rebuild)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UPDATE_BINDINGS")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Rebuild()
        print(("|cff33ccffMouseShift|r spike loaded: hold %s for the %s layer (%d keys mirrored). Type /mouseshift for details.")
            :format(TRIGGER_KEY, MODIFIER, driver:GetAttribute("mirror-count") or 0))
    elseif event == "UPDATE_BINDINGS" then
        RequestRebuild()
    elseif event == "PLAYER_REGEN_ENABLED" and rebuildPending then
        Rebuild()
    end
end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

SLASH_MOUSESHIFT1 = "/mouseshift"
SlashCmdList.MOUSESHIFT = function()
    local count = driver:GetAttribute("mirror-count") or 0
    print(("|cff33ccffMouseShift|r %s = %s, %d keys mirrored:"):format(TRIGGER_KEY, MODIFIER, count))
    for i = 1, count do
        print(("  %s -> %s"):format(driver:GetAttribute("mirror-key" .. i), driver:GetAttribute("mirror-action" .. i)))
    end
    print(("  client interface %s, in combat: %s"):format(select(4, GetBuildInfo()), tostring(InCombatLockdown())))
end
