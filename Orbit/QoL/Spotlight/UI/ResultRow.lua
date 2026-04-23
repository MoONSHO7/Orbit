-- [ RESULT ROW ]------------------------------------------------------------------------------------
local _, Orbit = ...
local L = Orbit.L
local Skin = Orbit.Skin
local AButtonSkin = Orbit.Skin.ActionButtonSkin
local Constants = Orbit.Constants
local ResultRow = {}
Orbit.Spotlight.UI.ResultRow = ResultRow

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
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
local SELECTED_BG_COLOR = { r = 1, g = 1, b = 1, a = 0.18 }
local LABEL_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local KIND_LABEL_COLOR = { r = 0.6, g = 0.6, b = 0.6, a = 1 }
local COUNT_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local SECURE_ATTR_KEYS = { "type", "item", "spell", "toy", "macro", "macrotext", "battlepet", "mount", "unit" }

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

-- [ PICKUP DISPATCH ]-------------------------------------------------------------------------------
local function PickupEntry(entry)
    local k = entry.kind
    if k == "spellbook" or k == "professions" then
        C_Spell.PickupSpell(entry.id)
    elseif k == "mounts" then
        local _, spellID = C_MountJournal.GetMountInfoByID(entry.id)
        if spellID then C_Spell.PickupSpell(spellID) end
    elseif k == "pets" then
        if entry.petGUID then C_PetJournal.PickupPet(entry.petGUID) end
    elseif k == "toys" then
        C_ToyBox.PickupToyBoxItem(entry.id)
    elseif k == "macros" then
        PickupMacro(entry.id)
    elseif k == "bags" or k == "heirlooms" or k == "equipped" or k == "questitems" then
        local itemRef = entry.secure and entry.secure.item or entry.id
        if itemRef then PickupItem(itemRef) end
    end
end

-- [ TOOLTIP DISPATCH ]------------------------------------------------------------------------------
local function ShowTooltip(row)
    local entry = row._entry
    if not entry then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local k = entry.kind
    if k == "bags" or k == "equipped" or k == "questitems" then
        if entry.secure and entry.secure.item then GameTooltip:SetHyperlink(entry.secure.item) end
    elseif k == "heirlooms" then
        GameTooltip:SetItemByID(entry.id)
    elseif k == "spellbook" or k == "professions" then
        GameTooltip:SetSpellByID(entry.id)
    elseif k == "toys" then
        GameTooltip:SetToyByItemID(entry.id)
    elseif k == "mounts" then
        local _, spellID = C_MountJournal.GetMountInfoByID(entry.id)
        if spellID then GameTooltip:SetMountBySpellID(spellID) end
    elseif k == "pets" then
        if entry.petGUID then
            local link = C_PetJournal.GetBattlePetLink(entry.petGUID)
            if link then GameTooltip:SetHyperlink(link) end
        end
    elseif k == "currencies" then
        if entry.tooltipLink then GameTooltip:SetHyperlink(entry.tooltipLink) end
    elseif k == "macros" then
        local name, _, body = GetMacroInfo(entry.id)
        GameTooltip:SetText(name or entry.name, 1, 1, 1)
        if body and body ~= "" then GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true) end
    end
    GameTooltip:Show()
end

-- [ FACTORY ]---------------------------------------------------------------------------------------
function ResultRow:Create(parent, width)
    local row = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    row:SetSize(width, ROW_HEIGHT)
    -- AnyUp only: AnyDown would dispatch and close on mouse-down, pre-empting OnDragStart.
    row:RegisterForClicks("AnyUp")
    row:RegisterForDrag("LeftButton")
    row:EnableMouse(true)

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

    local kindLabel = row:CreateFontString(nil, "OVERLAY")
    Skin:SkinText(kindLabel, { font = GetGlobalFontName(), textSize = KIND_FONT_SIZE, textColor = KIND_LABEL_COLOR })
    kindLabel:SetPoint("TOPRIGHT", row, "TOPRIGHT", -LABEL_RIGHT_PAD, -3)
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

-- [ BIND ]------------------------------------------------------------------------------------------
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

function ResultRow:Bind(row, entry)
    row._entry = entry
    row.iconBtn.icon:SetTexture(entry.icon)
    row.label:SetText(entry.name)
    if entry.quality and C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(entry.quality)
        row.label:SetTextColor(r, g, b, 1)
    else
        row.label:SetTextColor(LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, LABEL_COLOR.a)
    end
    row.kindLabel:SetText(KIND_LABEL[entry.kind] or entry.kind)
    local countLabel = FormatCount(entry.count)
    if countLabel then
        row.iconBtn.countText:SetText(countLabel)
        row.iconBtn.countText:Show()
    else
        row.iconBtn.countText:Hide()
    end
    row.iconBtn.star:SetShown(entry.favorite == true)
    row.iconBtn.starShadow:SetShown(entry.favorite == true)

    ClearSecureAttrs(row)
    if entry.secure then
        for k, v in pairs(entry.secure) do row:SetAttribute(k, v) end
        row:SetScript("PostClick", function(self)
            RecordActivation(self)
            Orbit.Spotlight.UI.SpotlightFrame:Close()
        end)
    else
        row:SetScript("PostClick", function(self)
            RecordActivation(self)
            if self._entry and self._entry.onClick then self._entry.onClick(self._entry) end
            Orbit.Spotlight.UI.SpotlightFrame:Close()
        end)
    end
end
