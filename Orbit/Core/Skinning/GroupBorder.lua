-- [ ORBIT GROUP BORDER ]-----------------------------------------------------------------------------
-- Extracted from Skin.lua — group border merging for anchored frames.
-- Methods remain on Orbit.Skin for call-site compatibility.
local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local Engine = Orbit.Engine
local Constants = Orbit.Constants


-- [ GROUP BORDER ] ----------------------------------------------------------------------------------
-- Snapshot lets RefreshAllGroupBorders Phase 4 reach ex-members whose anchors moved out of the
-- merge chain — Phase 1's walk only sees frames still anchored, so without this they'd retain
-- _groupBorderActive=true and a stale group mask attached to their surfaces.
Skin._groupMembers = setmetatable({}, { __mode = "k" })

function Skin:UpdateGroupBorder(rootFrame)
    if not rootFrame then return end
    if rootFrame._mergeSuspended then return self:ClearGroupBorder(rootFrame) end

    local FrameAnchor = Orbit.Engine.FrameAnchor
    local GetFrameOptions = FrameAnchor.GetFrameOptions

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
                -- GetAlpha may return a secret when alpha is driven by a range curve;
                -- `> 0` would throw. Treat secret alpha as "visible" — OOC-hidden
                -- state is tracked explicitly via _oocFadeHidden, so the other branch
                -- of the OR still catches the intentional-hide case.
                local childAlpha = child:GetAlpha()
                local alphaVisible = issecretvalue(childAlpha) or (childAlpha > 0)
                local merged = ShouldMergeBorders(pOpts, a.edge) and ShouldMergeBorders(cOpts, a.edge)
                    and child:IsShown() and (alphaVisible or child._oocFadeHidden)
                    and not child._mergeSuspended
                if merged then
                    hasMerge = true
                    allFrames[#allFrames + 1] = child
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
        Skin._groupMembers[frame] = rootFrame
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
    if isIconStyle then styleEntry = self:GetActiveIconBorderStyle()
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
        overlayLevel = rootFrame:GetFrameLevel() + Constants.Levels.Border
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

    local rootScale = rootFrame:GetEffectiveScale()
    if not rootScale or rootScale < 0.01 then rootScale = 1 end
    local matchTolerance = Engine.Pixel:GetScale() / rootScale * 0.5

    -- Identify true extremum frames for native layout anchoring (avoids SetSize desync during anims)
    local tlFrame, brFrame
    for i = 1, #allFrames do
        local frame = allFrames[i]
        local pos = positions[frame]
        if pos then
            local r = pos.x + frame:GetWidth()
            local b = pos.y + frame:GetHeight()
            if math.abs(pos.x - minX) < matchTolerance and math.abs(pos.y - minY) < matchTolerance then tlFrame = frame end
            if math.abs(r - maxX) < matchTolerance and math.abs(b - maxY) < matchTolerance then brFrame = frame end
        end
    end
    
    local canNativeAnchor = (tlFrame ~= nil and brFrame ~= nil)

    local totalW = maxX - minX
    local totalH = maxY - minY
    local offsetX = -minX
    local offsetY = -minY



    local hasModernSlice = (not isPixelMode) and styleEntry and styleEntry.sliceMargin

    if isPixelMode then
        if overlay._sliceTexture then overlay._sliceTexture:Hide() end
        self:_ClearGroupRoundedMask(rootFrame, allFrames)
        local borderSize = isIconStyle and (gs and gs.IconBorderSize or Constants.Settings.BorderSize.Default) or (gs and gs.BorderSize or Constants.Settings.BorderSize.Default)
        if borderSize <= 0 then
            overlay:Hide()
            return
        end
        local pixelSize = Engine.Pixel:Multiple(borderSize, rootScale)
        overlay:ClearAllPoints()

        if canNativeAnchor then
            overlay:SetPoint("TOPLEFT", tlFrame, "TOPLEFT", 0, 0)
            overlay:SetPoint("BOTTOMRIGHT", brFrame, "BOTTOMRIGHT", 0, 0)
        else
            overlay:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", Engine.Pixel:Snap(-offsetX, rootScale), Engine.Pixel:Snap(offsetY, rootScale))
            overlay:SetSize(Engine.Pixel:Snap(totalW, rootScale), Engine.Pixel:Snap(totalH, rootScale))
        end

        overlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = pixelSize })
        local colorKey = isIconStyle and "IconBorderColor" or "BorderColor"
        local raw = gs and gs[colorKey]
        local c
        if raw and raw.type == "class" then
            c = Engine.ClassColor:GetCurrentClassColor()
            c.a = raw.a or 1
        else
            c = (Engine.ColorCurve and Engine.ColorCurve:GetFirstColorFromCurve(raw) or raw) or { r = 0, g = 0, b = 0, a = 1 }
        end
        overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    elseif hasModernSlice then
        overlay:ClearAllPoints()
        if canNativeAnchor then
            overlay:SetPoint("TOPLEFT", tlFrame, "TOPLEFT", 0, 0)
            overlay:SetPoint("BOTTOMRIGHT", brFrame, "BOTTOMRIGHT", 0, 0)
        else
            overlay:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", Engine.Pixel:Snap(-offsetX, rootScale), Engine.Pixel:Snap(offsetY, rootScale))
            overlay:SetSize(Engine.Pixel:Snap(totalW, rootScale), Engine.Pixel:Snap(totalH, rootScale))
        end

        local c = self:ResolveBorderColor(isIconStyle)
        self:_RenderSliceTexture(overlay, styleEntry, c)
        self:_ApplyGroupRoundedMask(rootFrame, allFrames, isIconStyle, canNativeAnchor, tlFrame, brFrame, offsetX, offsetY, totalW, totalH, rootScale)
    else
        if overlay._sliceTexture then overlay._sliceTexture:Hide() end
        self:_ClearGroupRoundedMask(rootFrame, allFrames)
        local edgeSize, borderOffset
        if isIconStyle then
            local iconStyle = self:BuildIconStyle(styleEntry)
            edgeSize = iconStyle.edgeSize
            borderOffset = iconStyle.borderOffset
        else
            edgeSize = (gs and gs.BorderEdgeSize) or Constants.BorderStyle.EdgeSize
            borderOffset = (gs and gs.BorderOffset) or 0
        end
        local ownScale = rootFrame:GetScale() or 1
        if ownScale < 0.01 then ownScale = 1 end
        local adjEdge = edgeSize / ownScale
        local adjOffset = borderOffset / ownScale
        local outset = Engine.Pixel:Snap((adjEdge / 2) + adjOffset, rootScale)

        overlay:ClearAllPoints()

        if canNativeAnchor then
            overlay:SetPoint("TOPLEFT", tlFrame, "TOPLEFT", -outset, outset)
            overlay:SetPoint("BOTTOMRIGHT", brFrame, "BOTTOMRIGHT", outset, -outset)
        else
            overlay:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", Engine.Pixel:Snap(-outset - offsetX, rootScale), Engine.Pixel:Snap(outset + offsetY, rootScale))
            overlay:SetSize(Engine.Pixel:Snap(totalW + 2 * outset, rootScale), Engine.Pixel:Snap(totalH + 2 * outset, rootScale))
        end

        overlay:SetBackdrop({ edgeFile = styleEntry.edgeFile, edgeSize = adjEdge })
        overlay:SetBackdropBorderColor(1, 1, 1, 1)
    end
    overlay:Show()
    -- Re-hide if any merged frame is OOC-faded (prevents refresh from undoing OOCFadeMixin's hide)
    for _, frame in ipairs(allFrames) do
        if frame._oocFadeHidden then overlay:Hide(); break end
    end

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

function Skin:_ApplyGroupRoundedMask(rootFrame, allFrames, isIconStyle, canNativeAnchor, tlFrame, brFrame, offsetX, offsetY, totalW, totalH, rootScale)
    if not rootFrame._groupRoundedMask then
        rootFrame._groupRoundedMask = rootFrame:CreateMaskTexture(nil, "BACKGROUND")
        if Engine.Pixel then Engine.Pixel:Enforce(rootFrame._groupRoundedMask) end
    end
    local mask = rootFrame._groupRoundedMask
    local tier = self:GetRoundedTier(isIconStyle)
    mask:SetTexture(tier.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetTextureSliceMargins(tier.margin, tier.margin, tier.margin, tier.margin)
    mask:ClearAllPoints()
    if canNativeAnchor then
        mask:SetPoint("TOPLEFT", tlFrame, "TOPLEFT", 0, 0)
        mask:SetPoint("BOTTOMRIGHT", brFrame, "BOTTOMRIGHT", 0, 0)
    else
        mask:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", Engine.Pixel:Snap(-offsetX, rootScale), Engine.Pixel:Snap(offsetY, rootScale))
        mask:SetSize(Engine.Pixel:Snap(totalW, rootScale), Engine.Pixel:Snap(totalH, rootScale))
    end
    for _, frame in ipairs(allFrames) do
        for _, tex in ipairs(frame._maskedSurfaces or {}) do
            self:_SetSurfaceMask(tex, mask)
        end
    end
end

-- Clears whatever Orbit mask sits on each surface — per-frame or any group's — not just
-- rootFrame's, so a frame that hopped groups or fell back to pixel/legacy leaves no residue.
function Skin:_ClearGroupRoundedMask(rootFrame, frames)
    if not frames then return end
    for _, frame in ipairs(frames) do
        for _, tex in ipairs(frame._maskedSurfaces or {}) do
            self:_SetSurfaceMask(tex, nil)
        end
    end
    -- Detach the group mask from the member frames it was SetPoint-anchored to. A MaskTexture
    -- left cross-anchored onto a frame blocks that frame's StartMoving from re-latching a
    -- follow point — it must be fully unanchored when the group is torn down.
    if rootFrame and rootFrame._groupRoundedMask then
        rootFrame._groupRoundedMask:ClearAllPoints()
    end
end

function Skin:ClearGroupBorder(rootFrame)
    if not rootFrame then return end
    local walked = {}
    local function restoreFrame(frame)
        walked[#walked + 1] = frame
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
        local children = FrameAnchor.childrenOf[frame]
        if not children then return end
        for child in pairs(children) do
            restoreFrame(child)
            walk(child)
        end
    end
    walk(rootFrame)
    self:_ClearGroupRoundedMask(rootFrame, walked)
    local activeStyle = self:GetActiveBorderStyle()
    local activeIconStyle = self:GetActiveIconBorderStyle()
    for _, frame in ipairs(walked) do
        local style = frame._isIconContainer and activeIconStyle or activeStyle
        if style and style.sliceMargin then
            self:ApplyRoundedMaskToSurfaces(frame, frame._isIconContainer)
        end
    end
end

function Skin:_RestoreExMergeMember(frame)
    if not frame then return end
    frame._groupBorderActive = nil
    frame._groupBorderRoot = nil
    frame._groupBorderHiddenNineSlice = nil
    frame._groupBorderHiddenPixels = nil
    if frame._groupBorderOverlay then frame._groupBorderOverlay:Hide() end
    if frame.SetBorderHidden then frame:SetBorderHidden(false) end
    local activeStyle = frame._isIconContainer and self:GetActiveIconBorderStyle() or self:GetActiveBorderStyle()
    if activeStyle and activeStyle.sliceMargin then
        self:ApplyRoundedMaskToSurfaces(frame, frame._isIconContainer)
    else
        self:ClearRoundedMaskFromSurfaces(frame)
    end
end

function Skin:RefreshAllGroupBorders()
    local FrameAnchor = Orbit.Engine.FrameAnchor
    if not FrameAnchor or not FrameAnchor.anchors then return end

    local previousMembers = {}
    for frame, root in pairs(self._groupMembers) do previousMembers[frame] = root end
    wipe(self._groupMembers)

    -- Phase 1: Collect all current merge roots (including non-anchored parents)
    local visited = {}
    local mergeRoots = {}
    for child in pairs(FrameAnchor.anchors) do
        local mergeRoot = child
        while true do
            local pa = FrameAnchor.anchors[mergeRoot]
            if not pa or pa.padding ~= 0 then break end
            if mergeRoot._mergeSuspended or pa.parent._mergeSuspended then break end
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

    -- Phase 4: Restore ex-members (frames that were merged last refresh but aren't anymore).
    for frame in pairs(previousMembers) do
        if not self._groupMembers[frame] then
            self:_RestoreExMergeMember(frame)
        end
    end
end

-- [ MERGE SUSPENSION ] ------------------------------------------------------------------------------
-- Drag disables border merging for the dragged frame's whole group: every member shows its own
-- border for the drag, one rebuild runs on drop. The teardown must be synchronous — the group
-- overlay and group mask are anchored to member frames, so a deferred teardown lets both chase
-- the dragged frame until the refresh lands. ClearGroupBorder restores each member's own
-- self-anchored border + mask before the drag moves anything.
function Skin:SuspendMergeGroup(frame)
    if not frame then return end
    local members = {}
    local root = self._groupMembers[frame]
    if root then
        for member, r in pairs(self._groupMembers) do
            if r == root then members[#members + 1] = member end
        end
    else
        members[1] = frame
    end
    for _, m in ipairs(members) do m._mergeSuspended = true end
    if root then self:ClearGroupBorder(root) end
    return members
end

function Skin:ResumeMergeGroup(members)
    if not members then return end
    for _, m in ipairs(members) do m._mergeSuspended = nil end
    self:DeferGroupBorderRefresh()
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
