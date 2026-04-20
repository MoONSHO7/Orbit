-- [ ORBIT COOLDOWN VIEWER EXTENSIONS ] --------------------------------------------------------------
local _, Orbit = ...

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local TAB_TEMPLATE = "CooldownViewerSettingsTabTemplate"
local TAB_GAP_Y = -3
local TARGET_ADDON = "Blizzard_CooldownViewer"
-- Fixed icon size + SetChecked re-apply: the mixin's SetChecked re-applies the atlas with UseAtlasSize=true, overflowing the 43x55 tab for atlases larger than the native cooldown viewer icons.
local TAB_ICON_SIZE = 28

-- [ PLUGIN REGISTRATION ] ---------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Cooldown Viewer Extensions", "Orbit_CooldownViewerExtensions", {
    liveToggle = false,
    pendingTabs = {},
    builtTabs = {},
    OnLoad = function(self)
        self:HookCooldownViewer()
    end,
})

-- [ HOOK BLIZZARD COOLDOWN VIEWER ] -----------------------------------------------------------------
function Plugin:HookCooldownViewer()
    if self:IsSettingsFrameReady() then
        self:BuildPendingTabs()
        if Orbit.CooldownSettingsDragBridge then Orbit.CooldownSettingsDragBridge:Install() end
        return
    end
    if self._hookFrame then return end
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, _, addonName)
        if addonName ~= TARGET_ADDON then return end
        if not self:IsSettingsFrameReady() then return end
        self:BuildPendingTabs()
        if Orbit.CooldownSettingsDragBridge then Orbit.CooldownSettingsDragBridge:Install() end
        f:UnregisterEvent("ADDON_LOADED")
    end)
    self._hookFrame = f
end

function Plugin:IsSettingsFrameReady()
    return CooldownViewerSettings ~= nil and CooldownViewerSettings.AurasTab ~= nil
end

-- [ PUBLIC API ] ------------------------------------------------------------------------------------
-- spec = {
--     id          = string  (unique key, e.g. "Orbit_Tracked.Icons")
--     atlas       = string  (atlas name shown on the tab face)
--     tooltipText = string  (free-form tooltip body)
--     onClick     = function(tabFrame)  called on left-click
--     vertexColor = { r, g, b }  (optional — desaturates the atlas and tints
--                                 it. Used by Tracked Icons/Bars to match the
--                                 dropzone colors.)
-- }
function Plugin:RegisterTab(spec)
    if type(spec) ~= "table" or not spec.id then return end
    if self.builtTabs[spec.id] then return end
    for _, existing in ipairs(self.pendingTabs) do
        if existing.id == spec.id then return end
    end
    table.insert(self.pendingTabs, spec)
    if self:IsSettingsFrameReady() then
        self:BuildPendingTabs()
    end
end

-- [ TAB BUILDING ] ----------------------------------------------------------------------------------
-- Each new extension tab anchors below the previously built one (or AurasTab
-- for the first). `_lastBuiltTab` is the running tail of the chain so a second
-- RegisterTab call after the first batch already flushed still anchors below
-- the existing tabs instead of stacking on top of AurasTab. Tracked hits this
-- path because it registers Icons and Bars in two separate RegisterTab calls,
-- and if the settings frame is already open the first call flushes pendingTabs
-- before the second call is even made.
function Plugin:BuildPendingTabs()
    local parent = CooldownViewerSettings
    if not parent then return end
    local anchorTo = self._lastBuiltTab or CooldownViewerSettings.AurasTab

    -- HookScript (script callback, not a method hook) — doesn't taint the panel's attribute chain.
    if not self._panelVisHooked then
        self._panelVisHooked = true
        local plugin = self
        parent:HookScript("OnShow", function() for _, t in pairs(plugin.builtTabs) do t:Show() end end)
        parent:HookScript("OnHide", function() for _, t in pairs(plugin.builtTabs) do t:Hide() end end)
    end

    for _, spec in ipairs(self.pendingTabs) do
        if not self.builtTabs[spec.id] then
            local tab = self:CreateTab(parent, spec, anchorTo)
            if tab then
                self.builtTabs[spec.id] = tab
                self._lastBuiltTab = tab
                anchorTo = tab
            end
        end
    end
    self.pendingTabs = {}
end

local function NormalizeOrbitTabIcon(tab)
    if not tab.activeAtlas then return end
    tab.Icon:SetAtlas(tab.activeAtlas, false)
    tab.Icon:SetSize(TAB_ICON_SIZE, TAB_ICON_SIZE)
    -- The mixin's SetChecked re-applies the atlas which resets desaturation
    -- and vertex color, so we have to reapply our tint on every state change.
    if tab.vertexColor then
        tab.Icon:SetDesaturated(true)
        tab.Icon:SetVertexColor(tab.vertexColor.r, tab.vertexColor.g, tab.vertexColor.b)
    end
end

function Plugin:CreateTab(parent, spec, anchorTo)
    -- Parented to UIParent so per-tab hooks can't cascade taint into the settings panel.
    local tab = CreateFrame("CheckButton", nil, UIParent, TAB_TEMPLATE)
    tab:SetFrameStrata(parent:GetFrameStrata())
    tab:SetFrameLevel(parent:GetFrameLevel() + 10)
    tab.activeAtlas = spec.atlas
    tab.inactiveAtlas = spec.atlas
    tab.vertexColor = spec.vertexColor
    tab.tooltipText = spec.tooltipText
    tab.orbitTabId = spec.id

    tab:ClearAllPoints()
    tab:SetPoint("TOP", anchorTo, "BOTTOM", 0, TAB_GAP_Y)

    -- The mixin's SetChecked applies activeAtlas/inactiveAtlas with UseAtlasSize.
    -- Hook it to renormalize back to a fixed size after every state change.
    hooksecurefunc(tab, "SetChecked", NormalizeOrbitTabIcon)

    -- Defer onClick out of Blizzard's secure click dispatch so the spawn chain can't propagate taint.
    tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
        if button == "LeftButton" and upInside and spec.onClick then
            C_Timer.After(0, function() spec.onClick(tab) end)
        end
        tab:SetChecked(false)
    end)

    tab:SetChecked(false)
    if parent:IsShown() then tab:Show() else tab:Hide() end
    return tab
end

-- [ TAB LOOKUP ] ------------------------------------------------------------------------------------
function Plugin:GetTab(id)
    return self.builtTabs[id]
end
