-- [ METATALENTS / TREE OVERLAY ]--------------------------------------------------------------
-- Per-button heatmap pipeline: pick-rate badge under each talent button, red/green shape
-- glow indicating meta pick alignment, and the tooltip hook that appends the WCL pick-rate
-- line to spell tooltips. UpdateShapeGlow lives at file scope now — it used to be lazily
-- defined inside the first truthy-pickrate call to ApplyHeatmap, which was fragile.

local _, Orbit = ...
local MT = Orbit.MetaTalents
local C = MT.Constants
local Data = MT.Data
local Build = MT.Build

local Overlay = {}
MT.Overlay = Overlay

local GLOW_INSET = 14
local GLOW_CIRCLE_ATLAS = "talents-node-circle-greenglow"
local GLOW_CHOICE_ATLAS = "talents-node-choice-greenglow"
local GLOW_SQUARE_ATLAS = "talents-node-square-greenglow"

-- [ BADGE CREATION ]--------------------------------------------------------------------------
local function CreateBadge(button)
    local badge = CreateFrame("Frame", nil, button)
    badge:SetFrameLevel(math.max(1, button:GetFrameLevel() + C.BADGE_LEVEL_OFFSET))
    badge:SetSize(C.BADGE_WIDTH, C.BADGE_HEIGHT)
    badge:SetPoint("TOP", button, "BOTTOM", 0, C.BADGE_TOP_OFFSET)
    local bg = badge:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("CENTER")
    bg:SetSize(C.BADGE_SHADOW_WIDTH, C.BADGE_SHADOW_HEIGHT)
    bg:SetAtlas("PetJournal-BattleSlot-Shadow")
    bg:SetVertexColor(0, 0, 0, C.BADGE_SHADOW_ALPHA)
    local fs = badge:CreateFontString(nil, "OVERLAY", C.FONT_TEMPLATE)
    fs:SetPoint("CENTER", badge, "CENTER", C.BADGE_TEXT_X, 0)
    fs:SetTextColor(1, 1, 1)
    badge.text = fs
    button._orbitMetaBadge = badge
    return badge
end

-- [ SHAPE GLOW ]------------------------------------------------------------------------------
local function UpdateShapeGlow(button, glowType)
    if not glowType then
        if button._orbitShapeGlow then button._orbitShapeGlow:Hide() end
        return
    end
    local glow = button._orbitShapeGlow
    if not glow then
        glow = button:CreateTexture(nil, "BACKGROUND", nil, -3)
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER", button, "CENTER")
        button._orbitShapeGlow = glow
    end
    local atlas = GLOW_CIRCLE_ATLAS
    local refAtlas = (button.StateBorder and button.StateBorder:GetAtlas()) or (button.Border and button.Border:GetAtlas())
    if refAtlas then
        if string.find(refAtlas, "choice", 1, true) then atlas = GLOW_CHOICE_ATLAS
        elseif string.find(refAtlas, "square", 1, true) then atlas = GLOW_SQUARE_ATLAS end
    end
    glow:SetAtlas(atlas)
    glow:ClearAllPoints()
    local anchor = button.StateBorder or button
    glow:SetPoint("TOPLEFT", anchor, "TOPLEFT", -GLOW_INSET, GLOW_INSET)
    glow:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", GLOW_INSET, -GLOW_INSET)
    glow:SetDesaturation(1)
    if glowType == "RED" then
        glow:SetVertexColor(1, 0, 0, 1)
    else
        glow:SetVertexColor(0, 1, 0, 1)
    end
    glow:Show()
end

-- [ PURCHASABILITY ]--------------------------------------------------------------------------
local function IsLegallyPurchasable(cfg, nid, eid, itype, avail)
    if itype == Enum.TraitNodeType.Tiered then return avail end
    return C_Traits.CanPurchaseRank(cfg, nid, eid)
end

-- [ PICK RATE LOOKUP FOR BUTTON ]-------------------------------------------------------------
local function ResolvePickRate(button, info, isSelected, isChoiceNode)
    if isSelected and isChoiceNode then
        local pickedEntryID = (info and info.activeEntry and info.activeEntry.entryID) or (button.GetEntryID and button:GetEntryID())
        if pickedEntryID then return Data.LookupPickRate(pickedEntryID) end
        return nil
    end
    local bestPickRate = nil
    if info and info.entryIDs then
        for _, eID in ipairs(info.entryIDs) do
            local rate = Data.LookupPickRate(eID)
            if rate and (not bestPickRate or rate > bestPickRate) then bestPickRate = rate end
        end
    end
    local entryID = button.GetEntryID and button:GetEntryID()
    return bestPickRate or (entryID and Data.LookupPickRate(entryID))
end

-- [ GLOW DECISION ]---------------------------------------------------------------------------
local function DecideGlow(button, info, metaSet, isSelected, isChoiceNode, activeRank, metaConfigID, nID)
    if not (metaSet and info) then return nil end
    local pickedEntryID = (info.activeEntry and info.activeEntry.entryID) or (button.GetEntryID and button:GetEntryID())
    if isSelected then
        if isChoiceNode then
            if pickedEntryID and not metaSet[pickedEntryID] then return "RED" end
            return nil
        end
        local isMetaPath = pickedEntryID and metaSet[pickedEntryID]
        if not isMetaPath and info.entryIDs then
            for _, eID in ipairs(info.entryIDs) do
                if metaSet[eID] then isMetaPath = true; break end
            end
        end
        if not isMetaPath then return "RED" end
        if activeRank < (info.maxRanks or 1) and info.entryIDs then
            for _, eID in ipairs(info.entryIDs) do
                if IsLegallyPurchasable(metaConfigID, nID, eID, info.type, info.isAvailable) then
                    return "GREEN"
                end
            end
        end
        return nil
    end
    if info.entryIDs then
        for _, eID in ipairs(info.entryIDs) do
            if metaSet[eID] and IsLegallyPurchasable(metaConfigID, nID, eID, info.type, info.isAvailable) then
                return "GREEN"
            end
        end
    end
    return nil
end

-- [ HEATMAP APPLICATION ]---------------------------------------------------------------------
function Overlay.ApplyHeatmap(button)
    if button.Divider then button.Divider:SetAlpha(0) end
    local db = Orbit.db and Orbit.db.AccountSettings
    if not (db and db.MetaTalentsTree) then
        if button._orbitMetaBadge then button._orbitMetaBadge:Hide() end
        return
    end
    local metaConfigID = C_ClassTalents.GetActiveConfigID()
    local nID = button.GetNodeID and button:GetNodeID()
    local info = nID and metaConfigID and C_Traits.GetNodeInfo(metaConfigID, nID)
    local activeRank = info and info.activeRank or 0
    if button.nodeInfo and button.nodeInfo.ranksPurchased then
        activeRank = button.nodeInfo.ranksPurchased
    end
    local isSelected = activeRank > 0
    local isChoiceNode = info and info.type == Enum.TraitNodeType.Selection
    local pickRate = ResolvePickRate(button, info, isSelected, isChoiceNode)

    if not pickRate then
        if button._orbitMetaBadge then button._orbitMetaBadge:Hide() end
        if button._orbitShapeGlow then button._orbitShapeGlow:Hide() end
        return
    end

    local r, g, b = C.HeatmapColor(pickRate)
    local badge = button._orbitMetaBadge or CreateBadge(button)
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local fontPath = gs and gs.Font and LibStub("LibSharedMedia-3.0"):Fetch("font", gs.Font) or "Fonts\\FRIZQT__.TTF"
    badge.text:SetFont(fontPath, C.BADGE_FONT_SIZE, Orbit.Skin:GetFontOutline())
    Orbit.Skin:ApplyFontShadow(badge.text)
    badge.text:SetText(math.floor(pickRate) .. "%")
    badge.text:SetTextColor(r, g, b, 1)
    badge:Show()

    if Orbit.Skin and Orbit.Skin.ClearHighlightBorder then
        Orbit.Skin:ClearHighlightBorder(button, "_orbitMetaRed")
        Orbit.Skin:ClearHighlightBorder(button, "_orbitMetaGreen")
    end

    local metaSet = Build.GetMetaSet()
    local glowReq = DecideGlow(button, info, metaSet, isSelected, isChoiceNode, activeRank, metaConfigID, nID)
    UpdateShapeGlow(button, glowReq)
end

-- [ TOOLTIP HOOK ]----------------------------------------------------------------------------
function Overlay.HookTooltips()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
        local db = Orbit.db and Orbit.db.AccountSettings
        if not db or not db.MetaTalentsTooltip then return end
        if not data or not data.id then return end
        local pickRate = Data.GetSpellPickRate(data.id)
        if not pickRate then return end
        local r, g, b = C.HeatmapColor(pickRate)
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("WCL Top 100 Pick Rate", string.format("%.1f%%", pickRate), 0.6, 0.6, 0.6, r, g, b)
    end)
end
