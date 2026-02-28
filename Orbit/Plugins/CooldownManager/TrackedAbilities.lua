---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils
local ControlButtons = OrbitEngine.ControlButtonFactory

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local TRACKED_INDEX = Constants.Cooldown.SystemIndex.Tracked
local TRACKED_CHILD_START = Constants.Cooldown.SystemIndex.Tracked_ChildStart
local MAX_CHILD_FRAMES = Constants.Cooldown.MaxChildFrames
local TRACKED_ADD_ICON = "Interface\\PaperDollInfoFrame\\Character-Plus"
local TRACKED_REMOVE_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

-- [ TOOLTIP PARSER ALIASES ]------------------------------------------------------------------------
local Parser = Orbit.TrackedTooltipParser
local ParseActiveDuration = function(t, id) return Parser:ParseActiveDuration(t, id) end
local ParseCooldownDuration = function(t, id) return Parser:ParseCooldownDuration(t, id) end

-- [ SPELL OVERRIDE ALIAS ]--------------------------------------------------------------------------
local function GetActiveSpellID(spellID) return FindSpellOverrideByID(spellID) end

-- [ PLUGIN REFERENCE ]------------------------------------------------------------------------------
local Plugin = Orbit:GetPlugin("Orbit_CooldownViewer")
if not Plugin then
    error("TrackedAbilities.lua: Plugin 'Orbit_CooldownViewer' not found - ensure CooldownManager.lua loads first")
end
local function GetViewerMap() return Plugin.viewerMap end

-- [ SUB-MODULE REFERENCES ]-------------------------------------------------------------------------
local IconFactory = Orbit.TrackedIconFactory
local Layout = Orbit.TrackedLayout
local Updater = Orbit.TrackedUpdater

-- [ CHILD FRAME MANAGEMENT ]------------------------------------------------------------------------
Plugin.childFramePool = Plugin.childFramePool or {}
Plugin.activeChildren = Plugin.activeChildren or {}

-- [ COOLDOWN VALIDATION ]---------------------------------------------------------------------------
local function HasCooldown(itemType, id)
    if itemType == "spell" then
        local activeId = GetActiveSpellID(id)
        local cd = GetSpellBaseCooldown(activeId)
        if cd and cd > 0 then return true end
        local ci = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(activeId)
        if ci and ci.maxCharges and ci.maxCharges > 1 then return true end
        return ParseCooldownDuration("spell", activeId) ~= nil
    elseif itemType == "item" then
        return ParseCooldownDuration("item", id) ~= nil
    end
    return false
end

local function ResolveCursorInfo()
    local cursorType, id, subType, spellID = GetCursorInfo()
    if cursorType == "spell" then
        local actualId = spellID or id
        if not spellID and subType and subType ~= "" then
            local bookInfo = C_SpellBook.GetSpellBookItemInfo(id, Enum.SpellBookSpellBank[subType] or Enum.SpellBookSpellBank.Player)
            if bookInfo and bookInfo.spellID then actualId = bookInfo.spellID end
        end
        return "spell", actualId
    elseif cursorType == "item" then
        return "item", id
    end
    return nil, nil
end

local function IsDraggingCooldownAbility()
    local itemType, actualId = ResolveCursorInfo()
    if not itemType then return false end
    return HasCooldown(itemType, actualId)
end

-- Expose for sub-modules
Plugin.IsDraggingCooldownAbility = IsDraggingCooldownAbility

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
    frame.editModeTooltipLines = { "Drag and drop items and spells that have cooldowns here." }
    frame:EnableMouse(false)
    frame.orbitClickThrough = true
    frame.anchorOptions = { horizontal = true, vertical = true, syncScale = true, syncDimensions = false, useRowDimension = true }
    frame.orbitChainSync = true
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
        frame:SetPoint("CENTER", UIParent, "CENTER", -30, 0)
    end

    frame:SetScript("OnReceiveDrag", function() plugin:OnTrackedAnchorReceiveDrag(frame) end)
    frame:SetScript("OnMouseDown", function(_, button)
        if GetCursorInfo() then plugin:OnTrackedAnchorReceiveDrag(frame) end
    end)

    frame.icons = {}
    frame.placeholders = {}
    frame.recyclePool = {}
    frame.activeIcons = {}
    IconFactory:CreateTrackedIcons(self, frame, systemIndex)
    self:CreateFrameControlButtons(frame)

    frame.OnAnchorChanged = function(self) Layout:LayoutTrackedIcons(plugin, self, self.systemIndex, IsDraggingCooldownAbility) end
    return frame
end

-- [ FRAME CONTROL BUTTONS ]-------------------------------------------------------------------------
function Plugin:CreateFrameControlButtons(anchor)
    local plugin = self
    ControlButtons:Create(anchor, {
        addIcon = TRACKED_ADD_ICON, removeIcon = TRACKED_REMOVE_ICON,
        childFlag = "isChildFrame",
        onAdd = function() plugin:SpawnChildFrame() end,
        onRemove = function(a) plugin:DespawnChildFrame(a) end,
    })
    self:UpdateControlButtonVisibility(anchor)
    self:UpdateAllControlButtonColors()
end

function Plugin:UpdateControlButtonVisibility(anchor) ControlButtons:UpdateVisibility(anchor, "isChildFrame") end

function Plugin:UpdateAllControlButtonColors()
    local viewerMap = GetViewerMap()
    local entry = viewerMap[TRACKED_INDEX]
    ControlButtons:UpdateColors(self.activeChildren, entry and entry.anchor, MAX_CHILD_FRAMES)
end

function Plugin:RefreshAllControlButtonVisibility()
    local viewerMap = GetViewerMap()
    local entry = viewerMap[TRACKED_INDEX]
    ControlButtons:RefreshAll(entry and entry.anchor, self.activeChildren, "isChildFrame")
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

-- [ CHILD FRAME SPAWN/DESPAWN ]---------------------------------------------------------------------
function Plugin:SpawnChildFrame()
    local count = 0
    for _, _ in pairs(self.activeChildren) do count = count + 1 end
    if count >= MAX_CHILD_FRAMES then return nil end

    local slot = nil
    for s = 1, MAX_CHILD_FRAMES do
        if not self.activeChildren["child:" .. s] then slot = s; break end
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
        IconFactory:CreateTrackedIcons(self, frame, systemIndex)
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    if not frame.orbitMountedSuppressed then frame:Show() end
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
    self:SetSetting(frame.systemIndex, "Anchor", nil)
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
            self:ClearStaleTrackedSpatial(frame, systemIndex)
        end
    end
end

function Plugin:ClearStaleTrackedSpatial(frame, sysIndex)
    if not frame or (frame.gridItems and next(frame.gridItems)) then return end
    self:SetSetting(sysIndex, "Anchor", nil)
    self:SetSetting(sysIndex, "Position", nil)
    OrbitEngine.FrameAnchor:BreakAnchor(frame, true)
    for _, child in ipairs(OrbitEngine.FrameAnchor:GetAnchoredChildren(frame)) do
        OrbitEngine.FrameAnchor:BreakAnchor(child, true)
        if child.orbitPlugin and child.systemIndex then
            child.orbitPlugin:SetSetting(child.systemIndex, "Anchor", nil)
        end
    end
end

-- [ DRAG AND DROP ]----------------------------------------------------------------------------------
function Plugin:OnEdgeAddButtonClick(anchor, x, y)
    local itemType, actualId = ResolveCursorInfo()
    if not itemType then return end
    ClearCursor()
    self:SaveTrackedItem(anchor.systemIndex, x, y, itemType, actualId)
    self:LoadTrackedItems(anchor, anchor.systemIndex)
end

function Plugin:OnTrackedAnchorReceiveDrag(anchor)
    local gridItems = anchor.gridItems or {}
    if not next(gridItems) then self:OnEdgeAddButtonClick(anchor, 0, 0) end
end

function Plugin:OnTrackedIconReceiveDrag(icon)
    local itemType, actualId = ResolveCursorInfo()
    if not itemType then return end
    if not HasCooldown(itemType, actualId) then return end
    ClearCursor()
    self:SaveTrackedItem(icon.systemIndex, icon.gridX, icon.gridY, itemType, actualId)
    self:LoadTrackedItems(icon:GetParent(), icon.systemIndex)
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

function Plugin:SaveTrackedItem(systemIndex, x, y, itemType, itemId)
    local tracked = self:GetSetting(systemIndex, self:GetSpecKey("TrackedItems")) or {}
    local key = Layout.GridKey(x, y)
    if itemType and itemId then
        local parseId = (itemType == "spell") and GetActiveSpellID(itemId) or itemId
        local actDur = ParseActiveDuration(itemType, parseId)
        local cdDur = ParseCooldownDuration(itemType, parseId)
        tracked[key] = { type = itemType, id = itemId, x = x, y = y, activeDuration = actDur, cooldownDuration = cdDur }
    else
        tracked[key] = nil
    end
    self:SetSetting(systemIndex, self:GetSpecKey("TrackedItems"), tracked)
end

function Plugin:LoadTrackedItems(anchor, systemIndex)
    local tracked = self:GetSetting(systemIndex, self:GetSpecKey("TrackedItems")) or {}

    local needsMigration = false
    for key, _ in pairs(tracked) do
        if type(key) == "number" then needsMigration = true; break end
    end
    if needsMigration then
        local migrated = {}
        local x, y = 0, 0
        for slotIndex, data in pairs(tracked) do
            if type(slotIndex) == "number" and data and data.type and data.id then
                migrated[Layout.GridKey(x, y)] = { type = data.type, id = data.id, x = x, y = y }
                x = x + 1
            end
        end
        tracked = migrated
        self:SetSetting(systemIndex, self:GetSpecKey("TrackedItems"), tracked)
    end

    local copy = {}
    for k, v in pairs(tracked) do
        copy[k] = { type = v.type, id = v.id, x = v.x, y = v.y, activeDuration = v.activeDuration, cooldownDuration = v.cooldownDuration }
    end
    anchor.gridItems = copy
    Layout:LayoutTrackedIcons(self, anchor, systemIndex, IsDraggingCooldownAbility)
end

-- Canvas preview: see TrackedCanvasPreview.lua

-- [ DELEGATED METHODS ]------------------------------------------------------------------------------
function Plugin:LayoutTrackedIcons(anchor, systemIndex) Layout:LayoutTrackedIcons(self, anchor, systemIndex, IsDraggingCooldownAbility) end
function Plugin:ApplyTrackedIconSkin(icon, systemIndex, overrides) IconFactory:ApplyTrackedIconSkin(self, icon, systemIndex, overrides) end
function Plugin:StartTrackedUpdateTicker() Updater:StartTrackedUpdateTicker(self) end
function Plugin:RegisterSpellCastWatcher() Updater:RegisterSpellCastWatcher(self) end
function Plugin:RegisterCursorWatcher() Updater:RegisterCursorWatcher(self) end
function Plugin:RegisterTalentWatcher() Updater:RegisterTalentWatcher(self) end
function Plugin:ReparseActiveDurations() Updater:ReparseActiveDurations(self) end
function Plugin:RefreshAllTrackedLayouts() Updater:RefreshAllTrackedLayouts(self) end
function Plugin:ReloadTrackedForSpec() Updater:ReloadTrackedForSpec(self) end
function Plugin:StartActiveGlow(icon) Updater:StartActiveGlow(self, icon) end
function Plugin:StopActiveGlow(icon) Updater:StopActiveGlow(icon) end
function Plugin:SetTrackedClickEnabled(enabled) Updater:SetTrackedClickEnabled(self, enabled) end
function Plugin:UpdateTrackedIconsDisplay(anchor) Updater:UpdateTrackedIconsDisplay(self, anchor) end

-- [ SETTINGS ]----------------------------------------------------------------------------------------
function Plugin:ApplyTrackedSettings(anchor)
    if not anchor then return end
    if InCombatLockdown() then return end
    local systemIndex = anchor.systemIndex
    local isMountedHidden = Orbit.MountedVisibility:ShouldHide()
    local alpha = isMountedHidden and 0 or ((self:GetSetting(systemIndex, "Opacity") or 100) / 100)
    OrbitEngine.NativeFrame:Modify(anchor, { alpha = alpha })
    if not anchor.orbitMountedSuppressed then anchor:Show() end
    OrbitEngine.Frame:RestorePosition(anchor, self, systemIndex)
    self:LoadTrackedItems(anchor, systemIndex)
    Layout:LayoutTrackedIcons(self, anchor, systemIndex, IsDraggingCooldownAbility)
    local enableHover = self:GetSetting(systemIndex, "ShowOnMouseover") ~= false
    Orbit.OOCFadeMixin:ApplyOOCFade(anchor, self, systemIndex, "OutOfCombatFade", enableHover)
end
