-- [ RESULT ROW ]-------------------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L
local GameTooltip = Orbit.Tooltip
local Skin = Orbit.Skin
local AButtonSkin = Orbit.Skin.ActionButtonSkin
local Constants = Orbit.Constants
local Favorites = Orbit.Spotlight.Index.Favorites
local ResultRow = {}
Orbit.Spotlight.UI.ResultRow = ResultRow

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local ICON_SIZE = 28
local ROW_HEIGHT = 32
local LABEL_PAD_LEFT = 8
local LABEL_RIGHT_PAD = 6
local KIND_LABEL_GAP = 8
local LABEL_FONT_SIZE = 12
local KIND_FONT_SIZE = 10
local COUNT_FONT_SIZE = 11
local STAR_ATLAS = "transmog-icon-favorite"
local STAR_SHADOW_ATLAS = "PetJournal-BattleSlot-Shadow"
local STAR_SIZE = 12
local STAR_SHADOW_SIZE = 22
local STAR_SHADOW_ALPHA = 0.95
local STAR_OFFSET_X = 3
local STAR_OFFSET_Y = 3
local STAR_SHADOW_Y_OFFSET = -1
local QUALITY_SCALE = 0.8
local QUALITY_OFFSET_X = -7
local QUALITY_OFFSET_Y = 7
local SELECTED_BG_COLOR = { r = 1, g = 1, b = 1, a = 0.18 }
local LABEL_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local KIND_LABEL_COLOR = { r = 0.6, g = 0.6, b = 0.6, a = 1 }
local COUNT_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local TOOLTIP_HINT_COLOR = { 0.40, 0.73, 0.40 }
local SECURE_ATTR_KEYS = { "type", "type1", "item", "spell", "toy", "macro", "macrotext", "battlepet", "mount", "unit", "shift-type1", "shift-macrotext1" }

local function FormatCount(n)
    if not n or n <= 1 then return nil end
    if n >= 1000000 then return string.format("%.1fm", n / 1000000):gsub("%.0m", "m")
    elseif n >= 10000 then return math.floor(n / 1000) .. "k"
    elseif n >= 1000 then return string.format("%.1fk", n / 1000):gsub("%.0k", "k") end
    return tostring(n)
end

local function GetGlobalFontName() return Orbit.db.GlobalSettings.Font end

local KIND_LABEL = {}
for _, k in ipairs(Orbit.Spotlight.Kinds) do KIND_LABEL[k.kind] = L[k.labelKey] end

-- [ KIND HANDLERS ]----------------------------------------------------------------------------------
-- Each kind maps to optional pickup/tooltip/link closures; tooltip closures run between SetOwner and Show.
local function ItemPickup(entry)
    local itemRef = entry.secure and entry.secure.item or entry.id
    if itemRef then PickupItem(itemRef) end
end
local function ItemTooltip(entry)
    if entry.secure and entry.secure.item then GameTooltip:SetHyperlink(entry.secure.item) end
end
local function ItemLink(entry)
    return entry.secure and entry.secure.item
end

local ITEM_HANDLER = { pickup = ItemPickup, tooltip = ItemTooltip, link = ItemLink }

local KIND_HANDLERS = {
    spellbook = {
        pickup = function(entry) C_Spell.PickupSpell(entry.id) end,
        tooltip = function(entry) GameTooltip:SetSpellByID(entry.id) end,
        link = function(entry) return C_Spell.GetSpellLink(entry.id) end,
    },
    professions = {
        pickup = function(entry) C_Spell.PickupSpell(entry.spellID) end,
        tooltip = function(entry) GameTooltip:SetSpellByID(entry.spellID) end,
        link = function(entry) return C_Spell.GetSpellLink(entry.spellID) end,
    },
    mounts = {
        pickup = function(entry)
            local _, spellID = C_MountJournal.GetMountInfoByID(entry.id)
            if spellID then C_Spell.PickupSpell(spellID) end
        end,
        tooltip = function(entry)
            local _, spellID = C_MountJournal.GetMountInfoByID(entry.id)
            if spellID then GameTooltip:SetMountBySpellID(spellID) end
        end,
        link = function(entry)
            local _, spellID = C_MountJournal.GetMountInfoByID(entry.id)
            return spellID and C_MountJournal.GetMountLink(spellID)
        end,
    },
    pets = {
        pickup = function(entry)
            if entry.petGUID then C_PetJournal.PickupPet(entry.petGUID) end
        end,
        tooltip = function(entry)
            if entry.petGUID then
                local link = C_PetJournal.GetBattlePetLink(entry.petGUID)
                if link then GameTooltip:SetHyperlink(link) end
            end
        end,
        link = function(entry) return entry.petGUID and C_PetJournal.GetBattlePetLink(entry.petGUID) end,
    },
    toys = {
        pickup = function(entry) C_ToyBox.PickupToyBoxItem(entry.id) end,
        tooltip = function(entry) GameTooltip:SetToyByItemID(entry.id) end,
        link = function(entry) return C_ToyBox.GetToyLink(entry.id) end,
    },
    macros = {
        pickup = function(entry) PickupMacro(entry.id) end,
        tooltip = function(entry)
            local name, _, body = GetMacroInfo(entry.id)
            GameTooltip:SetText(name or entry.name, 1, 1, 1)
            if body and body ~= "" then GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true) end
        end,
    },
    heirlooms = {
        pickup = ItemPickup,
        tooltip = function(entry) GameTooltip:SetItemByID(entry.id) end,
        link = function(entry) return select(2, C_Item.GetItemInfo(entry.id)) end,
    },
    bags = ITEM_HANDLER,
    equipped = ITEM_HANDLER,
    questitems = ITEM_HANDLER,
    currencies = {
        tooltip = function(entry)
            if entry.tooltipLink then GameTooltip:SetHyperlink(entry.tooltipLink) end
        end,
        link = function(entry) return entry.tooltipLink end,
    },
    help = {
        tooltip = function(entry)
            GameTooltip:SetText(entry.name, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
            if entry.trigger then GameTooltip:AddLine(entry.trigger, TOOLTIP_HINT_COLOR[1], TOOLTIP_HINT_COLOR[2], TOOLTIP_HINT_COLOR[3], true) end
            if entry.desc then GameTooltip:AddLine(entry.desc, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, true) end
            if entry.note then
                if entry.desc then GameTooltip:AddLine(" ") end
                GameTooltip:AddLine(entry.note, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, true)
            end
        end,
    },
}

-- [ PICKUP DISPATCH ]--------------------------------------------------------------------------------
local function PickupEntry(entry)
    local h = KIND_HANDLERS[entry.kind]
    if h and h.pickup then h.pickup(entry) end
end

-- [ TOOLTIP DISPATCH ]-------------------------------------------------------------------------------
local function ShowTooltip(row)
    local entry = row._entry
    if not entry then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local h = KIND_HANDLERS[entry.kind]
    if h and h.tooltip then h.tooltip(entry) end
    GameTooltip:Show()
end

-- [ CHAT LINK ]--------------------------------------------------------------------------------------
local function GetEntryLink(entry)
    local h = KIND_HANDLERS[entry.kind]
    return h and h.link and h.link(entry) or nil
end

local function TryLinkEntry(entry)
    if not entry then return false end
    local editBox = ChatEdit_GetActiveWindow()
    if not editBox then return false end
    local link = GetEntryLink(entry)
    if not link then return false end
    editBox:Insert(link)
    return true
end

-- [ FACTORY ]----------------------------------------------------------------------------------------
function ResultRow:Create(parent, width)
    local row = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    row:SetSize(width, ROW_HEIGHT)
    row:RegisterForClicks("AnyUp")
    row:RegisterForDrag("LeftButton")
    row:EnableMouse(true)
    row:SetAttribute("useOnKeyDown", false)

    local function OnDragStart(self)
        local entry = (self._entry) or (self:GetParent() and self:GetParent()._entry)
        if not entry then return end
        PickupEntry(entry)
        if GetCursorInfo() then Orbit.Spotlight.UI.SpotlightFrame:Close() end
    end
    row:SetScript("OnDragStart", OnDragStart)

    -- Clicks and motion propagate so clicking the icon fires the row's secure dispatch.
    local iconBtn = CreateFrame("CheckButton", nil, row)
    iconBtn:SetSize(ICON_SIZE, ICON_SIZE)
    iconBtn:SetPoint("LEFT", row, "LEFT", 2, 0)
    iconBtn:EnableMouse(true)
    iconBtn:SetPropagateMouseClicks(true)
    iconBtn:SetPropagateMouseMotion(true)
    iconBtn.icon = iconBtn:CreateTexture(nil, "ARTWORK")
    iconBtn.icon:SetAllPoints(iconBtn)
    iconBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.iconBtn = iconBtn

    iconBtn:SetScript("OnEnter", function(self) ShowTooltip(self:GetParent()) end)
    iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    iconBtn:RegisterForDrag("LeftButton")
    iconBtn:SetScript("OnDragStart", OnDragStart)

    AButtonSkin:Apply(iconBtn, { hideName = true })

    local countText = iconBtn:CreateFontString(nil, "OVERLAY")
    Skin:SkinText(countText, { font = GetGlobalFontName(), textSize = COUNT_FONT_SIZE, textColor = COUNT_COLOR })
    countText:SetPoint("BOTTOMRIGHT", iconBtn, "BOTTOMRIGHT", -1, 1)
    countText:SetJustifyH("RIGHT")
    countText:Hide()
    iconBtn.countText = countText

    local starShadow = iconBtn:CreateTexture(nil, "OVERLAY", nil, 5)
    starShadow:SetAtlas(STAR_SHADOW_ATLAS)
    starShadow:SetSize(STAR_SHADOW_SIZE, STAR_SHADOW_SIZE)
    starShadow:SetVertexColor(0, 0, 0, STAR_SHADOW_ALPHA)
    starShadow:Hide()
    iconBtn.starShadow = starShadow

    local star = iconBtn:CreateTexture(nil, "OVERLAY", nil, 7)
    star:SetAtlas(STAR_ATLAS)
    star:SetSize(STAR_SIZE, STAR_SIZE)
    star:SetPoint("TOPRIGHT", iconBtn, "TOPRIGHT", STAR_OFFSET_X, STAR_OFFSET_Y)
    star:Hide()
    starShadow:SetPoint("CENTER", star, "CENTER", 0, STAR_SHADOW_Y_OFFSET)
    iconBtn.star = star

    local qualityOverlay = iconBtn:CreateTexture(nil, "OVERLAY", nil, 6)
    qualityOverlay:SetPoint("TOPLEFT", iconBtn, "TOPLEFT", QUALITY_OFFSET_X, QUALITY_OFFSET_Y)
    qualityOverlay:SetSnapToPixelGrid(true)
    qualityOverlay:SetTexelSnappingBias(0)
    qualityOverlay:Hide()
    iconBtn.qualityOverlay = qualityOverlay

    local kindLabel = row:CreateFontString(nil, "OVERLAY")
    Skin:SkinText(kindLabel, { font = GetGlobalFontName(), textSize = KIND_FONT_SIZE, textColor = KIND_LABEL_COLOR })
    kindLabel:SetPoint("RIGHT", row, "RIGHT", -LABEL_RIGHT_PAD, 0)
    kindLabel:SetJustifyH("RIGHT")
    row.kindLabel = kindLabel

    local label = row:CreateFontString(nil, "OVERLAY")
    Skin:SkinText(label, { font = GetGlobalFontName(), textSize = LABEL_FONT_SIZE, textColor = LABEL_COLOR })
    label:SetPoint("LEFT", iconBtn, "RIGHT", LABEL_PAD_LEFT, 0)
    label:SetPoint("RIGHT", kindLabel, "LEFT", -KIND_LABEL_GAP, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label

    local selectedBg = row:CreateTexture(nil, "BACKGROUND")
    selectedBg:SetAllPoints(row)
    selectedBg:SetColorTexture(SELECTED_BG_COLOR.r, SELECTED_BG_COLOR.g, SELECTED_BG_COLOR.b, SELECTED_BG_COLOR.a)
    selectedBg:Hide()
    row.selectedBg = selectedBg

    row:SetScript("OnEnter", function(self) self.selectedBg:Show(); ShowTooltip(self) end)
    row:SetScript("OnLeave", function(self) self.selectedBg:Hide(); GameTooltip:Hide() end)

    return row
end

-- [ BIND ]-------------------------------------------------------------------------------------------
-- SetAttribute is combat-forbidden; the caller relies on Spotlight being closed during combat.
local function ClearSecureAttrs(row)
    for _, key in ipairs(SECURE_ATTR_KEYS) do
        if row:GetAttribute(key) ~= nil then row:SetAttribute(key, nil) end
    end
end

local function RecordActivation(row)
    local entry = row._entry
    if not entry then return end
    local Recents = Orbit.Spotlight.Index.Recents
    if Recents then Recents:Record(entry) end
end

local function HandleFavoriteRightClick(row)
    local entry = row._entry
    if not entry or not Favorites:IsSupported(entry.kind) then return end
    local newState = Favorites:Toggle(entry)
    if newState == nil then return end
    row.iconBtn.star:SetShown(newState)
    row.iconBtn.starShadow:SetShown(newState)
end

local ITEM_KINDS = { bags = true, equipped = true, questitems = true }
local function GetCraftingQualityAtlas(entry)
    if not ITEM_KINDS[entry.kind] then return nil end
    local ref = (entry.secure and entry.secure.item) or entry.id
    if not ref then return nil end
    local info = C_TradeSkillUI.GetItemReagentQualityInfo(ref) or C_TradeSkillUI.GetItemCraftedQualityInfo(ref)
    return info and info.iconInventory
end

function ResultRow:Bind(row, entry)
    row._entry = entry
    row.iconBtn.icon:SetTexture(entry.icon)
    -- Help glyphs are full-bleed; game-item icons keep the standard border crop.
    if entry.kind == "help" then
        row.iconBtn.icon:SetTexCoord(0, 1, 0, 1)
    else
        row.iconBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    row.label:SetText(entry.name)
    if entry.quality and C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(entry.quality)
        row.label:SetTextColor(r, g, b, 1)
    else
        row.label:SetTextColor(LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, LABEL_COLOR.a)
    end
    row.kindLabel:SetText(entry.topic or KIND_LABEL[entry.kind] or entry.kind)
    local countLabel = FormatCount(entry.count)
    if countLabel then
        row.iconBtn.countText:SetText(countLabel)
        row.iconBtn.countText:Show()
    else
        row.iconBtn.countText:Hide()
    end
    row.iconBtn.star:SetShown(entry.favorite == true)
    row.iconBtn.starShadow:SetShown(entry.favorite == true)
    local qualityAtlas = GetCraftingQualityAtlas(entry)
    if qualityAtlas then
        local overlay = row.iconBtn.qualityOverlay
        overlay:SetAtlas(qualityAtlas, true)
        local w, h = overlay:GetSize()
        overlay:SetSize(w * QUALITY_SCALE, h * QUALITY_SCALE)
        overlay:SetPoint("TOPLEFT", row.iconBtn, "TOPLEFT", QUALITY_OFFSET_X + w * (1 - QUALITY_SCALE) * 0.5, QUALITY_OFFSET_Y - h * (1 - QUALITY_SCALE) * 0.5)
        overlay:Show()
    else
        row.iconBtn.qualityOverlay:Hide()
    end

    ClearSecureAttrs(row)
    if entry.secure then
        -- Bare "type" is SecureActionButtonTemplate's any-button fallback; rebind as "type1" so right-click stays unbound.
        for k, v in pairs(entry.secure) do
            if k == "type" then k = "type1" end
            row:SetAttribute(k, v)
        end
        -- Shift+left is reserved for chat-link; an empty macro neutralizes the use/cast so the item isn't consumed.
        row:SetAttribute("shift-type1", "macro")
        row:SetAttribute("shift-macrotext1", "")
    end
    row:SetScript("PostClick", function(self, button)
        if button == "RightButton" then HandleFavoriteRightClick(self); return end
        if button == "LeftButton" and IsShiftKeyDown() and TryLinkEntry(self._entry) then return end
        RecordActivation(self)
        -- onClick gets the row as a second arg so menu entries can anchor a context menu to it.
        if not self._entry.secure and self._entry.onClick then self._entry.onClick(self._entry, self) end
        -- Explainer help rows keep Spotlight open so the user can read other tooltips; actions close.
        if not self._entry.keepOpen then Orbit.Spotlight.UI.SpotlightFrame:Close() end
    end)
end
