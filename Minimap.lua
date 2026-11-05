-- MouseShift
-- Copyright (c) 2026 Mike Bronka - https://www.mikebronka.com
-- Released under the MIT License.
--
-- Minimap: a button on the minimap that opens the settings window.
--
-- MouseShift ships no libraries. When another addon has already loaded
-- LibDBIcon (most addons with a minimap button do), MouseShift registers its
-- button through it, so interfaces that collect minimap buttons into a bar
-- (ElvUI, EllesmereUI and others) pick it up like any other. Without
-- LibDBIcon, MouseShift creates a simple button of its own that can be
-- dragged around the edge of the minimap.

local ADDON_NAME, ns = ...

local ICON = "Interface\\AddOns\\MouseShift\\Media\\icon"
local TITLE = "MouseShift"
local HINT_CLICK = "Click to open the settings."
local HINT_DRAG = "Drag to move this button."
local HINT_HIDE = "Hide it in the settings window."

local libIcon -- LibDBIcon, when used
local ownButton -- the fallback button, when used

local function ShowTooltip(tooltip, canDrag)
    tooltip:AddLine(TITLE)
    tooltip:AddLine(HINT_CLICK, 1, 1, 1)
    if canDrag then
        tooltip:AddLine(HINT_DRAG, 1, 1, 1)
    end
    tooltip:AddLine(HINT_HIDE, 0.7, 0.7, 0.7)
end

local function OnButtonClick(_, mouseButton)
    if mouseButton == nil or mouseButton == "LeftButton" then
        ns.ToggleConfig()
    end
end

---------------------------------------------------------------------------
-- Through LibDBIcon, when another addon loaded it
---------------------------------------------------------------------------

local function RegisterWithLibDBIcon()
    local libStub = _G.LibStub
    if type(libStub) ~= "table" or not libStub.GetLibrary then
        return false
    end
    local dataBroker = libStub:GetLibrary("LibDataBroker-1.1", true)
    local dbIcon = libStub:GetLibrary("LibDBIcon-1.0", true)
    if not (dataBroker and dbIcon) then
        return false
    end

    local launcher = dataBroker:GetDataObjectByName(ADDON_NAME)
        or dataBroker:NewDataObject(ADDON_NAME, {
            type = "launcher",
            text = TITLE,
            icon = ICON,
            OnClick = OnButtonClick,
            OnTooltipShow = function(tooltip)
                ShowTooltip(tooltip, true)
            end,
        })
    if not launcher then
        return false
    end

    if not (dbIcon.IsRegistered and dbIcon:IsRegistered(ADDON_NAME)) then
        dbIcon:Register(ADDON_NAME, launcher, ns.db.minimap)
    end
    libIcon = dbIcon
    return true
end

---------------------------------------------------------------------------
-- Own button, when LibDBIcon is not available
---------------------------------------------------------------------------

-- Places the button on the edge of the minimap at the saved angle.
local function PlaceOwnButton()
    local angle = math.rad(ns.db.minimap.minimapPos or 220)
    local radius = (Minimap:GetWidth() / 2) + 5
    ownButton:ClearAllPoints()
    ownButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnOwnButtonUpdate()
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    ns.db.minimap.minimapPos = math.deg(math.atan2(cursorY - centerY, cursorX - centerX)) % 360
    PlaceOwnButton()
end

local function CreateOwnButton()
    local button = CreateFrame("Button", "MouseShiftMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("CENTER")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", OnButtonClick)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnOwnButtonUpdate)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        ShowTooltip(GameTooltip, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ownButton = button
    PlaceOwnButton()
end

---------------------------------------------------------------------------
-- Public functions
---------------------------------------------------------------------------

function ns.IsMinimapButtonShown()
    return ns.db and not ns.db.minimap.hide
end

function ns.SetMinimapButtonShown(show)
    if not ns.db then
        return
    end
    ns.db.minimap.hide = not show
    if libIcon then
        if show then
            libIcon:Show(ADDON_NAME)
        else
            libIcon:Hide(ADDON_NAME)
        end
    elseif ownButton then
        ownButton:SetShown(show)
    end
    if ns.OnMinimapButtonChanged then
        ns.OnMinimapButtonChanged()
    end
end

-- Which way the button was made, for /mouseshift list and the tests.
function ns.MinimapButtonKind()
    if libIcon then
        return "LibDBIcon"
    elseif ownButton then
        return "own"
    end
    return nil
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------

-- Runs at login, when every addon has loaded, so a LibDBIcon loaded by
-- another addon is found regardless of the order addons load in.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if not ns.db or not Minimap then
        return
    end
    if not RegisterWithLibDBIcon() then
        CreateOwnButton()
        ownButton:SetShown(not ns.db.minimap.hide)
    end
end)
