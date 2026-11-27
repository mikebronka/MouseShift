-- MouseShift
-- Copyright (c) 2026 Mike Bronka - https://www.mikebronka.com
-- Released under the MIT License.
--
-- Config: the settings window. A left click on a field makes it wait for
-- input; the next mouse button or key pressed becomes that modifier. Nobody
-- has to know whether their thumb button is Button 4 or Button 5, and side
-- buttons that send keyboard keys work the same way. Nothing is assigned
-- unless the field was clicked first, so a stray click cannot change it.

local _, ns = ...

local L = {
    TITLE = "MouseShift",
    INTRO = "Click a field, then press the mouse button or key you want to use as that modifier.",
    FOOTER = "Hold the assigned button or key and press another key to use its Shift, Ctrl or Alt binding.",
    EMPTY = "Click to assign",
    LISTENING = "Press a mouse button or key",
    LISTEN_HINT = "Press the mouse button or key you want to use as %s. Left-click or Escape cancels.",
    CLEAR = "Clear",
    KEYS_ONE = "%d binding",
    KEYS_MANY = "%d bindings",
    MAIN_BUTTONS = "The right mouse button is needed by the game and cannot be used. Press another button or key.",
    UNSUPPORTED = "This button cannot be used.",
    RESERVED = "%s cannot be used as a modifier.",
    MODIFIER_KEY = "Shift, Ctrl and Alt themselves cannot be used. Press another key.",
    MOVEMENT_KEY = "%s is used for movement and cannot be a modifier.",
    CANCELLED = "Cancelled.",
    ASSIGNED = "%s now works as %s.",
    MOVED = "%s now works as %s instead of %s.",
    OVERRIDES = "It was bound to \"%s\". That binding comes back when you clear it.",
    CLEARED = "%s cleared.",
    COMBAT = "Settings cannot be changed in combat.",
    PENDING = "Changes will be applied when combat ends.",
    OPEN = "Open MouseShift",
    PANEL_TEXT = "Use mouse buttons or other keys as Shift, Ctrl and Alt.",
    COMPARTMENT_HINT = "Click to open the settings.",
    SHOW_MINIMAP = "Show minimap button",
    MINIMAP_TIP = "A button on the minimap that opens this window.",
    MINIMAP_TIP_COMMAND = "You can also type /mouseshift minimap.",

    FIELD_TIP_SET = "Hold %s and press a key to use its %s keybind.",
    FIELD_TIP_EMPTY = "Click, then press the mouse button or key you want to use as %s.",
    FIELD_TIP_CHANGE = "Click to choose another button or key.",
    CLEAR_TIP = "Stop using %s as %s. Its own keybind comes back.",

    LAYER_TITLE = "%s layer: %s",
    LAYER_EMPTY = "None of your keybinds use %s yet. Set them in the game's key bindings: hold the real %s and press a key.",
    LAYER_MORE = "%d more. Type /mouseshift list to see all.",
    LAYER_SKIPPED = "Skipped: protected movement keys",
    LAYER_SKIPPED_HINT = "These keybinds work with the real %s key.",
    LAYER_SKIPPED_CHANGE = "Change this in Movement protection.",

    MOVEMENT = "Movement protection",
    MOVEMENT_BUTTON = "Movement protection...",
    MOVEMENT_SUMMARY = "%d protected, %d free",
    MOVEMENT_NONE = "no movement keys found",
    MOVEMENT_TIP = "Protected keys always move your character. MouseShift never changes what they do, so you never keep walking by accident.",
    MOVEMENT_TIP_PROTECTED = "Protected",
    MOVEMENT_TIP_FREE = "Free",
    MOVEMENT_TIP_CLICK = "Click to choose the keys. Nothing is bound here.",
    MOVEMENT_HEADER = "Protect from MouseShift:",
    MOVEMENT_EMPTY = "No keys are bound to movement.",
    DEFAULTS = "Defaults",
    DONE = "Done",
    KEY_PROTECTED = "Protected",
    KEY_FREE = "Not protected",
    KEY_DEFAULT = " (default)",
    KEY_ALWAYS = "MouseShift never changes what %s does.",
    KEY_GAIN_UNTICK = "Untick to let your mouse button reach %s.",
    KEY_NOTHING = "Your mouse buttons reach no Shift, Ctrl or Alt keybind on %s, so this changes nothing.",
    KEY_GAINS = "Your mouse button reaches %s.",
    KEY_RISK = "If you press the mouse button while holding %s, the movement can keep going until you press %s again.",
    KEY_TICK = "Tick to protect %s.",
}

local MODIFIER_LABELS = {
    SHIFT = SHIFT_KEY_TEXT or "Shift",
    CTRL = CTRL_KEY_TEXT or "Ctrl",
    ALT = ALT_KEY_TEXT or "Alt",
}

-- The window is sized for the game's default font, which is wider than the
-- fonts many interface addons use.
local WINDOW_WIDTH = 480
local ROW_HEIGHT = 34
-- Distance from the top of the window to the first row, leaving room for a
-- two-line introduction.
local ROWS_TOP = 84
-- Width of the binding count column on the right.
local COUNT_WIDTH = 96
-- Height of the options below the modifiers: the Movement protection button
-- and the minimap button checkbox.
local OPTIONS_HEIGHT = 66
-- Keys listed in a layer tooltip before "more".
local TOOLTIP_KEYS = 12

local frame
local rows = {}
local listener
local listeningRow
local movementFrame
local RefreshMovement

local function PlayClick()
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

local function SetStatus(text, isError)
    if not frame then
        return
    end
    frame.status:SetText(text or "")
    if isError then
        frame.status:SetTextColor(1, 0.3, 0.3)
    else
        frame.status:SetTextColor(1, 0.82, 0)
    end
end

local function KeysText(count)
    return (count == 1 and L.KEYS_ONE or L.KEYS_MANY):format(count)
end

local function Refresh()
    if not frame then
        return
    end
    local locked = InCombatLockdown()
    for _, row in ipairs(rows) do
        local key = ns.GetTrigger(row.modifier)
        if row == listeningRow then
            row.capture:SetText("|cffffffff" .. L.LISTENING .. "...|r")
            row.count:SetText(key and KeysText(ns.LayerSize(row.modifier)) or "")
        elseif key then
            row.capture:SetText(ns.KeyDisplayName(key))
            row.count:SetText(KeysText(ns.LayerSize(row.modifier)))
        else
            row.capture:SetText("|cff8c8c8c" .. L.EMPTY .. "|r")
            row.count:SetText("")
        end
        row.capture:SetEnabled(not locked)
        row.clear:SetEnabled(not locked and key ~= nil)
        if not row.clear:IsEnabled() then
            row.clear:UnlockHighlight()
        end
    end
    if frame.minimapCheck and ns.IsMinimapButtonShown then
        frame.minimapCheck:SetChecked(ns.IsMinimapButtonShown() and true or false)
    end
    if frame.movementSummary then
        local protected, free = 0, 0
        for _, entry in ipairs(ns.GetMovementKeys()) do
            if entry.protected then
                protected = protected + 1
            else
                free = free + 1
            end
        end
        if protected + free == 0 then
            frame.movementSummary:SetText(L.MOVEMENT_NONE)
        else
            frame.movementSummary:SetText(L.MOVEMENT_SUMMARY:format(protected, free))
        end
    end
    if RefreshMovement then
        RefreshMovement()
    end
end

ns.OnApplied = Refresh
ns.OnMinimapButtonChanged = Refresh

local function StopListening()
    listeningRow = nil
    if listener then
        listener:Hide()
    end
end

local function StartListening(row)
    listeningRow = row
    listener:Show()
    SetStatus(L.LISTEN_HINT:format(MODIFIER_LABELS[row.modifier]))
    Refresh()
end

-- Assigns a mouse button or key to a modifier and reports what happened.
local function Assign(modifier, key)
    StopListening()
    local keyName = ns.KeyDisplayName(key)

    local problem = ns.CheckTrigger(key)
    if problem == "modifier" then
        SetStatus(L.MODIFIER_KEY, true)
        Refresh()
        return
    elseif problem == "movement" then
        SetStatus(L.MOVEMENT_KEY:format(keyName), true)
        Refresh()
        return
    elseif problem then
        SetStatus(L.RESERVED:format(keyName), true)
        Refresh()
        return
    end

    local label = MODIFIER_LABELS[modifier]
    local previous = ns.FindModifierForKey(key)
    local message
    if previous and previous ~= modifier then
        message = L.MOVED:format(keyName, label, MODIFIER_LABELS[previous])
    else
        message = L.ASSIGNED:format(keyName, label)
    end

    local action = GetBindingAction(key)
    if action and action ~= "" then
        message = message .. " " .. L.OVERRIDES:format(ns.ActionDisplayName(action))
    end

    PlayClick()
    if not ns.SetTrigger(modifier, key) then
        message = message .. " " .. L.PENDING
    end
    SetStatus(message)
    Refresh()
end

local function OnCaptureClick(self)
    if InCombatLockdown() then
        StopListening()
        SetStatus(L.COMBAT, true)
        Refresh()
        return
    end
    StartListening(self.row)
end

-- While a field is listening, an invisible layer covers the screen and takes
-- the next mouse button or key, wherever the cursor is. Nothing pressed here
-- reaches the game, so nothing is cast by accident.
local function OnListenerMouseDown(_, button)
    if not listeningRow then
        return
    end
    if InCombatLockdown() then
        StopListening()
        SetStatus(L.COMBAT, true)
        Refresh()
        return
    end
    if button == "LeftButton" then
        StopListening()
        SetStatus(L.CANCELLED)
        Refresh()
        return
    end
    if button == "RightButton" then
        SetStatus(L.MAIN_BUTTONS, true)
        return
    end
    local key = ns.MouseButtonToKey(button)
    if not key then
        SetStatus(L.UNSUPPORTED, true)
        return
    end
    Assign(listeningRow.modifier, key)
end

local function OnListenerKeyDown(_, key)
    if not listeningRow then
        return
    end
    -- Mouse buttons are handled by OnListenerMouseDown. Never take a mouse
    -- button from here, whatever name it arrives under.
    if type(key) ~= "string" or key:lower():find("button", 1, true) then
        return
    end
    if key == "ESCAPE" then
        StopListening()
        SetStatus(L.CANCELLED)
        Refresh()
        return
    end
    if InCombatLockdown() then
        StopListening()
        SetStatus(L.COMBAT, true)
        Refresh()
        return
    end
    Assign(listeningRow.modifier, key)
end

local function OnClearClick(self)
    if InCombatLockdown() then
        SetStatus(L.COMBAT, true)
        return
    end
    StopListening()
    PlayClick()
    ns.SetTrigger(self.modifier, nil)
    SetStatus(L.CLEARED:format(MODIFIER_LABELS[self.modifier]))
    Refresh()
end

-- Makes a template button react to the left mouse button only. The button
-- itself stops taking the mouse, so the game cannot animate it for other
-- buttons. An invisible frame on top takes every click instead: a left click
-- presses the button and runs onClick, anything else is ignored.
local function LeftClickOnly(button, onClick)
    button:EnableMouse(false)

    local hit = CreateFrame("Frame", nil, button:GetParent())
    hit:SetAllPoints(button)
    hit:SetFrameLevel(button:GetFrameLevel() + 2)
    hit:EnableMouse(true)
    hit.button = button
    button.hit = hit

    hit:SetScript("OnEnter", function(self)
        if button:IsEnabled() then
            button:LockHighlight()
        end
        if button.tooltip and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if button.tooltip(GameTooltip) == false then
                GameTooltip:Hide()
            else
                GameTooltip:Show()
            end
        end
    end)
    hit:SetScript("OnLeave", function()
        button:UnlockHighlight()
        if button:IsEnabled() then
            button:SetButtonState("NORMAL")
        end
        if button.tooltip and GameTooltip then
            GameTooltip:Hide()
        end
    end)
    hit:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" and button:IsEnabled() then
            button:SetButtonState("PUSHED")
        end
    end)
    hit:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton ~= "LeftButton" or not button:IsEnabled() then
            return
        end
        button:SetButtonState("NORMAL")
        if self:IsMouseOver() then
            onClick(button)
        end
    end)
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------

local GOLD = { 1, 0.82, 0 }
local WHITE = { 1, 1, 1 }
local GREY = { 0.62, 0.62, 0.62 }
local GREEN = { 0.25, 1, 0.25 }
local ORANGE = { 1, 0.6, 0.3 }

local function AddText(tooltip, text, color)
    tooltip:AddLine(text, color[1], color[2], color[3], true)
end

local function AddPair(tooltip, left, right, leftColor, rightColor)
    tooltip:AddDoubleLine(left, right, leftColor[1], leftColor[2], leftColor[3], rightColor[1], rightColor[2], rightColor[3])
end

-- "Shift-Q: Bandage, Ctrl-Q: Kick"
local function BindingList(bindings)
    local parts = {}
    for _, binding in ipairs(bindings) do
        parts[#parts + 1] = ns.KeyDisplayName(binding.combo) .. ": " .. ns.ActionDisplayName(binding.action)
    end
    return table.concat(parts, ", ")
end

local function FieldTooltip(row)
    return function(tooltip)
        local label = MODIFIER_LABELS[row.modifier]
        local key = ns.GetTrigger(row.modifier)
        tooltip:SetText(label)
        if key then
            AddText(tooltip, L.FIELD_TIP_SET:format(ns.KeyDisplayName(key), label), GOLD)
            AddText(tooltip, L.FIELD_TIP_CHANGE, GREY)
        else
            AddText(tooltip, L.FIELD_TIP_EMPTY:format(label), GOLD)
        end
    end
end

local function ClearTooltip(row)
    return function(tooltip)
        local key = ns.GetTrigger(row.modifier)
        if not key then
            return false
        end
        tooltip:SetText(L.CLEAR)
        AddText(tooltip, L.CLEAR_TIP:format(ns.KeyDisplayName(key), MODIFIER_LABELS[row.modifier]), WHITE)
    end
end

local function LayerTooltip(row)
    return function(tooltip)
        if not ns.GetTrigger(row.modifier) then
            return false
        end
        local label = MODIFIER_LABELS[row.modifier]
        local layer, skipped = ns.LayerFor(row.modifier)
        tooltip:SetText(L.LAYER_TITLE:format(label, KeysText(#layer)))
        if #layer == 0 then
            AddText(tooltip, L.LAYER_EMPTY:format(label, label), GOLD)
        end
        for index = 1, math.min(#layer, TOOLTIP_KEYS) do
            local entry = layer[index]
            AddPair(tooltip, ns.KeyDisplayName(entry.key), ns.ActionDisplayName(entry.action), GOLD, WHITE)
        end
        if #layer > TOOLTIP_KEYS then
            AddText(tooltip, L.LAYER_MORE:format(#layer - TOOLTIP_KEYS), GREY)
        end
        if #skipped > 0 then
            tooltip:AddLine(" ")
            AddText(tooltip, L.LAYER_SKIPPED, ORANGE)
            for _, entry in ipairs(skipped) do
                AddPair(tooltip, ns.KeyDisplayName(entry.key), ns.ActionDisplayName(entry.action), GOLD, GREY)
            end
            AddText(tooltip, L.LAYER_SKIPPED_HINT:format(label), GREEN)
            AddText(tooltip, L.LAYER_SKIPPED_CHANGE, GREY)
        end
    end
end

local function MovementButtonTooltip(tooltip)
    tooltip:SetText(L.MOVEMENT)
    AddText(tooltip, L.MOVEMENT_TIP, GOLD)
    local protected, free = {}, {}
    for _, entry in ipairs(ns.GetMovementKeys()) do
        local list = entry.protected and protected or free
        list[#list + 1] = ns.KeyDisplayName(entry.key)
    end
    tooltip:AddLine(" ")
    AddText(tooltip, L.MOVEMENT_TIP_PROTECTED .. ": " .. (#protected > 0 and table.concat(protected, ", ") or "-"), WHITE)
    AddText(tooltip, L.MOVEMENT_TIP_FREE .. ": " .. (#free > 0 and table.concat(free, ", ") or "-"), WHITE)
    AddText(tooltip, L.MOVEMENT_TIP_CLICK, GREY)
end

local function MinimapTooltip(tooltip)
    tooltip:SetText(L.SHOW_MINIMAP)
    AddText(tooltip, L.MINIMAP_TIP, GOLD)
    AddText(tooltip, L.MINIMAP_TIP_COMMAND, GREY)
end

local function KeyTooltip(tooltip, entry)
    if not entry then
        return false
    end
    local name = ns.KeyDisplayName(entry.key)
    tooltip:SetText(name .. ": " .. ns.ActionDisplayName(entry.action))
    local state = entry.protected and L.KEY_PROTECTED or L.KEY_FREE
    if entry.isDefault then
        state = state .. L.KEY_DEFAULT
    end
    AddText(tooltip, state, GREY)
    if #entry.bindings == 0 then
        AddText(tooltip, L.KEY_NOTHING:format(name), GREY)
    elseif entry.protected then
        AddText(tooltip, L.KEY_ALWAYS:format(name), GOLD)
        AddText(tooltip, L.KEY_GAIN_UNTICK:format(BindingList(entry.bindings)), GREY)
    else
        AddText(tooltip, L.KEY_GAINS:format(BindingList(entry.bindings)), GREEN)
        AddText(tooltip, L.KEY_RISK:format(name, name), ORANGE)
        AddText(tooltip, L.KEY_TICK:format(name), GREY)
    end
end

-- Shows a tooltip while the mouse is over a plain frame.
local function AttachTooltip(target, fill)
    target:EnableMouse(true)
    target:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if fill(GameTooltip) == false then
            GameTooltip:Hide()
        else
            GameTooltip:Show()
        end
    end)
    target:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

local function CreateRow(parent, modifier, index)
    local row = { modifier = modifier }
    local top = -ROWS_TOP - (index - 1) * ROW_HEIGHT

    row.label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    row.label:SetPoint("TOPLEFT", 24, top - 4)
    row.label:SetWidth(56)
    row.label:SetJustifyH("LEFT")
    row.label:SetText(MODIFIER_LABELS[modifier])

    row.capture = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    row.capture:SetPoint("TOPLEFT", 84, top)
    row.capture:SetSize(190, 26)
    row.capture.row = row
    -- Only a left click reacts. Other mouse buttons do nothing at all here.
    LeftClickOnly(row.capture, OnCaptureClick)
    row.capture.tooltip = FieldTooltip(row)

    row.clear = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    row.clear:SetPoint("LEFT", row.capture, "RIGHT", 6, 0)
    row.clear:SetSize(60, 26)
    row.clear:SetText(L.CLEAR)
    row.clear.modifier = modifier
    LeftClickOnly(row.clear, OnClearClick)
    row.clear.tooltip = ClearTooltip(row)

    row.count = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.count:SetPoint("LEFT", row.clear, "RIGHT", 8, 0)
    row.count:SetWidth(COUNT_WIDTH)
    row.count:SetJustifyH("LEFT")
    row.count:SetWordWrap(false)

    -- Pointing at the count shows which keys the layer uses and skips.
    row.countHit = CreateFrame("Frame", nil, parent)
    row.countHit:SetPoint("LEFT", row.clear, "RIGHT", 4, 0)
    row.countHit:SetSize(COUNT_WIDTH + 4, 26)
    AttachTooltip(row.countHit, LayerTooltip(row))

    return row
end

local function CreateConfigFrame()
    frame = CreateFrame("Frame", "MouseShiftConfig", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WINDOW_WIDTH, ROWS_TOP + #ns.MODIFIERS * ROW_HEIGHT + OPTIONS_HEIGHT + 90)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    -- Escape closes the window.
    tinsert(UISpecialFrames, frame:GetName())

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText(L.TITLE)

    frame.version = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.version:SetPoint("TOPRIGHT", -30, -8)
    frame.version:SetText(ns.GetVersion())

    frame.intro = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.intro:SetPoint("TOPLEFT", 24, -34)
    frame.intro:SetPoint("RIGHT", -24, 0)
    frame.intro:SetJustifyH("LEFT")
    frame.intro:SetText(L.INTRO)

    for index, modifier in ipairs(ns.MODIFIERS) do
        rows[index] = CreateRow(frame, modifier, index)
    end

    -- Invisible full-screen layer that takes input while a field is
    -- listening. It is only shown and hidden later, which is allowed at any
    -- time, also in combat.
    listener = CreateFrame("Frame", nil, frame)
    listener:SetAllPoints(UIParent)
    listener:SetFrameStrata("FULLSCREEN_DIALOG")
    listener:EnableMouse(true)
    listener:EnableMouseWheel(true)
    listener:EnableKeyboard(true)
    listener:SetScript("OnMouseDown", OnListenerMouseDown)
    listener:SetScript("OnMouseWheel", function() end)
    listener:SetScript("OnKeyDown", OnListenerKeyDown)
    listener:Hide()

    frame.status = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    -- Minimap button checkbox. Like the fields, it reacts to the left mouse
    -- button only; the invisible click layer also covers its label.
    local optionsTop = -ROWS_TOP - #ns.MODIFIERS * ROW_HEIGHT

    -- Movement protection: opens its own window.
    local movementButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    movementButton:SetPoint("TOPLEFT", 84, optionsTop - 2)
    movementButton:SetSize(190, 26)
    movementButton:SetText(L.MOVEMENT_BUTTON)
    LeftClickOnly(movementButton, function()
        PlayClick()
        ns.ToggleMovement()
    end)
    movementButton.tooltip = MovementButtonTooltip
    frame.movementSummary = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.movementSummary:SetPoint("LEFT", movementButton, "RIGHT", 10, 0)

    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", 80, optionsTop - 34)
    local checkLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkLabel:SetPoint("LEFT", check, "RIGHT", 4, 0)
    checkLabel:SetText(L.SHOW_MINIMAP)
    LeftClickOnly(check, function()
        if ns.SetMinimapButtonShown then
            PlayClick()
            ns.SetMinimapButtonShown(not ns.IsMinimapButtonShown())
        end
        Refresh()
    end)
    check.hit:ClearAllPoints()
    check.hit:SetPoint("TOPLEFT", check, "TOPLEFT")
    check.hit:SetPoint("BOTTOM", check, "BOTTOM")
    check.hit:SetPoint("RIGHT", checkLabel, "RIGHT", 4, 0)
    check.tooltip = MinimapTooltip
    frame.minimapCheck = check

    frame.status:SetPoint("TOPLEFT", 24, -ROWS_TOP - #ns.MODIFIERS * ROW_HEIGHT - OPTIONS_HEIGHT - 4)
    frame.status:SetPoint("RIGHT", -24, 0)
    frame.status:SetJustifyH("LEFT")
    frame.status:SetJustifyV("TOP")
    frame.status:SetHeight(42)

    frame.footer = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    frame.footer:SetPoint("BOTTOMLEFT", 24, 14)
    frame.footer:SetPoint("RIGHT", -24, 0)
    frame.footer:SetJustifyH("LEFT")
    frame.footer:SetText(L.FOOTER)

    frame:SetScript("OnShow", function()
        SetStatus(InCombatLockdown() and L.COMBAT or "", InCombatLockdown())
        Refresh()
    end)

    frame:SetScript("OnHide", function()
        StopListening()
        if movementFrame then
            movementFrame:Hide()
        end
    end)
    frame:SetToplevel(true)

    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        if not frame:IsShown() then
            return
        end
        if event == "PLAYER_REGEN_DISABLED" then
            StopListening()
            SetStatus(L.COMBAT, true)
        else
            SetStatus("")
        end
        Refresh()
    end)
end

---------------------------------------------------------------------------
-- Movement protection window
---------------------------------------------------------------------------

local MOVEMENT_WIDTH = 320
local MOVEMENT_ROW_HEIGHT = 26
local MOVEMENT_ROWS_TOP = 58

local function CreateMovementRow()
    local check = CreateFrame("CheckButton", nil, movementFrame, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check.keyText = movementFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    check.keyText:SetPoint("LEFT", check, "RIGHT", 4, 0)
    check.keyText:SetWidth(100)
    check.keyText:SetJustifyH("LEFT")
    check.keyText:SetWordWrap(false)
    check.actionText = movementFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    check.actionText:SetPoint("LEFT", check.keyText, "RIGHT", 4, 0)
    check.actionText:SetWidth(MOVEMENT_WIDTH - 172)
    check.actionText:SetJustifyH("LEFT")
    check.actionText:SetWordWrap(false)
    LeftClickOnly(check, function(button)
        if InCombatLockdown() or not button.entry then
            return
        end
        PlayClick()
        ns.SetKeyProtected(button.entry.key, not button.entry.protected)
        Refresh()
        -- Show the tooltip again, so it matches the new state.
        if GameTooltip and GameTooltip:IsOwned(button.hit) then
            button.hit:GetScript("OnEnter")(button.hit)
        end
    end)
    -- The click and the tooltip cover the whole line, labels included.
    check.hit:ClearAllPoints()
    check.hit:SetPoint("TOPLEFT", check, "TOPLEFT")
    check.hit:SetPoint("BOTTOM", check, "BOTTOM")
    check.hit:SetPoint("RIGHT", movementFrame, "RIGHT", -16, 0)
    check.tooltip = function(tooltip)
        return KeyTooltip(tooltip, check.entry)
    end
    return check
end

local function ShowMovementRow(row, shown)
    row:SetShown(shown)
    row.keyText:SetShown(shown)
    row.actionText:SetShown(shown)
    row.hit:SetShown(shown)
end

RefreshMovement = function()
    if not (movementFrame and movementFrame:IsShown()) then
        return
    end
    local locked = InCombatLockdown()
    local list = ns.GetMovementKeys()
    for index, entry in ipairs(list) do
        local row = movementFrame.rows[index]
        if not row then
            row = CreateMovementRow()
            movementFrame.rows[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 20, -MOVEMENT_ROWS_TOP - (index - 1) * MOVEMENT_ROW_HEIGHT)
        row.entry = entry
        row:SetChecked(entry.protected)
        row:SetEnabled(not locked)
        row.keyText:SetText(ns.KeyDisplayName(entry.key))
        row.actionText:SetText(ns.ActionDisplayName(entry.action))
        ShowMovementRow(row, true)
    end
    for index = #list + 1, #movementFrame.rows do
        movementFrame.rows[index].entry = nil
        ShowMovementRow(movementFrame.rows[index], false)
    end
    movementFrame.empty:SetShown(#list == 0)
    movementFrame.defaults:SetEnabled(not locked)
    movementFrame:SetHeight(MOVEMENT_ROWS_TOP + math.max(#list, 1) * MOVEMENT_ROW_HEIGHT + 56)
end

local function CreateMovementFrame()
    movementFrame = CreateFrame("Frame", "MouseShiftMovement", UIParent, "BasicFrameTemplateWithInset")
    movementFrame:SetSize(MOVEMENT_WIDTH, 200)
    movementFrame:SetFrameStrata("DIALOG")
    movementFrame:SetClampedToScreen(true)
    movementFrame:SetMovable(true)
    movementFrame:EnableMouse(true)
    movementFrame:RegisterForDrag("LeftButton")
    movementFrame:SetScript("OnDragStart", movementFrame.StartMoving)
    movementFrame:SetScript("OnDragStop", movementFrame.StopMovingOrSizing)
    movementFrame:Hide()
    tinsert(UISpecialFrames, movementFrame:GetName())
    movementFrame.rows = {}

    local title = movementFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText(L.MOVEMENT)

    local header = movementFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 20, -34)
    header:SetText(L.MOVEMENT_HEADER)

    movementFrame.empty = movementFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    movementFrame.empty:SetPoint("TOPLEFT", 24, -MOVEMENT_ROWS_TOP - 6)
    movementFrame.empty:SetText(L.MOVEMENT_EMPTY)

    movementFrame.defaults = CreateFrame("Button", nil, movementFrame, "UIPanelButtonTemplate")
    movementFrame.defaults:SetPoint("BOTTOMLEFT", 18, 14)
    movementFrame.defaults:SetSize(110, 24)
    movementFrame.defaults:SetText(L.DEFAULTS)
    LeftClickOnly(movementFrame.defaults, function()
        if InCombatLockdown() then
            return
        end
        PlayClick()
        ns.ResetMovementKeys()
        Refresh()
    end)

    local done = CreateFrame("Button", nil, movementFrame, "UIPanelButtonTemplate")
    done:SetPoint("BOTTOMRIGHT", -18, 14)
    done:SetSize(90, 24)
    done:SetText(L.DONE)
    LeftClickOnly(done, function()
        movementFrame:Hide()
    end)

    movementFrame:SetScript("OnShow", RefreshMovement)
    movementFrame:SetToplevel(true)

    -- Combat and new key bindings change what the list shows.
    movementFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    movementFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    movementFrame:RegisterEvent("UPDATE_BINDINGS")
    movementFrame:SetScript("OnEvent", RefreshMovement)
end

function ns.ToggleMovement()
    if not movementFrame then
        CreateMovementFrame()
    end
    if movementFrame:IsShown() then
        movementFrame:Hide()
        return
    end
    movementFrame:ClearAllPoints()
    if frame and frame:IsShown() then
        movementFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
    else
        movementFrame:SetPoint("CENTER")
    end
    movementFrame:Show()
    movementFrame:Raise()
end

function ns.ToggleConfig()
    if not frame then
        CreateConfigFrame()
    end
    frame:SetShown(not frame:IsShown())
end

function ns.OpenConfig()
    if not frame then
        CreateConfigFrame()
    end
    frame:Show()
end

---------------------------------------------------------------------------
-- Entry in the addon compartment (the addons button next to the minimap)
---------------------------------------------------------------------------

-- Registered from code rather than through the TOC file: WoW Forever lists a
-- TOC entry internally but does not show it in the menu, while an entry
-- registered here shows in both Retail and Forever.
local function RegisterCompartmentEntry()
    local compartment = AddonCompartmentFrame
    if not (compartment and compartment.RegisterAddon) then
        return
    end

    -- Never add a second entry, for example if this runs twice.
    if type(compartment.registeredAddons) == "table" then
        for _, entry in ipairs(compartment.registeredAddons) do
            if type(entry) == "table" and entry.text == L.TITLE and entry.func then
                return
            end
        end
    end

    compartment:RegisterAddon({
        text = L.TITLE,
        icon = "Interface\\AddOns\\MouseShift\\Media\\icon",
        notCheckable = true,
        registerForAnyClick = true,
        func = function()
            ns.ToggleConfig()
        end,
        funcOnEnter = function(owner)
            if type(owner) == "table" and owner.IsObjectType and GameTooltip then
                GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
                GameTooltip:SetText(L.TITLE)
                GameTooltip:AddLine(L.COMPARTMENT_HINT, 1, 1, 1)
                GameTooltip:Show()
            end
        end,
        funcOnLeave = function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end,
    })
end

---------------------------------------------------------------------------
-- Entry in Options > AddOns
---------------------------------------------------------------------------

local function RegisterSettingsPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return
    end

    local panel = CreateFrame("Frame")

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.TITLE)

    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    text:SetText(L.PANEL_TEXT)

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
    open:SetSize(180, 26)
    open:SetText(L.OPEN)
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then
            HideUIPanel(SettingsPanel)
        end
        ns.OpenConfig()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, L.TITLE)
    Settings.RegisterAddOnCategory(category)
end

-- Register in the addon compartment as soon as the addon loads, like most
-- addons do: WoW Forever builds its list of addon buttons early and may not
-- add entries registered later. Login tries again in case the compartment
-- did not exist yet; an existing entry is never added twice.
RegisterCompartmentEntry()

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    RegisterSettingsPanel()
    RegisterCompartmentEntry()
end)
