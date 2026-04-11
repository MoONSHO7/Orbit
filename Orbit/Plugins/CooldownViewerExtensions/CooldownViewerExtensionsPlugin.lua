-- [ ORBIT COOLDOWN VIEWER EXTENSIONS ] ----------------------------------------
-- Lightweight plugin that adds extra side tabs to Blizzard's CooldownViewerSettings
-- frame. Other plugins (Tracked, future plugins) call RegisterTab to add a tab —
-- this plugin owns the ADDON_LOADED hook, the anchor chain below AurasTab, and
-- the click dispatch. Tabs here are click buttons; they do NOT switch the panel's
-- displayMode (the parent frame's content stays as-is). Their click handler runs
-- whatever the registering plugin asked for (e.g. spawn a new container).
local _, Orbit = ...

-- [ CONSTANTS ] ---------------------------------------------------------------
local TAB_TEMPLATE = "CooldownViewerSettingsTabTemplate"
local TAB_GAP_Y = -3
local TARGET_ADDON = "Blizzard_CooldownViewer"
-- The mixin's SetChecked re-applies the atlas with UseAtlasSize=true, so any
-- atlas larger than the native cooldown viewer icons (icon_cooldownmanager,
-- icon_trackedbuffs) overflows the 43x55 tab. We force a fixed icon size and
-- reapply on every SetChecked via hooksecurefunc.
local TAB_ICON_SIZE = 28

-- [ PLUGIN REGISTRATION ] -----------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Cooldown Viewer Extensions", "Orbit_CooldownViewerExtensions", {
    liveToggle = false,
    pendingTabs = {},
    builtTabs = {},
    OnLoad = function(self)
        self:HookCooldownViewer()
    end,
})

-- [ HOOK BLIZZARD COOLDOWN VIEWER ] -------------------------------------------
function Plugin:HookCooldownViewer()
    if self:IsSettingsFrameReady() then
        self:BuildPendingTabs()
        return
    end
    if self._hookFrame then return end
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, _, addonName)
        if addonName ~= TARGET_ADDON then return end
        if not self:IsSettingsFrameReady() then return end
        self:BuildPendingTabs()
        f:UnregisterEvent("ADDON_LOADED")
    end)
    self._hookFrame = f
end

function Plugin:IsSettingsFrameReady()
    return CooldownViewerSettings ~= nil and CooldownViewerSettings.AurasTab ~= nil
end

-- [ PUBLIC API ] --------------------------------------------------------------
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

-- [ TAB BUILDING ] ------------------------------------------------------------
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
    local tab = CreateFrame("CheckButton", nil, parent, TAB_TEMPLATE)
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

    tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
        if button == "LeftButton" and upInside and spec.onClick then
            spec.onClick(tab)
        end
        tab:SetChecked(false)
    end)

    tab:SetChecked(false)
    tab:Show()
    return tab
end

-- [ TAB LOOKUP ] --------------------------------------------------------------
function Plugin:GetTab(id)
    return self.builtTabs[id]
end
