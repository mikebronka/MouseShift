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
        if not row.clear:IsEnabled() then
            row.clear:UnlockHighlight()
        end
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

    hit:SetScript("OnEnter", function()
        if button:IsEnabled() then
            button:LockHighlight()
        end
    end)
    hit:SetScript("OnLeave", function()
        button:UnlockHighlight()
        if button:IsEnabled() then
            button:SetButtonState("NORMAL")
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

    row.clear = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    row.clear:SetPoint("LEFT", row.capture, "RIGHT", 6, 0)
    row.clear:SetSize(60, 26)
    row.clear:SetText(L.CLEAR)
    row.clear.modifier = modifier
    LeftClickOnly(row.clear, OnClearClick)

    row.count = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.count:SetPoint("LEFT", row.clear, "RIGHT", 8, 0)
    row.count:SetWidth(COUNT_WIDTH)
    row.count:SetJustifyH("LEFT")
    row.count:SetWordWrap(false)

    return row
end

local function CreateConfigFrame()
    frame = CreateFrame("Frame", "MouseShiftConfig", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WINDOW_WIDTH, ROWS_TOP + #ns.MODIFIERS * ROW_HEIGHT + 90)
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
    frame.status:SetPoint("TOPLEFT", 24, -ROWS_TOP - #ns.MODIFIERS * ROW_HEIGHT - 4)
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
