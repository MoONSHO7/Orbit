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
function CDM:CheckPandemicFrames(viewer, systemIndex)
    if not viewer then
        return
    end

    local GlowType = Constants.PandemicGlow.Type
    local glowType = self:GetSetting(systemIndex, "PandemicGlowType") or GlowType.None
    if glowType == GlowType.None then
        return
    end

    local GlowConfig = Constants.PandemicGlow
    local pandemicColor = self:GetSetting(systemIndex, "PandemicGlowColor") or GlowConfig.DefaultColor
    local colorTable = { pandemicColor.r, pandemicColor.g, pandemicColor.b, pandemicColor.a or 1 }

    local icons = viewer.GetItemFrames and viewer:GetItemFrames() or {}
    for _, icon in ipairs(icons) do
        local inPandemic = icon.PandemicIcon and icon.PandemicIcon:IsShown()
        if inPandemic then
            if not icon.orbitPandemicGlowActive then
                icon.PandemicIcon:SetAlpha(0)
                if glowType == GlowType.Pixel then
                    local cfg = GlowConfig.Pixel
                    LibCustomGlow.PixelGlow_Start(
                        icon,
                        colorTable,
                        cfg.Lines,
                        cfg.Frequency,
                        cfg.Length,
                        cfg.Thickness,
                        cfg.XOffset,
                        cfg.YOffset,
                        cfg.Border,
                        "orbitPandemic"
                    )
                elseif glowType == GlowType.Proc then
                    local cfg = GlowConfig.Proc
                    LibCustomGlow.ProcGlow_Start(icon, { color = colorTable, startAnim = cfg.StartAnim, duration = cfg.Duration, key = "orbitPandemic" })
                    local glowFrame = icon["_ProcGloworbitPandemic"]
                    if glowFrame then
                        glowFrame.startAnim = false
                        self:FixGlowTransparency(glowFrame, pandemicColor.a)
                    end
                elseif glowType == GlowType.Autocast then
                    local cfg = GlowConfig.Autocast
                    LibCustomGlow.AutoCastGlow_Start(icon, colorTable, cfg.Particles, cfg.Frequency, cfg.Scale, cfg.XOffset, cfg.YOffset, "orbitPandemic")
                elseif glowType == GlowType.Button then
                    local cfg = GlowConfig.Button
                    LibCustomGlow.ButtonGlow_Start(icon, colorTable, cfg.Frequency, cfg.FrameLevel)
                end
                icon.orbitPandemicGlowActive = glowType
            end
        else
            if icon.orbitPandemicGlowActive then
                local activeType = icon.orbitPandemicGlowActive
                if activeType == GlowType.Pixel then
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
