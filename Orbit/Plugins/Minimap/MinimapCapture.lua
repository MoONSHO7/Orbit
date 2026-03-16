-- [ MINIMAP CAPTURE ]-------------------------------------------------------------------------------
-- Blizzard minimap capture, art stripping, frame guard, and Blizzard component reparenting.

---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local C = Orbit.MinimapConstants

local SYSTEM_ID = C.SYSTEM_ID
local MISSIONS_BASE_SIZE = C.MISSIONS_BASE_SIZE

local Plugin = Orbit:GetPlugin(SYSTEM_ID)

-- [ BLIZZARD REFERENCES ]---------------------------------------------------------------------------

local function GetBlizzardMinimap() return Minimap end
local function GetBlizzardCluster() return MinimapCluster end

-- Expose on plugin so other files can use them without re-declaring
Plugin.GetBlizzardMinimap = GetBlizzardMinimap
Plugin.GetBlizzardCluster = GetBlizzardCluster

-- [ BLIZZARD ART STRIPPING ]------------------------------------------------------------------------

local function StripBlizzardArt()
    local cluster = GetBlizzardCluster()
    if not cluster then
        return
    end

    -- Hide the entire cluster (takes BorderTop, ZoneTextButton, Tracking, IndicatorFrame, InstanceDifficulty)
    OrbitEngine.NativeFrame:Hide(cluster, { unregisterEvents = false, clearScripts = false })

    if MinimapBackdrop then
        MinimapBackdrop:SetAlpha(0)
    end
    if MinimapCompassTexture then
        MinimapCompassTexture:Hide()
    end

    -- Suppress Blizzard's edit mode selection on the minimap cluster
    if cluster.Selection then
        cluster.Selection:SetAlpha(0)
        cluster.Selection:EnableMouse(false)
    end

    -- Hide Blizzard's native zoom buttons and hover area (we provide our own)
    local minimap = GetBlizzardMinimap()
    if minimap then
        if minimap.ZoomIn then
            minimap.ZoomIn:Hide()
            minimap.ZoomIn:SetScript("OnShow", minimap.ZoomIn.Hide)
        end
        if minimap.ZoomOut then
            minimap.ZoomOut:Hide()
            minimap.ZoomOut:SetScript("OnShow", minimap.ZoomOut.Hide)
        end
        if minimap.ZoomHitArea then
            minimap.ZoomHitArea:Hide()
            minimap.ZoomHitArea:EnableMouse(false)
        end
    end
end

-- [ BLIZZARD COMPONENT REPARENTING ]----------------------------------------------------------------

function Plugin:ReparentBlizzardComponents()
    local overlay = self.frame.Overlay

    -- Instance Difficulty indicator
    local difficulty = MinimapCluster and MinimapCluster.InstanceDifficulty
    if difficulty then
        self._origDifficultyParent = difficulty:GetParent()
        difficulty:SetParent(overlay)
        difficulty:ClearAllPoints()
        difficulty:SetPoint("CENTER", self.frame, "TOPLEFT", 20, -20)
        if not difficulty.Icon then
            difficulty.Icon = difficulty:CreateTexture(nil, "ARTWORK")
            difficulty.Icon:SetSize(16, 16)
            difficulty.Icon:SetPoint("CENTER")
            difficulty.Icon:SetAlpha(0)
        end
        self.frame.Difficulty = difficulty
    end

    -- Expansion Landing Page (Missions) button
    local missions = ExpansionLandingPageMinimapButton
    if missions then
        self._origMissionsParent = missions:GetParent()
        missions:SetParent(overlay)
        missions:ClearAllPoints()
        missions:SetPoint("CENTER", self.frame, "BOTTOMLEFT", 20, 20)
        missions:SetSize(MISSIONS_BASE_SIZE, MISSIONS_BASE_SIZE)
        -- Must be sized to MISSIONS_BASE_SIZE so CyclingAtlas creator's GetSourceSize
        -- returns the correct dimensions for the crossfade preview.
        if not missions.Icon then
            missions.Icon = missions:CreateTexture(nil, "ARTWORK")
            missions.Icon:SetPoint("CENTER")
            missions.Icon:SetAlpha(0)
        end
        missions.Icon:SetSize(MISSIONS_BASE_SIZE, MISSIONS_BASE_SIZE)
        self.frame.Missions = missions
    end

    -- New Mail indicator
    local mail = MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.MailFrame
    if mail then
        self._origMailParent = mail:GetParent()
        mail:SetParent(overlay)
        mail:ClearAllPoints()
        mail:SetPoint("CENTER", self.frame, "TOPRIGHT", -20, -20)
        mail:Show()
        -- Call via mixin so flipbook animations (NewMailAnim, MailReminderAnim) play correctly.
        -- Never manually set MailIcon visibility — that bypasses the animations.
        if mail.TryPlayMailNotification and HasNewMail and HasNewMail() then
            mail:TryPlayMailNotification()
        end
        if not mail.Icon then
            mail.Icon = mail:CreateTexture(nil, "ARTWORK")
            mail.Icon:SetSize(16, 16)
            mail.Icon:SetPoint("CENTER")
            mail.Icon:SetAlpha(0)
        end
        self.frame.Mail = mail
    end

    -- Crafting Order indicator
    local craftingOrder = MinimapCluster and MinimapCluster.IndicatorFrame and MinimapCluster.IndicatorFrame.CraftingOrderFrame
    if craftingOrder then
        self._origCraftingOrderParent = craftingOrder:GetParent()
        craftingOrder:SetParent(overlay)
        craftingOrder:ClearAllPoints()
        craftingOrder:SetPoint("CENTER", self.frame, "TOPRIGHT", -20, -38)
        if not craftingOrder.Icon then
            craftingOrder.Icon = craftingOrder:CreateTexture(nil, "ARTWORK")
            craftingOrder.Icon:SetSize(16, 16)
            craftingOrder.Icon:SetPoint("CENTER")
            craftingOrder.Icon:SetAlpha(0)
        end
        self.frame.CraftingOrder = craftingOrder
    end
end

function Plugin:RestoreBlizzardComponents()
    if self.frame.Difficulty and self._origDifficultyParent then
        self.frame.Difficulty:SetParent(self._origDifficultyParent)
        self.frame.Difficulty:ClearAllPoints()
        self.frame.Difficulty = nil
    end

    if self.frame.Missions and self._origMissionsParent then
        self.frame.Missions:SetScript("OnShow", nil)
        self.frame.Missions:SetParent(self._origMissionsParent)
        self.frame.Missions:ClearAllPoints()
        self.frame.Missions:SetSize(53, 53) -- restore original size
        self.frame.Missions = nil
    end

    if self.frame.Mail and self._origMailParent then
        self.frame.Mail:SetScript("OnShow", nil)
        self.frame.Mail:SetParent(self._origMailParent)
        self.frame.Mail:ClearAllPoints()
        self.frame.Mail = nil
    end

    if self.frame.CraftingOrder and self._origCraftingOrderParent then
        self.frame.CraftingOrder:SetScript("OnShow", nil)
        self.frame.CraftingOrder:SetParent(self._origCraftingOrderParent)
        self.frame.CraftingOrder:ClearAllPoints()
        self.frame.CraftingOrder = nil
    end
end

-- [ CAPTURE ]---------------------------------------------------------------------------------------

function Plugin:CaptureBlizzardMinimap()
    local minimap = GetBlizzardMinimap()

    StripBlizzardArt()

    minimap:SetParent(self.frame)
    minimap:ClearAllPoints()
    minimap:SetAllPoints(self.frame)

    minimap:EnableMouse(true)
    minimap:SetArchBlobRingScalar(0)
    minimap:SetQuestBlobRingScalar(0)

    -- Apply the correct mask immediately at capture time.
    -- ApplyShape (called from ApplySettings) will update it if the setting changes.
    local shape = self:GetSetting(C.SYSTEM_ID, "Shape") or "square"
    if shape == "round" then
        minimap:SetMaskTexture(C.MASK_ROUND)
    else
        minimap:SetMaskTexture(C.MASK_SQUARE)
    end

    OrbitEngine.FrameGuard:Protect(minimap, self.frame)
    OrbitEngine.FrameGuard:UpdateProtection(minimap, self.frame, function() self:ApplySettings() end, { enforceShow = true })

    -- Hook SetPoint to prevent Blizzard from repositioning.
    -- No pcall: if ClearAllPoints/SetAllPoints throws here, that is a real bug.
    if not minimap._orbitSetPointHooked then
        hooksecurefunc(minimap, "SetPoint", function(f, ...)
            if f._orbitRestoringPoint then
                return
            end
            if f:GetParent() == self.frame then
                local point = ...
                if point ~= "TOPLEFT" or select(2, ...) ~= self.frame then
                    f._orbitRestoringPoint = true
                    f:ClearAllPoints()
                    f:SetAllPoints(self.frame)
                    f._orbitRestoringPoint = nil
                end
            end
        end)
        minimap._orbitSetPointHooked = true
    end

    -- Right-click on the minimap opens the tracking menu
    if not minimap._orbitRightClickHooked then
        minimap:SetScript("OnMouseUp", function(f, button)
            if button == "RightButton" then
                local nativeButton = MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button
                if nativeButton and nativeButton.menuGenerator then
                    local menuMixin = (f.menuMixin or MenuVariants.GetDefaultContextMenuMixin())
                    local description = MenuUtil.CreateRootMenuDescription(menuMixin)
                    Menu.PopulateDescription(nativeButton.menuGenerator, nativeButton, description)
                    local anchor = AnchorUtil.CreateAnchor("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
                    Menu.GetManager():OpenMenu(f, description, anchor)
                end
            elseif button == "MiddleButton" then
                local action = self:GetSetting(C.SYSTEM_ID, "MiddleClickAction") or "none"
                if action == "worldmap" then
                    ToggleWorldMap()
                elseif action == "tracking" then
                    local nativeButton = MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button
                    if nativeButton and nativeButton.menuGenerator then
                        local menuMixin = (f.menuMixin or MenuVariants.GetDefaultContextMenuMixin())
                        local description = MenuUtil.CreateRootMenuDescription(menuMixin)
                        Menu.PopulateDescription(nativeButton.menuGenerator, nativeButton, description)
                        local anchor = AnchorUtil.CreateAnchor("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
                        Menu.GetManager():OpenMenu(f, description, anchor)
                    end
                end
            end
        end)
        minimap._orbitRightClickHooked = true
    end

    -- Update zoom button state after scroll-wheel zoom
    if not minimap._orbitScrollHooked then
        minimap:HookScript("OnMouseWheel", function()
            self:UpdateZoomState()
            self:StartAutoZoomOut()
        end)
        minimap._orbitScrollHooked = true
    end

    self._captured = true
end
