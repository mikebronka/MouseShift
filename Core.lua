-- MouseShift
-- Copyright (c) 2026 Mike Bronka - https://www.mikebronka.com
-- Released under the MIT License.
--
-- Core: turns mouse buttons, or other keys, into Shift, Ctrl and Alt modifiers.
--
-- Every assigned mouse button or key (the "trigger") is bound to a click on a secure
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

---------------------------------------------------------------------------
-- Event log
---------------------------------------------------------------------------

-- The last events, kept in memory for /mouseshift status, so a report shows
-- what happened just before something went wrong.
local LOG_SIZE = 40
local log = {}

function ns.Log(text)
    log[#log + 1] = date("%H:%M:%S") .. "  " .. text
    if #log > LOG_SIZE then
        table.remove(log, 1)
    end
end

function ns.GetLog()
    return log
end

-- Bit value of each modifier. A layer is identified by the sum of the bits
-- of the modifiers it needs, so 1 = SHIFT, 3 = CTRL-SHIFT, 7 = ALT-CTRL-SHIFT.
local MODIFIER_BIT = { SHIFT = 1, CTRL = 2, ALT = 4 }

-- The game writes modifiers in this order: ALT-CTRL-SHIFT-key.
local PREFIX_ORDER = { "ALT", "CTRL", "SHIFT" }

-- Movement that runs for as long as its key is held. A key's release goes to
-- whatever the key is bound to at that moment, so a key bound to one of these
-- is never taken over by a layer: pressing the trigger while walking would
-- send the key's release to the layer's action and the character would keep
-- walking.
local HELD_MOVEMENT = {
    MOVEFORWARD = true,
    MOVEBACKWARD = true,
    STRAFELEFT = true,
    STRAFERIGHT = true,
    TURNLEFT = true,
    TURNRIGHT = true,
    MOVEANDSTEER = true,
    PITCHUP = true,
    PITCHDOWN = true,
    CAMERAORSELECTORMOVE = true,
    TURNORACTION = true,
}

-- Actions that are never put on a key by a layer, or releasing the trigger
-- before the key would leave the character moving. Jump is one of them, but
-- the jump key itself stays available to layers: a jump is over at once, and
-- Shift-Space or Ctrl-Space are popular keybinds.
local EXCLUDED_ACTIONS = { JUMP = true }
for action in pairs(HELD_MOVEMENT) do
    EXCLUDED_ACTIONS[action] = true
end

-- Keys bound to these actions are listed in the Movement protection window.
-- Each one can be protected (never taken over by a layer) or free. By
-- default, keys for held movement are protected and the jump key is free.
-- The order is the order of the list. Mouse steering is not listed: it is
-- always protected.
local MOVEMENT_ORDER = {
    "MOVEFORWARD", "MOVEBACKWARD", "TURNLEFT", "TURNRIGHT", "STRAFELEFT",
    "STRAFERIGHT", "JUMP", "PITCHUP", "PITCHDOWN",
}
local MOVEMENT_RANK = {}
for index, action in ipairs(MOVEMENT_ORDER) do
    MOVEMENT_RANK[action] = index
end

-- Keys that are never taken over: the main mouse buttons and Escape.
local EXCLUDED_KEYS = {
    BUTTON1 = true,
    BUTTON2 = true,
    LEFTBUTTON = true,
    RIGHTBUTTON = true,
    ESCAPE = true,
}

-- Actions that control the camera and the character with the mouse. A mouse
-- button bound to one of these is never taken over, whatever its number.
local MOUSE_CONTROL_ACTIONS = {
    CAMERAORSELECTORMOVE = true,
    TURNORACTION = true,
    MOVEANDSTEER = true,
}

-- True for the left or right mouse button under any of the names the game
-- uses for them in events and bindings.
local function IsMainMouseButton(key)
    local upper = key:upper()
    return upper == "BUTTON1" or upper == "BUTTON2" or upper == "LEFTBUTTON" or upper == "RIGHTBUTTON"
end
ns.IsMainMouseButton = IsMainMouseButton

-- Keys that cannot be a trigger, on top of EXCLUDED_KEYS. The mouse wheel
-- has no release event, so a layer on it would never switch off.
local FORBIDDEN_TRIGGERS = {
    ENTER = true,
    NUMPADENTER = true,
    PRINTSCREEN = true,
    MOUSEWHEELUP = true,
    MOUSEWHEELDOWN = true,
}

-- The real modifier keys, as reported by keyboard events.
local MODIFIER_KEYS = {
    SHIFT = true, LSHIFT = true, RSHIFT = true,
    CTRL = true, LCTRL = true, RCTRL = true,
    ALT = true, LALT = true, RALT = true,
    META = true, LMETA = true, RMETA = true,
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
-- Modifier prefixes in key names, written out. The game abbreviates them
-- ("s-Spacebar"), which reads poorly in a tooltip.
local MODIFIER_PREFIXES = {
    { prefix = "ALT-", name = "Alt" },
    { prefix = "CTRL-", name = "Ctrl" },
    { prefix = "SHIFT-", name = "Shift" },
}

function ns.KeyDisplayName(key)
    for _, modifier in ipairs(MODIFIER_PREFIXES) do
        if key:sub(1, #modifier.prefix) == modifier.prefix and #key > #modifier.prefix then
            return modifier.name .. "-" .. ns.KeyDisplayName(key:sub(#modifier.prefix + 1))
        end
    end
    local text = _G["KEY_" .. key]
    if (not text or text == "") and GetBindingText then
        text = GetBindingText(key, "KEY_")
    end
    if text and text ~= "" then
        return text
    end
    return key
end

-- Checks whether a key can be a trigger. Returns nil when it can, or a reason:
-- "reserved" (main mouse buttons, Escape, Enter, Print Screen), "modifier"
-- (Shift, Ctrl and Alt themselves) or "movement" (a keyboard key bound to
-- movement). Saved settings are checked with skipBindings, because the
-- player's bindings are not loaded yet at that point.
function ns.CheckTrigger(key, skipBindings)
    if type(key) ~= "string" or key == "" or HasModifier(key) then
        return "reserved"
    end
    if IsMainMouseButton(key) or EXCLUDED_KEYS[key] or FORBIDDEN_TRIGGERS[key] then
        return "reserved"
    end
    if MODIFIER_KEYS[key] then
        return "modifier"
    end

    local mouseNumber = tonumber(key:match("^BUTTON(%d+)$"))
    if mouseNumber then
        if mouseNumber < 3 then
            return "reserved"
        end
    elseif key:lower():find("button", 1, true) then
        -- Mouse button names from events ("MiddleButton", "Button4") are
        -- converted before they get here. Anything else is not a real key.
        return "reserved"
    end

    if not skipBindings then
        local action = GetBindingAction(key)
        if action and action ~= "" then
            if MOUSE_CONTROL_ACTIONS[action] then
                return "movement"
            end
            if not mouseNumber and EXCLUDED_ACTIONS[action] then
                return "movement"
            end
        end
    end
    return nil
end

-- Readable name of a binding action, for example "Action Button 1".
-- Buttons of popular action bar addons, bound as "CLICK <frame>:<button>".
local CLICK_NAMES = {
    { pattern = "^BT4Button(%d+)$", format = "Bartender button %s" },
    { pattern = "^ElvUI_Bar(%d+)Button(%d+)$", format = "ElvUI bar %s button %s" },
    { pattern = "^DominosActionButton(%d+)$", format = "Dominos button %s" },
}

function ns.ActionDisplayName(action)
    local name = _G["BINDING_NAME_" .. action]
    if name and name ~= "" then
        return name
    end
    -- A click on a button frame: name the frame, without "CLICK" and the
    -- mouse button.
    local frameName = action:match("^CLICK ([^:]+)")
    if frameName then
        for _, known in ipairs(CLICK_NAMES) do
            local first, second = frameName:match(known.pattern)
            if first then
                return known.format:format(first, second)
            end
        end
        return frameName
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
        if not MODIFIER_BIT[modifier] or type(key) ~= "string" or ns.CheckTrigger(key, true) then
            MouseShiftDB.triggers[modifier] = nil
        end
    end
    -- Minimap button: "hide" and "minimapPos" are the field names the
    -- LibDBIcon library uses, so the same table works with it and without it.
    if type(MouseShiftDB.minimap) ~= "table" then
        MouseShiftDB.minimap = {}
    end
    if type(MouseShiftDB.minimap.hide) ~= "boolean" then
        MouseShiftDB.minimap.hide = false
    end
    if type(MouseShiftDB.minimap.minimapPos) ~= "number" then
        MouseShiftDB.minimap.minimapPos = 220
    end
    -- Movement protection choices that differ from the default, per key:
    -- { action = "STRAFELEFT", protected = false }.
    if type(MouseShiftDB.movementKeys) ~= "table" then
        MouseShiftDB.movementKeys = {}
    end
    for key, choice in pairs(MouseShiftDB.movementKeys) do
        if type(key) ~= "string" or type(choice) ~= "table" or type(choice.action) ~= "string"
            or type(choice.protected) ~= "boolean" then
            MouseShiftDB.movementKeys[key] = nil
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

-- Logs every press and release of a trigger. This runs after the secure
-- snippet and only reads its result, so it changes nothing in combat.
driver:HookScript("OnClick", function(self, modifier, down)
    local active = self:GetAttribute("active-mask") or 0
    ns.Log(("%s %s, layer %s"):format(modifier or "?", down and "pressed" or "released",
        active == 0 and "off" or PrefixForMask(active):sub(1, -2)))
end)

---------------------------------------------------------------------------
-- Layer tables
---------------------------------------------------------------------------

ns.layers = {}
ns.skipped = {}

-- Returns an ordered list of { key = "2", action = "ACTIONBUTTON8" } entries
-- for one layer.
---------------------------------------------------------------------------
-- Movement protection
---------------------------------------------------------------------------

-- True while a layer is switched on and has put its own override on the key.
local function IsInActiveLayer(key)
    local active = driver:GetAttribute("active-mask") or 0
    local layer = active ~= 0 and ns.layers[active]
    if layer then
        for _, entry in ipairs(layer) do
            if entry.key == key then
                return true
            end
        end
    end
    return false
end

-- What each layer key was bound to outside MouseShift's layers, including
-- the overrides of other addons, recorded when the layers were built.
local baseActions = {}

-- The binding in effect on a key, including the overrides of other addons,
-- but not MouseShift's own layer overrides.
local function EffectiveAction(key)
    if IsInActiveLayer(key) then
        local recorded = baseActions[key]
        if recorded ~= nil then
            return recorded
        end
        return GetBindingAction(key)
    end
    return GetBindingAction(key, true)
end

-- The movement action a key performs, or nil.
local function MovementActionOf(key)
    local action = EffectiveAction(key)
    if action and MOVEMENT_RANK[action] then
        return action
    end
    return nil
end

local function DefaultProtected(action)
    return HELD_MOVEMENT[action] == true
end

-- True when a layer must leave this key alone.
function ns.IsKeyProtected(key)
    -- Steering with the mouse is always protected and never listed.
    if MOUSE_CONTROL_ACTIONS[EffectiveAction(key) or ""] then
        return true
    end
    local action = MovementActionOf(key)
    if not action then
        return false
    end
    -- A choice counts only for the movement it was made for. Bindings can
    -- differ between characters: E may strafe on one and walk on another.
    local choice = ns.db and ns.db.movementKeys[key]
    if choice and choice.action == action then
        return choice.protected
    end
    return DefaultProtected(action)
end

local function IsDefaultChoice(key)
    local choice = ns.db and ns.db.movementKeys[key]
    return not (choice and choice.action == MovementActionOf(key))
end

function ns.SetKeyProtected(key, protected)
    if InCombatLockdown() or not ns.db then
        return false
    end
    local action = MovementActionOf(key)
    if not action then
        return false
    end
    ns.Log(("%s %s"):format(key, protected and "protected" or "freed"))
    if DefaultProtected(action) == protected then
        ns.db.movementKeys[key] = nil
    else
        ns.db.movementKeys[key] = { action = action, protected = protected and true or false }
    end
    return ns.Apply()
end

function ns.ResetMovementKeys()
    if InCombatLockdown() or not ns.db then
        return false
    end
    wipe(ns.db.movementKeys)
    ns.Log("movement protection reset to defaults")
    return ns.Apply()
end

-- The Shift, Ctrl and Alt keybinds on a key that the assigned mouse buttons
-- can reach: { { combo, action }, ... }.
local function ModifiedBindings(key)
    local available = 0
    for _, modifier in ipairs(ns.MODIFIERS) do
        if ns.GetTrigger(modifier) then
            available = available + MODIFIER_BIT[modifier]
        end
    end
    local result = {}
    for mask = 1, 7 do
        local combo = PrefixForMask(mask) .. key
        if bit.band(mask, available) ~= mask then
            combo = nil
        end
        local action = combo and GetBindingAction(combo, true)
        if action and action ~= "" and not EXCLUDED_ACTIONS[action] and not action:find("MouseShiftDriver", 1, true) then
            result[#result + 1] = { combo = combo, action = action }
        end
    end
    return result
end

-- Every key that moves the character, in list order:
-- { key, action, protected, isDefault, bindings }.
function ns.GetMovementKeys()
    local seen, list = {}, {}
    for index = 1, GetNumBindings() do
        local results = { GetBinding(index) }
        for i = 2, #results do
            local key = results[i]
            if type(key) == "string" and not seen[key] and not HasModifier(key)
                and not EXCLUDED_KEYS[key] and not IsMainMouseButton(key) then
                seen[key] = true
                local action = MovementActionOf(key)
                if action then
                    list[#list + 1] = {
                        key = key,
                        action = action,
                        protected = ns.IsKeyProtected(key),
                        isDefault = IsDefaultChoice(key),
                        bindings = ModifiedBindings(key),
                    }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.action ~= b.action then
            return MOVEMENT_RANK[a.action] < MOVEMENT_RANK[b.action]
        end
        return a.key < b.key
    end)
    return list
end

---------------------------------------------------------------------------
-- Layers
---------------------------------------------------------------------------

-- Returns the layer for one combination of modifiers, and the keys it had
-- to skip because they are protected movement keys.
local function CollectLayer(mask, triggerKeys, recorded)
    local prefix = PrefixForMask(mask)
    local found, skipped = {}, {}

    local function consider(combo)
        if type(combo) ~= "string" or combo:sub(1, #prefix) ~= prefix then
            return
        end
        local base = combo:sub(#prefix + 1)
        if base == "" or found[base] or skipped[base] or EXCLUDED_KEYS[base] or IsMainMouseButton(base) or triggerKeys[base] or HasModifier(base) then
            return
        end
        local action = GetBindingAction(combo, true)
        if not action or action == "" or EXCLUDED_ACTIONS[action] or action:find("MouseShiftDriver", 1, true) then
            return
        end
        -- A protected key keeps moving the character on every layer.
        if ns.IsKeyProtected(base) then
            skipped[base] = action
            return
        end
        found[base] = action
        recorded[base] = EffectiveAction(base) or ""
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

    local function sorted(map)
        local list = {}
        for key, action in pairs(map) do
            list[#list + 1] = { key = key, action = action }
        end
        table.sort(list, function(a, b) return a.key < b.key end)
        return list
    end
    return sorted(found), sorted(skipped)
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

    local layers, skipped, recorded = {}, {}, {}
    for mask = 1, 7 do
        if bit.band(mask, availableBits) == mask then
            layers[mask], skipped[mask] = CollectLayer(mask, triggerKeys, recorded)
        end
    end
    return layers, skipped, recorded
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
        if key and not ns.CheckTrigger(key, true) then
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
        if not rebuildPending then
            ns.Log("keybinds changed in combat, rebuild after combat")
        end
        rebuildPending = true
        return false
    end
    rebuildPending = false

    local layers, skipped, recorded = CollectAllLayers()
    ns.skipped = skipped
    baseActions = recorded
    local signature = Signature(layers)
    if signature == lastSignature then
        -- Nothing changed. Returning here also keeps the UPDATE_BINDINGS
        -- events caused by our own binding changes from looping forever.
        return true
    end
    lastSignature = signature
    local sizes = {}
    for mask = 1, 7 do
        if layers[mask] then
            sizes[#sizes + 1] = PrefixForMask(mask):sub(1, -2) .. " " .. #layers[mask]
        end
    end
    ns.Log("layers rebuilt: " .. (#sizes > 0 and table.concat(sizes, ", ") or "none"))

    ResetActiveLayer()
    -- Drop every override the driver owns, so nothing from an earlier
    -- layer table can survive a rebuild.
    ClearOverrideBindings(driver)
    StoreLayers(layers)
    BindTriggers()
    ns.layers = layers

    if ns.UpdatePassThrough then
        ns.UpdatePassThrough()
    end

    if ns.OnApplied then
        ns.OnApplied()
    end
    return true
end

---------------------------------------------------------------------------
-- Stuck layer guard
---------------------------------------------------------------------------

-- If a trigger is released while the game window is not focused (for
-- example after Alt-Tab), the game never sees the release and the layer
-- stays on. Out of combat, mouse button triggers are checked regularly and
-- a layer whose button is no longer held is switched off. Keyboard keys
-- cannot be checked this way; pressing them again fixes it.

-- "BUTTON3" -> "MiddleButton", "BUTTON4" -> "Button4"
local function KeyToMouseButton(key)
    if key == "BUTTON3" then
        return "MiddleButton"
    end
    local number = key:match("^BUTTON(%d+)$")
    if number then
        return "Button" .. number
    end
    return nil
end

ns.KeyToMouseButton = KeyToMouseButton

local CHECK_INTERVAL = 0.5
-- A button must be seen as released this many times in a row, so a single
-- odd reading never switches a layer off while the player holds it.
local MISSES_NEEDED = 2
local misses = {}
-- Buttons the game has reported as held at least once while their layer was
-- on. Only these are trusted to be released, so a button the game does not
-- report correctly can never switch its layer off by mistake.
local verified = {}

local function SwitchLayer(newMask)
    local active = driver:GetAttribute("active-mask") or 0
    if newMask == active then
        return
    end
    local count = driver:GetAttribute("layer" .. active .. "-count") or 0
    for i = 1, count do
        SetOverrideBinding(driver, true, driver:GetAttribute("layer" .. active .. "-key" .. i), nil)
    end
    count = driver:GetAttribute("layer" .. newMask .. "-count") or 0
    for i = 1, count do
        SetOverrideBinding(driver, true, driver:GetAttribute("layer" .. newMask .. "-key" .. i),
            driver:GetAttribute("layer" .. newMask .. "-action" .. i))
    end
    driver:SetAttribute("active-mask", newMask)
end

local function CheckStuckLayers()
    if InCombatLockdown() or not IsMouseButtonDown then
        return
    end
    if (driver:GetAttribute("active-mask") or 0) == 0 then
        wipe(misses)
        return
    end

    local changed = false
    for _, modifier in ipairs(ns.MODIFIERS) do
        local button = driver:GetAttribute("held-" .. modifier) and KeyToMouseButton(ns.GetTrigger(modifier) or "")
        local down = button and IsMouseButtonDown(button)
        if down then
            verified[button] = true
        end
        if button and not down and verified[button] then
            misses[modifier] = (misses[modifier] or 0) + 1
            if misses[modifier] >= MISSES_NEEDED then
                ns.Log(("%s switched off: %s is no longer held"):format(modifier, button))
                driver:SetAttribute("held-" .. modifier, nil)
                misses[modifier] = nil
                changed = true
            end
        else
            misses[modifier] = nil
        end
    end

    if changed then
        local mask = 0
        for _, modifier in ipairs(ns.MODIFIERS) do
            if driver:GetAttribute("held-" .. modifier) then
                mask = mask + MODIFIER_BIT[modifier]
            end
        end
        SwitchLayer(mask)
    end
end

-- Switches every layer off. Used after loading screens, where no trigger
-- can still be held.
local function ReleaseAllLayers()
    if InCombatLockdown() then
        return
    end
    if (driver:GetAttribute("active-mask") or 0) ~= 0 then
        ns.Log("loading screen: layer switched off")
    end
    for _, modifier in ipairs(ns.MODIFIERS) do
        driver:SetAttribute("held-" .. modifier, nil)
    end
    wipe(misses)
    SwitchLayer(0)
end

function ns.IsApplyPending()
    return rebuildPending
end

-- The internal state, for /mouseshift status.
function ns.GetState()
    local held = {}
    for _, modifier in ipairs(ns.MODIFIERS) do
        held[modifier] = driver:GetAttribute("held-" .. modifier) and true or false
    end
    local trusted = {}
    for button in pairs(verified) do
        trusted[#trusted + 1] = button
    end
    table.sort(trusted)
    return {
        activeMask = driver:GetAttribute("active-mask") or 0,
        held = held,
        rebuildPending = rebuildPending,
        verifiedButtons = trusted,
        driverName = driver:GetName(),
    }
end

function ns.LayerName(mask)
    if mask == 0 then
        return "none"
    end
    return PrefixForMask(mask):sub(1, -2)
end

function ns.SetTrigger(modifier, key)
    if not MODIFIER_BIT[modifier] or InCombatLockdown() then
        return false
    end
    if key and ns.CheckTrigger(key) then
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
    ns.Log(("%s set to %s"):format(modifier, key or "nothing"))
    return ns.Apply()
end

-- The layer of a single modifier and the keys it skipped.
function ns.LayerFor(modifier)
    local mask = MODIFIER_BIT[modifier]
    return ns.layers[mask] or {}, ns.skipped[mask] or {}
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
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitDatabase()
            events:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        ns.Apply()
        C_Timer.NewTicker(CHECK_INTERVAL, CheckStuckLayers)
        if not ns.HasAnyTrigger() then
            ns.Print("Type /mouseshift to choose your mouse buttons.")
        end
    elseif event == "UPDATE_BINDINGS" then
        RequestApply()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.Log("loading screen")
        ReleaseAllLayers()
    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.Log("combat started")
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.Log("combat ended")
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
            local skipped = ns.skipped[mask]
            if skipped and #skipped > 0 then
                local keys = {}
                for _, entry in ipairs(skipped) do
                    keys[#keys + 1] = ns.KeyDisplayName(entry.key)
                end
                print(("    |cffff9a4dskipped, protected movement keys: %s|r"):format(table.concat(keys, ", ")))
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
        ns.Print("All mouse buttons and keys cleared.")
    elseif command == "minimap" then
        if ns.SetMinimapButtonShown then
            local show = not ns.IsMinimapButtonShown()
            ns.SetMinimapButtonShown(show)
            ns.Print(show and "Minimap button shown." or "Minimap button hidden. Type /mouseshift minimap to show it again.")
        end
    elseif command == "status" then
        if ns.ShowStatus then
            ns.ShowStatus()
        end
    elseif command == "help" then
        ns.Print("commands:")
        print("  /mouseshift - open the settings window")
        print("  /mouseshift list - show which keys each layer uses")
        print("  /mouseshift status - a report to copy when something does not work")
        print("  /mouseshift minimap - show or hide the minimap button")
        print("  /mouseshift reset - clear all mouse buttons and keys")
    else
        if ns.ToggleConfig then
            ns.ToggleConfig()
        end
    end
end
