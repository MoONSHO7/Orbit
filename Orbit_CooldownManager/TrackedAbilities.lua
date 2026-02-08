---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils
local LCG = LibStub("LibCustomGlow-1.0", true)
local ACTIVE_GLOW_KEY = "orbitActive"
local GlowType = Constants.PandemicGlow.Type
local GlowConfig = Constants.PandemicGlow

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

-- [ ACTIVE DURATION PARSING ]-----------------------------------------------------------------------
local function StripEscapes(text)
    text = text:gsub("|4([^:]+):([^;]+);", "%2")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text
end

local function ParseActiveDuration(itemType, id)
    local text = nil
    if itemType == "spell" then
        text = C_Spell.GetSpellDescription(id)
    elseif itemType == "item" then
        local tooltipData = C_TooltipInfo and C_TooltipInfo.GetItemByID(id)
        if tooltipData and tooltipData.lines then
            for _, line in ipairs(tooltipData.lines) do
                text = (text or "") .. " " .. (line.leftText or "")
            end
        end
    end
    if not text then return nil end
    text = StripEscapes(text)
    local best = nil
    for _, pattern in ipairs({"for (%d+) sec", "lasts (%d+) sec", "over (%d+) sec"}) do
        for num in text:gmatch(pattern) do
            local n = tonumber(num)
            if not best or n > best then best = n end
        end
        if best then return best end
    end
    return best
end

local function ParseCooldownDuration(itemType, id)
    local tooltipData = nil
    if itemType == "spell" then
        tooltipData = C_TooltipInfo and C_TooltipInfo.GetSpellByID(id)
    elseif itemType == "item" then
        tooltipData = C_TooltipInfo and C_TooltipInfo.GetItemByID(id)
    end
    if not tooltipData or not tooltipData.lines then return nil end
    for _, line in ipairs(tooltipData.lines) do
        local text = StripEscapes(line.rightText or line.leftText or "")
        local min = text:match("(%d+) [Mm]in [Cc]ooldown")
        if min then return tonumber(min) * 60 end
        local sec = text:match("(%d+) [Ss]ec [Cc]ooldown")
        if sec then return tonumber(sec) end
    end
    return nil
end

local function BuildDesatCurve(activeDuration, cooldownDuration)
    local curve = C_CurveUtil.CreateCurve()
    curve:AddPoint(0.0, 0)
    if not activeDuration or not cooldownDuration or cooldownDuration <= 0 or activeDuration >= cooldownDuration then
        curve:AddPoint(0.001, 1)
        curve:AddPoint(1.0, 1)
        return curve
    end
    local breakpoint = 1.0 - (activeDuration / cooldownDuration)
    curve:AddPoint(0.001, 1)
    curve:AddPoint(math.max(breakpoint, 0.002), 1)
    curve:AddPoint(breakpoint + 0.001, 0)
    curve:AddPoint(1.0, 0)
    return curve
end

local function BuildCooldownAlphaCurve(activeDuration, cooldownDuration)
    local curve = C_CurveUtil.CreateCurve()
    if not activeDuration or not cooldownDuration or cooldownDuration <= 0 or activeDuration >= cooldownDuration then
        curve:AddPoint(0.0, 0)
        curve:AddPoint(0.001, 1)
        curve:AddPoint(1.0, 1)
        return curve
    end
    local breakpoint = 1.0 - (activeDuration / cooldownDuration)
    curve:AddPoint(0.0, 0)
    curve:AddPoint(0.001, 1)
    curve:AddPoint(math.max(breakpoint, 0.002), 1)
    curve:AddPoint(breakpoint + 0.001, 0)
    curve:AddPoint(1.0, 0)
    return curve
end

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
    OrbitEngine.Pixel:Enforce(frame)
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

    self:SetSetting(frame.systemIndex, self:GetSpecKey("TrackedItems"), nil)
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
        local tracked = self:GetSetting(systemIndex, self:GetSpecKey("TrackedItems"))
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
    OrbitEngine.Pixel:Enforce(icon)
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

    icon.ActiveCooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.ActiveCooldown:SetAllPoints()
    icon.ActiveCooldown:SetDrawSwipe(true)
    icon.ActiveCooldown:SetDrawBling(false)

    local textOverlay = CreateFrame("Frame", nil, icon)
    textOverlay:SetAllPoints()
    textOverlay:SetFrameLevel(icon:GetFrameLevel() + 20)
    icon.TextOverlay = textOverlay

    icon.CountText = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    icon.CountText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    icon.CountText:SetFont(STANDARD_TEXT_FONT, 12, Orbit.Skin:GetFontOutline())
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
    local tracked = self:GetSetting(systemIndex, self:GetSpecKey("TrackedItems")) or {}
    local key = GridKey(x, y)
    if itemType and itemId then
        local actDur = ParseActiveDuration(itemType, itemId)
        local cdDur = ParseCooldownDuration(itemType, itemId)
        tracked[key] = { type = itemType, id = itemId, x = x, y = y, activeDuration = actDur, cooldownDuration = cdDur }
    else
        tracked[key] = nil
    end
    self:SetSetting(systemIndex, self:GetSpecKey("TrackedItems"), tracked)
end

function Plugin:LoadTrackedItems(anchor, systemIndex)
    local tracked = self:GetSetting(systemIndex, self:GetSpecKey("TrackedItems")) or {}

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
        self:SetSetting(systemIndex, self:GetSpecKey("TrackedItems"), tracked)
    end

    -- Deep copy to avoid shared reference between frames
    local copy = {}
    for k, v in pairs(tracked) do
        copy[k] = { type = v.type, id = v.id, x = v.x, y = v.y, activeDuration = v.activeDuration, cooldownDuration = v.cooldownDuration }
    end
    anchor.gridItems = copy
    self:LayoutTrackedIcons(anchor, systemIndex)
end

-- [ ICON UPDATES ]-----------------------------------------------------------------------------------
local function IsSpellUsable(spellId)
    if not spellId then return false end
    return IsSpellKnown(spellId) or IsPlayerSpell(spellId)
end

local function IsItemUsable(itemId)
    if not itemId then return false end
    local usable, noMana = C_Item.IsUsableItem(itemId)
    if usable or noMana then return true end
    return C_Item.GetItemCount(itemId, false, true) > 0
end

-- [ ACTIVE GLOW HELPERS ]--------------------------------------------------------------------------
function Plugin:StartActiveGlow(icon)
    if not LCG then return end
    local systemIndex = icon.systemIndex or TRACKED_INDEX
    local glowTypeId = self:GetSetting(systemIndex, "ActiveGlowType")
    if glowTypeId == nil then glowTypeId = GlowType.None end
    if glowTypeId == GlowType.None then return end
    local color = self:GetSetting(systemIndex, "ActiveGlowColor") or { r = 0.3, g = 0.8, b = 1, a = 1 }
    local ct = { color.r, color.g, color.b, color.a or 1 }
    if glowTypeId == GlowType.Pixel then
        local cfg = GlowConfig.Pixel
        LCG.PixelGlow_Start(icon, ct, cfg.Lines, cfg.Frequency, cfg.Length, cfg.Thickness, cfg.XOffset, cfg.YOffset, cfg.Border, ACTIVE_GLOW_KEY)
    elseif glowTypeId == GlowType.Proc then
        local cfg = GlowConfig.Proc
        LCG.ProcGlow_Start(icon, { color = ct, startAnim = cfg.StartAnim, duration = cfg.Duration, key = ACTIVE_GLOW_KEY })
    elseif glowTypeId == GlowType.Autocast then
        local cfg = GlowConfig.Autocast
        LCG.AutoCastGlow_Start(icon, ct, cfg.Particles, cfg.Frequency, cfg.Scale, cfg.XOffset, cfg.YOffset, ACTIVE_GLOW_KEY)
    elseif glowTypeId == GlowType.Button then
        local cfg = GlowConfig.Button
        LCG.ButtonGlow_Start(icon, ct, cfg.Frequency, cfg.FrameLevel)
    end
    icon._activeGlowing = true
    icon._activeGlowType = glowTypeId
end

function Plugin:StopActiveGlow(icon)
    if not LCG or not icon._activeGlowing then return end
    local t = icon._activeGlowType
    if t == GlowType.Pixel then LCG.PixelGlow_Stop(icon, ACTIVE_GLOW_KEY)
    elseif t == GlowType.Proc then LCG.ProcGlow_Stop(icon, ACTIVE_GLOW_KEY)
    elseif t == GlowType.Autocast then LCG.AutoCastGlow_Stop(icon, ACTIVE_GLOW_KEY)
    elseif t == GlowType.Button then LCG.ButtonGlow_Stop(icon)
    end
    icon._activeGlowing = false
    icon._activeGlowType = nil
end

function Plugin:UpdateTrackedIcon(icon)
    if not icon.trackedId then
        icon:Hide()
        return
    end

    local systemIndex = icon.systemIndex or TRACKED_INDEX
    local showGCDSwipe = self:GetSetting(systemIndex, "ShowGCDSwipe") ~= false

    local texture, durObj = nil, nil
    local isUsable = false

    if icon.trackedType == "spell" then
        isUsable = IsSpellUsable(icon.trackedId)
        if not isUsable then icon:Hide() return end

        texture = C_Spell.GetSpellTexture(icon.trackedId)
        if texture then
            icon.Icon:SetTexture(texture)
            local cdInfo = C_Spell.GetSpellCooldown(icon.trackedId) or {}
            local onGCD = cdInfo.isOnGCD
            local chargeInfo = icon.isChargeSpell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(icon.trackedId)

            if onGCD and not showGCDSwipe then
                icon.Cooldown:Clear()
                icon.ActiveCooldown:Clear()
                icon.Icon:SetDesaturation(0)
            elseif chargeInfo then
                local chargeDurObj = C_Spell.GetSpellChargesDuration and C_Spell.GetSpellChargesDuration(icon.trackedId)
                if chargeDurObj then
                    icon.Cooldown:SetCooldownFromDurationObject(chargeDurObj, true)
                    local allConsumed = not issecretvalue(chargeInfo.currentCharges) and chargeInfo.currentCharges == 0
                    icon.Icon:SetDesaturation(allConsumed and chargeDurObj:EvaluateRemainingPercent(icon.desatCurve or DESAT_CURVE) or 0)
                    if icon.cdAlphaCurve and allConsumed then
                        icon.Cooldown:SetAlpha(chargeDurObj:EvaluateRemainingPercent(icon.cdAlphaCurve))
                    else
                        icon.Cooldown:SetAlpha(1)
                    end
                else
                    icon.Cooldown:Clear()
                    icon.Cooldown:SetAlpha(1)
                    icon.Icon:SetDesaturation(0)
                end
                icon.ActiveCooldown:Clear()
                if icon._activeGlowing then Plugin:StopActiveGlow(icon) end
            else
                durObj = C_Spell.GetSpellCooldownDuration(icon.trackedId)
                if durObj then
                    icon.Cooldown:SetCooldownFromDurationObject(durObj, true)
                    icon.Icon:SetDesaturation(onGCD and 0 or durObj:EvaluateRemainingPercent(icon.desatCurve or DESAT_CURVE))
                    if icon.cdAlphaCurve then
                        icon.Cooldown:SetAlpha(durObj:EvaluateRemainingPercent(icon.cdAlphaCurve))
                    end
                    local onRealCD = issecretvalue(cdInfo.startTime) or cdInfo.startTime > 0
                    if icon.activeDuration and onRealCD and not onGCD then
                        icon.ActiveCooldown:SetCooldown(cdInfo.startTime, icon.activeDuration)
                    else
                        icon.ActiveCooldown:Clear()
                    end
                    if LCG and icon._activeGlowExpiry then
                        if GetTime() < icon._activeGlowExpiry then
                            if not icon._activeGlowing then
                                Plugin:StartActiveGlow(icon)
                            end
                        else
                            Plugin:StopActiveGlow(icon)
                            icon._activeGlowExpiry = nil
                        end
                    end
                else
                    icon.Cooldown:Clear()
                    icon.Cooldown:SetAlpha(1)
                    icon.ActiveCooldown:Clear()
                    icon.Icon:SetDesaturation(0)
                    if icon._activeGlowing then Plugin:StopActiveGlow(icon) end
                end
            end
            local displayCount = chargeInfo and chargeInfo.currentCharges or C_Spell.GetSpellDisplayCount(icon.trackedId)
            if displayCount then
                icon.CountText:SetText(displayCount)
                icon.CountText:Show()
            else
                icon.CountText:Hide()
            end
        end
    elseif icon.trackedType == "item" then
        isUsable = IsItemUsable(icon.trackedId)
        if not isUsable then icon:Hide() return end

        texture = C_Item.GetItemIconByID(icon.trackedId)
        if texture then
            icon.Icon:SetTexture(texture)
            local start, duration = C_Container.GetItemCooldown(icon.trackedId)
            if start and duration and duration > 0 then
                icon.Cooldown:SetCooldown(start, duration)
                if icon.activeDuration and duration > icon.activeDuration then
                    local inActivePhase = (GetTime() - start) < icon.activeDuration
                    if inActivePhase then
                        icon.Icon:SetDesaturation(0)
                        icon.Cooldown:SetAlpha(0)
                        icon.ActiveCooldown:SetCooldown(start, icon.activeDuration)
                        if not icon._activeGlowing then Plugin:StartActiveGlow(icon) end
                    else
                        icon.Icon:SetDesaturation(1)
                        icon.Cooldown:SetAlpha(1)
                        icon.ActiveCooldown:Clear()
                        if icon._activeGlowing then Plugin:StopActiveGlow(icon) end
                    end
                else
                    icon.Icon:SetDesaturation(1)
                    icon.Cooldown:SetAlpha(1)
                    icon.ActiveCooldown:Clear()
                end
            else
                icon.Cooldown:Clear()
                icon.Cooldown:SetAlpha(1)
                icon.ActiveCooldown:Clear()
                icon.Icon:SetDesaturation(0)
                if icon._activeGlowing then Plugin:StopActiveGlow(icon) end
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

    self:ApplyTimerTextColor(icon, durObj)
    icon:Show()
end

function Plugin:ApplyTimerTextColor(icon, durObj)
    local cooldown = icon.Cooldown
    if not cooldown then return end

    local timerText = cooldown.Text
    if not timerText then
        local regions = { cooldown:GetRegions() }
        for _, region in ipairs(regions) do
            if region:GetObjectType() == "FontString" then timerText = region break end
        end
        cooldown.Text = timerText
    end
    if not timerText then return end

    local systemIndex = icon.systemIndex or TRACKED_INDEX
    local positions = self:GetSetting(systemIndex, "ComponentPositions") or {}
    local timerPos = positions["Timer"] or {}
    local overrides = timerPos.overrides or {}

    if durObj and overrides.CustomColor and overrides.CustomColorCurve then
        local wowColorCurve = OrbitEngine.WidgetLogic:ToNativeColorCurve(overrides.CustomColorCurve)
        if wowColorCurve then
            local secretColor = durObj:EvaluateRemainingPercent(wowColorCurve)
            timerText:SetTextColor(secretColor:GetRGBA())
            return
        end
    end

    CooldownUtils:ApplyTextColor(timerText, overrides)
end

function Plugin:UpdateTrackedIconsDisplay(anchor)
    if not anchor or not anchor.activeIcons then return end
    for _, icon in pairs(anchor.activeIcons) do
        if icon.trackedId then self:UpdateTrackedIcon(icon) end
    end
end

local function IsGridItemUsable(data)
    if data.type == "spell" then return IsSpellUsable(data.id) end
    if data.type == "item" then return IsItemUsable(data.id) end
    return false
end

-- [ LAYOUT ]-----------------------------------------------------------------------------------------
function Plugin:LayoutTrackedIcons(anchor, systemIndex)
    if not anchor then return end

    local iconWidth, iconHeight = CooldownUtils:CalculateIconDimensions(self, systemIndex)
    local rawPadding = self:GetSetting(systemIndex, "IconPadding") or Constants.Cooldown.DefaultPadding
    local Pixel = OrbitEngine.Pixel
    local padding = Pixel and Pixel:Snap(rawPadding) or rawPadding

    local rawGridItems = anchor.gridItems or {}
    local isDragging = GetCursorInfo() ~= nil
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()

    -- Filter to only usable items (prevents cross-character ability bleed)
    local gridItems = {}
    for key, data in pairs(rawGridItems) do
        if IsGridItemUsable(data) then gridItems[key] = data end
    end

    -- Hide all existing icons and edge buttons
    for _, icon in pairs(anchor.activeIcons or {}) do icon:Hide() end
    for _, btn in pairs(anchor.edgeButtons or {}) do btn:Hide() end

    -- Calculate grid bounds from usable items only
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
            local plusSize = Pixel and Pixel:Snap(math.min(iconWidth, iconHeight) * 0.4) or (math.min(iconWidth, iconHeight) * 0.4)
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
        icon.activeDuration = data.activeDuration
        icon.cooldownDuration = data.cooldownDuration
        local hasActive = data.activeDuration and data.cooldownDuration
        icon.desatCurve = hasActive and BuildDesatCurve(data.activeDuration, data.cooldownDuration) or nil
        icon.cdAlphaCurve = hasActive and BuildCooldownAlphaCurve(data.activeDuration, data.cooldownDuration) or nil
        if data.type == "spell" and C_Spell.GetSpellCharges then
            local ci = C_Spell.GetSpellCharges(data.id)
            icon.isChargeSpell = ci and ci.maxCharges and ci.maxCharges > 1 or false
        end

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
        if icon.ActiveCooldown then
            icon.ActiveCooldown:ClearAllPoints()
            icon.ActiveCooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
            icon.ActiveCooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        end
        if icon.TextOverlay then icon.TextOverlay:SetAllPoints() end
        if icon.DropHighlight then icon.DropHighlight:SetAllPoints() end

        local posX = (x - minX) * (iconWidth + padding)
        local posY = -(y - minY) * (iconHeight + padding)
        if Pixel then posX = Pixel:Snap(posX) posY = Pixel:Snap(posY) end
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
            local plusSize = Pixel and Pixel:Snap(math.min(iconWidth, iconHeight) * 0.4) or (math.min(iconWidth, iconHeight) * 0.4)
            btn.Plus:SetSize(plusSize, plusSize)

            local posX = (pos.x - extendedMinX) * (iconWidth + padding)
            local posY = -(pos.y - extendedMinY) * (iconHeight + padding)
            if Pixel then posX = Pixel:Snap(posX) posY = Pixel:Snap(posY) end
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
            if Pixel then posX = Pixel:Snap(posX) posY = Pixel:Snap(posY) end
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

-- [ TALENT REPARSE ]---------------------------------------------------------------------------------
function Plugin:ReparseActiveDurations()
    local viewerMap = GetViewerMap()
    local function ReparseAnchor(anchor, systemIndex)
        if not anchor then return end
        local tracked = self:GetSetting(systemIndex, self:GetSpecKey("TrackedItems")) or {}
        local changed = false
        for key, data in pairs(tracked) do
            if data.id then
                local newActDur = ParseActiveDuration(data.type, data.id)
                local newCdDur = ParseCooldownDuration(data.type, data.id)
                if newActDur ~= data.activeDuration or newCdDur ~= data.cooldownDuration then
                    data.activeDuration = newActDur
                    data.cooldownDuration = newCdDur
                    changed = true
                end
            end
        end
        if changed then self:SetSetting(systemIndex, self:GetSpecKey("TrackedItems"), tracked) end
        for _, icon in pairs(anchor.activeIcons or {}) do
            local key = icon.gridX .. "," .. icon.gridY
            local data = tracked[key]
            if data then
                icon.activeDuration = data.activeDuration
                icon.cooldownDuration = data.cooldownDuration
            end
            local hasActive = icon.activeDuration and icon.cooldownDuration
            icon.desatCurve = hasActive and BuildDesatCurve(icon.activeDuration, icon.cooldownDuration) or nil
            icon.cdAlphaCurve = hasActive and BuildCooldownAlphaCurve(icon.activeDuration, icon.cooldownDuration) or nil
        end
    end
    local entry = viewerMap[TRACKED_INDEX]
    if entry and entry.anchor then ReparseAnchor(entry.anchor, TRACKED_INDEX) end
    for _, childData in pairs(self.activeChildren) do
        if childData.frame then ReparseAnchor(childData.frame, childData.systemIndex) end
    end
end

function Plugin:RegisterTalentWatcher()
    if self.talentWatcherSetup then return end
    self.talentWatcherSetup = true
    local plugin = self
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            plugin:ReloadTrackedForSpec()
        end
        plugin:ReparseActiveDurations()
    end)
end

function Plugin:ReloadTrackedForSpec()
    -- Reload tracked abilities for main anchor
    local viewerMap = GetViewerMap()
    local entry = viewerMap[TRACKED_INDEX]
    if entry and entry.anchor then self:LoadTrackedItems(entry.anchor, TRACKED_INDEX) end
    -- Reload child anchors
    for _, childData in pairs(self.activeChildren) do
        if childData.frame then self:LoadTrackedItems(childData.frame, childData.frame.systemIndex) end
    end
    -- Reload charge bars
    self:ReloadChargeBarsForSpec()
end

-- [ SPELL CAST WATCHER ]-----------------------------------------------------------------------------
function Plugin:RegisterSpellCastWatcher()
    if self.spellCastWatcherSetup then return end
    self.spellCastWatcherSetup = true
    local plugin = self
    local viewerMap = GetViewerMap()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:SetScript("OnEvent", function(_, _, unit, _, spellId)
        if unit ~= "player" then return end
        local function CheckAnchor(anchor)
            if not anchor or not anchor.activeIcons then return end
            for _, icon in pairs(anchor.activeIcons) do
                if icon.trackedType == "spell" and icon.trackedId == spellId and icon.activeDuration then
                    icon._activeGlowExpiry = GetTime() + icon.activeDuration
                end
            end
        end
        local entry = viewerMap[TRACKED_INDEX]
        if entry and entry.anchor then CheckAnchor(entry.anchor) end
        for _, childData in pairs(plugin.activeChildren) do
            if childData.frame then CheckAnchor(childData.frame) end
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
        local tracked = plugin:GetSetting(systemIndex, plugin:GetSpecKey("TrackedItems")) or {}
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
            fs:SetFont(fontPath, 12, Orbit.Skin:GetFontOutline())
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
