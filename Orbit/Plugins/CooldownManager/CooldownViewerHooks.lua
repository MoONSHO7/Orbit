---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants


local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local VIEWER_MAP = CDM.viewerMap
local BUFFICON_INDEX = Constants.Cooldown.SystemIndex.BuffIcon
local BUFFBAR_INDEX = Constants.Cooldown.SystemIndex.BuffBar

local CooldownUtils = OrbitEngine.CooldownUtils
local PackChildren = function(...) return CooldownUtils:PackChildren(...) end

local function GetViewerAnchorPoint(plugin, anchor)
    local vPoint = (plugin:GetGrowthDirection(anchor) == "UP") and "BOTTOM" or "TOP"
    if anchor.systemIndex ~= BUFFICON_INDEX and anchor.systemIndex ~= BUFFBAR_INDEX then return vPoint end
    local hGrowth = plugin:GetHorizontalGrowth(anchor)
    if hGrowth == "LEFT" then return vPoint .. "RIGHT" end
    if hGrowth == "RIGHT" then return vPoint .. "LEFT" end
    return vPoint
end

-- [ BLIZZARD VIEWER HOOKING ] -----------------------------------------------------------------------
function CDM:HookBlizzardViewers()
    for _, entry in pairs(VIEWER_MAP) do
        self:SetupViewerHooks(entry.viewer, entry.anchor)
    end

    if EventRegistry then
        EventRegistry:RegisterCallback("EditMode.Exit", function() self:ReapplyParentage() end, self)
    end

    self:HookProcGlow()
    self:MonitorViewers()
    self:HookEssentialUtilityMixins()
end

-- [ ESSENTIAL/UTILITY MIXIN HOOKS ] -----------------------------------------------------------------
function CDM:HookEssentialUtilityMixins()
    local function OnSpellUpdate(frame, systemIndex)
        local viewer = frame:GetParent()
        local anchor = viewer and viewer:GetParent()
        if anchor and anchor.systemIndex == systemIndex then self:ProcessChildren(anchor) end
    end
    if CooldownViewerEssentialItemMixin then
        local ess = Constants.Cooldown.SystemIndex.Essential
        if CooldownViewerEssentialItemMixin.OnCooldownIDSet then
            hooksecurefunc(CooldownViewerEssentialItemMixin, "OnCooldownIDSet", function(f) OnSpellUpdate(f, ess) end)
        end
        if CooldownViewerEssentialItemMixin.OnActiveStateChanged then
            hooksecurefunc(CooldownViewerEssentialItemMixin, "OnActiveStateChanged", function(f) OnSpellUpdate(f, ess) end)
        end
    end
    if CooldownViewerUtilityItemMixin then
        local util = Constants.Cooldown.SystemIndex.Utility
        if CooldownViewerUtilityItemMixin.OnCooldownIDSet then
            hooksecurefunc(CooldownViewerUtilityItemMixin, "OnCooldownIDSet", function(f) OnSpellUpdate(f, util) end)
        end
        if CooldownViewerUtilityItemMixin.OnActiveStateChanged then
            hooksecurefunc(CooldownViewerUtilityItemMixin, "OnActiveStateChanged", function(f) OnSpellUpdate(f, util) end)
        end
    end
end

-- [ VIEWER HOOKS ] ----------------------------------------------------------------------------------
function CDM:SetupViewerHooks(viewer, anchor)
    if not viewer or not anchor then return end

    if viewer.Selection then
        viewer.Selection:Hide()
        viewer.Selection:SetScript("OnShow", function(s) s:Hide() end)
    end

    local LayoutHandler = function()
        if viewer._orbitResizing or anchor.orbitMountedSuppressed then return end
        self:ProcessChildren(anchor)
    end
    if viewer.UpdateLayout then hooksecurefunc(viewer, "UpdateLayout", LayoutHandler) end
    if viewer.RefreshLayout then hooksecurefunc(viewer, "RefreshLayout", LayoutHandler) end

    local function RestoreViewer(v, parent)
        if not v or not parent or not anchor:IsShown() or anchor.orbitMountedSuppressed then return end
        v:ClearAllPoints()
        local point = GetViewerAnchorPoint(self, anchor)
        v:SetPoint(point, parent, point, 0, 0)
        v:SetAlpha(1)
        v:Show()
    end
    OrbitEngine.Frame:Protect(viewer, anchor, RestoreViewer, { enforceShow = true })

    if not viewer.orbitAlphaHooked then
        hooksecurefunc(viewer, "SetAlpha", function(s, alpha)
            if s._orbitSettingAlpha or (anchor and (not anchor:IsShown() or anchor.orbitMountedSuppressed)) then return end
            if alpha < 0.1 then s._orbitSettingAlpha = true; s:SetAlpha(1); s._orbitSettingAlpha = false end
        end)
        viewer.orbitAlphaHooked = true
    end

    if not viewer.orbitPosHooked then
        local function ReAnchor()
            if viewer._orbitRestoringPos or (anchor and not anchor:IsShown()) then return end
            if InCombatLockdown() then return end
            viewer._orbitRestoringPos = true
            viewer:ClearAllPoints()
            local point = GetViewerAnchorPoint(self, anchor)
            viewer:SetPoint(point, anchor, point, 0, 0)
            viewer._orbitRestoringPos = false
        end
        hooksecurefunc(viewer, "SetPoint", ReAnchor)
        hooksecurefunc(viewer, "ClearAllPoints", ReAnchor)
        viewer.orbitPosHooked = true
    end

    if not viewer.orbitHideHooked then
        hooksecurefunc(viewer, "Hide", function(s)
            if s._orbitRestoringVis or (anchor and (not anchor:IsShown() or anchor.orbitMountedSuppressed)) then return end
            if InCombatLockdown() then return end
            s._orbitRestoringVis = true; s:Show(); s:SetAlpha(1); s._orbitRestoringVis = false
        end)
        viewer.orbitHideHooked = true
    end

    self:EnforceViewerParentage(viewer, anchor)
end

-- [ PARENTAGE MANAGEMENT ] --------------------------------------------------------------------------
function CDM:ReapplyParentage()
    for _, entry in pairs(VIEWER_MAP) do
        self:EnforceViewerParentage(entry.viewer, entry.anchor)
    end
end

function CDM:EnforceViewerParentage(viewer, anchor)
    if not viewer or not anchor then return end
    if anchor.orbitMountedSuppressed then return end
    -- Viewers are InCombatProtect; protected setters taint Orbit when blocked. PLAYER_REGEN_ENABLED retries via CheckAll.
    if InCombatLockdown() then return end
    if viewer:GetParent() ~= anchor then viewer:SetParent(anchor) end
    -- EditModeSystemMixin:SetScale always calls the protected SetScaleBase, even when scale is unchanged.
    if viewer:GetScale() ~= 1 then viewer:SetScale(1) end
    viewer:ClearAllPoints()
    local point = GetViewerAnchorPoint(self, anchor)
    viewer:SetPoint(point, anchor, point, 0, 0)
    viewer:SetAlpha(1)
    viewer:Show()
    self:ProcessChildren(anchor)
end

-- [ EVENT-DRIVEN MONITOR ] --------------------------------------------------------------------------
local OOC_THROTTLE_DELAY = 20
local OOC_THROTTLE_INTERVAL = 0.5

function CDM:MonitorViewers()
    if self._monitorEventSetup then return end
    self._monitorEventSetup = true
    local plugin = self
    local oocThrottled = false
    local oocNextUpdate = 0
    local oocDirty = false
    local pandemicDirty = true

    local function CheckAll()
        for _, entry in pairs(VIEWER_MAP) do
            plugin:CheckViewer(entry.viewer, entry.anchor)
        end
    end

    local function CheckPandemicAll()

        for si, entry in pairs(VIEWER_MAP) do
            if entry.viewer then plugin:CheckPandemicFrames(entry.viewer, si) end
        end
    end

    local function CheckPandemicIfDirty()
        if not pandemicDirty then return end
        pandemicDirty = false
        CheckPandemicAll()
    end

    function plugin:MarkPandemicDirty()
        pandemicDirty = true
    end

    local frame = CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_AURA", "player")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    local function OOCUpdate()
        if not (oocThrottled and oocDirty) then return end
        local now = GetTime()
        if now < oocNextUpdate then return end
        oocNextUpdate = now + OOC_THROTTLE_INTERVAL
        oocDirty = false
        local p = Orbit.Profiler
        local s = p and p:Begin()
        CheckAll()
        CheckPandemicIfDirty()
        if p then p:End(plugin, "OOCThrottle", s) end
    end

    frame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" then
            if unit == "player" then
                if oocThrottled then
                    local now = GetTime()
                    if now < oocNextUpdate then oocDirty = true; return end
                    oocNextUpdate = now + OOC_THROTTLE_INTERVAL
                    oocDirty = false
                end
                CheckAll()
                CheckPandemicIfDirty()
            end
            return
        end
        local inCombat = (event == "PLAYER_REGEN_DISABLED")
        if inCombat then
            oocThrottled = false
            oocDirty = false
            frame:SetScript("OnUpdate", nil)
            if plugin._oocThrottleTimer then plugin._oocThrottleTimer:Cancel(); plugin._oocThrottleTimer = nil end
        else
            plugin._oocThrottleTimer = C_Timer.NewTimer(OOC_THROTTLE_DELAY, function()
                oocThrottled = true
                oocNextUpdate = 0
                plugin._oocThrottleTimer = nil
                frame:SetScript("OnUpdate", OOCUpdate)
            end)
        end
        pandemicDirty = true
        CheckAll()
        CheckPandemicIfDirty()
        if not inCombat then plugin:PreSizeAnchors() end
    end)
    self._monitorEventFrame = frame
end

function CDM:CheckViewer(viewer, anchor)
    if not viewer or not anchor then return end
    if viewer:GetParent() ~= anchor then self:EnforceViewerParentage(viewer, anchor); return end
    local _, _, relativeTo = viewer:GetPoint(1)
    if relativeTo ~= anchor then self:EnforceViewerParentage(viewer, anchor); return end
    -- viewer:Show() is protected on InCombatProtect cooldown viewers; defer to PLAYER_REGEN_ENABLED to avoid taint.
    if not viewer:IsShown() and not anchor.orbitMountedSuppressed and not InCombatLockdown() then viewer:Show(); viewer:SetAlpha(1) end
end

-- [ PLAYER ENTERING WORLD ] -------------------------------------------------------------------------
function CDM:OnPlayerEnteringWorld()
    C_Timer.After(Constants.Timing.RetryShort, function() self:ReapplyParentage(); self:ApplyAll() end)
    C_Timer.After(Constants.Timing.RetryLong, function() self:ReapplyParentage(); self:PreSizeAnchors() end)
end
