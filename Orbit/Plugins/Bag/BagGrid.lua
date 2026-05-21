local _, addonTable = ...
local Orbit = addonTable

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local NUM_PLAYER_BAGS = 6
local CELL_SIZE = 40
local CELL_PADDING = 1
local STRIDE = CELL_SIZE + CELL_PADDING
local DEFAULT_COLS = 16
local CATEGORY_HEADER_HEIGHT = 16
local CATEGORY_HEADER_FONT_SIZE = 11
local CATEGORY_STRIPE_WIDTH = 3
local CATEGORY_INNER_PADDING = 2
local POOL_GAP = STRIDE
local FILTERED_ALPHA = 0.3
local CATEGORY_BG_ALPHA = 0.18
local CATEGORY_BORDER_ALPHA = 0.85
local EMPTY_CELL_R, EMPTY_CELL_G, EMPTY_CELL_B = 0.18, 0.18, 0.22
local EMPTY_CELL_ALPHA = 0.45
local MARQUEE_BG_R, MARQUEE_BG_G, MARQUEE_BG_B = 0.6, 0.85, 1.0
local MARQUEE_BG_ALPHA = 0.18
local MARQUEE_BORDER_ALPHA = 0.85

local DEFAULT_QUALITY_ATLAS = "wowlabs-in-world-item-common"
local QUALITY_ATLASES = {
    [Enum.ItemQuality.Poor]      = "wowlabs-in-world-item-common",
    [Enum.ItemQuality.Common]    = "wowlabs-in-world-item-common",
    [Enum.ItemQuality.Uncommon]  = "wowlabs-in-world-item-uncommon",
    [Enum.ItemQuality.Rare]      = "wowlabs-in-world-item-rare",
    [Enum.ItemQuality.Epic]      = "wowlabs-in-world-item-epic",
    [Enum.ItemQuality.Legendary] = "wowlabs-in-world-item-legendary",
    [Enum.ItemQuality.Artifact]  = "wowlabs-in-world-item-legendary",
    [Enum.ItemQuality.Heirloom]  = "wowlabs-in-world-item-legendary",
    [Enum.ItemQuality.WoWToken]  = "wowlabs-in-world-item-common",
}
local ICON_INSET = 2
local BORDER_OVERSIZE = 0
local MASK_OVERSIZE = 6
local HIGHLIGHT_ATLAS = "common-button-tertiary-square-selected"
local NEW_ITEM_ATLAS = "bags-newitem"
local COSMETIC_ATLAS = "CosmeticIconFrame"
local CURIO_ATLAS = "delves-curios-icon-border"
local ICON_MASK_ATLAS = "UI-HUD-ActionBar-IconFrame-Mask"

-- [ MODULE ]-----------------------------------------------------------------------------------------
Orbit.BagGrid = {}
local BagGrid = Orbit.BagGrid

local Masque = LibStub("Masque", true)
local masqueGroup = Masque and Masque:Group("Orbit", "Bag")

-- [ COORDS ]-----------------------------------------------------------------------------------------
local function CellLocalPos(col, row) return col * STRIDE, -(row * STRIDE) end

local function WorkspaceCursorCell(workspace)
    local x, y = GetCursorPosition()
    local scale = workspace:GetEffectiveScale()
    local left, top = workspace:GetLeft(), workspace:GetTop()
    if not left or not top then return 0, 0 end
    local localX = (x / scale) - left
    local localY = top - (y / scale)
    return math.max(0, math.floor(localX / STRIDE)), math.max(0, math.floor(localY / STRIDE))
end

-- [ SLOT SCRIPTS ]-----------------------------------------------------------------------------------
local function OnSlotEnter(self)
    if not self.bagID or not self.slotID then return end
    if GameTooltip:GetOwner() == self then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(self.bagID, self.slotID)
    GameTooltip:Show()
end

local function OnSlotLeave(self)
    if self:IsMouseOver() then return end
    if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end

local function OnSlotMouseUp(self, mouseButton)
    if not self.bagID or not self.slotID then return end
    if mouseButton == "LeftButton" then
        if InCombatLockdown() then return end
        local link = C_Container.GetContainerItemLink(self.bagID, self.slotID)
        if link and IsModifiedClick() and HandleModifiedItemClick(link) then return end
        C_Container.PickupContainerItem(self.bagID, self.slotID)
    elseif mouseButton == "RightButton" then
        if IsShiftKeyDown() and Orbit.BagContextMenu and Orbit.BagContextMenu.OpenItemMenu then
            Orbit.BagContextMenu.OpenItemMenu(self)
            return
        end
        if InCombatLockdown() then return end
        C_Container.UseContainerItem(self.bagID, self.slotID)
    end
end

local function OnSlotDragStart(self)
    if not self.bagID or not self.slotID then return end
    if InCombatLockdown() then return end
    C_Container.PickupContainerItem(self.bagID, self.slotID)
end

local function IsStackNew(stack)
    if not stack or not stack.sources then return false end
    for _, src in ipairs(stack.sources) do
        if C_NewItems and C_NewItems.IsNewItem(src.bag, src.slot) then return true end
    end
    return false
end

local function IsDelveCurio(itemID)
    if not itemID or not C_Item or not C_Item.GetItemInfo then return false end
    local _, _, _, _, _, _, subType = C_Item.GetItemInfo(itemID)
    return subType and string.find(string.lower(subType), "curio") ~= nil or false
end

local function ResolveBorderAtlas(stack)
    local itemID = stack.itemID
    if itemID and C_Item and C_Item.IsCosmeticItem and C_Item.IsCosmeticItem(itemID) then
        return COSMETIC_ATLAS
    end
    if IsDelveCurio(itemID) then return CURIO_ATLAS end
    return QUALITY_ATLASES[stack.info.quality] or DEFAULT_QUALITY_ATLAS
end

local function ConfigureSlot(button, stack)
    if stack then
        local primary = stack.sources[1]
        button.bagID = primary.bag
        button.slotID = primary.slot
        button.itemID = stack.itemID
        SetItemButtonTexture(button, stack.info.iconFileID)
        SetItemButtonCount(button, stack.totalCount or stack.info.stackCount or 0)
        SetItemButtonDesaturated(button, stack.info.isLocked or stack.info.isFiltered)
        button:SetAlpha(stack.info.isFiltered and FILTERED_ALPHA or 1)
        if button.IconBorder then
            button.IconBorder:SetAtlas(ResolveBorderAtlas(stack))
            button.IconBorder:SetVertexColor(1, 1, 1, 1)
            button.IconBorder:SetDesaturated(false)
            button.IconBorder:ClearAllPoints()
            button.IconBorder:SetPoint("TOPLEFT", button, "TOPLEFT", -BORDER_OVERSIZE, BORDER_OVERSIZE)
            button.IconBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", BORDER_OVERSIZE, -BORDER_OVERSIZE)
            button.IconBorder:Show()
        end
        if button._orbitNewItem then
            if IsStackNew(stack) then button._orbitNewItem:Show() else button._orbitNewItem:Hide() end
        end
    else
        button.bagID = nil
        button.slotID = nil
        button.itemID = nil
        SetItemButtonTexture(button, nil)
        SetItemButtonCount(button, 0)
        SetItemButtonDesaturated(button, false)
        button:SetAlpha(1)
        if button.IconBorder then button.IconBorder:Hide() end
        if button._orbitNewItem then button._orbitNewItem:Hide() end
    end
end

local function ResolveAsync(button, stack)
    local primary = stack and stack.sources and stack.sources[1]
    if not primary then return end
    local item = Item:CreateFromBagAndSlot(primary.bag, primary.slot)
    if item:IsItemEmpty() or item:IsItemDataCached() then return end
    item:ContinueOnItemLoad(function()
        if button.itemID == stack.itemID then
            stack.info = C_Container.GetContainerItemInfo(primary.bag, primary.slot) or stack.info
            ConfigureSlot(button, stack)
        end
    end)
end

local function StripDefaultChrome(button)
    local normal = button:GetNormalTexture()
    if normal then normal:SetTexture(nil); normal:SetAtlas(nil); normal:Hide() end
    local pushed = button:GetPushedTexture()
    if pushed then pushed:SetTexture(nil); pushed:SetAtlas(nil) end
    if button.NewItemTexture then button.NewItemTexture:Hide() end
    if button.BattlepayItemTexture then button.BattlepayItemTexture:Hide() end
end

local function ApplyHighlightAtlas(button)
    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetAlpha(0) end
end

local function InitSlotIcon(button)
    if not button.icon then return end
    button.icon:ClearAllPoints()
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", ICON_INSET, -ICON_INSET)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
    if not button._orbitMask then
        button._orbitMask = button:CreateMaskTexture()
        button._orbitMask:SetAtlas(ICON_MASK_ATLAS, false, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if button.icon.AddMaskTexture then button.icon:AddMaskTexture(button._orbitMask) end
    end
    button._orbitMask:ClearAllPoints()
    button._orbitMask:SetPoint("TOPLEFT", button.icon, "TOPLEFT", -MASK_OVERSIZE, MASK_OVERSIZE)
    button._orbitMask:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", MASK_OVERSIZE, -MASK_OVERSIZE)
end

local function InitSlotLayers(button)
    if button.IconBorder then button.IconBorder:SetDrawLayer("ARTWORK", 7) end
    if not button._orbitNewItem then
        button._orbitNewItem = button:CreateTexture(nil, "OVERLAY", nil, 2)
        button._orbitNewItem:SetAtlas(NEW_ITEM_ATLAS)
        button._orbitNewItem:SetBlendMode("ADD")
        button._orbitNewItem:Hide()
    end
    button._orbitNewItem:ClearAllPoints()
    button._orbitNewItem:SetPoint("TOPLEFT", button, "TOPLEFT", -BORDER_OVERSIZE, BORDER_OVERSIZE)
    button._orbitNewItem:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", BORDER_OVERSIZE, -BORDER_OVERSIZE)
    local count = button.Count or _G[(button:GetName() or "") .. "Count"]
    if count then count:SetDrawLayer("OVERLAY", 7) end
end

local function InitSlot(button)
    if button._orbitInitialized then return end
    button._orbitInitialized = true
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", nil)
    button:SetScript("OnEnter", OnSlotEnter)
    button:SetScript("OnLeave", OnSlotLeave)
    button:SetScript("OnMouseUp", OnSlotMouseUp)
    button:SetScript("OnDragStart", OnSlotDragStart)
    button:SetScript("OnReceiveDrag", OnSlotDragStart)
    StripDefaultChrome(button)
    ApplyHighlightAtlas(button)
    InitSlotIcon(button)
    InitSlotLayers(button)
    if masqueGroup then masqueGroup:AddButton(button) end
end

-- [ SLOT POOL ]--------------------------------------------------------------------------------------
local function AcquireSlot(workspace, index)
    local btn = workspace.slots[index]
    if not btn then
        btn = CreateFrame("ItemButton", "OrbitBagSlot" .. index, workspace, "ContainerFrameItemButtonTemplate")
        workspace.slots[index] = btn
    end
    InitSlot(btn)
    btn:SetFrameLevel(workspace:GetFrameLevel() + 10)
    btn:SetSize(CELL_SIZE, CELL_SIZE)
    return btn
end

-- [ EMPTY CELL POOL ]--------------------------------------------------------------------------------
local function AcquireEmptyCell(parent, key)
    parent._emptyCells = parent._emptyCells or {}
    local tex = parent._emptyCells[key]
    if not tex then
        tex = parent:CreateTexture(nil, "ARTWORK")
        tex:SetColorTexture(EMPTY_CELL_R, EMPTY_CELL_G, EMPTY_CELL_B, EMPTY_CELL_ALPHA)
        parent._emptyCells[key] = tex
    end
    tex:SetSize(CELL_SIZE, CELL_SIZE)
    return tex
end

local function HideUnusedEmptyCells(parent, usedSet)
    if not parent._emptyCells then return end
    for key, tex in pairs(parent._emptyCells) do
        if not usedSet[key] then tex:Hide() end
    end
end

-- [ CATEGORY REGION ]--------------------------------------------------------------------------------
local function SnapRegionToGrid(region, workspace)
    local wsLeft, wsTop = workspace:GetLeft(), workspace:GetTop()
    local rLeft, rTop = region:GetLeft(), region:GetTop()
    if not wsLeft or not wsTop or not rLeft or not rTop then return end
    local localX = rLeft - wsLeft
    local localY = wsTop - rTop
    local cellX = math.max(0, math.floor((localX + STRIDE / 2) / STRIDE))
    local cellY = math.max(0, math.floor((localY + STRIDE / 2) / STRIDE))
    if region.categoryId then
        Orbit.BagCategoryStore:MoveCategory(region.categoryId, cellX, cellY)
    end
end

local function CreateRegionFrame(workspace, catId)
    local f = CreateFrame("Frame", "OrbitBagRegion" .. catId, workspace, "BackdropTemplate")
    f:SetFrameLevel(workspace:GetFrameLevel() + 5)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    f.header = CreateFrame("Frame", nil, f)
    f.header:SetHeight(CATEGORY_HEADER_HEIGHT)
    f.header:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 1)
    f.header:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 1)
    f.header:SetFrameLevel(f:GetFrameLevel() + 1)
    f.header:EnableMouse(true)
    f.header:RegisterForDrag("LeftButton")
    f.header:SetScript("OnDragStart", function() f:StartMoving() end)
    f.header:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        SnapRegionToGrid(f, workspace)
    end)
    f.header:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and CursorHasItem() and Orbit.BagContextMenu
                and Orbit.BagContextMenu.OnRegionReceiveDrag then
            Orbit.BagContextMenu.OnRegionReceiveDrag(f)
            return
        end
        if button == "RightButton" and Orbit.BagContextMenu and Orbit.BagContextMenu.OpenCategoryMenu then
            Orbit.BagContextMenu.OpenCategoryMenu(f, f.categoryId)
        end
    end)
    f.header:SetScript("OnReceiveDrag", function()
        if Orbit.BagContextMenu and Orbit.BagContextMenu.OnRegionReceiveDrag then
            Orbit.BagContextMenu.OnRegionReceiveDrag(f)
        end
    end)

    f.headerStripe = f.header:CreateTexture(nil, "OVERLAY")
    f.headerStripe:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.headerStripe:SetSize(CATEGORY_STRIPE_WIDTH, CATEGORY_HEADER_HEIGHT - 2)
    f.headerStripe:SetPoint("LEFT", f.header, "LEFT", 2, 0)
    f.headerLabel = f.header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.headerLabel:SetFont(STANDARD_TEXT_FONT, CATEGORY_HEADER_FONT_SIZE, "OUTLINE")
    f.headerLabel:SetPoint("LEFT", f.headerStripe, "RIGHT", 4, 0)

    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and CursorHasItem() then
            if Orbit.BagContextMenu and Orbit.BagContextMenu.OnRegionReceiveDrag then
                Orbit.BagContextMenu.OnRegionReceiveDrag(self)
            end
            return
        end
        if button == "RightButton" and Orbit.BagContextMenu and Orbit.BagContextMenu.OpenCategoryMenu then
            Orbit.BagContextMenu.OpenCategoryMenu(self, self.categoryId)
        end
    end)
    f:SetScript("OnReceiveDrag", function(self)
        if Orbit.BagContextMenu and Orbit.BagContextMenu.OnRegionReceiveDrag then
            Orbit.BagContextMenu.OnRegionReceiveDrag(self)
        end
    end)
    return f
end

local function HideAllSlotsAfter(workspace, idx)
    for i = idx + 1, #workspace.slots do workspace.slots[i]:Hide() end
end

local function HideObsoleteRegions(workspace, activeIds)
    for id, region in pairs(workspace.regions) do
        if not activeIds[id] then
            region:Hide()
            if region._emptyCells then
                for _, tex in pairs(region._emptyCells) do tex:Hide() end
            end
        end
    end
end

-- [ MARQUEE ]----------------------------------------------------------------------------------------
local marquee = { active = false }

local function EnsureMarqueeFrame(workspace)
    if marquee.frame then return marquee.frame end
    local f = CreateFrame("Frame", "OrbitBagMarquee", workspace, "BackdropTemplate")
    f:SetFrameLevel(workspace:GetFrameLevel() + 50)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(MARQUEE_BG_R, MARQUEE_BG_G, MARQUEE_BG_B, MARQUEE_BG_ALPHA)
    f:SetBackdropBorderColor(MARQUEE_BG_R, MARQUEE_BG_G, MARQUEE_BG_B, MARQUEE_BORDER_ALPHA)
    f:Hide()
    marquee.frame = f
    return f
end

local function UpdateMarqueeVisual(workspace)
    if not marquee.active then return end
    local col, row = WorkspaceCursorCell(workspace)
    marquee.endCol = col
    marquee.endRow = row
    local x1 = math.min(marquee.startCol, marquee.endCol)
    local y1 = math.min(marquee.startRow, marquee.endRow)
    local w = math.abs(marquee.endCol - marquee.startCol) + 1
    local h = math.abs(marquee.endRow - marquee.startRow) + 1
    local px, py = CellLocalPos(x1, y1)
    marquee.frame:ClearAllPoints()
    marquee.frame:SetPoint("TOPLEFT", workspace, "TOPLEFT", px, py)
    marquee.frame:SetSize(w * STRIDE - CELL_PADDING, h * STRIDE - CELL_PADDING)
end

local function OnMarqueeUpdate(self) UpdateMarqueeVisual(marquee.workspace) end

local function StartMarquee(workspace)
    local frame = EnsureMarqueeFrame(workspace)
    marquee.active = true
    marquee.workspace = workspace
    marquee.startCol, marquee.startRow = WorkspaceCursorCell(workspace)
    marquee.endCol, marquee.endRow = marquee.startCol, marquee.startRow
    frame:Show()
    frame:SetScript("OnUpdate", OnMarqueeUpdate)
    UpdateMarqueeVisual(workspace)
end

local function EndMarquee(workspace, plugin)
    if not marquee.active then return end
    marquee.active = false
    if marquee.frame then
        marquee.frame:SetScript("OnUpdate", nil)
        marquee.frame:Hide()
    end
    local x1 = math.min(marquee.startCol, marquee.endCol)
    local y1 = math.min(marquee.startRow, marquee.endRow)
    local w = math.abs(marquee.endCol - marquee.startCol) + 1
    local h = math.abs(marquee.endRow - marquee.startRow) + 1
    if w < 1 or h < 1 then return end
    local store = Orbit.BagCategoryStore
    if store:RegionOverlapsAny(x1, y1, w, h) then return end
    store:CreateCategory({ x = x1, y = y1, w = w, h = h }, "", { r = 0.6, g = 0.7, b = 0.9 })
end

-- [ ITEM COLLECTION ]--------------------------------------------------------------------------------
local function CollectStacks()
    local stacks = {}
    local byItemID = {}
    for bag = 0, NUM_PLAYER_BAGS - 1 do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local stack = byItemID[info.itemID]
                if not stack then
                    stack = { itemID = info.itemID, info = info, totalCount = 0, sources = {} }
                    byItemID[info.itemID] = stack
                    table.insert(stacks, stack)
                end
                stack.totalCount = stack.totalCount + (info.stackCount or 1)
                table.insert(stack.sources, { bag = bag, slot = slot })
            end
        end
    end
    return stacks
end

local function GroupStacks(stacks, store)
    local byCategory, allStacks, hiddenStacks = {}, {}, {}
    local HIDDEN_ID = store.HIDDEN_ID
    for _, stack in ipairs(stacks) do
        local catId = store:GetCategoryForItem(stack.itemID)
        if catId == HIDDEN_ID then
            table.insert(hiddenStacks, stack)
        elseif catId then
            byCategory[catId] = byCategory[catId] or {}
            table.insert(byCategory[catId], stack)
        else
            table.insert(allStacks, stack)
        end
    end
    return byCategory, allStacks, hiddenStacks
end

-- [ BUILD ]------------------------------------------------------------------------------------------
function BagGrid:Build(plugin, bagFrame, anchorTop)
    local workspace = CreateFrame("Frame", "OrbitBagWorkspace", bagFrame)
    workspace:SetFrameLevel(bagFrame:GetFrameLevel() + 5)
    workspace:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 8, -(anchorTop + CATEGORY_HEADER_HEIGHT))
    workspace:SetSize(DEFAULT_COLS * STRIDE, STRIDE)
    workspace:EnableMouse(true)
    workspace.slots = {}
    workspace.regions = {}
    workspace.plugin = plugin

    workspace:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then StartMarquee(self) end
    end)
    workspace:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then EndMarquee(self, plugin) end
    end)

    return workspace
end

-- [ APPLY ]------------------------------------------------------------------------------------------
function BagGrid:Apply(plugin, workspace)
    if not workspace then return end

    local store = Orbit.BagCategoryStore
    local categories = store:GetOrderedCategories()
    local stacks = CollectStacks()
    local byCategory, allItems, hiddenItems = GroupStacks(stacks, store)

    local slotIndex = 0
    local maxRow = 0
    local activeRegionIds = {}

    for _, cat in ipairs(categories) do
        local r = cat.region
        if not r then break end
        activeRegionIds[cat.id] = true

        local region = workspace.regions[cat.id] or CreateRegionFrame(workspace, cat.id)
        workspace.regions[cat.id] = region
        region.categoryId = cat.id

        local regionW = r.w * STRIDE - CELL_PADDING
        local regionH = r.h * STRIDE - CELL_PADDING
        local regionX, regionY = CellLocalPos(r.x, r.y)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", workspace, "TOPLEFT", regionX, regionY)
        region:SetSize(regionW, regionH)
        region:SetBackdropColor(cat.color.r, cat.color.g, cat.color.b, CATEGORY_BG_ALPHA)
        region:SetBackdropBorderColor(cat.color.r, cat.color.g, cat.color.b, CATEGORY_BORDER_ALPHA)
        region.headerStripe:SetColorTexture(cat.color.r, cat.color.g, cat.color.b, 1)
        region.headerLabel:SetText(cat.name ~= "" and cat.name or "—")
        region:Show()

        local pinned = byCategory[cat.id] or {}
        local pinnedIdx = 0
        local usedCells = {}
        for row = 0, r.h - 1 do
            for col = 0, r.w - 1 do
                local cellKey = col .. "," .. row
                usedCells[cellKey] = true
                local cellX = col * STRIDE
                local cellY = -(row * STRIDE)
                pinnedIdx = pinnedIdx + 1
                local stack = pinned[pinnedIdx]
                if stack then
                    slotIndex = slotIndex + 1
                    local btn = AcquireSlot(workspace, slotIndex)
                    if btn:GetParent() ~= region then btn:SetParent(region) end
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", region, "TOPLEFT", cellX, cellY)
                    ConfigureSlot(btn, stack)
                    if stack.info and stack.info.itemID and not C_Item.IsItemDataCachedByID(stack.info.itemID) then
                        ResolveAsync(btn, stack)
                    end
                    btn:Show()
                    local emptyTex = region._emptyCells and region._emptyCells[cellKey]
                    if emptyTex then emptyTex:Hide() end
                else
                    local tex = AcquireEmptyCell(region, cellKey)
                    tex:ClearAllPoints()
                    tex:SetPoint("TOPLEFT", region, "TOPLEFT", cellX, cellY)
                    tex:Show()
                end
            end
        end
        HideUnusedEmptyCells(region, usedCells)

        local bottomRow = r.y + r.h
        if bottomRow > maxRow then maxRow = bottomRow end
    end

    HideObsoleteRegions(workspace, activeRegionIds)

    local poolStartLocalY
    if maxRow > 0 then
        poolStartLocalY = maxRow * STRIDE + POOL_GAP
    else
        poolStartLocalY = 0
    end
    local poolCols = DEFAULT_COLS
    for index, stack in ipairs(allItems) do
        slotIndex = slotIndex + 1
        local btn = AcquireSlot(workspace, slotIndex)
        if btn:GetParent() ~= workspace then btn:SetParent(workspace) end
        btn:ClearAllPoints()
        local col = (index - 1) % poolCols
        local row = math.floor((index - 1) / poolCols)
        btn:SetPoint("TOPLEFT", workspace, "TOPLEFT", col * STRIDE, -(poolStartLocalY + row * STRIDE))
        ConfigureSlot(btn, stack)
        if stack.info and stack.info.itemID and not C_Item.IsItemDataCachedByID(stack.info.itemID) then
            ResolveAsync(btn, stack)
        end
        btn:Show()
    end

    local poolRows = math.ceil(#allItems / poolCols)
    local totalHeight = poolStartLocalY + math.max(poolRows, 1) * STRIDE

    local showHidden = store:IsHiddenShown()
    if workspace.hiddenLabel then workspace.hiddenLabel:Hide() end
    if workspace.hiddenPlaceholder then workspace.hiddenPlaceholder:Hide() end
    if showHidden then
        if not workspace.hiddenLabel then
            workspace.hiddenLabel = workspace:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            workspace.hiddenLabel:SetFont(STANDARD_TEXT_FONT, CATEGORY_HEADER_FONT_SIZE, "OUTLINE")
        end
        local count = #hiddenItems
        workspace.hiddenLabel:SetFormattedText("%s  |cff808080(%d)|r", Orbit.L.PLU_BAGS_HIDDEN, count)
        local labelY = totalHeight + POOL_GAP
        workspace.hiddenLabel:ClearAllPoints()
        workspace.hiddenLabel:SetPoint("TOPLEFT", workspace, "TOPLEFT", 2, -labelY)
        workspace.hiddenLabel:Show()
        local hiddenStartY = labelY + CATEGORY_HEADER_HEIGHT
        if count > 0 then
            for index, stack in ipairs(hiddenItems) do
                slotIndex = slotIndex + 1
                local btn = AcquireSlot(workspace, slotIndex)
                if btn:GetParent() ~= workspace then btn:SetParent(workspace) end
                btn:ClearAllPoints()
                local col = (index - 1) % poolCols
                local row = math.floor((index - 1) / poolCols)
                btn:SetPoint("TOPLEFT", workspace, "TOPLEFT", col * STRIDE, -(hiddenStartY + row * STRIDE))
                ConfigureSlot(btn, stack)
                btn:SetAlpha(FILTERED_ALPHA)
                btn:Show()
            end
            local hiddenRows = math.ceil(count / poolCols)
            totalHeight = hiddenStartY + hiddenRows * STRIDE
        else
            if not workspace.hiddenPlaceholder then
                workspace.hiddenPlaceholder = workspace:CreateFontString(nil, "OVERLAY", "GameFontDisable")
                workspace.hiddenPlaceholder:SetFont(STANDARD_TEXT_FONT, CATEGORY_HEADER_FONT_SIZE, "OUTLINE")
                workspace.hiddenPlaceholder:SetText("—")
            end
            workspace.hiddenPlaceholder:ClearAllPoints()
            workspace.hiddenPlaceholder:SetPoint("TOPLEFT", workspace, "TOPLEFT", 2, -hiddenStartY)
            workspace.hiddenPlaceholder:Show()
            totalHeight = hiddenStartY + CATEGORY_HEADER_HEIGHT
        end
    end

    HideAllSlotsAfter(workspace, slotIndex)

    if masqueGroup then masqueGroup:ReSkin() end

    workspace:SetSize(DEFAULT_COLS * STRIDE, totalHeight)
end

-- [ DIMENSIONS ]-------------------------------------------------------------------------------------
function BagGrid:GetCellSize() return CELL_SIZE end
function BagGrid:GetStride() return STRIDE end
function BagGrid:GetDefaultCols() return DEFAULT_COLS end
function BagGrid:GetWorkspaceTopOffset() return CATEGORY_HEADER_HEIGHT end
