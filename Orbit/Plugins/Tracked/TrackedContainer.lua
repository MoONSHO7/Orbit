-- [ TRACKED CONTAINER ] -------------------------------------------------------
-- Icons-mode sparse 2D grid with neighbor-expansion drop zones and per-container update ticker.
local _, Orbit = ...

local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils
local DragDrop = Orbit.CooldownDragDrop

-- [ CONSTANTS ] ---------------------------------------------------------------
local DROP_ZONE_BACKDROP_ATLAS = "cdm-empty"
local DROP_ZONE_BG_ATLAS = "talents-node-choiceflyout-square-green"
local DROP_ZONE_PLUS_ATLAS = "bags-icon-addslots"
local DROP_ZONE_ALPHA_IDLE = 0.4
local DROP_ZONE_ALPHA_HOVER = 1.0
local DROP_ZONE_PLUS_INSET_RATIO = 0.28
local MAX_GRID_REACH = 10
local UPDATE_INTERVAL = 0.1
local VISUAL_POLL_INTERVAL = 0.3
local COOLDOWN_THROTTLE = 0.1
local TALENT_REPARSE_DELAY = 0.5
local EQUIPMENT_SLOTS = { 13, 14 }

-- [ TOOLTIP PARSER ALIASES ] --------------------------------------------------
local Parser = Orbit.TooltipParser
local ParseActiveDuration = function(t, id) return Parser:ParseActiveDuration(t, id) end
local ParseCooldownDuration = function(t, id) return Parser:ParseCooldownDuration(t, id) end
local BuildPhaseCurve = function(a, c) return Parser:BuildPhaseCurve(a, c) end

-- [ SPELL OVERRIDE ALIAS ] ----------------------------------------------------
local function GetActiveSpellID(spellID) return FindSpellOverrideByID(spellID) end

-- [ MODULE ] ------------------------------------------------------------------
Orbit.TrackedContainer = {}
local Container = Orbit.TrackedContainer

-- [ GRID HELPERS ] ------------------------------------------------------------
local function GridKey(x, y) return x .. "," .. y end
local function ParseGridKey(key)
    local x, y = key:match("^(-?%d+),(-?%d+)$")
    return tonumber(x), tonumber(y)
end

-- [ FRAME FACTORY ] -----------------------------------------------------------
function Container:Build(plugin, record)
    local frame = CreateFrame("Frame", "OrbitTrackedContainer" .. record.id, UIParent)
    OrbitEngine.Pixel:Enforce(frame)
    frame:SetSize(40, 40)
    frame:SetClampedToScreen(true)
    frame.systemIndex = record.id
    frame.editModeName = "Tracked Icons"
    frame.orbitPlugin = plugin
    frame.recordId = record.id
    frame.iconItems = {} -- key -> icon item frame
    frame.dropZones = {} -- index -> drop zone frame
    frame.anchorOptions = { horizontal = true, vertical = true, syncScale = false, syncDimensions = false, mergeBorders = true }
    frame.orbitChainSync = true
    frame.orbitCursorReveal = true
    frame.orbitAnchorTargetPerSpec = true
    frame._isIconContainer = true

    OrbitEngine.Frame:AttachSettingsListener(frame, plugin, record.id)

    frame.Selection = frame:CreateTexture(nil, "OVERLAY")
    frame.Selection:SetColorTexture(1, 1, 1, 0.1)
    frame.Selection:SetAllPoints()
    frame.Selection:Hide()

    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnReceiveDrag", function(self) Container:OnReceiveDrag(plugin, self) end)
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() and self:IsGridEmpty() then
            plugin:DeleteContainer(self.recordId)
            return
        end
        if GetCursorInfo() then
            Container:OnReceiveDrag(plugin, self)
        end
    end)

    function frame:IsGridEmpty()
        local rec = plugin:GetContainerRecord(self.recordId)
        if not rec or not rec.grid then return true end
        return next(rec.grid) == nil
    end

    -- Canvas Mode: representative icon preview with draggable ChargeText component.
    function frame:CreateCanvasPreview(options)
        local rec = plugin:GetContainerRecord(self.recordId)
        if not rec then return nil end

        local w, h = CooldownUtils:CalculateIconDimensions(plugin, self.recordId)
        local iconTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
        for _, item in pairs(self.iconItems) do
            if item:IsShown() and item.Icon then
                local tex = item.Icon:GetTexture()
                if tex then iconTexture = tex; break end
            end
        end

        local preview = OrbitEngine.IconCanvasPreview:Create(self, options.parent or UIParent, w, h, iconTexture)
        preview.systemIndex = self.recordId

        local savedPositions = plugin:GetSetting(self.recordId, "ComponentPositions") or {}
        local fontPath = plugin:GetGlobalFont()

        OrbitEngine.IconCanvasPreview:AttachTextComponents(preview, {
            { key = "ChargeText", preview = "2", anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
        }, savedPositions, fontPath)

        return preview
    end

    frame.OnAnchorChanged = function(self) Container:Apply(plugin, self, plugin:GetContainerRecord(self.recordId)) end

    Container:StartCursorWatcher(plugin, frame)
    Container:StartUpdateTicker(plugin, frame)
    Container:StartSpellCastWatcher(plugin, frame)
    return frame
end

-- [ APPLY / LAYOUT ] ----------------------------------------------------------
-- Recompute grid layout, drop zones, and container size on any state change.
function Container:Apply(plugin, frame, record)
    if not frame or not record then return end
    plugin:RefreshContainerVirtualState(frame)
    -- Visibility Engine: every icon container shares the "TrackedIcons" entry
    -- (sentinel index 1). Real record IDs are >= 1000 so the sentinel can't
    -- collide. ApplyOOCFade is idempotent — safe to call from the layout pass.
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, plugin, 1, "OutOfCombatFade", false) end
    local iconW, iconH = CooldownUtils:CalculateIconDimensions(plugin, record.id)
    local rawPadding = plugin:GetSetting(record.id, "IconPadding") or Constants.Cooldown.DefaultPadding
    local Pixel = OrbitEngine.Pixel
    local padding = Pixel and Pixel:Multiple(rawPadding) or rawPadding
    local skinSettings = CooldownUtils:BuildSkinSettings(plugin, record.id)

    self:ClearDropZones(frame)

    local grid = record.grid or {}
    local minX, maxX, minY, maxY, hasItems = self:ComputeBounds(grid)

    for key, icon in pairs(frame.iconItems) do
        if not grid[key] then icon:Hide() end
    end

    -- Cache per-container settings once for all icons.
    local hideOnCd = plugin:GetSetting(record.id, "HideOnCooldown") or false
    local hideOnReady = plugin:GetSetting(record.id, "HideOnAvailable") or false
    local showGCDSwipe = plugin:GetSetting(record.id, "ShowGCDSwipe") ~= false
    local GU = OrbitEngine.GlowUtils
    local glowTypeName, glowOptions
    if GU then glowTypeName, glowOptions = GU:BuildOptions(plugin, record.id, "ActiveGlow", Constants.Glow.DefaultColor, "orbitActive") end

    for key, data in pairs(grid) do
        local icon = frame.iconItems[key] or self:AcquireIcon(plugin, frame, key)
        icon.trackedType = data.type
        icon.trackedId = data.id
        icon._activeDuration = data.activeDuration
        icon._cooldownDuration = data.cooldownDuration
        icon._useSpellId = data.useSpellId
        icon._showGCDSwipe = showGCDSwipe
        icon._hideOnCooldown = hideOnCd
        icon._hideOnAvailable = hideOnReady
        icon._activeGlowTypeName = glowTypeName
        icon._activeGlowOptions = glowOptions
        -- Charge spell detection
        if data.type == "spell" then
            local isCharge, ci = DragDrop:IsChargeSpell(data.id)
            icon._isChargeSpell = isCharge
            icon._maxCharges = ci and ci.maxCharges or nil
        else
            icon._isChargeSpell = false
            icon._maxCharges = nil
        end
        -- Phase-aware curves for active-duration spells
        local hasActive = data.activeDuration and data.cooldownDuration
        icon._desatCurve = hasActive and BuildPhaseCurve(data.activeDuration, data.cooldownDuration) or nil
        icon._cdAlphaCurve = hasActive and BuildPhaseCurve(data.activeDuration, data.cooldownDuration) or nil
        icon:SetSize(iconW, iconH)
        if Orbit.Skin and Orbit.Skin.Icons then
            Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
        end
        Orbit.TrackedIconItem:ApplyFont(plugin, icon)
        Orbit.TrackedIconItem:ApplySwipeColor(plugin, icon, record.id)
        Orbit.TrackedIconItem:ApplyCanvasComponents(plugin, icon, record.id)
        Orbit.TrackedIconItem:Update(icon)
    end

    local extMinX, extMaxX, extMinY, extMaxY = minX, maxX, minY, maxY
    local edgePositions
    local showHints = plugin:ShouldShowDropHints(not hasItems)
    if showHints then
        edgePositions = self:ComputeEdgePositions(frame, grid, minX, maxX, minY, maxY, hasItems)
        for _, pos in ipairs(edgePositions) do
            if hasItems then
                extMinX = math.min(extMinX, pos.x)
                extMaxX = math.max(extMaxX, pos.x)
                extMinY = math.min(extMinY, pos.y)
                extMaxY = math.max(extMaxY, pos.y)
            else
                extMinX, extMaxX, extMinY, extMaxY = pos.x, pos.x, pos.y, pos.y
            end
        end
    end

    if not hasItems and not showHints then
        frame:SetSize(iconW, iconH)
        return
    end

    if not hasItems then extMinX, extMaxX, extMinY, extMaxY = 0, 0, 0, 0 end

    for key, icon in pairs(frame.iconItems) do
        if grid[key] then
            local x, y = ParseGridKey(key)
            local posX = (x - extMinX) * (iconW + padding)
            local posY = -(y - extMinY) * (iconH + padding)
            if Pixel then posX = Pixel:Snap(posX); posY = Pixel:Snap(posY) end
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", frame, "TOPLEFT", posX, posY)
        end
    end

    if showHints and edgePositions then
        for i, pos in ipairs(edgePositions) do
            local zone = self:AcquireDropZone(plugin, frame, i, pos.x, pos.y, iconW, iconH)
            zone:SetSize(iconW, iconH)
            local posX = (pos.x - extMinX) * (iconW + padding)
            local posY = -(pos.y - extMinY) * (iconH + padding)
            if Pixel then posX = Pixel:Snap(posX); posY = Pixel:Snap(posY) end
            zone:ClearAllPoints()
            zone:SetPoint("TOPLEFT", frame, "TOPLEFT", posX, posY)
            zone:Show()
        end
    end

    local cols = (extMaxX - extMinX + 1)
    local rows = (extMaxY - extMinY + 1)
    local totalW = cols * iconW + (cols - 1) * padding
    local totalH = rows * iconH + (rows - 1) * padding
    frame:SetSize(math.max(totalW, iconW), math.max(totalH, iconH))

    -- At padding 0, draw a single wrapper border around merged icons; otherwise clear it.
    if rawPadding == 0 and hasItems then
        local iconNineSlice = Orbit.Skin:GetActiveIconBorderStyle()
        Orbit.Skin:ApplyIconGroupBorder(frame, iconNineSlice)
    else
        Orbit.Skin:ClearIconGroupBorder(frame)
    end
end

function Container:ComputeBounds(grid)
    local minX, maxX, minY, maxY
    local hasItems = false
    for key in pairs(grid) do
        local x, y = ParseGridKey(key)
        if x then
            if not hasItems then
                minX, maxX, minY, maxY = x, x, y, y
                hasItems = true
            else
                if x < minX then minX = x end
                if x > maxX then maxX = x end
                if y < minY then minY = y end
                if y > maxY then maxY = y end
            end
        end
    end
    if not hasItems then minX, maxX, minY, maxY = 0, 0, 0, 0 end
    return minX, maxX, minY, maxY, hasItems
end

-- [ DROP ZONE EDGE EXPANSION ] ------------------------------------------------
-- Find empty cardinal neighbors of grid items; blocked directions prevent growth into anchored edges.
function Container:ComputeEdgePositions(frame, grid, minX, maxX, minY, maxY, hasItems)
    local positions = {}
    if not hasItems then
        positions[1] = { x = 0, y = 0 }
        return positions
    end

    local checked = {}
    local blocked = self:GetBlockedDirections(frame)

    for key in pairs(grid) do
        local x, y = ParseGridKey(key)
        if x then
            local blockLeft = blocked.left and x == minX
            local blockRight = blocked.right and x == maxX
            local blockTop = blocked.top and y == minY
            local blockBottom = blocked.bottom and y == maxY
            local neighbors = {}
            if not blockLeft then neighbors[#neighbors + 1] = { x - 1, y } end
            if not blockRight then neighbors[#neighbors + 1] = { x + 1, y } end
            if not blockTop then neighbors[#neighbors + 1] = { x, y - 1 } end
            if not blockBottom then neighbors[#neighbors + 1] = { x, y + 1 } end
            for _, n in ipairs(neighbors) do
                local nx, ny = n[1], n[2]
                local nKey = GridKey(nx, ny)
                if not grid[nKey] and not checked[nKey] then
                    if nx >= -MAX_GRID_REACH and nx <= MAX_GRID_REACH and ny >= -MAX_GRID_REACH and ny <= MAX_GRID_REACH then
                        positions[#positions + 1] = { x = nx, y = ny }
                        checked[nKey] = true
                    end
                end
            end
        end
    end
    return positions
end

function Container:GetBlockedDirections(frame)
    local blocked = {}
    local FrameAnchor = OrbitEngine.FrameAnchor
    if not FrameAnchor then return blocked end
    local data = FrameAnchor.anchors and FrameAnchor.anchors[frame]
    if data and data.edge then
        if data.edge == "BOTTOM" then blocked.top = true
        elseif data.edge == "TOP" then blocked.bottom = true
        elseif data.edge == "LEFT" then blocked.right = true
        elseif data.edge == "RIGHT" then blocked.left = true end
    end
    for _, childAnchor in pairs(FrameAnchor.anchors or {}) do
        if childAnchor.parent == frame then
            local edge = childAnchor.edge
            if edge == "TOP" then blocked.top = true
            elseif edge == "BOTTOM" then blocked.bottom = true
            elseif edge == "LEFT" then blocked.left = true
            elseif edge == "RIGHT" then blocked.right = true end
        end
    end
    return blocked
end

-- [ ICON ITEM POOLING ] -------------------------------------------------------
function Container:AcquireIcon(plugin, frame, key)
    local icon = Orbit.TrackedIconItem:Build(frame, function(removedIcon)
        Container:RemoveIconAt(plugin, frame, removedIcon)
    end)
    frame.iconItems[key] = icon
    return icon
end

function Container:RemoveIconAt(plugin, frame, icon)
    local record = plugin:GetContainerRecord(frame.recordId)
    if not record then return end
    for key, candidate in pairs(frame.iconItems) do
        if candidate == icon then
            record.grid[key] = nil
            icon:Hide()
            frame.iconItems[key] = nil
            break
        end
    end
    Container:Apply(plugin, frame, record)
end

-- [ DROP ZONES ] --------------------------------------------------------------
function Container:AcquireDropZone(plugin, frame, index, gridX, gridY, iconW, iconH)
    local zone = frame.dropZones[index]
    if not zone then
        zone = CreateFrame("Frame", nil, frame)
        zone.backdrop = zone:CreateTexture(nil, "BACKGROUND", nil, -1)
        zone.backdrop:SetAtlas(DROP_ZONE_BACKDROP_ATLAS)
        zone.backdrop:SetAllPoints()
        zone.bg = zone:CreateTexture(nil, "BACKGROUND")
        zone.bg:SetAtlas(DROP_ZONE_BG_ATLAS)
        zone.bg:SetAllPoints()
        zone.plus = zone:CreateTexture(nil, "OVERLAY")
        zone.plus:SetAtlas(DROP_ZONE_PLUS_ATLAS)
        zone.plus:SetPoint("CENTER")
        zone:EnableMouse(true)
        zone:SetScript("OnEnter", function(self) self:SetAlpha(DROP_ZONE_ALPHA_HOVER) end)
        zone:SetScript("OnLeave", function(self) self:SetAlpha(DROP_ZONE_ALPHA_IDLE) end)
        frame.dropZones[index] = zone
    end
    zone.gridX = gridX
    zone.gridY = gridY
    -- Route shift-right-click through to delete when grid is empty.
    zone:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() then
            if frame:IsGridEmpty() then plugin:DeleteContainer(frame.recordId) end
            return
        end
        Container:CommitDrop(plugin, frame, self.gridX, self.gridY)
    end)
    local plusSize = math.min(iconW, iconH) * (1 - DROP_ZONE_PLUS_INSET_RATIO * 2)
    zone.plus:SetSize(plusSize, plusSize)
    zone:SetAlpha(DROP_ZONE_ALPHA_IDLE)
    return zone
end

function Container:ClearDropZones(frame)
    for _, zone in pairs(frame.dropZones) do
        zone:Hide()
        zone:SetAlpha(DROP_ZONE_ALPHA_IDLE)
    end
end

-- [ DROP HANDLING ] -----------------------------------------------------------
function Container:OnReceiveDrag(plugin, frame)
    if not DragDrop:IsDraggingCooldownAbility() then return end
    local record = plugin:GetContainerRecord(frame.recordId)
    if not record then return end
    -- Body drop lands at the next free right-edge slot, or 0,0 if empty.
    local minX, maxX, minY, _, hasItems = self:ComputeBounds(record.grid or {})
    local x, y = 0, 0
    if hasItems then x = maxX + 1; y = minY end
    self:CommitDrop(plugin, frame, x, y)
end

function Container:CommitDrop(plugin, frame, gridX, gridY)
    if not DragDrop:IsDraggingCooldownAbility() then return end
    local itemType, itemId = DragDrop:ResolveCursorInfo()
    if not itemType then return end

    local record = plugin:GetContainerRecord(frame.recordId)
    if not record then return end
    record.grid = record.grid or {}

    local key = GridKey(gridX, gridY)
    if record.grid[key] then return end

    local entry = DragDrop:BuildTrackedItemEntry(itemType, itemId, gridX, gridY)
    if not entry then return end
    record.grid[key] = entry

    ClearCursor()
    Container:Apply(plugin, frame, record)
end

-- [ CURSOR WATCHER ] ----------------------------------------------------------
-- Independent per-container poll; triggers Apply when ShouldShowDropHints flips.
function Container:StartCursorWatcher(plugin, frame)
    if frame._cursorWatcher then return end
    local watcher = CreateFrame("Frame")
    watcher._wasShowing = false
    watcher:SetScript("OnUpdate", function(self)
        local record = plugin:GetContainerRecord(frame.recordId)
        if not record then return end
        local isEmpty = not record.grid or next(record.grid) == nil
        local now = plugin:ShouldShowDropHints(isEmpty)
        if now ~= self._wasShowing then
            self._wasShowing = now
            Container:Apply(plugin, frame, record)
        end
    end)
    frame._cursorWatcher = watcher
end

-- [ EVENT-DRIVEN UPDATE ] -----------------------------------------------------
-- Listens for cooldown/bag/spell events and updates all icons; throttled.
function Container:StartUpdateTicker(plugin, frame)
    if frame._eventFrame then return end
    local IconItem = Orbit.TrackedIconItem
    local nextUpdate = 0
    local evtFrame = CreateFrame("Frame")
    evtFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    evtFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    evtFrame:RegisterEvent("BAG_UPDATE")
    evtFrame:RegisterEvent("SPELLS_CHANGED")
    evtFrame:SetScript("OnEvent", function()
        local now = GetTime()
        if now < nextUpdate then return end
        nextUpdate = now + COOLDOWN_THROTTLE
        if not frame:IsShown() then return end
        for _, icon in pairs(frame.iconItems) do
            if icon:IsShown() then IconItem:Update(icon) end
        end
    end)
    -- Visual-state poll: re-evaluate desat/alpha/glow between event bursts.
    local pollAccum = 0
    evtFrame:SetScript("OnUpdate", function(_, elapsed)
        pollAccum = pollAccum + elapsed
        if pollAccum < VISUAL_POLL_INTERVAL then return end
        pollAccum = 0
        if not frame:IsShown() then return end
        for _, icon in pairs(frame.iconItems) do
            if icon:IsShown() and icon.trackedId then IconItem:Update(icon) end
        end
    end)
    frame._eventFrame = evtFrame
end

-- [ SPELL CAST WATCHER ] ------------------------------------------------------
-- Sets _activeGlowExpiry on cast and handles charge bookkeeping via OnChargeCast.
function Container:StartSpellCastWatcher(plugin, frame)
    if frame._castWatcher then return end
    local watcher = CreateFrame("Frame")
    watcher:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    watcher:RegisterEvent("TRAIT_CONFIG_UPDATED")
    watcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    watcher:SetScript("OnEvent", function(_, event, unit, _, spellId)
        if event == "TRAIT_CONFIG_UPDATED" then
            C_Timer.After(TALENT_REPARSE_DELAY, function()
                if InCombatLockdown() then return end
                Container:ReparseActiveDurations(plugin, frame)
                local record = plugin:GetContainerRecord(frame.recordId)
                if record then Container:Apply(plugin, frame, record) end
            end)
            return
        end
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            Container:OnEquipmentChanged(plugin, frame)
            return
        end
        if unit ~= "player" then return end
        for _, icon in pairs(frame.iconItems) do
            local isMatch = (icon.trackedType == "spell" and icon.trackedId == spellId) or (icon.trackedType == "item" and icon._useSpellId == spellId)
            if isMatch then
                if icon._activeDuration then
                    icon._activeGlowExpiry = GetTime() + icon._activeDuration
                    local expectedId = icon.trackedId
                    C_Timer.After(icon._activeDuration, function()
                        if icon.trackedId ~= expectedId then return end
                        local GC = OrbitEngine.GlowController
                        if GC:IsActive(icon, "orbitActive") then GC:Hide(icon, "orbitActive") end
                        icon._activeGlowExpiry = nil
                    end)
                end
                if icon._isChargeSpell then CooldownUtils:OnChargeCast(icon) end
            end
        end
    end)
    frame._castWatcher = watcher
end

-- [ ACTIVE DURATION REPARSE ] -------------------------------------------------
-- Re-reads tooltip durations after talent changes and rebuilds phase curves.
function Container:ReparseActiveDurations(plugin, frame)
    local record = plugin:GetContainerRecord(frame.recordId)
    if not record or not record.grid then return end
    local changed = false
    for key, data in pairs(record.grid) do
        if data.id then
            local parseId = (data.type == "spell") and GetActiveSpellID(data.id) or data.id
            local newActDur = ParseActiveDuration(data.type, parseId)
            local newCdDur = ParseCooldownDuration(data.type, parseId)
            if newActDur ~= data.activeDuration or newCdDur ~= data.cooldownDuration then
                data.activeDuration = newActDur
                data.cooldownDuration = newCdDur
                changed = true
            end
        end
    end
    if not changed then return end
    for key, icon in pairs(frame.iconItems) do
        local data = record.grid[key]
        if data then
            icon._activeDuration = data.activeDuration
            icon._cooldownDuration = data.cooldownDuration
            local hasActive = data.activeDuration and data.cooldownDuration
            icon._desatCurve = hasActive and BuildPhaseCurve(data.activeDuration, data.cooldownDuration) or nil
            icon._cdAlphaCurve = hasActive and BuildPhaseCurve(data.activeDuration, data.cooldownDuration) or nil
        end
    end
end

-- [ EQUIPMENT CHANGE HANDLER ] ------------------------------------------------
-- Updates item IDs in the grid when equipped trinkets change.
function Container:OnEquipmentChanged(plugin, frame)
    local record = plugin:GetContainerRecord(frame.recordId)
    if not record or not record.grid then return end
    local changed = false
    for key, data in pairs(record.grid) do
        if data.slotId then
            local newItemId = GetInventoryItemID("player", data.slotId)
            if newItemId and newItemId ~= data.id then
                data.id = newItemId
                data.useSpellId = select(2, GetItemSpell(newItemId)) or nil
                data.activeDuration = ParseActiveDuration("item", newItemId)
                data.cooldownDuration = ParseCooldownDuration("item", newItemId)
                changed = true
            elseif not newItemId then
                record.grid[key] = nil
                changed = true
            end
        end
    end
    if changed then Container:Apply(plugin, frame, record) end
end
