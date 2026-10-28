-- MouseShift
-- Copyright (c) 2026 Mike Bronka - https://www.mikebronka.com
-- Released under the MIT License.
--
-- Core: turns mouse buttons into Shift, Ctrl and Alt modifiers.
--
-- Every assigned mouse button (the "trigger") is bound to a click on a secure
-- handler button. The click carries the modifier name ("SHIFT", "CTRL" or
-- "ALT") and fires on both press and release. A restricted snippet keeps
-- track of which triggers are held and swaps in the matching layer: for
-- every <MODIFIERS>-<key> binding it adds an override binding on the plain
-- <key>. Snippets run by secure handlers may change override bindings in
-- combat, which is what makes this work during a fight.
--
-- The layer tables are prepared out of combat and stored as attributes on
-- the secure button. Changes made during combat are applied after it ends.

local ADDON_NAME, ns = ...

ns.MODIFIERS = { "SHIFT", "CTRL", "ALT" }

-- Bit value of each modifier. A layer is identified by the sum of the bits
-- of the modifiers it needs, so 1 = SHIFT, 3 = CTRL-SHIFT, 7 = ALT-CTRL-SHIFT.
local MODIFIER_BIT = { SHIFT = 1, CTRL = 2, ALT = 4 }

-- The game writes modifiers in this order: ALT-CTRL-SHIFT-key.
local PREFIX_ORDER = { "ALT", "CTRL", "SHIFT" }

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

-- Keys that are never taken over: the main mouse buttons and Escape.
local EXCLUDED_KEYS = {
    BUTTON1 = true,
    BUTTON2 = true,
    ESCAPE = true,
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

-- Binding prefix for a layer, for example 3 -> "CTRL-SHIFT-".
local function PrefixForMask(mask)
    local prefix = ""
    for _, modifier in ipairs(PREFIX_ORDER) do
        if bit.band(mask, MODIFIER_BIT[modifier]) ~= 0 then
            prefix = prefix .. modifier .. "-"
        end
    end
    return prefix
end

---------------------------------------------------------------------------
-- Mouse button names
---------------------------------------------------------------------------

-- Mouse events report "MiddleButton" and "Button4", while bindings use
-- "BUTTON3" and "BUTTON4". Returns the binding key, or nil for buttons that
-- cannot be used as a trigger.
function ns.MouseButtonToKey(button)
    if button == "MiddleButton" then
        return "BUTTON3"
    end
    local number = type(button) == "string" and button:match("^Button(%d+)$")
    number = tonumber(number)
    if number and number >= 3 then
        return "BUTTON" .. number
    end
    return nil
end

-- Localized key name from the game, for example "Mouse Button 4".
function ns.KeyDisplayName(key)
    local text = _G["KEY_" .. key]
    if (not text or text == "") and GetBindingText then
        text = GetBindingText(key, "KEY_")
    end
    if text and text ~= "" then
        return text
    end
    return key
end

-- Readable name of a binding action, for example "Action Button 1".
function ns.ActionDisplayName(action)
    local name = _G["BINDING_NAME_" .. action]
    if name and name ~= "" then
        return name
    end
    return action
end

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------

local function InitDatabase()
    if type(MouseShiftDB) ~= "table" then
        MouseShiftDB = {}
    end
    if type(MouseShiftDB.triggers) ~= "table" then
        MouseShiftDB.triggers = {}
    end
    -- Drop anything that is not a valid trigger.
    for modifier, key in pairs(MouseShiftDB.triggers) do
        if not MODIFIER_BIT[modifier] or type(key) ~= "string" or EXCLUDED_KEYS[key] then
            MouseShiftDB.triggers[modifier] = nil
        end
    end
    ns.db = MouseShiftDB
end

function ns.GetTrigger(modifier)
    return ns.db and ns.db.triggers[modifier]
end

function ns.HasAnyTrigger()
    for _, modifier in ipairs(ns.MODIFIERS) do
        if ns.GetTrigger(modifier) then
            return true
        end
    end
    return false
end

-- Returns the modifier that already uses this key, if any.
function ns.FindModifierForKey(key)
    for _, modifier in ipairs(ns.MODIFIERS) do
        if ns.GetTrigger(modifier) == key then
            return modifier
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Secure driver
---------------------------------------------------------------------------

local driver = CreateFrame("Button", "MouseShiftDriver", UIParent, "SecureHandlerClickTemplate")
driver:RegisterForClicks("AnyDown", "AnyUp")
driver:SetAttribute("active-mask", 0)

-- Layer attributes: "layer<mask>-count", "layer<mask>-key<i>", "layer<mask>-action<i>".
driver:SetAttribute("_onclick", [=[
    local bitValue
    if button == "SHIFT" then
        bitValue = 1
    elseif button == "CTRL" then
        bitValue = 2
    elseif button == "ALT" then
        bitValue = 4
    else
        return
    end

    if down then
        self:SetAttribute("held-" .. button, true)
    else
        self:SetAttribute("held-" .. button, nil)
    end

    local mask = 0
    if self:GetAttribute("held-SHIFT") then mask = mask + 1 end
    if self:GetAttribute("held-CTRL") then mask = mask + 2 end
    if self:GetAttribute("held-ALT") then mask = mask + 4 end

    local active = self:GetAttribute("active-mask") or 0
    if mask == active then
        return
    end

    local count = self:GetAttribute("layer" .. active .. "-count") or 0
    for i = 1, count do
        self:ClearBinding(self:GetAttribute("layer" .. active .. "-key" .. i))
    end

    count = self:GetAttribute("layer" .. mask .. "-count") or 0
    for i = 1, count do
        self:SetBinding(true, self:GetAttribute("layer" .. mask .. "-key" .. i), self:GetAttribute("layer" .. mask .. "-action" .. i))
    end

    self:SetAttribute("active-mask", mask)
]=])

-- Owns the bindings of the trigger buttons themselves.
local triggerOwner = CreateFrame("Frame")

---------------------------------------------------------------------------
-- Layer tables
---------------------------------------------------------------------------

ns.layers = {}

-- Returns an ordered list of { key = "2", action = "ACTIONBUTTON8" } entries
-- for one layer.
local function CollectLayer(mask, triggerKeys)
    local prefix = PrefixForMask(mask)
    local found = {}

    local function consider(combo)
        if type(combo) ~= "string" or combo:sub(1, #prefix) ~= prefix then
            return
        end
        local base = combo:sub(#prefix + 1)
        if base == "" or found[base] or EXCLUDED_KEYS[base] or triggerKeys[base] or HasModifier(base) then
            return
        end
        local action = GetBindingAction(combo, true)
        if action and action ~= "" and not EXCLUDED_ACTIONS[action] and not action:find("MouseShiftDriver", 1, true) then
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

    local layer = {}
    for key, action in pairs(found) do
        layer[#layer + 1] = { key = key, action = action }
    end
    table.sort(layer, function(a, b) return a.key < b.key end)
    return layer
end

-- Builds every layer whose modifiers all have a trigger assigned.
local function CollectAllLayers()
    local triggerKeys = {}
    local availableBits = 0
    for _, modifier in ipairs(ns.MODIFIERS) do
        local key = ns.GetTrigger(modifier)
        if key then
            triggerKeys[key] = true
            availableBits = availableBits + MODIFIER_BIT[modifier]
        end
    end

    local layers = {}
    for mask = 1, 7 do
        if bit.band(mask, availableBits) == mask then
            layers[mask] = CollectLayer(mask, triggerKeys)
        end
    end
    return layers
end

local function Signature(layers)
    local parts = {}
    for _, modifier in ipairs(ns.MODIFIERS) do
        parts[#parts + 1] = modifier .. "=" .. (ns.GetTrigger(modifier) or "")
    end
    for mask = 1, 7 do
        local layer = layers[mask]
        if layer then
            parts[#parts + 1] = "#" .. mask
            for _, entry in ipairs(layer) do
                parts[#parts + 1] = entry.key .. "=" .. entry.action
            end
        end
    end
    return table.concat(parts, ";")
end

---------------------------------------------------------------------------
-- Applying the settings
---------------------------------------------------------------------------

local lastSignature
local rebuildPending = false
local rebuildQueued = false

-- Removes the layer that is currently active and forgets held triggers.
local function ResetActiveLayer()
    local active = driver:GetAttribute("active-mask") or 0
    local count = driver:GetAttribute("layer" .. active .. "-count") or 0
    for i = 1, count do
        local key = driver:GetAttribute("layer" .. active .. "-key" .. i)
        if key then
            SetOverrideBinding(driver, true, key, nil)
        end
    end
    for _, modifier in ipairs(ns.MODIFIERS) do
        driver:SetAttribute("held-" .. modifier, nil)
    end
    driver:SetAttribute("active-mask", 0)
end

local function StoreLayers(layers)
    for mask = 1, 7 do
        local oldCount = driver:GetAttribute("layer" .. mask .. "-count") or 0
        for i = 1, oldCount do
            driver:SetAttribute("layer" .. mask .. "-key" .. i, nil)
            driver:SetAttribute("layer" .. mask .. "-action" .. i, nil)
        end
        local layer = layers[mask] or {}
        for i, entry in ipairs(layer) do
            driver:SetAttribute("layer" .. mask .. "-key" .. i, entry.key)
            driver:SetAttribute("layer" .. mask .. "-action" .. i, entry.action)
        end
        driver:SetAttribute("layer" .. mask .. "-count", #layer)
    end
end

local function BindTriggers()
    ClearOverrideBindings(triggerOwner)
    for _, modifier in ipairs(ns.MODIFIERS) do
        local key = ns.GetTrigger(modifier)
        if key then
            SetOverrideBindingClick(triggerOwner, true, key, driver:GetName(), modifier)
        end
    end
end

-- Rebuilds everything out of combat. Returns false when it had to wait.
function ns.Apply()
    if not ns.db then
        return false
    end
    if InCombatLockdown() then
        rebuildPending = true
        return false
    end
    rebuildPending = false

    local layers = CollectAllLayers()
    local signature = Signature(layers)
    if signature == lastSignature then
        -- Nothing changed. Returning here also keeps the UPDATE_BINDINGS
        -- events caused by our own binding changes from looping forever.
        return true
    end
    lastSignature = signature

    ResetActiveLayer()
    StoreLayers(layers)
    BindTriggers()
    ns.layers = layers

    if ns.OnApplied then
        ns.OnApplied()
    end
    return true
end

function ns.IsApplyPending()
    return rebuildPending
end

function ns.SetTrigger(modifier, key)
    if not MODIFIER_BIT[modifier] or InCombatLockdown() then
        return false
    end
    if key then
        -- A mouse button can only stand for one modifier.
        local current = ns.FindModifierForKey(key)
        if current and current ~= modifier then
            ns.db.triggers[current] = nil
        end
    end
    ns.db.triggers[modifier] = key
    return ns.Apply()
end

-- Number of keys mirrored for a single modifier.
function ns.LayerSize(modifier)
    local layer = ns.layers[MODIFIER_BIT[modifier]]
    return layer and #layer or 0
end

local function RequestApply()
    if rebuildQueued then
        return
    end
    rebuildQueued = true
    -- Bindings often change in bursts; wait a moment and rebuild once.
    C_Timer.After(0.2, function()
        rebuildQueued = false
        ns.Apply()
    end)
end

---------------------------------------------------------------------------
-- Metadata
---------------------------------------------------------------------------

function ns.GetVersion()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = getMetadata and getMetadata(ADDON_NAME, "Version")
    if not version or version:find("@", 1, true) then
        return "dev"
    end
    return version
end

function ns.Print(message)
    print("|cff33ccffMouseShift|r " .. message)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UPDATE_BINDINGS")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitDatabase()
            events:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        ns.Apply()
        if not ns.HasAnyTrigger() then
            ns.Print("Type /mouseshift to choose your mouse buttons.")
        end
    elseif event == "UPDATE_BINDINGS" then
        RequestApply()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if rebuildPending then
            ns.Apply()
        end
    end
end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

local function PrintLayers()
    ns.Print(("version %s, client interface %s"):format(ns.GetVersion(), tostring(select(4, GetBuildInfo()))))
    local any = false
    for mask = 1, 7 do
        local layer = ns.layers[mask]
        if layer then
            any = true
            local prefix = PrefixForMask(mask):sub(1, -2)
            print(("  %s layer: %d keys"):format(prefix, #layer))
            for _, entry in ipairs(layer) do
                print(("    %s -> %s"):format(entry.key, ns.ActionDisplayName(entry.action)))
            end
        end
    end
    if not any then
        print("  No mouse buttons assigned.")
    end
end

SLASH_MOUSESHIFT1 = "/mouseshift"
SlashCmdList.MOUSESHIFT = function(input)
    local command = strtrim(input or ""):lower()
    if command == "list" then
        PrintLayers()
    elseif command == "reset" then
        if InCombatLockdown() then
            ns.Print("Settings cannot be changed in combat.")
            return
        end
        for _, modifier in ipairs(ns.MODIFIERS) do
            ns.db.triggers[modifier] = nil
        end
        ns.Apply()
        ns.Print("All mouse buttons cleared.")
    elseif command == "help" then
        ns.Print("commands:")
        print("  /mouseshift - open the settings window")
        print("  /mouseshift list - show which keys each layer uses")
        print("  /mouseshift reset - clear all mouse buttons")
    else
        if ns.ToggleConfig then
            ns.ToggleConfig()
        end
    end
end
