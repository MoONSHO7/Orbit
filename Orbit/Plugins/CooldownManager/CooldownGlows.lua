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
    return ESSENTIAL_INDEX
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
        if button.SpellActivationAlert then
            button.SpellActivationAlert:SetAlpha(0)
        end
        if button.orbitProcGlowActive then
            return
        end
        local si = FindSystemIndexForButton(button)
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
local PANDEMIC_ATLAS = "UI-CooldownManager-PandemicBorder"
local PANDEMIC_INSET = Constants.IconScale.PandemicPadding / 2
local BLIZZARD_GLOW_LEVEL = Constants.Levels.IconGlow

local function EnsureBlizzardGlowFrame(icon)
    if icon.orbitBlizzardGlow then return icon.orbitBlizzardGlow end
    local f = CreateFrame("Frame", nil, icon)
    f:SetFrameLevel(icon:GetFrameLevel() + BLIZZARD_GLOW_LEVEL)
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas(PANDEMIC_ATLAS)
    tex:SetAllPoints(f)
    f.tex = tex
    f:Hide()
    icon.orbitBlizzardGlow = f
    return f
end

-- Forward declaration; defined after helpers
local HookPandemicIcon

-- [ PANDEMIC GLOW FRAME HELPERS ] ---------------------------------------------
local function GetPandemicGlowFrame(icon, glowType)
    local GlowType = Constants.Glow.Type
    if glowType == GlowType.Blizzard then return icon.orbitBlizzardGlow
    elseif glowType == GlowType.Pixel then return icon["_PixelGloworbitPandemic"]
    elseif glowType == GlowType.Proc then return icon["_LibGlowFlipbookorbitPandemic"]
    elseif glowType == GlowType.Autocast then return icon["_LibGlowAutocastorbitPandemic"]
    elseif glowType == GlowType.Button then return icon["_LibGlowButton"]
    end
end

local function CreatePandemicGlow(icon, plugin, systemIndex)
    local typeName, options = Orbit.Engine.GlowUtils:BuildOptions(plugin, systemIndex, "PandemicGlow", Constants.Glow.DefaultColor, "orbitPandemic")
    if not typeName or not options then return end
    
    if options._glowTypeEnum == Constants.Glow.Type.Blizzard then
        local glow = EnsureBlizzardGlowFrame(icon)
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", icon, "TOPLEFT", -PANDEMIC_INSET, PANDEMIC_INSET)
        glow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", PANDEMIC_INSET, -PANDEMIC_INSET)
        glow:Show()
    else
        options.frameLevel = icon:GetFrameLevel() + BLIZZARD_GLOW_LEVEL
        LCG.Show(icon, typeName, options)
    end
end

local function GetGlowTypeName(activeType)
    local GlowType = Constants.Glow.Type
    if activeType == GlowType.Pixel then return "Pixel"
    elseif activeType == GlowType.Proc then return "Thin" -- Note: Proc uses Thin flipbook internally in LibOrbitGlow
    elseif activeType == GlowType.Autocast then return "Autocast"
    elseif activeType == GlowType.Classic then return "Classic"
    elseif activeType == GlowType.Medium then return "Medium"
    end
end

-- Full teardown: actually destroy glow (settings changes / cleanup only)
local function StopPandemicGlowFull(icon)
    local activeType = icon.orbitPandemicGlowActive
    if not activeType then return end
    icon.orbitSuppressPandemic = nil
    icon.orbitPandemicClearAt = nil
    icon.orbitPandemicGlowHidden = nil
    
    if activeType == Constants.Glow.Type.Blizzard then
        if icon.orbitBlizzardGlow then icon.orbitBlizzardGlow:Hide() end
    else
        local typeName = GetGlowTypeName(activeType)
        if typeName then LCG.Hide(icon, typeName, "orbitPandemic") end
    end
    icon.orbitPandemicGlowActive = nil
end

-- [ HOOK-DRIVEN PANDEMIC GLOW ] -----------------------------------------------
HookPandemicIcon = function(icon, plugin, systemIndex)
    if icon.orbitPandemicHooked then return end
    icon.orbitPandemicHooked = true
    
    local GlowType = Constants.Glow.Type
    
    local function SuppressPandemicIcon(self)
        local pi = self.PandemicIcon
        if pi and self.orbitSuppressPandemic then pi:SetAlpha(0) end
    end
    
    local function OnPandemicShow(self)
        local glowType = plugin:GetSetting(systemIndex, "PandemicGlowType") or GlowType.None
        if glowType == GlowType.None then return end
        
        local activeType = self.orbitPandemicGlowActive
        if activeType and activeType ~= glowType then StopPandemicGlowFull(self) end
        
        self.orbitSuppressPandemic = true
        SuppressPandemicIcon(self)
        CreatePandemicGlow(self, plugin, systemIndex)
        self.orbitPandemicGlowActive = glowType
    end
    
    local function OnPandemicHide(self)
        StopPandemicGlowFull(self)
    end
    
    hooksecurefunc(icon, "Hide", function(self)
        OnPandemicHide(self)
    end)
    
    if icon.ShowPandemicStateFrame then
        hooksecurefunc(icon, "ShowPandemicStateFrame", function(self)
            SuppressPandemicIcon(self)
            OnPandemicShow(self)
        end)
    end
    
    if icon.HidePandemicStateFrame then
        hooksecurefunc(icon, "HidePandemicStateFrame", function(self)
            OnPandemicHide(self)
        end)
    end
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
        
        local activeType = icon.orbitPandemicGlowActive
        
        -- Native sync resolution incase the item is organically out of pandemic but our logic missed the exit window
        local isPandemic = icon.PandemicIcon and icon.PandemicIcon:IsShown()
        
        -- Full structural teardown uniquely reserved for explicitly disabling the feature via settings
        if glowType == GlowType.None and activeType then
            StopPandemicGlowFull(icon)
            if icon.PandemicIcon then
                icon.orbitSuppressPandemic = nil
                icon.PandemicIcon:SetAlpha(1)
            end
        elseif activeType and activeType ~= glowType then
            -- Live settings swap
            StopPandemicGlowFull(icon)
            if isPandemic and glowType ~= GlowType.None then
                CreatePandemicGlow(icon, self, systemIndex)
                icon.orbitPandemicGlowActive = glowType
            end
        elseif not isPandemic and activeType then
            -- Fallback verification 
            StopPandemicGlowFull(icon)
        elseif isPandemic and not activeType and glowType ~= GlowType.None then
            -- Re-hydration if missing
            icon.orbitSuppressPandemic = true
            if icon.PandemicIcon then icon.PandemicIcon:SetAlpha(0) end
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
