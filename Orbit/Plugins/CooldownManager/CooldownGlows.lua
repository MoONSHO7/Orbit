---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants

local LCG = LibStub("LibOrbitGlow-1.0", true)
if not LCG then
    return
end

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then
    return
end

local ESSENTIAL_INDEX = Constants.Cooldown.SystemIndex.Essential
local UTILITY_INDEX = Constants.Cooldown.SystemIndex.Utility
local BUFFICON_INDEX = Constants.Cooldown.SystemIndex.BuffIcon
local PANDEMIC_CLEAR_DEBOUNCE = 0.3

-- [ PROC GLOW HOOKS ] ---------------------------------------------------------
local PROC_GLOW_KEY = "orbitProc"

local function FindSystemIndexForButton(button)
    if button.orbitCDMSystemIndex then
        return button.orbitCDMSystemIndex
    end
    for systemIndex, data in pairs(CDM.viewerMap) do
        if data.viewer and data.viewer.GetItemFrames then
            for _, icon in ipairs(data.viewer:GetItemFrames()) do
                if icon == button then
                    return systemIndex
                end
            end
        end
    end
    return nil
end

local function StartProcGlow(button, plugin, systemIndex)
    local typeName, options = Orbit.Engine.GlowUtils:BuildOptions(plugin, systemIndex, "ProcGlow", Constants.Glow.DefaultColor, PROC_GLOW_KEY)
    if typeName and options then
        options.frameLevel = Constants.Levels.IconGlow
        LCG.Show(button, typeName, options)
    end
end

local function StopProcGlow(button, activeTypeName)
    if activeTypeName then
        LCG.Hide(button, activeTypeName, PROC_GLOW_KEY)
    end
end

function CDM:HookProcGlow()
    if self.procGlowHooked or not ActionButtonSpellAlertManager then
        return
    end

    hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button)
        if button.orbitProcGlowActive then
            return
        end
        local si = FindSystemIndexForButton(button)
        if not si then return end
        if button.SpellActivationAlert then
            button.SpellActivationAlert:SetAlpha(0)
        end
        local typeName = Orbit.Engine.GlowUtils:BuildOptions(self, si, "ProcGlow", Constants.Glow.DefaultColor, PROC_GLOW_KEY)
        if not typeName then return end
        StartProcGlow(button, self, si)
        button.orbitProcGlowActive = typeName
    end)

    hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", function(_, button)
        if not button.orbitProcGlowActive then
            return
        end
        StopProcGlow(button, button.orbitProcGlowActive)
        button.orbitProcGlowActive = nil
    end)

    self.procGlowHooked = true
end

-- [ GLOW TRANSPARENCY FIX ] ---------------------------------------------------
function CDM:FixGlowTransparency(glowFrame, alpha)
    if not glowFrame or not alpha then
        return
    end
    if glowFrame.ProcLoopAnim and glowFrame.ProcLoopAnim.alphaRepeat then
        glowFrame.ProcLoopAnim.alphaRepeat:SetFromAlpha(alpha)
        glowFrame.ProcLoopAnim.alphaRepeat:SetToAlpha(alpha)
    end
    if glowFrame.ProcStartAnim then
        for _, anim in pairs({ glowFrame.ProcStartAnim:GetAnimations() }) do
            if anim:GetObjectType() == "Alpha" then
                local order = anim:GetOrder()
                if order == 0 then
                    anim:SetFromAlpha(alpha)
                    anim:SetToAlpha(alpha)
                elseif order == 2 then
                    anim:SetFromAlpha(alpha)
                end
            end
        end
    end
end

-- [ PANDEMIC GLOW ] -----------------------------------------------------------
local GLOW_LEVEL = Constants.Levels.IconGlow

-- Forward declaration; defined after helpers
local HookPandemicIcon

-- [ PANDEMIC GLOW FRAME HELPERS ] ---------------------------------------------
local function GetPandemicGlowFrame(icon, glowType)
    local GlowType = Constants.Glow.Type
    if glowType == GlowType.Pixel then return icon["_PixelGloworbitPandemic"]
    elseif glowType == GlowType.Medium then return icon["_LibGlowFlipbookorbitPandemic"]
    elseif glowType == GlowType.Thin then return icon["_LibGlowFlipbookorbitPandemic"]
    elseif glowType == GlowType.Thick then return icon["_LibGlowFlipbookorbitPandemic"]
    elseif glowType == GlowType.Autocast then return icon["_LibGlowAutocastorbitPandemic"]
    elseif glowType == GlowType.Classic then return icon["_LibGlowButtonorbitPandemic"]
    end
end

local function CreatePandemicGlow(icon, plugin, systemIndex)
    local typeName, options = Orbit.Engine.GlowUtils:BuildOptions(plugin, systemIndex, "PandemicGlow", Constants.Glow.DefaultColor, "orbitPandemic")
    if not typeName or not options then return end
    options.frameLevel = icon:GetFrameLevel() + GLOW_LEVEL
    LCG.Show(icon, typeName, options)
end

local function GetGlowTypeName(activeType)
    local GlowType = Constants.Glow.Type
    if activeType == GlowType.Pixel then return "Pixel"
    elseif activeType == GlowType.Medium then return "Medium"
    elseif activeType == GlowType.Autocast then return "Autocast"
    elseif activeType == GlowType.Classic then return "Classic"
    elseif activeType == GlowType.Thin then return "Thin"
    elseif activeType == GlowType.Thick then return "Thick"
    end
end

-- Alpha-toggle: show glow without pool churn
local function ShowPandemicGlow(icon, glowType)
    local glowFrame = GetPandemicGlowFrame(icon, glowType)
    if not glowFrame then return end
    glowFrame:SetAlpha(1)
end

-- Alpha-toggle: hide glow without pool churn
local function HidePandemicGlow(icon, glowType)
    local glowFrame = GetPandemicGlowFrame(icon, glowType)
    if not glowFrame then return end
    glowFrame:SetAlpha(0)
end

-- Full teardown: actually destroy glow (settings changes / icon pooling only)
local function StopPandemicGlowFull(icon)
    local activeType = icon.orbitPandemicGlowActive
    if not activeType then return end
    icon.orbitSuppressPandemic = nil
    icon.orbitPandemicClearAt = nil
    icon.orbitPandemicGlowHidden = nil
    local typeName = GetGlowTypeName(activeType)
    if typeName then LCG.Hide(icon, typeName, "orbitPandemic") end
    icon.orbitPandemicGlowActive = nil
end

-- [ HOOK-DRIVEN PANDEMIC GLOW ] -----------------------------------------------
HookPandemicIcon = function(icon, plugin, systemIndex)
    if icon.orbitPandemicHooked then return end
    if not icon.ShowPandemicStateFrame then return end
    icon.orbitPandemicHooked = true
    local GlowType = Constants.Glow.Type
    -- Suppress Blizzard's PandemicIcon alpha whenever it's shown
    local function SuppressPandemicIcon(self)
        local pi = self.PandemicIcon
        if pi and self.orbitSuppressPandemic then pi:SetAlpha(0) end
    end
    local function OnPandemicShow(self)
        local glowType = plugin:GetSetting(systemIndex, "PandemicGlowType") or GlowType.None
        if glowType == GlowType.None then return end
        local activeType = self.orbitPandemicGlowActive
        if activeType and activeType ~= glowType then StopPandemicGlowFull(self); activeType = nil end
        if not activeType then
            -- First time: create the glow
            self.orbitSuppressPandemic = true
            SuppressPandemicIcon(self)
            CreatePandemicGlow(self, plugin, systemIndex)
            self.orbitPandemicGlowActive = glowType
        elseif self.orbitPandemicGlowHidden then
            -- Glow exists but was alpha-hidden: just show it
            self.orbitSuppressPandemic = true
            SuppressPandemicIcon(self)
            ShowPandemicGlow(self, activeType)
            self.orbitPandemicGlowHidden = nil
        else
            -- Glow exists and is visible: just suppress native icon
            self.orbitSuppressPandemic = true
            SuppressPandemicIcon(self)
        end
    end
    local function OnPandemicHide(self)
        -- Alpha-hide only, don't destroy the glow frame (avoids pool churn)
        if self.orbitPandemicGlowActive and not self.orbitPandemicGlowHidden then
            HidePandemicGlow(self, self.orbitPandemicGlowActive)
            self.orbitPandemicGlowHidden = true
            self.orbitSuppressPandemic = nil
        end
    end
    -- Hook the ITEM's methods, not the PandemicIcon frame (which gets pooled/recreated)
    hooksecurefunc(icon, "ShowPandemicStateFrame", function(self)
        SuppressPandemicIcon(self)
        OnPandemicShow(self)
    end)
    hooksecurefunc(icon, "HidePandemicStateFrame", function(self)
        OnPandemicHide(self)
    end)
    -- When the icon is fully hidden (pooled by CooldownViewer), do a full teardown
    hooksecurefunc(icon, "Hide", function(self)
        StopPandemicGlowFull(self)
    end)
end

-- CheckPandemicFrames: initial hookup + settings-change sync (hooks handle live state)
function CDM:CheckPandemicFrames(viewer, systemIndex)
    if not viewer then return end
    local icons = viewer.GetItemFrames and viewer:GetItemFrames()
    if not icons then return end
    local GlowType = Constants.Glow.Type
    local glowType = self:GetSetting(systemIndex, "PandemicGlowType") or GlowType.None
    for _, icon in ipairs(icons) do
        HookPandemicIcon(icon, self, systemIndex)
        -- Settings type change: teardown old glow, hooks will recreate on next Show
        local activeType = icon.orbitPandemicGlowActive
        if activeType and activeType ~= glowType then
            StopPandemicGlowFull(icon)
            -- If currently in pandemic, re-create with new type immediately
            if glowType ~= GlowType.None and icon.PandemicIcon and icon.PandemicIcon:IsShown() then
                icon.orbitSuppressPandemic = true
                icon.PandemicIcon:SetAlpha(0)
                CreatePandemicGlow(icon, self, systemIndex)
                icon.orbitPandemicGlowActive = glowType
            end
        end
        -- Initial state sync: if pandemic already active when first hooked
        if not icon.orbitPandemicGlowActive and glowType ~= GlowType.None and icon.PandemicIcon and icon.PandemicIcon:IsShown() then
            icon.orbitSuppressPandemic = true
            icon.PandemicIcon:SetAlpha(0)
            CreatePandemicGlow(icon, self, systemIndex)
            icon.orbitPandemicGlowActive = glowType
        end
    end
end

-- [ CLEAR ALL PANDEMIC GLOWS ] ------------------------------------------------
function CDM:ClearAllPandemicGlows()
    for _, entry in pairs(CDM.viewerMap) do
        if entry.viewer and entry.viewer.GetItemFrames then
            local icons = entry.viewer:GetItemFrames()
            if icons then
                for _, icon in ipairs(icons) do StopPandemicGlowFull(icon) end
            end
        end
    end
end
