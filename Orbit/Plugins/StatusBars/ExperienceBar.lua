---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_ExperienceBar"
local FRAME_NAME = "OrbitExperienceBar"
local DEFAULT_WIDTH = 500
local DEFAULT_HEIGHT = 14
local DEFAULT_FONT_SIZE = 11
local DEFAULT_Y = 28

local XP_COLOR = { r = 0.58, g = 0.0, b = 0.55, a = 1 }
local RESTED_COLOR = { r = 0.25, g = 0.25, b = 1.0, a = 0.6 }
local PENDING_COLOR = { r = 0.2, g = 0.9, b = 0.2, a = 0.5 }
local WARBAND_PREFIX = ""

local REACTION_LABEL = {
    [1] = "Hated",    [2] = "Hostile",  [3] = "Unfriendly", [4] = "Neutral",
    [5] = "Friendly", [6] = "Honored",  [7] = "Revered",    [8] = "Exalted",
}

local MODE_XP = "xp"
local MODE_REP = "rep"

local DEFAULT_TICK_WIDTH = 2

local WOW_EVENTS = {
    "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "DISABLE_XP_GAIN", "ENABLE_XP_GAIN",
    "UPDATE_FACTION", "QUEST_FINISHED", "MAJOR_FACTION_UNLOCKED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
    "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
}

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Experience Bar", SYSTEM_ID, {
    liveToggle = true,
    canvasMode = true,
    defaults = {
        Width = DEFAULT_WIDTH,
        Height = DEFAULT_HEIGHT,
        ValueMode = "percent",
        TextOnMouseover = false,
        TickWidth = DEFAULT_TICK_WIDTH,
        SmoothFill = true,
        ShowPending = true,
        ShowParagonTicks = true,
        AutoWatchFaction = true,
        MinLevel = 1,
        XPColor = { pins = { { position = 0, color = { r = XP_COLOR.r, g = XP_COLOR.g, b = XP_COLOR.b, a = 1 } } } },
        ComponentPositions = {
            Name     = { anchorX = "LEFT",   anchorY = "CENTER", offsetX = 5,  offsetY = 0, posX = -240, posY = 0, justifyH = "LEFT",   selfAnchorY = "CENTER" },
            BarLevel = { anchorX = "CENTER", anchorY = "CENTER", offsetX = 0,  offsetY = 0, posX = 0,    posY = 0, justifyH = "CENTER", selfAnchorY = "CENTER" },
            BarValue = { anchorX = "RIGHT",  anchorY = "CENTER", offsetX = -5, offsetY = 0, posX = 240,  posY = 0, justifyH = "RIGHT",  selfAnchorY = "CENTER" },
        },
        DisabledComponents = {},
    },
})

-- Previous-rep tracker for auto-watch detection (no UI cycling).
local lastReputationByFaction = {}

-- [ MODE RESOLUTION ]--------------------------------------------------------------------------------
local function ParagonCycles(currentValue, threshold, hasReward)
    if not currentValue or not threshold or threshold <= 0 then return 0 end
    local n = math.floor(currentValue / threshold)
    return hasReward and math.max(0, n - 1) or n
end

local function BuildRepRecord(watched)
    local factionID = watched.factionID
    local majorData = C_MajorFactions and C_MajorFactions.GetMajorFactionData and C_MajorFactions.GetMajorFactionData(factionID)
    local RC = OrbitEngine.ReactionColor
    local isAccountWide = C_Reputation and C_Reputation.IsAccountWideReputation and C_Reputation.IsAccountWideReputation(factionID) or false

    if majorData and majorData.renownLevelThreshold and majorData.renownLevelThreshold > 0 then
        return {
            mode = MODE_REP, factionID = factionID,
            name = majorData.name or watched.name,
            current = majorData.renownReputationEarned or 0,
            min = 0,
            max = majorData.renownLevelThreshold,
            level = string.format("Renown %d", majorData.renownLevel or 0),
            color = RC:GetOverride("RENOWN"),
            isAccountWide = isAccountWide,
        }
    end

    if C_Reputation.IsFactionParagon and C_Reputation.IsFactionParagon(factionID) then
        local value, threshold, _, hasReward = C_Reputation.GetFactionParagonInfo(factionID)
        if value and threshold and threshold > 0 then
            local renownLevel = majorData and majorData.renownLevel
            local cycles = ParagonCycles(value, threshold, hasReward)
            local levelLabel = renownLevel
                and string.format("Renown %d — %s", renownLevel, hasReward and "Paragon!" or "Paragon")
                or (hasReward and "Paragon!" or "Paragon")
            return {
                mode = MODE_REP, factionID = factionID,
                name = (majorData and majorData.name) or watched.name,
                current = value % threshold,
                min = 0,
                max = threshold,
                level = levelLabel,
                color = RC:GetOverride(hasReward and "PARAGON_REWARD" or "PARAGON"),
                paragonCycles = cycles,
                isAccountWide = isAccountWide,
            }
        end
    end

    local reaction = watched.reaction or 4
    local reactionMin = watched.currentReactionThreshold or 0
    local reactionMax = watched.nextReactionThreshold or (reactionMin + 1)
    if reactionMax <= reactionMin then reactionMax = reactionMin + 1 end
    return {
        mode = MODE_REP, factionID = factionID,
        name = watched.name or "Unknown",
        current = watched.currentStanding or reactionMin,
        min = reactionMin,
        max = reactionMax,
        level = REACTION_LABEL[reaction] or "",
        color = RC:GetReactionColor(reaction),
        isAccountWide = isAccountWide,
    }
end

function Plugin:BuildActiveRecord()
    local level = UnitLevel("player")
    local maxLevel = GetMaxPlayerLevel()
    local xpDisabled = IsXPUserDisabled and IsXPUserDisabled() or false
    local minLevel = self:GetSetting(SYSTEM_ID, "MinLevel") or 1

    if level < maxLevel and not xpDisabled and level >= minLevel then
        return { mode = MODE_XP, level = level }
    end
    local watched = C_Reputation.GetWatchedFactionData()
    if watched and watched.factionID and watched.factionID > 0 then
        return BuildRepRecord(watched)
    end
    return nil
end

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:OnLoad()
    Orbit.StatusBarBase:HideBlizzardTrackingBars()

    local frame = Orbit.StatusBarBase:Create(FRAME_NAME, UIParent)
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    frame.systemIndex = SYSTEM_ID
    frame.editModeName = "Experience Bar"
    frame.anchorOptions = { horizontal = true, vertical = true }
    frame.orbitWidthSync = true
    frame.orbitHeightSync = true
    frame.orbitResizeBounds = { minW = 100, maxW = 1200, minH = 4, maxH = 40 }
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, DEFAULT_Y)

    self.frame = frame
    self.Frame = frame

    Orbit.StatusBarBase:CreateTextComponents(frame)
    Orbit.StatusBarBase:EnableSmoothFill(frame)
    OrbitEngine.Frame:AttachSettingsListener(frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)
    Orbit.StatusBarBase:AttachCanvasComponents(self, frame, SYSTEM_ID)
    Orbit.StatusBarBase:SetupMouseoverHooks(self, frame)
    self:SetupTooltipAndClicks()

    -- Start sessions for XP and Rep separately so switching modes doesn't nuke rates.
    Orbit.StatusBarSession:Start("Orbit_ExperienceBar_XP", UnitXP("player") or 0)

    for _, event in ipairs(WOW_EVENTS) do
        Orbit.EventBus:On(event, function(...) self:OnEvent(event, ...) end, self)
    end

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()
end

-- [ EVENT ROUTER ]-----------------------------------------------------------------------------------
-- UpdateBar is always deferred one tick so secret-adjacent reads (UnitXP, C_Reputation.*, etc.)
-- never run inside Blizzard's synchronous edit-mode callback chain. Side-effect work that must
-- observe the pre-deferral state (session boundary on level up, auto-watched faction scan) stays
-- on the event's own frame.
function Plugin:OnEvent(event, arg1)
    if event == "PLAYER_LEVEL_UP" then
        Orbit.StatusBarSession:OnResetBoundary("Orbit_ExperienceBar_XP", UnitXPMax("player") or 0)
    elseif event == "PLAYER_XP_UPDATE" then
        Orbit.StatusBarSession:Update("Orbit_ExperienceBar_XP", UnitXP("player") or 0)
    elseif event == "UPDATE_FACTION" then
        self:OnFactionUpdate()
    end
    if self._updatePending then return end
    self._updatePending = true
    C_Timer.After(0, function()
        self._updatePending = false
        if self.frame then self:UpdateBar() end
    end)
end

-- Auto-watch the faction whose reputation just changed. Detected by scanning recent rep for a
-- delta. Only triggers when setting enabled.
function Plugin:OnFactionUpdate()
    if not self:GetSetting(SYSTEM_ID, "AutoWatchFaction") then return end
    if not C_Reputation or not C_Reputation.GetFactionDataByIndex then return end
    local numFactions = C_Reputation.GetNumFactions and C_Reputation.GetNumFactions() or 0
    for i = 1, numFactions do
        local data = C_Reputation.GetFactionDataByIndex(i)
        if data and data.factionID and not data.isHeader and data.currentStanding then
            local prev = lastReputationByFaction[data.factionID]
            if prev and data.currentStanding > prev and C_Reputation.SetWatchedFactionByIndex then
                C_Reputation.SetWatchedFactionByIndex(i)
            end
            lastReputationByFaction[data.factionID] = data.currentStanding
        end
    end
end

-- [ UPDATE ]-----------------------------------------------------------------------------------------
function Plugin:UpdateBar()
    local frame = self.frame
    if not frame then return end

    local record = self:BuildActiveRecord()
    if not record then
        if Orbit:IsEditMode() then
            frame:Show()
            local c = self:GetXPColor()
            frame.Bar:SetStatusBarColor(c.r, c.g, c.b, 1)
            frame.Bar:SetMinMaxValues(0, 1)
            frame.Bar:SetValue(0.5)
            Orbit.StatusBarBase:SetComponentText(frame.Name, L.PLU_SB_REP_NONE)
            Orbit.StatusBarBase:SetComponentText(frame.Level, "")
            Orbit.StatusBarBase:SetComponentText(frame.Value, "")
            Orbit.StatusBarBase:SyncPreviewText(self, frame)
        else
            frame:Hide()
        end
        Orbit.StatusBarBase:HideOverlay(frame)
        Orbit.StatusBarBase:HidePending(frame)
        Orbit.StatusBarBase:SetTickWidth(frame, 0)
        Orbit.StatusBarBase:SetTickMarks(frame, 0)
        return
    end

    frame:Show()
    Orbit.StatusBarBase:SetTickWidth(frame, self:GetSetting(SYSTEM_ID, "TickWidth") or 0)

    if record.mode == MODE_XP then
        local c = self:GetXPColor()
        frame.Bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        self:UpdateXP(record.level)
        Orbit.StatusBarBase:SetTickMarks(frame, 0)
    else
        frame.Bar:SetStatusBarColor(record.color.r, record.color.g, record.color.b, record.color.a or 1)
        Orbit.StatusBarBase:HideOverlay(frame)
        Orbit.StatusBarBase:HidePending(frame)
        self:UpdateRep(record)
    end

    Orbit.StatusBarBase:SyncPreviewText(self, frame)
end

function Plugin:UpdateXP(level)
    local frame = self.frame
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    if self:GetSetting(SYSTEM_ID, "SmoothFill") then
        Orbit.StatusBarBase:SetSmoothFill(frame, currentXP, maxXP)
    else
        Orbit.StatusBarBase:SetFill(frame, currentXP, maxXP)
    end

    local rested = GetXPExhaustion() or 0
    if rested > 0 and not issecretvalue(currentXP) and not issecretvalue(maxXP) and maxXP > 0 then
        local overlayValue = currentXP + rested
        if overlayValue > maxXP then overlayValue = maxXP end
        frame.Overlay:SetStatusBarColor(RESTED_COLOR.r, RESTED_COLOR.g, RESTED_COLOR.b, RESTED_COLOR.a)
        Orbit.StatusBarBase:SetOverlayFill(frame, overlayValue, maxXP)
    else
        Orbit.StatusBarBase:HideOverlay(frame)
    end

    local pending = 0
    if self:GetSetting(SYSTEM_ID, "ShowPending") then
        pending = Orbit.StatusBarPendingXP:Sum()
        Orbit.StatusBarBase:SetPendingFill(frame, currentXP, maxXP, pending, PENDING_COLOR)
    else
        Orbit.StatusBarBase:HidePending(frame)
    end

    local gained, rate = Orbit.StatusBarSession:GetStats("Orbit_ExperienceBar_XP")
    local remaining = (maxXP or 0) - (currentXP or 0)
    local eta = (rate and rate > 0 and remaining > 0) and ((remaining / rate) * 3600) or 0

    local ctx = {
        cur = currentXP, max = maxXP, rested = rested, level = level, name = "Experience",
        perhour = rate, session = gained, eta = eta, pending = pending,
    }
    Orbit.StatusBarBase:SetComponentText(frame.Name, "Experience")
    Orbit.StatusBarBase:SetComponentText(frame.Level, tostring(level))
    Orbit.StatusBarBase:SetComponentText(frame.Value, Orbit.StatusBarTextTemplate:Render(Orbit.StatusBarBase:ResolveTemplate(self, SYSTEM_ID), ctx))
    Orbit.StatusBarBase:SyncPreviewText(self, frame)
end

function Plugin:UpdateRep(record)
    local frame = self.frame
    if self:GetSetting(SYSTEM_ID, "SmoothFill") then
        Orbit.StatusBarBase:SetSmoothFill(frame, record.current, record.max)
    else
        frame.Bar:SetMinMaxValues(record.min, record.max)
        frame.Bar:SetValue(record.current)
    end

    local tickCount = 0
    if self:GetSetting(SYSTEM_ID, "ShowParagonTicks") and record.paragonCycles and record.paragonCycles > 0 then
        tickCount = math.min(record.paragonCycles, 5)
    end
    Orbit.StatusBarBase:SetTickMarks(frame, tickCount, { r = 1.0, g = 0.8, b = 0.2, a = 0.8 })

    local ctx = {
        cur = record.current - record.min, max = record.max - record.min,
        level = record.level, name = record.name,
        paragonCycles = record.paragonCycles or 0,
    }
    local displayName = record.isAccountWide and (WARBAND_PREFIX .. record.name) or record.name
    Orbit.StatusBarBase:SetComponentText(frame.Name, displayName)
    Orbit.StatusBarBase:SetComponentText(frame.Level, record.level)
    Orbit.StatusBarBase:SetComponentText(frame.Value, Orbit.StatusBarTextTemplate:Render(Orbit.StatusBarBase:ResolveTemplate(self, SYSTEM_ID), ctx))
    Orbit.StatusBarBase:SyncPreviewText(self, frame)
end

function Plugin:GetXPColor()
    local curve = self:GetSetting(SYSTEM_ID, "XPColor")
    local c = curve and OrbitEngine.ColorCurve and OrbitEngine.ColorCurve:GetFirstColorFromCurve(curve)
    return c or XP_COLOR
end

-- [ TOOLTIP + CLICK ]--------------------------------------------------------------------------------
function Plugin:SetupTooltipAndClicks()
    local frame = self.frame
    frame:HookScript("OnEnter", function(self) Plugin:ShowTooltip() end)
    frame:HookScript("OnLeave", function(self) Orbit.StatusBarTooltip:Hide() end)

    Orbit.StatusBarBase:SetupClickDispatch(frame, {
        onLeftClick = function() Plugin:OnLeftClick() end,
        onShiftClick = function() Plugin:OnShiftClick() end,
        onShiftRightClick = function() Plugin:ResetSession() end,
    })
end

function Plugin:ResetSession()
    Orbit.StatusBarSession:Reset("Orbit_ExperienceBar_XP", UnitXP("player") or 0)
    if self.frame then self:UpdateBar() end
end

function Plugin:ShowTooltip()
    if Orbit:IsEditMode() then return end
    local record = self:BuildActiveRecord()
    if not record then return end
    if record.mode == MODE_XP then
        Orbit.StatusBarTooltip:ShowXP(self.frame, record.level, UnitXP("player"), UnitXPMax("player"))
    else
        Orbit.StatusBarTooltip:ShowRep(self.frame, record, record.isAccountWide, record.paragonCycles)
    end
end

function Plugin:OnLeftClick()
    local record = self:BuildActiveRecord()
    if not record or record.mode == MODE_XP then
        if ToggleCharacter then ToggleCharacter("PaperDollFrame") end
    else
        if ToggleCharacter then ToggleCharacter("ReputationFrame") end
    end
end

function Plugin:OnShiftClick()
    local record = self:BuildActiveRecord()
    if not record then return end
    local editBox = ChatEdit_GetActiveWindow() or ChatEdit_GetLastActiveWindow()
    if not editBox then
        if ChatFrame_OpenChat then ChatFrame_OpenChat("") end
        editBox = ChatEdit_GetActiveWindow()
    end
    if not editBox then return end
    local text
    if record.mode == MODE_XP then
        local cur, max = UnitXP("player"), UnitXPMax("player")
        if not issecretvalue(cur) and not issecretvalue(max) and max > 0 then
            text = string.format("[XP: Level %d — %d/%d (%.1f%%)]", record.level, cur, max, (cur / max) * 100)
        end
    else
        local prog = record.current - record.min
        local span = record.max - record.min
        if span > 0 then
            text = string.format("[%s — %s — %d/%d (%.1f%%)]", record.name, record.level, prog, span, (prog / span) * 100)
        end
    end
    if text then editBox:Insert(text) end
end

-- [ APPLY SETTINGS ]---------------------------------------------------------------------------------
function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then return end

    local width = self:GetSetting(SYSTEM_ID, "Width") or DEFAULT_WIDTH
    local height = self:GetSetting(SYSTEM_ID, "Height") or DEFAULT_HEIGHT

    frame:SetSize(width, height)
    Orbit.StatusBarBase:ApplyTheme(frame)

    local positions = self:GetComponentPositions(SYSTEM_ID) or {}
    Orbit.StatusBarBase:ApplyTextComponent(frame.Name,  (positions.Name     or {}).overrides, DEFAULT_FONT_SIZE)
    Orbit.StatusBarBase:ApplyTextComponent(frame.Level, (positions.BarLevel or {}).overrides, DEFAULT_FONT_SIZE)
    Orbit.StatusBarBase:ApplyTextComponent(frame.Value, (positions.BarValue or {}).overrides, DEFAULT_FONT_SIZE)
    OrbitEngine.ComponentDrag:RestoreFramePositions(frame, positions)
    Orbit.StatusBarBase:ApplyComponentVisibility(self, frame)

    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(frame, self, SYSTEM_ID) end
    C_Timer.After(0, function()
        if self.frame then self:UpdateBar() end
    end)
end

-- [ SETTINGS UI ]------------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }

    SB:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = SB:AddSettingsTabs(schema, dialog,
        { L.PLU_SB_TAB_LAYOUT, L.PLU_SB_TAB_COLOR, L.PLU_SB_TAB_BEHAVIOUR },
        L.PLU_SB_TAB_LAYOUT)

    if currentTab == L.PLU_SB_TAB_LAYOUT then
        SB:AddSizeSettings(self, schema, systemIndex, systemFrame,
            { key = "Width",  label = L.PLU_SB_WIDTH,  min = 100, max = 1200, step = 1, default = DEFAULT_WIDTH },
            { key = "Height", label = L.PLU_SB_HEIGHT, min = 4,   max = 40,   step = 1, default = DEFAULT_HEIGHT },
            nil)
        table.insert(schema.controls, {
            type = "slider", key = "TickWidth", label = L.PLU_SB_TICK, tooltip = L.PLU_SB_TICK_TT,
            min = 0, max = 10, step = 1, default = DEFAULT_TICK_WIDTH,
        })
        table.insert(schema.controls, {
            type = "slider", key = "MinLevel", label = L.PLU_SB_MIN_LEVEL,
            min = 1, max = 80, step = 1, default = 1,
        })
    elseif currentTab == L.PLU_SB_TAB_COLOR then
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "XPColor",
            label = L.PLU_SB_XP_COLOR,
            singleColor = true,
        })
    elseif currentTab == L.PLU_SB_TAB_BEHAVIOUR then
        table.insert(schema.controls, { type = "checkbox", key = "TextOnMouseover",   label = L.PLU_SB_TEXT_MOUSEOVER,   default = false })
        table.insert(schema.controls, { type = "checkbox", key = "SmoothFill",        label = L.PLU_SB_SMOOTH_FILL,      default = true })
        table.insert(schema.controls, { type = "checkbox", key = "ShowPending",       label = L.PLU_SB_SHOW_PENDING,     default = true })
        table.insert(schema.controls, { type = "checkbox", key = "ShowParagonTicks",  label = L.PLU_SB_SHOW_PARAGON_TICKS, default = true })
        table.insert(schema.controls, { type = "checkbox", key = "AutoWatchFaction",  label = L.PLU_SB_AUTO_WATCH,       default = true })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ BLIZZARD HIDER ]---------------------------------------------------------------------------------
Orbit:RegisterBlizzardHider("Experience Bar", function()
    Orbit.StatusBarBase:HideBlizzardTrackingBars()
end)
