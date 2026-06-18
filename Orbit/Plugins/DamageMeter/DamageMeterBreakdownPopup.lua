---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DM = Constants.DamageMeter
local BREAKDOWN = DM.BreakdownMode
local POPUP_GAP = DM.BreakdownPopupGap
local LEVEL_BUMP = DM.BreakdownPopupLevelBump
local CALLBACK_OWNER = "Orbit_DamageMeter_BreakdownPopups"

local Plugin = Orbit:GetPlugin(DM.SystemID)
if not Plugin then return end

-- [ REGISTRY ] --------------------------------------------------------------------------------------
-- mouseoverPopup is a non-interactive singleton that follows the hovered bar; detachedPopups holds at
-- most one draggable window per meter. Both are transient — nothing here writes to SavedVariables.
local mouseoverPopup
local detachedPopups = {}

-- [ SYNTHETIC DEF ] ---------------------------------------------------------------------------------
-- Styling the popup inherits verbatim from its parent meter so it renders identically to the in-place view.
local INHERITED_FIELDS = {
    "meterType", "sessionType", "sessionID",
    "barCount", "barWidth", "barHeight", "barGap",
    "iconPosition", "style", "border", "background", "title", "titleSize",
    "componentPositions", "disabledComponents",
}

local function ReinheritStyle(def, meterDef)
    for _, k in ipairs(INHERITED_FIELDS) do def[k] = meterDef[k] end
end

local function BuildSyntheticDef(meterDef, target)
    local def = { id = meterDef.id, viewMode = "breakdown", scrollOffset = 0 }
    ReinheritStyle(def, meterDef)
    def.breakdownGUID       = target.breakdownGUID
    def.breakdownCreatureID = target.breakdownCreatureID
    def.breakdownClass      = target.breakdownClass
    def.breakdownName       = target.breakdownName
    return def
end

-- Out-of-combat only (the caller gates on it), so sourceGUID/name are non-secret and safe to read here.
local function TargetFromSource(src, displayName)
    return {
        breakdownGUID       = src.sourceGUID,
        breakdownCreatureID = src.sourceCreatureID,
        breakdownClass      = src.classFilename,
        breakdownName       = displayName or src.name,
    }
end

-- Both popups show the full breakdown (no scroll) — override the inherited bar count with the source's
-- actual row count. `#combatSpells` is the array length, never a secret. Capped at the meter's own
-- MaxBarsStretch ceiling so a pathological source can't allocate a multi-thousand-pixel frame.
local function FitAllSpells(def)
    local sd = OrbitEngine.DamageMeterData:ResolveSessionSource(
        def.sessionID, def.sessionType, def.meterType,
        def.breakdownGUID, def.breakdownCreatureID
    )
    local n = sd and sd.combatSpells and #sd.combatSpells or 0
    if n > 0 then def.barCount = math.min(n, DM.MaxBarsStretch) end
end

-- [ PLACEMENT ] -------------------------------------------------------------------------------------
-- Anchor the popup beside the meter, flipping on whichever edges lack room: horizontally to the meter's
-- left, and vertically (top corner → grow up from the bottom corner) when a tall popup would run off-screen.
local function AnchorBeside(popup, meterFrame)
    popup:ClearAllPoints()
    local right, top = meterFrame:GetRight(), meterFrame:GetTop()
    local popupW, popupH = popup:GetWidth(), popup:GetHeight()
    local screenW = UIParent:GetWidth()
    local onLeft     = right and popupW and screenW and (right + POPUP_GAP + popupW) > screenW
    local fromBottom = top and popupH and (top - popupH) < 0
    local vert  = fromBottom and "BOTTOM" or "TOP"
    local xEdge = onLeft and "RIGHT" or "LEFT"
    local meterX = onLeft and "LEFT" or "RIGHT"
    local xOff  = onLeft and -POPUP_GAP or POPUP_GAP
    popup:SetPoint(vert .. xEdge, meterFrame, vert .. meterX, xOff, 0)
end

local function BarUnderCursor(frame)
    if not frame or not frame.bars then return nil end
    for _, bar in ipairs(frame.bars) do
        if bar:IsShown() and bar:IsMouseOver() then return bar end
    end
    return nil
end

local function ResolveDisplayName(src)
    local name = src.name
    if src.sourceGUID then
        local _, _, _, _, _, apiName = GetPlayerInfoByGUID(src.sourceGUID)
        if apiName and apiName ~= "" then name = apiName end
    end
    return name
end

local function DrawPopup(popup, def)
    Plugin:LayoutBreakdownFrame(popup, def)
    Plugin:RenderBreakdownFrame(popup, def)
end

-- [ MOUSEOVER ] -------------------------------------------------------------------------------------
local function EnsureMouseoverPopup()
    if mouseoverPopup then return mouseoverPopup end
    local p = Plugin:BuildBreakdownFrame()
    p:EnableMouse(false)
    p:SetClampedToScreen(true)
    p:Hide()
    mouseoverPopup = p
    return p
end

function Plugin:HideMouseoverBreakdown()
    if mouseoverPopup then
        mouseoverPopup:Hide()
        mouseoverPopup._key = nil
    end
end

function Plugin:TrackMouseoverBreakdown(meterId)
    local meterFrame = self:GetFrameBySystemIndex(meterId)
    local meterDef = self:GetMeterDef(meterId)
    if not meterFrame or not meterDef or InCombatLockdown()
       or meterDef.breakdownMode ~= BREAKDOWN.Mouseover
       or (meterDef.viewMode == "breakdown" or meterDef.viewMode == "history") then
        self:HideMouseoverBreakdown()
        return
    end

    local bar = BarUnderCursor(meterFrame)
    local src = bar and bar._source
    if not src or not (src.sourceGUID or src.sourceCreatureID) then
        self:HideMouseoverBreakdown()
        return
    end

    -- Re-render only when the hovered source changes, not on every throttle tick.
    local key = src.sourceGUID or src.sourceCreatureID
    local popup = EnsureMouseoverPopup()
    if popup:IsShown() and popup._key == key then return end
    popup._key = key

    local def = BuildSyntheticDef(meterDef, TargetFromSource(src, ResolveDisplayName(src)))
    FitAllSpells(def)
    popup._def = def
    popup._sourceMeter = meterId
    popup:SetFrameLevel(meterFrame:GetFrameLevel() + LEVEL_BUMP)
    DrawPopup(popup, def)
    AnchorBeside(popup, meterFrame)
    popup:Show()
end

-- [ DETACHED ] --------------------------------------------------------------------------------------
local function EnsureDetachedPopup(meterId)
    local p = detachedPopups[meterId]
    if p then return p end
    p = Plugin:BuildBreakdownFrame()
    p:EnableMouse(true)
    p:SetMouseClickEnabled(true)
    p:SetMovable(true)
    p:SetClampedToScreen(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    p:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then Plugin:CloseBreakdownPopups(meterId) end
    end)
    detachedPopups[meterId] = p
    return p
end

function Plugin:OpenDetachedBreakdown(meterId, src, displayName)
    if InCombatLockdown() then return end
    local meterFrame = self:GetFrameBySystemIndex(meterId)
    local meterDef = self:GetMeterDef(meterId)
    if not meterFrame or not meterDef then return end
    if not src or not (src.sourceGUID or src.sourceCreatureID) then return end

    local popup = EnsureDetachedPopup(meterId)
    popup._def = BuildSyntheticDef(meterDef, TargetFromSource(src, displayName or ResolveDisplayName(src)))
    FitAllSpells(popup._def)
    popup:SetFrameLevel(meterFrame:GetFrameLevel() + LEVEL_BUMP)
    DrawPopup(popup, popup._def)
    -- Anchor beside the meter on first open only; keep the user's position once they've dragged it.
    if not popup._placed then
        AnchorBeside(popup, meterFrame)
        popup._placed = true
    end
    popup:Show()
end

-- [ RENDER & LIFECYCLE ] ----------------------------------------------------------------------------
-- Called from RenderAllMeters so popups stay live with the data and re-inherit meter restyles each pass.
function Plugin:RenderBreakdownPopups()
    -- Breakdown source GUIDs go secret in combat; this ticker can fire in the window before
    -- PLAYER_REGEN_DISABLED hides popups, so guard here too rather than feed a secret GUID to the API.
    if InCombatLockdown() then
        self:HideAllBreakdownPopups()
        return
    end
    if mouseoverPopup and mouseoverPopup:IsShown() then
        local meterId = mouseoverPopup._sourceMeter
        local meterFrame = self:GetFrameBySystemIndex(meterId)
        local meterDef = self:GetMeterDef(meterId)
        if meterFrame and meterDef and mouseoverPopup._def then
            ReinheritStyle(mouseoverPopup._def, meterDef)
            -- Re-apply after ReinheritStyle (which resets barCount) so new spells grow the panel live.
            FitAllSpells(mouseoverPopup._def)
            DrawPopup(mouseoverPopup, mouseoverPopup._def)
            AnchorBeside(mouseoverPopup, meterFrame)
        else
            self:HideMouseoverBreakdown()
        end
    end
    for meterId, p in pairs(detachedPopups) do
        if p:IsShown() then
            local meterDef = self:GetMeterDef(meterId)
            if meterDef and p._def then
                ReinheritStyle(p._def, meterDef)
                -- Re-apply after ReinheritStyle (which resets barCount) so new spells grow the window live.
                FitAllSpells(p._def)
                DrawPopup(p, p._def)
            else
                p:Hide()
            end
        end
    end
end

function Plugin:CloseBreakdownPopups(meterId)
    local p = detachedPopups[meterId]
    if p then p:Hide() end
    if mouseoverPopup and mouseoverPopup._sourceMeter == meterId then
        self:HideMouseoverBreakdown()
    end
end

function Plugin:HideAllBreakdownPopups()
    self:HideMouseoverBreakdown()
    for _, p in pairs(detachedPopups) do p:Hide() end
end

-- Owning meter torn down (delete / rebuild): hide any popup that points at a now-dead meter.
function Plugin:PruneBreakdownPopups()
    local frames = self:GetMeterFrames()
    for meterId, p in pairs(detachedPopups) do
        if not frames[meterId] then p:Hide() end
    end
    if mouseoverPopup and mouseoverPopup:IsShown() and not frames[mouseoverPopup._sourceMeter] then
        self:HideMouseoverBreakdown()
    end
end

-- [ INIT ] ------------------------------------------------------------------------------------------
function Plugin:InitBreakdownPopups()
    -- Breakdown drill-in is invalid in combat (secret GUIDs) and meaningless over dummy preview data.
    Orbit.EventBus:On("PLAYER_REGEN_DISABLED", function() self:HideAllBreakdownPopups() end, CALLBACK_OWNER)
    Orbit.EventBus:On("ORBIT_PROFILE_CHANGED", function() self:HideAllBreakdownPopups() end, CALLBACK_OWNER)
    Orbit.Engine.EditMode:RegisterCallbacks({
        Enter = function() self:HideAllBreakdownPopups() end,
    }, CALLBACK_OWNER)
end
