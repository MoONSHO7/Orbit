local _, Orbit = ...
local L = Orbit.L
local DT = Orbit.Datatexts

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local UPDATE_INTERVALS = {
    FAST    = 0.5,
    NORMAL  = 1.0,
    SLOW    = 5.0,
    GLACIAL = 60.0,
}

local SYSTEM_ID = "Orbit_Datatexts"
local DEFAULT_TEXT_SIZE = 12

-- [ STATE ] -----------------------------------------------------------------------------------------
local datatexts = {}
local datatextOrder = {}
local schedulerTickers = {}
local schedulerCallbacks = {}
local isLocked = true

-- [ DATATEXT MANAGER ] ------------------------------------------------------------------------------
local DatatextManager = {}
DT.DatatextManager = DatatextManager

-- [ REGISTRATION ] ----------------------------------------------------------------------------------
function DatatextManager:Register(id, datatextData)
    if datatexts[id] then return end
    datatexts[id] = {
        id = id,
        name = datatextData.name or id,
        displayName = datatextData.displayName or datatextData.name or id,
        frame = datatextData.frame,
        category = datatextData.category or "UTILITY",
        onEnable = datatextData.onEnable,
        onDisable = datatextData.onDisable,
        SetScale = datatextData.SetScale,
        refit = datatextData.refit,
        isEnabled = false,
        isPlaced = false,
    }
    datatextOrder[#datatextOrder + 1] = id
end

function DatatextManager:GetDatatext(id) return datatexts[id] end
function DatatextManager:GetAllDatatexts() return datatexts end

-- [ LOCK / UNLOCK ] ---------------------------------------------------------------------------------
function DatatextManager:CanDrag() return not isLocked end

function DatatextManager:SetLocked(locked)
    isLocked = locked
    for _, datatext in pairs(datatexts) do
        if datatext.isPlaced and datatext.frame then
            datatext.frame:SetMovable(not locked)
            if datatext.frame.resizeHandle then
                if locked then datatext.frame.resizeHandle:Hide() else datatext.frame.resizeHandle:Show() end
            end
            if datatext.frame.overlay then
                if locked then datatext.frame.overlay:Hide() else datatext.frame.overlay:Show() end
            end
            self:SetActiveHighlight(datatext.frame, not locked)
        end
    end
end

-- Bright flat outline on placed datatexts while the drawer is open — shared Skin selection-outline primitive, identical to Canvas Mode selection.
function DatatextManager:SetActiveHighlight(frame, shown)
    if not frame then return end
    if shown then
        Orbit.Skin:ApplySelectionOutline(frame, "_dtActiveHighlight")
    else
        Orbit.Skin:ClearSelectionOutline(frame, "_dtActiveHighlight")
    end
end

-- [ GROWTH ANCHOR ] ---------------------------------------------------------------------------------
-- Edge-anchor a placed datatext by screen side so growing text expands toward centre, not symmetrically.
function DatatextManager:ApplyGrowthAnchor(frame)
    if not frame then return end
    local cx, cy = frame:GetCenter()
    if not cx then return end
    local s = frame:GetScale()
    local uipW = UIParent:GetWidth()
    local uipY = UIParent:GetHeight() / 2
    local w, h = frame:GetWidth(), frame:GetHeight()
    local es = frame:GetEffectiveScale()
    local offsetY = (cy * s - uipY) / s
    frame:ClearAllPoints()
    if cx * s < uipW / 2 then
        local px, py = Orbit.Engine.Pixel:SnapPosition(cx - w / 2, offsetY, "LEFT", w, h, es)
        frame:SetPoint("LEFT", UIParent, "LEFT", px, py)
    else
        local px, py = Orbit.Engine.Pixel:SnapPosition((cx + w / 2) - uipW / s, offsetY, "RIGHT", w, h, es)
        frame:SetPoint("RIGHT", UIParent, "RIGHT", px, py)
    end
end

-- [ PLACEMENT ] -------------------------------------------------------------------------------------
function DatatextManager:PlaceDatatext(id, point, x, y, skipSave)
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:PlaceDatatext(id, point, x, y, skipSave) end)
        return
    end
    local datatext = datatexts[id]
    if not datatext then return end
    datatext.isPlaced = true
    local f = datatext.frame
    local resolvedPoint = point or "CENTER"
    local px, py = Orbit.Engine.Pixel:SnapPosition(x or 0, y or 0, resolvedPoint, f:GetWidth(), f:GetHeight(), f:GetEffectiveScale())
    f:ClearAllPoints()
    f:SetPoint(resolvedPoint, UIParent, resolvedPoint, px, py)
    f:SetFrameStrata(Orbit.Constants.Strata.HUD)
    f:SetFrameLevel(500)
    f:SetMovable(not isLocked)
    if f.resizeHandle then
        if isLocked then f.resizeHandle:Hide() else f.resizeHandle:Show() end
    end
    if f.overlay then
        if isLocked then f.overlay:Hide() else f.overlay:Show() end
    end
    self:SetActiveHighlight(f, not isLocked)
    f:Show()
    if not self:ShouldShowPlaced(datatext) then f:Hide() end
    self:EnableDatatext(id)
    self:ApplyGrowthAnchor(f)
    if not skipSave then self:SavePositions() end
    
    if Orbit.OOCFadeMixin then
        local plugin = Orbit:GetPlugin("Datatexts")
        if plugin then
            Orbit.OOCFadeMixin:ApplyOOCFade(f, plugin, 1)
        end
    end
end

function DatatextManager:UnplaceDatatext(id, skipLayout)
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:UnplaceDatatext(id, skipLayout) end)
        return
    end
    local datatext = datatexts[id]
    if not datatext then return end
    datatext.isPlaced = false
    if datatext.frame then 
        datatext.frame:Hide()
        datatext.frame:SetMovable(false)
        if Orbit.OOCFadeMixin then
            Orbit.OOCFadeMixin:RemoveOOCFade(datatext.frame)
        end
    end
    
    -- Drawer keeps the datatext running its logic while visually demoted — re-enable immediately if open.
    self:DisableDatatext(id)
    if DT.DrawerUI and DT.DrawerUI:IsOpen() then
        self:EnableDatatext(id)
    end
    
    if not skipLayout then
        self:SavePositions()
        if DT.DrawerUI then
            DT.DrawerUI:LayoutDrawer()
        end
    end
end

function DatatextManager:ResetToDefaults()
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:ResetToDefaults() end)
        return
    end
    for id, datatext in pairs(datatexts) do
        if datatext.SetScale then datatext:SetScale(1.0) end
        self:UnplaceDatatext(id, true)
    end
    self:SavePositions()
    if DT.DrawerUI then
        DT.DrawerUI:LayoutDrawer()
    end
end

-- [ ENABLE / DISABLE ] ------------------------------------------------------------------------------
function DatatextManager:EnableDatatext(id)
    local datatext = datatexts[id]
    if not datatext or datatext.isEnabled then return end
    datatext.isEnabled = true
    if datatext.onEnable then datatext.onEnable() end
end

function DatatextManager:DisableDatatext(id)
    local datatext = datatexts[id]
    if not datatext or not datatext.isEnabled then return end
    datatext.isEnabled = false
    if datatext.onDisable then datatext.onDisable() end
end

-- [ DRAG STOP ] -------------------------------------------------------------------------------------
function DatatextManager:OnDatatextDragStop(datatextId)
    local drawerFrame = DT.DrawerUI and DT.DrawerUI:GetPanel()
    local wasHovering = false
    if drawerFrame and drawerFrame.dropGlow and drawerFrame.dropGlow:IsShown() then
        wasHovering = true
        drawerFrame.dropGlow:Hide()
    end
    local datatext = datatexts[datatextId]
    if not datatext then return false end
    if drawerFrame and drawerFrame:IsShown() and (wasHovering or self:IsCursorOverFrame(drawerFrame)) then
        self:UnplaceDatatext(datatextId)
        return true
    end
    datatext.isPlaced = true
    self:EnableDatatext(datatextId)
    if datatext.frame and datatext.frame.resizeHandle then datatext.frame.resizeHandle:Show() end
    if datatext.frame and datatext.frame.overlay then datatext.frame.overlay:Show() end
    if datatext.frame then self:SetActiveHighlight(datatext.frame, true) end
    self:ApplyGrowthAnchor(datatext.frame)
    self:SavePositions()
    return false
end

function DatatextManager:IsCursorOverFrame(frame)
    if not frame then return false end
    if frame.IsMouseOver and frame:IsMouseOver() then return true end
    
    local left, bottom, width, height = frame:GetRect()
    if not left then return false end
    local cx, cy = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    cx = cx / scale
    cy = cy / scale
    
    return cx >= left and cx <= left + width and cy >= bottom and cy <= bottom + height
end

-- [ PERSISTENCE ] -----------------------------------------------------------------------------------
function DatatextManager:GetPositionData()
    local plugin = Orbit:GetPlugin("Datatexts")
    if not plugin then return nil end
    return plugin:GetSetting(1, "datatextPositions")
end

function DatatextManager:SavePositions()
    local plugin = Orbit:GetPlugin("Datatexts")
    if not plugin then return end
    local positions = {}
    for id, datatext in pairs(datatexts) do
        if datatext.isPlaced and datatext.frame then
            local point, _, _, x, y = datatext.frame:GetPoint(1)
            positions[id] = { placed = true, point = point, x = x, y = y, scale = math.floor((datatext.frame:GetScale() * 100) + 0.5) / 100 }
        else
            positions[id] = { placed = false }
        end
    end
    plugin:SetSetting(1, "datatextPositions", positions)
end

function DatatextManager:RestorePositions()
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:RestorePositions() end)
        return
    end
    local positions = self:GetPositionData()
    if not positions then return end
    for id, data in pairs(positions) do
        local datatext = datatexts[id]
        if datatext and data.placed then
            datatext:SetScale(data.scale or 1.0)
            self:PlaceDatatext(id, data.point, data.x, data.y, true)
        end
    end
end

-- [ INSTANCE VISIBILITY ] ---------------------------------------------------------------------------
function DatatextManager:GetDatatextOption(id, key)
    local plugin = Orbit:GetPlugin("Datatexts")
    if not plugin then return nil end
    local opts = plugin:GetSetting(1, "datatextOptions")
    return opts and opts[id] and opts[id][key]
end

function DatatextManager:SetDatatextOption(id, key, value)
    local plugin = Orbit:GetPlugin("Datatexts")
    if not plugin then return end
    local existing = plugin:GetSetting(1, "datatextOptions")
    local opts = {}
    if existing then for k, v in pairs(existing) do opts[k] = v end end
    opts[id] = {}
    if existing and existing[id] then for k, v in pairs(existing[id]) do opts[id][k] = v end end
    opts[id][key] = value
    plugin:SetSetting(1, "datatextOptions", opts)
end

-- Placed datatexts stay visible while the drawer is open (to configure); an "only in instance" datatext is otherwise hidden outside instances.
function DatatextManager:ShouldShowPlaced(datatext)
    if not datatext or not datatext.isPlaced then return false end
    if DT.DrawerUI and DT.DrawerUI:IsOpen() then return true end
    if not self:GetDatatextOption(datatext.id, "onlyInInstance") then return true end
    return IsInInstance()
end

function DatatextManager:ApplyInstanceVisibility()
    local plugin = Orbit:GetPlugin("Datatexts")
    if plugin and plugin.suspended then return end
    for _, datatext in pairs(datatexts) do
        if datatext.isPlaced and datatext.frame then
            if self:ShouldShowPlaced(datatext) then datatext.frame:Show() else datatext.frame:Hide() end
        end
    end
end

-- Re-evaluate "only in instance" visibility on every world/instance transition; the plugin does not run ApplySettings on PLAYER_ENTERING_WORLD.
local instanceWatcher = CreateFrame("Frame")
instanceWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
instanceWatcher:SetScript("OnEvent", function() DatatextManager:ApplyInstanceVisibility() end)

-- [ ENABLE/DISABLE ALL DRAWER DATATEXTS ] -----------------------------------------------------------
function DatatextManager:EnableDrawerDatatexts()
    for _, datatext in pairs(datatexts) do
        if not datatext.isPlaced then self:EnableDatatext(datatext.id) end
    end
end

function DatatextManager:DisableDrawerDatatexts()
    for _, datatext in pairs(datatexts) do
        if not datatext.isPlaced then self:DisableDatatext(datatext.id) end
    end
end

-- [ UPDATE SCHEDULER ] ------------------------------------------------------------------------------
function DatatextManager:RegisterForScheduler(datatextId, tier, callback)
    if not UPDATE_INTERVALS[tier] then return end
    if not schedulerCallbacks[tier] then schedulerCallbacks[tier] = {} end
    schedulerCallbacks[tier][datatextId] = callback
    if not schedulerTickers[tier] then
        schedulerTickers[tier] = C_Timer.NewTicker(UPDATE_INTERVALS[tier], function()
            for _, cb in pairs(schedulerCallbacks[tier]) do cb() end
        end)
    end
end

function DatatextManager:UnregisterFromScheduler(datatextId, tier)
    if not schedulerCallbacks[tier] then return end
    schedulerCallbacks[tier][datatextId] = nil
    if not next(schedulerCallbacks[tier]) and schedulerTickers[tier] then
        schedulerTickers[tier]:Cancel()
        schedulerTickers[tier] = nil
    end
end

-- [ TEARDOWN ] --------------------------------------------------------------------------------------
function DatatextManager:DisableAll()
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:DisableAll() end)
        return
    end
    for _, datatext in pairs(datatexts) do
        self:DisableDatatext(datatext.id)
        if datatext.frame then datatext.frame:Hide() end
    end
    for tier, ticker in pairs(schedulerTickers) do
        ticker:Cancel()
        schedulerTickers[tier] = nil
    end
    schedulerCallbacks = {}
end

-- [ UPDATE ALL ] ------------------------------------------------------------------------------------
function DatatextManager:UpdateAllDatatexts()
    local font = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    for _, datatext in pairs(datatexts) do
        if datatext.frame and datatext.frame.Text and font then
            Orbit.Skin:SkinText(datatext.frame.Text, { font = font, textSize = DEFAULT_TEXT_SIZE })
            if datatext.refit then datatext.refit() end
        end
    end
end
