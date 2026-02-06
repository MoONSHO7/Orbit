---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

local LibCustomGlow = LibStub("LibCustomGlow-1.0", true)

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local VIEWER_MAP = CDM.viewerMap

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
        local point = (self:GetGrowthDirection(anchor) == "UP") and "BOTTOM" or "TOP"
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
            local point = (self:GetGrowthDirection(anchor) == "UP") and "BOTTOM" or "TOP"
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
            s._orbitRestoringVis = true; s:Show(); s:SetAlpha(1); s._orbitRestoringVis = false
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
    if viewer:GetParent() ~= anchor then viewer:SetParent(anchor) end
    viewer:SetScale(1)
    viewer:ClearAllPoints()
    local point = (self:GetGrowthDirection(anchor) == "UP") and "BOTTOM" or "TOP"
    viewer:SetPoint(point, anchor, point, 0, 0)
    viewer:SetAlpha(1)
    viewer:Show()
    self:ProcessChildren(anchor)
end

-- [ MONITOR TICKER ]--------------------------------------------------------------------------------
function CDM:MonitorViewers()
    if self.monitorTicker then self.monitorTicker:Cancel() end
    local plugin = self
    self.monitorTicker = C_Timer.NewTicker(Constants.Timing.LayoutMonitorInterval, function()
        for systemIndex, entry in pairs(VIEWER_MAP) do
            plugin:CheckViewer(entry.viewer, entry.anchor)
            if LibCustomGlow then plugin:CheckPandemicFrames(entry.viewer, systemIndex) end
        end
    end)
end

function CDM:CheckViewer(viewer, anchor)
    if not viewer or not anchor then return end
    if viewer:GetParent() ~= anchor then self:EnforceViewerParentage(viewer, anchor); return end
    if not viewer:IsShown() then viewer:Show(); viewer:SetAlpha(1) end

    local count = 0
    for _, child in ipairs({ viewer:GetChildren() }) do
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
    C_Timer.After(Constants.Timing.RetryLong, function() self:ReapplyParentage() end)
end
