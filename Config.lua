-- MouseShift
-- Copyright (c) 2026 Mike Bronka - https://www.mikebronka.com
-- Released under the MIT License.
--
-- Config: the settings window. Each modifier has a field that is assigned
-- by clicking it with the mouse button the player wants to use, so nobody
-- has to know whether their thumb button is Button 4 or Button 5. A left
-- click starts listening for a key instead, for mice whose side buttons send
-- keyboard keys, or for any other key the player wants to use.

local _, ns = ...

local L = {
    TITLE = "MouseShift",
    INTRO = "Click a field with the mouse button you want to use, or left-click it and press a key.",
    FOOTER = "Hold the assigned button or key and press another key to use its Shift, Ctrl or Alt binding.",
    EMPTY = "Click to assign",
    LISTENING = "Press a key or mouse button",
    LISTEN_HINT = "Press the key you want to use as %s, or click the field with a mouse button. Escape cancels.",
    CLEAR = "Clear",
    KEYS_ONE = "%d binding",
    KEYS_MANY = "%d bindings",
    MAIN_BUTTONS = "The left and right mouse buttons are needed by the game and cannot be used.",
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
}

local MODIFIER_LABELS = {
    SHIFT = SHIFT_KEY_TEXT or "Shift",
    CTRL = CTRL_KEY_TEXT or "Ctrl",
    ALT = ALT_KEY_TEXT or "Alt",
}

local WINDOW_WIDTH = 420
local ROW_HEIGHT = 34

local frame
local rows = {}
local listener
local listeningRow

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
    end
end

ns.OnApplied = Refresh

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

local function OnCaptureMouseDown(self, button)
    local row = self.row
    if InCombatLockdown() then
        StopListening()
        SetStatus(L.COMBAT, true)
        Refresh()
        return
    end

    if button == "LeftButton" then
        if listeningRow == row then
            StopListening()
            SetStatus(L.CANCELLED)
            Refresh()
        else
            StartListening(row)
        end
        return
    end

    if button == "RightButton" then
        StopListening()
        SetStatus(L.MAIN_BUTTONS, true)
        Refresh()
        return
    end

    local key = ns.MouseButtonToKey(button)
    if not key then
        StopListening()
        SetStatus(L.UNSUPPORTED, true)
        Refresh()
        return
    end
    Assign(row.modifier, key)
end

-- Receives key presses while a field is listening. Keys pressed here do not
-- reach the game, so nothing is cast by accident.
local function OnListenerKeyDown(_, key)
    if not listeningRow then
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

local function CreateRow(parent, modifier, index)
    local row = { modifier = modifier }
    local top = -70 - (index - 1) * ROW_HEIGHT

    row.label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    row.label:SetPoint("TOPLEFT", 24, top - 4)
    row.label:SetWidth(56)
    row.label:SetJustifyH("LEFT")
    row.label:SetText(MODIFIER_LABELS[modifier])

    row.capture = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    row.capture:SetPoint("TOPLEFT", 84, top)
    row.capture:SetSize(200, 26)
    row.capture.row = row
    -- Hook rather than replace, so the template keeps its pressed look.
    row.capture:HookScript("OnMouseDown", OnCaptureMouseDown)

    row.clear = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    row.clear:SetPoint("LEFT", row.capture, "RIGHT", 6, 0)
    row.clear:SetSize(60, 26)
    row.clear:SetText(L.CLEAR)
    row.clear.modifier = modifier
    row.clear:SetScript("OnClick", OnClearClick)

    row.count = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.count:SetPoint("LEFT", row.clear, "RIGHT", 8, 0)
    row.count:SetJustifyH("LEFT")

    return row
end

local function CreateConfigFrame()
    frame = CreateFrame("Frame", "MouseShiftConfig", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WINDOW_WIDTH, 70 + #ns.MODIFIERS * ROW_HEIGHT + 90)
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
    frame.intro:SetPoint("TOPLEFT", 24, -36)
    frame.intro:SetPoint("RIGHT", -24, 0)
    frame.intro:SetJustifyH("LEFT")
    frame.intro:SetText(L.INTRO)

    for index, modifier in ipairs(ns.MODIFIERS) do
        rows[index] = CreateRow(frame, modifier, index)
    end

    -- Invisible frame that takes keyboard input while a field is listening.
    -- It is only shown and hidden later, which is allowed at any time.
    listener = CreateFrame("Frame", nil, frame)
    listener:SetAllPoints(frame)
    listener:EnableKeyboard(true)
    listener:SetScript("OnKeyDown", OnListenerKeyDown)
    listener:Hide()

    frame.status = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.status:SetPoint("TOPLEFT", 24, -70 - #ns.MODIFIERS * ROW_HEIGHT - 4)
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

    frame:SetScript("OnHide", StopListening)

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

-- Entry in the addon compartment (the addons button next to the minimap).
function MouseShift_OnAddonCompartmentClick()
    ns.ToggleConfig()
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

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    RegisterSettingsPanel()
end)
