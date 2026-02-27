-- [ ORBIT ICON LAYOUT ENGINE ]----------------------------------------------------------------------
local _, Orbit = ...
local Skin = Orbit.Skin
local Constants = Orbit.Constants
local Pixel = Orbit.Engine.Pixel
Skin.IconLayout = {}
local IL = Skin.IconLayout

function IL:CalculateGeometry(frame, settings)
    if not frame then return Constants.Skin.DefaultIconSize, Constants.Skin.DefaultIconSize end
    local w
    if settings and settings.baseIconSize then
        w = settings.baseIconSize * ((settings.size or 100) / 100)
    else
        w = frame:GetWidth()
        if w <= 0 then w = Constants.Skin.DefaultIconSize end
    end
    local newWidth, newHeight = w, w
    local aspectRatio = settings and settings.aspectRatio or "1:1"
    local rw, rh = 1, 1
    if aspectRatio ~= "1:1" then
        local sw, sh = strsplit(":", aspectRatio)
        if sw and sh then
            rw, rh = tonumber(sw), tonumber(sh)
        elseif sw then
            local ratio = tonumber(sw)
            if ratio then rw, rh = ratio, 1 end
        end
    end
    if rw ~= rh then newHeight = newWidth * (rh / rw) end
    return newWidth, newHeight, rw, rh
end

function IL:ApplyManualLayout(frame, icons, settings)
    local padding = tonumber(settings.padding)
    if not padding then return end
    local limit = tonumber(settings.limit) or 10
    local orientation = tonumber(settings.orientation) or 0
    local totalIcons = #icons
    if totalIcons == 0 then return end

    local baseSize = settings.baseIconSize or Constants.Skin.DefaultIconSize
    local sizeMultiplier = (settings.size or 100) / 100
    local w, h = baseSize * sizeMultiplier, baseSize * sizeMultiplier

    local aspectRatio = settings.aspectRatio or "1:1"
    if aspectRatio ~= "1:1" then
        local sw, sh = strsplit(":", aspectRatio)
        if sw and sh then
            local rw, rh = tonumber(sw), tonumber(sh)
            if rw and rh and rw ~= rh then h = w * (rh / rw) end
        elseif sw then
            local ratio = tonumber(sw)
            if ratio and ratio ~= 1 then h = w / ratio end
        end
    end

    local scale = frame:GetEffectiveScale()
    w = Pixel:Snap(w, scale)
    h = Pixel:Snap(h, scale)
    padding = Pixel:Snap(padding, scale)

    local numGroups = math.ceil(totalIcons / limit)
    local maxMajorSize = (math.min(totalIcons, limit) * (orientation == 0 and w or h)) + ((math.min(totalIcons, limit) - 1) * padding)
    local hGrowth = settings.horizontalGrowth

    for i, icon in ipairs(icons) do
        icon:ClearAllPoints()
        local groupIdx = math.floor((i - 1) / limit)
        local itemIdx = (i - 1) % limit
        local col, row
        if orientation == 0 then row, col = groupIdx, itemIdx
        else col, row = groupIdx, itemIdx end

        local itemsInGroup = limit
        local itemsPrior = groupIdx * limit
        local itemsRemaining = totalIcons - itemsPrior
        if itemsRemaining < limit then itemsInGroup = itemsRemaining end

        local currentGroupSize = (itemsInGroup * (orientation == 0 and w or h)) + ((itemsInGroup - 1) * padding)
        local centeringOffset = (maxMajorSize - currentGroupSize) / 2
        local rowOffset
        if hGrowth == "LEFT" then rowOffset = maxMajorSize - currentGroupSize
        elseif hGrowth == "CENTER" or not hGrowth then rowOffset = centeringOffset
        else rowOffset = 0 end

        local x, y = 0, 0
        if settings.verticalGrowth == "UP" then
            if orientation == 0 then x = rowOffset + (col * (w + padding)); y = row * (h + padding)
            else x = col * (w + padding); y = centeringOffset + (row * (h + padding)) end
            x = Pixel:Snap(x, scale); y = Pixel:Snap(y, scale)
            icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, y)
        else
            if orientation == 0 then x = rowOffset + (col * (w + padding)); y = -row * (h + padding)
            else x = col * (w + padding); y = -(centeringOffset + (row * (h + padding))) end
            x = Pixel:Snap(x, scale); y = Pixel:Snap(y, scale)
            icon:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        end
    end

    local finalCols, finalRows
    if orientation == 0 then
        finalCols = math.min(totalIcons, limit)
        finalRows = math.ceil(totalIcons / limit)
    else
        finalRows = math.min(totalIcons, limit)
        finalCols = math.ceil(totalIcons / limit)
    end
    local finalW = (finalCols * w) + ((finalCols - 1) * padding)
    local finalH = (finalRows * h) + ((finalRows - 1) * padding)
    if finalW < 1 then finalW = w end
    if finalH < 1 then finalH = h end
    local curW, curH = frame:GetSize()
    if math.abs(curW - finalW) > 1 or math.abs(curH - finalH) > 1 then
        frame._orbitResizing = true
        frame:SetSize(finalW, finalH)
        frame._orbitResizing = false
    end
    frame.orbitRowHeight = h
    frame.orbitColumnWidth = w
end
