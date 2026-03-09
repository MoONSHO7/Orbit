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
        LibCustomGlow.PixelGlow_Start(
            button,
            colorTable,
            cfg.Lines,
            cfg.Frequency,
            cfg.Length,
            cfg.Thickness,
            cfg.XOffset,
            cfg.YOffset,
            cfg.Border,
            PROC_GLOW_KEY
        )
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

local function EnsureBlizzardGlowFrame(icon)
    if icon._orbitBlizzardGlow then return icon._orbitBlizzardGlow end
    local f = CreateFrame("Frame", nil, icon)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(icon:GetFrameLevel() + 30)
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas(PANDEMIC_ATLAS)
    tex:SetAllPoints(f)
    f.tex = tex
    f:Hide()
    icon._orbitBlizzardGlow = f
    return f
end

local function HookPandemicIcon(icon)
    if icon._orbitPandemicHooked or not icon.PandemicIcon then return end
    icon._orbitPandemicHooked = true
    local pi = icon.PandemicIcon
    hooksecurefunc(pi, "Show", function(self)
        if icon.orbitSuppressPandemic then self:SetAlpha(0) end
    end)
    hooksecurefunc(pi, "SetAlpha", function(self, a)
        if icon.orbitSuppressPandemic and a > 0 then self:SetAlpha(0) end
    end)
end

function CDM:CheckPandemicFrames(viewer, systemIndex)
    if not viewer then return end

    local GlowType = Constants.PandemicGlow.Type
    local glowType = self:GetSetting(systemIndex, "PandemicGlowType") or GlowType.None
    if glowType == GlowType.None then return end

    local GlowConfig = Constants.PandemicGlow
    local pandemicColor = self:GetSetting(systemIndex, "PandemicGlowColor") or GlowConfig.DefaultColor
    local ct = self._pandemicColorCache
    if not ct then ct = { 0, 0, 0, 1 }; self._pandemicColorCache = ct end
    ct[1], ct[2], ct[3], ct[4] = pandemicColor.r, pandemicColor.g, pandemicColor.b, pandemicColor.a or 1

    local icons = viewer.GetItemFrames and viewer:GetItemFrames()
    if not icons then return end
    for _, icon in ipairs(icons) do
        HookPandemicIcon(icon)
        local inPandemic = icon.PandemicIcon and icon.PandemicIcon:IsShown()
        if inPandemic then
            if not icon.orbitPandemicGlowActive then
                -- Suppress Blizzard's red border for all glow types
                icon.orbitSuppressPandemic = true
                icon.PandemicIcon:SetAlpha(0)
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
                        self:FixGlowTransparency(glowFrame, pandemicColor.a)
                    end
                elseif glowType == GlowType.Autocast then
                    local cfg = GlowConfig.Autocast
                    LibCustomGlow.AutoCastGlow_Start(icon, ct, cfg.Particles, cfg.Frequency, cfg.Scale, cfg.XOffset, cfg.YOffset, "orbitPandemic")
                elseif glowType == GlowType.Button then
                    local cfg = GlowConfig.Button
                    LibCustomGlow.ButtonGlow_Start(icon, ct, cfg.Frequency, cfg.FrameLevel)
                end
                icon.orbitPandemicGlowActive = glowType
            end
        else
            if icon.orbitPandemicGlowActive then
                local activeType = icon.orbitPandemicGlowActive
                icon.orbitSuppressPandemic = nil
                if activeType == GlowType.Blizzard then
                    if icon._orbitBlizzardGlow then icon._orbitBlizzardGlow:Hide() end
                elseif activeType == GlowType.Pixel then
                    LibCustomGlow.PixelGlow_Stop(icon, "orbitPandemic")
                elseif activeType == GlowType.Proc then
                    LibCustomGlow.ProcGlow_Stop(icon, "orbitPandemic")
                elseif activeType == GlowType.Autocast then
                    LibCustomGlow.AutoCastGlow_Stop(icon, "orbitPandemic")
                elseif activeType == GlowType.Button then
                    LibCustomGlow.ButtonGlow_Stop(icon)
                end
                icon.orbitPandemicGlowActive = nil
            end
        end
    end
end
