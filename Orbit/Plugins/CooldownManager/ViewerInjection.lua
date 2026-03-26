---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local ESSENTIAL_INDEX = Constants.Cooldown.SystemIndex.Essential
local UTILITY_INDEX = Constants.Cooldown.SystemIndex.Utility
local COOLDOWN_THROTTLE = 0.1
local PLACEHOLDER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local EQUIPMENT_SLOTS = { 13, 14 }
local BOUNDS_PADDING = 30
local HIT_RECT_INSET = -40
local GLOW_OUTSET_BASE = 4
local DROP_ZONE_TICK_RATE = 0.05
local GLOW_SIZE = 12
local GLOW_SLICE_START = 0.33
local GLOW_SLICE_END = 0.67
local GLOW_ATLAS = "GenericWidgetBar-Spell-Glow"
local PREVIEW_ALPHA = 0.5
-- [ SPELL OVERRIDE ALIAS ]--------------------------------------------------------------------------
local function GetActiveSpellID(spellID) return FindSpellOverrideByID(spellID) end

-- [ TOOLTIP PARSER ALIASES ]------------------------------------------------------------------------
local function GetParser() return Orbit.TrackedTooltipParser end
local ParseActiveDuration = function(t, id) return GetParser():ParseActiveDuration(t, id) end
local ParseCooldownDuration = function(t, id) return GetParser():ParseCooldownDuration(t, id) end

-- [ MODULE ]----------------------------------------------------------------------------------------
Orbit.ViewerInjection = {}
local Injection = Orbit.ViewerInjection

-- [ PLUGIN REFERENCE ]------------------------------------------------------------------------------
local Plugin = Orbit:GetPlugin("Orbit_CooldownViewer")
if not Plugin then
    error("ViewerInjection.lua: Plugin 'Orbit_CooldownViewer' not found - ensure CooldownManager.lua loads first")
end

-- [ STATE ]-----------------------------------------------------------------------------------------
Plugin.injectedFrames = Plugin.injectedFrames or {}
Plugin.injectedRecyclePools = Plugin.injectedRecyclePools or {}

-- [ DESAT CURVE ]-----------------------------------------------------------------------------------
local DESAT_CURVE = C_CurveUtil.CreateCurve()
DESAT_CURVE:AddPoint(0.0, 0)
DESAT_CURVE:AddPoint(0.001, 1)
DESAT_CURVE:AddPoint(1.0, 1)

-- [ CURSOR RESOLUTION ]-----------------------------------------------------------------------------
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

local function ResolveEquipmentSlot(itemId)
    for _, slotId in ipairs(EQUIPMENT_SLOTS) do
        local equippedId = GetInventoryItemID("player", slotId)
        if equippedId and equippedId == itemId then return slotId end
    end
    return nil
end

-- [ VALIDATION ]------------------------------------------------------------------------------------
local function HasCooldown(itemType, id)
    if itemType == "spell" then
        local activeId = GetActiveSpellID(id)
        local cd = GetSpellBaseCooldown(activeId)
        if cd and not issecretvalue(cd) and cd > 0 then return true end
        local ci = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(activeId)
        if ci and ci.maxCharges and not issecretvalue(ci.maxCharges) and ci.maxCharges > 1 then return true end
        return GetParser() and ParseCooldownDuration("spell", activeId) ~= nil
    elseif itemType == "item" then
        if GetParser() and ParseCooldownDuration("item", id) ~= nil then return true end
        return GetItemSpell(id) ~= nil
    end
    return false
end

-- [ FRAME CREATION ]--------------------------------------------------------------------------------
local function CreateInjectedIcon(parent, systemIndex)
    local icon = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    OrbitEngine.Pixel:Enforce(icon)
    icon:SetSize(40, 40)
    icon.systemIndex = systemIndex
    icon.isInjectedIcon = true
    icon.trackedType = nil
    icon.trackedId = nil

    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints()

    icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.Cooldown:SetAllPoints()
    icon.Cooldown:SetDrawSwipe(true)
    icon.Cooldown:SetDrawBling(false)
    icon.Cooldown:Clear()

    icon.ActiveCooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.ActiveCooldown:SetAllPoints()
    icon.ActiveCooldown:SetDrawSwipe(true)
    icon.ActiveCooldown:SetDrawBling(false)
    icon.ActiveCooldown:SetReverse(true)
    icon.ActiveCooldown:Clear()

    local textOverlay = CreateFrame("Frame", nil, icon)
    textOverlay:SetAllPoints()
    textOverlay:SetFrameLevel(icon:GetFrameLevel() + Constants.Levels.IconOverlay)
    icon.TextOverlay = textOverlay

    local chargeCount = CreateFrame("Frame", nil, textOverlay)
    chargeCount:SetAllPoints(icon)
    chargeCount:SetFrameLevel(icon:GetFrameLevel() + Constants.Levels.IconOverlay)
    local chargeText = chargeCount:CreateFontString(nil, "OVERLAY", nil, 7)
    chargeText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    chargeText:SetFont(STANDARD_TEXT_FONT, 12, Orbit.Skin:GetFontOutline())
    chargeCount.Current = chargeText
    icon.ChargeCount = chargeCount
    chargeCount:Hide()

    icon:EnableMouse(false)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnReceiveDrag", function(self) Injection:OnIconReceiveDrag(self) end)
    icon:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() then
            Injection:RemoveInjectedIcon(self)
        elseif GetCursorInfo() then
            Injection:OnIconReceiveDrag(self)
        end
    end)
    icon:Hide()
    return icon
end

-- [ ICON UPDATE ]-----------------------------------------------------------------------------------
function Injection:UpdateIcon(icon)
    if not icon.trackedId then icon:Hide(); return end

    local texture
    if icon.trackedType == "spell" then
        local activeId = GetActiveSpellID(icon.trackedId)
        if not IsSpellKnown(icon.trackedId) and not IsPlayerSpell(icon.trackedId) then
            if activeId == icon.trackedId or (not IsSpellKnown(activeId) and not IsPlayerSpell(activeId)) then
                icon:Hide(); return
            end
        end
        texture = C_Spell.GetSpellTexture(activeId)
        if texture then
            icon.Icon:SetTexture(texture)
            local durObj = C_Spell.GetSpellCooldownDuration(activeId)
            local cdInfo = C_Spell.GetSpellCooldown(activeId)
            local onGCD = cdInfo and cdInfo.isOnGCD
            local showGCDSwipe = Plugin:GetSetting(icon.systemIndex, "ShowGCDSwipe") ~= false
            if onGCD and not showGCDSwipe then
                icon.Cooldown:Clear()
                icon.ActiveCooldown:Clear()
                icon.Icon:SetDesaturation(0)
            elseif durObj then
                if icon.activeDuration and icon._activeGlowExpiry and not onGCD and GetTime() < icon._activeGlowExpiry then
                    local castTime = icon._activeGlowExpiry - icon.activeDuration
                    icon.Cooldown:Clear()
                    icon.ActiveCooldown:SetCooldown(castTime, icon.activeDuration)
                    icon.Icon:SetDesaturation(0)
                else
                    icon.Cooldown:SetCooldownFromDurationObject(durObj, true)
                    icon.ActiveCooldown:Clear()
                    icon.Icon:SetDesaturation(onGCD and 0 or durObj:EvaluateRemainingPercent(DESAT_CURVE))
                    if icon._activeGlowExpiry then icon._activeGlowExpiry = nil end
                end
            else
                icon.Cooldown:Clear()
                icon.ActiveCooldown:Clear()
                icon.Icon:SetDesaturation(0)
            end
            local chargeInfo = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(activeId)
            local displayCount = chargeInfo and chargeInfo.currentCharges or C_Spell.GetSpellDisplayCount(activeId)
            if displayCount then icon.ChargeCount.Current:SetText(displayCount); icon.ChargeCount:Show()
            else icon.ChargeCount:Hide() end
        end
    elseif icon.trackedType == "item" then
        local usable, noMana = C_Item.IsUsableItem(icon.trackedId)
        local isUsable = usable or noMana or C_Item.GetItemCount(icon.trackedId, false, true) > 0
        texture = C_Item.GetItemIconByID(icon.trackedId)
        if texture then
            icon.Icon:SetTexture(texture)
            if not isUsable then
                icon.Cooldown:Clear()
                icon.Icon:SetDesaturation(1)
                icon.ChargeCount.Current:SetText("0"); icon.ChargeCount:Show()
            elseif icon.useSpellId then
                local start, duration = C_Container.GetItemCooldown(icon.trackedId)
                if start and duration and duration > 1.5 then
                    if icon.activeDuration and duration > icon.activeDuration and (GetTime() - start) < icon.activeDuration then
                        icon.Cooldown:Clear()
                        icon.ActiveCooldown:SetCooldown(start, icon.activeDuration)
                        icon.Icon:SetDesaturation(0)
                    else
                        icon.Cooldown:SetCooldown(start, duration)
                        icon.ActiveCooldown:Clear()
                        icon.Icon:SetDesaturation(1)
                    end
                else
                    local durObj = C_Spell.GetSpellCooldownDuration(icon.useSpellId)
                    if durObj then
                        icon.Cooldown:SetCooldownFromDurationObject(durObj, true)
                        icon.Icon:SetDesaturation(durObj:EvaluateRemainingPercent(DESAT_CURVE))
                    else
                        icon.Cooldown:Clear()
                        icon.Icon:SetDesaturation(0)
                    end
                    icon.ActiveCooldown:Clear()
                end
                local count = C_Item.GetItemCount(icon.trackedId, false, true)
                if count and count > 1 then icon.ChargeCount.Current:SetText(count); icon.ChargeCount:Show()
                else icon.ChargeCount:Hide() end
            else
                local start, duration = C_Container.GetItemCooldown(icon.trackedId)
                if start and duration and duration > 0 then
                    if icon.activeDuration and duration > icon.activeDuration and (GetTime() - start) < icon.activeDuration then
                        icon.Cooldown:Clear()
                        icon.ActiveCooldown:SetCooldown(start, icon.activeDuration)
                        icon.Icon:SetDesaturation(0)
                    else
                        icon.Cooldown:SetCooldown(start, duration)
                        icon.ActiveCooldown:Clear()
                        icon.Icon:SetDesaturation(1)
                    end
                else
                    icon.Cooldown:Clear()
                    icon.ActiveCooldown:Clear()
                    icon.Icon:SetDesaturation(0)
                end
                local count = C_Item.GetItemCount(icon.trackedId, false, true)
                if count and count > 1 then icon.ChargeCount.Current:SetText(count); icon.ChargeCount:Show()
                else icon.ChargeCount:Hide() end
            end
        end
    end

    if not texture then
        icon.Icon:SetTexture(PLACEHOLDER_ICON)
        icon.Icon:SetDesaturation(1)
        icon.Cooldown:Clear()
        icon.ChargeCount:Hide()
    end
    icon:Show()
end

-- [ DATA MANAGEMENT ]-------------------------------------------------------------------------------
function Injection:GetInjectedItems(systemIndex)
    return Plugin:GetSpecData(systemIndex, "InjectedItems") or {}
end

function Injection:SetInjectedItems(systemIndex, items)
    Plugin:SetSpecData(systemIndex, "InjectedItems", items)
end

function Injection:AddItem(systemIndex, itemType, itemId, afterNativeIndex, arrayIndex)
    local items = self:GetInjectedItems(systemIndex)
    local slotId = (itemType == "item") and ResolveEquipmentSlot(itemId) or nil
    for _, entry in ipairs(items) do
        if slotId and entry.slotId == slotId then return end
        if not slotId and entry.type == itemType and entry.id == itemId then return end
    end
    local useSpellId = (itemType == "item") and select(2, GetItemSpell(itemId)) or nil
    local parseId = (itemType == "spell") and GetActiveSpellID(itemId) or itemId
    local activeDuration = GetParser() and ParseActiveDuration(itemType, parseId) or nil
    local entry = { type = itemType, id = itemId, useSpellId = useSpellId, slotId = slotId, activeDuration = activeDuration, afterNativeIndex = afterNativeIndex or 0 }
    if arrayIndex and arrayIndex <= #items then
        table.insert(items, arrayIndex, entry)
    else
        items[#items + 1] = entry
    end
    self:SetInjectedItems(systemIndex, items)
    self:RefreshFrames(systemIndex)
end

function Injection:RemoveItemAtIndex(systemIndex, removeIdx)
    local items = self:GetInjectedItems(systemIndex)
    table.remove(items, removeIdx)
    self:SetInjectedItems(systemIndex, items)
    self:RefreshFrames(systemIndex)
end

-- [ FRAME MANAGEMENT ]------------------------------------------------------------------------------
function Injection:GetRecyclePool(systemIndex)
    if not Plugin.injectedRecyclePools[systemIndex] then Plugin.injectedRecyclePools[systemIndex] = {} end
    return Plugin.injectedRecyclePools[systemIndex]
end

function Injection:AcquireFrame(systemIndex, parent)
    local pool = self:GetRecyclePool(systemIndex)
    local frame = table.remove(pool)
    if frame then
        frame:SetParent(parent)
        frame:ClearAllPoints()
        frame.Cooldown:Clear()
        frame.ActiveCooldown:Clear()
        frame.ChargeCount:Hide()
        return frame
    end
    return CreateInjectedIcon(parent, systemIndex)
end

function Injection:ReleaseFrame(systemIndex, frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame.trackedType = nil
    frame.trackedId = nil
    frame.useSpellId = nil
    frame.Cooldown:Clear()
    frame.ActiveCooldown:Clear()
    frame.ChargeCount:Hide()
    local pool = self:GetRecyclePool(systemIndex)
    pool[#pool + 1] = frame
end

function Injection:RefreshFrames(systemIndex)
    local items = self:GetInjectedItems(systemIndex)
    local active = Plugin.injectedFrames[systemIndex] or {}
    -- Release excess frames
    for i = #items + 1, #active do
        self:ReleaseFrame(systemIndex, active[i])
        active[i] = nil
    end
    -- Acquire/update frames — parent to blizzFrame (viewer) so ApplyManualLayout positions them correctly
    local viewerMap = Plugin.viewerMap
    local entry = viewerMap[systemIndex]
    local parent = entry and entry.viewer or UIParent
    for i, data in ipairs(items) do
        local frame = active[i]
        if not frame then
            frame = self:AcquireFrame(systemIndex, parent)
            active[i] = frame
        else
            frame:SetParent(parent)
        end
        frame.systemIndex = systemIndex
        frame.trackedType = data.type
        frame.trackedId = data.id
        frame.useSpellId = data.useSpellId
        frame.activeDuration = data.activeDuration
        frame.injectedIndex = i
        frame.afterNativeIndex = data.afterNativeIndex or 0
        self:UpdateIcon(frame)
    end
    Plugin.injectedFrames[systemIndex] = active
    -- Trigger layout refresh
    if entry and entry.anchor and Plugin.ProcessChildren then
        Plugin:ProcessChildren(entry.anchor)
    end
end

-- [ PUBLIC API ]------------------------------------------------------------------------------------
function Injection:GetActiveFrames(systemIndex)
    local frames = Plugin.injectedFrames[systemIndex]
    if not frames or #frames == 0 then return nil end
    return frames
end

-- [ DRAG AND DROP ]----------------------------------------------------------------------------------
function Injection:OnViewerReceiveDrag(anchor)
    local itemType, actualId = ResolveCursorInfo()
    if not itemType then return end
    if not HasCooldown(itemType, actualId) then return end
    local targetAfterNativeIndex, arrayIndex = self:GetDropInsertionInfo(anchor)
    self:RemovePhantom()
    ClearCursor()
    self:AddItem(anchor.systemIndex, itemType, actualId, targetAfterNativeIndex, arrayIndex)
end

function Injection:OnIconReceiveDrag(icon)
    -- Forward to the parent anchor so the cursor-position logic handles placement
    local entry = Plugin.viewerMap[icon.systemIndex]
    if entry and entry.anchor then self:OnViewerReceiveDrag(entry.anchor) end
end

function Injection:RemoveInjectedIcon(icon)
    local systemIndex = icon.systemIndex
    local idx = icon.injectedIndex
    if not idx then return end
    self:RemoveItemAtIndex(systemIndex, idx)
end

function Injection:FlushAll()
    for _, sysIdx in ipairs({ ESSENTIAL_INDEX, UTILITY_INDEX }) do
        self:SetInjectedItems(sysIdx, {})
        local active = Plugin.injectedFrames[sysIdx] or {}
        for i = #active, 1, -1 do
            self:ReleaseFrame(sysIdx, active[i])
            active[i] = nil
        end
        Plugin.injectedFrames[sysIdx] = active
        local entry = Plugin.viewerMap[sysIdx]
        if entry and entry.anchor and Plugin.ProcessChildren then
            Plugin:ProcessChildren(entry.anchor)
        end
    end
end

-- [ UPDATE TICKER ]---------------------------------------------------------------------------------
function Injection:StartUpdateTicker()
    if Plugin._injectedTickerSetup then return end
    Plugin._injectedTickerSetup = true
    local nextUpdate = 0
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    frame:RegisterEvent("BAG_UPDATE")
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    frame:SetScript("OnEvent", function(_, event, unit, _, spellId)
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            Injection:OnEquipmentChanged()
            return
        end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            Injection:OnSpellCast(spellId)
            return
        end
        local now = GetTime()
        if now < nextUpdate then return end
        nextUpdate = now + COOLDOWN_THROTTLE
        for _, sysIdx in ipairs({ ESSENTIAL_INDEX, UTILITY_INDEX }) do
            local frames = Plugin.injectedFrames[sysIdx]
            if frames then
                for _, icon in ipairs(frames) do
                    if icon:IsShown() then Injection:UpdateIcon(icon) end
                end
            end
        end
    end)
end

-- [ SPELL CAST HANDLER ]----------------------------------------------------------------------------
function Injection:OnSpellCast(spellId)
    if not spellId then return end
    for _, sysIdx in ipairs({ ESSENTIAL_INDEX, UTILITY_INDEX }) do
        local frames = Plugin.injectedFrames[sysIdx]
        if frames then
            for _, icon in ipairs(frames) do
                local isMatch = (icon.trackedType == "spell" and icon.trackedId == spellId)
                    or (icon.trackedType == "item" and icon.useSpellId == spellId)
                if isMatch and icon.activeDuration then
                    icon._activeGlowExpiry = GetTime() + icon.activeDuration
                    local expectedId = icon.trackedId
                    C_Timer.After(icon.activeDuration, function()
                        if icon.trackedId ~= expectedId then return end
                        icon._activeGlowExpiry = nil
                    end)
                end
            end
        end
    end
end

-- [ EQUIPMENT CHANGE HANDLER ]----------------------------------------------------------------------
function Injection:OnEquipmentChanged()
    for _, sysIdx in ipairs({ ESSENTIAL_INDEX, UTILITY_INDEX }) do
        local items = self:GetInjectedItems(sysIdx)
        local changed = false
        for i = #items, 1, -1 do
            local entry = items[i]
            if entry.slotId then
                local newItemId = GetInventoryItemID("player", entry.slotId)
                if newItemId and newItemId ~= entry.id then
                    entry.id = newItemId
                    entry.useSpellId = select(2, GetItemSpell(newItemId)) or nil
                    changed = true
                elseif not newItemId then
                    table.remove(items, i)
                    changed = true
                end
            end
        end
        if changed then
            self:SetInjectedItems(sysIdx, items)
            self:RefreshFrames(sysIdx)
        end
    end
end

-- [ DROP ZONE OVERLAYS ]----------------------------------------------------------------------------
local function CreateGlowCorner(parent, point, l, r, t, b)
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas(GLOW_ATLAS)
    tex:SetTexCoord(l, r, t, b)
    tex:SetSize(GLOW_SIZE, GLOW_SIZE)
    tex:SetPoint(point, parent, point)
    tex:SetBlendMode("ADD")
    return tex
end

local function CreateGlowEdge(parent, point1, point2, isVertical, l, r, t, b)
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas(GLOW_ATLAS)
    tex:SetTexCoord(l, r, t, b)
    tex:SetBlendMode("ADD")
    if isVertical then
        tex:SetWidth(GLOW_SIZE)
        tex:SetPoint("TOPLEFT", parent, point1, point1 == "TOPLEFT" and 0 or -GLOW_SIZE, -GLOW_SIZE)
        tex:SetPoint("BOTTOMRIGHT", parent, point2, point2 == "BOTTOMRIGHT" and 0 or GLOW_SIZE, GLOW_SIZE)
    else
        tex:SetHeight(GLOW_SIZE)
        tex:SetPoint("TOPLEFT", parent, point1, GLOW_SIZE, point1 == "TOPLEFT" and 0 or GLOW_SIZE)
        tex:SetPoint("BOTTOMRIGHT", parent, point2, -GLOW_SIZE, point2 == "BOTTOMRIGHT" and 0 or -GLOW_SIZE)
    end
    return tex
end

local function GetCursorTexture()
    local itemType, id = ResolveCursorInfo()
    if not itemType then return nil end
    if itemType == "spell" then
        local info = C_Spell.GetSpellInfo(GetActiveSpellID(id))
        return info and info.iconID
    elseif itemType == "item" then
        return C_Item.GetItemIconByID(id)
    end
    return nil
end

function Injection:CreateDropZone(anchor)
    if anchor._dropZone then return end
    local zone = CreateFrame("Frame", nil, UIParent)
    zone:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    zone:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
    zone:SetFrameStrata("TOOLTIP")
    zone:SetFrameLevel(999)
    -- Glow container extending beyond frame edges, placed in background
    local glow = CreateFrame("Frame", nil, UIParent)
    glow:SetFrameStrata("BACKGROUND")
    glow:SetFrameLevel(0)
    glow:SetScript("OnShow", function(self)
        local borderSize = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BorderSize or 1
        local outset = (borderSize + GLOW_OUTSET_BASE)
        self:SetPoint("TOPLEFT", anchor, "TOPLEFT", -outset, outset)
        self:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", outset, -outset)
    end)
    CreateGlowCorner(glow, "TOPLEFT", 0, GLOW_SLICE_START, 0, GLOW_SLICE_START)
    CreateGlowCorner(glow, "TOPRIGHT", GLOW_SLICE_END, 1, 0, GLOW_SLICE_START)
    CreateGlowCorner(glow, "BOTTOMLEFT", 0, GLOW_SLICE_START, GLOW_SLICE_END, 1)
    CreateGlowCorner(glow, "BOTTOMRIGHT", GLOW_SLICE_END, 1, GLOW_SLICE_END, 1)
    CreateGlowEdge(glow, "TOPLEFT", "TOPRIGHT", false, GLOW_SLICE_START, GLOW_SLICE_END, 0, GLOW_SLICE_START)
    CreateGlowEdge(glow, "BOTTOMLEFT", "BOTTOMRIGHT", false, GLOW_SLICE_START, GLOW_SLICE_END, GLOW_SLICE_END, 1)
    CreateGlowEdge(glow, "TOPLEFT", "BOTTOMLEFT", true, 0, GLOW_SLICE_START, GLOW_SLICE_START, GLOW_SLICE_END)
    CreateGlowEdge(glow, "TOPRIGHT", "BOTTOMRIGHT", true, GLOW_SLICE_END, 1, GLOW_SLICE_START, GLOW_SLICE_END)
    glow:Hide()
    zone.Glow = glow
    zone:Hide()
    zone:SetScript("OnShow", function() glow:Show() end)
    zone:SetScript("OnHide", function()
        glow:Hide()
        Injection:RemovePhantom()
    end)
    anchor._dropZone = zone
end

-- [ PHANTOM PREVIEW ]-------------------------------------------------------------------------------
function Injection:GetOrCreatePhantom(sysIdx)
    if self._phantom then return self._phantom end
    local entry = Plugin.viewerMap[sysIdx]
    local parent = entry and entry.viewer or UIParent
    local icon = CreateInjectedIcon(parent, sysIdx)
    icon.isPhantom = true
    icon:SetAlpha(PREVIEW_ALPHA)
    icon:Show()
    self._phantom = icon
    self._phantomSysIdx = nil
    self._phantomArrayIdx = nil
    return icon
end

function Injection:RemovePhantom()
    if not self._phantom then return end
    local sysIdx = self._phantomSysIdx
    if sysIdx then
        local frames = Plugin.injectedFrames[sysIdx]
        if frames then
            for i = #frames, 1, -1 do
                if frames[i] == self._phantom then table.remove(frames, i); break end
            end
        end
        local entry = Plugin.viewerMap[sysIdx]
        if entry and entry.anchor and Plugin.ProcessChildren then
            Plugin:ProcessChildren(entry.anchor)
        end
    end
    self._phantom:Hide()
    self._phantom:ClearAllPoints()
    self._phantom = nil
    self._phantomSysIdx = nil
    self._phantomArrayIdx = nil
    self._phantomAfterNative = nil
end

function Injection:GetVisiblePositions(anchor, nativeOnly)
    local sysIdx = anchor.systemIndex
    local entry = Plugin.viewerMap[sysIdx]
    if not entry or not entry.viewer then return {} end
    local blizzFrame = entry.viewer
    local scale = blizzFrame:GetEffectiveScale()
    local positions = {}
    for i = 1, select("#", blizzFrame:GetChildren()) do
        local child = select(i, blizzFrame:GetChildren())
        if child and child:IsShown() and child:GetLeft() and not child.isPhantom and (not nativeOnly or not child.isInjectedIcon) then
            positions[#positions + 1] = {
                frame = child,
                left = child:GetLeft() * scale,
                right = child:GetRight() * scale,
                mid = (child:GetLeft() + child:GetRight()) / 2 * scale,
            }
        end
    end
    table.sort(positions, function(a, b) return a.left < b.left end)
    return positions
end

function Injection:GetDropInsertionInfo(anchor)
    local cx = GetCursorPosition()
    local positions = self:GetVisiblePositions(anchor, false)
    local dropVisualIdx = #positions + 1
    for i, pos in ipairs(positions) do
        if cx < pos.mid then dropVisualIdx = i; break end
    end
    
    local sysIdx = anchor.systemIndex
    local existingItems = self:GetInjectedItems(sysIdx)
    local frames = Plugin.injectedFrames[sysIdx] or {}
    -- Filter out phantom from frame lookups
    local realFrames = {}
    for _, f in ipairs(frames) do
        if not f.isPhantom then realFrames[#realFrames + 1] = f end
    end
    
    local frameBefore = (dropVisualIdx > 1) and positions[dropVisualIdx - 1].frame or nil
    local frameAfter = (dropVisualIdx <= #positions) and positions[dropVisualIdx].frame or nil
    
    local nativeCount = 0
    for i = 1, dropVisualIdx - 1 do
        if not positions[i].frame.isInjectedIcon then nativeCount = nativeCount + 1 end
    end
    
    local targetAfterNativeIndex = nativeCount
    local insertArrayIndex = #existingItems + 1
    
    if frameBefore and frameBefore.isInjectedIcon then
        for i, f in ipairs(realFrames) do
            if f == frameBefore then insertArrayIndex = i + 1; break end
        end
    elseif frameAfter and frameAfter.isInjectedIcon then
        for i, f in ipairs(realFrames) do
            if f == frameAfter then insertArrayIndex = i; break end
        end
    else
        for i, item in ipairs(existingItems) do
            if item.afterNativeIndex >= targetAfterNativeIndex then insertArrayIndex = i; break end
        end
    end
    
    return targetAfterNativeIndex, insertArrayIndex
end

function Injection:UpdateDropZoneHighlight(anchor)
    local zone = anchor._dropZone
    if not zone or not zone:IsShown() then return end
    local sysIdx = anchor.systemIndex
    
    local cx, cy = GetCursorPosition()
    local scale = anchor:GetEffectiveScale()
    local left, right, top, bottom = anchor:GetLeft(), anchor:GetRight(), anchor:GetTop(), anchor:GetBottom()
    if not (left and top and bottom) then
        if self._phantomSysIdx == sysIdx then self:RemovePhantom() end
        return
    end
    
    local boundsPadding = BOUNDS_PADDING * scale
    if cy > (top * scale) + boundsPadding or cy < (bottom * scale) - boundsPadding then
        if self._phantomSysIdx == sysIdx then self:RemovePhantom() end
        return
    end
    
    local tex = GetCursorTexture()
    if not tex then
        if self._phantomSysIdx == sysIdx then self:RemovePhantom() end
        return
    end
    
    local afterNative, arrayIdx = self:GetDropInsertionInfo(anchor)
    
    -- Only reflow if position actually changed
    if self._phantomSysIdx == sysIdx and self._phantomArrayIdx == arrayIdx and self._phantomAfterNative == afterNative then
        return
    end
    
    -- Remove from old position
    if self._phantomSysIdx then
        local oldFrames = Plugin.injectedFrames[self._phantomSysIdx]
        if oldFrames then
            for i = #oldFrames, 1, -1 do
                if oldFrames[i] == self._phantom then table.remove(oldFrames, i); break end
            end
        end
    end
    
    local phantom = self:GetOrCreatePhantom(sysIdx)
    phantom.Icon:SetTexture(tex)
    phantom.afterNativeIndex = afterNative
    phantom.systemIndex = sysIdx
    
    local entry = Plugin.viewerMap[sysIdx]
    local parent = entry and entry.viewer or UIParent
    phantom:SetParent(parent)
    
    local frames = Plugin.injectedFrames[sysIdx] or {}
    Plugin.injectedFrames[sysIdx] = frames
    local clampedIdx = math.min(arrayIdx, #frames + 1)
    table.insert(frames, clampedIdx, phantom)
    
    self._phantomSysIdx = sysIdx
    self._phantomArrayIdx = arrayIdx
    self._phantomAfterNative = afterNative
    
    if entry and entry.anchor and Plugin.ProcessChildren then
        Plugin:ProcessChildren(entry.anchor)
    end
end

function Injection:ShowDropZones()
    for _, sysIdx in ipairs({ ESSENTIAL_INDEX, UTILITY_INDEX }) do
        local entry = Plugin.viewerMap[sysIdx]
        if entry and entry.anchor and entry.anchor._dropZone then
            entry.anchor._dropZone:Show()
        end
    end
    if not self._dropZoneTicker then
        self._dropZoneTicker = C_Timer.NewTicker(DROP_ZONE_TICK_RATE, function()
            if not self._dropZonesVisible then
                self._dropZoneTicker:Cancel()
                self._dropZoneTicker = nil
                return
            end
            -- Find which viewer the cursor is closest to vertically
            local _, cy = GetCursorPosition()
            local bestAnchor, bestDist = nil, math.huge
            for _, sysIdx in ipairs({ ESSENTIAL_INDEX, UTILITY_INDEX }) do
                local entry = Plugin.viewerMap[sysIdx]
                if entry and entry.anchor then
                    local anchor = entry.anchor
                    local top, bottom = anchor:GetTop(), anchor:GetBottom()
                    local scale = anchor:GetEffectiveScale()
                    if top and bottom then
                        local midY = (top + bottom) / 2 * scale
                        local dist = math.abs(cy - midY)
                        if dist < bestDist then
                            bestDist = dist
                            bestAnchor = anchor
                        end
                    end
                end
            end
            if bestAnchor then
                -- Remove phantom from any other viewer
                if self._phantomSysIdx and self._phantomSysIdx ~= bestAnchor.systemIndex then
                    self:RemovePhantom()
                end
                self:UpdateDropZoneHighlight(bestAnchor)
            end
        end)
    end
    self._dropZonesVisible = true
end

function Injection:HideDropZones()
    self._dropZonesVisible = false
    for _, sysIdx in ipairs({ ESSENTIAL_INDEX, UTILITY_INDEX }) do
        local entry = Plugin.viewerMap[sysIdx]
        if entry and entry.anchor and entry.anchor._dropZone then
            entry.anchor._dropZone:Hide()
        end
    end
end

-- [ CURSOR WATCHER INTEGRATION ]--------------------------------------------------------------------
function Injection:SetClickEnabled(enabled)
    local isDroppable = enabled and self:IsDraggingCooldownAbility()
    for _, sysIdx in ipairs({ ESSENTIAL_INDEX, UTILITY_INDEX }) do
        local frames = Plugin.injectedFrames[sysIdx]
        if frames then
            for _, icon in ipairs(frames) do
                icon:EnableMouse(enabled)
            end
        end
        local entry = Plugin.viewerMap[sysIdx]
        if entry and entry.anchor then
            entry.anchor:EnableMouse(enabled)
        end
    end
    if isDroppable then self:ShowDropZones() else self:HideDropZones() end
end

function Injection:IsDraggingCooldownAbility()
    local itemType, actualId = ResolveCursorInfo()
    if not itemType then return false end
    local ok, result = pcall(HasCooldown, itemType, actualId)
    if not (ok and result) then return false end
    
    local slotId = (itemType == "item") and ResolveEquipmentSlot(actualId) or nil
    for _, sysIdx in ipairs({ ESSENTIAL_INDEX, UTILITY_INDEX }) do
        local items = self:GetInjectedItems(sysIdx)
        for _, entry in ipairs(items) do
            if slotId and entry.slotId == slotId then return false end
            if not slotId and entry.type == itemType and entry.id == actualId then return false end
        end
    end
    
    return true
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Injection:Initialize()
    for _, sysIdx in ipairs({ ESSENTIAL_INDEX, UTILITY_INDEX }) do
        self:RefreshFrames(sysIdx)
        local entry = Plugin.viewerMap[sysIdx]
        if entry and entry.anchor then
            local anchor = entry.anchor
            self:CreateDropZone(anchor)
            anchor:SetHitRectInsets(HIT_RECT_INSET, HIT_RECT_INSET, HIT_RECT_INSET, HIT_RECT_INSET)
            anchor:SetScript("OnReceiveDrag", function(self) Injection:OnViewerReceiveDrag(self) end)
            local origMouseDown = anchor:GetScript("OnMouseDown")
            anchor:SetScript("OnMouseDown", function(self, button, ...)
                if GetCursorInfo() then
                    Injection:OnViewerReceiveDrag(self)
                    return
                end
                if origMouseDown then origMouseDown(self, button, ...) end
            end)
        end
    end
    self:StartUpdateTicker()
end

-- [ SPEC CHANGE ]-----------------------------------------------------------------------------------
function Injection:OnSpecChanged()
    for _, sysIdx in ipairs({ ESSENTIAL_INDEX, UTILITY_INDEX }) do
        self:RefreshFrames(sysIdx)
    end
end
