-- [ ORBIT ACTION BUTTON SKINNING ]------------------------------------------------------------------
local _, Orbit = ...
local Skin = Orbit.Skin
local Icons = Skin.Icons
local Constants = Orbit.Constants
local Pixel = Orbit.Engine.Pixel
Skin.ActionButtonSkin = {}
local ABS = Skin.ActionButtonSkin

local STANDARD_ACTION_BUTTON_SIZE = 45
local DESAT_NONE = 0
local DESAT_FULL = 1
local MASQUE_REGION_KEYS = { "Backdrop", "Normal_Custom", "Shadow", "Gloss" }

local function ResetRegion(region)
    if region then
        region:SetAlpha(0)
        if region.Hide then region:Hide() end
    end
end

function ABS:Apply(button, settings)
    if not button then return end
    local w, h = button:GetSize()
    local scale = button:GetEffectiveScale() or 1
    local borderInset = (Pixel and Pixel:BorderInset(button, settings.borderSize or Pixel:DefaultBorderSize(scale)) or 1) * 2

    ResetRegion(button.NormalTexture)
    ResetRegion(button.PushedTexture)
    ResetRegion(button.HighlightTexture)
    ResetRegion(button.CheckedTexture)

    if button.Border then
        ResetRegion(button.Border)
        button.orbitHideBorder = true
        if not button.orbitBorderHooked then
            hooksecurefunc(button.Border, "Show", function(self)
                if self:GetParent().orbitHideBorder then self:Hide(); self:SetAlpha(0) end
            end)
            button.orbitBorderHooked = true
        end
    end

    local checkedTexture = button.CheckedTexture
    if not checkedTexture and button.GetCheckedTexture then checkedTexture = button:GetCheckedTexture() end
    if checkedTexture then
        checkedTexture:ClearAllPoints()
        checkedTexture:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
        checkedTexture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -2)
        checkedTexture:SetAlpha(1)
        checkedTexture:SetDrawLayer("OVERLAY", 7)
    end

    ResetRegion(button.FloatingBG)
    ResetRegion(button.SlotBackground)
    ResetRegion(button.SlotArt)

    if not button.orbitBackdrop then
        button.orbitBackdrop = button:CreateTexture(nil, "BACKGROUND", nil, Constants.Layers.BackdropDeep)
        local bgColor = settings.backdropColor or Constants.Colors.Background
        button.orbitBackdrop:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    end
    button.orbitBackdrop:SetDrawLayer("BACKGROUND", Constants.Layers.BackdropDeep)
    button.orbitBackdrop:ClearAllPoints()
    button.orbitBackdrop:SetAllPoints(button)
    local bgColor = settings.backdropColor or Constants.Colors.Background
    button.orbitBackdrop:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    button.orbitBackdrop:Show()

    local icon = button.icon or button.Icon
    if icon then icon:ClearAllPoints(); icon:SetAllPoints(button) end

    local cooldown = button.cooldown or button.Cooldown
    if cooldown then cooldown:ClearAllPoints(); cooldown:SetAllPoints(button) end

    if button.SpellHighlightTexture then
        button.SpellHighlightTexture:ClearAllPoints()
        button.SpellHighlightTexture:SetAllPoints(button)
        button.SpellHighlightTexture:SetColorTexture(1, 1, 1, 0.6)
    end

    if button.NewActionTexture then
        button.NewActionTexture:ClearAllPoints()
        button.NewActionTexture:SetAllPoints(button)
        button.NewActionTexture:SetColorTexture(1, 1, 1, 1)
    end

    if button.Flash then
        button.Flash:ClearAllPoints()
        button.Flash:SetAllPoints(button)
        button.Flash:SetColorTexture(1, 1, 0.4, 0.2)
    end

    local autoCast = button.AutoCastOverlay or button.AutoCastFrame or button.Shine
    if not autoCast and button:GetName() then autoCast = _G[button:GetName() .. "Shine"] end
    if autoCast then
        autoCast:ClearAllPoints()
        autoCast:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 1)
        autoCast:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
        autoCast:SetFrameLevel(button:GetFrameLevel() + 10)
        if autoCast.Shine then autoCast.Shine:ClearAllPoints(); autoCast.Shine:SetAllPoints(autoCast) end
        if autoCast.Corners then autoCast.Corners:ClearAllPoints(); autoCast.Corners:SetAllPoints(autoCast) end
    end

    local scaleRatio = w / STANDARD_ACTION_BUTTON_SIZE
    local overlays = { button.TargetReticleAnimFrame, button.SpellCastAnimFrame, button.CooldownFlash, button.InterruptDisplay }
    for _, overlay in ipairs(overlays) do
        if overlay then
            overlay:ClearAllPoints()
            overlay:SetPoint("CENTER", button, "CENTER", 0, 0)
            overlay:SetScale(scaleRatio)
        end
    end

    if button.UpdateAssistedCombatRotationFrame and not button.orbitAssistedHooked then
        hooksecurefunc(button, "UpdateAssistedCombatRotationFrame", function(self)
            local frame = self.AssistedCombatRotationFrame
            if not frame or frame.orbitScaled then return end
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", self, "CENTER", 0, 0)
            frame:SetScale((w + borderInset) / STANDARD_ACTION_BUTTON_SIZE)
            frame.orbitScaled = true
        end)
        button.orbitAssistedHooked = true
    end

    button.orbitButtonWidth = w + borderInset + 2
    button.orbitButtonHeight = h + borderInset + 2
    if AssistedCombatManager and not ABS.orbitHighlightHooked then
        hooksecurefunc(AssistedCombatManager, "SetAssistedHighlightFrameShown", function(_, actionButton)
            local frame = actionButton.AssistedCombatHighlightFrame
            if not frame or frame.orbitScaled or not actionButton.orbitButtonWidth then return end
            local bw, bh = actionButton.orbitButtonWidth, actionButton.orbitButtonHeight
            frame:SetSize(bw, bh)
            if frame.Flipbook then
                local s = actionButton:GetEffectiveScale()
                frame.Flipbook:SetSize(Pixel:Snap(bw * 1.4, s), Pixel:Snap(bh * 1.4, s))
            end
            frame.orbitScaled = true
        end)
        ABS.orbitHighlightHooked = true
    end

    Icons:ApplyCustom(button, settings)

    if button.HotKey then
        local fontName = Orbit.db.GlobalSettings.Font
        local fontPath = (Orbit.Fonts and Orbit.Fonts[fontName]) or Constants.Settings.Font.FallbackPath
        local fontSize = math.max(8, w * 0.28)
        button.HotKey:SetFont(fontPath, fontSize, Skin:GetFontOutline())
        button.HotKey:SetTextColor(1, 1, 1, 1)
        button.HotKey:ClearAllPoints()
        button.HotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    end

    if button.Name then
        local fontName = Orbit.db.GlobalSettings.Font
        local fontPath = (Orbit.Fonts and Orbit.Fonts[fontName]) or Constants.Settings.Font.FallbackPath
        local fontSize = math.max(7, w * 0.22)
        button.Name:SetFont(fontPath, fontSize, Skin:GetFontOutline())
        if settings.hideName then button.Name:Hide()
        else
            button.Name:Show()
            button.Name:SetTextColor(1, 1, 1, 0.9)
            button.Name:ClearAllPoints()
            button.Name:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
        end
    end

    if not button.orbitHighlight then
        button.orbitHighlight = button:CreateTexture(nil, "OVERLAY")
        button.orbitHighlight:SetAllPoints(button)
        button.orbitHighlight:SetColorTexture(1, 1, 1, 0.3)
        button.orbitHighlight:Hide()
        button:HookScript("OnEnter", function(self) if self.orbitHighlight then self.orbitHighlight:Show() end end)
        button:HookScript("OnLeave", function(self) if self.orbitHighlight then self.orbitHighlight:Hide() end end)
    end

    -- [ KEYPRESS FLASH ]--------------------------------------------------------------------------------
    local kpColor = settings.keypressColor or { r = 1, g = 1, b = 1, a = 0.6 }
    button.orbitKpColor = kpColor

    if not button.orbitKeypressFlash then
        local flashFrame = CreateFrame("Frame", nil, button)
        flashFrame:SetAllPoints(button)
        flashFrame:SetFrameLevel(button:GetFrameLevel() + 3)
        flashFrame:Hide()
        local flash = flashFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        flash:SetAllPoints(flashFrame)
        flash:SetColorTexture(kpColor.r, kpColor.g, kpColor.b, kpColor.a)
        button.orbitKeypressFlash = flashFrame
        button.orbitKeypressTexture = flash
        local fadeGroup = flashFrame:CreateAnimationGroup()
        fadeGroup:SetToFinalAlpha(true)
        local fadeOut = fadeGroup:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(0.15)
        fadeOut:SetSmoothing("OUT")
        fadeGroup:SetScript("OnFinished", function() flashFrame:Hide() end)
        button.orbitKeypressFade = fadeGroup
        hooksecurefunc(button, "SetButtonState", function(self, state)
            if state == "PUSHED" then
                local c = self.orbitKpColor
                flash:SetColorTexture(c.r, c.g, c.b, c.a)
                flashFrame:SetAlpha(1)
                flashFrame:Show()
                fadeGroup:Stop()
            elseif state == "NORMAL" then fadeGroup:Play() end
        end)
    end

    if button.FlyoutArrow then
        if not button.orbitOverlayFrame then
            button.orbitOverlayFrame = CreateFrame("Frame", nil, button)
            button.orbitOverlayFrame:SetAllPoints(button)
            button.orbitOverlayFrame:SetFrameStrata("TOOLTIP")
            button.orbitOverlayFrame:SetFrameLevel(100)
        end
        button.FlyoutArrow:SetParent(button.orbitOverlayFrame)
        button.FlyoutArrow:ClearAllPoints()
        button.FlyoutArrow:SetPoint("TOP", button.orbitOverlayFrame, "TOP", 0, 2)
        if button.FlyoutBorderShadow then button.FlyoutBorderShadow:SetParent(button.orbitOverlayFrame) end
    end

    if button.action and not button.orbitRangeHooked then
        hooksecurefunc(button, "OnEvent", function(self, event, ...)
            if event == "ACTION_RANGE_CHECK_UPDATE" then
                local _, inRange, checksRange = ...
                local icon = self.icon or self.Icon
                if icon and checksRange then icon:SetDesaturation(C_CurveUtil.EvaluateColorValueFromBoolean(inRange, DESAT_NONE, DESAT_FULL)) end
            end
        end)
        button.orbitRangeHooked = true
    end
end

function ABS:Strip(button)
    if not button then return end
    button.orbitHideBorder = false
    if button.orbitBackdrop then button.orbitBackdrop:Hide() end
    if button.orbitHighlight then button.orbitHighlight:Hide() end
    if Icons.borderCache[button] then Icons.borderCache[button]:Hide() end
    local cd = button.cooldown or button.Cooldown
    if cd then cd.orbitDesiredSwipe = nil end
    local icon = button.icon or button.Icon
    if icon and button.IconMask then
        button.IconMask:Show()
        if icon.AddMaskTexture then icon:AddMaskTexture(button.IconMask) end
    end
end

function ABS:StripMasque(button)
    if not button then return end
    local cfg = button._MSQ_CFG
    if not cfg then return end
    for _, key in ipairs(MASQUE_REGION_KEYS) do
        local region = cfg[key]
        if region and region.Hide then region:SetTexture(); region:Hide() end
    end
end
