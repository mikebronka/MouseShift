-- MouseShift
-- Copyright (c) 2026 Mike Bronka - https://www.mikebronka.com
-- Released under the MIT License.
--
-- Debug: /mouseshift status builds a plain text report of the settings, the
-- bindings in effect, the internal state and the last events, and shows it
-- in a window ready to copy. The last report is also kept in the saved
-- variables, so it ends up in a file on the next /reload or logout.

local ADDON_NAME, ns = ...

local L = {
    TITLE = "MouseShift status",
    HINT = "Press Ctrl+C (Cmd+C on a Mac) to copy the report, then paste it into your message.",
}

local statusFrame

local function YesNo(value)
    return value and "yes" or "no"
end

local function GetAddOnList()
    local api = C_AddOns or {}
    local count = (api.GetNumAddOns or GetNumAddOns or function() return 0 end)() or 0
    local getInfo = api.GetAddOnInfo or GetAddOnInfo
    local isLoaded = api.IsAddOnLoaded or IsAddOnLoaded
    local getMetadata = api.GetAddOnMetadata or GetAddOnMetadata
    local list = {}
    for index = 1, count do
        local name = getInfo and getInfo(index)
        if name and isLoaded and isLoaded(name) then
            local version = getMetadata and getMetadata(name, "Version")
            list[#list + 1] = version and version ~= "" and (name .. " " .. version) or name
        end
    end
    table.sort(list)
    return list
end

-- Builds the report as plain text, one line per item.
function ns.BuildStatusReport()
    local lines = {}
    local function add(text)
        lines[#lines + 1] = text
    end

    local state = ns.GetState()
    local version, build, _, interface = GetBuildInfo()

    add("MouseShift status report")
    add(("Time: %s"):format(date("%Y-%m-%d %H:%M:%S")))
    add(("MouseShift: %s"):format(ns.GetVersion()))
    add(("Game: %s (build %s, interface %s), %s"):format(tostring(version), tostring(build),
        tostring(interface), tostring(GetLocale and GetLocale() or "?")))
    add(("In combat: %s. Bindings to check again after combat: %s"):format(
        YesNo(InCombatLockdown()), YesNo(state.rebuildPending)))
    add("")

    add("Assigned buttons and keys:")
    local any = false
    for _, modifier in ipairs(ns.MODIFIERS) do
        local key = ns.GetTrigger(modifier)
        if key then
            any = true
            local expected = ("CLICK %s:%s"):format(state.driverName, modifier)
            local actual = GetBindingAction(key, true) or ""
            local check = actual == expected and "OK" or ("PROBLEM, bound to: " .. (actual ~= "" and actual or "nothing"))
            local button = ns.KeyToMouseButton(key)
            local physical = ""
            if button and IsMouseButtonDown then
                physical = ", physically down: " .. YesNo(IsMouseButtonDown(button))
            end
            add(("  %s: %s (%s), held: %s%s, binding %s"):format(modifier, key, ns.KeyDisplayName(key),
                YesNo(state.held[modifier]), physical, check))
        end
    end
    if not any then
        add("  none")
    end
    add(("Layer on now: %s"):format(ns.LayerName(state.activeMask)))
    if state.activeMask ~= 0 then
        local wrong = {}
        for _, entry in ipairs(ns.layers[state.activeMask] or {}) do
            local actual = GetBindingAction(entry.key, true) or ""
            if actual ~= entry.action then
                wrong[#wrong + 1] = ("%s is %s, should be %s"):format(entry.key, actual ~= "" and actual or "nothing", entry.action)
            end
        end
        add("  Layer keys bound as expected: " .. (#wrong == 0 and "yes" or ("NO: " .. table.concat(wrong, "; "))))
    end
    add(("Mouse buttons seen held: %s"):format(#state.verifiedButtons > 0 and table.concat(state.verifiedButtons, ", ") or "none"))
    add("")

    add("Layers:")
    any = false
    for mask = 1, 7 do
        local layer = ns.layers[mask]
        if layer then
            any = true
            local skipped = ns.skipped[mask] or {}
            add(("  %s: %d keys%s"):format(ns.LayerName(mask), #layer,
                #skipped > 0 and (", skipped " .. #skipped) or ""))
            local keys = {}
            for _, entry in ipairs(layer) do
                keys[#keys + 1] = ("%s=%s"):format(entry.key, entry.action)
            end
            if #keys > 0 then
                add("    " .. table.concat(keys, "; "))
            end
            local skippedKeys = {}
            for _, entry in ipairs(skipped) do
                skippedKeys[#skippedKeys + 1] = ("%s=%s"):format(entry.key, entry.action)
            end
            if #skippedKeys > 0 then
                add("    skipped: " .. table.concat(skippedKeys, "; "))
            end
        end
    end
    if not any then
        add("  none")
    end
    add("")

    add("Movement keys:")
    local movement = ns.GetMovementKeys()
    for _, entry in ipairs(movement) do
        add(("  %s %s: %s%s"):format(entry.key, entry.action, entry.protected and "protected" or "free",
            entry.isDefault and "" or " (changed)"))
    end
    if #movement == 0 then
        add("  none")
    end
    add("")

    if ns.GetPassThroughState then
        local pass = ns.GetPassThroughState()
        add(("Unit frames: mouse buttons passed through: %s, on %d frames, update waiting for combat to end: %s"):format(
            #pass.buttons > 0 and table.concat(pass.buttons, ", ") or "none", pass.frames, YesNo(pass.pending)))
    end
    add(("Minimap button: %s"):format(ns.IsMinimapButtonShown and YesNo(ns.IsMinimapButtonShown()) or "?"))
    add("")

    add("Loaded addons:")
    local addons = GetAddOnList()
    add("  " .. (#addons > 0 and table.concat(addons, ", ") or "none found"))
    add("")

    local log, pressLog = ns.GetLog()
    add("Last events:")
    for _, entry in ipairs(log) do
        add("  " .. entry)
    end
    if #log == 0 then
        add("  none")
    end
    add("")
    add("Last presses of the assigned buttons:")
    for _, entry in ipairs(pressLog) do
        add("  " .. entry)
    end
    if #pressLog == 0 then
        add("  none")
    end

    return table.concat(lines, "\n")
end

local function CreateStatusFrame()
    statusFrame = CreateFrame("Frame", "MouseShiftStatus", UIParent, "BasicFrameTemplateWithInset")
    statusFrame:SetSize(620, 460)
    statusFrame:SetPoint("CENTER")
    statusFrame:SetFrameStrata("DIALOG")
    statusFrame:SetToplevel(true)
    statusFrame:SetClampedToScreen(true)
    statusFrame:SetMovable(true)
    statusFrame:EnableMouse(true)
    statusFrame:RegisterForDrag("LeftButton")
    statusFrame:SetScript("OnDragStart", statusFrame.StartMoving)
    statusFrame:SetScript("OnDragStop", statusFrame.StopMovingOrSizing)
    statusFrame:Hide()
    tinsert(UISpecialFrames, statusFrame:GetName())

    local title = statusFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText(L.TITLE)

    local hint = statusFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hint:SetPoint("TOPLEFT", 16, -34)
    hint:SetText(L.HINT)

    local scroll = CreateFrame("ScrollFrame", "MouseShiftStatusScroll", statusFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -58)
    scroll:SetPoint("BOTTOMRIGHT", -34, 14)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(560)
    edit:SetScript("OnEscapePressed", function()
        statusFrame:Hide()
    end)
    -- The report is read-only: any typing puts it back as it was.
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(statusFrame.report or "")
            self:HighlightText()
        end
    end)
    scroll:SetScrollChild(edit)
    statusFrame.edit = edit
end

function ns.ShowStatus()
    local report = ns.BuildStatusReport()
    if ns.db then
        ns.db.lastReport = report
    end
    if not statusFrame then
        CreateStatusFrame()
    end
    statusFrame.report = report
    statusFrame:Show()
    statusFrame:Raise()
    statusFrame.edit:SetText(report)
    -- Out of combat the report is selected, ready to copy. In combat it does
    -- not take the keyboard, so keys keep working: click it to select.
    if not InCombatLockdown() then
        statusFrame.edit:SetFocus()
        statusFrame.edit:HighlightText()
    end
    ns.Print("Status report ready. It is also saved to MouseShift.lua in your SavedVariables folder after /reload.")
end
