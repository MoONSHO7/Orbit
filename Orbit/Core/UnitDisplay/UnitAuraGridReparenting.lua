-- [ UNIT AURA GRID REPARENTING ]---------------------------------------------------------------------
-- Reparents Blizzard's native BuffFrame auraFrames into an Orbit grid container, suppresses the
-- stock textures/borders, wires timer + stacks text into Orbit's font/override system, and feeds
-- DurationObjects to the shared expiration pulse ticker.
--
-- Extracted from UnitAuraGridMixin.lua. Reaches file-local helpers (ResolveGrowthDirection,
-- UpdateCollapseArrow, CropIconTexture) through Mixin._Internal and the expiration pulse through
-- Mixin._RegisterExpirationPulse.

local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local Mixin = Orbit.UnitAuraGridMixin

local ResolveGrowthDirection = Mixin._Internal.ResolveGrowthDirection
local UpdateCollapseArrow = Mixin._Internal.UpdateCollapseArrow
local CropIconTexture = Mixin._Internal.CropIconTexture

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local TIMER_FONT_SIZE = 8
local COUNT_FONT_SIZE = 8
local MAX_AURA_SCAN = 40

-- [ HOISTED CLOSURES + SCRATCH STATE ]---------------------------------------------------------------
local _durCtx = { unit = nil, idx = 0, byIndex = nil }
local function _collectDur(aura)
    _durCtx.idx = _durCtx.idx + 1
    if aura.auraInstanceID then
        local durObj = C_UnitAuras.GetAuraDuration(_durCtx.unit, aura.auraInstanceID)
        if durObj then _durCtx.byIndex[_durCtx.idx] = durObj end
    end
end

local _playerCtx = { ids = nil }
local function _collectPlayerIDs(aura)
    _playerCtx.ids[aura.auraInstanceID] = true
end

local _showCtx = { excluded = nil, playerIDs = nil, showIndices = nil, idx = 0 }
local function _collectShowIndices(aura)
    _showCtx.idx = _showCtx.idx + 1
    local sid = aura.spellId
    local isExcluded = not issecretvalue(sid) and _showCtx.excluded[sid]
    if _showCtx.playerIDs[aura.auraInstanceID] and not isExcluded then
        _showCtx.showIndices[_showCtx.idx] = true
    end
end

local function ApplyComponentPosition(textElement, btn, key, defaultAnchorX, defaultAnchorY, defaultOffsetX, defaultOffsetY, componentPositions)
    if not textElement then return end
    local pos = componentPositions[key] or {}
    local anchorX = pos.anchorX or defaultAnchorX
    local anchorY = pos.anchorY or defaultAnchorY
    local offsetX = pos.offsetX or defaultOffsetX
    local offsetY = pos.offsetY or defaultOffsetY
    local justifyH = pos.justifyH or "CENTER"
    local anchorPoint
    if anchorY == "CENTER" and anchorX == "CENTER" then anchorPoint = "CENTER"
    elseif anchorY == "CENTER" then anchorPoint = anchorX
    elseif anchorX == "CENTER" then anchorPoint = anchorY
    else anchorPoint = anchorY .. anchorX end
    local textPoint = justifyH == "LEFT" and "LEFT" or justifyH == "RIGHT" and "RIGHT" or "CENTER"
    local finalOffsetX = anchorX == "LEFT" and offsetX or -offsetX
    local finalOffsetY = anchorY == "BOTTOM" and offsetY or -offsetY
    local btnW, btnH = btn:GetSize()
    local snapScale = btn:GetEffectiveScale() or 1
    finalOffsetX, finalOffsetY = OrbitEngine.Pixel:SnapPosition(finalOffsetX, finalOffsetY, textPoint, btnW, btnH, snapScale)
    textElement:ClearAllPoints()
    textElement:SetPoint(textPoint, btn, anchorPoint, finalOffsetX, finalOffsetY)
    if textElement.SetJustifyH then textElement:SetJustifyH(justifyH) end
end

-- [ UPDATE BLIZZARD BUFFS ]--------------------------------------------------------------------------
function Mixin:_updateBlizzardBuffs()
    local Frame = self._agFrame
    local cfg = self._agConfig
    if not Frame then return end
    if not self:IsEnabled() then return end
    if Orbit:IsEditMode() then return end

    local blizzFrame = cfg.blizzardFrame
    if not blizzFrame or not blizzFrame.auraFrames then return end

    local collapsed = cfg.showIconLimit and self:GetSetting(1, "Collapsed")
    local maxAuras, iconsPerRow, spacing, iconH, iconW = self:_resolveGrid()
    local anchor, growthX, growthY = ResolveGrowthDirection(Frame, cfg.showIconLimit)
    if Frame.collapseArrow then UpdateCollapseArrow(Frame.collapseArrow, collapsed, iconH, growthX, growthY) end

    -- When collapsed, build a set of HELPFUL indices that are player-cast and not excluded
    -- auraInstanceID is the ONLY non-secret field; use C-side filter HELPFUL|PLAYER to identify player auras
    -- spellId may be non-secret from clean context; use issecretvalue guard
    local showIndices
    if collapsed then
        local excludedSpells = Orbit.GroupAuraFilters and Orbit.GroupAuraFilters.AlwaysExcluded or {}
        Frame._scratchPlayerIDs = Frame._scratchPlayerIDs or {}
        wipe(Frame._scratchPlayerIDs)
        _playerCtx.ids = Frame._scratchPlayerIDs
        AuraUtil.ForEachAura("player", "HELPFUL|PLAYER", MAX_AURA_SCAN, _collectPlayerIDs, true)

        Frame._scratchShowIndices = Frame._scratchShowIndices or {}
        wipe(Frame._scratchShowIndices)
        showIndices = Frame._scratchShowIndices
        _showCtx.excluded = excludedSpells
        _showCtx.playerIDs = Frame._scratchPlayerIDs
        _showCtx.showIndices = showIndices
        _showCtx.idx = 0
        AuraUtil.ForEachAura("player", "HELPFUL", MAX_AURA_SCAN, _collectShowIndices, true)
    end

    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    local fontPath = (LSM and fontName and LSM:Fetch("font", fontName)) or "Fonts\\FRIZQT__.TTF"
    local fontOutline = Orbit.Skin and Orbit.Skin.GetFontOutline and Orbit.Skin:GetFontOutline() or ""
    local isPlayerGrid = self._agConfig and self._agConfig.unit == "player"
    local skinBorderSize = isPlayerGrid and (Orbit.db.GlobalSettings.IconBorderSize or 2) or 1
    local skinSettings = Frame._scratchSkinSettings
    if not skinSettings then
        skinSettings = {}
        Frame._scratchSkinSettings = skinSettings
    end
    skinSettings.zoom = 0
    skinSettings.borderStyle = 1
    skinSettings.borderSize = skinBorderSize
    skinSettings.showTimer = true
    skinSettings.iconBorder = isPlayerGrid or nil
    skinSettings.padding = spacing
    skinSettings.aspectRatio = self:GetSetting(1, "aspectRatio") or "1:1"
    local componentPositions = self:GetSetting(1, "ComponentPositions") or {}
    local OverrideUtils = OrbitEngine.OverrideUtils

    Frame._scratchDurObjByIndex = Frame._scratchDurObjByIndex or {}
    wipe(Frame._scratchDurObjByIndex)
    _durCtx.unit = cfg.unit
    _durCtx.idx = 0
    _durCtx.byIndex = Frame._scratchDurObjByIndex
    AuraUtil.ForEachAura(cfg.unit, "HELPFUL", MAX_AURA_SCAN, _collectDur, true)
    local durObjByIndex = Frame._scratchDurObjByIndex

    local skinVersion = (Frame._orbitSkinVersion or 0)
    Frame._scratchActiveIcons = Frame._scratchActiveIcons or {}
    local activeIcons = Frame._scratchActiveIcons
    wipe(activeIcons)
    local frameScale = Frame:GetEffectiveScale() or 1
    local snappedIconW = OrbitEngine.Pixel:Snap(iconW, frameScale)
    local snappedIconH = OrbitEngine.Pixel:Snap(iconH, frameScale)
    for _, btn in ipairs(blizzFrame.auraFrames) do
        if btn.hasValidInfo and not btn.isAuraAnchor then
            local bi = btn.buttonInfo
            -- When collapsed: hide temp enchants and non-player buffs
            local excluded = collapsed and (bi.auraType ~= "Buff" or not showIndices[bi.index])
            if excluded or #activeIcons >= maxAuras then
                if btn:GetParent() == Frame then
                    btn:SetParent(blizzFrame.AuraContainer)
                    btn._orbitSkinned = nil
                end
                btn:EnableMouse(false)
                btn:Hide()
            else
                -- Full setup only on first reparent or settings change
                if btn._orbitSkinned ~= skinVersion then
                    btn:SetParent(Frame)
                    btn:SetFrameLevel(Frame:GetFrameLevel() + Orbit.Constants.Levels.StatusBar)
                    btn:SetScale(1)
                    btn:SetAlpha(1)
                    btn:SetSize(snappedIconW, snappedIconH)
                    CropIconTexture(btn, snappedIconW, snappedIconH)
                    Orbit.Skin.Icons:ApplyCustom(btn, skinSettings)
                    btn.Duration:Hide()
                    btn:SetScript("OnUpdate", nil)
                    -- Permanently suppress Blizzard's native border textures
                    local nt = btn.GetNormalTexture and btn:GetNormalTexture() or btn.NormalTexture
                    if nt then
                        nt:SetAlpha(0); nt:Hide()
                        if not btn.orbitNormalTextureHooked then
                            hooksecurefunc(nt, "Show", function(self) self:Hide(); self:SetAlpha(0) end)
                            btn.orbitNormalTextureHooked = true
                        end
                    end

                    -- Permanently suppress standard Blizzard default borders
                    local nativeBorder = btn.Border or btn.IconBorder
                    if nativeBorder then
                        nativeBorder:SetAlpha(0); nativeBorder:Hide()
                        if not btn.orbitBorderHooked then
                            hooksecurefunc(nativeBorder, "Show", function(self) self:Hide(); self:SetAlpha(0) end)
                            btn.orbitBorderHooked = true
                        end
                    end

                    -- Suppress and hook Colored Borders (TempEnchants, Debuffs) into Orbit's pixel-perfect Highlight system
                    for _, b in ipairs({ {border=btn.TempEnchantBorder, key="_orbitTempEnchantBorder"}, {border=btn.DebuffBorder, key="_orbitDebuffBorder"} }) do
                        local nb = b.border
                        if nb then
                            local wasShown = nb:IsShown()
                            -- Proactively force the border rendering on if the button metadata confirms it is a TempEnchant,
                            -- completely bypassing Blizzard's notoriously deferred `TempEnchantBorder:Show()` pool delay (which causes 3-5s visual pop-in on /load)
                            if b.key == "_orbitTempEnchantBorder" and btn.buttonInfo and btn.buttonInfo.isTempEnchant then
                                wasShown = true
                            end
                            if not btn[b.key.."Hooked"] then
                                hooksecurefunc(nb, "Show", function(self)
                                    self:Hide(); self:SetAlpha(0)
                                    local r, g, b_color, a = self:GetVertexColor()
                                    if b.key == "_orbitTempEnchantBorder" then
                                        local q = btn.buttonInfo and (btn.buttonInfo.itemQuality or btn.buttonInfo.quality) or 4
                                        r, g, b_color = C_Item.GetItemQualityColor(q)
                                        a = 1
                                    end
                                    Orbit.Skin:ApplyHighlightBorder(btn, b.key, {r=r, g=g, b=b_color, a=a}, Orbit.Constants.Levels.IconOverlay + 1)
                                end)
                                hooksecurefunc(nb, "Hide", function(self)
                                    Orbit.Skin:ClearHighlightBorder(btn, b.key)
                                end)
                                hooksecurefunc(nb, "SetVertexColor", function(self, r, g, b_color, a)
                                    if b.key == "_orbitTempEnchantBorder" then
                                        local q = btn.buttonInfo and (btn.buttonInfo.itemQuality or btn.buttonInfo.quality) or 4
                                        r, g, b_color = C_Item.GetItemQualityColor(q)
                                        a = 1
                                    end
                                    Orbit.Skin:ApplyHighlightBorder(btn, b.key, {r=r, g=g, b=b_color, a=a}, Orbit.Constants.Levels.IconOverlay + 1)
                                end)
                                btn[b.key.."Hooked"] = true
                            end
                            nb:SetAlpha(0); nb:Hide()

                            -- Initial Sync
                            local r, g, b_color, a = nb:GetVertexColor()
                            if b.key == "_orbitTempEnchantBorder" then
                                local q = btn.buttonInfo and (btn.buttonInfo.itemQuality or btn.buttonInfo.quality) or 4
                                r, g, b_color = C_Item.GetItemQualityColor(q)
                                a = 1
                            end

                            if wasShown then
                                Orbit.Skin:ApplyHighlightBorder(btn, b.key, {r=r, g=g, b=b_color, a=a}, Orbit.Constants.Levels.IconOverlay + 1)
                            else
                                Orbit.Skin:ClearHighlightBorder(btn, b.key)
                            end
                        end
                    end
                    -- Cooldown frame for timer
                    if not btn.Cooldown then
                        btn.Cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
                        btn.Cooldown:SetAllPoints()
                        btn.Cooldown:SetHideCountdownNumbers(false)
                        btn.Cooldown:EnableMouse(false)
                        btn.cooldown = btn.Cooldown
                    end
                    -- Text overlay above border
                    if not btn.orbitTextOverlay then
                        btn.orbitTextOverlay = CreateFrame("Frame", nil, btn)
                        btn.orbitTextOverlay:SetAllPoints(btn)
                        btn.orbitTextOverlay:SetFrameLevel(btn:GetFrameLevel() + Orbit.Constants.Levels.IconOverlay)
                    end
                    -- Style timer text
                    local timerText = btn.Cooldown.Text
                    if not timerText then
                        for _, region in pairs({ btn.Cooldown:GetRegions() }) do
                            if region:IsObjectType("FontString") then timerText = region; break end
                        end
                        btn.Cooldown.Text = timerText
                    end
                    if timerText and timerText.SetFont then
                        timerText:SetParent(btn.orbitTextOverlay)
                        if OverrideUtils then OverrideUtils.ApplyOverrides(timerText, (componentPositions.Timer or {}).overrides or {}, { fontSize = TIMER_FONT_SIZE, fontPath = fontPath }) end
                        timerText:SetDrawLayer("OVERLAY", 7)
                        ApplyComponentPosition(timerText, btn, "Timer", "CENTER", "CENTER", 0, 0, componentPositions)
                    end
                    -- Style stacks
                    btn.Count:SetParent(btn.orbitTextOverlay)
                    if OverrideUtils then OverrideUtils.ApplyOverrides(btn.Count, (componentPositions.Stacks or {}).overrides or {}, { fontSize = COUNT_FONT_SIZE, fontPath = fontPath }) end
                    Orbit.Skin:ApplyFontShadow(btn.Count)
                    btn.Count:SetDrawLayer("OVERLAY", 7)
                    ApplyComponentPosition(btn.Count, btn, "Stacks", "RIGHT", "BOTTOM", 1, 1, componentPositions)
                    btn._orbitSkinned = skinVersion
                end
                btn:EnableMouse(true)
                btn:SetSize(snappedIconW, snappedIconH)
                CropIconTexture(btn, snappedIconW, snappedIconH)
                btn.Cooldown:Clear()
                if btn.Cooldown.Text then btn.Cooldown.Text:SetText("") end
                local durObj = bi and bi.index and durObjByIndex[bi.index]
                if durObj then btn.Cooldown:SetCooldownFromDurationObject(durObj) end
                -- Expiration pulse: stash DurationObject for the pulse ticker
                if durObj then Mixin._RegisterExpirationPulse(btn, durObj) else btn._orbitExpireDurObj = nil; btn:SetAlpha(1) end
                btn:Show()
                table.insert(activeIcons, btn)
            end
        end
    end

    if #activeIcons == 0 then
        if Frame._gridGroupBorder then Frame._gridGroupBorder:Hide() end
        return
    end
    Frame._scratchLayoutOpts = Frame._scratchLayoutOpts or {}
    local opts = Frame._scratchLayoutOpts
    opts.size = iconH; opts.sizeW = iconW; opts.spacing = spacing; opts.maxPerRow = iconsPerRow
    opts.anchor = anchor; opts.growthX = growthX; opts.growthY = growthY; opts.yOffset = 0
    Orbit.AuraLayout:LayoutGrid(Frame, activeIcons, opts)
    skinSettings._maxPerRow = iconsPerRow
    skinSettings._growthX = growthX
    skinSettings._growthY = growthY
    self:_applyGridGroupBorder(Frame, activeIcons, spacing, skinSettings)
end
