-- [ CONTINUOUS BAR RENDERER ]----------------------------------------------------------------------
-- Handles Stagger, Soul Fragments, Ebon Might, Mana, Maelstrom Weapon
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local ResourceMixin = Orbit.ResourceBarMixin
local CanUseUnitPowerPercent = Orbit.PlayerUtilShared.CanUseUnitPowerPercent
local SafeUnitPowerPercent = Orbit.PlayerUtilShared.SafeUnitPowerPercent

local SMOOTH_ANIM = Enum.StatusBarInterpolation.ExponentialEaseOut
local MAX_SPACER_COUNT = 10
local TICK_ALPHA_CURVE = OrbitEngine.TickMixin.TICK_ALPHA_CURVE

local Renderer = {}
Orbit.ContinuousBarRenderer = Renderer

-- [ RESOURCE CONFIG ]------------------------------------------------------------------------------
Renderer.CONFIG = {
    STAGGER = {
        curveKey = "StaggerColorCurve",
        getState = function() return ResourceMixin:GetStaggerState() end,
        updateText = function(text, current) text:SetText(current) end,
    },
    SOUL_FRAGMENTS = {
        curveKey = "SoulFragmentsColorCurve",
        getState = function() return ResourceMixin:GetSoulFragmentsState() end,
        updateText = function(text, current) text:SetText(current) end,
    },
    EBON_MIGHT = {
        curveKey = "EbonMightColorCurve",
        getState = function() return ResourceMixin:GetEbonMightState() end,
        updateText = function(text, current) text:SetFormattedText("%.1f", current) end,
    },
    MANA = {
        curveKey = "ManaColorCurve",
        getState = function() return UnitPower("player", Enum.PowerType.Mana), UnitPowerMax("player", Enum.PowerType.Mana) end,
        updateText = function(text, current)
            local percent = SafeUnitPowerPercent("player", Enum.PowerType.Mana)
            if percent then text:SetFormattedText("%.0f", percent)
            else text:SetText(current) end
        end,
    },
    MAELSTROM_WEAPON = {
        curveKey = "MaelstromWeaponColorCurve",
        dividers = true,
        maxDividers = 10,
        getState = function() return ResourceMixin:GetMaelstromWeaponState() end,
        updateText = function(text, _, _, hasAura, auraInstanceID)
            if not hasAura then text:SetText("0"); return end
            if auraInstanceID and C_UnitAuras.GetAuraApplicationDisplayCount then
                text:SetText(C_UnitAuras.GetAuraApplicationDisplayCount("player", auraInstanceID))
            else text:SetText("1") end
        end,
    },
}

-- [ MODE SWITCHING ]-------------------------------------------------------------------------------
function Renderer:SetContinuousMode(frame, isContinuous)
    if isContinuous then
        if frame.StatusBarContainer then frame.StatusBarContainer:Show() end
        OrbitEngine.TickMixin:Show(frame)
        for _, btn in ipairs(frame.buttons or {}) do btn:Hide() end
        if frame.Spacers then for _, s in ipairs(frame.Spacers) do s:Hide() end end
    else
        if frame.StatusBarContainer then frame.StatusBarContainer:Hide() end
        OrbitEngine.TickMixin:Hide(frame)
    end
end

-- [ CONTINUOUS BAR UPDATE ]------------------------------------------------------------------------
function Renderer:UpdateBar(plugin, frame, systemIndex, curveKey, current, max, continuousResource)
    if not frame.StatusBar then return end
    frame.StatusBar:SetMinMaxValues(0, max)
    local smoothing = plugin:GetSetting(systemIndex, "SmoothAnimation") ~= false and SMOOTH_ANIM or nil
    frame.StatusBar:SetValue(current, smoothing)
    OrbitEngine.TickMixin:Update(frame, current, max, smoothing)
    if frame.TickMark and continuousResource == "MANA" and TICK_ALPHA_CURVE and CanUseUnitPowerPercent then
        frame.TickMark:SetAlpha(UnitPowerPercent("player", Enum.PowerType.Mana, false, TICK_ALPHA_CURVE))
    end
    local curveData = plugin:GetSetting(systemIndex, curveKey)
    if not curveData then return end
    -- MANA: use UnitPowerPercent + native ColorCurve (fully secret-safe)
    if continuousResource == "MANA" then
        local nativeCurve = OrbitEngine.ColorCurve:ToNativeColorCurve(curveData)
        if nativeCurve and CanUseUnitPowerPercent then
            local color = UnitPowerPercent("player", Enum.PowerType.Mana, false, nativeCurve)
            if color then frame.StatusBar:GetStatusBarTexture():SetVertexColor(color:GetRGBA()); return end
        end
    end
    if issecretvalue and (issecretvalue(current) or issecretvalue(max)) then return end
    local progress = (max > 0) and (current / max) or 0
    local color = OrbitEngine.ColorCurve:SampleColorCurve(curveData, progress)
    if color then frame.StatusBar:SetStatusBarColor(color.r, color.g, color.b) end
end

-- [ CONTINUOUS SPACERS ]--------------------------------------------------------------------------
function Renderer:UpdateSpacers(plugin, frame, cfg, max)
    if not frame or not frame.StatusBar then return end
    if not cfg.dividers or max <= 1 then
        if frame.Spacers then for _, s in ipairs(frame.Spacers) do s:Hide() end end
        return
    end
    -- Lazy-create spacers (UpdateMaxPower is never called for continuous resources)
    frame.Spacers = frame.Spacers or {}
    for i = 1, MAX_SPACER_COUNT do
        if not frame.Spacers[i] then
            frame.Spacers[i] = frame.StatusBar:CreateTexture(nil, "OVERLAY", nil, 7)
            frame.Spacers[i]:SetColorTexture(0, 0, 0, 1)
        end
    end
    plugin:RepositionSpacers(max)
end

-- [ UPDATE POWER (CONTINUOUS PATH) ]---------------------------------------------------------------
function Renderer:UpdatePower(plugin, frame, systemIndex, textEnabled)
    local cfg = self.CONFIG[plugin.continuousResource]
    if not cfg then return end
    local current, max, extra1, extra2 = cfg.getState()
    if current and max then
        self:UpdateBar(plugin, frame, systemIndex, cfg.curveKey, current, max, plugin.continuousResource)
        self:UpdateSpacers(plugin, frame, cfg, max)
        if frame.Text and textEnabled then cfg.updateText(frame.Text, current, max, extra1, extra2) end
    elseif frame.StatusBar then
        frame.StatusBar:SetValue(0)
    end
end
