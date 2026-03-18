---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants

local LibCustomGlow = LibStub("LibCustomGlow-1.0", true)
if not LibCustomGlow then
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

-- [ PROC GLOW HOOKS ]-------------------------------------------------------------------------------
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

local function StartProcGlow(button, glowType, colorTable)
    local GlowType = Constants.PandemicGlow.Type
    local GlowConfig = Constants.PandemicGlow
    if glowType == GlowType.Pixel then
        local cfg = GlowConfig.Pixel
        LibCustomGlow.PixelGlow_Start(button, colorTable, cfg.Lines, cfg.Frequency, cfg.Length, cfg.Thickness, cfg.XOffset, cfg.YOffset, cfg.Border, PROC_GLOW_KEY)
    elseif glowType == GlowType.Proc then
        local cfg = GlowConfig.Proc
        LibCustomGlow.ProcGlow_Start(button, { color = colorTable, startAnim = false, duration = cfg.Duration, key = PROC_GLOW_KEY })
    elseif glowType == GlowType.Autocast then
        local cfg = GlowConfig.Autocast
        LibCustomGlow.AutoCastGlow_Start(button, colorTable, cfg.Particles, cfg.Frequency, cfg.Scale, cfg.XOffset, cfg.YOffset, PROC_GLOW_KEY)
    elseif glowType == GlowType.Button then
        LibCustomGlow.ButtonGlow_Start(button, colorTable)
    end
end

local function StopProcGlow(button, activeType)
    local GlowType = Constants.PandemicGlow.Type
    if activeType == GlowType.Pixel then
        LibCustomGlow.PixelGlow_Stop(button, PROC_GLOW_KEY)
    elseif activeType == GlowType.Proc then
        LibCustomGlow.ProcGlow_Stop(button, PROC_GLOW_KEY)
    elseif activeType == GlowType.Autocast then
        LibCustomGlow.AutoCastGlow_Stop(button, PROC_GLOW_KEY)
    elseif activeType == GlowType.Button then
        LibCustomGlow.ButtonGlow_Stop(button)
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
        local GlowType = Constants.PandemicGlow.Type
        local glowType = self:GetSetting(si, "ProcGlowType") or GlowType.Button
        if glowType == GlowType.None then
            return
        end
        local color = self:GetSetting(si, "ProcGlowColor") or Constants.PandemicGlow.DefaultColor
        StartProcGlow(button, glowType, { color.r, color.g, color.b, color.a or 1 })
        button.orbitProcGlowActive = glowType
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

-- [ GLOW TRANSPARENCY FIX ]-------------------------------------------------------------------------
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

-- [ PANDEMIC GLOW ]----------------------------------------------------------------------------------
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

-- [ PANDEMIC GLOW FRAME HELPERS ]-------------------------------------------------------------------
local function GetPandemicGlowFrame(icon, glowType)
    local GlowType = Constants.PandemicGlow.Type
    if glowType == GlowType.Blizzard then return icon.orbitBlizzardGlow
    elseif glowType == GlowType.Pixel then return icon["_PixelGloworbitPandemic"]
    elseif glowType == GlowType.Proc then return icon["_ProcGloworbitPandemic"]
    elseif glowType == GlowType.Autocast then return icon["_AutoCastGloworbitPandemic"]
    elseif glowType == GlowType.Button then return icon["__ButtonGlow"]
    end
end

local function CreatePandemicGlow(icon, glowType, ct, plugin)
    local GlowType = Constants.PandemicGlow.Type
    local GlowConfig = Constants.PandemicGlow
    if glowType == GlowType.Blizzard then
        local glow = EnsureBlizzardGlowFrame(icon)
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", icon, "TOPLEFT", -PANDEMIC_INSET, PANDEMIC_INSET)
        glow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", PANDEMIC_INSET, -PANDEMIC_INSET)
        glow:Show()
    elseif glowType == GlowType.Pixel then
        local cfg = GlowConfig.Pixel
        LibCustomGlow.PixelGlow_Start(icon, ct, cfg.Lines, cfg.Frequency, cfg.Length, cfg.Thickness, cfg.XOffset, cfg.YOffset, cfg.Border, "orbitPandemic")
    elseif glowType == GlowType.Proc then
        local cfg = GlowConfig.Proc
        LibCustomGlow.ProcGlow_Start(icon, { color = ct, startAnim = cfg.StartAnim, duration = cfg.Duration, key = "orbitPandemic" })
        local glowFrame = icon["_ProcGloworbitPandemic"]
        if glowFrame then
            glowFrame.startAnim = false
            plugin:FixGlowTransparency(glowFrame, ct[4])
        end
    elseif glowType == GlowType.Autocast then
        local cfg = GlowConfig.Autocast
        LibCustomGlow.AutoCastGlow_Start(icon, ct, cfg.Particles, cfg.Frequency, cfg.Scale, cfg.XOffset, cfg.YOffset, "orbitPandemic")
    elseif glowType == GlowType.Button then
        local cfg = GlowConfig.Button
        LibCustomGlow.ButtonGlow_Start(icon, ct, cfg.Frequency, cfg.FrameLevel)
    end
    -- Clamp glow frame level so it never renders above border or text
    local glowFrame = GetPandemicGlowFrame(icon, glowType)
    if glowFrame and glowFrame.SetFrameLevel then
        glowFrame:SetFrameLevel(icon:GetFrameLevel() + BLIZZARD_GLOW_LEVEL)
    end
end

local function ShowPandemicGlow(icon, glowType)
    local glowFrame = GetPandemicGlowFrame(icon, glowType)
    if not glowFrame then return end
    if glowType == Constants.PandemicGlow.Type.Blizzard then glowFrame:Show()
    else glowFrame:SetAlpha(1) end
end

local function HidePandemicGlow(icon, glowType)
    local glowFrame = GetPandemicGlowFrame(icon, glowType)
    if not glowFrame then return end
    if glowType == Constants.PandemicGlow.Type.Blizzard then glowFrame:Hide()
    else glowFrame:SetAlpha(0) end
end

-- Full teardown: actually destroy glow (settings changes / cleanup only)
local function StopPandemicGlowFull(icon)
    local GlowType = Constants.PandemicGlow.Type
    local activeType = icon.orbitPandemicGlowActive
    if not activeType then return end
    icon.orbitSuppressPandemic = nil
    icon.orbitPandemicClearAt = nil
    icon.orbitPandemicGlowHidden = nil
    if activeType == GlowType.Blizzard then
        if icon.orbitBlizzardGlow then icon.orbitBlizzardGlow:Hide() end
    elseif activeType == GlowType.Pixel then LibCustomGlow.PixelGlow_Stop(icon, "orbitPandemic")
    elseif activeType == GlowType.Proc then LibCustomGlow.ProcGlow_Stop(icon, "orbitPandemic")
    elseif activeType == GlowType.Autocast then LibCustomGlow.AutoCastGlow_Stop(icon, "orbitPandemic")
    elseif activeType == GlowType.Button then LibCustomGlow.ButtonGlow_Stop(icon) end
    icon.orbitPandemicGlowActive = nil
end

-- [ HOOK-DRIVEN PANDEMIC GLOW ]---------------------------------------------------------------------
HookPandemicIcon = function(icon, plugin, systemIndex)
    if icon.orbitPandemicHooked then return end
    if not icon.ShowPandemicStateFrame then return end
    icon.orbitPandemicHooked = true
    local GlowType = Constants.PandemicGlow.Type
    local function BuildColorTable()
        local pandemicColor = plugin:GetSetting(systemIndex, "PandemicGlowColor") or Constants.PandemicGlow.DefaultColor
        local ct = plugin._pandemicColorCache
        if not ct then ct = { 0, 0, 0, 1 }; plugin._pandemicColorCache = ct end
        ct[1], ct[2], ct[3], ct[4] = pandemicColor.r, pandemicColor.g, pandemicColor.b, pandemicColor.a or 1
        return ct
    end
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
            self.orbitSuppressPandemic = true
            SuppressPandemicIcon(self)
            CreatePandemicGlow(self, glowType, BuildColorTable(), plugin)
            self.orbitPandemicGlowActive = glowType
        elseif self.orbitPandemicGlowHidden then
            self.orbitSuppressPandemic = true
            SuppressPandemicIcon(self)
            ShowPandemicGlow(self, activeType)
            self.orbitPandemicGlowHidden = nil
        else
            self.orbitSuppressPandemic = true
            SuppressPandemicIcon(self)
        end
    end
    local function OnPandemicHide(self)
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
end

-- CheckPandemicFrames: initial hookup + settings-change sync (hooks handle live state)
function CDM:CheckPandemicFrames(viewer, systemIndex)
    if not viewer then return end
    local icons = viewer.GetItemFrames and viewer:GetItemFrames()
    if not icons then return end
    local GlowType = Constants.PandemicGlow.Type
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
                local ct = self._pandemicColorCache
                if not ct then ct = { 0, 0, 0, 1 }; self._pandemicColorCache = ct end
                local c = self:GetSetting(systemIndex, "PandemicGlowColor") or Constants.PandemicGlow.DefaultColor
                ct[1], ct[2], ct[3], ct[4] = c.r, c.g, c.b, c.a or 1
                CreatePandemicGlow(icon, glowType, ct, self)
                icon.orbitPandemicGlowActive = glowType
            end
        end
        -- Initial state sync: if pandemic already active when first hooked
        if not icon.orbitPandemicGlowActive and glowType ~= GlowType.None and icon.PandemicIcon and icon.PandemicIcon:IsShown() then
            icon.orbitSuppressPandemic = true
            icon.PandemicIcon:SetAlpha(0)
            local ct = self._pandemicColorCache
            if not ct then ct = { 0, 0, 0, 1 }; self._pandemicColorCache = ct end
            local c = self:GetSetting(systemIndex, "PandemicGlowColor") or Constants.PandemicGlow.DefaultColor
            ct[1], ct[2], ct[3], ct[4] = c.r, c.g, c.b, c.a or 1
            CreatePandemicGlow(icon, glowType, ct, self)
            icon.orbitPandemicGlowActive = glowType
        end
    end
end

-- [ CLEAR ALL PANDEMIC GLOWS ]----------------------------------------------------------------------
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
