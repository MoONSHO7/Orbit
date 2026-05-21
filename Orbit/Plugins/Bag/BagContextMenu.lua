local _, addonTable = ...
local Orbit = addonTable
local L = Orbit.L

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local PALETTE = {
    { r = 0.95, g = 0.40, b = 0.40 },
    { r = 0.95, g = 0.65, b = 0.35 },
    { r = 0.95, g = 0.85, b = 0.40 },
    { r = 0.55, g = 0.85, b = 0.45 },
    { r = 0.40, g = 0.75, b = 0.85 },
    { r = 0.50, g = 0.65, b = 0.95 },
    { r = 0.75, g = 0.55, b = 0.95 },
    { r = 0.85, g = 0.85, b = 0.85 },
}
local RENAME_CATEGORY_POPUP = "ORBIT_BAG_RENAME_CATEGORY"

-- [ MODULE ]-----------------------------------------------------------------------------------------
Orbit.BagContextMenu = {}
local BagContextMenu = Orbit.BagContextMenu

local function ColoredSwatch(color)
    return string.format("|cff%02x%02x%02x|||||||r", color.r * 255, color.g * 255, color.b * 255)
end

-- [ POPUPS ]-----------------------------------------------------------------------------------------
StaticPopupDialogs[RENAME_CATEGORY_POPUP] = {
    text = "%s",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 40,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(self, data)
        local cat = data and Orbit.BagCategoryStore:GetCategory(data.categoryId)
        self.EditBox:SetText(cat and cat.name or "")
        self.EditBox:HighlightText()
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self, data)
        if not data or not data.categoryId then return end
        local name = self.EditBox:GetText()
        if name and name ~= "" then
            Orbit.BagCategoryStore:RenameCategory(data.categoryId, name)
        end
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent().Buttons[1]:Click() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

local function PromptRenameCategory(categoryId)
    StaticPopup_Show(RENAME_CATEGORY_POPUP, L.PLU_BAGS_NAME_LABEL, nil, { categoryId = categoryId })
end

-- [ ITEM MENU ]--------------------------------------------------------------------------------------
function BagContextMenu.OpenItemMenu(slotButton)
    if not slotButton or not slotButton.itemID then return end
    local itemID = slotButton.itemID
    local store = Orbit.BagCategoryStore
    MenuUtil.CreateContextMenu(slotButton, function(_, root)
        local cats = store:GetOrderedCategories()
        local pinMenu = root:CreateButton(L.PLU_BAGS_PIN_TO)
        for _, cat in ipairs(cats) do
            local catId = cat.id
            pinMenu:CreateButton(ColoredSwatch(cat.color) .. " " .. (cat.name ~= "" and cat.name or "—"), function()
                store:PinItem(itemID, catId)
            end)
        end
        if #cats > 0 then pinMenu:CreateDivider() end
        pinMenu:CreateButton(L.PLU_BAGS_HIDDEN, function() store:PinItem(itemID, store.HIDDEN_ID) end)
        if store:GetCategoryForItem(itemID) then
            root:CreateButton(L.PLU_BAGS_UNPIN, function() store:UnpinItem(itemID) end)
        end
    end)
end

-- [ PORTRAIT MENU ]----------------------------------------------------------------------------------
function BagContextMenu.OpenPortraitMenu(anchor)
    local store = Orbit.BagCategoryStore
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateCheckbox(L.PLU_BAGS_SHOW_HIDDEN,
            function() return store:IsHiddenShown() end,
            function() store:SetHiddenShown(not store:IsHiddenShown()) end)
    end)
end

-- [ CATEGORY MENU ]----------------------------------------------------------------------------------
function BagContextMenu.OpenCategoryMenu(regionFrame, categoryId)
    if not categoryId then return end
    local store = Orbit.BagCategoryStore
    MenuUtil.CreateContextMenu(regionFrame, function(_, root)
        root:CreateButton(L.PLU_BAGS_RENAME, function() PromptRenameCategory(categoryId) end)
        local colorMenu = root:CreateButton(L.PLU_BAGS_COLOR)
        for _, color in ipairs(PALETTE) do
            local swatch = color
            colorMenu:CreateButton(ColoredSwatch(swatch) .. " ", function()
                store:RecolorCategory(categoryId, swatch)
            end)
        end
        root:CreateDivider()
        root:CreateButton(L.CMN_DELETE, function() store:DeleteCategory(categoryId) end)
    end)
end

-- [ DRAG-TO-PIN ]------------------------------------------------------------------------------------
function BagContextMenu.OnRegionReceiveDrag(regionFrame)
    if not regionFrame or not regionFrame.categoryId then return end
    if not CursorHasItem() then return end
    local cursorType, itemID = GetCursorInfo()
    if cursorType == "item" and itemID then
        Orbit.BagCategoryStore:PinItem(itemID, regionFrame.categoryId)
        ClearCursor()
    end
end
