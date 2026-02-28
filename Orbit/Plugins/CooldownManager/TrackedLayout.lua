---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local TRACKED_INDEX = Constants.Cooldown.SystemIndex.Tracked
local MAX_GRID_SIZE = 10
local TRACKED_ADD_ICON = "Interface\\PaperDollInfoFrame\\Character-Plus"
local EDGE_GLOW_ALPHA = 0.6

-- [ MODULE ]----------------------------------------------------------------------------------------
Orbit.TrackedLayout = {}
local Layout = Orbit.TrackedLayout

-- [ GRID HELPERS ]----------------------------------------------------------------------------------
function Layout.GridKey(x, y) return x .. "," .. y end
function Layout.ParseGridKey(key)
    local x, y = key:match("^(-?%d+),(-?%d+)$")
    return tonumber(x), tonumber(y)
end

-- [ USABILITY HELPERS ]-----------------------------------------------------------------------------
local function IsSpellUsable(spellId)
    if not spellId then return false end
    if IsSpellKnown(spellId) or IsPlayerSpell(spellId) then return true end
    local activeId = FindSpellOverrideByID(spellId)
    return activeId ~= spellId and (IsSpellKnown(activeId) or IsPlayerSpell(activeId))
end

local function IsItemUsable(itemId)
    if not itemId then return false end
    local usable, noMana = C_Item.IsUsableItem(itemId)
    if usable or noMana then return true end
    return C_Item.GetItemCount(itemId, false, true) > 0
end

local function HasItemTexture(itemId)
    return itemId and C_Item.GetItemIconByID(itemId) ~= nil
end

function Layout.IsGridItemUsable(data)
    if data.type == "spell" then return IsSpellUsable(data.id) end
    if data.type == "item" then return IsItemUsable(data.id) or HasItemTexture(data.id) end
    return false
end

-- [ USABILITY CHANGE DETECTION ]--------------------------------------------------------------------
function Layout:HasUsabilityChanged(anchor)
    local rawGridItems = anchor.gridItems
    if not rawGridItems then return false end
    local prev = anchor._lastUsableSet or {}
    for key, data in pairs(rawGridItems) do
        local nowUsable = Layout.IsGridItemUsable(data)
        if nowUsable and not prev[key] then return true end
        if not nowUsable and prev[key] then return true end
    end
    return false
end

-- [ EDGE BUTTON FACTORY ]---------------------------------------------------------------------------
local function CreateEdgeButton(anchor, index)
    local btn = CreateFrame("Frame", nil, anchor)
    btn.Backdrop = btn:CreateTexture(nil, "BACKGROUND")
    btn.Backdrop:SetAllPoints()
    btn.Backdrop:SetColorTexture(0, 0, 0, 0.2)
    btn.Glow = btn:CreateTexture(nil, "OVERLAY")
    btn.Glow:SetAtlas("cyphersetupgrade-leftitem-slotinnerglow")
    btn.Glow:SetBlendMode("ADD")
    btn.Glow:SetAllPoints()
    btn.Plus = btn:CreateTexture(nil, "OVERLAY", nil, 2)
    btn.Plus:SetPoint("CENTER")
    btn.Plus:SetTexture(TRACKED_ADD_ICON)
    btn.PulseAnim = btn:CreateAnimationGroup()
    btn.PulseAnim:SetLooping("BOUNCE")
    local pulse = btn.PulseAnim:CreateAnimation("Alpha")
    pulse:SetTarget(btn.Glow)
    pulse:SetDuration(1)
    pulse:SetFromAlpha(0.4)
    pulse:SetToAlpha(1)
    btn:EnableMouse(true)
    anchor.edgeButtons[index] = btn
    return btn
end

local function SizeEdgeButton(btn, iconWidth, iconHeight, Pixel)
    btn:SetSize(iconWidth, iconHeight)
    local plusSize = Pixel and Pixel:Snap(math.min(iconWidth, iconHeight) * 0.4) or (math.min(iconWidth, iconHeight) * 0.4)
    btn.Plus:SetSize(plusSize, plusSize)
end

-- [ LAYOUT MAIN ]-----------------------------------------------------------------------------------
function Layout:LayoutTrackedIcons(plugin, anchor, systemIndex, isDraggingFn)
    if not anchor then return end

    local IconFactory = Orbit.TrackedIconFactory
    local Updater = Orbit.TrackedUpdater
    local viewerMap = plugin.viewerMap
    local parentIndex = CooldownUtils:GetInheritedParentIndex(anchor, viewerMap)
    local overrides = parentIndex
            and {
                aspectRatio = plugin:GetSetting(parentIndex, "aspectRatio"),
                size = plugin:GetSetting(parentIndex, "IconSize"),
                padding = plugin:GetSetting(parentIndex, "IconPadding"),
            }
        or nil
    local iconWidth, iconHeight = CooldownUtils:CalculateIconDimensions(plugin, systemIndex, overrides)
    local rawPadding = (overrides and overrides.padding) or plugin:GetSetting(systemIndex, "IconPadding") or Constants.Cooldown.DefaultPadding
    local Pixel = OrbitEngine.Pixel
    local padding = Pixel and Pixel:Snap(rawPadding) or rawPadding

    local rawGridItems = anchor.gridItems or {}
    local isDragging = isDraggingFn and isDraggingFn() or false
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()

    local gridItems = {}
    local usableSnapshot = {}
    for key, data in pairs(rawGridItems) do
        if Layout.IsGridItemUsable(data) then
            gridItems[key] = data
            usableSnapshot[key] = true
        end
    end
    anchor._lastUsableSet = usableSnapshot

    for _, icon in pairs(anchor.activeIcons or {}) do icon:Hide() end
    for _, btn in pairs(anchor.edgeButtons or {}) do btn:Hide() end

    local minX, maxX, minY, maxY
    local hasItems = false
    for key, _ in pairs(gridItems) do
        local x, y = Layout.ParseGridKey(key)
        if x then
            if not hasItems then
                minX, maxX, minY, maxY = x, x, y, y
                hasItems = true
            else
                minX, maxX = math.min(minX, x), math.max(maxX, x)
                minY, maxY = math.min(minY, y), math.max(maxY, y)
            end
        end
    end
    if not hasItems then minX, maxX, minY, maxY = 0, 0, 0, 0 end

    -- Empty grid: show seed button or hide
    if not hasItems then
        for _, placeholder in ipairs(anchor.placeholders or {}) do placeholder:Hide() end
        if isEditMode or isDragging then
            anchor.edgeButtons = anchor.edgeButtons or {}
            local btn = anchor.edgeButtons[1] or CreateEdgeButton(anchor, 1)
            SizeEdgeButton(btn, iconWidth, iconHeight, Pixel)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
            btn:SetScript("OnMouseDown", function() plugin:OnEdgeAddButtonClick(anchor, 0, 0) end)
            btn:Show()
            if isDragging then btn.PulseAnim:Play() else btn.PulseAnim:Stop(); btn.Glow:SetAlpha(EDGE_GLOW_ALPHA) end
            anchor:SetSize(iconWidth, iconHeight)
        else
            for _, b in pairs(anchor.edgeButtons or {}) do b:Hide() end
            anchor:SetSize(iconWidth, iconHeight)
        end
        return
    end

    for _, placeholder in ipairs(anchor.placeholders or {}) do placeholder:Hide() end
    if not anchor.recyclePool then anchor.recyclePool = {} end
    if not anchor.activeIcons then anchor.activeIcons = {} end

    IconFactory:ReleaseTrackedIcons(anchor)

    local Parser = Orbit.TrackedTooltipParser
    local BuildPhaseCurve = function(a, c) return Parser:BuildPhaseCurve(a, c) end

    for key, data in pairs(gridItems) do
        local x, y = Layout.ParseGridKey(key)
        local icon = IconFactory:AcquireTrackedIcon(plugin, anchor, systemIndex)

        icon.gridX, icon.gridY = x, y
        icon.trackedType = data.type
        icon.trackedId = data.id
        icon.activeDuration = data.activeDuration
        icon.cooldownDuration = data.cooldownDuration
        local hasActive = data.activeDuration and data.cooldownDuration
        icon.desatCurve = hasActive and BuildPhaseCurve(data.activeDuration, data.cooldownDuration) or nil
        icon.cdAlphaCurve = hasActive and BuildPhaseCurve(data.activeDuration, data.cooldownDuration) or nil
        if data.type == "spell" and C_Spell.GetSpellCharges then
            local ci = C_Spell.GetSpellCharges(data.id)
            if ci and ci.maxCharges and not issecretvalue(ci.maxCharges) then
                icon.isChargeSpell = ci.maxCharges > 1
                if icon.isChargeSpell then
                    icon._maxCharges = ci.maxCharges
                    icon._trackedCharges = ci.currentCharges or ci.maxCharges
                    icon._knownRechargeDuration = ci.cooldownDuration
                end
            else
                icon.isChargeSpell = icon._maxCharges and icon._maxCharges > 1 or false
            end
        end

        Updater:UpdateTrackedIcon(plugin, icon)
        IconFactory:ApplyTrackedIconSkin(plugin, icon, systemIndex, overrides)

        icon:SetSize(iconWidth, iconHeight)
        icon.Icon:ClearAllPoints()
        icon.Icon:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        icon.Icon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        if icon.Cooldown then
            icon.Cooldown:ClearAllPoints()
            icon.Cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
            icon.Cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        end
        if icon.ActiveCooldown then
            icon.ActiveCooldown:ClearAllPoints()
            icon.ActiveCooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
            icon.ActiveCooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        end
        if icon.TextOverlay then icon.TextOverlay:SetAllPoints() end
        if icon.DropHighlight then icon.DropHighlight:SetAllPoints() end

        local posX = (x - minX) * (iconWidth + padding)
        local posY = -(y - minY) * (iconHeight + padding)
        if Pixel then posX = Pixel:Snap(posX); posY = Pixel:Snap(posY) end
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", anchor, "TOPLEFT", posX, posY)
        icon:Show()
        anchor.activeIcons[key] = icon
    end

    Updater:UpdateTrackedIconsDisplay(plugin, anchor)

    local gridW = (maxX - minX + 1)
    local gridH = (maxY - minY + 1)
    local totalW = gridW * iconWidth + (gridW - 1) * padding
    local totalH = gridH * iconHeight + (gridH - 1) * padding

    -- Edge buttons during drag
    anchor.edgeButtons = anchor.edgeButtons or {}
    if isDragging then
        local edgePositions = {}
        local checked = {}

        local blockedDirections = {}
        local FrameAnchor = OrbitEngine.FrameAnchor
        if FrameAnchor then
            local anchorData = FrameAnchor.anchors and FrameAnchor.anchors[anchor]
            if anchorData and anchorData.edge then
                if anchorData.edge == "BOTTOM" then blockedDirections.top = true
                elseif anchorData.edge == "TOP" then blockedDirections.bottom = true
                elseif anchorData.edge == "LEFT" then blockedDirections.right = true
                elseif anchorData.edge == "RIGHT" then blockedDirections.left = true end
            end
            for child, childAnchor in pairs(FrameAnchor.anchors or {}) do
                if childAnchor.parent == anchor then
                    if childAnchor.edge == "TOP" then blockedDirections.top = true
                    elseif childAnchor.edge == "BOTTOM" then blockedDirections.bottom = true
                    elseif childAnchor.edge == "LEFT" then blockedDirections.left = true
                    elseif childAnchor.edge == "RIGHT" then blockedDirections.right = true end
                end
            end
        end

        for key, _ in pairs(gridItems) do
            local x, y = Layout.ParseGridKey(key)
            if x then
                local neighbors = {}
                local blockLeft = blockedDirections.left and x == minX
                local blockRight = blockedDirections.right and x == maxX
                local blockTop = blockedDirections.top and y == minY
                local blockBottom = blockedDirections.bottom and y == maxY
                if not blockLeft then table.insert(neighbors, { x = x - 1, y = y }) end
                if not blockRight then table.insert(neighbors, { x = x + 1, y = y }) end
                if not blockTop then table.insert(neighbors, { x = x, y = y - 1 }) end
                if not blockBottom then table.insert(neighbors, { x = x, y = y + 1 }) end
                for _, n in ipairs(neighbors) do
                    local nKey = Layout.GridKey(n.x, n.y)
                    if not gridItems[nKey] and not checked[nKey] then
                        if n.x >= -MAX_GRID_SIZE and n.x <= MAX_GRID_SIZE and n.y >= -MAX_GRID_SIZE and n.y <= MAX_GRID_SIZE then
                            table.insert(edgePositions, { x = n.x, y = n.y })
                            checked[nKey] = true
                        end
                    end
                end
            end
        end

        local extendedMinX, extendedMaxX = minX, maxX
        local extendedMinY, extendedMaxY = minY, maxY
        for _, pos in ipairs(edgePositions) do
            extendedMinX = math.min(extendedMinX, pos.x)
            extendedMaxX = math.max(extendedMaxX, pos.x)
            extendedMinY = math.min(extendedMinY, pos.y)
            extendedMaxY = math.max(extendedMaxY, pos.y)
        end

        for i, pos in ipairs(edgePositions) do
            local btn = anchor.edgeButtons[i] or CreateEdgeButton(anchor, i)
            btn.edgeX = pos.x
            btn.edgeY = pos.y
            btn:SetScript("OnMouseDown", function() plugin:OnEdgeAddButtonClick(anchor, pos.x, pos.y) end)
            SizeEdgeButton(btn, iconWidth, iconHeight, Pixel)
            local posX = (pos.x - extendedMinX) * (iconWidth + padding)
            local posY = -(pos.y - extendedMinY) * (iconHeight + padding)
            if Pixel then posX = Pixel:Snap(posX); posY = Pixel:Snap(posY) end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", anchor, "TOPLEFT", posX, posY)
            btn:Show()
            btn.PulseAnim:Play()
        end

        local extendedW = (extendedMaxX - extendedMinX + 1)
        local extendedH = (extendedMaxY - extendedMinY + 1)
        totalW = extendedW * iconWidth + (extendedW - 1) * padding
        totalH = extendedH * iconHeight + (extendedH - 1) * padding

        for key, icon in pairs(anchor.activeIcons) do
            local posX = (icon.gridX - extendedMinX) * (iconWidth + padding)
            local posY = -(icon.gridY - extendedMinY) * (iconHeight + padding)
            if Pixel then posX = Pixel:Snap(posX); posY = Pixel:Snap(posY) end
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", anchor, "TOPLEFT", posX, posY)
        end
    end

    anchor:SetSize(math.max(totalW, iconWidth), math.max(totalH, iconHeight))
end
