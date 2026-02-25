-- [ CANVAS MODE - DOCK ]------------------------------------------------------------
-- Disabled Components Dock: vertical column on LEFT side of viewport
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog
local C = CanvasMode.Constants
local Layout = OrbitEngine.Layout

-- [ DOCK FRAME ]-------------------------------------------------------------------------

Dialog.DisabledDock = CreateFrame("Frame", nil, Dialog.PreviewContainer)
Dialog.DisabledDock:SetPoint("BOTTOMLEFT", Dialog.PreviewContainer, "BOTTOMLEFT", 4, 4)
Dialog.DisabledDock:SetPoint("BOTTOMRIGHT", Dialog.PreviewContainer, "BOTTOMRIGHT", -4, 4)
Dialog.DisabledDock:SetHeight(C.DOCK_HEIGHT)
Dialog.DisabledDock:SetFrameLevel(Dialog.PreviewContainer:GetFrameLevel() + 50)

-- Dock hint text (shown when empty)
Dialog.DisabledDock.EmptyHint = Dialog.DisabledDock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Dialog.DisabledDock.EmptyHint:SetPoint("CENTER", Dialog.DisabledDock, "CENTER", 0, 0)
Dialog.DisabledDock.EmptyHint:SetText("drag here to disable")
Dialog.DisabledDock.EmptyHint:SetTextColor(0.6, 0.6, 0.6, 0.15)

-- Container for dock component icons (horizontal row)
Dialog.DisabledDock.IconContainer = CreateFrame("Frame", nil, Dialog.DisabledDock)
Dialog.DisabledDock.IconContainer:SetPoint("TOPLEFT", Dialog.DisabledDock, "TOPLEFT", C.DOCK_PADDING, -C.DOCK_PADDING)
Dialog.DisabledDock.IconContainer:SetPoint("BOTTOMRIGHT", Dialog.DisabledDock, "BOTTOMRIGHT", -C.DOCK_PADDING, C.DOCK_PADDING)

-- Drop highlight for dock
Dialog.DisabledDock.DropHighlight = Dialog.DisabledDock:CreateTexture(nil, "ARTWORK")
Dialog.DisabledDock.DropHighlight:SetAllPoints()
Dialog.DisabledDock.DropHighlight:SetColorTexture(0.3, 0.8, 0.3, 0.2)
Dialog.DisabledDock.DropHighlight:Hide()



-- [ DOCK LAYOUT ]------------------------------------------------------------------------

function Dialog:LayoutDockIcons()
    local x = 0
    local iconCount = 0

    for key, icon in pairs(self.dockComponents) do
        if icon:IsShown() then
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", self.DisabledDock.IconContainer, "TOPLEFT", x, 0)
            x = x + C.DOCK_ICON_SIZE + C.DOCK_ICON_SPACING
            iconCount = iconCount + 1
        end
    end

end

-- [ ADD TO DOCK ]------------------------------------------------------------------------

function Dialog:AddToDock(key, sourceComponent)
    if self.dockComponents[key] then return end

    local icon = CreateFrame("Button", nil, self.DisabledDock.IconContainer)
    icon:SetSize(C.DOCK_ICON_SIZE, C.DOCK_ICON_SIZE)
    icon.key = key

    icon.bg = icon:CreateTexture(nil, "BACKGROUND")
    icon.bg:SetAllPoints()
    icon.bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)

    local isTexture = sourceComponent and sourceComponent.GetTexture
    local isFontString = sourceComponent and sourceComponent.GetFont ~= nil
    local isIconFrame = sourceComponent and sourceComponent.Icon and sourceComponent.Icon.GetTexture

    if isTexture and not isFontString then
        icon.visual = icon:CreateTexture(nil, "OVERLAY")
        icon.visual:SetPoint("CENTER")
        icon.visual:SetSize(C.DOCK_ICON_SIZE - 4, C.DOCK_ICON_SIZE - 4)

        local atlasName = sourceComponent.GetAtlas and sourceComponent:GetAtlas()
        if atlasName then
            icon.visual:SetAtlas(atlasName)
        else
            local texturePath = sourceComponent:GetTexture()
            if texturePath then icon.visual:SetTexture(texturePath) end

            if sourceComponent.GetTexCoord then
                local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = sourceComponent:GetTexCoord()
                if ULx and ULy then
                    if LRx then
                        icon.visual:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
                    else
                        icon.visual:SetTexCoord(ULx, ULy, LLx, LLy)
                    end
                end
            end

            if key == "MarkerIcon" then
                local tc = Orbit.MarkerIconTexCoord
                if tc then icon.visual:SetTexCoord(tc[1], tc[2], tc[3], tc[4]) end
            end

            if sourceComponent.orbitSpriteIndex then
                local index = sourceComponent.orbitSpriteIndex
                local rows = sourceComponent.orbitSpriteRows or 4
                local cols = sourceComponent.orbitSpriteCols or 4
                local col = (index - 1) % cols
                local row = math.floor((index - 1) / cols)
                local w, h = 1 / cols, 1 / rows
                icon.visual:SetTexCoord(col * w, (col + 1) * w, row * h, (row + 1) * h)
            end
        end

        icon.visual:SetDesaturated(true)
        icon.visual:SetAlpha(0.7)
    elseif isIconFrame then
        icon.visual = icon:CreateTexture(nil, "OVERLAY")
        icon.visual:SetPoint("CENTER")
        icon.visual:SetSize(C.DOCK_ICON_SIZE - 4, C.DOCK_ICON_SIZE - 4)

        local iconTex = sourceComponent.Icon
        local texturePath = iconTex and iconTex:GetTexture()
        local StatusMixin = Orbit.StatusIconMixin
        if texturePath then
            icon.visual:SetTexture(texturePath)
        elseif StatusMixin and key == "DefensiveIcon" then
            icon.visual:SetTexture(StatusMixin:GetDefensiveTexture())
        elseif StatusMixin and key == "CrowdControlIcon" then
            icon.visual:SetTexture(StatusMixin:GetCrowdControlTexture())
        else
            local previewAtlases = Orbit.IconPreviewAtlases or {}
            if previewAtlases[key] then icon.visual:SetAtlas(previewAtlases[key], false) end
        end

        icon.visual:SetDesaturated(true)
        icon.visual:SetAlpha(0.7)
    elseif key == "Portrait" then
        icon.visual = icon:CreateTexture(nil, "OVERLAY")
        icon.visual:SetPoint("CENTER")
        icon.visual:SetSize(C.DOCK_ICON_SIZE - 4, C.DOCK_ICON_SIZE - 4)
        SetPortraitTexture(icon.visual, "player")
        icon.visual:SetDesaturated(true)
        icon.visual:SetAlpha(0.7)
    else
        icon.visual = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        icon.visual:SetPoint("CENTER")
        icon.visual:SetText(key:sub(1, 4))
        icon.visual:SetTextColor(0.7, 0.7, 0.7, 1)
    end

    icon:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.3, 0.5, 0.3, 0.8)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(key, 1, 1, 1)
        GameTooltip:AddLine("Click to enable", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    icon:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.6)
        GameTooltip:Hide()
    end)

    icon:SetScript("OnClick", function(self)
        Dialog:RestoreFromDock(self.key)
    end)

    self.dockComponents[key] = icon

    local alreadyTracked = false
    for _, k in ipairs(self.disabledComponentKeys) do
        if k == key then alreadyTracked = true break end
    end
    if not alreadyTracked then table.insert(self.disabledComponentKeys, key) end

    self:LayoutDockIcons()

    -- The paladin swaps their oath; HealthText and Status can't both be on the field
    if not self._exclusiveSwapping then
        local EXCLUSIVE_PAIRS = { HealthText = "Status", Status = "HealthText" }
        local partner = EXCLUSIVE_PAIRS[key]
        if partner and self.dockComponents[partner] then
            self._exclusiveSwapping = true
            self:RestoreFromDock(partner)
            self._exclusiveSwapping = nil
        end
    end
end

-- [ REMOVE FROM DOCK ]-------------------------------------------------------------------

function Dialog:RemoveFromDock(key)
    local icon = self.dockComponents[key]
    if icon then
        icon:Hide()
        icon:SetParent(nil)
        self.dockComponents[key] = nil
    end

    for i, k in ipairs(self.disabledComponentKeys) do
        if k == key then table.remove(self.disabledComponentKeys, i) break end
    end

    self:LayoutDockIcons()
end

-- [ RESTORE FROM DOCK ]------------------------------------------------------------------

function Dialog:RestoreFromDock(key)
    local dockIcon = self.dockComponents[key]

    if dockIcon and dockIcon.storedSubFrame then
        local subFrame = dockIcon.storedSubFrame
        subFrame:Show()
        self:RemoveFromDock(key)
        return
    end

    local storedComp = dockIcon and dockIcon.storedDraggableComp

    self:RemoveFromDock(key)

    if storedComp then
        storedComp:Show()
        Dialog.previewComponents[key] = storedComp
        if Dialog.activeFilter and Dialog.activeFilter ~= "All" then Dialog:ApplyFilter(Dialog.activeFilter) end
        return
    end

    local savedPositions = self.targetPlugin and self.targetPlugin:GetSetting(self.targetSystemIndex, "ComponentPositions") or {}
    local pos = savedPositions[key]

    local dragComponents = OrbitEngine.ComponentDrag:GetComponentsForFrame(self.targetFrame)
    local data = dragComponents and dragComponents[key]

    if data and data.component then
        local canvasFrame = self.targetFrame.orbitCanvasFrame or self.targetFrame
        local frameW = canvasFrame:GetWidth()
        local frameH = canvasFrame:GetHeight()

        local centerX, centerY = 0, 0
        local anchorX, anchorY = "CENTER", "CENTER"
        local offsetX, offsetY = 0, 0

        if pos and pos.anchorX then
            anchorX = pos.anchorX
            anchorY = pos.anchorY or "CENTER"
            offsetX = pos.offsetX or 0
            offsetY = pos.offsetY or 0

            local halfW = frameW / 2
            local halfH = frameH / 2

            if anchorX == "LEFT" then centerX = offsetX - halfW
            elseif anchorX == "RIGHT" then centerX = halfW - offsetX end

            if anchorY == "BOTTOM" then centerY = offsetY - halfH
            elseif anchorY == "TOP" then centerY = halfH - offsetY end
        end

        local compData = {
            component = data.component,
            x = centerX, y = centerY,
            anchorX = anchorX, anchorY = anchorY,
            offsetX = offsetX, offsetY = offsetY,
            justifyH = pos and pos.justifyH or "CENTER",
            overrides = pos and pos.overrides,
            posX = pos and pos.posX, posY = pos and pos.posY,
        }

        if CanvasMode.CreateDraggableComponent then
            local comp = CanvasMode.CreateDraggableComponent(Dialog.previewFrame, key, data.component, centerX, centerY, compData)
            if comp then comp:SetFrameLevel(Dialog.previewFrame:GetFrameLevel() + 10) end
            Dialog.previewComponents[key] = comp
        end
    end
    if Dialog.activeFilter and Dialog.activeFilter ~= "All" then Dialog:ApplyFilter(Dialog.activeFilter) end

    if not self._exclusiveSwapping then
        local EXCLUSIVE_PAIRS = { HealthText = "Status", Status = "HealthText" }
        local partner = EXCLUSIVE_PAIRS[key]
        if partner and not self.dockComponents[partner] and self.previewComponents[partner] then
            self._exclusiveSwapping = true
            local comp = self.previewComponents[partner]
            comp:Hide()
            local sourceComp = comp.sourceComponent or comp.visual or comp
            self:AddToDock(partner, sourceComp)
            if self.dockComponents[partner] then
                self.dockComponents[partner].storedDraggableComp = comp
            end
            self.previewComponents[partner] = nil
            self._exclusiveSwapping = nil
        end
    end
end

-- [ CLEAR DOCK ]-------------------------------------------------------------------------

function Dialog:ClearDock()
    for key, icon in pairs(self.dockComponents) do
        icon:Hide()
        icon:SetParent(nil)
    end
    wipe(self.dockComponents)
    wipe(self.disabledComponentKeys)
    self:LayoutDockIcons()
end
