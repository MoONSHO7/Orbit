---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_HonorBar"
local FRAME_NAME = "OrbitHonorBar"
local DEFAULT_WIDTH = 500
local DEFAULT_HEIGHT = 14
local DEFAULT_FONT_SIZE = 11
local DEFAULT_Y = 10

local HONOR_COLOR = { r = 0.95, g = 0.45, b = 0.15, a = 1 }
local DEFAULT_TICK_WIDTH = 2

local WOW_EVENTS = { "HONOR_XP_UPDATE", "HONOR_LEVEL_UPDATE", "ZONE_CHANGED_NEW_AREA" }

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Honor Bar", SYSTEM_ID, {
    liveToggle = true,
    canvasMode = true,
    defaults = {
        Width = DEFAULT_WIDTH,
        Height = DEFAULT_HEIGHT,
        ValueMode = "percent",
        TextOnMouseover = false,
        TickWidth = DEFAULT_TICK_WIDTH,
        SmoothFill = true,
        OnlyInPvP = false,
        BarColor = { pins = { { position = 0, color = { r = HONOR_COLOR.r, g = HONOR_COLOR.g, b = HONOR_COLOR.b, a = 1 } } } },
        ComponentPositions = {
            Name     = { anchorX = "LEFT",   anchorY = "CENTER", offsetX = 5,  offsetY = 0, posX = -240, posY = 0, justifyH = "LEFT",   selfAnchorY = "CENTER" },
            BarLevel = { anchorX = "CENTER", anchorY = "CENTER", offsetX = 0,  offsetY = 0, posX = 0,    posY = 0, justifyH = "CENTER", selfAnchorY = "CENTER" },
            BarValue = { anchorX = "RIGHT",  anchorY = "CENTER", offsetX = -5, offsetY = 0, posX = 240,  posY = 0, justifyH = "RIGHT",  selfAnchorY = "CENTER" },
        },
        DisabledComponents = {},
    },
})

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:OnLoad()
    Orbit.StatusBarBase:HideBlizzardTrackingBars()

    local frame = Orbit.StatusBarBase:Create(FRAME_NAME, UIParent)
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    frame.systemIndex = SYSTEM_ID
    frame.editModeName = "Honor Bar"
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

    Orbit.StatusBarSession:Start("Orbit_HonorBar", UnitHonor("player") or 0)

    for _, event in ipairs(WOW_EVENTS) do
        Orbit.EventBus:On(event, function() self:OnEvent(event) end, self)
    end

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()
end

function Plugin:OnEvent(event)
    if event == "HONOR_LEVEL_UPDATE" then
        Orbit.StatusBarSession:OnResetBoundary("Orbit_HonorBar", UnitHonorMax("player") or 0)
    elseif event == "HONOR_XP_UPDATE" then
        local cur = UnitHonor("player")
        if cur and not issecretvalue(cur) then
            Orbit.StatusBarSession:Update("Orbit_HonorBar", cur)
        end
    end
    if self._updatePending then return end
    self._updatePending = true
    C_Timer.After(0, function()
        self._updatePending = false
        if self.frame then self:UpdateBar() end
    end)
end

-- [ UPDATE ]-----------------------------------------------------------------------------------------
function Plugin:UpdateBar()
    local frame = self.frame
    if not frame or not frame:IsShown() then return end

    local current = UnitHonor("player")
    local max = UnitHonorMax("player")
    local level = UnitHonorLevel("player") or 0

    if self:GetSetting(SYSTEM_ID, "SmoothFill") then
        Orbit.StatusBarBase:SetSmoothFill(frame, current, max)
    else
        Orbit.StatusBarBase:SetFill(frame, current, max)
    end

    local c = self:GetBarColor()
    frame.Bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
    Orbit.StatusBarBase:SetTickWidth(frame, self:GetSetting(SYSTEM_ID, "TickWidth") or 0)

    local gained, rate = Orbit.StatusBarSession:GetStats("Orbit_HonorBar")
    local remaining, eta = 0, 0
    if not issecretvalue(current) and not issecretvalue(max) and max and max > 0 then
        remaining = max - current
        eta = (rate and rate > 0) and ((remaining / rate) * 3600) or 0
    end

    local ctx = {
        cur = (not issecretvalue(current)) and current or nil,
        max = (not issecretvalue(max)) and max or nil,
        level = level, name = L.PLU_HONOR_NAME,
        perhour = rate, session = gained, eta = eta,
    }
    Orbit.StatusBarBase:SetComponentText(frame.Name, L.PLU_HONOR_NAME)
    Orbit.StatusBarBase:SetComponentText(frame.Level, tostring(level))
    Orbit.StatusBarBase:SetComponentText(frame.Value, Orbit.StatusBarTextTemplate:Render(Orbit.StatusBarBase:ResolveTemplate(self, SYSTEM_ID), ctx))
    Orbit.StatusBarBase:SyncPreviewText(self, frame)
end

function Plugin:GetBarColor()
    local curve = self:GetSetting(SYSTEM_ID, "BarColor")
    local c = curve and OrbitEngine.ColorCurve and OrbitEngine.ColorCurve:GetFirstColorFromCurve(curve)
    return c or HONOR_COLOR
end

-- [ TOOLTIP + CLICK ]--------------------------------------------------------------------------------
function Plugin:SetupTooltipAndClicks()
    local frame = self.frame
    frame:HookScript("OnEnter", function() Plugin:ShowTooltip() end)
    frame:HookScript("OnLeave", function() Orbit.StatusBarTooltip:Hide() end)

    Orbit.StatusBarBase:SetupClickDispatch(frame, {
        onLeftClick = function() Plugin:OnLeftClick() end,
        onShiftClick = function() Plugin:OnShiftClick() end,
        onShiftRightClick = function() Plugin:ResetSession() end,
    })
end

function Plugin:ResetSession()
    Orbit.StatusBarSession:Reset("Orbit_HonorBar", UnitHonor("player") or 0)
    if self.frame then self:UpdateBar() end
end

function Plugin:ShowTooltip()
    if Orbit:IsEditMode() then return end
    Orbit.StatusBarTooltip:ShowHonor(self.frame, UnitHonorLevel("player") or 0, UnitHonor("player"), UnitHonorMax("player"))
end

function Plugin:OnLeftClick()
    if TogglePVPUI then TogglePVPUI() end
end

function Plugin:OnShiftClick()
    local cur, max = UnitHonor("player"), UnitHonorMax("player")
    if issecretvalue(cur) or issecretvalue(max) or not max or max <= 0 then return end
    local editBox = ChatEdit_GetActiveWindow() or ChatEdit_GetLastActiveWindow()
    if not editBox and ChatFrame_OpenChat then ChatFrame_OpenChat("") end
    editBox = ChatEdit_GetActiveWindow()
    if not editBox then return end
    editBox:Insert(L.PLU_HONOR_CHAT_LINK_F:format(
        UnitHonorLevel("player") or 0, cur, max, (cur / max) * 100))
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

    frame:SetShown(self:ShouldShow())
    C_Timer.After(0, function()
        if self.frame and self.frame:IsShown() then self:UpdateBar() end
    end)
end

function Plugin:ShouldShow()
    if not self:GetSetting(SYSTEM_ID, "OnlyInPvP") then return true end
    if Orbit:IsEditMode() then return true end
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena" or (C_PvP and C_PvP.IsWarModeActive and C_PvP.IsWarModeActive())
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
    elseif currentTab == L.PLU_SB_TAB_COLOR then
        SB:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "BarColor",
            label = L.PLU_SB_BAR_COLOR,
            singleColor = true,
        })
    elseif currentTab == L.PLU_SB_TAB_BEHAVIOUR then
        table.insert(schema.controls, { type = "checkbox", key = "OnlyInPvP",       label = L.PLU_SB_ONLY_IN_PVP,     default = false })
        table.insert(schema.controls, { type = "checkbox", key = "TextOnMouseover", label = L.PLU_SB_TEXT_MOUSEOVER,  default = false })
        table.insert(schema.controls, { type = "checkbox", key = "SmoothFill",      label = L.PLU_SB_SMOOTH_FILL,     default = true })
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

-- [ BLIZZARD HIDER ]---------------------------------------------------------------------------------
Orbit:RegisterBlizzardHider("Honor Bar", function()
    Orbit.StatusBarBase:HideBlizzardTrackingBars()
end)
