local _, addonTable = ...
local Orbit = addonTable

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local FRAME_PADDING = 8
local TITLE_HEIGHT = 28
local SEARCH_HEIGHT = 22
local SEARCH_PADDING_TOP = 4
local SEARCH_PADDING_BOTTOM = 8
local SEARCH_LEFT_INSET = 70
local SEARCH_RIGHT_INSET = 14
local HEADER_BLOCK_HEIGHT = TITLE_HEIGHT + SEARCH_PADDING_TOP + SEARCH_HEIGHT + SEARCH_PADDING_BOTTOM
local FRAME_STRATA = "DIALOG"
local FRAME_LEVEL = 100
local BAG_ICON = [[Interface\ICONS\INV_Misc_Bag_08]]

-- [ MODULE ]-----------------------------------------------------------------------------------------
Orbit.BagFrame = {}
local BagFrame = Orbit.BagFrame

-- [ POSITION PERSISTENCE ]---------------------------------------------------------------------------
local function SavePosition(frame)
    if not Orbit.db or not Orbit.db.AccountSettings then return end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    Orbit.db.AccountSettings.BagPosition = {
        point = point,
        relativeTo = (relativeTo and relativeTo.GetName and relativeTo:GetName()) or "UIParent",
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function RestorePosition(frame)
    local pos = Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.BagPosition
    if not pos or not pos.point then return end
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, _G[pos.relativeTo] or UIParent, pos.relativePoint, pos.x, pos.y)
end

-- [ BUILD ]------------------------------------------------------------------------------------------
function BagFrame:Build(plugin)
    local frame = CreateFrame("Frame", "OrbitBagFrame", UIParent, "PortraitFrameTemplate")
    frame:SetSize(700, 400)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata(FRAME_STRATA)
    frame:SetFrameLevel(FRAME_LEVEL)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    if frame.SetTitle then frame:SetTitle(plugin.displayName) end
    if frame.PortraitContainer and frame.PortraitContainer.portrait then
        frame.PortraitContainer.portrait:SetTexture(BAG_ICON)
    elseif frame.portrait then
        frame.portrait:SetTexture(BAG_ICON)
    end
    local portraitAnchor = frame.PortraitContainer or frame
    if portraitAnchor and portraitAnchor.EnableMouse then
        portraitAnchor:EnableMouse(true)
        portraitAnchor:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" and Orbit.BagContextMenu and Orbit.BagContextMenu.OpenPortraitMenu then
                Orbit.BagContextMenu.OpenPortraitMenu(self)
            end
        end)
    end

    frame.count = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.count:SetPoint("RIGHT", frame.CloseButton or frame, "LEFT", -4, 0)

    frame.search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    frame.search:SetHeight(SEARCH_HEIGHT)
    frame.search:SetPoint("TOPLEFT", frame, "TOPLEFT", SEARCH_LEFT_INSET, -(TITLE_HEIGHT + SEARCH_PADDING_TOP))
    frame.search:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -SEARCH_RIGHT_INSET, -(TITLE_HEIGHT + SEARCH_PADDING_TOP))
    frame.search:SetScript("OnTextChanged", function(self, userInput)
        if userInput then C_Container.SetItemSearch(self:GetText() or "") end
    end)

    frame.workspace = Orbit.BagGrid:Build(plugin, frame, HEADER_BLOCK_HEIGHT)
    frame.plugin = plugin

    frame:HookScript("OnHide", function() plugin._isOpen = false end)

    RestorePosition(frame)
    frame:Hide()
    return frame
end

-- [ APPLY ]------------------------------------------------------------------------------------------
local function CountSlots()
    local free, total = 0, 0
    for bag = 0, 5 do
        local s = C_Container.GetContainerNumSlots(bag) or 0
        total = total + s
        free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
    end
    return free, total
end

function BagFrame:Apply(plugin, frame)
    if not frame then return end
    if not plugin._isOpen then
        frame:Hide()
        return
    end
    frame:Show()

    Orbit.BagGrid:Apply(plugin, frame.workspace)

    local ws = frame.workspace
    local topOffset = Orbit.BagGrid:GetWorkspaceTopOffset()
    local width = ws:GetWidth() + FRAME_PADDING * 2
    local height = HEADER_BLOCK_HEIGHT + topOffset + ws:GetHeight() + FRAME_PADDING * 2
    frame:SetSize(width, height)

    local free, total = CountSlots()
    frame.count:SetFormattedText("%d / %d", free, total)
end
