-- RaidPanelIcon.lua: Circular icon factory + per-slot configure for the Raid Panel dock.

local _, Orbit = ...
local OrbitEngine = Orbit.Engine

local InCombatLockdown = InCombatLockdown
local math_floor = math.floor

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local INITIAL_ICON_SIZE       = 32
local ICON_BORDER_SCALE       = 1.1
local CIRCULAR_MASK_PATH      = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local BORDER_ATLAS_SILVER     = "talents-node-choiceflyout-circle-gray"
local WHITE_TEXTURE           = "Interface\\Buttons\\WHITE8x8"

local HOVER_TINT_R = 1.0
local HOVER_TINT_G = 0.95
local HOVER_TINT_B = 0.70
local HOVER_TINT_A = 0.35

local PUSHED_TINT  = 0.85

local SHEEN_ATLAS              = "talents-sheen-node"
local SHEEN_WIDTH_SCALE        = 1.0
local SHEEN_SWEEP_DURATION     = 0.5
local SHEEN_FADEIN_DURATION    = 0.15
local SHEEN_FADEOUT_DURATION   = 0.20
local SHEEN_FADEOUT_START      = 0.30
local SHEEN_PEAK_ALPHA         = 0.85

local CLICK_SOUND_KIT = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 856

-- [ MODULE ] ----------------------------------------------------------------------------------------
Orbit.RaidPanelIcon = {}
local Icon = Orbit.RaidPanelIcon

local function ApplyMask(tex, mask)
    if tex and not tex._raidPanelMasked then
        tex:AddMaskTexture(mask)
        tex._raidPanelMasked = true
    end
end

local SHAPE_CIRCLE = 1

local function GetBackdropColor()
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local c = gs and gs.BackdropColour
    if c then return c.r or 0, c.g or 0, c.b or 0, c.a or 1 end
    return 0.145, 0.145, 0.145, 0.7
end

function Icon.ApplyShape(icon, shape, mergeBorders)
    if shape == SHAPE_CIRCLE then
        icon.mask:SetTexture(CIRCULAR_MASK_PATH, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        icon.background:SetVertexColor(GetBackdropColor())
        icon.background:Show()
        icon.border:Show()
        if icon._borderFrame then icon._borderFrame:Hide() end
        if icon._edgeBorderOverlay then icon._edgeBorderOverlay:Hide() end
    else
        icon.mask:SetTexture(WHITE_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        icon.border:Hide()
        if mergeBorders then
            icon.background:Hide()
            if icon._borderFrame then icon._borderFrame:Hide() end
            if icon._edgeBorderOverlay then icon._edgeBorderOverlay:Hide() end
        else
            icon.background:SetVertexColor(GetBackdropColor())
            icon.background:Show()
            if Orbit.Skin and Orbit.Skin.SkinBorder then
                Orbit.Skin:SkinBorder(icon, icon, nil, nil, true)
            end
        end
    end
end

function Icon.Create(plugin, dockFrame, ctx)
    local Menus = Orbit.RaidPanelMenus

    local icon = CreateFrame("Button", nil, dockFrame, "SecureActionButtonTemplate")
    icon:RegisterForClicks("AnyUp")
    icon:SetSize(INITIAL_ICON_SIZE, INITIAL_ICON_SIZE)
    OrbitEngine.Pixel:Enforce(icon)

    icon.mask = icon:CreateMaskTexture()
    icon.mask:SetAllPoints()
    icon.mask:SetTexture(CIRCULAR_MASK_PATH, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    icon.background = icon:CreateTexture(nil, "BACKGROUND")
    icon.background:SetAllPoints()
    icon.background:SetTexture(WHITE_TEXTURE)
    icon.background:AddMaskTexture(icon.mask)

    icon.sheen = icon:CreateTexture(nil, "ARTWORK", nil, 6)
    icon.sheen:SetAtlas(SHEEN_ATLAS)
    icon.sheen:SetBlendMode("ADD")
    icon.sheen:AddMaskTexture(icon.mask)
    icon.sheen:SetAlpha(0)

    icon.sheenAnim = icon.sheen:CreateAnimationGroup()
    icon.sheenTranslate = icon.sheenAnim:CreateAnimation("Translation")
    icon.sheenTranslate:SetDuration(SHEEN_SWEEP_DURATION)
    icon.sheenTranslate:SetOrder(1)
    icon.sheenFadeIn = icon.sheenAnim:CreateAnimation("Alpha")
    icon.sheenFadeIn:SetFromAlpha(0)
    icon.sheenFadeIn:SetToAlpha(SHEEN_PEAK_ALPHA)
    icon.sheenFadeIn:SetDuration(SHEEN_FADEIN_DURATION)
    icon.sheenFadeIn:SetOrder(1)
    icon.sheenFadeOut = icon.sheenAnim:CreateAnimation("Alpha")
    icon.sheenFadeOut:SetFromAlpha(SHEEN_PEAK_ALPHA)
    icon.sheenFadeOut:SetToAlpha(0)
    icon.sheenFadeOut:SetDuration(SHEEN_FADEOUT_DURATION)
    icon.sheenFadeOut:SetStartDelay(SHEEN_FADEOUT_START)
    icon.sheenFadeOut:SetOrder(1)

    icon.border = icon:CreateTexture(nil, "OVERLAY")
    icon.border:SetPoint("CENTER")
    icon.border:SetAtlas(BORDER_ATLAS_SILVER, false)

    icon:SetScript("OnEnter", function(self)
        if self.slotData then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.slotData.label or "")
            if self.slotData.kind == "marker" then
                GameTooltip:AddLine(Orbit.L.PLU_RAIDPANEL_MARKER_HINT, 1, 0.82, 0, true)
            end
            GameTooltip:Show()
        end
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    icon:SetScript("PostClick", function(self, button)
        if self.sheenAnim then self.sheenAnim:Stop(); self.sheenAnim:Play() end
        PlaySound(CLICK_SOUND_KIT)
        if button == "LeftButton" then
            local data = self.slotData
            if data then
                if data.kind == "menu" then
                    Menus.Open(data.menuKey, self, ctx)
                elseif data.action then
                    data.action()
                end
            end
        end
    end)

    return icon
end

local function SizeInner(tex, iconSize, sizeMult)
    if not tex then return end
    local s = iconSize * (sizeMult or 1)
    tex:ClearAllPoints()
    tex:SetSize(s, s)
    tex:SetPoint("CENTER")
end

local function ApplySpriteCell(tex, cell)
    if not tex or not cell then return end
    if cell.index then
        tex:SetSpriteSheetCell(cell.index, cell.rows, cell.cols)
    elseif cell.row and cell.col then
        local idx = (cell.row - 1) * cell.cols + cell.col
        tex:SetSpriteSheetCell(idx, cell.rows, cell.cols)
    end
end

local function ApplyMarkerSprite(tex, i)
    local PD = Orbit.RaidPanelData
    local col = (i - 1) % PD.RAID_TARGET_COLUMNS
    local row = math_floor((i - 1) / PD.RAID_TARGET_COLUMNS)
    local w, h = 1 / PD.RAID_TARGET_COLUMNS, 1 / PD.RAID_TARGET_ROWS
    tex:SetTexture(PD.RAID_TARGET_TEXTURE)
    tex:SetTexCoord(col * w, (col + 1) * w, row * h, (row + 1) * h)
end

local function ApplyAtlasState(tex, atlas, iconSize, mult, mask, spriteCell)
    tex:SetAtlas(atlas, false, nil, true)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:SetBlendMode("BLEND")
    ApplySpriteCell(tex, spriteCell)
    SizeInner(tex, iconSize, mult)
    ApplyMask(tex, mask)
end

local function ApplyAtlasIcon(icon, slotData, iconSize)
    local mult = slotData.sizeMult
    local PD = Orbit.RaidPanelData
    local atlasNormal, atlasHover, atlasPressed
    if slotData.dynamic == "difficulty" then
        local fam = PD.GetCurrentDifficultyAtlases()
        atlasNormal, atlasHover, atlasPressed = fam.normal, fam.pressed, fam.pressed
    else
        atlasNormal, atlasHover, atlasPressed = slotData.atlas, slotData.atlasHover, slotData.atlasPressed
    end

    if atlasNormal then
        icon:SetNormalAtlas(atlasNormal)
        ApplyAtlasState(icon:GetNormalTexture(), atlasNormal, iconSize, mult, icon.mask, slotData.spriteSheetCell)
    end

    if atlasHover then
        icon:SetHighlightAtlas(atlasHover)
        ApplyAtlasState(icon:GetHighlightTexture(), atlasHover, iconSize, mult, icon.mask, slotData.spriteSheetCell)
    else
        icon:SetHighlightTexture(WHITE_TEXTURE)
        local ht = icon:GetHighlightTexture()
        ht:SetTexCoord(0, 1, 0, 1)
        ht:SetVertexColor(HOVER_TINT_R, HOVER_TINT_G, HOVER_TINT_B, HOVER_TINT_A)
        ht:SetBlendMode("ADD")
        SizeInner(ht, iconSize, 1)
        ApplyMask(ht, icon.mask)
    end

    local pressedAtlas = atlasPressed or atlasNormal
    if pressedAtlas then
        icon:SetPushedAtlas(pressedAtlas)
        ApplyAtlasState(icon:GetPushedTexture(), pressedAtlas, iconSize, mult, icon.mask, slotData.spriteSheetCell)
    end
end

local function ApplyMarkerIcon(icon, slotData, iconSize)
    local mult = slotData.sizeMult
    local i = slotData.markerIndex

    icon:SetNormalTexture(WHITE_TEXTURE)
    local nt = icon:GetNormalTexture()
    ApplyMarkerSprite(nt, i)
    nt:SetVertexColor(1, 1, 1)
    SizeInner(nt, iconSize, mult)
    ApplyMask(nt, icon.mask)

    icon:SetPushedTexture(WHITE_TEXTURE)
    local pt = icon:GetPushedTexture()
    ApplyMarkerSprite(pt, i)
    pt:SetVertexColor(PUSHED_TINT, PUSHED_TINT, PUSHED_TINT)
    SizeInner(pt, iconSize, mult)
    ApplyMask(pt, icon.mask)

    icon:SetHighlightTexture(WHITE_TEXTURE)
    local ht = icon:GetHighlightTexture()
    ht:SetTexture(WHITE_TEXTURE)
    ht:SetTexCoord(0, 1, 0, 1)
    ht:SetVertexColor(HOVER_TINT_R, HOVER_TINT_G, HOVER_TINT_B, HOVER_TINT_A)
    SizeInner(ht, iconSize, 1)
    ht:SetBlendMode("ADD")
    ApplyMask(ht, icon.mask)
end

local function ApplyIconArtwork(icon, slotData, iconSize)
    if slotData.kind == "marker" then
        ApplyMarkerIcon(icon, slotData, iconSize)
        return
    end
    ApplyAtlasIcon(icon, slotData, iconSize)
end

function Icon.Configure(plugin, icon, slotData, ctx, iconSize)
    icon.slotData = slotData

    iconSize = iconSize or plugin:GetSetting(1, "IconSize")
    icon:SetSize(iconSize, iconSize)
    local iconScale = icon:GetEffectiveScale()

    Icon.ApplyShape(icon, plugin:GetSetting(1, "DisplayShape") or SHAPE_CIRCLE, ctx.mergeBorders)

    local borderSize = OrbitEngine.Pixel:Snap(iconSize * ICON_BORDER_SCALE, iconScale)
    icon.border:SetSize(borderSize, borderSize)

    if icon.sheen then
        local sheenW = OrbitEngine.Pixel:Snap(iconSize * SHEEN_WIDTH_SCALE, iconScale)
        icon.sheen:SetSize(sheenW, iconSize)
        icon.sheen:ClearAllPoints()
        icon.sheen:SetPoint("RIGHT", icon, "LEFT", 0, 0)
        if icon.sheenTranslate then
            icon.sheenTranslate:SetOffset(OrbitEngine.Pixel:Snap(iconSize + sheenW, iconScale), 0)
        end
    end

    ApplyIconArtwork(icon, slotData, iconSize)
    Icon.ApplySecureAttributes(icon, slotData, ctx.isEditModeActive)
end

function Icon.ApplySecureAttributes(icon, slotData, isEditMode)
    if InCombatLockdown() then return end

    if isEditMode then
        icon:SetAttribute("type1", nil)
        icon:SetAttribute("shift-type1", nil)
        icon:EnableMouse(false)
        return
    end
    icon:EnableMouse(true)

    if slotData.kind == "marker" then
        icon:SetAttribute("type1", "raidtarget")
        icon:SetAttribute("shift-type1", "worldmarker")
        icon:SetAttribute("marker", slotData.markerIndex)
        icon:SetAttribute("action1", nil)
    elseif slotData.kind == "clearmarkers" then
        icon:SetAttribute("type1", "worldmarker")
        icon:SetAttribute("shift-type1", nil)
        icon:SetAttribute("marker", nil)
        icon:SetAttribute("action1", "clear")
    else
        icon:SetAttribute("type1", nil)
        icon:SetAttribute("shift-type1", nil)
        icon:SetAttribute("marker", nil)
        icon:SetAttribute("action1", nil)
    end
end
