local _, addonTable = ...
local Orbit = addonTable

-- [ MODULE ]-----------------------------------------------------------------------------------------
Orbit.BagCategoryStore = {}
local BagCategoryStore = Orbit.BagCategoryStore

local HIDDEN_ID = "_hidden"
BagCategoryStore.HIDDEN_ID = HIDDEN_ID

local function ItemKey(itemID) return "i:" .. tostring(itemID) end

-- [ STORE ACCESS ]-----------------------------------------------------------------------------------
function BagCategoryStore:GetData()
    local account = Orbit.db and Orbit.db.AccountSettings
    if not account then return nil end
    if not account.BagCategories then
        account.BagCategories = { categories = {}, displayOrder = {}, nextId = 1, hiddenItems = {}, showHidden = false }
    end
    local data = account.BagCategories
    data.categories = data.categories or {}
    data.displayOrder = data.displayOrder or {}
    data.nextId = data.nextId or 1
    data.hiddenItems = data.hiddenItems or {}
    if data.showHidden == nil then data.showHidden = false end
    return data
end

-- [ CATEGORY CRUD ]----------------------------------------------------------------------------------
function BagCategoryStore:CreateCategory(region, name, color)
    local data = self:GetData()
    if not data or not region then return nil end
    local id = tostring(data.nextId)
    data.nextId = data.nextId + 1
    data.categories[id] = {
        id = id,
        name = name or "",
        color = color or { r = 0.6, g = 0.7, b = 0.9 },
        region = { x = region.x, y = region.y, w = region.w, h = region.h },
        addedItems = {},
    }
    table.insert(data.displayOrder, 1, id)
    Orbit.EventBus:Fire("ORBIT_BAG_CATEGORIES_CHANGED")
    return id
end

function BagCategoryStore:DeleteCategory(id)
    local data = self:GetData()
    if not data or not data.categories[id] then return end
    data.categories[id] = nil
    for i = #data.displayOrder, 1, -1 do
        if data.displayOrder[i] == id then table.remove(data.displayOrder, i) end
    end
    Orbit.EventBus:Fire("ORBIT_BAG_CATEGORIES_CHANGED")
end

function BagCategoryStore:RenameCategory(id, name)
    local data = self:GetData()
    local cat = data and data.categories[id]
    if not cat then return end
    cat.name = name or ""
    Orbit.EventBus:Fire("ORBIT_BAG_CATEGORIES_CHANGED")
end

function BagCategoryStore:RecolorCategory(id, color)
    local data = self:GetData()
    local cat = data and data.categories[id]
    if not cat or not color then return end
    cat.color = { r = color.r, g = color.g, b = color.b }
    Orbit.EventBus:Fire("ORBIT_BAG_CATEGORIES_CHANGED")
end

function BagCategoryStore:MoveCategory(id, newX, newY)
    local data = self:GetData()
    local cat = data and data.categories[id]
    if not cat or not cat.region then return end
    newX, newY = math.max(0, newX), math.max(0, newY)
    if self:RegionOverlapsAny(newX, newY, cat.region.w, cat.region.h, id) then
        Orbit.EventBus:Fire("ORBIT_BAG_CATEGORIES_CHANGED")
        return
    end
    cat.region.x = newX
    cat.region.y = newY
    Orbit.EventBus:Fire("ORBIT_BAG_CATEGORIES_CHANGED")
end

-- [ ITEM PINS ]--------------------------------------------------------------------------------------
function BagCategoryStore:PinItem(itemID, categoryId)
    local data = self:GetData()
    if not data or not itemID then return end
    local key = ItemKey(itemID)
    if categoryId == HIDDEN_ID then
        for _, cat in pairs(data.categories) do cat.addedItems[key] = nil end
        data.hiddenItems[key] = true
        Orbit.EventBus:Fire("ORBIT_BAG_CATEGORIES_CHANGED")
        return
    end
    local target = data.categories[categoryId]
    if not target then return end
    for _, cat in pairs(data.categories) do cat.addedItems[key] = nil end
    data.hiddenItems[key] = nil
    target.addedItems[key] = true
    Orbit.EventBus:Fire("ORBIT_BAG_CATEGORIES_CHANGED")
end

function BagCategoryStore:UnpinItem(itemID)
    local data = self:GetData()
    if not data or not itemID then return end
    local key = ItemKey(itemID)
    for _, cat in pairs(data.categories) do cat.addedItems[key] = nil end
    data.hiddenItems[key] = nil
    Orbit.EventBus:Fire("ORBIT_BAG_CATEGORIES_CHANGED")
end

-- [ HIDDEN CATEGORY ]--------------------------------------------------------------------------------
function BagCategoryStore:IsItemHidden(itemID)
    local data = self:GetData()
    if not data or not itemID then return false end
    return data.hiddenItems[ItemKey(itemID)] == true
end

function BagCategoryStore:IsHiddenShown()
    local data = self:GetData()
    return data and data.showHidden or false
end

function BagCategoryStore:SetHiddenShown(val)
    local data = self:GetData()
    if not data then return end
    data.showHidden = val and true or false
    Orbit.EventBus:Fire("ORBIT_BAG_CATEGORIES_CHANGED")
end

-- [ LOOKUPS ]----------------------------------------------------------------------------------------
function BagCategoryStore:GetCategoryForItem(itemID)
    local data = self:GetData()
    if not data or not itemID then return nil end
    local key = ItemKey(itemID)
    if data.hiddenItems[key] then return HIDDEN_ID end
    for _, id in ipairs(data.displayOrder) do
        local cat = data.categories[id]
        if cat and cat.addedItems[key] then return id end
    end
    return nil
end

function BagCategoryStore:GetOrderedCategories()
    local data = self:GetData()
    if not data then return {} end
    local result = {}
    for _, id in ipairs(data.displayOrder) do
        local cat = data.categories[id]
        if cat then table.insert(result, cat) end
    end
    return result
end

function BagCategoryStore:GetCategory(id)
    local data = self:GetData()
    return data and data.categories[id] or nil
end

-- [ REGION OVERLAP ]---------------------------------------------------------------------------------
function BagCategoryStore:RegionOverlapsAny(x, y, w, h, excludeId)
    local data = self:GetData()
    if not data then return false end
    for id, cat in pairs(data.categories) do
        if id ~= excludeId then
            local r = cat.region
            if r and not (x + w <= r.x or x >= r.x + r.w or y + h <= r.y or y >= r.y + r.h) then
                return true
            end
        end
    end
    return false
end
