-- [ ORBIT ICON SKINNING ]--------------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local Icons = {}
Skin.Icons = Icons

local Constants = Orbit.Constants
local Pixel = Orbit.Engine.Pixel

Icons.iconSettings = setmetatable({}, { __mode = "k" })
Icons.regionCache = setmetatable({}, { __mode = "k" })
Icons.borderCache = setmetatable({}, { __mode = "k" })
local IM = Skin.IconMonitor
local IL = Skin.IconLayout

-- [ APPLY & MONITORING ]----------------------------------------------------------------------------
function Icons:Apply(frame, settings)
    if not frame then return end
    local CM = Orbit and Orbit.CombatManager
    if CM and CM:IsInCombat() then CM:QueueUpdate(function() self:Apply(frame, settings) end); return end
    self.frameSettings = self.frameSettings or setmetatable({}, { __mode = "k" })
    self.frameSettings[frame] = settings
    if not IM:IsMonitored(frame) then IM:Start(frame, function(f) self:SkinIcons(f) end) end
    self:SkinIcons(frame)
end

function Icons:SkinIcons(frame)
    local CM = Orbit and Orbit.CombatManager
    if CM and CM:IsInCombat() then CM:QueueUpdate(function() self:SkinIcons(frame) end); return end
    local s = self.frameSettings and self.frameSettings[frame]
    if not s then return end
    local icons = {}
    if frame.GetLayoutChildren then icons = frame:GetLayoutChildren()
    elseif frame.icons then icons = frame.icons
    else icons = { frame:GetChildren() } end
    for _, icon in ipairs(icons) do
        if icon then
            self.iconSettings[icon] = s
            self:ApplyCustom(icon, s)
        end
    end
    if not InCombatLockdown() and s.padding then IL:ApplyManualLayout(frame, icons, s) end
end

-- [ REGION DISCOVERY ]------------------------------------------------------------------------------
function Icons:FindRegions(icon)
    if self.regionCache[icon] then return self.regionCache[icon] end
    local regions = {
        icon = icon.Icon or icon.icon, cooldown = icon.Cooldown,
        outOfRange = icon.OutOfRange or icon.outOfRange,
        border = icon.Border or icon.IconBorder,
        proc = icon.SpellActivationAlert, pandemic = icon.PandemicIcon,
        mask = nil, masks = {},
    }
    if icon.IconMask then table.insert(regions.masks, icon.IconMask); regions.mask = icon.IconMask end
    local kids = { icon:GetRegions() }
    for _, region in ipairs(kids) do
        local objType = region:GetObjectType()
        if objType == "Texture" then
            local atlas = region:GetAtlas()
            local name = region:GetName()
            if atlas == Constants.Atlases.CooldownBorder then regions.border = region
            elseif not regions.icon then
                if name and (string.find(name, "Icon") or string.find(name, "icon")) then regions.icon = region end
            end
        elseif objType == "MaskTexture" then
            regions.mask = region
            local exists = false
            for _, m in ipairs(regions.masks) do if m == region then exists = true; break end end
            if not exists then table.insert(regions.masks, region) end
        end
    end
    if not regions.icon then
        for _, region in ipairs(kids) do
            if region:IsObjectType("Texture") and region ~= regions.border and region ~= regions.procs then
                local layer = region:GetDrawLayer()
                if layer == "BACKGROUND" or layer == "BORDER" or layer == "ARTWORK" then regions.icon = region; break end
            end
        end
    end
    local children = { icon:GetChildren() }
    for _, child in ipairs(children) do
        if not regions.flash and (child == icon.CooldownFlash or (child:GetName() and string.find(child:GetName(), "CooldownFlash"))) then regions.flash = child end
        if not regions.proc and (child == icon.SpellActivationAlert) then regions.proc = child end
    end
    self.regionCache[icon] = regions
    return regions
end

-- [ ICON SKINNING ]---------------------------------------------------------------------------------
function Icons:ApplyCustom(icon, settings)
    if icon.SetScale then icon:SetScale(1) end
    local r = self:FindRegions(icon)
    local tex = r.icon
    if tex then
        local newWidth, newHeight, rw, rh = IL:CalculateGeometry(icon, settings)
        local scale = icon:GetEffectiveScale()
        newWidth = Pixel:Snap(newWidth, scale)
        newHeight = Pixel:Snap(newHeight, scale)
        Skin:SkinIcon(tex, settings)
        local trim = Constants.Texture.BlizzardIconBorderTrim
        local zoom = settings.zoom or 0
        trim = trim + ((zoom / 100) / 2)
        local left, right, top, bottom = trim, 1 - trim, trim, 1 - trim
        local validW, validH = right - left, bottom - top
        if rw > rh then
            local newH = validW * (rh / rw)
            local centerY = (top + bottom) / 2
            top, bottom = centerY - (newH / 2), centerY + (newH / 2)
        elseif rh > rw then
            local newW = validH * (rw / rh)
            local centerX = (left + right) / 2
            left, right = centerX - (newW / 2), centerX + (newW / 2)
        end
        if tex.SetTexCoord then tex:SetTexCoord(left, right, top, bottom) end
        icon:SetSize(newWidth, newHeight)
        tex:ClearAllPoints()
        tex:SetAllPoints(icon)
        if r.masks then
            for _, mask in ipairs(r.masks) do
                if tex.RemoveMaskTexture then tex:RemoveMaskTexture(mask) end
                mask:Hide()
            end
        elseif r.mask then
            if tex.RemoveMaskTexture then tex:RemoveMaskTexture(r.mask) end
            r.mask:Hide()
        end
        if icon.IconMask then
            if tex.RemoveMaskTexture then tex:RemoveMaskTexture(icon.IconMask) end
            icon.IconMask:Hide()
        end
        if icon.spellOutOfRange and icon.RefreshIconColor then icon:RefreshIconColor() end
        if r.cooldown then
            r.cooldown:ClearAllPoints()
            r.cooldown:SetAllPoints(icon)
            local desiredTexture = Constants.Assets.SwipeCustom
            local desiredColor = settings.swipeColor or { r = 0, g = 0, b = 0, a = 0.8 }
            r.cooldown.orbitDesiredSwipe = { texture = desiredTexture, r = desiredColor.r, g = desiredColor.g, b = desiredColor.b, a = desiredColor.a }
            r.cooldown.orbitUpdating = true
            r.cooldown:SetSwipeTexture(desiredTexture)
            if r.cooldown.SetSwipeColor then r.cooldown:SetSwipeColor(desiredColor.r, desiredColor.g, desiredColor.b, desiredColor.a) end
            r.cooldown.orbitUpdating = false
            if not r.cooldown.orbitHooked then
                hooksecurefunc(r.cooldown, "SetSwipeTexture", function(self, texture)
                    if self.orbitUpdating then return end
                    local desired = self.orbitDesiredSwipe
                    if not desired then return end
                    if texture ~= desired.texture then
                        self.orbitUpdating = true
                        self:SetSwipeTexture(desired.texture)
                        self.orbitUpdating = false
                    end
                end)
                if r.cooldown.SetSwipeColor then
                    hooksecurefunc(r.cooldown, "SetSwipeColor", function(self, cr, cg, cb, ca)
                        if self.orbitUpdating then return end
                        local desired = self.orbitDesiredSwipe
                        if not desired then return end
                        if cr ~= desired.r or cg ~= desired.g or cb ~= desired.b or ca ~= desired.a then
                            self.orbitUpdating = true
                            self:SetSwipeColor(desired.r, desired.g, desired.b, desired.a)
                            self.orbitUpdating = false
                        end
                    end)
                end
                r.cooldown.orbitHooked = true
            end
        end
        if r.flash then
            r.flash:ClearAllPoints()
            r.flash:SetAllPoints(icon)
            r.flash:SetFrameStrata("HIGH")
            r.flash:SetFrameLevel(50)
            if r.flash.Flipbook then
                r.flash.Flipbook:ClearAllPoints()
                r.flash.Flipbook:SetPoint("CENTER")
                r.flash.Flipbook:SetSize(newWidth * Constants.IconScale.FlashScale, newHeight * Constants.IconScale.FlashScale)
            end
        end
        if r.pandemic then
            r.pandemic:ClearAllPoints()
            r.pandemic:SetPoint("CENTER")
            r.pandemic:SetSize(newWidth + Constants.IconScale.PandemicPadding, newHeight + Constants.IconScale.PandemicPadding)
            r.pandemic:SetFrameStrata("HIGH")
            r.pandemic:SetFrameLevel(50)
        end
        local borderStyle = settings.borderStyle or 0
        local bScale = icon:GetEffectiveScale() or 1
        local borderSize = settings.borderSize or (Pixel and Pixel:Multiple(1, bScale) or 1)
        if r.border then
            if borderStyle == 1 then r.border:SetAlpha(0)
            else
                r.border:SetAlpha(1)
                r.border:ClearAllPoints()
                r.border:SetPoint("CENTER")
                r.border:SetSize(newWidth + Constants.IconScale.BorderPaddingH, newHeight + Constants.IconScale.BorderPaddingV)
            end
        end
        if borderStyle == 1 then
            if not self.borderCache[icon] then self.borderCache[icon] = Skin:CreateBackdrop(icon, nil) end
            local b = self.borderCache[icon]
            b:SetFrameStrata("MEDIUM")
            b:SetFrameLevel(icon:GetFrameLevel() + 5)
            b:Show()
            Skin:SkinBorder(icon, b, borderSize, { r = 0, g = 0, b = 0, a = 1 })
        else
            if self.borderCache[icon] then self.borderCache[icon]:Hide() end
        end
    end
    if icon.Cooldown and icon.Cooldown.SetHideCountdownNumbers then
        icon.Cooldown:SetHideCountdownNumbers(not (settings.showTimer ~= false))
    end
    if icon.DebuffBorder then icon.DebuffBorder:SetAlpha(0); icon.DebuffBorder:Hide() end
    if settings.showTooltip == false then
        if not icon.orbitTooltipHooked then
            icon:HookScript("OnEnter", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
            icon.orbitTooltipHooked = true
        end
    end
end
