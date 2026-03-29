-- [ ORBIT ACTION BUTTON SKINNING ]------------------------------------------------------------------
local _, Orbit = ...
local Skin = Orbit.Skin
local Icons = Skin.Icons
local Constants = Orbit.Constants
local Pixel = Orbit.Engine.Pixel
local LSM = LibStub("LibSharedMedia-3.0")
Skin.ActionButtonSkin = {}
local ABS = Skin.ActionButtonSkin

local STANDARD_ACTION_BUTTON_SIZE = 45
local MASQUE_REGION_KEYS = { "Backdrop", "Normal_Custom", "Shadow", "Gloss" }
local CHECKED_OFFSET_TL = { x = -2, y = 2 }
local CHECKED_OFFSET_BR = { x = 3, y = -2 }
local SPELL_HIGHLIGHT_ALPHA = 0.6
local FLASH_COLOR = { r = 1, g = 1, b = 0.4, a = 0.2 }
local AUTOCAST_OFFSET_TL = { x = 0, y = 1 }
local AUTOCAST_OFFSET_BR = { x = 1, y = -1 }
local HOTKEY_FONT_SCALE = 0.28
local HOTKEY_MIN_SIZE = 8
local HOTKEY_OFFSET = { x = -2, y = -2 }
local NAME_FONT_SCALE = 0.22
local NAME_MIN_SIZE = 7
local NAME_OFFSET_Y = 2
local NAME_TEXT_ALPHA = 0.9
local HIGHLIGHT_ALPHA = 0.3
local KEYPRESS_FADE_DURATION = 0.15
local DEFAULT_KEYPRESS_COLOR = { r = 1, g = 1, b = 1, a = 0.6 }

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
        checkedTexture:SetPoint("TOPLEFT", button, "TOPLEFT", CHECKED_OFFSET_TL.x, CHECKED_OFFSET_TL.y)
        checkedTexture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", CHECKED_OFFSET_BR.x, CHECKED_OFFSET_BR.y)
        checkedTexture:SetAlpha(1)
        checkedTexture:SetDrawLayer("OVERLAY", Constants.Layers.Text)
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
        button.SpellHighlightTexture:SetColorTexture(1, 1, 1, SPELL_HIGHLIGHT_ALPHA)
    end

    if button.NewActionTexture then
        button.NewActionTexture:ClearAllPoints()
        button.NewActionTexture:SetAllPoints(button)
        button.NewActionTexture:SetColorTexture(1, 1, 1, 1)
    end

    if button.Flash then
        button.Flash:ClearAllPoints()
        button.Flash:SetAllPoints(button)
        button.Flash:SetColorTexture(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, FLASH_COLOR.a)
    end

    local autoCast = button.AutoCastOverlay or button.AutoCastFrame or button.Shine
    if not autoCast and button:GetName() then autoCast = _G[button:GetName() .. "Shine"] end
    if autoCast then
        autoCast:ClearAllPoints()
        autoCast:SetPoint("TOPLEFT", button, "TOPLEFT", AUTOCAST_OFFSET_TL.x, AUTOCAST_OFFSET_TL.y)
        autoCast:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", AUTOCAST_OFFSET_BR.x, AUTOCAST_OFFSET_BR.y)
        autoCast:SetFrameLevel(button:GetFrameLevel() + Constants.Levels.IconOverlay)
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

    local fontName = Orbit.db.GlobalSettings.Font
    local fontPath = LSM:Fetch("font", fontName) or Constants.Settings.Font.FallbackPath
    if button.HotKey then
        local fontSize = math.max(HOTKEY_MIN_SIZE, w * HOTKEY_FONT_SCALE)
        button.HotKey:SetFont(fontPath, fontSize, Skin:GetFontOutline())
        button.HotKey:SetTextColor(1, 1, 1, 1)
        button.HotKey:ClearAllPoints()
        button.HotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", HOTKEY_OFFSET.x, HOTKEY_OFFSET.y)
    end

    if button.Name then
        local fontSize = math.max(NAME_MIN_SIZE, w * NAME_FONT_SCALE)
        button.Name:SetFont(fontPath, fontSize, Skin:GetFontOutline())
        if settings.hideName then button.Name:Hide()
        else
            button.Name:Show()
            button.Name:SetTextColor(1, 1, 1, NAME_TEXT_ALPHA)
            button.Name:ClearAllPoints()
            button.Name:SetPoint("BOTTOM", button, "BOTTOM", 0, NAME_OFFSET_Y)
        end
    end

    if not button.orbitHighlight then
        button.orbitHighlight = button:CreateTexture(nil, "OVERLAY")
        button.orbitHighlight:SetAllPoints(button)
        button.orbitHighlight:SetColorTexture(1, 1, 1, HIGHLIGHT_ALPHA)
        button.orbitHighlight:Hide()
        button:HookScript("OnEnter", function(self) if self.orbitHighlight then self.orbitHighlight:Show() end end)
        button:HookScript("OnLeave", function(self) if self.orbitHighlight then self.orbitHighlight:Hide() end end)
    end

    -- [ KEYPRESS FLASH ]--------------------------------------------------------------------------------
    local kpColor = settings.keypressColor or DEFAULT_KEYPRESS_COLOR
    button.orbitKpColor = kpColor

    if not button.orbitKeypressFlash then
        local flashFrame = CreateFrame("Frame", nil, button)
        flashFrame:SetAllPoints(button)
        flashFrame:SetFrameLevel(button:GetFrameLevel() + Constants.Levels.IconSwipe)
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
        fadeOut:SetDuration(KEYPRESS_FADE_DURATION)
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

    if button.Arrow then
        if not button.orbitFlyoutOverlay then
            local overlay = CreateFrame("Frame", nil, button)
            overlay:SetAllPoints(button)
            local arrow = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
            arrow:SetAtlas(button.arrowNormalTexture or "UI-HUD-ActionBar-Flyout")
            arrow:SetSize(button.arrowMainAxisSize or 15, button.arrowCrossAxisSize or 6)
            overlay.arrow = arrow
            button.orbitFlyoutOverlay = overlay
        end
        local overlay = button.orbitFlyoutOverlay
        overlay:SetFrameLevel(button:GetFrameLevel() + Constants.Levels.Tooltip)
        overlay.arrow:SetShown(button.Arrow:IsShown())
        button.Arrow:SetAlpha(0)
        if button.BorderShadow then button.BorderShadow:SetAlpha(0) end
        if not button.orbitFlyoutHooked then
            local function SyncArrow(self)
                local ov = self.orbitFlyoutOverlay
                if not ov then return end
                ov.arrow:SetShown(self.Arrow:IsShown())
                self.Arrow:SetAlpha(0)
                if self.BorderShadow then self.BorderShadow:SetAlpha(0) end
            end
            local function SyncPosition(self)
                local ov = self.orbitFlyoutOverlay
                if not ov then return end
                ov.arrow:ClearAllPoints()
                local direction = self:GetPopupDirection()
                local offset = (self.IsPopupOpen and self:IsPopupOpen()) and self.openArrowOffset or self.closedArrowOffset
                if direction == "UP" then ov.arrow:SetPoint("TOP", ov, "TOP", 0, offset)
                elseif direction == "DOWN" then ov.arrow:SetPoint("BOTTOM", ov, "BOTTOM", 0, -offset)
                elseif direction == "LEFT" then ov.arrow:SetPoint("LEFT", ov, "LEFT", -offset, 0)
                elseif direction == "RIGHT" then ov.arrow:SetPoint("RIGHT", ov, "RIGHT", offset, 0) end
            end
            local function SyncTexture(self)
                local ov = self.orbitFlyoutOverlay
                if not ov then return end
                local atlas = self.arrowNormalTexture or "UI-HUD-ActionBar-Flyout"
                if self.IsDown and self:IsDown() then atlas = self.arrowDownTexture or "UI-HUD-ActionBar-Flyout-Down"
                elseif self.IsOver and self:IsOver() then atlas = self.arrowOverTexture or "UI-HUD-ActionBar-Flyout-Mouseover" end
                ov.arrow:SetAtlas(atlas, false)
            end
            local function SyncRotation(self)
                local ov = self.orbitFlyoutOverlay
                if not ov then return end
                local rotation = self.GetArrowRotation and self:GetArrowRotation() or 0
                SetClampedTextureRotation(ov.arrow, rotation)
            end
            hooksecurefunc(button, "UpdateArrowShown", SyncArrow)
            hooksecurefunc(button, "UpdateArrowPosition", function(self) SyncPosition(self); SyncRotation(self) end)
            if button.UpdateArrowTexture then hooksecurefunc(button, "UpdateArrowTexture", SyncTexture) end
            if button.UpdateArrowRotation then hooksecurefunc(button, "UpdateArrowRotation", SyncRotation) end
            SyncPosition(button)
            SyncRotation(button)
            button.orbitFlyoutHooked = true
        end
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
