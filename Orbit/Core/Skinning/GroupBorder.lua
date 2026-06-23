-- [ ORBIT GROUP BORDER ]-----------------------------------------------------------------------------
local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local Engine = Orbit.Engine
local Constants = Orbit.Constants


-- [ GROUP BORDER ] ----------------------------------------------------------------------------------
-- Snapshot lets Phase 4 reach ex-members whose anchors left the chain — Phase 1's walk only sees still-anchored frames.
Skin._groupMembers = setmetatable({}, { __mode = "k" })

-- Group-manages surfaces unless: per-icon container (Icon Padding > 0; child icons own their masks via Icons:ApplyCustom) or aura grid (UnitAuraGridMixin masks per-icon on UNIT_AURA).
local function GroupManagesMask(frame)
    if frame._auraGridFrame then return false end
    -- A live merge member always manages its own surfaces — covers born-merged icon containers that never set _activeBorderMode.
    return (not frame._isIconContainer) or frame._activeBorderMode ~= nil or frame._groupBorderActive
end

function Skin:UpdateGroupBorder(rootFrame)
    if not rootFrame then return end
    if rootFrame._mergeSuspended then return self:ClearGroupBorder(rootFrame) end

    local FrameAnchor = Orbit.Engine.FrameAnchor
    local GetFrameOptions = FrameAnchor.GetFrameOptions

    local allFrames = { rootFrame }
    local hasMerge = false

    local ShouldMergeBorders = FrameAnchor.ShouldMergeBorders

    local function Walk(frame)
        local children = FrameAnchor.childrenOf[frame]
        if not children then return end
        for child in pairs(children) do
            local a = FrameAnchor.anchors[child]
            if a and a.padding == 0 then
                local pOpts = GetFrameOptions(frame)
                local cOpts = GetFrameOptions(child)
                -- GetAlpha is secret when alpha is curve-driven; `> 0` would throw. Treat secret as visible — _oocFadeHidden catches the intentional-hide case via the other OR branch.
                local childAlpha = child:GetAlpha()
                local alphaVisible = issecretvalue(childAlpha) or (childAlpha > 0)
                local merged = ShouldMergeBorders(pOpts, a.edge) and ShouldMergeBorders(cOpts, a.edge)
                    and child:IsShown() and (alphaVisible or child._oocFadeHidden)
                    and not child._mergeSuspended
                if merged then
                    hasMerge = true
                    allFrames[#allFrames + 1] = child
                    Walk(child)
                end
            end
        end
    end
    Walk(rootFrame)

    if not hasMerge then
        self:ClearGroupBorder(rootFrame)
        return
    end

    -- Any icon container in the chain makes the whole group icon-styled (flag set by ApplyIconGroupBorder).
    local isIconStyle = false
    for _, frame in ipairs(allFrames) do
        if frame._isIconContainer then isIconStyle = true; break end
    end

    -- Determine border mode: a LibSharedMedia edge-file border, or the flat pixel border.
    local styleEntry
    if isIconStyle then styleEntry = self:GetActiveIconBorderStyle()
    else styleEntry = self:GetActiveBorderStyle() end
    local isPixelMode = (styleEntry == nil)

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

    -- Icon containers boost above the highest child button; unit frames sit at root+Border so canvas text/icons stay above the border.
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



    -- Bounding box from anchor edges (deterministic, no screen coords) — each frame's position relative to rootFrame TOPLEFT.
    local positions = {}
    positions[rootFrame] = { x = 0, y = 0 }
    local function ComputePositions(frame)
        local pos = positions[frame]
        local children = FrameAnchor.childrenOf[frame]
        if not children then return end
        for child in pairs(children) do
            if not positions[child] then
                local a = FrameAnchor.anchors[child]
                if a and a.padding == 0 then
                    local cx, cy = pos.x, pos.y
                    local pw, ph = frame:GetWidth(), frame:GetHeight()
                    local cw, ch = child:GetWidth(), child:GetHeight()
                    -- Offset the CROSS axis by anchor.align so the box matches ApplyAnchorPosition, else a narrower aligned row mis-rounds.
                    if a.edge == "BOTTOM" or a.edge == "TOP" then
                        cy = (a.edge == "BOTTOM") and (pos.y + ph) or (pos.y - ch)
                        if a.align == "RIGHT" then cx = pos.x + (pw - cw)
                        elseif a.align ~= "LEFT" then cx = pos.x + (pw - cw) / 2 end
                    elseif a.edge == "RIGHT" or a.edge == "LEFT" then
                        cx = (a.edge == "RIGHT") and (pos.x + pw) or (pos.x - cw)
                        if a.align == "BOTTOM" then cy = pos.y + (ph - ch)
                        elseif a.align ~= "TOP" then cy = pos.y + (ph - ch) / 2 end
                    end
                    positions[child] = { x = cx, y = cy }
                    ComputePositions(child)
                end
            end
        end
    end
    ComputePositions(rootFrame)

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

    if isPixelMode then
        if overlay._sliceTexture then overlay._sliceTexture:Hide() end
        self:_ClearGroupRoundedMask(rootFrame, allFrames)
        rootFrame._groupRoundedMask = nil          -- drop the cached rounded mask so the aura-grid cross-merge read unmasks under a flat group
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
        local c = self:ResolveBorderColor(isIconStyle)
        overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
    elseif styleEntry.rounded then
        -- One slice mask over the merged box clips every member's surfaces, so only the group's four outer corners round.
        overlay:ClearAllPoints()
        if canNativeAnchor then
            overlay:SetPoint("TOPLEFT", tlFrame, "TOPLEFT", 0, 0)
            overlay:SetPoint("BOTTOMRIGHT", brFrame, "BOTTOMRIGHT", 0, 0)
        else
            overlay:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", Engine.Pixel:Snap(-offsetX, rootScale), Engine.Pixel:Snap(offsetY, rootScale))
            overlay:SetSize(Engine.Pixel:Snap(totalW, rootScale), Engine.Pixel:Snap(totalH, rootScale))
        end
        self:_RenderSliceTexture(overlay, styleEntry, self:ResolveBorderTint(isIconStyle))
        self:_ClearGroupRoundedMask(rootFrame, allFrames)
        local mask = self:EnsureSliceMask(rootFrame, "_groupRoundedMask", styleEntry, function(m) m:SetAllPoints(overlay) end)
        for _, frame in ipairs(allFrames) do
            if GroupManagesMask(frame) then
                for _, tex in ipairs(frame._maskedSurfaces or {}) do
                    self:_SetSurfaceMask(tex, mask)
                end
            end
        end
    else
        -- LibSharedMedia edge-file border drawn on the merged bounding box.
        if overlay._sliceTexture then overlay._sliceTexture:Hide() end
        self:_ClearGroupRoundedMask(rootFrame, allFrames)
        rootFrame._groupRoundedMask = nil          -- drop the cached rounded mask so the aura-grid cross-merge read unmasks under an edge-file group
        local edgeSize, borderOffset
        if isIconStyle then
            local iconStyle = self:BuildIconStyle(styleEntry)
            edgeSize = iconStyle.edgeSize
            borderOffset = iconStyle.borderOffset
        else
            edgeSize = (gs and gs.BorderEdgeSize) or Constants.BorderStyle.EdgeSize
            borderOffset = (gs and gs.BorderOffset) or 0
        end
        local outset, adjEdge = self:ComputeBorderOutset(rootFrame, edgeSize, borderOffset, rootScale)

        overlay:ClearAllPoints()

        if canNativeAnchor then
            overlay:SetPoint("TOPLEFT", tlFrame, "TOPLEFT", -outset, outset)
            overlay:SetPoint("BOTTOMRIGHT", brFrame, "BOTTOMRIGHT", outset, -outset)
        else
            overlay:SetPoint("TOPLEFT", rootFrame, "TOPLEFT", Engine.Pixel:Snap(-outset - offsetX, rootScale), Engine.Pixel:Snap(outset + offsetY, rootScale))
            overlay:SetSize(Engine.Pixel:Snap(totalW + 2 * outset, rootScale), Engine.Pixel:Snap(totalH + 2 * outset, rootScale))
        end

        overlay:SetBackdrop({ edgeFile = styleEntry.edgeFile, edgeSize = adjEdge })
        -- Tint the grayscale edge-file by Border Color, or natural art when "none", matching ApplyNineSliceBorder.
        local c = self:ResolveBorderTint(isIconStyle)
        if c then
            overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
        else
            overlay:SetBackdropBorderColor(1, 1, 1, 1)
        end
    end
    overlay:Show()
    -- Re-hide if any merged frame is OOC-faded (prevents refresh from undoing OOCFadeMixin's hide)
    for _, frame in ipairs(allFrames) do
        if frame._oocFadeHidden then overlay:Hide(); break end
    end

    -- Visibility hooks so merges update immediately on show/hide (e.g. target frame via RegisterUnitWatch); persistent and debounced.
    for _, frame in ipairs(allFrames) do
        if not frame._mergeVisHooked then
            frame:HookScript("OnShow", function() Skin:DeferGroupBorderRefresh() end)
            frame:HookScript("OnHide", function() Skin:DeferGroupBorderRefresh() end)
            frame._mergeVisHooked = true
        end
    end
end

-- Sweep whatever Orbit mask sits on each surface (not just rootFrame's), so a hopped-group or pixel-fallback frame leaves no residue from an ex-rounded profile.
function Skin:_ClearGroupRoundedMask(_, frames)
    if not frames then return end
    for _, frame in ipairs(frames) do
        if GroupManagesMask(frame) then
            for _, tex in ipairs(frame._maskedSurfaces or {}) do
                self:_SetSurfaceMask(tex, nil)
            end
        end
    end
end

function Skin:ClearGroupBorder(rootFrame)
    if not rootFrame then return end
    local walked = {}
    local function RestoreFrame(frame)
        walked[#walked + 1] = frame
        local wasActive = frame._groupBorderActive
        frame._groupBorderActive = nil
        frame._groupBorderRoot = nil
        frame._groupBorderHiddenNineSlice = nil
        frame._groupBorderHiddenPixels = nil
        if frame._groupBorderOverlay then frame._groupBorderOverlay:Hide() end
        if wasActive and frame.SetBorderHidden then frame:SetBorderHidden(false) end
    end
    RestoreFrame(rootFrame)
    local FrameAnchor = Orbit.Engine.FrameAnchor
    local function Walk(frame)
        local children = FrameAnchor.childrenOf[frame]
        if not children then return end
        for child in pairs(children) do
            RestoreFrame(child)
            Walk(child)
        end
    end
    Walk(rootFrame)
    self:_ClearGroupRoundedMask(rootFrame, walked)
    for _, frame in ipairs(walked) do
        if GroupManagesMask(frame) then
            if frame._isIconContainer then
                self:ApplyRoundedMaskToSurfaces(frame, self:GetActiveIconBorderStyle())
            else
                self:ApplyRoundedMaskToSurfaces(frame, self:GetActiveBorderStyle())
            end
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
    if GroupManagesMask(frame) then
        -- Sweep any leftover GROUP mask first — owner-guarded ClearRoundedMaskFromSurfaces can't remove the _groupRoundedMask an ex-member still carries.
        for _, tex in ipairs(frame._maskedSurfaces or {}) do
            self:_SetSurfaceMask(tex, nil)
        end
        if frame._isIconContainer then
            self:ApplyRoundedMaskToSurfaces(frame, self:GetActiveIconBorderStyle())
        else
            self:ApplyRoundedMaskToSurfaces(frame, self:GetActiveBorderStyle())
        end
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
-- Synchronous teardown: group overlay and mask are anchored to member frames, so a deferred teardown lets both chase the dragged frame until the next refresh lands.
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
    Orbit.EventBus:Fire("ORBIT_BORDER_LAYOUT_CHANGED")
end

-- Debounced listener: coalesces all border layout events into a single refresh
Orbit.EventBus:On("ORBIT_BORDER_LAYOUT_CHANGED", function()
    Orbit.Async:Debounce("GroupBorderRefresh", function()
        Skin:RefreshAllGroupBorders()
    end, 0)
end)

-- Rebuild merged group borders on style/size change — per-frame re-skin updates each member's overlay but never touches the group overlay.
Orbit.EventBus:On("ORBIT_BORDER_SIZE_CHANGED", function()
    Skin:DeferGroupBorderRefresh()
end)

-- Refresh group borders after plugins finish loading
Orbit.EventBus:On("ORBIT_PLAYER_ENTERING_WORLD", function()
    Orbit.Async:Debounce("GroupBorderRefresh", function()
        Skin:RefreshAllGroupBorders()
    end, 1)
end)
