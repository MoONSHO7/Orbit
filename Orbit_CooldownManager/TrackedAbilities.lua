---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

-- [ TRACKED ABILITIES CONSTANTS ]-------------------------------------------------------------------
local TRACKED_INDEX = Constants.Cooldown.SystemIndex.Tracked
local TRACKED_CHILD_START = Constants.Cooldown.SystemIndex.Tracked_ChildStart
local MAX_CHILD_FRAMES = Constants.Cooldown.MaxChildFrames
local MAX_GRID_SIZE = 10
local TRACKED_PLACEHOLDER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local TRACKED_ADD_ICON = "Interface\\PaperDollInfoFrame\\Character-Plus"
local TRACKED_REMOVE_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local CONTROL_BTN_SIZE = 10
local CONTROL_BTN_SPACING = 1
local COLOR_GREEN = { r = 0.2, g = 0.9, b = 0.2 }
local COLOR_RED = { r = 0.9, g = 0.2, b = 0.2 }

-- Desaturation curve: 0% remaining (ready) = colored, >0% remaining (on CD) = grayscale
local DESAT_CURVE = C_CurveUtil.CreateCurve()
DESAT_CURVE:AddPoint(0.0, 0)
DESAT_CURVE:AddPoint(0.001, 1)
DESAT_CURVE:AddPoint(1.0, 1)

-- [ PLUGIN REFERENCE ]------------------------------------------------------------------------------
local Plugin = Orbit:GetPlugin("Orbit_CooldownViewer")
if not Plugin then error("TrackedAbilities.lua: Plugin 'Orbit_CooldownViewer' not found - ensure CooldownManager.lua loads first") end
local function GetViewerMap() return Plugin.viewerMap end

-- [ CHILD FRAME MANAGEMENT ]------------------------------------------------------------------------
Plugin.childFramePool = Plugin.childFramePool or {}
Plugin.activeChildren = Plugin.activeChildren or {}

-- [ TRACKED ANCHOR ]--------------------------------------------------------------------------------
function Plugin:CreateTrackedAnchor(name, systemIndex, label)
    local plugin = self
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(40, 40)
    frame:SetClampedToScreen(true)
    frame.systemIndex = systemIndex
    frame.editModeName = label
    frame.isTrackedBar = true
    frame:EnableMouse(true)
    frame.anchorOptions = { horizontal = true, vertical = true, syncScale = false, syncDimensions = false }
    OrbitEngine.Frame:AttachSettingsListener(frame, self, systemIndex)

    frame.Selection = frame:CreateTexture(nil, "OVERLAY")
    frame.Selection:SetColorTexture(1, 1, 1, 0.1)
    frame.Selection:SetAllPoints()
    frame.Selection:Hide()

    frame.DropHighlight = frame:CreateTexture(nil, "BORDER")
    frame.DropHighlight:SetAllPoints()
    frame.DropHighlight:SetColorTexture(0, 0, 0, 0)
    frame.DropHighlight:Hide()

    if not frame:GetPoint() then
        local yOffset = (systemIndex == TRACKED_INDEX) and -250 or -150
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, yOffset)
    end

    frame:SetScript("OnReceiveDrag", function() plugin:OnTrackedAnchorReceiveDrag(frame) end)
    frame:SetScript("OnMouseDown", function(_, button)
        if GetCursorInfo() then plugin:OnTrackedAnchorReceiveDrag(frame) end
    end)

    frame.icons = {}
    frame.placeholders = {}
    frame.recyclePool = {}
    frame.activeIcons = {}
    self:CreateTrackedIcons(frame, systemIndex)
    self:CreateFrameControlButtons(frame)
    return frame
end

-- [ FRAME CONTROL BUTTONS ]-------------------------------------------------------------------------
function Plugin:CreateFrameControlButtons(anchor)
    local plugin = self
    local controlContainer = CreateFrame("Frame", nil, anchor)
    controlContainer:SetSize(CONTROL_BTN_SIZE, (CONTROL_BTN_SIZE * 2) + CONTROL_BTN_SPACING)
    controlContainer:SetPoint("LEFT", anchor, "TOPRIGHT", 2, -((CONTROL_BTN_SIZE * 2 + CONTROL_BTN_SPACING) / 2))
    anchor.controlContainer = controlContainer

    local plusBtn = CreateFrame("Button", nil, controlContainer)
    plusBtn:SetSize(CONTROL_BTN_SIZE, CONTROL_BTN_SIZE)
    plusBtn:SetPoint("TOP", controlContainer, "TOP", 0, 0)
    plusBtn.Icon = plusBtn:CreateTexture(nil, "ARTWORK")
    plusBtn.Icon:SetAllPoints()
    plusBtn.Icon:SetTexture(TRACKED_ADD_ICON)
    plusBtn.Icon:SetVertexColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
    plusBtn:SetScript("OnClick", function() if not InCombatLockdown() then plugin:SpawnChildFrame() end end)
    plusBtn:SetScript("OnEnter", function(self) self.Icon:SetAlpha(1) end)
    plusBtn:SetScript("OnLeave", function(self) self.Icon:SetAlpha(0.8) end)
    plusBtn.Icon:SetAlpha(0.8)
    anchor.plusBtn = plusBtn

    local minusBtn = CreateFrame("Button", nil, controlContainer)
    minusBtn:SetSize(CONTROL_BTN_SIZE, CONTROL_BTN_SIZE)
    minusBtn:SetPoint("TOP", plusBtn, "BOTTOM", 0, -CONTROL_BTN_SPACING)
    minusBtn.Icon = minusBtn:CreateTexture(nil, "ARTWORK")
    minusBtn.Icon:SetAllPoints()
    minusBtn.Icon:SetTexture(TRACKED_REMOVE_ICON)
    minusBtn.Icon:SetVertexColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
    minusBtn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if anchor.isChildFrame then plugin:DespawnChildFrame(anchor) end
    end)
    minusBtn:SetScript("OnEnter", function(self) self.Icon:SetAlpha(1) end)
    minusBtn:SetScript("OnLeave", function(self) self.Icon:SetAlpha(0.8) end)
    minusBtn.Icon:SetAlpha(0.8)
    anchor.minusBtn = minusBtn

    self:UpdateControlButtonVisibility(anchor)
    self:UpdateAllControlButtonColors()
end

function Plugin:UpdateControlButtonVisibility(anchor)
    if not anchor or not anchor.controlContainer then return end
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    if isEditMode then
        anchor.controlContainer:Show()
        anchor.minusBtn:SetShown(anchor.isChildFrame == true)
    else
        anchor.controlContainer:Hide()
    end
end

function Plugin:UpdateAllControlButtonColors()
    local count = 0
    for _ in pairs(self.activeChildren) do count = count + 1 end
    local atMax = count >= MAX_CHILD_FRAMES

    local viewerMap = GetViewerMap()
    local entry = viewerMap[TRACKED_INDEX]
    if entry and entry.anchor and entry.anchor.plusBtn then
        local c = atMax and COLOR_RED or COLOR_GREEN
        entry.anchor.plusBtn.Icon:SetVertexColor(c.r, c.g, c.b)
        entry.anchor.plusBtn:SetEnabled(not atMax)
    end
    for _, childData in pairs(self.activeChildren) do
        if childData.frame and childData.frame.plusBtn then
            local c = atMax and COLOR_RED or COLOR_GREEN
            childData.frame.plusBtn.Icon:SetVertexColor(c.r, c.g, c.b)
            childData.frame.plusBtn:SetEnabled(not atMax)
        end
    end
end

function Plugin:RefreshAllControlButtonVisibility()
    local viewerMap = GetViewerMap()
    local entry = viewerMap[TRACKED_INDEX]
    if entry and entry.anchor then self:UpdateControlButtonVisibility(entry.anchor) end
    for _, childData in pairs(self.activeChildren) do
        if childData.frame then self:UpdateControlButtonVisibility(childData.frame) end
    end
end

function Plugin:SetupEditModeHooks()
    if self.editModeHooksSetup then return end
    self.editModeHooksSetup = true
    local plugin = self
    if EditModeManagerFrame then
        EditModeManagerFrame:HookScript("OnShow", function() plugin:RefreshAllControlButtonVisibility() end)
        EditModeManagerFrame:HookScript("OnHide", function() plugin:RefreshAllControlButtonVisibility() end)
    end
end


function Plugin:SpawnChildFrame()
    local count = 0
    for _, _ in pairs(self.activeChildren) do count = count + 1 end
    if count >= MAX_CHILD_FRAMES then return nil end

    local slot = nil
    for s = 1, MAX_CHILD_FRAMES do
        if not self.activeChildren["child:" .. s] then slot = s break end
    end
    if not slot then return nil end

    local key = "child:" .. slot
    local systemIndex = TRACKED_CHILD_START + slot - 1
    local label = "Tracked Cooldowns " .. (slot + 1)

    local frame = table.remove(self.childFramePool)
    if not frame then
        frame = self:CreateTrackedAnchor("OrbitTrackedChild_" .. slot, systemIndex, label)
    else
        frame.systemIndex = systemIndex
        frame.editModeName = label
        OrbitEngine.Frame:AttachSettingsListener(frame, self, systemIndex)
        for _, icon in pairs(frame.activeIcons or {}) do icon:Hide() end
        frame.activeIcons = {}
        frame.recyclePool = {}
        frame.gridItems = {}
        self:CreateTrackedIcons(frame, systemIndex)
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:Show()
    frame.isChildFrame = true
    frame.childSlot = slot

    self.activeChildren[key] = { frame = frame, systemIndex = systemIndex, slot = slot }
    GetViewerMap()[systemIndex] = { anchor = frame }
    self:SetSetting(systemIndex, "Enabled", true)

    self:LoadTrackedItems(frame, systemIndex)
    self:ApplySettings(frame)
    self:SetupTrackedCanvasPreview(frame, systemIndex)
    self:UpdateControlButtonVisibility(frame)
    self:UpdateAllControlButtonColors()

    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        OrbitEngine.FrameSelection:OnEditModeEnter()
    end
    return frame
end

function Plugin:DespawnChildFrame(frame)
    if not frame or not frame.isChildFrame then return end
    local key = "child:" .. frame.childSlot

    frame:Hide()
    frame:ClearAllPoints()
    for _, icon in pairs(frame.activeIcons or {}) do icon:Hide() end
    for _, btn in pairs(frame.edgeButtons or {}) do btn:Hide() end

    self:SetSetting(frame.systemIndex, "TrackedItems", nil)
    self:SetSetting(frame.systemIndex, "Position", nil)
    self:SetSetting(frame.systemIndex, "Enabled", nil)

    GetViewerMap()[frame.systemIndex] = nil
    self.activeChildren[key] = nil
    table.insert(self.childFramePool, frame)
    self:UpdateAllControlButtonColors()
end

function Plugin:RestoreChildFrames()
    for slot = 1, MAX_CHILD_FRAMES do
        local systemIndex = TRACKED_CHILD_START + slot - 1
        local enabled = self:GetSetting(systemIndex, "Enabled")
        local tracked = self:GetSetting(systemIndex, "TrackedItems")
        if enabled or (tracked and next(tracked)) then
            local key = "child:" .. slot
            local label = "Tracked Cooldowns " .. (slot + 1)
            local frame = self:CreateTrackedAnchor("OrbitTrackedChild_" .. slot, systemIndex, label)
            frame.isChildFrame = true
            frame.childSlot = slot
            self.activeChildren[key] = { frame = frame, systemIndex = systemIndex, slot = slot }
            GetViewerMap()[systemIndex] = { anchor = frame }
            self:SetSetting(systemIndex, "Enabled", true)
            self:LoadTrackedItems(frame, systemIndex)
            self:SetupTrackedCanvasPreview(frame, systemIndex)
            self:ApplySettings(frame)
        end
    end
end

-- [ DRAG AND DROP ]----------------------------------------------------------------------------------
function Plugin:OnEdgeAddButtonClick(anchor, x, y)
    local cursorType, id, subType, spellID = GetCursorInfo()
    if cursorType ~= "spell" and cursorType ~= "item" then return end

    local actualId = id
    if cursorType == "spell" then
        actualId = spellID or id
        if subType and subType ~= "" then
            local bookInfo = C_SpellBook.GetSpellBookItemInfo(id, Enum.SpellBookSpellBank[subType] or Enum.SpellBookSpellBank.Player)
            if bookInfo and bookInfo.spellID then actualId = bookInfo.spellID end
        end
    end

    ClearCursor()
    self:SaveTrackedItem(anchor.systemIndex, x, y, cursorType, actualId)
    self:LoadTrackedItems(anchor, anchor.systemIndex)
end

function Plugin:OnTrackedAnchorReceiveDrag(anchor)
    local gridItems = anchor.gridItems or {}
    local hasAny = next(gridItems) ~= nil
    if not hasAny then
        self:OnEdgeAddButtonClick(anchor, 0, 0)
    end
end

function Plugin:OnTrackedIconReceiveDrag(icon)
    local cursorType, id, subType, spellID = GetCursorInfo()
    if cursorType ~= "spell" and cursorType ~= "item" then return end

    local actualId = id
    if cursorType == "spell" then
        actualId = spellID or id
        if subType and subType ~= "" then
            local bookInfo = C_SpellBook.GetSpellBookItemInfo(id, Enum.SpellBookSpellBank[subType] or Enum.SpellBookSpellBank.Player)
            if bookInfo and bookInfo.spellID then actualId = bookInfo.spellID end
        end
    elseif cursorType == "item" then
        actualId = id
    end

    ClearCursor()
    self:SaveTrackedItem(icon.systemIndex, icon.gridX, icon.gridY, cursorType, actualId)
    self:LoadTrackedItems(icon:GetParent(), icon.systemIndex)
end

-- [ ICON CREATION ]----------------------------------------------------------------------------------
function Plugin:CreateTrackedIcons(anchor, systemIndex)
    anchor.activeIcons = {}
    anchor.recyclePool = {}
    anchor.edgeButtons = {}
    anchor.gridItems = {}

    local iconWidth, iconHeight = CooldownUtils:CalculateIconDimensions(self, systemIndex)

    for i = 1, 2 do
        local placeholder = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
        placeholder:SetSize(iconWidth, iconHeight)
        placeholder.Texture = placeholder:CreateTexture(nil, "ARTWORK")
        placeholder.Texture:SetAllPoints()
        placeholder.Texture:SetTexture(TRACKED_PLACEHOLDER_ICON)
        placeholder.Texture:SetDesaturated(true)
        placeholder.Texture:SetAlpha(0.5)
        self:ApplyTrackedIconSkin(placeholder, systemIndex)
        placeholder:Hide()
        anchor.placeholders[i] = placeholder
    end

    self:LayoutTrackedIcons(anchor, systemIndex)
end

function Plugin:AcquireTrackedIcon(anchor, systemIndex)
    if #anchor.recyclePool > 0 then return table.remove(anchor.recyclePool) end
    return self:CreateTrackedIcon(anchor, systemIndex, 0, 0)
end

function Plugin:ReleaseTrackedIcons(anchor)
    for _, icon in pairs(anchor.activeIcons or {}) do
        icon:Hide()
        icon:ClearAllPoints()
        table.insert(anchor.recyclePool, icon)
    end
    anchor.activeIcons = {}
end

function Plugin:CreateTrackedIcon(anchor, systemIndex, x, y)
    local plugin = self
    local icon = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
    icon:SetSize(40, 40)
    icon.systemIndex = systemIndex
    icon.gridX = x
    icon.gridY = y
    icon.trackedType = nil
    icon.trackedId = nil

    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints()

    icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.Cooldown:SetAllPoints()
    icon.Cooldown:SetDrawSwipe(true)
    icon.Cooldown:SetDrawBling(false)

    local textOverlay = CreateFrame("Frame", nil, icon)
    textOverlay:SetAllPoints()
    textOverlay:SetFrameLevel(icon:GetFrameLevel() + 20)
    icon.TextOverlay = textOverlay

    icon.CountText = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    icon.CountText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    icon.CountText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    icon.CountText:Hide()

    icon.DropHighlight = icon:CreateTexture(nil, "BORDER")
    icon.DropHighlight:SetAllPoints()
    icon.DropHighlight:SetColorTexture(0, 0, 0, 0)
    icon.DropHighlight:Hide()

    self:ApplyTrackedIconSkin(icon, systemIndex)

    icon:EnableMouse(true)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnReceiveDrag", function(self) plugin:OnTrackedIconReceiveDrag(self) end)
    icon:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() then
            plugin:ClearTrackedIcon(self)
        elseif GetCursorInfo() then
            plugin:OnTrackedIconReceiveDrag(self)
        end
    end)
    icon:Hide()
    return icon
end

function Plugin:ApplyTrackedIconSkin(icon, systemIndex)
    local skinSettings = CooldownUtils:BuildSkinSettings(self, systemIndex, { zoom = 8 })
    if Orbit.Skin and Orbit.Skin.Icons then Orbit.Skin.Icons:ApplyCustom(icon, skinSettings) end
    self:ApplyTrackedTextSettings(icon, systemIndex)
end

function Plugin:ApplyTrackedTextSettings(icon, systemIndex)
    CooldownUtils:ApplySimpleTextStyle(self, systemIndex, icon.CountText, "Stacks", "BOTTOMRIGHT", -2, 2)

    local cooldown = icon.Cooldown
    if cooldown then
        local timerText = cooldown.Text
        if not timerText then
            local regions = { cooldown:GetRegions() }
            for _, region in ipairs(regions) do
                if region:GetObjectType() == "FontString" then timerText = region break end
            end
        end
        if timerText then
            local font, size, flags, pos, overrides = CooldownUtils:GetComponentStyle(self, systemIndex, "Timer", 2)
            timerText:SetFont(font, size, flags)
            timerText:SetDrawLayer("OVERLAY", 7)
            CooldownUtils:ApplyTextShadow(timerText, overrides.ShowShadow)
            CooldownUtils:ApplyTextColor(timerText, overrides)
            local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition
            if ApplyTextPosition then ApplyTextPosition(timerText, icon, pos) end
        end
    end
end


-- [ DATA MANAGEMENT ]--------------------------------------------------------------------------------
function Plugin:ClearTrackedIcon(icon)
    icon.trackedType = nil
    icon.trackedId = nil
    icon.Icon:SetTexture(nil)
    icon.Cooldown:Clear()
    icon.CountText:Hide()
    icon:Hide()
    self:SaveTrackedItem(icon.systemIndex, icon.gridX, icon.gridY, nil, nil)
    self:LoadTrackedItems(icon:GetParent(), icon.systemIndex)
end

-- [ GRID HELPERS ]-----------------------------------------------------------------------------------
local function GridKey(x, y) return x .. "," .. y end
local function ParseGridKey(key)
    local x, y = key:match("^(-?%d+),(-?%d+)$")
    return tonumber(x), tonumber(y)
end

function Plugin:SaveTrackedItem(systemIndex, x, y, itemType, itemId)
    local tracked = self:GetSetting(systemIndex, "TrackedItems") or {}
    local key = GridKey(x, y)
    if itemType and itemId then
        tracked[key] = { type = itemType, id = itemId, x = x, y = y }
    else
        tracked[key] = nil
    end
    self:SetSetting(systemIndex, "TrackedItems", tracked)
end

function Plugin:LoadTrackedItems(anchor, systemIndex)
    local tracked = self:GetSetting(systemIndex, "TrackedItems") or {}

    -- Migration: convert old slot-based data to coordinate-based
    local needsMigration = false
    for key, data in pairs(tracked) do
        if type(key) == "number" then needsMigration = true break end
    end
    if needsMigration then
        local migrated = {}
        local x, y = 0, 0
        for slotIndex, data in pairs(tracked) do
            if type(slotIndex) == "number" and data and data.type and data.id then
                migrated[GridKey(x, y)] = { type = data.type, id = data.id, x = x, y = y }
                x = x + 1
            end
        end
        tracked = migrated
        self:SetSetting(systemIndex, "TrackedItems", tracked)
    end

    -- Deep copy to avoid shared reference between frames
    local copy = {}
    for k, v in pairs(tracked) do
        copy[k] = { type = v.type, id = v.id, x = v.x, y = v.y }
    end
    anchor.gridItems = copy
    self:LayoutTrackedIcons(anchor, systemIndex)
end

-- [ ICON UPDATES ]-----------------------------------------------------------------------------------
function Plugin:UpdateTrackedIcon(icon)
    if not icon.trackedId then
        icon:Hide()
        return
    end

    local systemIndex = icon.systemIndex or TRACKED_INDEX
    local showGCDSwipe = self:GetSetting(systemIndex, "ShowGCDSwipe") ~= false

    local texture, durObj = nil, nil
    if icon.trackedType == "spell" then
        texture = C_Spell.GetSpellTexture(icon.trackedId)
        if texture then
            icon.Icon:SetTexture(texture)
            if not showGCDSwipe and (C_Spell.GetSpellCooldown(icon.trackedId) or {}).isOnGCD then
                icon.Cooldown:Clear()
                icon.Icon:SetDesaturation(0)
            else
                durObj = C_Spell.GetSpellCooldownDuration(icon.trackedId)
                if durObj then
                    icon.Cooldown:SetCooldownFromDurationObject(durObj, true)
                    icon.Icon:SetDesaturation(durObj:EvaluateRemainingPercent(DESAT_CURVE))
                else
                    icon.Cooldown:Clear()
                    icon.Icon:SetDesaturation(0)
                end
            end
            local displayCount = C_Spell.GetSpellDisplayCount(icon.trackedId)
            if displayCount then
                icon.CountText:SetText(displayCount)
                icon.CountText:Show()
            else
                icon.CountText:Hide()
            end
        end
    elseif icon.trackedType == "item" then
        texture = C_Item.GetItemIconByID(icon.trackedId)
        if texture then
            icon.Icon:SetTexture(texture)
            local start, duration = C_Container.GetItemCooldown(icon.trackedId)
            if start and duration and duration > 0 then
                icon.Cooldown:SetCooldown(start, duration)
                icon.Icon:SetDesaturation(1)
            else
                icon.Cooldown:Clear()
                icon.Icon:SetDesaturation(0)
            end
            local count = C_Item.GetItemCount(icon.trackedId, false, true)
            if count and count > 1 then
                icon.CountText:SetText(count)
                icon.CountText:Show()
            else
                icon.CountText:Hide()
            end
        end
    end

    if not texture then
        icon.Icon:SetTexture(TRACKED_PLACEHOLDER_ICON)
        icon.Icon:SetDesaturation(1)
        icon.Cooldown:Clear()
        icon.CountText:Hide()
    end
    icon:Show()
end

function Plugin:UpdateTrackedIconsDisplay(anchor)
    if not anchor or not anchor.activeIcons then return end
    for _, icon in pairs(anchor.activeIcons) do
        if icon.trackedId then self:UpdateTrackedIcon(icon) end
    end
end

-- [ LAYOUT ]-----------------------------------------------------------------------------------------
function Plugin:LayoutTrackedIcons(anchor, systemIndex)
    if not anchor then return end

    local iconWidth, iconHeight = CooldownUtils:CalculateIconDimensions(self, systemIndex)
    local padding = self:GetSetting(systemIndex, "IconPadding") or Constants.Cooldown.DefaultPadding

    local gridItems = anchor.gridItems or {}
    local isDragging = GetCursorInfo() ~= nil
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()

    -- Hide all existing icons and edge buttons
    for _, icon in pairs(anchor.activeIcons or {}) do icon:Hide() end
    for _, btn in pairs(anchor.edgeButtons or {}) do btn:Hide() end

    -- Calculate grid bounds from actual items
    local minX, maxX, minY, maxY
    local hasItems = false
    for key, data in pairs(gridItems) do
        local x, y = ParseGridKey(key)
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

    -- Handle empty grid
    if not hasItems then
        -- Hide placeholders when showing seed button
        for _, placeholder in ipairs(anchor.placeholders or {}) do placeholder:Hide() end

        -- Show seed button in edit mode OR when dragging
        if isEditMode or isDragging then
            anchor.edgeButtons = anchor.edgeButtons or {}
            local btn = anchor.edgeButtons[1]
            if not btn then
                btn = CreateFrame("Frame", nil, anchor)
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
                anchor.edgeButtons[1] = btn
            end
            btn:SetSize(iconWidth, iconHeight)
            local plusSize = math.min(iconWidth, iconHeight) * 0.4
            btn.Plus:SetSize(plusSize, plusSize)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
            btn:SetScript("OnMouseDown", function() self:OnEdgeAddButtonClick(anchor, 0, 0) end)
            btn:Show()
            if isDragging then btn.PulseAnim:Play() else btn.PulseAnim:Stop() btn.Glow:SetAlpha(0.6) end
            anchor:SetSize(iconWidth, iconHeight)
        else
            for _, b in pairs(anchor.edgeButtons or {}) do b:Hide() end
            anchor:SetSize(iconWidth, iconHeight)
        end
        return
    end

    -- Hide placeholders
    for _, placeholder in ipairs(anchor.placeholders or {}) do placeholder:Hide() end

    -- Initialize pools if needed
    if not anchor.recyclePool then anchor.recyclePool = {} end
    if not anchor.activeIcons then anchor.activeIcons = {} end

    -- Release all icons to pool for redistribution
    self:ReleaseTrackedIcons(anchor)

    -- Acquire icons for current grid items
    for key, data in pairs(gridItems) do
        local x, y = ParseGridKey(key)
        local icon = self:AcquireTrackedIcon(anchor, systemIndex)

        icon.gridX, icon.gridY = x, y
        icon.trackedType = data.type
        icon.trackedId = data.id

        self:UpdateTrackedIcon(icon)
        self:ApplyTrackedIconSkin(icon, systemIndex)

        icon:SetSize(iconWidth, iconHeight)
        icon.Icon:ClearAllPoints()
        icon.Icon:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        icon.Icon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        if icon.Cooldown then
            icon.Cooldown:ClearAllPoints()
            icon.Cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
            icon.Cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        end
        if icon.TextOverlay then icon.TextOverlay:SetAllPoints() end
        if icon.DropHighlight then icon.DropHighlight:SetAllPoints() end

        local posX = (x - minX) * (iconWidth + padding)
        local posY = -(y - minY) * (iconHeight + padding)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", anchor, "TOPLEFT", posX, posY)
        icon:Show()
        anchor.activeIcons[key] = icon
    end

    self:UpdateTrackedIconsDisplay(anchor)

    -- Calculate anchor size
    local gridW = (maxX - minX + 1)
    local gridH = (maxY - minY + 1)
    local totalW = gridW * iconWidth + (gridW - 1) * padding
    local totalH = gridH * iconHeight + (gridH - 1) * padding

    -- Create edge buttons when dragging using WFC adjacency detection
    anchor.edgeButtons = anchor.edgeButtons or {}
    if isDragging then
        local edgePositions = {}
        local checked = {}

        -- Determine blocked edges based on anchor relationships
        local blockedDirections = {}
        local FrameAnchor = OrbitEngine.FrameAnchor
        if FrameAnchor then
            -- Check if this anchor is a child anchored to something
            local anchorData = FrameAnchor.anchors and FrameAnchor.anchors[anchor]
            if anchorData and anchorData.edge then
                -- If anchored via BOTTOM → our TOP touches parent → block upward (y-1)
                -- If anchored via TOP → our BOTTOM touches parent → block downward (y+1)
                -- If anchored via LEFT → our RIGHT touches parent → block leftward (x-1)
                -- If anchored via RIGHT → our LEFT touches parent → block rightward (x+1)
                if anchorData.edge == "BOTTOM" then blockedDirections.top = true
                elseif anchorData.edge == "TOP" then blockedDirections.bottom = true
                elseif anchorData.edge == "LEFT" then blockedDirections.right = true
                elseif anchorData.edge == "RIGHT" then blockedDirections.left = true
                end
            end

            -- Check if something is anchored TO us (we are the parent)
            for child, childAnchor in pairs(FrameAnchor.anchors or {}) do
                if childAnchor.parent == anchor then
                    if childAnchor.edge == "TOP" then blockedDirections.top = true
                    elseif childAnchor.edge == "BOTTOM" then blockedDirections.bottom = true
                    elseif childAnchor.edge == "LEFT" then blockedDirections.left = true
                    elseif childAnchor.edge == "RIGHT" then blockedDirections.right = true
                    end
                end
            end
        end

        -- For each existing icon, check all 4 adjacent cells
        for key, _ in pairs(gridItems) do
            local x, y = ParseGridKey(key)
            if x then
                local neighbors = {}
                -- Only block direction if this icon is ON the blocked edge
                local blockLeft = blockedDirections.left and x == minX
                local blockRight = blockedDirections.right and x == maxX
                local blockTop = blockedDirections.top and y == minY
                local blockBottom = blockedDirections.bottom and y == maxY

                if not blockLeft then table.insert(neighbors, { x = x - 1, y = y }) end
                if not blockRight then table.insert(neighbors, { x = x + 1, y = y }) end
                if not blockTop then table.insert(neighbors, { x = x, y = y - 1 }) end
                if not blockBottom then table.insert(neighbors, { x = x, y = y + 1 }) end

                for _, n in ipairs(neighbors) do
                    local nKey = GridKey(n.x, n.y)
                    if not gridItems[nKey] and not checked[nKey] then
                        if n.x >= -MAX_GRID_SIZE and n.x <= MAX_GRID_SIZE and n.y >= -MAX_GRID_SIZE and n.y <= MAX_GRID_SIZE then
                            table.insert(edgePositions, { x = n.x, y = n.y })
                            checked[nKey] = true
                        end
                    end
                end
            end
        end

        -- Calculate extended bounds including edge buttons
        local extendedMinX, extendedMaxX = minX, maxX
        local extendedMinY, extendedMaxY = minY, maxY
        for _, pos in ipairs(edgePositions) do
            extendedMinX = math.min(extendedMinX, pos.x)
            extendedMaxX = math.max(extendedMaxX, pos.x)
            extendedMinY = math.min(extendedMinY, pos.y)
            extendedMaxY = math.max(extendedMaxY, pos.y)
        end

        for i, pos in ipairs(edgePositions) do
            local btn = anchor.edgeButtons[i]
            if not btn then
                btn = CreateFrame("Frame", nil, anchor)
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
                anchor.edgeButtons[i] = btn
            end

            btn.edgeX = pos.x
            btn.edgeY = pos.y
            btn:SetScript("OnMouseDown", function() self:OnEdgeAddButtonClick(anchor, pos.x, pos.y) end)

            btn:SetSize(iconWidth, iconHeight)
            local plusSize = math.min(iconWidth, iconHeight) * 0.4
            btn.Plus:SetSize(plusSize, plusSize)

            local posX = (pos.x - extendedMinX) * (iconWidth + padding)
            local posY = -(pos.y - extendedMinY) * (iconHeight + padding)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", anchor, "TOPLEFT", posX, posY)
            btn:Show()
            btn.PulseAnim:Play()
        end

        -- Update anchor size to include edge button area
        local extendedW = (extendedMaxX - extendedMinX + 1)
        local extendedH = (extendedMaxY - extendedMinY + 1)
        totalW = extendedW * iconWidth + (extendedW - 1) * padding
        totalH = extendedH * iconHeight + (extendedH - 1) * padding

        -- Reposition icons to account for edge buttons
        for key, icon in pairs(anchor.activeIcons) do
            local posX = (icon.gridX - extendedMinX) * (iconWidth + padding)
            local posY = -(icon.gridY - extendedMinY) * (iconHeight + padding)
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", anchor, "TOPLEFT", posX, posY)
        end
    end

    anchor:SetSize(math.max(totalW, iconWidth), math.max(totalH, iconHeight))
end

-- [ TICKER ]-----------------------------------------------------------------------------------------
function Plugin:StartTrackedUpdateTicker()
    if self.trackedTicker then return end
    local viewerMap = GetViewerMap()
    self.trackedTicker = C_Timer.NewTicker(Constants.Timing.IconMonitorInterval, function()
        local entry = viewerMap[TRACKED_INDEX]
        if entry and entry.anchor and entry.anchor.activeIcons then
            for _, icon in pairs(entry.anchor.activeIcons) do
                if icon.trackedId then self:UpdateTrackedIcon(icon) end
            end
        end
        for _, childData in pairs(self.activeChildren) do
            if childData.frame and childData.frame.activeIcons then
                for _, icon in pairs(childData.frame.activeIcons) do
                    if icon.trackedId then self:UpdateTrackedIcon(icon) end
                end
            end
        end
    end)
end

-- [ CURSOR WATCHER ]---------------------------------------------------------------------------------
function Plugin:RegisterCursorWatcher()
    local lastCursor = nil
    local lastEditMode = nil
    local viewerMap = GetViewerMap()
    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function()
        local cursorType = GetCursorInfo()
        local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
        if cursorType == lastCursor and isEditMode == lastEditMode then return end
        lastCursor = cursorType
        lastEditMode = isEditMode
        local isDroppable = cursorType == "spell" or cursorType == "item"
        local entry = viewerMap[TRACKED_INDEX]
        if entry and entry.anchor then
            local anchor = entry.anchor
            self:LayoutTrackedIcons(anchor, TRACKED_INDEX)
            if isDroppable then anchor.DropHighlight:Show() else anchor.DropHighlight:Hide() end
        end
        -- Also update child frames
        for _, childData in pairs(self.activeChildren) do
            if childData.frame then
                self:LayoutTrackedIcons(childData.frame, childData.systemIndex)
                if isDroppable then
                    childData.frame.DropHighlight:Show()
                else
                    childData.frame.DropHighlight:Hide()
                end
            end
        end
    end)
end

-- [ CANVAS PREVIEW ]---------------------------------------------------------------------------------
function Plugin:SetupTrackedCanvasPreview(anchor, systemIndex)
    local plugin = self
    local LSM = LibStub("LibSharedMedia-3.0")

    anchor.CreateCanvasPreview = function(self, options)
        local w, h = CooldownUtils:CalculateIconDimensions(plugin, systemIndex)

        local parent = options.parent or UIParent
        local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        preview:SetSize(w, h)

        local borderSize = Orbit.db.GlobalSettings.BorderSize
        local contentW = w - (borderSize * 2)
        local contentH = h - (borderSize * 2)
        preview.sourceFrame = self
        preview.sourceWidth = contentW
        preview.sourceHeight = contentH
        preview.previewScale = 1
        preview.components = {}

        local iconTexture = TRACKED_PLACEHOLDER_ICON
        local tracked = plugin:GetSetting(systemIndex, "TrackedItems") or {}
        for _, data in pairs(tracked) do
            if data and data.type and data.id then
                if data.type == "spell" then
                    iconTexture = C_Spell.GetSpellTexture(data.id) or iconTexture
                elseif data.type == "item" then
                    iconTexture = C_Item.GetItemIconByID(data.id) or iconTexture
                end
                break
            end
        end

        local icon = preview:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(iconTexture)

        local backdrop = { bgFile = "Interface\\BUTTONS\\WHITE8x8", insets = { left = 0, right = 0, top = 0, bottom = 0 } }
        if borderSize > 0 then
            backdrop.edgeFile = "Interface\\BUTTONS\\WHITE8x8"
            backdrop.edgeSize = borderSize
        end
        preview:SetBackdrop(backdrop)
        preview:SetBackdropColor(0, 0, 0, 0)
        if borderSize > 0 then preview:SetBackdropBorderColor(0, 0, 0, 1) end

        local savedPositions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
        local globalFontName = Orbit.db.GlobalSettings.Font
        local fontPath = LSM:Fetch("font", globalFontName) or "Fonts\\FRIZQT__.TTF"

        local textComponents = {
            { key = "Timer", preview = string.format("%.1f", 3 + math.random() * 7), anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0 },
            { key = "Stacks", preview = "3", anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
            { key = "Keybind", preview = "Q", anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2 },
        }

        local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent

        for _, def in ipairs(textComponents) do
            local fs = preview:CreateFontString(nil, "OVERLAY", nil, 7)
            fs:SetFont(fontPath, 12, "OUTLINE")
            fs:SetText(def.preview)
            fs:SetTextColor(1, 1, 1, 1)
            fs:SetPoint("CENTER", preview, "CENTER", 0, 0)

            local saved = savedPositions[def.key] or {}
            local defaultJustifyH = def.anchorX == "LEFT" and "LEFT" or def.anchorX == "RIGHT" and "RIGHT" or "CENTER"
            local data = {
                anchorX = saved.anchorX or def.anchorX,
                anchorY = saved.anchorY or def.anchorY,
                offsetX = saved.offsetX or def.offsetX,
                offsetY = saved.offsetY or def.offsetY,
                justifyH = saved.justifyH or defaultJustifyH,
                overrides = saved.overrides,
            }

            local halfW, halfH = contentW / 2, contentH / 2
            local startX, startY = saved.posX or 0, saved.posY or 0

            if not saved.posX then
                if data.anchorX == "LEFT" then startX = -halfW + data.offsetX
                elseif data.anchorX == "RIGHT" then startX = halfW - data.offsetX end
            end
            if not saved.posY then
                if data.anchorY == "BOTTOM" then startY = -halfH + data.offsetY
                elseif data.anchorY == "TOP" then startY = halfH - data.offsetY end
            end

            if CreateDraggableComponent then
                local comp = CreateDraggableComponent(preview, def.key, fs, startX, startY, data)
                if comp then
                    comp:SetFrameLevel(preview:GetFrameLevel() + 10)
                    preview.components[def.key] = comp
                    fs:Hide()
                end
            else
                fs:ClearAllPoints()
                fs:SetPoint("CENTER", preview, "CENTER", startX, startY)
            end
        end

        return preview
    end
end

-- [ SETTINGS ]----------------------------------------------------------------------------------------
function Plugin:ApplyTrackedSettings(anchor)
    if not anchor then return end
    if InCombatLockdown() then return end

    local systemIndex = anchor.systemIndex
    local alpha = self:GetSetting(systemIndex, "Opacity") or 100
    OrbitEngine.NativeFrame:Modify(anchor, { alpha = alpha / 100 })
    anchor:Show()
    OrbitEngine.Frame:RestorePosition(anchor, self, systemIndex)
    self:LoadTrackedItems(anchor, systemIndex)
    self:LayoutTrackedIcons(anchor, systemIndex)
end
