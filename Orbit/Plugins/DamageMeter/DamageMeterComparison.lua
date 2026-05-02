---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Pixel = Orbit.Engine.Pixel
local Constants = Orbit.Constants
local LSM = LibStub("LibSharedMedia-3.0", true)

-- [ DAMAGE METER COMPARISON ] -----------------------------------------------------------------------
local DM = Constants.DamageMeter

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local FRAME_NAME         = "OrbitDamageMeterComparison"
local WINDOW_WIDTH       = 560
local WINDOW_MAX_H       = 640
local WINDOW_FRAME_LEVEL = 200
local EDGE_PAD           = 20
local ICON_SIZE          = 20
local ICON_BAR_GAP       = 8
local SECTION_ROW_H      = 20
local BAR_STACK_H        = 18
local SECTION_GAP        = 4
-- Mythic+ "Gold Timer" crown atlases — tried in order. First one that resolves wins.
-- Different clients version these atlases differently; falling back to a plain spell-icon
-- texture guarantees SOMETHING renders.
local OVERALL_CROWN_ATLASES = {
    "challenges-medal-gold",
}
local OVERALL_CROWN_TEXTURE = "Interface\\Icons\\INV_Crown_03"
local DIVIDER_HEIGHT        = 1
local DIVIDER_MARGIN_Y      = 6
local TITLE_Y            = -15
local TITLE_ROW_HEIGHT   = 42
local LEGEND_HEIGHT      = 24
local LEGEND_GAP         = 10
local LEGEND_SWATCH      = 14
local LEGEND_FONT_SIZE   = 13
local MAX_COLUMNS        = 5
local HEADER_FONT_SIZE   = 11
local ROW_FONT_SIZE      = 12
local ESC_RESTORE_DELAY  = 0.05

local METER_TYPE_LABEL_KEY = {
    [DM.MeterType.DamageDone]            = "PLU_DM_METRIC_DAMAGE",
    [DM.MeterType.Dps]                   = "PLU_DM_METRIC_DAMAGE",
    [DM.MeterType.HealingDone]           = "PLU_DM_METRIC_HEALING",
    [DM.MeterType.Hps]                   = "PLU_DM_METRIC_HEALING",
    [DM.MeterType.DamageTaken]           = "PLU_DM_METRIC_DAMAGETAKEN",
    [DM.MeterType.AvoidableDamageTaken]  = "PLU_DM_METRIC_AVOIDABLEDAMAGE",
    [DM.MeterType.EnemyDamageTaken]      = "PLU_DM_METRIC_ENEMYDAMAGETAKEN",
    [DM.MeterType.Interrupts]            = "PLU_DM_METRIC_INTERRUPTS",
    [DM.MeterType.Dispels]               = "PLU_DM_METRIC_DISPELS",
    [DM.MeterType.Deaths]                = "PLU_DM_METRIC_DEATHS",
}

local PLAYER_COLORS = {
    { 0.26, 0.52, 0.96 }, -- blue
    { 0.92, 0.35, 0.30 }, -- red
    { 0.95, 0.76, 0.03 }, -- amber
    { 0.30, 0.72, 0.40 }, -- green
    { 0.72, 0.40, 0.86 }, -- violet
}
local function ColorFor(i)
    local c = PLAYER_COLORS[((i - 1) % #PLAYER_COLORS) + 1]
    return c[1], c[2], c[3]
end

local Plugin = Orbit:GetPlugin(DM.SystemID)
if not Plugin then return end

-- [ SPEC / CLASS LOOKUP ] ---------------------------------------------------------------------------
-- Reverse map from specIconID (fileID) → localized spec name. Built lazily on first open;
-- the data is static so one pass over GetNumClasses × GetNumSpecializationsForClassID suffices.
local SPEC_ICON_TO_NAME
local function GetSpecNameByIcon(iconID)
    if not iconID then return nil end
    if not SPEC_ICON_TO_NAME then
        SPEC_ICON_TO_NAME = {}
        local numClasses = GetNumClasses and GetNumClasses() or 0
        for classID = 1, numClasses do
            local numSpecs = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID
                and C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 0
            for specIndex = 1, numSpecs do
                local _, specName, _, icon = GetSpecializationInfoForClassID(classID, specIndex)
                if icon then SPEC_ICON_TO_NAME[icon] = specName end
            end
        end
    end
    return SPEC_ICON_TO_NAME[iconID]
end

local function GetLocalizedClassName(classFilename)
    if not classFilename or classFilename == "" then return nil end
    return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFilename] or classFilename
end

-- [ MEDIA HELPERS ] ---------------------------------------------------------------------------------
local function GetBarTexture()
    if not LSM then return "Interface\\TargetingFrame\\UI-StatusBar" end
    local name = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Texture
    return (name and LSM:Fetch("statusbar", name)) or "Interface\\TargetingFrame\\UI-StatusBar"
end

local function GetFont()
    if not LSM then return STANDARD_TEXT_FONT end
    local name = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    return (name and LSM:Fetch("font", name)) or STANDARD_TEXT_FONT
end

local function GetFontOutline()
    return (Orbit.Skin and Orbit.Skin:GetFontOutline()) or "OUTLINE"
end

-- [ CANDIDATE ENUMERATION ] -------------------------------------------------------------------------
-- source.sourceGUID is ConditionalSecret in combat; out-of-combat only.
local function GetSpecMatches(def, originSource)
    if not originSource or InCombatLockdown() then return {} end
    local Data = OrbitEngine.DamageMeterData
    if not Data or not Data:IsAvailable() then return {} end
    local session = Data:ResolveSession(def.sessionID, def.sessionType, def.meterType)
    if not session or not session.combatSources then return {} end
    local targetSpec = originSource.specIconID
    if not targetSpec or targetSpec == 0 then return {} end

    local matches = { originSource }
    for _, source in ipairs(session.combatSources) do
        if source ~= originSource
           and source.sourceGUID ~= originSource.sourceGUID
           and source.specIconID == targetSpec
        then
            matches[#matches + 1] = source
            if #matches >= MAX_COLUMNS then break end
        end
    end
    return matches
end

-- Returns union sorted by origin's amounts so "why am I doing less X than them" stays at the top.
local function GatherSpellMatrix(def, candidates)
    local Data = OrbitEngine.DamageMeterData
    local perPlayer = {}
    local unionByID = {}
    local originAmounts = {}

    for i, source in ipairs(candidates) do
        local slot = { source = source, spellAmounts = {}, spellDPS = {}, totalDamage = 0 }
        local sourceData = Data and Data:ResolveSessionSource(
            def.sessionID, def.sessionType, def.meterType,
            source.sourceGUID, source.sourceCreatureID
        )
        if sourceData and sourceData.combatSpells then
            for _, spell in ipairs(sourceData.combatSpells) do
                local id = spell.spellID
                if id then
                    local amount = spell.totalAmount or 0
                    slot.spellAmounts[id] = amount
                    slot.spellDPS[id]     = spell.amountPerSecond or 0
                    slot.totalDamage      = slot.totalDamage + amount
                    unionByID[id]         = (unionByID[id] or 0) + amount
                    if i == 1 then originAmounts[id] = amount end
                end
            end
        end
        perPlayer[i] = slot
    end

    local order = {}
    for id in pairs(unionByID) do order[#order + 1] = id end
    table.sort(order, function(a, b)
        local oa = originAmounts[a] or -1
        local ob = originAmounts[b] or -1
        if oa ~= ob then return oa > ob end
        return (unionByID[a] or 0) > (unionByID[b] or 0)
    end)

    return perPlayer, order
end

-- [ UI HELPERS ] ------------------------------------------------------------------------------------
local function AbbreviateAmount(n)
    if not n or n <= 0 then return "" end
    if AbbreviateNumbers then return AbbreviateNumbers(n) end
    return tostring(n)
end

local function LongAmount(n)
    if not n or n <= 0 then return "0" end
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    return tostring(n)
end

local function GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name and name ~= "" then return name end
    end
    if _G.GetSpellInfo then
        local name = _G.GetSpellInfo(spellID)
        if name and name ~= "" then return name end
    end
    return "?"
end

local function GetSpellTexture(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(spellID)
        if tex then return tex end
    end
    if _G.GetSpellTexture then return _G.GetSpellTexture(spellID) end
end

local function ShortName(fullName)
    if not fullName or fullName == "" then return "?" end
    local dash = fullName:find("-", 1, true)
    return dash and fullName:sub(1, dash - 1) or fullName
end

-- [ FRAME CONSTRUCTION ] ----------------------------------------------------------------------------
local compareFrame

local function EnsureFrame()
    if compareFrame then return compareFrame end
    local f = CreateFrame("Frame", FRAME_NAME, UIParent)
    Pixel:Enforce(f)
    f:SetSize(WINDOW_WIDTH, 400)
    -- Center on first open, then pin TOPLEFT so subsequent SetHeight calls extend the bottom
    -- edge downward instead of re-centering (which would make the top creep up/down).
    local sw = UIParent and UIParent:GetWidth() or (GetScreenWidth and GetScreenWidth()) or 1920
    local sh = UIParent and UIParent:GetHeight() or (GetScreenHeight and GetScreenHeight()) or 1080
    local openHeight = 500
    local offsetX = math.floor((sw - WINDOW_WIDTH) / 2)
    local offsetY = -math.floor((sh - openHeight) / 2)
    local snappedX, snappedY = Pixel:SnapPosition(offsetX, offsetY, "TOPLEFT", WINDOW_WIDTH, openHeight, f:GetEffectiveScale())
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", snappedX, snappedY)
    f:SetFrameStrata(Constants.Strata.Dialog or "DIALOG")
    f:SetFrameLevel(WINDOW_FRAME_LEVEL)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    f.Border = CreateFrame("Frame", nil, f, "DialogBorderTranslucentTemplate")
    f.Border:SetAllPoints(f)
    f.Border:SetFrameLevel(f:GetFrameLevel())

    f.Title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    f.Title:SetPoint("TOP", f, "TOP", 0, TITLE_Y)

    f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.Close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    f.Close:SetScript("OnClick", function() f:Hide() end)

    tinsert(UISpecialFrames, FRAME_NAME)
    f:SetPropagateKeyboardInput(true)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            if InCombatLockdown() then return end
            self:SetPropagateKeyboardInput(false)
            self:Hide()
            C_Timer.After(ESC_RESTORE_DELAY, function()
                if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
            end)
        end
    end)
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" and self:IsShown() then self:Hide() end
    end)

    local fScale = f:GetEffectiveScale()
    f.Legend = CreateFrame("Frame", nil, f)
    f.Legend:SetPoint("TOPLEFT",  f, "TOPLEFT",   EDGE_PAD, -TITLE_ROW_HEIGHT)
    f.Legend:SetPoint("TOPRIGHT", f, "TOPRIGHT", -EDGE_PAD, -TITLE_ROW_HEIGHT)
    f.Legend:SetHeight(Pixel:Multiple(LEGEND_HEIGHT, fScale))
    f.Legend._entries = {}

    f.Overall = CreateFrame("Frame", nil, f)
    f.Overall:SetPoint("TOPLEFT",  f, "TOPLEFT",   EDGE_PAD, -(TITLE_ROW_HEIGHT + LEGEND_HEIGHT + 4))
    f.Overall:SetPoint("TOPRIGHT", f, "TOPRIGHT", -EDGE_PAD, -(TITLE_ROW_HEIGHT + LEGEND_HEIGHT + 4))
    f.Overall._bars = {}

    f.OverallIcon = f.Overall:CreateTexture(nil, "ARTWORK")
    f.OverallIcon:SetSize(ICON_SIZE, ICON_SIZE)
    -- Walk the atlas fallback chain; use texture+crop only if none resolve.
    local resolved = false
    if C_Texture and C_Texture.GetAtlasInfo then
        for _, atlas in ipairs(OVERALL_CROWN_ATLASES) do
            if C_Texture.GetAtlasInfo(atlas) then
                f.OverallIcon:SetAtlas(atlas)
                resolved = true
                break
            end
        end
    end
    if not resolved then
        f.OverallIcon:SetTexture(OVERALL_CROWN_TEXTURE)
        f.OverallIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    f.Divider = f:CreateTexture(nil, "ARTWORK")
    f.Divider:SetColorTexture(1, 1, 1, 0.15)
    f.Divider:SetHeight(Pixel:Multiple(DIVIDER_HEIGHT, fScale))

    f.Scroll = CreateFrame("ScrollFrame", nil, f, "ScrollFrameTemplate")
    f.Scroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", EDGE_PAD, EDGE_PAD)
    f.Scroll:SetPoint("TOPRIGHT",   f, "TOPRIGHT",  -EDGE_PAD, 0)
    if f.Scroll.ScrollBar then f.Scroll.ScrollBar:Hide() end
    for _, child in ipairs({ f.Scroll:GetChildren() }) do
        local name = child:GetObjectType()
        if name == "Slider" or name == "EventButton" then child:Hide() end
    end

    f.Content = CreateFrame("Frame", nil, f.Scroll)
    local contentW = WINDOW_WIDTH - EDGE_PAD * 2
    f.Content:SetSize(contentW, 1)
    f.Scroll:SetScrollChild(f.Content)

    f._sectionPool = {}
    f._empty = f:CreateFontString(nil, "OVERLAY")
    f._empty:SetFont(GetFont(), HEADER_FONT_SIZE, GetFontOutline())
    f._empty:SetPoint("CENTER", f.Scroll, "CENTER")
    f._empty:SetTextColor(0.75, 0.75, 0.75)
    f._empty:Hide()

    compareFrame = f
    return f
end

local function ComputeTrackGeometry(contentWidth)
    local iconX  = 0
    local trackX = ICON_SIZE + ICON_BAR_GAP
    local trackW = math.max(40, contentWidth - trackX)
    return iconX, trackX, trackW
end

local function BuildSection(content)
    local section = CreateFrame("Frame", nil, content)
    section._bars = {}

    section.IconBtn = CreateFrame("Button", nil, section)
    section.IconBtn:SetSize(ICON_SIZE, ICON_SIZE)
    section.IconBtn:EnableMouse(true)

    section.Icon = section.IconBtn:CreateTexture(nil, "ARTWORK")
    section.Icon:SetAllPoints(section.IconBtn)
    section.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    section.IconBtn:SetScript("OnEnter", function(self)
        if not self._spellID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(self._spellID)
        else
            GameTooltip:SetText(GetSpellName(self._spellID))
        end
        GameTooltip:Show()
    end)
    section.IconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return section
end

local function BuildSubBar(section)
    local bar = {}
    bar.bg = section:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetColorTexture(1, 1, 1, 0.06)

    bar.fill = section:CreateTexture(nil, "ARTWORK")
    bar.fill:SetTexture(GetBarTexture())

    bar.hit = CreateFrame("Frame", nil, section)
    bar.hit:EnableMouse(true)
    return bar
end

local function InstallHoverBinding(hitFrame, ctx)
    hitFrame._ctx = ctx
    hitFrame:SetScript("OnEnter", function(self)
        local c = self._ctx
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()

        local header = c.mode == "spell" and GetSpellName(c.spellID) or "Overall"
        GameTooltip:AddLine(header, 1, 1, 1)
        GameTooltip:AddLine(" ")

        for i, slot in ipairs(c.perPlayer) do
            local r, g, b = ColorFor(slot.colorIndex or i)
            local amount, dps, pctTotal
            if c.mode == "spell" then
                amount   = slot.spellAmounts[c.spellID] or 0
                dps      = slot.spellDPS[c.spellID] or 0
                pctTotal = slot.totalDamage
            else
                amount   = slot.totalDamage or 0
                dps      = slot.source.amountPerSecond or 0
                pctTotal = c.maxTotal
            end
            local pct = (pctTotal and pctTotal > 0) and (amount / pctTotal * 100) or 0
            GameTooltip:AddLine(ShortName(slot.source.name), r, g, b)
            GameTooltip:AddLine(
                ("%s - %s"):format(AbbreviateAmount(dps), string.format("%.1f%%", pct)),
                0.9, 0.9, 0.9)
            GameTooltip:AddLine(LongAmount(amount), 0.7, 0.7, 0.7)
            if i < #c.perPlayer then GameTooltip:AddLine(" ") end
        end
        GameTooltip:Show()
    end)
    hitFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Checks if a slot is toggled off in the legend. Stored by sourceGUID so state survives
-- re-renders (LayoutContent rebuilds but f._disabled is preserved on the singleton frame).
local function IsSlotDisabled(f, slot)
    local guid = slot and slot.source and slot.source.sourceGUID
    return guid and f._disabled and f._disabled[guid] or false
end

-- Returns the subset of perPlayer that's currently enabled. Order preserved so color
-- assignments (slot.colorIndex) stay stable.
local function ActiveSlots(f, perPlayer)
    local out = {}
    for _, slot in ipairs(perPlayer) do
        if not IsSlotDisabled(f, slot) then out[#out + 1] = slot end
    end
    return out
end

local function LayoutLegend(f, perPlayer)
    for _, e in ipairs(f.Legend._entries) do
        if e.btn then e.btn:Hide() end
    end

    local widths = {}
    local totalW = 0
    for i, slot in ipairs(perPlayer) do
        local entry = f.Legend._entries[i]
        if not entry then
            entry = {}
            entry.btn = CreateFrame("Button", nil, f.Legend)
            entry.btn:RegisterForClicks("LeftButtonUp")
            entry.swatch = entry.btn:CreateTexture(nil, "ARTWORK")
            entry.label  = entry.btn:CreateFontString(nil, "OVERLAY")
            f.Legend._entries[i] = entry
        end
        entry.swatch:SetSize(LEGEND_SWATCH, LEGEND_SWATCH)
        local r, g, b = ColorFor(slot.colorIndex or i)
        entry.swatch:SetColorTexture(r, g, b, 1)
        entry.label:SetFont(GetFont(), LEGEND_FONT_SIZE, GetFontOutline())
        entry.label:SetText(ShortName(slot.source.name))

        local disabled = IsSlotDisabled(f, slot)
        entry.swatch:SetDesaturated(disabled)
        entry.swatch:SetAlpha(disabled and 0.35 or 1)
        entry.label:SetTextColor(disabled and 0.5 or 1, disabled and 0.5 or 1, disabled and 0.5 or 1)

        local entryW = LEGEND_SWATCH + 4 + entry.label:GetStringWidth()
        widths[i] = entryW
        totalW = totalW + entryW
        if i < #perPlayer then totalW = totalW + LEGEND_GAP end

        -- Click toggles enabled/disabled state, then triggers a full re-render.
        entry.btn._slot = slot
        entry.btn:SetScript("OnClick", function(self)
            local s = self._slot
            local guid = s and s.source and s.source.sourceGUID
            if not guid then return end
            f._disabled = f._disabled or {}
            f._disabled[guid] = (not f._disabled[guid]) or nil
            if Plugin.RefreshSpecComparison then Plugin:RefreshSpecComparison() end
        end)
    end

    local legendScale = f.Legend:GetEffectiveScale()
    local legendWidth = WINDOW_WIDTH - EDGE_PAD * 2
    local x = math.max(0, math.floor((legendWidth - totalW) / 2 + 0.5))
    for i in ipairs(perPlayer) do
        local entry = f.Legend._entries[i]
        local w = widths[i]
        entry.btn:ClearAllPoints()
        entry.btn:SetPoint("LEFT", f.Legend, "LEFT", Pixel:Snap(x, legendScale), 0)
        entry.btn:SetSize(Pixel:Snap(w, legendScale), Pixel:Multiple(LEGEND_HEIGHT, legendScale))
        entry.btn:Show()

        entry.swatch:ClearAllPoints()
        entry.swatch:SetPoint("LEFT", entry.btn, "LEFT", 0, 0)

        entry.label:ClearAllPoints()
        entry.label:SetPoint("LEFT", entry.swatch, "RIGHT", 4, 0)

        x = x + w + LEGEND_GAP
    end
end

local function LayoutSection(section, spellID, perPlayer, contentWidth, globalMax)
    local iconX, trackX, trackW = ComputeTrackGeometry(contentWidth)
    local sectionScale = section:GetEffectiveScale()

    section.IconBtn:ClearAllPoints()
    section.IconBtn:SetPoint("TOPLEFT", section, "TOPLEFT", iconX, 0)
    section.Icon:SetTexture(GetSpellTexture(spellID))
    section.IconBtn._spellID = spellID

    local playerCount = #perPlayer
    local barH = playerCount > 0 and math.max(1, math.floor(BAR_STACK_H / playerCount)) or BAR_STACK_H
    local stackTotalH = barH * playerCount
    local stackTopOffset = math.floor((SECTION_ROW_H - stackTotalH) / 2)
    local snappedTrackX = Pixel:Snap(trackX, sectionScale)
    local snappedTrackW = Pixel:Snap(trackW, sectionScale)
    local snappedBarH = Pixel:Multiple(barH, sectionScale)

    for i, slot in ipairs(perPlayer) do
        local bar = section._bars[i] or BuildSubBar(section)
        section._bars[i] = bar
        local yTop = -Pixel:Snap(stackTopOffset + (i - 1) * barH, sectionScale)
        local r, g, b = ColorFor(slot.colorIndex or i)
        local amount = slot.spellAmounts[spellID] or 0

        bar.bg:ClearAllPoints()
        bar.bg:SetPoint("TOPLEFT", section, "TOPLEFT", snappedTrackX, yTop)
        bar.bg:SetSize(snappedTrackW, snappedBarH)
        bar.bg:Show()

        local fillW = (globalMax and globalMax > 0) and math.max(1, math.floor(trackW * (amount / globalMax) + 0.5)) or 0
        if fillW > 0 then
            bar.fill:ClearAllPoints()
            bar.fill:SetPoint("TOPLEFT", section, "TOPLEFT", snappedTrackX, yTop)
            bar.fill:SetSize(Pixel:Snap(fillW, sectionScale), snappedBarH)
            bar.fill:SetVertexColor(r, g, b, 0.95)
            bar.fill:Show()
        else
            bar.fill:Hide()
        end

        bar.hit:ClearAllPoints()
        bar.hit:SetPoint("TOPLEFT", section, "TOPLEFT", snappedTrackX, yTop)
        bar.hit:SetSize(snappedTrackW, snappedBarH)
        InstallHoverBinding(bar.hit, {
            mode      = "spell",
            spellID   = spellID,
            perPlayer = perPlayer,
        })
        bar.hit:Show()
    end

    for i = #perPlayer + 1, #section._bars do
        local bar = section._bars[i]
        if bar then
            bar.bg:Hide(); bar.fill:Hide()
            if bar.hit then bar.hit:Hide(); bar.hit:SetScript("OnEnter", nil); bar.hit:SetScript("OnLeave", nil) end
        end
    end

    section:SetHeight(Pixel:Multiple(SECTION_ROW_H, section:GetEffectiveScale()))
    return SECTION_ROW_H
end

local function LayoutOverall(f, perPlayer)
    local maxTotal = 0
    for _, slot in ipairs(perPlayer) do
        if slot.totalDamage > maxTotal then maxTotal = slot.totalDamage end
    end

    -- f.Overall:GetWidth() returns 0 on first pass before anchor resolves, collapsing trackW.
    local overallWidth = WINDOW_WIDTH - EDGE_PAD * 2
    local iconX, trackX, trackW = ComputeTrackGeometry(overallWidth)
    local overallScale = f.Overall:GetEffectiveScale()

    f.OverallIcon:ClearAllPoints()
    f.OverallIcon:SetPoint("TOPLEFT", f.Overall, "TOPLEFT", iconX, 0)

    local playerCount = #perPlayer
    local barH = playerCount > 0 and math.max(1, math.floor(BAR_STACK_H / playerCount)) or BAR_STACK_H
    local stackTotalH = barH * playerCount
    local stackTopOffset = math.floor((SECTION_ROW_H - stackTotalH) / 2)
    local snappedTrackX = Pixel:Snap(trackX, overallScale)
    local snappedTrackW = Pixel:Snap(trackW, overallScale)
    local snappedBarH = Pixel:Multiple(barH, overallScale)

    for i, slot in ipairs(perPlayer) do
        local bar = f.Overall._bars[i]
        if not bar then
            bar = {}
            bar.bg = f.Overall:CreateTexture(nil, "BACKGROUND")
            bar.bg:SetColorTexture(1, 1, 1, 0.06)
            bar.fill = f.Overall:CreateTexture(nil, "ARTWORK")
            bar.fill:SetTexture(GetBarTexture())
            bar.hit = CreateFrame("Frame", nil, f.Overall)
            bar.hit:EnableMouse(true)
            f.Overall._bars[i] = bar
        end
        local yTop = -Pixel:Snap(stackTopOffset + (i - 1) * barH, overallScale)
        local r, g, b = ColorFor(slot.colorIndex or i)
        local amount = slot.totalDamage or 0

        bar.bg:ClearAllPoints()
        bar.bg:SetPoint("TOPLEFT", f.Overall, "TOPLEFT", snappedTrackX, yTop)
        bar.bg:SetSize(snappedTrackW, snappedBarH)
        bar.bg:Show()

        local fillW = maxTotal > 0 and math.max(1, math.floor(trackW * (amount / maxTotal) + 0.5)) or 0
        if fillW > 0 then
            bar.fill:ClearAllPoints()
            bar.fill:SetPoint("TOPLEFT", f.Overall, "TOPLEFT", snappedTrackX, yTop)
            bar.fill:SetSize(Pixel:Snap(fillW, overallScale), snappedBarH)
            bar.fill:SetVertexColor(r, g, b, 0.95)
            bar.fill:Show()
        else
            bar.fill:Hide()
        end

        bar.hit:ClearAllPoints()
        bar.hit:SetPoint("TOPLEFT", f.Overall, "TOPLEFT", snappedTrackX, yTop)
        bar.hit:SetSize(snappedTrackW, snappedBarH)
        InstallHoverBinding(bar.hit, {
            mode      = "overall",
            perPlayer = perPlayer,
            maxTotal  = maxTotal,
        })
        bar.hit:Show()
    end
    for i = #perPlayer + 1, #f.Overall._bars do
        local bar = f.Overall._bars[i]
        if bar then
            bar.bg:Hide(); bar.fill:Hide()
            if bar.hit then bar.hit:Hide(); bar.hit:SetScript("OnEnter", nil); bar.hit:SetScript("OnLeave", nil) end
        end
    end

    f.Overall:SetHeight(Pixel:Multiple(SECTION_ROW_H, f.Overall:GetEffectiveScale()))
    return SECTION_ROW_H
end

local function LayoutContent(f, perPlayer, unionOrder)
    local contentWidth = f.Content:GetWidth()
    local contentScale = f.Content:GetEffectiveScale()
    -- Shared max (not per-player) so absolute magnitudes are visually comparable across players.
    local globalMax = 0
    for _, slot in ipairs(perPlayer) do
        for _, amount in pairs(slot.spellAmounts) do
            if amount > globalMax then globalMax = amount end
        end
    end
    local y = 0
    local used = 0
    for idx, spellID in ipairs(unionOrder) do
        local section = f._sectionPool[idx] or BuildSection(f.Content)
        f._sectionPool[idx] = section
        section:ClearAllPoints()
        local snappedY = -Pixel:Snap(y, contentScale)
        section:SetPoint("TOPLEFT",  f.Content, "TOPLEFT",  0, snappedY)
        section:SetPoint("TOPRIGHT", f.Content, "TOPRIGHT", 0, snappedY)
        local h = LayoutSection(section, spellID, perPlayer, contentWidth, globalMax)
        section:Show()
        y = y + h + SECTION_GAP
        used = idx
    end
    for i = used + 1, #f._sectionPool do f._sectionPool[i]:Hide() end
    f.Content:SetHeight(Pixel:Snap(math.max(1, y), contentScale))
end

-- [ PUBLIC ENTRY POINT ] ----------------------------------------------------------------------------
-- Lays out legend / overall / content using the already-gathered f._perPlayer and
-- f._unionOrder. Called both on initial open and when the legend toggles a player on/off.
local function ApplyLayout(f)
    local perPlayer = f._perPlayer or {}
    local unionOrder = f._unionOrder or {}
    local active = ActiveSlots(f, perPlayer)

    LayoutLegend(f, perPlayer)
    local overallH = LayoutOverall(f, active)

    local overallTopY = TITLE_ROW_HEIGHT + LEGEND_HEIGHT + 4
    local dividerY    = overallTopY + overallH + DIVIDER_MARGIN_Y
    local scrollTopY  = dividerY + DIVIDER_HEIGHT + DIVIDER_MARGIN_Y

    f.Divider:ClearAllPoints()
    f.Divider:SetPoint("TOPLEFT",  f, "TOPLEFT",   EDGE_PAD, -dividerY)
    f.Divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -EDGE_PAD, -dividerY)
    f.Divider:Show()

    f.Scroll:ClearAllPoints()
    f.Scroll:SetPoint("TOPRIGHT",   f, "TOPRIGHT",  -EDGE_PAD, -scrollTopY)
    f.Scroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", EDGE_PAD, EDGE_PAD)

    if #unionOrder == 0 or #active == 0 then
        f._empty:SetText(L.PLU_DM_COMPARE_EMPTY)
        f._empty:Show()
        for _, s in ipairs(f._sectionPool) do s:Hide() end
        f.Content:SetHeight(1)
    else
        f._empty:Hide()
        LayoutContent(f, active, unionOrder)
    end

    local contentH = math.min(f.Content:GetHeight(), WINDOW_MAX_H - scrollTopY - EDGE_PAD)
    f:SetHeight(scrollTopY + contentH + EDGE_PAD)
end

-- Legend OnClick calls this to re-lay out without re-gathering spell data.
function Plugin:RefreshSpecComparison()
    if compareFrame and compareFrame:IsShown() then ApplyLayout(compareFrame) end
end

function Plugin:OpenSpecComparison(meterID, originSource)
    if InCombatLockdown() then return end
    if not originSource or not originSource.sourceGUID then return end
    local def = self:GetMeterDef(meterID)
    if not def then return end
    local candidates = GetSpecMatches(def, originSource)
    if #candidates < 2 then return end

    local f = EnsureFrame()
    local metric = L[METER_TYPE_LABEL_KEY[def.meterType] or "PLU_DM_METRIC_DAMAGE"] or ""
    local title = L.PLU_DM_COMPARE_TITLE_F:format(metric)
    local className = GetLocalizedClassName(originSource.classFilename)
    local specName = GetSpecNameByIcon(originSource.specIconID)
    local idParts = {}
    if className then idParts[#idParts + 1] = className end
    if specName then idParts[#idParts + 1] = specName end
    if #idParts > 0 then title = title .. ": " .. table.concat(idParts, " - ") end
    f.Title:SetText(title)
    f:SetWidth(WINDOW_WIDTH)

    local perPlayer, unionOrder = GatherSpellMatrix(def, candidates)
    -- Leader-first so perPlayer[1] gets color 1 (blue).
    table.sort(perPlayer, function(a, b)
        return (a.totalDamage or 0) > (b.totalDamage or 0)
    end)
    -- Stamp each slot's color index so toggling players on/off doesn't reshuffle colors.
    for i, slot in ipairs(perPlayer) do slot.colorIndex = i end
    -- Cascade spell order by the leader's spell amounts.
    local leader = perPlayer[1]
    if leader then
        table.sort(unionOrder, function(a, b)
            local la = leader.spellAmounts[a] or 0
            local lb = leader.spellAmounts[b] or 0
            if la ~= lb then return la > lb end
            return a < b
        end)
    end
    f._perPlayer  = perPlayer
    f._unionOrder = unionOrder
    -- Reset disabled state on fresh open (fresh context = fresh toggles).
    f._disabled = {}

    ApplyLayout(f)
    f:Show()
end
