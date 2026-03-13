---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

local LibCustomGlow = LibStub("LibCustomGlow-1.0", true)

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

-- [ BLIZZARD VIEWER HOOKING ]-----------------------------------------------------------------------
function CDM:HookBlizzardViewers()
    for _, entry in pairs(VIEWER_MAP) do
        self:SetupViewerHooks(entry.viewer, entry.anchor)
    end

    if EventRegistry then
        EventRegistry:RegisterCallback("EditMode.Exit", function() self:ReapplyParentage() end, self)
    end

    self:HookProcGlow()
    self:MonitorViewers()
end

-- [ VIEWER HOOKS ]----------------------------------------------------------------------------------
function CDM:SetupViewerHooks(viewer, anchor)
    if not viewer or not anchor then return end

    if viewer.Selection then
        viewer.Selection:Hide()
        viewer.Selection:SetScript("OnShow", function(s) s:Hide() end)
    end

    local LayoutHandler = function()
        if viewer._orbitResizing then return end
        self:ProcessChildren(anchor)
    end
    if viewer.UpdateLayout then hooksecurefunc(viewer, "UpdateLayout", LayoutHandler) end
    if viewer.RefreshLayout then hooksecurefunc(viewer, "RefreshLayout", LayoutHandler) end

    local function RestoreViewer(v, parent)
        if not v or not parent or not anchor:IsShown() then return end
        v:ClearAllPoints()
        local point = GetViewerAnchorPoint(self, anchor)
        v:SetPoint(point, parent, point, 0, 0)
        v:SetAlpha(1)
        v:Show()
    end
    OrbitEngine.Frame:Protect(viewer, anchor, RestoreViewer, { enforceShow = true })

    if not viewer.orbitAlphaHooked then
        hooksecurefunc(viewer, "SetAlpha", function(s, alpha)
            if s._orbitSettingAlpha or (anchor and not anchor:IsShown()) then return end
            if alpha < 0.1 then s._orbitSettingAlpha = true; s:SetAlpha(1); s._orbitSettingAlpha = false end
        end)
        viewer.orbitAlphaHooked = true
    end

    if not viewer.orbitPosHooked then
        local function ReAnchor()
            if viewer._orbitRestoringPos or (anchor and not anchor:IsShown()) then return end
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
            if s._orbitRestoringVis or (anchor and not anchor:IsShown()) then return end
            -- Defer to break taint chain — synchronous Show() taints GetTotemInfo() returns
            C_Timer.After(0, function()
                if not s or not anchor or not anchor:IsShown() then return end
                s._orbitRestoringVis = true; s:Show(); s:SetAlpha(1); s._orbitRestoringVis = false
            end)
        end)
        viewer.orbitHideHooked = true
    end

    self:EnforceViewerParentage(viewer, anchor)
end

-- [ PARENTAGE MANAGEMENT ]--------------------------------------------------------------------------
function CDM:ReapplyParentage()
    for _, entry in pairs(VIEWER_MAP) do
        self:EnforceViewerParentage(entry.viewer, entry.anchor)
    end
end

function CDM:EnforceViewerParentage(viewer, anchor)
    if not viewer or not anchor then return end
    if InCombatLockdown() then return end
    if viewer:GetParent() ~= anchor then viewer:SetParent(anchor) end
    viewer:SetScale(1)
    viewer:ClearAllPoints()
    local point = GetViewerAnchorPoint(self, anchor)
    viewer:SetPoint(point, anchor, point, 0, 0)
    viewer:SetAlpha(1)
    viewer:Show()
    self:ProcessChildren(anchor)
end

-- [ EVENT-DRIVEN MONITOR ]--------------------------------------------------------------------------
local PANDEMIC_TICK = 0.25
local OOC_THROTTLE_DELAY = 20
local OOC_THROTTLE_INTERVAL = 0.5

function CDM:MonitorViewers()
    if self._monitorEventSetup then return end
    self._monitorEventSetup = true
    local plugin = self
    local inCombat = false
    local oocThrottled = false
    local oocNextUpdate = 0
    local oocDirty = false

    local function CheckAll()
        for _, entry in pairs(VIEWER_MAP) do
            plugin:CheckViewer(entry.viewer, entry.anchor)
        end
    end

    local function CheckPandemicAll()
        if not LibCustomGlow then return end
        for si, entry in pairs(VIEWER_MAP) do
            if entry.viewer then plugin:CheckPandemicFrames(entry.viewer, si) end
        end
    end

    local function StartPandemicTicker()
        if plugin._pandemicTicker or not LibCustomGlow then return end
        plugin._pandemicTicker = C_Timer.NewTicker(PANDEMIC_TICK, function()
            for systemIndex, entry in pairs(VIEWER_MAP) do
                if entry.viewer then plugin:CheckPandemicFrames(entry.viewer, systemIndex) end
            end
        end)
    end

    local function StopPandemicTicker()
        if not plugin._pandemicTicker then return end
        plugin._pandemicTicker:Cancel()
        plugin._pandemicTicker = nil
        if LibCustomGlow then
            for systemIndex, entry in pairs(VIEWER_MAP) do
                if entry.viewer then plugin:CheckPandemicFrames(entry.viewer, systemIndex) end
            end
        end
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UNIT_AURA")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
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
                CheckPandemicAll()
            end
            return
        end
        inCombat = (event == "PLAYER_REGEN_DISABLED")
        if inCombat then
            oocThrottled = false
            oocDirty = false
            if plugin._oocThrottleTimer then plugin._oocThrottleTimer:Cancel(); plugin._oocThrottleTimer = nil end
            StartPandemicTicker()
        else
            StopPandemicTicker()
            plugin._oocThrottleTimer = C_Timer.NewTimer(OOC_THROTTLE_DELAY, function()
                oocThrottled = true
                oocNextUpdate = 0
                plugin._oocThrottleTimer = nil
            end)
        end
        CheckAll()
        if not inCombat then plugin:PreSizeAnchors() end
    end)
    local pandemicAccum = 0
    local PANDEMIC_OOC_INTERVAL = 1
    local PANDEMIC_OOC_THROTTLED_INTERVAL = 5
    frame:SetScript("OnUpdate", function(_, elapsed)
        -- OOC throttle flush
        if oocThrottled and oocDirty then
            local now = GetTime()
            if now >= oocNextUpdate then
                oocNextUpdate = now + OOC_THROTTLE_INTERVAL
                oocDirty = false
                CheckAll()
                CheckPandemicAll()
            end
        end
        -- OOC pandemic poll: 1s normally, 5s when throttled
        if not inCombat then
            pandemicAccum = pandemicAccum + elapsed
            local interval = oocThrottled and PANDEMIC_OOC_THROTTLED_INTERVAL or PANDEMIC_OOC_INTERVAL
            if pandemicAccum >= interval then
                pandemicAccum = 0
                CheckPandemicAll()
            end
        else
            pandemicAccum = 0
        end
    end)
    self._monitorEventFrame = frame
end

function CDM:CheckViewer(viewer, anchor)
    if not viewer or not anchor then return end
    if InCombatLockdown() then return end
    if viewer:GetParent() ~= anchor then self:EnforceViewerParentage(viewer, anchor); return end
    local _, _, relativeTo = viewer:GetPoint(1)
    if relativeTo ~= anchor then self:EnforceViewerParentage(viewer, anchor); return end
    if not viewer:IsShown() then viewer:Show(); viewer:SetAlpha(1) end

    local count = 0
    for _, child in ipairs(PackChildren(viewer:GetChildren())) do
        if child:IsShown() then count = count + 1 end
    end
    if count ~= (viewer.orbitLastCount or 0) then
        viewer.orbitLastCount = count
        self:ProcessChildren(anchor)
    end
end

-- [ PLAYER ENTERING WORLD ]-------------------------------------------------------------------------
function CDM:OnPlayerEnteringWorld()
    C_Timer.After(Constants.Timing.RetryShort, function() self:ReapplyParentage(); self:ApplyAll() end)
    C_Timer.After(Constants.Timing.RetryLong, function() self:ReapplyParentage(); self:PreSizeAnchors() end)
end
