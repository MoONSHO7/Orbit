---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local LSM = LibStub("LibSharedMedia-3.0", true)

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DM = Constants.DamageMeter
local SYSTEM_INDEX = DM.SystemIndex
local SIGNAL = DM.Events
local FRAME_PREFIX = "OrbitDamageMeter"
local FRAME_LEVEL_STRIDE = 10
local FRAME_LEVEL_BASE = 10
local BAR_FONT_SIZE = 10
local ICON_PAD = 0
local TEXT_PAD_INNER = 4
local VIEW_TIMEOUT_SECONDS = 20
local NAME_AFTER_RANK_PAD = 22
local DPS_AFTER_TOTAL_PAD = 48
local BACKDROP_ALPHA = 0.4
local ICON_POS_LEFT, ICON_POS_OFF, ICON_POS_RIGHT = 1, 2, 3

local Plugin = Orbit:GetPlugin(DM.SystemID)
if not Plugin then return end

-- [ METER REGISTRY ] --------------------------------------------------------------------------------
local meters = {}

-- [ MEDIA ] -----------------------------------------------------------------------------------------
local function GetBarTexture()
    if not LSM then return "Interface\\TargetingFrame\\UI-StatusBar" end
    local name = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Texture
    return (name and LSM:Fetch("statusbar", name)) or "Interface\\TargetingFrame\\UI-StatusBar"
end

local function GetFont()
    if not LSM then return STANDARD_TEXT_FONT end
    local name = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    return (name and LSM:Fetch("font", name)) or STANDARD_TEXT_FONT
end

local function GetFontOutline()
    return (Orbit.Skin and Orbit.Skin:GetFontOutline()) or "OUTLINE"
end

local function GetBorderSize()
    return (Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BorderSize) or 2
end

local function GetClassColorRGBA(classFilename)
    if not classFilename or classFilename == "" then return 0.5, 0.5, 0.5, 1 end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename]
    if not c then return 0.5, 0.5, 0.5, 1 end
    return c.r, c.g, c.b, 1
end

local function IsPlayerClass(classFilename)
    if not classFilename or classFilename == "" then return false end
    return RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename] and true or false
end

-- Metrics whose sources ARE the enemies, not the players — NPC rows fall back to HOSTILE reaction color.
local HOSTILE_SOURCE_METRICS = {
    [DM.MeterType.DamageTaken]          = true,
    [DM.MeterType.AvoidableDamageTaken] = true,
    [DM.MeterType.EnemyDamageTaken]     = true,
}

local function ResolveNPCReaction(meterType)
    local RC = OrbitEngine.ReactionColor
    if not RC then return { r = 0.5, g = 0.5, b = 0.5, a = 1 } end
    if HOSTILE_SOURCE_METRICS[meterType] then
        return RC:GetOverride("HOSTILE")
    end
    return RC:GetOverride("FRIENDLY")
end

-- Gradient sample is flat (first pin) because totalAmount/maxAmount arithmetic is secret-in-combat.
local function ResolveBarColor(classFilename, meterType)
    local curve = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BarColorCurve
    local CCE = OrbitEngine.ColorCurve
    if not curve or not curve.pins or #curve.pins == 0 then
        if IsPlayerClass(classFilename) then
            local r, g, b, a = GetClassColorRGBA(classFilename)
            return r, g, b, a
        end
        local c = ResolveNPCReaction(meterType)
        return c.r, c.g, c.b, c.a or 1
    end
    if CCE:CurveHasClassPin(curve) then
        if IsPlayerClass(classFilename) then
            local c = OrbitEngine.ClassColor:GetOverrides(classFilename)
            return c.r, c.g, c.b, c.a or 1
        end
        local c = ResolveNPCReaction(meterType)
        return c.r, c.g, c.b, c.a or 1
    end
    local c = CCE:GetFirstColorFromCurve(curve)
    if c then return c.r, c.g, c.b, c.a or 1 end
    local r, g, b, a = GetClassColorRGBA(classFilename)
    return r, g, b, a
end

local function ApplyClassIcon(iconTexture, classFilename)
    if not classFilename or classFilename == "" then return false end
    iconTexture:SetAtlas(GetClassAtlas(classFilename))
    return true
end

-- [ CONTEXT MENU ] ----------------------------------------------------------------------------------
local METRIC_ENTRIES = {
    { value = DM.MeterType.DamageDone,            labelKey = "PLU_DM_METRIC_DAMAGE" },
    { value = DM.MeterType.HealingDone,           labelKey = "PLU_DM_METRIC_HEALING" },
    { value = DM.MeterType.DamageTaken,           labelKey = "PLU_DM_METRIC_DAMAGETAKEN" },
    { value = DM.MeterType.AvoidableDamageTaken,  labelKey = "PLU_DM_METRIC_AVOIDABLEDAMAGE" },
    { value = DM.MeterType.EnemyDamageTaken,      labelKey = "PLU_DM_METRIC_ENEMYDAMAGETAKEN" },
    { value = DM.MeterType.Interrupts,            labelKey = "PLU_DM_METRIC_INTERRUPTS" },
    { value = DM.MeterType.Dispels,               labelKey = "PLU_DM_METRIC_DISPELS" },
    { value = DM.MeterType.Deaths,                labelKey = "PLU_DM_METRIC_DEATHS" },
}

local function FormatDuration(seconds)
    if not seconds or seconds <= 0 then return "" end
    seconds = math.floor(seconds + 0.5)
    if seconds < 60 then return seconds .. "s" end
    return ("%dm %02ds"):format(math.floor(seconds / 60), seconds % 60)
end

local function ShowContextMenu(owner, id)
    local def = Plugin:GetMeterDef(id)
    if not def then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then return end

    local meterTag = (id == DM.MasterID) and L.PLU_DM_MASTER_LABEL or ("#" .. id)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        -- [ METRIC ] ----------------------------------------------------------
        root:CreateTitle(L.PLU_DM_METRIC .. "   |cff808080" .. meterTag .. "|r")
        for _, entry in ipairs(METRIC_ENTRIES) do
            local value = entry.value
            root:CreateCheckbox(
                L[entry.labelKey],
                function()
                    local d = Plugin:GetMeterDef(id)
                    return d and d.meterType == value
                end,
                function()
                    Plugin:UpdateMeterDef(id, {
                        meterType           = value,
                        viewMode            = "chart",
                        breakdownGUID       = Plugin.CLEAR,
                        breakdownCreatureID = Plugin.CLEAR,
                        breakdownClass      = Plugin.CLEAR,
                        breakdownName       = Plugin.CLEAR,
                        scrollOffset        = 0,
                    })
                    Plugin:RenderAllMeters()
                end
            )
        end

        -- [ RESET ] -----------------------------------------------------------
        root:CreateDivider()
        root:CreateButton(L.PLU_DM_MENU_RESET, function()
            OrbitEngine.DamageMeterData:ResetAllSessions()
        end)

        -- [ ACTIONS ] ---------------------------------------------------------
        root:CreateDivider()
        local count = Plugin:GetMeterCount()
        local atLimit = count >= DM.MaxMeters
        local newLabel = L.PLU_DM_MENU_NEW
        if atLimit then
            newLabel = newLabel .. (" (%d/%d)"):format(count, DM.MaxMeters)
        end
        local newButton = root:CreateButton(newLabel, function()
            local d = Plugin:GetMeterDef(id)
            Plugin:CreateMeter(d and d.meterType or DM.MeterType.Dps)
        end)
        if atLimit and newButton and newButton.SetEnabled then
            newButton:SetEnabled(false)
        end
        if not def.isMaster then
            root:CreateButton(L.PLU_DM_MENU_DELETE, function()
                Plugin:DeleteMeter(id)
            end)
        end
    end)
end

local function BarUnderCursor(frame)
    if not frame or not frame.bars then return nil end
    for _, bar in ipairs(frame.bars) do
        if bar:IsShown() and bar:IsMouseOver() then return bar end
    end
    return nil
end

local function BuildHistoryEntries()
    local entries = {
        { kind = "type", sessionType = DM.SessionType.Current, name = L.PLU_DM_SESSION_CURRENT, durationSeconds = nil },
        { kind = "type", sessionType = DM.SessionType.Overall, name = L.PLU_DM_SESSION_OVERALL, durationSeconds = nil },
    }
    if C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions then
        local sessions = {}
        for _, s in ipairs(C_DamageMeter.GetAvailableCombatSessions() or {}) do
            sessions[#sessions + 1] = s
        end
        table.sort(sessions, function(a, b) return (a.sessionID or 0) > (b.sessionID or 0) end)
        for _, s in ipairs(sessions) do
            entries[#entries + 1] = {
                kind            = "id",
                sessionID       = s.sessionID,
                name            = s.name or ("#" .. tostring(s.sessionID)),
                durationSeconds = s.durationSeconds,
            }
        end
    end
    return entries
end

local function IsHistoryEntrySelected(def, entry)
    if entry.kind == "type" then
        return def.sessionID == nil and def.sessionType == entry.sessionType
    end
    return def.sessionID == entry.sessionID
end

-- Encounter type inferred from Blizzard name prefix: "(!)" marks elite/boss pulls.
local HISTORY_ATLAS_CURRENT  = "questlog-questtypeicon-clockorange"
local HISTORY_ATLAS_OVERALL  = "questlog-questtypeicon-quest"
local HISTORY_ATLAS_ELITE    = "nameplates-icon-elite-gold"
local HISTORY_ATLAS_NORMAL   = "worldquest-icon-boss"

local function PickHistoryAtlas(entry)
    if entry.kind == "type" then
        if entry.sessionType == DM.SessionType.Current then return HISTORY_ATLAS_CURRENT end
        if entry.sessionType == DM.SessionType.Overall then return HISTORY_ATLAS_OVERALL end
    end
    local name = entry.name or ""
    if name:sub(1, 3) == "(!)" then return HISTORY_ATLAS_ELITE end
    return HISTORY_ATLAS_NORMAL
end

local function PaintHistoryBar(bar, rank, entry, maxDuration, isSelected, playerClass)
    bar._source = nil
    bar._historyEntry = entry
    bar.Icon:SetTexture(nil)
    bar.Icon:SetTexCoord(0, 1, 0, 1)
    bar.Icon:SetAtlas(PickHistoryAtlas(entry))
    local denom = (maxDuration and maxDuration > 0) and maxDuration or 1
    bar.StatusBar:SetMinMaxValues(0, denom)
    bar.StatusBar:SetValue(entry.durationSeconds or denom)
    local r, g, b, a
    if isSelected then
        r, g, b, a = ResolveBarColor(playerClass or "")
    else
        r, g, b, a = 0.3, 0.3, 0.3, 1
    end
    local tex = bar.StatusBar:GetStatusBarTexture()
    if tex and tex.SetVertexColor then tex:SetVertexColor(r, g, b, a) end
    bar.Rank:SetFormattedText("%d.", rank)
    bar.Name:SetText(entry.name or "?")
    bar.DPS:SetText("")
    bar.DamageDone:SetText(FormatDuration(entry.durationSeconds))
    bar:Show()
end

-- [ BAR CONSTRUCTION ] ------------------------------------------------------------------------------
local function CreateBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:EnableMouse(false) -- clicks/drag are handled by the outer meter frame

    bar.Icon = bar:CreateTexture(nil, "ARTWORK")
    bar.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- No SetClipsChildren: nine-slice border overlay uses an outset that would be cropped.
    bar.StatusBar = CreateFrame("StatusBar", nil, bar)
    bar.StatusBar:SetStatusBarTexture(GetBarTexture())
    bar.StatusBar:SetMinMaxValues(0, 1)
    bar.StatusBar:SetValue(0)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar.StatusBar)
    bar.bg:SetColorTexture(0, 0, 0, 0.4)

    -- TextFrame spans the full row (not the Style-shrunk StatusBar) so canvas drag coords stay stable.
    bar.TextFrame = CreateFrame("Frame", nil, bar)
    bar.TextFrame:SetFrameLevel(bar.StatusBar:GetFrameLevel() + Constants.Levels.Overlay)

    bar.Rank = bar.TextFrame:CreateFontString(nil, "OVERLAY")
    bar.Rank:SetFont(GetFont(), BAR_FONT_SIZE, GetFontOutline())
    bar.Rank:SetJustifyH("LEFT")
    bar.Rank:SetTextColor(1, 1, 1)

    bar.Name = bar.TextFrame:CreateFontString(nil, "OVERLAY")
    bar.Name:SetFont(GetFont(), BAR_FONT_SIZE, GetFontOutline())
    bar.Name:SetJustifyH("LEFT")
    bar.Name:SetTextColor(1, 1, 1)

    bar.DPS = bar.TextFrame:CreateFontString(nil, "OVERLAY")
    bar.DPS:SetFont(GetFont(), BAR_FONT_SIZE, GetFontOutline())
    bar.DPS:SetJustifyH("RIGHT")
    bar.DPS:SetTextColor(1, 1, 1)

    bar.DamageDone = bar.TextFrame:CreateFontString(nil, "OVERLAY")
    bar.DamageDone:SetFont(GetFont(), BAR_FONT_SIZE, GetFontOutline())
    bar.DamageDone:SetJustifyH("RIGHT")
    bar.DamageDone:SetTextColor(1, 1, 1)
    return bar
end

-- Prefer live width when an anchor parent has SetWidth-synced us, to avoid clobbering the sync.
local function GetEffectiveWidth(frame, def)
    local FA = Orbit.Engine and Orbit.Engine.FrameAnchor
    local parent = FA and FA.GetAnchorParent and FA:GetAnchorParent(frame)
    if parent then
        local w = frame:GetWidth()
        if w and w > 1 then return w end
    end
    return def.barWidth
end

local function FrameHeightFor(def, count)
    if count <= 0 then return 0 end
    local gap = def.barGap or 0
    return count * def.barHeight + (count - 1) * gap
end

local function DefaultRankPos()
    return { anchorX = "LEFT",  offsetX = TEXT_PAD_INNER,                                anchorY = "CENTER", offsetY = 0, justifyH = "LEFT"  }
end

local function DefaultNamePos()
    return { anchorX = "LEFT",  offsetX = TEXT_PAD_INNER + NAME_AFTER_RANK_PAD,          anchorY = "CENTER", offsetY = 0, justifyH = "LEFT"  }
end

local function DefaultDamageDonePos()
    return { anchorX = "RIGHT", offsetX = TEXT_PAD_INNER,                                anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" }
end

local function DefaultDPSPos()
    return { anchorX = "RIGHT", offsetX = TEXT_PAD_INNER + DPS_AFTER_TOTAL_PAD,          anchorY = "CENTER", offsetY = 0, justifyH = "RIGHT" }
end

local TEXT_COMPONENT_KEYS = { "Rank", "Name", "DPS", "DamageDone" }

-- Canvas transactions are singleton; only read when target matches or other meters leak staged state.
local function GetCanvasStateForMeter(def, meterId)
    local positions = def.componentPositions or {}
    local disabledList = def.disabledComponents
    local txn = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.Transaction
    if txn and txn.IsActive and txn:IsActive()
       and txn.GetSystemIndex and txn:GetSystemIndex() == meterId then
        if txn.GetPositions then positions = txn:GetPositions() or positions end
        if txn.GetDisabledComponents then disabledList = txn:GetDisabledComponents() or disabledList end
    end
    return positions, disabledList
end

-- Supports both array form (canvas writes) and map form (manual edits / older saves).
local function BuildDisabledHash(list)
    local hash = {}
    if type(list) ~= "table" then return hash end
    for _, v in ipairs(list) do hash[v] = true end
    for k, v in pairs(list) do
        if type(k) == "string" and v then hash[k] = true end
    end
    return hash
end

local function ApplyCanvasState(bar, positions, disabledList)
    local disabled = BuildDisabledHash(disabledList)
    local fontPath = GetFont()
    for _, key in ipairs(TEXT_COMPONENT_KEYS) do
        local fs = bar[key]
        if fs then
            if disabled[key] then
                fs:Hide()
            else
                fs:Show()
                local overrides = positions[key] and positions[key].overrides or {}
                OrbitEngine.OverrideUtils.ApplyOverrides(fs, overrides, { fontSize = BAR_FONT_SIZE, fontPath = fontPath })
            end
        end
    end
end

local function LayoutBarInternals(bar, def)
    local iconSide = def.iconPosition or ICON_POS_LEFT
    local showIcon = iconSide ~= ICON_POS_OFF
    local iconSize = showIcon and def.barHeight or 0

    bar.Icon:ClearAllPoints()
    if showIcon then
        bar.Icon:SetSize(iconSize, iconSize)
        if iconSide == ICON_POS_RIGHT then
            bar.Icon:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
        else
            bar.Icon:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        end
        bar.Icon:Show()
    else
        bar.Icon:Hide()
    end

    local stylePct = def.style
    if stylePct == nil then stylePct = 100 end
    local fillHeight = def.barHeight * stylePct / 100
    bar.StatusBar:ClearAllPoints()
    if iconSide == ICON_POS_RIGHT then
        bar.StatusBar:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT",   0,         0)
        bar.StatusBar:SetPoint("TOPRIGHT",   bar, "BOTTOMRIGHT", -iconSize,  fillHeight)
    else
        bar.StatusBar:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT",   iconSize,  0)
        bar.StatusBar:SetPoint("TOPRIGHT",   bar, "BOTTOMRIGHT",  0,         fillHeight)
    end

    bar.TextFrame:ClearAllPoints()
    if iconSide == ICON_POS_RIGHT then
        bar.TextFrame:SetPoint("TOPLEFT",     bar, "TOPLEFT",      0,         0)
        bar.TextFrame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -iconSize,  0)
    else
        bar.TextFrame:SetPoint("TOPLEFT",     bar, "TOPLEFT",      iconSize,  0)
        bar.TextFrame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT",  0,         0)
    end

    if bar.StatusBar.SetReverseFill then bar.StatusBar:SetReverseFill(false) end

    local positions, disabledList = GetCanvasStateForMeter(def, def.id)

    -- Overrides before positions: ApplyOverrides may change font size which affects measured text.
    ApplyCanvasState(bar, positions, disabledList)

    local ApplyTextPosition = OrbitEngine.PositionUtils.ApplyTextPosition
    ApplyTextPosition(bar.Rank,       bar.TextFrame, positions.Rank       or DefaultRankPos())
    ApplyTextPosition(bar.Name,       bar.TextFrame, positions.Name       or DefaultNamePos())
    ApplyTextPosition(bar.DPS,        bar.TextFrame, positions.DPS        or DefaultDPSPos())
    ApplyTextPosition(bar.DamageDone, bar.TextFrame, positions.DamageDone or DefaultDamageDonePos())
end

local function AttachCanvasComponents(frame)
    if frame._canvasComponentsAttached then return end
    if not OrbitEngine.ComponentDrag then return end
    local bar = frame.bars[1]
    if not bar or not bar.Rank or not bar.Name or not bar.DPS or not bar.DamageDone then return end
    frame.Rank       = bar.Rank
    frame.Name       = bar.Name
    frame.DPS        = bar.DPS
    frame.DamageDone = bar.DamageDone
    local id = frame._id
    OrbitEngine.ComponentDrag:Attach(frame.Rank, frame, {
        key = "Rank",
        onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(Plugin, id, "Rank"),
    })
    OrbitEngine.ComponentDrag:Attach(frame.Name, frame, {
        key = "Name",
        onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(Plugin, id, "Name"),
    })
    OrbitEngine.ComponentDrag:Attach(frame.DPS, frame, {
        key = "DPS",
        onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(Plugin, id, "DPS"),
    })
    OrbitEngine.ComponentDrag:Attach(frame.DamageDone, frame, {
        key = "DamageDone",
        onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(Plugin, id, "DamageDone"),
    })
    frame._canvasComponentsAttached = true
end

local BORDER_NONE    = 1
local BORDER_PER_BAR = 2
local BORDER_FRAME   = 3
local BG_NONE        = 1
local BG_PER_BAR     = 2
local BG_FRAME       = 3
local TITLE_OFF          = 1
local TITLE_TOP_LEFT     = 2
local TITLE_TOP_RIGHT    = 3
local TITLE_BOTTOM_LEFT  = 4
local TITLE_BOTTOM_RIGHT = 5
local TITLE_GAP = 2
local STRETCH_TAB_ATLAS_LEFT   = "glues-characterSelect-TopHUD-selected-left"
local STRETCH_TAB_ATLAS_RIGHT  = "glues-characterSelect-TopHUD-selected-right"
local STRETCH_TAB_WIDTH        = 60
local STRETCH_TAB_HEIGHT       = 12
local STRETCH_TAB_INSET        = 0
local STRETCH_TAB_IDLE_ALPHA   = 0
local STRETCH_TAB_HOVER_ALPHA  = 1
local STRETCH_MAX_BARS         = 40

-- Forward-declared: stretch-tab OnUpdate closure captures this upvalue before RenderFrame is defined.
local RenderFrame
local METER_TYPE_LABEL_KEY = {
    [DM.MeterType.DamageDone]            = "PLU_DM_METRIC_DAMAGE",
    [DM.MeterType.Dps]                   = "PLU_DM_METRIC_DAMAGE",
    [DM.MeterType.HealingDone]           = "PLU_DM_METRIC_HEALING",
    [DM.MeterType.Hps]                   = "PLU_DM_METRIC_HEALING",
    [DM.MeterType.DamageTaken]           = "PLU_DM_METRIC_DAMAGETAKEN",
    [DM.MeterType.AvoidableDamageTaken]  = "PLU_DM_METRIC_AVOIDABLEDAMAGE",
    [DM.MeterType.EnemyDamageTaken]      = "PLU_DM_METRIC_ENEMYDAMAGETAKEN",
    [DM.MeterType.Interrupts]            = "PLU_DM_METRIC_INTERRUPTS",
    [DM.MeterType.Dispels]               = "PLU_DM_METRIC_DISPELS",
    [DM.MeterType.Deaths]                = "PLU_DM_METRIC_DEATHS",
}

-- sessionName is captured drop-time with issecretvalue guard; type-based labels are localized constants.
local function ResolveSessionLabel(def)
    if def.sessionID then
        if def.sessionName and def.sessionName ~= "" then return def.sessionName end
        return "#" .. tostring(def.sessionID)
    end
    if def.sessionType == DM.SessionType.Overall then return L.PLU_DM_SESSION_OVERALL end
    return L.PLU_DM_SESSION_CURRENT
end

local function BuildTitleText(def)
    if not def then return "" end
    local labelKey = METER_TYPE_LABEL_KEY[def.meterType] or "PLU_DM_METRIC_DAMAGE"
    local metricLabel = L[labelKey] or ""
    if def.viewMode == "breakdown" then
        local name
        -- Skip API call on secret GUID: returned name would be secret and concat/equality would throw.
        local guidOk = def.breakdownGUID and (not issecretvalue or not issecretvalue(def.breakdownGUID))
        if guidOk and GetPlayerInfoByGUID then
            local _, _, _, _, _, apiName = GetPlayerInfoByGUID(def.breakdownGUID)
            if apiName and apiName ~= "" then name = apiName end
        end
        if not name or name == "" then name = def.breakdownName end
        if name and name ~= "" then
            return metricLabel .. ": " .. name
        end
        return metricLabel
    end
    return metricLabel .. ": " .. ResolveSessionLabel(def)
end

local function RefreshTitle(frame, def)
    local title = frame._title
    if not title then return end
    local mode = def.title or TITLE_OFF
    local rect = frame._visibleRect
    if mode == TITLE_OFF or not rect or not rect:IsShown() then
        title:Hide()
        return
    end
    title:SetText(BuildTitleText(def))
    title:SetWordWrap(false)
    title:SetNonSpaceWrap(false)
    -- Cap width to the visible rect so overflowing titles render as "Damage: Curren..." instead of spilling past the frame.
    local rectWidth = rect:GetWidth()
    if rectWidth and rectWidth > 0 then title:SetWidth(rectWidth) end
    title:ClearAllPoints()
    if mode == TITLE_TOP_LEFT then
        title:SetPoint("BOTTOMLEFT",  rect, "TOPLEFT",    0,  TITLE_GAP)
        title:SetJustifyH("LEFT")
    elseif mode == TITLE_TOP_RIGHT then
        title:SetPoint("BOTTOMRIGHT", rect, "TOPRIGHT",   0,  TITLE_GAP)
        title:SetJustifyH("RIGHT")
    elseif mode == TITLE_BOTTOM_LEFT then
        title:SetPoint("TOPLEFT",     rect, "BOTTOMLEFT", 0, -TITLE_GAP)
        title:SetJustifyH("LEFT")
    else -- TITLE_BOTTOM_RIGHT
        title:SetPoint("TOPRIGHT",    rect, "BOTTOMRIGHT",0, -TITLE_GAP)
        title:SetJustifyH("RIGHT")
    end
    title:Show()
end

local function GetStretchTabSize()
    return STRETCH_TAB_WIDTH, STRETCH_TAB_HEIGHT
end

-- Flip within atlas region UVs (plain SetTexCoord after SetAtlas would expose the whole sheet).
local function ApplyStretchAtlas(tex, atlasName, flipV)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlasName)
    if not info or not info.file then
        tex:SetAtlas(atlasName)
        return
    end
    tex:SetTexture(info.file)
    local left   = info.leftTexCoord   or 0
    local right  = info.rightTexCoord  or 1
    local top    = info.topTexCoord    or 0
    local bottom = info.bottomTexCoord or 1
    if flipV then
        top, bottom = bottom, top
    end
    tex:SetTexCoord(left, right, top, bottom)
end

local function RefreshStretchTab(frame, def)
    local tab = frame._stretchTab
    if not tab then return end
    -- Freeze position mid-drag: SetClampedToScreen can flip isOnTop and invert stretchPx.
    if tab._dragging then return end
    -- Hide in Edit Mode so the selection overlay receives clicks (alpha 0 still captures mouse).
    if Orbit and Orbit.IsEditMode and Orbit:IsEditMode() then
        tab:Hide()
        return
    end
    tab:Show()

    local topY = frame:GetTop()
    local screenH = GetScreenHeight() or 800
    local isOnTop = topY and (topY <= screenH / 2) or false

    local titleMode = def.title or TITLE_OFF
    local titleOnRight = (titleMode == TITLE_TOP_RIGHT or titleMode == TITLE_BOTTOM_RIGHT)
    local tabOnLeft = titleOnRight

    tab._isOnTop = isOnTop
    tab:ClearAllPoints()
    local outerEdge = isOnTop and "TOP" or "BOTTOM"
    local innerEdge = isOnTop and "BOTTOM" or "TOP"
    local side = tabOnLeft and "LEFT" or "RIGHT"
    local xInset = tabOnLeft and STRETCH_TAB_INSET or -STRETCH_TAB_INSET
    tab:SetPoint(innerEdge .. side, frame, outerEdge .. side, xInset, 0)

    -- Atlas names reflect pointing direction not position: `-right` art visually fits LEFT corner.
    tab.texLeft:SetShown(not tabOnLeft)
    tab.texRight:SetShown(tabOnLeft)
    ApplyStretchAtlas(tab.texLeft,  STRETCH_TAB_ATLAS_LEFT,  not isOnTop)
    ApplyStretchAtlas(tab.texRight, STRETCH_TAB_ATLAS_RIGHT, not isOnTop)
end

local function GetAvailableRowCount(def)
    if not def then return 0 end
    local Data = OrbitEngine.DamageMeterData
    if def.viewMode == "breakdown" and (def.breakdownGUID or def.breakdownCreatureID) then
        local sd = Data and Data:ResolveSessionSource(
            def.sessionID, def.sessionType, def.meterType,
            def.breakdownGUID, def.breakdownCreatureID
        )
        return (sd and sd.combatSpells and #sd.combatSpells) or 0
    end
    if def.viewMode == "history" then
        local entries = BuildHistoryEntries()
        return #entries
    end
    if Data and Data:IsAvailable() then
        local session = Data:ResolveSession(def.sessionID, def.sessionType, def.meterType)
        if session and session.combatSources then return #session.combatSources end
    end
    return 0
end

-- SkinBorder(f, f, 0) leaks into _edgeBorderOverlay for nine-slice — hide both overlays explicitly.
local function HideBorder(frame)
    if not frame then return end
    if frame._borderFrame       then frame._borderFrame:Hide()       end
    if frame._edgeBorderOverlay then frame._edgeBorderOverlay:Hide() end
end

local function UpdateVisibleRect(frame, def, visibleCount)
    local rect = frame._visibleRect
    if not rect then return end
    if not visibleCount or visibleCount <= 0 then
        rect:Hide()
        return
    end
    local gap = def.barGap or 0
    local rectHeight = visibleCount * def.barHeight + math.max(0, visibleCount - 1) * gap
    rect:ClearAllPoints()
    rect:SetPoint("TOPLEFT",     frame, "TOPLEFT",   0,  0)
    rect:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT",  0, -rectHeight)
    rect:Show()
end

local function RefreshBorders(frame, def)
    local mode = def.border or BORDER_FRAME
    local borderSize = GetBorderSize()

    HideBorder(frame)
    if mode == BORDER_FRAME then
        Orbit.Skin:SkinBorder(frame._visibleRect, frame._visibleRect, borderSize)
    else
        HideBorder(frame._visibleRect)
    end

    for _, bar in ipairs(frame.bars or {}) do
        HideBorder(bar)
        if mode == BORDER_PER_BAR then
            Orbit.Skin:SkinBorder(bar.StatusBar, bar.StatusBar, borderSize)
        else
            HideBorder(bar.StatusBar)
        end
    end
end

local function RefreshBackgrounds(frame, def)
    local mode = def.background or BG_PER_BAR
    if frame._backdrop then
        frame._backdrop:SetShown(mode == BG_FRAME)
    end
    for _, bar in ipairs(frame.bars or {}) do
        if bar.bg then
            bar.bg:SetShown(mode == BG_PER_BAR)
        end
    end
end

local function LayoutBars(frame, def)
    frame.bars = frame.bars or {}
    local count = def.barCount
    local width = GetEffectiveWidth(frame, def)
    local height = def.barHeight
    local gap = def.barGap or 1
    local stride = height + gap
    for i = 1, count do
        local bar = frame.bars[i] or CreateBar(frame)
        frame.bars[i] = bar
        bar:SetSize(width, height)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -((i - 1) * stride))
        bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -((i - 1) * stride))
        -- Do NOT reset font here: ApplyCanvasState owns font via overrides, reset would wipe them.
        bar.StatusBar:SetStatusBarTexture(GetBarTexture())
        LayoutBarInternals(bar, def)
        bar:Show()
    end
    for i = count + 1, #frame.bars do frame.bars[i]:Hide() end

    frame:SetSize(width, FrameHeightFor(def, count))
    RefreshBorders(frame, def)
    RefreshBackgrounds(frame, def)
    if frame._title then
        frame._title:SetFont(GetFont(), def.titleSize or 12, GetFontOutline())
    end
    AttachCanvasComponents(frame)
end

-- [ FRAME FACTORY ] ---------------------------------------------------------------------------------
local SHORT_BREAKPOINTS = {
    { breakpoint = 1000000000, abbreviation = "B", significandDivisor = 100000000, fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 1000000,    abbreviation = "M", significandDivisor = 100000,    fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 1000,       abbreviation = "K", significandDivisor = 100,       fractionDivisor = 10, abbreviationIsGlobal = false },
}
local SHORT_OPTIONS = { breakpointData = SHORT_BREAKPOINTS }

-- Declared above BuildMeterFrame: CreateCanvasPreview closure captures this upvalue at parse time.
local function WriteNumberField(fs, value, overrides)
    if not value then fs:SetText(""); return end
    local format = overrides and overrides.Format
    if format == "Full" then
        fs:SetFormattedText("%s", BreakUpLargeNumbers(value))
    else
        fs:SetFormattedText("%s", AbbreviateNumbers(value, SHORT_OPTIONS))
    end
end

local MASTER_FRAME_LEVEL = 500

local function BuildMeterFrame(id, def)
    local frame = CreateFrame("Frame", FRAME_PREFIX .. id, UIParent)
    frame:SetFrameStrata("MEDIUM")
    if def.isMaster then
        frame:SetFrameLevel(MASTER_FRAME_LEVEL)
    else
        frame:SetFrameLevel(FRAME_LEVEL_BASE + math.max(0, id) * FRAME_LEVEL_STRIDE)
    end
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetMouseClickEnabled(true)
    frame:RegisterForDrag("LeftButton")

    -- [ EDIT MODE SELECTION PROTOCOL ] ----------------------------------------
    frame.systemIndex = id
    frame.recordId = id
    local meterTag = (id == DM.MasterID) and L.PLU_DM_MASTER_LABEL or ("#" .. id)
    frame.editModeName = "Damage Meter " .. meterTag
    frame.orbitPlugin = Plugin
    -- Any-edge anchoring: DM stack can snap T/B (width propagates via orbitWidthSync) or L/R
    -- (plain anchor, no cross-axis sync). Height is intentionally NOT synced — DM's height
    -- derives from barCount × barHeight + gaps and must not be overwritten by a parent.
    frame.anchorOptions = {
        horizontal   = true,
        vertical     = true,
        mergeBorders = true,
    }
    frame.orbitWidthSync = true
    -- Master barCount is pinned to 1, so vertical drag writes BarHeight instead of TotalHeight.
    if def.isMaster then
        frame.orbitResizeBounds = {
            minW = 100, maxW = 600,
            minH = 14, maxH = 60,
            widthKey = "BarWidth",
            heightKey = "BarHeight",
        }
    else
        frame.orbitResizeBounds = {
            minW = 100, maxW = 600,
            minH = 18, maxH = 18 * 40,
            widthKey = "BarWidth",
            heightKey = "TotalHeight",
        }
    end

    OrbitEngine.Frame:AttachSettingsListener(frame, Plugin, id)

    frame.Selection = frame:CreateTexture(nil, "OVERLAY")
    frame.Selection:SetColorTexture(1, 1, 1, 0.1)
    frame.Selection:SetAllPoints()
    frame.Selection:Hide()

    -- Drag handlers are no-ops but RegisterForDrag consumes the events so they don't leak to OnMouseUp.
    frame:SetScript("OnDragStart", function() end)
    frame:SetScript("OnDragStop", function() end)
    frame:SetScript("OnMouseUp", function(self, button)
        self._lastInteraction = GetTime()
        local def2 = Plugin:GetMeterDef(id)
        if not def2 then return end

        if button == "LeftButton" then
            local bar = BarUnderCursor(self)
            if not bar then return end
            -- Plugin.CLEAR erases def.sessionID explicitly: nil in a patch table is invisible to pairs().
            if def2.viewMode == "history" and bar._historyEntry then
                local entry = bar._historyEntry
                -- Drop-time capture: session names from C_DamageMeter can be secret in combat; skip if so.
                local capturedName
                if entry.kind == "id" and entry.name
                   and (not issecretvalue or not issecretvalue(entry.name)) then
                    capturedName = entry.name
                end
                Plugin:UpdateMeterDef(id, {
                    sessionType  = entry.sessionType or DM.SessionType.Current,
                    sessionID    = entry.sessionID or Plugin.CLEAR,
                    sessionName  = capturedName or Plugin.CLEAR,
                    viewMode     = "chart",
                    scrollOffset = 0,
                })
                Plugin:RenderAllMeters()
                return
            end
            -- Refuse drill-in during combat: sourceGUID is ConditionalSecret and secrets never un-secret.
            if def2.viewMode ~= "chart" then return end
            if not bar._source then return end
            if InCombatLockdown() then return end
            local src = bar._source
            if IsShiftKeyDown() and src.sourceGUID and src.classFilename
               and src.classFilename ~= "" and Plugin.OpenSpecComparison then
                Plugin:OpenSpecComparison(id, src)
                return
            end
            if src.sourceGUID or src.sourceCreatureID then
                local displayName = src.name
                if src.sourceGUID and GetPlayerInfoByGUID then
                    local _, _, _, _, _, apiName = GetPlayerInfoByGUID(src.sourceGUID)
                    if apiName and apiName ~= "" then displayName = apiName end
                end
                Plugin:EnterBreakdown(id, src.sourceGUID, src.sourceCreatureID, src.classFilename, displayName)
            end
            return
        end

        if button == "RightButton" then
            if IsShiftKeyDown() then
                ShowContextMenu(self, id)
                return
            end
            if def2.viewMode == "chart" then
                Plugin:EnterHistory(id)
            else
                Plugin:ReturnToChart(id)
            end
        end
    end)
    frame:SetScript("OnMouseWheel", function(self, delta)
        self._lastInteraction = GetTime()
        local def2 = Plugin:GetMeterDef(id)
        if not def2 then return end
        local Data = OrbitEngine.DamageMeterData
        local totalRows = 0
        if def2.viewMode == "history" then
            totalRows = #BuildHistoryEntries()
        elseif def2.viewMode == "breakdown" and (def2.breakdownGUID or def2.breakdownCreatureID) then
            local sd = Data and Data:ResolveSessionSource(
                def2.sessionID, def2.sessionType, def2.meterType,
                def2.breakdownGUID, def2.breakdownCreatureID
            )
            if sd and sd.combatSpells then totalRows = #sd.combatSpells end
        elseif Data and Data:IsAvailable() then
            local session = Data:ResolveSession(def2.sessionID, def2.sessionType, def2.meterType)
            if session and session.combatSources then totalRows = #session.combatSources end
        end
        local maxOffset = math.max(0, totalRows - def2.barCount)
        local offset = (def2.scrollOffset or 0) - delta
        if offset < 0 then offset = 0 end
        if offset > maxOffset then offset = maxOffset end
        if offset == (def2.scrollOffset or 0) then return end
        Plugin:UpdateMeterDef(id, { scrollOffset = offset })
        Plugin:RenderAllMeters()
    end)

    -- Elastic rect that wraps only visible bars: Frame-mode border/backdrop skin this, not the outer frame.
    frame._visibleRect = CreateFrame("Frame", nil, frame)

    frame._backdrop = frame._visibleRect:CreateTexture(nil, "BACKGROUND")
    frame._backdrop:SetAllPoints(frame._visibleRect)
    frame._backdrop:SetColorTexture(0, 0, 0, BACKDROP_ALPHA)

    -- Parented to outer frame so it can render outside _visibleRect bounds; anchors track the rect.
    frame._title = frame:CreateFontString(nil, "OVERLAY")
    frame._title:SetFont(GetFont(), def.titleSize or 12, GetFontOutline())
    frame._title:SetTextColor(1, 1, 1)
    frame._title:Hide()

    if not def.isMaster then
        local tabW, tabH = GetStretchTabSize()
        local tab = CreateFrame("Button", nil, frame)
        tab:SetSize(tabW, tabH)
        tab:SetFrameLevel(frame:GetFrameLevel() + 20)
        tab:SetAlpha(STRETCH_TAB_IDLE_ALPHA)
        tab:EnableMouse(true)
        tab:RegisterForClicks("LeftButtonDown", "LeftButtonUp")

        local texLeft = tab:CreateTexture(nil, "OVERLAY")
        texLeft:SetAtlas(STRETCH_TAB_ATLAS_LEFT)
        texLeft:SetAllPoints(tab)
        texLeft:Hide()
        local texRight = tab:CreateTexture(nil, "OVERLAY")
        texRight:SetAtlas(STRETCH_TAB_ATLAS_RIGHT)
        texRight:SetAllPoints(tab)
        texRight:Hide()

        tab.texLeft  = texLeft
        tab.texRight = texRight
        tab._meterID = id

        tab:SetScript("OnEnter", function(self)
            if Orbit and Orbit.IsEditMode and Orbit:IsEditMode() then return end
            self:SetAlpha(STRETCH_TAB_HOVER_ALPHA)
        end)
        tab:SetScript("OnLeave", function(self)
            if self._dragging then return end
            self:SetAlpha(STRETCH_TAB_IDLE_ALPHA)
        end)

        -- Mutate def.barCount in memory only (no SavedVariables write) — release restores the original.
        local function RelayoutForCount(self, newCount)
            local d = Plugin:GetMeterDef(self._meterID)
            if not d then return end
            if d.barCount ~= newCount then
                d.barCount = newCount
                LayoutBars(frame, d)
                RenderFrame(self._meterID)
            end
        end

        -- Stride-multiple thresholds in both directions: round-to-nearest flickers on sub-pixel jitter.
        local function OnStretchUpdate(self)
            local d = Plugin:GetMeterDef(self._meterID)
            if not d then return end
            local _, curY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale() or 1
            local deltaPx = (curY - self._startCursorY) / scale
            -- Flip sign so "grow direction" is +ve regardless of which edge the tab sits on.
            local stretchPx = self._isOnTop and deltaPx or -deltaPx
            stretchPx = math.max(self._minStretchPx, math.min(stretchPx, self._maxStretchPx))

            local stride = self._stride
            local absExtra = stride > 0 and math.floor(math.abs(stretchPx) / stride) or 0
            local extra = stretchPx >= 0 and absExtra or -absExtra
            local newCount = math.max(1, math.min(self._origBarCount + extra, self._maxBars))
            RelayoutForCount(self, newCount)
        end

        local function EndStretch(self)
            if not self._dragging then return end
            self._dragging = false
            self:SetScript("OnUpdate", nil)
            RelayoutForCount(self, self._origBarCount or 1)
            self._origBarCount  = nil
            self._maxBars       = nil
            self._maxStretchPx  = nil
            self._minStretchPx  = nil
            self._stride        = nil
            if not self:IsMouseOver() then self:SetAlpha(STRETCH_TAB_IDLE_ALPHA) end
        end

        tab:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            if Orbit and Orbit.IsEditMode and Orbit:IsEditMode() then return end
            local d = Plugin:GetMeterDef(self._meterID)
            if not d then return end
            local _, startY = GetCursorPosition()
            self._origBarCount = d.barCount
            self._startCursorY = startY
            local maxRows = math.max(self._origBarCount, GetAvailableRowCount(d))
            maxRows = math.min(maxRows, STRETCH_MAX_BARS)
            local stride = (d.barHeight or 18) + (d.barGap or 0)
            self._stride       = stride
            self._maxBars      = maxRows
            self._maxStretchPx = math.max(0, (maxRows - self._origBarCount) * stride)
            self._minStretchPx = -math.max(0, (self._origBarCount - 1) * stride)
            self._dragging = true
            self:SetScript("OnUpdate", OnStretchUpdate)
        end)
        tab:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then EndStretch(self) end
        end)
        -- Prevent leaving def.barCount bumped if the frame hides mid-drag.
        tab:SetScript("OnHide", EndStretch)

        frame._stretchTab = tab
    end

    frame._id = id
    frame.bars = {}

    frame.CreateCanvasPreview = function(_, options)
        local currentDef = Plugin:GetMeterDef(id) or def
        local scale = (options and options.scale) or 1
        local parent = (options and options.parent) or UIParent
        local borderSize = (options and options.borderSize)
            or (OrbitEngine.Pixel and OrbitEngine.Pixel:DefaultBorderSize(scale))

        local iconSide = currentDef.iconPosition or ICON_POS_LEFT
        local showIcon = iconSide ~= ICON_POS_OFF
        local iconSize = showIcon and currentDef.barHeight or 0
        local fillWidth = currentDef.barWidth - iconSize

        local preview = OrbitEngine.Preview.Frame:CreateBasePreview(frame, scale, parent, borderSize)
        preview:SetSize(fillWidth * scale, currentDef.barHeight * scale)
        preview.sourceFrame = frame
        preview.sourceWidth = fillWidth
        preview.sourceHeight = currentDef.barHeight
        preview.previewScale = scale
        preview.components = {}

        if showIcon then
            local icon = preview:CreateTexture(nil, "ARTWORK")
            icon:SetSize(iconSize * scale, iconSize * scale)
            if iconSide == ICON_POS_RIGHT then
                icon:SetPoint("LEFT", preview, "RIGHT", 0, 0)
            else
                icon:SetPoint("RIGHT", preview, "LEFT", 0, 0)
            end
            ApplyClassIcon(icon, "WARRIOR")
        end

        local previewStylePct = currentDef.style
        if previewStylePct == nil then previewStylePct = 100 end
        local previewFillHeight = currentDef.barHeight * previewStylePct / 100 * scale

        local bar = CreateFrame("StatusBar", nil, preview)
        bar:SetPoint("BOTTOMLEFT",  preview, "BOTTOMLEFT",  0, 0)
        bar:SetPoint("TOPRIGHT",    preview, "BOTTOMRIGHT", 0, previewFillHeight)
        bar:SetStatusBarTexture(GetBarTexture())
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0.7)
        local tex = bar:GetStatusBarTexture()
        if tex and tex.SetVertexColor then tex:SetVertexColor(ResolveBarColor("WARRIOR")) end

        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(bar)
        bg:SetColorTexture(0, 0, 0, 0.4)

        local rank = preview:CreateFontString(nil, "OVERLAY")
        rank:SetFont(GetFont(), BAR_FONT_SIZE, GetFontOutline())
        rank:SetText("1.")
        rank:SetTextColor(1, 1, 1)

        local name = preview:CreateFontString(nil, "OVERLAY")
        name:SetFont(GetFont(), BAR_FONT_SIZE, GetFontOutline())
        name:SetText("Paintrains")
        name:SetTextColor(1, 1, 1)

        local positions       = currentDef.componentPositions or {}
        local rankPos         = positions.Rank       or DefaultRankPos()
        local namePos         = positions.Name       or DefaultNamePos()
        local dpsPos          = positions.DPS        or DefaultDPSPos()
        local damageDonePos   = positions.DamageDone or DefaultDamageDonePos()
        local dpsOverrides    = positions.DPS        and positions.DPS.overrides        or nil
        local totalOverrides  = positions.DamageDone and positions.DamageDone.overrides or nil

        local dps = preview:CreateFontString(nil, "OVERLAY")
        dps:SetFont(GetFont(), BAR_FONT_SIZE, GetFontOutline())
        dps:SetTextColor(1, 1, 1)
        WriteNumberField(dps, 13333, dpsOverrides)

        local damageDone = preview:CreateFontString(nil, "OVERLAY")
        damageDone:SetFont(GetFont(), BAR_FONT_SIZE, GetFontOutline())
        damageDone:SetTextColor(1, 1, 1)
        WriteNumberField(damageDone, 2400000, totalOverrides)

        -- StartX/StartY must be center-relative: CanvasModeDrag derives dragGripX from them.
        local AnchorToCenter = OrbitEngine.PositionUtils.AnchorToCenter
        local halfW, halfH = preview.sourceWidth / 2, preview.sourceHeight / 2
        local rankStartX,       rankStartY       = AnchorToCenter(rankPos.anchorX,       rankPos.anchorY,       rankPos.offsetX,       rankPos.offsetY,       halfW, halfH)
        local nameStartX,       nameStartY       = AnchorToCenter(namePos.anchorX,       namePos.anchorY,       namePos.offsetX,       namePos.offsetY,       halfW, halfH)
        local dpsStartX,        dpsStartY        = AnchorToCenter(dpsPos.anchorX,        dpsPos.anchorY,        dpsPos.offsetX,        dpsPos.offsetY,        halfW, halfH)
        local damageDoneStartX, damageDoneStartY = AnchorToCenter(damageDonePos.anchorX, damageDonePos.anchorY, damageDonePos.offsetX, damageDonePos.offsetY, halfW, halfH)

        local CDC = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent
        if CDC then
            local rankComp       = CDC(preview, "Rank",       rank,       rankStartX,       rankStartY,       rankPos)
            local nameComp       = CDC(preview, "Name",       name,       nameStartX,       nameStartY,       namePos)
            local dpsComp        = CDC(preview, "DPS",        dps,        dpsStartX,        dpsStartY,        dpsPos)
            local damageDoneComp = CDC(preview, "DamageDone", damageDone, damageDoneStartX, damageDoneStartY, damageDonePos)
            local fl = preview:GetFrameLevel() + 10
            if rankComp       then rankComp:SetFrameLevel(fl);       preview.components.Rank       = rankComp;       rank:Hide()       end
            if nameComp       then nameComp:SetFrameLevel(fl);       preview.components.Name       = nameComp;       name:Hide()       end
            if dpsComp        then dpsComp:SetFrameLevel(fl);        preview.components.DPS        = dpsComp;        dps:Hide()        end
            if damageDoneComp then damageDoneComp:SetFrameLevel(fl); preview.components.DamageDone = damageDoneComp; damageDone:Hide() end
        end

        return preview
    end

    return frame
end

-- [ RENDER ] ----------------------------------------------------------------------------------------
local DUMMY_MAX          = 2400000
local DUMMY_MIN          = 300000
local DUMMY_SLOTS        = 20
local DUMMY_FIGHT_SECONDS = 180

local function BuildPreviewRoster()
    local roster = Orbit.PlayerDummies
    local indices = roster:ShuffleIndices() -- all roles, random order
    local slots = math.min(DUMMY_SLOTS, #indices)
    local out = {}
    for i = 1, slots do
        local entry = roster[indices[i]]
        local t = slots > 1 and (i - 1) / (slots - 1) or 0
        local total = math.floor(DUMMY_MAX - (DUMMY_MAX - DUMMY_MIN) * t + 0.5)
        out[i] = {
            name            = entry.name,
            classFilename   = entry.classFilename,
            totalAmount     = total,
            amountPerSecond = math.floor(total / DUMMY_FIGHT_SECONDS + 0.5),
        }
    end
    return out
end

local function GetPreviewRoster()
    if not Plugin._previewRoster then Plugin._previewRoster = BuildPreviewRoster() end
    return Plugin._previewRoster
end

function Plugin:ReshufflePreviewRoster()
    self._previewRoster = nil
end

local NPC_DUMMY_SOURCES = {
    { name = "Molten Construct",  specIconID = "Interface\\Icons\\Ability_Hunter_Pet_Core",        totalAmount = 2400000, amountPerSecond = 13333 },
    { name = "Soul Drinker",      specIconID = "Interface\\Icons\\Spell_Shadow_SoulLeech_3",       totalAmount = 2180000, amountPerSecond = 12111 },
    { name = "Raging Proto-Drake",specIconID = "Interface\\Icons\\INV_Misc_Head_Dragon_01",        totalAmount = 1960000, amountPerSecond = 10888 },
    { name = "Corrupted Sentinel",specIconID = "Interface\\Icons\\Spell_Shadow_UnholyStrength",    totalAmount = 1840000, amountPerSecond = 10222 },
    { name = "Frostbound Ogre",   specIconID = "Interface\\Icons\\INV_Misc_MonsterHorn_09",        totalAmount = 1720000, amountPerSecond = 9555  },
    { name = "Shadow Acolyte",    specIconID = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",    totalAmount = 1550000, amountPerSecond = 8611  },
    { name = "Arcane Wyrm",       specIconID = "Interface\\Icons\\INV_Misc_Head_Dragon_Blue",      totalAmount = 1410000, amountPerSecond = 7833  },
    { name = "Stonebound Golem",  specIconID = "Interface\\Icons\\Spell_Nature_EarthShock",        totalAmount = 1270000, amountPerSecond = 7055  },
    { name = "Ravenous Mawrat",   specIconID = "Interface\\Icons\\Ability_Hunter_Pet_Rat",         totalAmount = 1140000, amountPerSecond = 6333  },
    { name = "Fel Imp",           specIconID = "Interface\\Icons\\Spell_Shadow_SummonImp",         totalAmount = 1020000, amountPerSecond = 5666  },
    { name = "Spectral Banshee",  specIconID = "Interface\\Icons\\Spell_Shadow_AntiShadow",        totalAmount = 910000,  amountPerSecond = 5055  },
    { name = "Infernal Hound",    specIconID = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",  totalAmount = 820000,  amountPerSecond = 4555  },
    { name = "Blightcaller",      specIconID = "Interface\\Icons\\Ability_Creature_Poison_05",     totalAmount = 730000,  amountPerSecond = 4055  },
    { name = "Venomous Skitterer",specIconID = "Interface\\Icons\\Ability_Hunter_Pet_Spider",      totalAmount = 650000,  amountPerSecond = 3611  },
    { name = "Thornclaw Stalker", specIconID = "Interface\\Icons\\Ability_Druid_Rake",             totalAmount = 580000,  amountPerSecond = 3222  },
    { name = "Pyroclast Elemental",specIconID = "Interface\\Icons\\Spell_Fire_Volcano",            totalAmount = 510000,  amountPerSecond = 2833  },
    { name = "Glacial Shardbearer",specIconID = "Interface\\Icons\\Spell_Frost_IceShard",          totalAmount = 450000,  amountPerSecond = 2500  },
    { name = "Abyssal Lurker",    specIconID = "Interface\\Icons\\Ability_Creature_Cursed_04",     totalAmount = 400000,  amountPerSecond = 2222  },
    { name = "Void Stalker",      specIconID = "Interface\\Icons\\Spell_Shadow_ShadowFiend",       totalAmount = 350000,  amountPerSecond = 1944  },
    { name = "Bone Horror",       specIconID = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_02",    totalAmount = 300000,  amountPerSecond = 1666  },
}

local function BuildMasterDummy(fillAmount)
    local name = UnitName("player") or "You"
    local _, classFilename = UnitClass("player")
    local specIconID
    local specIndex = GetSpecialization and GetSpecialization()
    if specIndex then
        local _, _, _, icon = GetSpecializationInfo(specIndex)
        specIconID = icon
    end
    return {
        name            = name,
        classFilename   = classFilename or "WARRIOR",
        specIconID      = specIconID,
        totalAmount     = fillAmount or 0,
        amountPerSecond = fillAmount or 0,
        isLocalPlayer   = true,
    }
end

-- Frame size is static (full barCount); only _visibleRect is elastic so hit area stays stable.
local function SetFrameHeightForVisible(frame, def, visibleCount)
    local width = GetEffectiveWidth(frame, def)
    frame:SetSize(width, FrameHeightFor(def, def.barCount))
    frame:Show()
    UpdateVisibleRect(frame, def, visibleCount)
    RefreshTitle(frame, def)
    RefreshStretchTab(frame, def)
    return false
end

local function RenderEmpty(frame, def)
    for _, bar in ipairs(frame.bars or {}) do
        bar.StatusBar:SetValue(0)
        if bar.Icon then bar.Icon:SetTexture(nil) end
        bar.Rank:SetText("")
        bar.Name:SetText("")
        bar.DPS:SetText("")
        bar.DamageDone:SetText("")
        bar:Hide()
    end
    if def then SetFrameHeightForVisible(frame, def, 0) end
end

-- Metrics with a single meaningful value — PostProcessDiscrete re-routes it into DamageDone slot.
local DISCRETE_METRICS = {
    [DM.MeterType.Interrupts] = "count",
    [DM.MeterType.Dispels]    = "count",
    [DM.MeterType.Deaths]     = "time",
}

local function PostProcessDiscrete(bar, source, meterType, positions, disabledHash)
    local kind = DISCRETE_METRICS[meterType]
    if not kind then return end
    if source.displayValue then return end

    local damageDoneDisabled = disabledHash and disabledHash.DamageDone
    local targetFS, otherFS, targetKey
    if damageDoneDisabled then
        targetFS, otherFS, targetKey = bar.DPS, bar.DamageDone, "DPS"
    else
        targetFS, otherFS, targetKey = bar.DamageDone, bar.DPS, "DamageDone"
    end
    otherFS:SetText("")
    if kind == "time" then
        targetFS:SetText(FormatDuration(source.deathTimeSeconds))
    else
        local overrides = positions and positions[targetKey] and positions[targetKey].overrides or nil
        WriteNumberField(targetFS, source.totalAmount, overrides)
    end
end

local function PaintBar(bar, rank, source, maxAmount, iconPosition, positions, meterType)
    bar._source = source
    bar.StatusBar:SetMinMaxValues(0, maxAmount)
    bar.StatusBar:SetValue(source.totalAmount)
    if iconPosition == ICON_POS_OFF then
        bar.Icon:SetTexture(nil)
    elseif source.specIconID and source.specIconID ~= 0 then
        bar.Icon:SetTexture(source.specIconID)
        bar.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        bar.Icon:Show()
    elseif ApplyClassIcon(bar.Icon, source.classFilename) then
        bar.Icon:Show()
    else
        bar.Icon:SetTexture(nil)
        bar.Icon:Hide()
    end
    local r, g, b, a = ResolveBarColor(source.classFilename, meterType)
    local tex = bar.StatusBar:GetStatusBarTexture()
    if tex and tex.SetVertexColor then tex:SetVertexColor(r, g, b, a) end
    bar.Rank:SetFormattedText("%d.", rank)
    -- GetPlayerInfoByGUID is AllowedWhenTainted and returns name/realmName separately (combat-safe).
    local displayName
    if source.sourceGUID and GetPlayerInfoByGUID then
        -- No == "" check: returned name may be secret, truthy check is the only legal inspection.
        local _, _, _, _, _, name = GetPlayerInfoByGUID(source.sourceGUID)
        if name then displayName = name end
    end
    bar.Name:SetText(displayName or source.name or "?")
    positions = positions or {}
    local rankOverrides  = positions.Rank       and positions.Rank.overrides       or nil
    local nameOverrides  = positions.Name       and positions.Name.overrides       or nil
    local dpsOverrides   = positions.DPS        and positions.DPS.overrides        or nil
    local totalOverrides = positions.DamageDone and positions.DamageDone.overrides or nil
    if source.displayValue then
        bar.DPS:SetText("")
        bar.DamageDone:SetText(source.displayValue)
    else
        WriteNumberField(bar.DPS,        source.amountPerSecond, dpsOverrides)
        WriteNumberField(bar.DamageDone, source.totalAmount,     totalOverrides)
    end

    local ApplyTextColor = OrbitEngine.OverrideUtils.ApplyTextColor
    local classFile = source.classFilename
    ApplyTextColor(bar.Rank,       rankOverrides,  nil, nil, classFile)
    ApplyTextColor(bar.Name,       nameOverrides,  nil, nil, classFile)
    ApplyTextColor(bar.DPS,        dpsOverrides,   nil, nil, classFile)
    ApplyTextColor(bar.DamageDone, totalOverrides, nil, nil, classFile)

    bar:Show()
end

function RenderFrame(id)
    local frame = meters[id]
    if not frame then return end
    local def = Plugin:GetMeterDef(id)
    if not def then return end

    local count = def.barCount
    local offset = def.scrollOffset or 0
    local inEditMode = Orbit.IsEditMode and Orbit:IsEditMode()

    local iconPosition = def.iconPosition or ICON_POS_LEFT
    local positions, disabledList = GetCanvasStateForMeter(def, def.id)
    local disabledHash = BuildDisabledHash(disabledList)
    local meterType = def.meterType
    -- metricOverride flips the color-resolution perspective (breakdown rows represent friendly casters).
    local function Paint(bar, rank, source, maxAmount, metricOverride)
        PaintBar(bar, rank, source, maxAmount, iconPosition, positions, metricOverride or meterType)
        PostProcessDiscrete(bar, source, meterType, positions, disabledHash)
    end

    if inEditMode then
        if def.isMaster then
            local bar = frame.bars[1]
            if bar then Paint(bar, 1, BuildMasterDummy(DUMMY_MAX * 0.6), DUMMY_MAX) end
            for i = 2, #frame.bars do frame.bars[i]:Hide() end
        else
            local dummies = HOSTILE_SOURCE_METRICS[meterType] and NPC_DUMMY_SOURCES or GetPreviewRoster()
            for i = 1, count do
                local bar = frame.bars[i]
                if not bar then break end
                local source = dummies[((i - 1) % #dummies) + 1]
                Paint(bar, i, source, DUMMY_MAX)
            end
            for i = count + 1, #frame.bars do frame.bars[i]:Hide() end
        end
        SetFrameHeightForVisible(frame, def, count)
        return
    end

    local Data = OrbitEngine.DamageMeterData
    local session = nil
    if Data and Data:IsAvailable() then
        session = Data:ResolveSession(def.sessionID, def.sessionType, def.meterType)
    end

    if def.isMaster then
        local bar = frame.bars[1]
        if bar then
            if session and session.combatSources then
                for i, source in ipairs(session.combatSources) do
                    if source.isLocalPlayer then
                        Paint(bar, i, source, session.maxAmount)
                        for j = 2, #frame.bars do frame.bars[j]:Hide() end
                        SetFrameHeightForVisible(frame, def, 1)
                        return
                    end
                end
            end
            local idle = BuildMasterDummy(1)
            idle.displayValue = "—"
            Paint(bar, 1, idle, 1)
            for j = 2, #frame.bars do frame.bars[j]:Hide() end
        end
        SetFrameHeightForVisible(frame, def, 1)
        return
    end

    if def.viewMode == "history" then
        local entries = BuildHistoryEntries()
        local maxDuration = 0
        for _, e in ipairs(entries) do
            if e.durationSeconds and e.durationSeconds > maxDuration then
                maxDuration = e.durationSeconds
            end
        end
        local _, playerClass = UnitClass("player")
        local visibleCount = 0
        for i = 1, count do
            local bar = frame.bars[i]
            if not bar then break end
            local entry = entries[offset + i]
            if entry then
                PaintHistoryBar(bar, offset + i, entry, maxDuration, IsHistoryEntrySelected(def, entry), playerClass)
                visibleCount = i
            else
                bar:Hide()
            end
        end
        SetFrameHeightForVisible(frame, def, visibleCount)
        return
    end

    if def.viewMode == "breakdown" and (def.breakdownGUID or def.breakdownCreatureID) then
        -- Legacy recovery: secret breakdown IDs from pre-guard saves auto-exit (secrets never un-secret).
        if issecretvalue and (
            (def.breakdownGUID and issecretvalue(def.breakdownGUID))
            or (def.breakdownCreatureID and issecretvalue(def.breakdownCreatureID))
        ) then
            C_Timer.After(0, function() Plugin:ExitBreakdown(id) end)
            RenderEmpty(frame, def)
            return
        end
        local Data = OrbitEngine.DamageMeterData
        local sourceData = Data and Data:ResolveSessionSource(
            def.sessionID, def.sessionType, def.meterType,
            def.breakdownGUID, def.breakdownCreatureID
        )
        if not sourceData or not sourceData.combatSpells then
            RenderEmpty(frame, def)
            return
        end
        local spells = sourceData.combatSpells
        local spellMax = sourceData.maxAmount
        -- Hostile-parent breakdown rows are the friendly casters (unitName/unitClassFilename) not spells.
        local isHostileParent = HOSTILE_SOURCE_METRICS[meterType]
        local metricForBreakdown = isHostileParent and DM.MeterType.DamageDone or meterType
        local fallbackClass = def.breakdownClass or ""
        local visibleCount = 0
        for i = 1, count do
            local bar = frame.bars[i]
            if not bar then break end
            local spell = spells[offset + i]
            if spell then
                local details = spell.combatSpellDetails
                local rowName, rowClass, iconID
                if isHostileParent then
                    -- Explicit blank check: details.unitName carries "" rather than nil sometimes.
                    rowName = details and details.unitName
                    if not rowName or rowName == "" then rowName = "?" end
                    rowClass = (details and details.unitClassFilename) or ""
                    if rowClass == "" then rowClass = fallbackClass end
                    iconID = details and details.specIconID
                    if not iconID or iconID == 0 then
                        if spell.spellID then
                            if C_Spell and C_Spell.GetSpellTexture then
                                iconID = C_Spell.GetSpellTexture(spell.spellID)
                            end
                            if not iconID and _G.GetSpellTexture then
                                iconID = _G.GetSpellTexture(spell.spellID)
                            end
                        end
                    end
                else
                    if spell.spellID then
                        if C_Spell and C_Spell.GetSpellName then
                            rowName = C_Spell.GetSpellName(spell.spellID)
                        end
                        if (not rowName or rowName == "") and _G.GetSpellInfo then
                            rowName = _G.GetSpellInfo(spell.spellID)
                        end
                        if C_Spell and C_Spell.GetSpellTexture then
                            iconID = C_Spell.GetSpellTexture(spell.spellID)
                        end
                        if not iconID and _G.GetSpellTexture then
                            iconID = _G.GetSpellTexture(spell.spellID)
                        end
                    end
                    if not rowName or rowName == "" then rowName = "?" end
                    rowClass = fallbackClass
                end
                bar._source = spell
                Paint(bar, offset + i, {
                    name            = rowName,
                    classFilename   = rowClass,
                    specIconID      = iconID,
                    totalAmount     = spell.totalAmount,
                    amountPerSecond = spell.amountPerSecond,
                }, spellMax, metricForBreakdown)
                visibleCount = i
            else
                bar:Hide()
            end
        end
        SetFrameHeightForVisible(frame, def, visibleCount)
        return
    end

    if not session then RenderEmpty(frame, def) return end
    local sources = session.combatSources or {}
    local maxAmount = session.maxAmount

    local visibleCount = 0
    for i = 1, count do
        local bar = frame.bars[i]
        if not bar then break end
        local source = sources[offset + i]
        if source then
            Paint(bar, offset + i, source, maxAmount)
            visibleCount = i
        else
            bar:Hide()
        end
    end

    SetFrameHeightForVisible(frame, def, visibleCount)
end

-- [ PUBLIC API ] ------------------------------------------------------------------------------------
-- Reuse frames by id: re-creating a named frame orphans the old one in _G with undefined render state.
function Plugin:RebuildAllMeters()
    if self.EnsureMasterMeter then self:EnsureMasterMeter() end

    local defs = self:GetMeterDefs()

    -- Can't :SetParent(nil) + GC in Lua 5.1; Hide + drop references and let the frame pool reclaim.
    for id, frame in pairs(meters) do
        if not defs[id] then
            frame:Hide()
            frame:ClearAllPoints()
            frame:SetParent(UIParent)
            frame._id = nil
            meters[id] = nil
        end
    end

    for id, def in pairs(defs) do
        local frame = meters[id]
        if not frame then
            frame = BuildMeterFrame(id, def)
            meters[id] = frame
        end
        LayoutBars(frame, def)
        frame:ClearAllPoints()
        local restored = false
        if OrbitEngine.Frame and OrbitEngine.Frame.RestorePosition then
            restored = OrbitEngine.Frame:RestorePosition(frame, self, id) and true or false
        end
        if not restored then
            local pos = def.position or { point = "TOPLEFT", x = 200, y = -200 }
            frame:SetPoint(pos.point or "TOPLEFT", UIParent, pos.point or "TOPLEFT", pos.x or 0, pos.y or 0)
        end
        frame:Show()
        -- Visibility Engine: all meters (master + user) share the "DamageMeters" entry via sentinel index 1.
        if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, 1, "OutOfCombatFade", false) end
    end

    self:RenderAllMeters()
end

function Plugin:CheckViewTimeouts()
    local now = GetTime()
    for id, frame in pairs(meters) do
        local def = self:GetMeterDef(id)
        if def and not def.isMaster
           and (def.viewMode == "breakdown" or def.viewMode == "history") then
            local last = frame._lastInteraction or now
            if now - last > VIEW_TIMEOUT_SECONDS then
                self:UpdateMeterDef(id, {
                    viewMode            = "chart",
                    breakdownGUID       = Plugin.CLEAR,
                    breakdownCreatureID = Plugin.CLEAR,
                    breakdownClass      = Plugin.CLEAR,
                    breakdownName       = Plugin.CLEAR,
                    scrollOffset        = 0,
                })
            end
        end
    end
end

function Plugin:RenderAllMeters()
    for id in pairs(meters) do RenderFrame(id) end
end

function Plugin:RelayoutAllMeters()
    for id, frame in pairs(meters) do
        local def = self:GetMeterDef(id)
        if def then LayoutBars(frame, def) end
    end
    self:RenderAllMeters()
end

function Plugin:GetMeterFrames()
    return meters
end

function Plugin:GetFrameBySystemIndex(systemIndex)
    return meters[systemIndex]
end

local function RegisterComponentSchemas()
    local Schema = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.SettingsSchema
    if not Schema or not Schema.KEY_SCHEMAS then return end
    local FORMAT_DROPDOWN = {
        type = "dropdown", key = "Format", label = L.PLU_DM_FORMAT, default = "Short",
        options = {
            { text = L.PLU_DM_FORMAT_SHORT, value = "Short" },
            { text = L.PLU_DM_FORMAT_FULL,  value = "Full"  },
        },
    }
    local NUMBER_TEXT = {
        controls = {
            { type = "font",        key = "Font",             label = "Font" },
            { type = "slider",      key = "FontSize",         label = "Size", min = 6, max = 32, step = 1 },
            { type = "colorcurve",  key = "CustomColorCurve", label = "Color", singleColor = true },
            FORMAT_DROPDOWN,
        },
    }
    Schema.KEY_SCHEMAS.DPS        = NUMBER_TEXT
    Schema.KEY_SCHEMAS.DamageDone = NUMBER_TEXT
end

-- [ INIT ] ------------------------------------------------------------------------------------------
function Plugin:InitUI()
    RegisterComponentSchemas()

    Orbit.EventBus:On(SIGNAL.CurrentUpdated, function() self:RenderAllMeters() end, self)
    Orbit.EventBus:On(SIGNAL.SessionUpdated, function() self:RenderAllMeters() end, self)
    Orbit.EventBus:On(SIGNAL.SessionReset, function()
        for id, frame in pairs(meters) do RenderEmpty(frame, self:GetMeterDef(id)) end
    end, self)

    if Orbit.Engine and Orbit.Engine.EditMode then
        Orbit.Engine.EditMode:RegisterCallbacks({
            Exit = function()
                self:RelayoutAllMeters()
            end,
        }, self)
    end

    if self._uiTicker then self._uiTicker:Cancel() end
    self._uiTicker = C_Timer.NewTicker(0.5, function()
        self:CheckViewTimeouts()
        self:RenderAllMeters()
    end)
end
