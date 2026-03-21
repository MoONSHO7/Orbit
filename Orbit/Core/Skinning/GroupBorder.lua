-- [ ORBIT GROUP BORDER ]----------------------------------------------------------------------------
-- Extracted from Skin.lua — group border merging for anchored frames.
-- Methods remain on Orbit.Skin for call-site compatibility.
local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local NINESLICE_LEVEL_OFFSET = Constants.Levels.Border

-- [ GROUP BORDER ]-----------------------------------------------------------------------------------
-- Creates a single wrapper border around all merged frames in an anchor chain.

function Skin:UpdateGroupBorder(rootFrame)
    if not rootFrame then return end

    local FrameAnchor = Orbit.Engine.FrameAnchor
    local GetFrameOptions = FrameAnchor.GetFrameOptions

    local topLeft, bottomRight = rootFrame, rootFrame
    local allFrames = { rootFrame }
    local hasMerge = false

    local ShouldMergeBorders = FrameAnchor.ShouldMergeBorders

    local function walk(frame)
        local children = FrameAnchor.childrenOf[frame]
        if not children then return end
        for child in pairs(children) do
            local a = FrameAnchor.anchors[child]
            if a and a.padding == 0 then
                local pOpts = GetFrameOptions(frame)
                local cOpts = GetFrameOptions(child)
                local merged = ShouldMergeBorders(pOpts, a.edge) and ShouldMergeBorders(cOpts, a.edge)
                    and child:IsShown() and child:GetAlpha() > 0
                if merged then
                    hasMerge = true
                    allFrames[#allFrames + 1] = child
                    if a.edge == "BOTTOM" or a.edge == "RIGHT" then bottomRight = child end
                    if a.edge == "TOP" or a.edge == "LEFT" then topLeft = child end
                    walk(child)
                end
            end
        end
    end
    walk(rootFrame)

    if not hasMerge then
        self:ClearGroupBorder(rootFrame)
        return
    end

    -- Icon containers are explicitly flagged via ApplyIconGroupBorder;
    -- check ALL frames in the chain — any icon container makes the whole group icon-styled
    local isIconStyle = false
    for _, frame in ipairs(allFrames) do
        if frame._isIconContainer then isIconStyle = true; break end
    end

    -- Mark all merged frames and hide their individual borders
    for _, frame in ipairs(allFrames) do
        frame._groupBorderActive = true
        frame._groupBorderRoot = rootFrame
        if frame._edgeBorderOverlay and frame._edgeBorderOverlay:IsShown() then
            frame._edgeBorderOverlay:Hide()
            frame._groupBorderHiddenNineSlice = true
        end
        if frame ~= rootFrame and frame._groupBorderOverlay then frame._groupBorderOverlay:Hide() end
        if frame._borderFrame and frame._borderFrame:IsShown() then
            frame._borderFrame:Hide()
            frame._groupBorderHiddenPixels = true
        end
        if frame._gridGroupBorder then frame._gridGroupBorder:Hide() end
    end

    -- Determine border mode: NineSlice texture or pixel flat
    local isPixelMode = false
    local styleEntry
    if isIconStyle then styleEntry = self:GetActiveIconBorderStyle() or self:GetActiveBorderStyle()
    else styleEntry = self:GetActiveBorderStyle() end
    if not styleEntry or not styleEntry.edgeFile then
        isPixelMode = true
    end

    -- Icon containers: boost above the highest child button level.
    -- Unit frames: border sits just above status textures (root level + Border offset),
    -- leaving canvas components (text, status icons) above the border.
    local overlayLevel
    if isIconStyle then
        local maxLevel = rootFrame:GetFrameLevel()
        for _, frame in ipairs(allFrames) do
            local fl = frame:GetFrameLevel()
            if fl > maxLevel then maxLevel = fl end
        end
        overlayLevel = maxLevel + Constants.Levels.IconOverlay
    else
        overlayLevel = rootFrame:GetFrameLevel() + NINESLICE_LEVEL_OFFSET
    end

    if not rootFrame._groupBorderOverlay then
        rootFrame._groupBorderOverlay = CreateFrame("Frame", nil, rootFrame, "BackdropTemplate")
        rootFrame._groupBorderOverlay:EnableMouse(false)
    end
    rootFrame._groupBorderOverlay:SetFrameLevel(overlayLevel)

    local overlay = rootFrame._groupBorderOverlay
    local gs = Orbit.db and Orbit.db.GlobalSettings

    -- Calculate bounding box from anchor edge data (deterministic, no screen coords needed).
    -- Each frame's position relative to rootFrame TOPLEFT is derived from its anchor edge.
    local positions = {}
    positions[rootFrame] = { x = 0, y = 0 }
    local function computePositions(frame)
        local pos = positions[frame]
        local children = FrameAnchor.childrenOf[frame]
        if not children then return end
        for child in pairs(children) do
            if not positions[child] then
                local a = FrameAnchor.anchors[child]
                if a and a.padding == 0 then
                    local cx, cy = pos.x, pos.y
                    if a.edge == "BOTTOM" then cy = pos.y + frame:GetHeight()
                    elseif a.edge == "TOP" then cy = pos.y - child:GetHeight()
                    elseif a.edge == "RIGHT" then cx = pos.x + frame:GetWidth()
                    elseif a.edge == "LEFT" then cx = pos.x - child:GetWidth()
                    end
                    positions[child] = { x = cx, y = cy }
                    computePositions(child)
                end
            end
        end
    end
    computePositions(rootFrame)

    local minX, maxX = 0, rootFrame:GetWidth()
    local minY, maxY = 0, rootFrame:GetHeight()
    for i = 2, #allFrames do
        local frame = allFrames[i]
        local pos = positions[frame]
        if pos then
            local r = pos.x + frame:GetWidth()
            local b = pos.y + frame:GetHeight()
            if pos.x < minX then minX = pos.x end
            if r > maxX then maxX = r end
            if pos.y < minY then minY = pos.y end
            if b > maxY then maxY = b end
        end
    end
    local totalW = maxX - minX
    local totalH = maxY - minY
    local offsetX = -minX
    local offsetY = -minY

    if isPixelMode then
        -- Pixel-style group overlay: use WHITE8x8 with pixel-snapped sizing
        local scale = rootFrame:GetEffectiveScale()
        if not scale or scale < 0.01 then scale = 1 end
        local borderSize = isIconStyle and (gs and gs.IconBorderSize or 2) or (gs and gs.BorderSize or 2)
        if borderSize <= 0 then overlay:Hide(); return end
        local pixelSize = Engine.Pixel:Multiple(borderSize, scale)
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", -offsetX, offsetY)
        overlay:SetSize(totalW, totalH)
        overlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = pixelSize })
        local colorKey = isIconStyle and "IconBorderColor" or "BorderColor"
        local c = (gs and gs[colorKey]) or { r = 0, g = 0, b = 0, a = 1 }
        overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    else
        -- NineSlice-style group overlay
        local edgeSize, borderOffset
        if isIconStyle then
            local iconStyle = self:BuildIconStyle(styleEntry)
            edgeSize = iconStyle.edgeSize
            borderOffset = iconStyle.borderOffset
        else
            edgeSize = (gs and gs.BorderEdgeSize) or Constants.BorderStyle.EdgeSize
            borderOffset = (gs and gs.BorderOffset) or 0
        end
        local grpScale = rootFrame:GetEffectiveScale()
        if not grpScale or grpScale < 0.01 then grpScale = 1 end
        local ownScale = rootFrame:GetScale() or 1
        if ownScale < 0.01 then ownScale = 1 end
        local adjEdge = edgeSize / ownScale
        local adjOffset = borderOffset / ownScale
        local outset = Engine.Pixel:Snap((adjEdge / 2) + adjOffset, grpScale)
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", -outset - offsetX, outset + offsetY)
        overlay:SetSize(Engine.Pixel:Snap(totalW + 2 * outset, grpScale), Engine.Pixel:Snap(totalH + 2 * outset, grpScale))
        overlay:SetBackdrop({ edgeFile = styleEntry.edgeFile, edgeSize = adjEdge })
        overlay:SetBackdropBorderColor(1, 1, 1, 1)
    end
    overlay:Show()

    -- Hook visibility changes so merges update immediately when frames show/hide
    -- (e.g. target frame via RegisterUnitWatch). Hooks are persistent and debounced.
    for _, frame in ipairs(allFrames) do
        if not frame._mergeVisHooked then
            frame:HookScript("OnShow", function() Skin:DeferGroupBorderRefresh() end)
            frame:HookScript("OnHide", function() Skin:DeferGroupBorderRefresh() end)
            frame._mergeVisHooked = true
        end
    end
end

function Skin:ClearGroupBorder(rootFrame)
    if not rootFrame then return end
    local function restoreFrame(frame)
        local wasActive = frame._groupBorderActive
        frame._groupBorderActive = nil
        frame._groupBorderRoot = nil
        frame._groupBorderHiddenNineSlice = nil
        frame._groupBorderHiddenPixels = nil
        if frame._groupBorderOverlay then frame._groupBorderOverlay:Hide() end
        if wasActive and frame.SetBorderHidden then frame:SetBorderHidden(false) end
    end
    restoreFrame(rootFrame)
    local FrameAnchor = Orbit.Engine.FrameAnchor
    local function walk(frame)
        restoreFrame(frame)
        local children = FrameAnchor.childrenOf[frame]
        if not children then return end
        for child in pairs(children) do walk(child) end
    end
    walk(rootFrame)
end

function Skin:RefreshAllGroupBorders()
    local FrameAnchor = Orbit.Engine.FrameAnchor
    if not FrameAnchor or not FrameAnchor.anchors then return end

    -- Phase 1: Collect all current merge roots (including non-anchored parents)
    local visited = {}
    local mergeRoots = {}
    for child in pairs(FrameAnchor.anchors) do
        local mergeRoot = child
        while true do
            local pa = FrameAnchor.anchors[mergeRoot]
            if not pa or pa.padding ~= 0 then break end
            local pO = FrameAnchor.GetFrameOptions(pa.parent)
            local cO = FrameAnchor.GetFrameOptions(mergeRoot)
            if not (FrameAnchor.ShouldMergeBorders(pO, pa.edge) and FrameAnchor.ShouldMergeBorders(cO, pa.edge)) then break end
            mergeRoot = pa.parent
        end
        if not visited[mergeRoot] then
            visited[mergeRoot] = true
            mergeRoots[#mergeRoots + 1] = mergeRoot
        end
        -- Clean stale overlays on parents that aren't merge roots
        local a = FrameAnchor.anchors[child]
        if a and a.parent and not visited[a.parent] and a.parent._groupBorderOverlay then
            a.parent._groupBorderOverlay:Hide()
            a.parent._groupBorderActive = nil
            a.parent._groupBorderRoot = nil
        end
    end

    -- Phase 2: Clear all existing group borders via ClearGroupBorder (proper cleanup)
    for _, root in ipairs(mergeRoots) do
        self:ClearGroupBorder(root)
    end

    -- Phase 3: Re-evaluate all merges from clean state
    for _, root in ipairs(mergeRoots) do
        self:UpdateGroupBorder(root)
    end
end

function Skin:DeferGroupBorderRefresh()
    Orbit.EventBus:Fire("BORDER_LAYOUT_CHANGED")
end

-- Debounced listener: coalesces all border layout events into a single refresh
Orbit.EventBus:On("BORDER_LAYOUT_CHANGED", function()
    Orbit.Async:Debounce("GroupBorderRefresh", function()
        Skin:RefreshAllGroupBorders()
    end, 0)
end)

-- Refresh group borders after plugins finish loading
Orbit.EventBus:On("PLAYER_ENTERING_WORLD", function()
    Orbit.Async:Debounce("GroupBorderRefresh", function()
        Skin:RefreshAllGroupBorders()
    end, 1)
end)
