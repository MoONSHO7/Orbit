-- DatatextManager.lua
-- Central registry, position persistence, and update scheduler for Datatexts
local _, Orbit = ...
local DT = Orbit.Datatexts

-- [ CONSTANTS ] -------------------------------------------------------------------
local DATATEXT_CATEGORIES = {
    SYSTEM    = { order = 1, label = "System" },
    CHARACTER = { order = 2, label = "Character" },
    SOCIAL    = { order = 3, label = "Social" },
    GAMEPLAY  = { order = 4, label = "Gameplay" },
    WORLD     = { order = 5, label = "World" },
    UTILITY   = { order = 6, label = "Utility" },
}
DT.DATATEXT_CATEGORIES = DATATEXT_CATEGORIES

local UPDATE_INTERVALS = {
    FAST    = 0.5,
    NORMAL  = 1.0,
    SLOW    = 5.0,
    GLACIAL = 60.0,
}

local SYSTEM_ID = "Orbit_Datatexts"
local DEFAULT_TEXT_SIZE = 12

-- [ STATE ] -----------------------------------------------------------------------
local datatexts = {}
local datatextOrder = {}
local schedulerTickers = {}
local schedulerCallbacks = {}
local isLocked = true

-- [ DATATEXT MANAGER ] --------------------------------------------------------------
local DatatextManager = {}
DT.DatatextManager = DatatextManager

-- [ REGISTRATION ] ----------------------------------------------------------------
function DatatextManager:Register(id, datatextData)
    if datatexts[id] then return end
    datatexts[id] = {
        id = id,
        name = datatextData.name or id,
        frame = datatextData.frame,
        category = datatextData.category or "UTILITY",
        onEnable = datatextData.onEnable,
        onDisable = datatextData.onDisable,
        SetScale = datatextData.SetScale,
        isEnabled = false,
        isPlaced = false,
    }
    datatextOrder[#datatextOrder + 1] = id
end

function DatatextManager:GetDatatext(id) return datatexts[id] end
function DatatextManager:GetAllDatatexts() return datatexts end
function DatatextManager:GetDatatextCount() return #datatextOrder end
function DatatextManager:GetDatatextOrder() return datatextOrder end

-- [ LOCK / UNLOCK ] ---------------------------------------------------------------
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
        end
    end
end

-- [ PLACEMENT ] -------------------------------------------------------------------
function DatatextManager:PlaceDatatext(id, point, x, y, skipSave)
    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:PlaceDatatext(id, point, x, y, skipSave) end)
        return
    end
    local datatext = datatexts[id]
    if not datatext then return end
    datatext.isPlaced = true
    local f = datatext.frame
    f:ClearAllPoints()
    f:SetPoint(point or "CENTER", UIParent, point or "CENTER", x or 0, y or 0)
    f:SetFrameStrata(Orbit.Constants.Strata.HUD)
    f:SetFrameLevel(500)
    f:SetMovable(not isLocked)
    if f.resizeHandle then
        if isLocked then f.resizeHandle:Hide() else f.resizeHandle:Show() end
    end
    if f.overlay then
        if isLocked then f.overlay:Hide() else f.overlay:Show() end
    end
    f:Show()
    self:EnableDatatext(id)
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
    
    -- Disable the datatext, but re-enable it immediately if the drawer is open 
    -- so it continues running logic while residing visually inside the drawer.
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

-- [ ENABLE / DISABLE ] ------------------------------------------------------------
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

-- [ DRAG STOP ] -------------------------------------------------------------------
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

-- [ PERSISTENCE ] -----------------------------------------------------------------
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

-- [ ENABLE/DISABLE ALL DRAWER DATATEXTS ] -------------------------------------------
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

-- [ CATEGORIES ] ------------------------------------------------------------------
function DatatextManager:GetDatatextsByCategory()
    local categorized = {}
    for key, cat in pairs(DATATEXT_CATEGORIES) do categorized[key] = { label = cat.label, order = cat.order, datatexts = {} } end
    for _, id in ipairs(datatextOrder) do
        local datatext = datatexts[id]
        local catKey = datatext.category or "UTILITY"
        if categorized[catKey] then categorized[catKey].datatexts[#categorized[catKey].datatexts + 1] = datatext end
    end
    return categorized
end

-- [ UPDATE SCHEDULER ] ------------------------------------------------------------
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

-- [ TEARDOWN ] --------------------------------------------------------------------
function DatatextManager:DisableAll()
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

-- [ UPDATE ALL ] ------------------------------------------------------------------
function DatatextManager:UpdateAllDatatexts()
    local font = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    for _, datatext in pairs(datatexts) do
        if datatext.frame and datatext.frame.Text and font then
            Orbit.Skin:SkinText(datatext.frame.Text, { font = font, textSize = DEFAULT_TEXT_SIZE })
        end
    end
end
