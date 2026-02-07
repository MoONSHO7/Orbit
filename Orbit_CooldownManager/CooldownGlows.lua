---@type Orbit
local Orbit = Orbit
local Constants = Orbit.Constants

local LibCustomGlow = LibStub("LibCustomGlow-1.0", true)
if not LibCustomGlow then return end

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local ESSENTIAL_INDEX = Constants.Cooldown.SystemIndex.Essential
local UTILITY_INDEX = Constants.Cooldown.SystemIndex.Utility
local BUFFICON_INDEX = Constants.Cooldown.SystemIndex.BuffIcon

-- [ PROC GLOW HOOKS ]-------------------------------------------------------------------------------
function CDM:HookProcGlow()
    if self.procGlowHooked or not ActionButtonSpellAlertManager then return end

    local plugin = self
    local GlowType = Constants.PandemicGlow.Type
    local GlowConfig = Constants.PandemicGlow

    hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button)
        local viewer = button.viewerFrame
        if not viewer then return end

        local systemIndex = viewer == EssentialCooldownViewer and ESSENTIAL_INDEX
            or viewer == UtilityCooldownViewer and UTILITY_INDEX
            or viewer == BuffIconCooldownViewer and BUFFICON_INDEX
            or nil
        if not systemIndex then return end

        local glowType = plugin:GetSetting(systemIndex, "ProcGlowType") or GlowType.None
        if glowType == GlowType.None then return end

        local procColor = plugin:GetSetting(systemIndex, "ProcGlowColor") or GlowConfig.DefaultColor
        local colorTable = { procColor.r, procColor.g, procColor.b, procColor.a or 1 }

        if button.SpellActivationAlert then button.SpellActivationAlert:SetAlpha(0) end
        if button.orbitProcGlowActive then return end

        if glowType == GlowType.Pixel then
            local cfg = GlowConfig.Pixel
            LibCustomGlow.PixelGlow_Start(button, colorTable, cfg.Lines, cfg.Frequency, cfg.Length, cfg.Thickness, cfg.XOffset, cfg.YOffset, cfg.Border, "orbitProc")
        elseif glowType == GlowType.Proc then
            local cfg = GlowConfig.Proc
            LibCustomGlow.ProcGlow_Start(button, { color = colorTable, startAnim = cfg.StartAnim, duration = cfg.Duration, key = "orbitProc" })
            local glowFrame = button["_ProcGloworbitProc"]
            if glowFrame then
                glowFrame.startAnim = false
                plugin:FixGlowTransparency(glowFrame, procColor.a)
            end
        elseif glowType == GlowType.Autocast then
            local cfg = GlowConfig.Autocast
            LibCustomGlow.AutoCastGlow_Start(button, colorTable, cfg.Particles, cfg.Frequency, cfg.Scale, cfg.XOffset, cfg.YOffset, "orbitProc")
        elseif glowType == GlowType.Button then
            local cfg = GlowConfig.Button
            LibCustomGlow.ButtonGlow_Start(button, colorTable, cfg.Frequency, cfg.FrameLevel)
        end
        button.orbitProcGlowActive = glowType
    end)

    hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", function(_, button)
        if not button.orbitProcGlowActive then return end
        local activeType = button.orbitProcGlowActive
        if activeType == GlowType.Pixel then LibCustomGlow.PixelGlow_Stop(button, "orbitProc")
        elseif activeType == GlowType.Proc then LibCustomGlow.ProcGlow_Stop(button, "orbitProc")
        elseif activeType == GlowType.Autocast then LibCustomGlow.AutoCastGlow_Stop(button, "orbitProc")
        elseif activeType == GlowType.Button then LibCustomGlow.ButtonGlow_Stop(button)
        end
        button.orbitProcGlowActive = nil
    end)

    self.procGlowHooked = true
end

-- [ GLOW TRANSPARENCY FIX ]-------------------------------------------------------------------------
function CDM:FixGlowTransparency(glowFrame, alpha)
    if not glowFrame or not alpha then return end
    if glowFrame.ProcLoopAnim and glowFrame.ProcLoopAnim.alphaRepeat then
        glowFrame.ProcLoopAnim.alphaRepeat:SetFromAlpha(alpha)
        glowFrame.ProcLoopAnim.alphaRepeat:SetToAlpha(alpha)
    end
    if glowFrame.ProcStartAnim then
        for _, anim in pairs({ glowFrame.ProcStartAnim:GetAnimations() }) do
            if anim:GetObjectType() == "Alpha" then
                local order = anim:GetOrder()
                if order == 0 then anim:SetFromAlpha(alpha); anim:SetToAlpha(alpha)
                elseif order == 2 then anim:SetFromAlpha(alpha)
                end
            end
        end
    end
end

-- [ PANDEMIC GLOW ]----------------------------------------------------------------------------------
function CDM:CheckPandemicFrames(viewer, systemIndex)
    if not viewer then return end

    local GlowType = Constants.PandemicGlow.Type
    local glowType = self:GetSetting(systemIndex, "PandemicGlowType") or GlowType.None
    if glowType == GlowType.None then return end

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
                    LibCustomGlow.PixelGlow_Start(icon, colorTable, cfg.Lines, cfg.Frequency, cfg.Length, cfg.Thickness, cfg.XOffset, cfg.YOffset, cfg.Border, "orbitPandemic")
                elseif glowType == GlowType.Proc then
                    local cfg = GlowConfig.Proc
                    LibCustomGlow.ProcGlow_Start(icon, { color = colorTable, startAnim = cfg.StartAnim, duration = cfg.Duration, key = "orbitPandemic" })
                    local glowFrame = icon["_ProcGloworbitPandemic"]
                    if glowFrame then glowFrame.startAnim = false; self:FixGlowTransparency(glowFrame, pandemicColor.a) end
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
                if activeType == GlowType.Pixel then LibCustomGlow.PixelGlow_Stop(icon, "orbitPandemic")
                elseif activeType == GlowType.Proc then LibCustomGlow.ProcGlow_Stop(icon, "orbitPandemic")
                elseif activeType == GlowType.Autocast then LibCustomGlow.AutoCastGlow_Stop(icon, "orbitPandemic")
                elseif activeType == GlowType.Button then LibCustomGlow.ButtonGlow_Stop(icon)
                end
                icon.orbitPandemicGlowActive = nil
            end
        end
    end
end
