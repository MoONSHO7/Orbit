---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

local Plugin = Orbit:RegisterPlugin("Player Buffs", "Orbit_PlayerBuffs", {
    defaults = Orbit.UnitAuraGridMixin.playerBuffDefaults,
})

Mixin(Plugin, Orbit.AuraMixin)
Mixin(Plugin, Orbit.UnitAuraGridMixin)

function Plugin:IsEnabled() return true end

function Plugin:AddSettings(dialog, systemFrame) self:AddAuraGridSettings(dialog, systemFrame) end

function Plugin:OnLoad()
    self:CreateAuraGridPlugin({
        unit = "player", auraFilter = "HELPFUL", isHarmful = false,
        frameName = "OrbitPlayerBuffsFrame", editModeName = "Player Buffs",
        defaultX = 230, defaultY = 360, initialWidth = 400, initialHeight = 20,
        changeEvent = "PLAYER_ENTERING_WORLD",
        showTimer = true, enablePandemic = false,
        showIconLimit = true, defaultIconLimit = 20,
        showRows = true,
    })
    if BuffFrame then self:InitBlizzardBuffs() end
end

-- [ BLIZZARD BUFF REPARENTING ]---------------------------------------------------------------------
function Plugin:InitBlizzardBuffs()
    self._useBlizzardBuffs = true
    -- Keep BuffFrame alive but invisible
    OrbitEngine.NativeFrame:Protect(BuffFrame)
    -- Force expanded so all buttons stay available — we handle our own collapse
    BuffFrame.IsExpanded = function() return true end
    -- Hook after BuffFrame updates buttons to reparent into our frame
    hooksecurefunc(BuffFrame, "UpdateAuraButtons", function()
        if not Orbit:IsEditMode() then self:UpdateBlizzardBuffs() end
    end)
end

-- Override: skip pool-based UpdateAuras when using Blizzard buffs
function Plugin:UpdateAuras()
    if self._useBlizzardBuffs then
        self:UpdateBlizzardBuffs()
        return
    end
    Orbit.UnitAuraGridMixin.UpdateAuras(self)
end

function Plugin:UpdateBlizzardBuffs()
    local Frame = self._agFrame
    if not Frame or not self:IsEnabled() then return end
    if not BuffFrame or not BuffFrame.auraFrames then return end
    if Orbit:IsEditMode() then return end

    local collapsed = self:GetSetting(1, "Collapsed")
    local maxAuras, iconsPerRow, spacing, iconH, iconW = self:_resolveGrid()
    local iconLimit = self:GetSetting(1, "IconLimit") or 20
    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = Orbit.db.GlobalSettings.BorderSize, showTimer = true }

    local anchor, growthX, growthY = self.ResolveGrowthDirection(Frame, true)
    if Frame.collapseArrow then
        self.UpdateCollapseArrow(Frame.collapseArrow, collapsed, iconH, growthX, growthY)
    end

    local activeIcons = {}
    for _, btn in ipairs(BuffFrame.auraFrames) do
        if btn.isAuraAnchor then
            -- skip private aura anchors
        elseif btn.hasValidInfo and btn:IsShown() then
            if collapsed and btn.buttonInfo and btn.buttonInfo.hideUnlessExpanded then
                -- skip hidden-when-collapsed buffs
            elseif #activeIcons < iconLimit then
                btn:SetParent(Frame)
                btn:SetSize(iconW, iconH)
                self:SkinBlizzardButton(btn, iconH, iconW, skinSettings)
                table.insert(activeIcons, btn)
            end
        end
    end

    if #activeIcons == 0 then
        if collapsed and not InCombatLockdown() then Frame:SetSize(iconW, iconH) end
        return
    end

    Orbit.AuraLayout:LayoutGrid(Frame, activeIcons, {
        size = iconH, sizeW = iconW, spacing = spacing, maxPerRow = iconsPerRow,
        anchor = anchor, growthX = growthX, growthY = growthY, yOffset = 0,
    })
end

-- [ SKINNING ]--------------------------------------------------------------------------------------
function Plugin:SkinBlizzardButton(btn, iconH, iconW, skinSettings)
    -- Icon fills the button
    btn.Icon:ClearAllPoints()
    btn.Icon:SetAllPoints(btn)
    self.CropIconTexture(btn, iconW, iconH)

    -- Hide Blizzard chrome
    if btn.Duration then btn.Duration:Hide() end
    if btn.DebuffBorder then btn.DebuffBorder:Hide() end
    if btn.TempEnchantBorder then btn.TempEnchantBorder:Hide() end
    if btn.Symbol then btn.Symbol:Hide() end
    if btn.Count then btn.Count:Hide() end

    -- Cooldown swipe
    if not btn.Cooldown then
        btn.Cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        btn.Cooldown:SetAllPoints()
        btn.Cooldown:SetHideCountdownNumbers(false)
        btn.Cooldown:EnableMouse(false)
        btn.cooldown = btn.Cooldown
    end

    -- Timer text font
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    local fontPath = (LSM and fontName and LSM:Fetch("font", fontName)) or "Fonts\\FRIZQT__.TTF"
    local fontOutline = Orbit.Skin and Orbit.Skin.GetFontOutline and Orbit.Skin:GetFontOutline() or ""
    local timerText = btn.Cooldown.Text
    if not timerText then
        for _, region in pairs({ btn.Cooldown:GetRegions() }) do
            if region:IsObjectType("FontString") then timerText = region; break end
        end
        btn.Cooldown.Text = timerText
    end
    if timerText and timerText.SetFont then
        timerText:SetFont(fontPath, Orbit.Skin:GetAdaptiveTextSize(iconH, 8, nil, 0.45), fontOutline)
        timerText:ClearAllPoints()
        timerText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        timerText:SetJustifyH("CENTER")
        timerText:SetDrawLayer("OVERLAY", 7)
    end
    btn.Cooldown:SetHideCountdownNumbers(iconH < 14)

    -- Set cooldown from buttonInfo
    if btn.buttonInfo then
        local info = btn.buttonInfo
        if info.expirationTime and info.expirationTime > 0 and info.duration and info.duration > 0 then
            btn.Cooldown:SetCooldown(info.expirationTime - info.duration, info.duration)
        else
            btn.Cooldown:Clear()
        end
    end

    -- Apply Orbit skin (backdrop border)
    if Orbit.Skin and Orbit.Skin.Icons then
        Orbit.Skin.Icons.regionCache[btn] = nil
        Orbit.Skin.Icons:ApplyCustom(btn, skinSettings)
    end
end
