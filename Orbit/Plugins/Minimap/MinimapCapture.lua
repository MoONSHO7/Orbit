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

local function OpenTrackingMenu(frame)
    local nativeButton = MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button
    if not (nativeButton and nativeButton.menuGenerator) then return end
    local menuMixin = frame.menuMixin or MenuVariants.GetDefaultContextMenuMixin()
    local description = MenuUtil.CreateRootMenuDescription(menuMixin)
    Menu.PopulateDescription(nativeButton.menuGenerator, nativeButton, description)
    Menu.GetManager():OpenMenu(frame, description, AnchorUtil.CreateAnchor("TOPLEFT", frame, "BOTTOMLEFT", 0, 0))
end

local function GetActiveDifficultyFrame(difficulty)
    if difficulty.ChallengeMode and difficulty.ChallengeMode:IsShown() then return difficulty.ChallengeMode end
    if difficulty.Guild and difficulty.Guild:IsShown() then return difficulty.Guild end
    return difficulty.Default
end

local function UpdateDifficultyBounds(difficulty)
    local activeFrame = GetActiveDifficultyFrame(difficulty)
    local width = 0
    local height = 0

    local bg = activeFrame and activeFrame.Background
    local border = activeFrame and activeFrame.Border
    local icon = difficulty.Icon
    if bg then
        width = math.max(width, bg:GetWidth() or 0)
        height = math.max(height, bg:GetHeight() or 0)
    end
    if border then
        width = math.max(width, border:GetWidth() or 0)
        height = math.max(height, border:GetHeight() or 0)
    end
    if icon then
        width = math.max(width, icon:GetWidth() or 0)
        height = math.max(height, icon:GetHeight() or 0)
    end

    difficulty.orbitOriginalWidth = width > 0 and width or 16
    difficulty.orbitOriginalHeight = height > 0 and height or 16
end

local function GetDifficultyIconTexture(difficulty)
    local activeFrame = GetActiveDifficultyFrame(difficulty)
    if not activeFrame then return nil end

    for _, region in ipairs({ activeFrame:GetRegions() }) do
        if region and region:GetObjectType() == "Texture" and region:IsShown() and region ~= activeFrame.Background and region ~= activeFrame.Border then
            local atlas = region.GetAtlas and region:GetAtlas()
            local texturePath = region:GetTexture()
            if atlas or texturePath then
                return region
            end
        end
    end

    return nil
end

local function SyncDifficultyPreviewIcon(difficulty)
    if not difficulty or not difficulty.Icon then return end

    local sourceTexture = GetDifficultyIconTexture(difficulty)
    if not sourceTexture then return end

    local atlas = sourceTexture.GetAtlas and sourceTexture:GetAtlas()
    if atlas then
        local info = C_Texture.GetAtlasInfo(atlas)
        if info and info.file then
            difficulty.Icon:SetTexture(info.file)
            difficulty.Icon:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
        else
            difficulty.Icon:SetAtlas(atlas, false)
        end
    else
        difficulty.Icon:SetTexture(sourceTexture:GetTexture())
        difficulty.Icon:SetTexCoord(sourceTexture:GetTexCoord())
    end

    local width = sourceTexture:GetWidth()
    local height = sourceTexture:GetHeight()
    difficulty.Icon:SetSize(width and width > 0 and width or 16, height and height > 0 and height or 16)
    difficulty.Icon:SetAlpha(0)
end

function Plugin:RunMinimapClickAction(action, frame)
    if action == "worldmap" then
        ToggleWorldMap()
    elseif action == "tracking" then
        OpenTrackingMenu(frame)
    elseif action == "calendar" then
        ToggleCalendar()
    elseif action == "time" then
        TimeManager_Toggle()
    elseif action == "addons" then
        self:ApplyAddonCompartment()
        self:ToggleCompartmentFlyout()
    end
end

-- Expose on plugin so other files can use them without re-declaring
Plugin.GetBlizzardMinimap = GetBlizzardMinimap
Plugin.GetBlizzardCluster = GetBlizzardCluster

-- [ BLIZZARD ART STRIPPING ]------------------------------------------------------------------------

local function StripBlizzardArt()
    local cluster = GetBlizzardCluster()
    if not cluster then return end

    -- Hide the entire cluster (takes BorderTop, ZoneTextButton, Tracking, IndicatorFrame, InstanceDifficulty)
    OrbitEngine.NativeFrame:Hide(cluster, { unregisterEvents = false, clearScripts = false })

    if MinimapBackdrop then MinimapBackdrop:SetAlpha(0) end
    if MinimapCompassTexture then MinimapCompassTexture:Hide() end

    -- Suppress Blizzard's edit mode selection on the minimap cluster
    if cluster.Selection then cluster.Selection:SetAlpha(0); cluster.Selection:EnableMouse(false) end

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
        local iconFrame = self.frame.DifficultyIcon
        if not iconFrame then
            iconFrame = CreateFrame("Frame", nil, overlay)
            iconFrame:SetPoint("CENTER", self.frame, "TOPLEFT", 20, -20)
            iconFrame.orbitOriginalWidth = 16
            iconFrame.orbitOriginalHeight = 16
            self.frame.DifficultyIcon = iconFrame
        end

        local textFrame = self.frame.DifficultyText
        if not textFrame then
            textFrame = CreateFrame("Frame", nil, overlay)
            textFrame:SetPoint("CENTER", self.frame, "TOPLEFT", 20, -20)
            textFrame.Text = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            textFrame.Text:SetPoint("CENTER")
            textFrame.Text:SetJustifyH("CENTER")
            textFrame.visual = textFrame.Text
            textFrame.orbitHandleMinWidth = 0
            textFrame.orbitHandleMinHeight = 0
            textFrame.orbitHideHandleHeader = true
            textFrame.orbitHandleHeaderMinWidth = 0
            self.frame.DifficultyText = textFrame
        end

        difficulty:SetParent(iconFrame)
        difficulty:ClearAllPoints()
        difficulty:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
        
        -- Hide the Blizzard guild-banner Background and Border art on every sub-frame;
        -- we only want the difficulty icon texture, not the decorative chrome.
        for _, sub in ipairs({ difficulty.Default, difficulty.Guild, difficulty.ChallengeMode }) do
            if sub then
                if sub.Background then sub.Background:SetAlpha(0) end
                if sub.Border then sub.Border:SetAlpha(0) end
            end
        end

        if not difficulty.Icon then
            difficulty.Icon = difficulty:CreateTexture(nil, "ARTWORK")
            difficulty.Icon:SetSize(16, 16)
            difficulty.Icon:SetPoint("CENTER")
            difficulty.Icon:SetAlpha(0)
        end
        iconFrame.Default = difficulty.Default
        iconFrame.Guild = difficulty.Guild
        iconFrame.ChallengeMode = difficulty.ChallengeMode
        iconFrame.Icon = difficulty.Icon
        SyncDifficultyPreviewIcon(difficulty)
        UpdateDifficultyBounds(difficulty)
        iconFrame.orbitOriginalWidth = difficulty.orbitOriginalWidth or 16
        iconFrame.orbitOriginalHeight = difficulty.orbitOriginalHeight or 16
        iconFrame:SetSize(iconFrame.orbitOriginalWidth, iconFrame.orbitOriginalHeight)
        if self.UpdateDifficultyVisuals then self:UpdateDifficultyVisuals() end

        if not difficulty._orbitPreviewHooksInstalled then
            local function RefreshDifficultyPreview()
                SyncDifficultyPreviewIcon(difficulty)
                UpdateDifficultyBounds(difficulty)
                iconFrame.orbitOriginalWidth = difficulty.orbitOriginalWidth or 16
                iconFrame.orbitOriginalHeight = difficulty.orbitOriginalHeight or 16
                iconFrame:SetSize(iconFrame.orbitOriginalWidth, iconFrame.orbitOriginalHeight)
                if self.UpdateDifficultyVisuals then self:UpdateDifficultyVisuals() end
            end

            for _, sub in ipairs({ difficulty.Default, difficulty.Guild, difficulty.ChallengeMode }) do
                if sub then
                    sub:HookScript("OnShow", RefreshDifficultyPreview)
                    sub:HookScript("OnHide", RefreshDifficultyPreview)
                end
            end

            difficulty:HookScript("OnShow", RefreshDifficultyPreview)
            difficulty._orbitPreviewHooksInstalled = true
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
        if mail.TryPlayMailNotification and HasNewMail and HasNewMail() then mail:TryPlayMailNotification() end
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
        
        -- The native texture has a baked-in border and scales tightly, becoming low-res.
        -- We hide it and use a borderless high-rez anvil atlas instead.
        if MiniMapCraftingOrderIcon then
            MiniMapCraftingOrderIcon:SetAlpha(0)
        end
        
        if not craftingOrder.Icon then
            craftingOrder.Icon = craftingOrder:CreateTexture(nil, "ARTWORK")
            craftingOrder.Icon:SetSize(20, 20)
            craftingOrder.Icon:SetPoint("CENTER")
            
            local info = C_Texture.GetAtlasInfo("UI-HUD-Minimap-CraftingOrder-Over-2x")
            if info and info.file then
                craftingOrder.Icon:SetTexture(info.file)
                craftingOrder.Icon:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
            else
                craftingOrder.Icon:SetAtlas("UI-HUD-Minimap-CraftingOrder-Over-2x", true)
            end
            
            -- Ignore native scaling so the atlas stays crisp
            craftingOrder.Icon:SetScale(1)
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
    if self.frame.DifficultyIcon then
        self.frame.DifficultyIcon:Hide()
        self.frame.DifficultyIcon:SetParent(nil)
        self.frame.DifficultyIcon = nil
    end
    if self.frame.DifficultyText then
        self.frame.DifficultyText:Hide()
        self.frame.DifficultyText:SetParent(nil)
        self.frame.DifficultyText = nil
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
    minimap:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    minimap:SetSize(self.frame:GetWidth(), self.frame:GetHeight())

    minimap:EnableMouse(true)
    if minimap.RegisterForClicks then
        minimap:RegisterForClicks("AnyUp")
    end
    minimap:SetArchBlobRingScalar(0)
    minimap:SetQuestBlobRingScalar(0)

    -- Apply the correct mask immediately at capture time.
    local shape = self:GetSetting(C.SYSTEM_ID, "Shape") or "square"
    if shape == "round" then minimap:SetMaskTexture(C.MASK_ROUND) else minimap:SetMaskTexture(C.MASK_SQUARE) end

    OrbitEngine.FrameGuard:Protect(minimap, self.frame)
    OrbitEngine.FrameGuard:UpdateProtection(minimap, self.frame, function() self:ApplySettings() end, { enforceShow = true })

    -- Hook SetPoint and SetSize to prevent Blizzard from repositioning or resizing
    -- the minimap away from our intended values.
    if not minimap._orbitSetPointHooked then
        hooksecurefunc(minimap, "SetPoint", function(f, ...)
            if f._orbitRestoringPoint then return end
            if f:GetParent() == self.frame then
                local point = ...
                local relFrame = select(2, ...)
                if point ~= "CENTER" or relFrame ~= self.frame then
                    f._orbitRestoringPoint = true
                    f:ClearAllPoints()
                    f:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
                    f:SetSize(self.frame:GetWidth(), self.frame:GetHeight())
                    f._orbitRestoringPoint = nil
                end
            end
        end)
        hooksecurefunc(minimap, "SetSize", function(f, w, h)
            if f._orbitRestoringPoint then return end
            if f:GetParent() == self.frame then
                local intended = self.frame:GetWidth()
                if intended and (math.abs(w - intended) > 0.5 or math.abs(h - intended) > 0.5) then
                    f._orbitRestoringPoint = true
                    f:SetSize(intended, intended)
                    f._orbitRestoringPoint = nil
                end
            end
        end)
        minimap._orbitSetPointHooked = true
    end

    -- Click actions are handled by OrbitMinimapClickCapture (created in OnLoad),
    -- a MEDIUM-strata Button with SetPropagateMouseClicks(true) that covers the whole
    -- minimap area and sits above most third-party overlays. No per-frame hook needed.

    -- FarmHud integration: register our container so FarmHud knows about it.
    C_Timer.After(0, function()
        if FarmHud and FarmHud.RegisterForeignAddOnObject then
            FarmHud:RegisterForeignAddOnObject(self.frame, "Orbit")
        end
    end)

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
