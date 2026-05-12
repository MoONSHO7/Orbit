---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local C = Orbit.ObjectivesConstants
local SYSTEM_ID = C.SYSTEM_ID

-- [ PLUGIN REGISTRATION ]----------------------------------------------------------------------------
local Plugin = Orbit:RegisterPlugin("Objectives", SYSTEM_ID, {
    defaults = {
        Scale = C.DEFAULT_SCALE,
        Width = C.DEFAULT_WIDTH,
        Height = C.DEFAULT_HEIGHT,
        SkinProgressBars = true,
        ClassColorHeaders = false,
        ShowBorder = true,
        BackgroundOpacity = C.BG_OPACITY_DEFAULT,
        HeaderSeparators = true,
        AutoCollapseCombat = false,
    },
})

-- Apply NativeBarMixin for mouseOver helpers
Mixin(Plugin, Orbit.NativeBarMixin)

-- [ LIFECYCLE ]--------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create container frame that will own the Blizzard ObjectiveTrackerFrame
    self.frame = CreateFrame("Frame", "OrbitObjectivesContainer", UIParent)
    self.frame:SetSize(C.DEFAULT_WIDTH, C.DEFAULT_HEIGHT)
    self.frame:SetClampedToScreen(true)
    self.frame:SetClipsChildren(true)
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Objectives"

    self.frame.anchorOptions = {
        horizontal = true,
        vertical = true,
    }

    self.scrollChild = CreateFrame("Frame", "OrbitObjectivesScrollChild", self.frame)
    self.scrollChild:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    self.scrollChild:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
    self.scrollChild:SetSize(C.DEFAULT_WIDTH, C.DEFAULT_HEIGHT)

    -- Default position: right side, below minimap (matches Blizzard's native position)
    self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -80, -260)

    -- Register to Orbit edit mode + position persistence
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()
    self:InstallCombatCollapseHooks()

    -- Hook ObjectiveTracker addon loading
    local function HookTracker()
        self:CaptureTracker()
        self:InstallSkinHooks()
        self:InstallCollapseHooks()
        self:ApplySettings()
    end

    if C_AddOns.IsAddOnLoaded("Blizzard_ObjectiveTracker") then
        HookTracker()
    else
        self._addonLoader = CreateFrame("Frame")
        self._addonLoader:RegisterEvent("ADDON_LOADED")
        self._addonLoader:SetScript("OnEvent", function(f, event, addonName)
            if addonName == "Blizzard_ObjectiveTracker" then
                HookTracker()
                f:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

-- [ CAPTURE ]----------------------------------------------------------------------------------------
function Plugin:CaptureTracker()
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end

    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:CaptureTracker() end)
        return
    end

    if tracker:GetParent() ~= self.scrollChild then
        local parent = tracker:GetParent()
        -- Only capture from native Blizzard parents
        if parent ~= UIParent and parent ~= (UIParentRightManagedFrameContainer or UIParent) then
            return
        end
        tracker:SetParent(self.scrollChild)
    end

    tracker:ClearAllPoints()
    local pad = self:GetContentInset()
    tracker:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", pad, -pad)
    tracker:SetPoint("TOPRIGHT", self.scrollChild, "TOPRIGHT", -pad, -pad)

    -- Suppress Blizzard's native Edit Mode selection (prevents double-highlight)
    if tracker.Selection then
        tracker.Selection:SetAlpha(0)
        tracker.Selection:EnableMouse(false)
    end

    -- Protect against re-parenting by Blizzard or other addons
    OrbitEngine.FrameGuard:Protect(tracker, self.scrollChild)
    OrbitEngine.FrameGuard:UpdateProtection(tracker, self.scrollChild, function()
        self:ApplySettings()
    end, { enforceShow = false })

    -- Override the tracker's height system so modules use our container height
    if not self._heightOverridden then
        self._currentScroll = 0
        
        -- Let Blizzard render as many blocks as it wants (for scrolling)
        tracker.GetAvailableHeight = function()
            return 50000
        end

        local function handleScroll(_, delta)
            if not ObjectiveTrackerFrame then return end
            
            local visibleHeight = self.frame:GetHeight() - (self:GetContentInset()*2)
            -- Add arbitrary padding at the bottom so the last item isn't strictly flush against the border
            local BOTTOM_PADDING = 20
            local maxScroll = math.max(0, ObjectiveTrackerFrame:GetHeight() - visibleHeight + BOTTOM_PADDING)
            
            -- Scrolling down (delta < 0) means we want to push the content UP so we see lower items.
            -- Pushing content UP means a POSITIVE Y offset on the TOPLEFT anchor.
            self._currentScroll = self._currentScroll - (delta * 60)
            
            -- Clamp between 0 (top) and maxScroll (bottom)
            if self._currentScroll < 0 then self._currentScroll = 0 end
            if self._currentScroll > maxScroll then self._currentScroll = maxScroll end
            
            self.scrollChild:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, self._currentScroll)
            self.scrollChild:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, self._currentScroll)
        end
        
        self.frame:EnableMouseWheel(true)
        self.frame:SetScript("OnMouseWheel", handleScroll)
        tracker:EnableMouseWheel(true)
        tracker:SetScript("OnMouseWheel", handleScroll)

        -- Replace UpdateHeight to track exact height of modules
        local origUpdateHeight = tracker.UpdateHeight
        tracker.UpdateHeight = function(container)
            local h = 0
            if container.Header and container.Header:IsShown() then
                h = h + container.Header:GetHeight()
            end
            for _, module in ipairs(container.modules or {}) do
                if module.contentsHeight and module:IsShown() then
                    h = h + module.contentsHeight
                end
            end
            container:SetHeight(math.max(h, 50))
            
            -- Clamp scroll offset if container height became smaller
            local visibleHeight = self.frame:GetHeight() - (self:GetContentInset()*2)
            local BOTTOM_PADDING = 20
            local maxScroll = math.max(0, container:GetHeight() - visibleHeight + BOTTOM_PADDING)
            if self._currentScroll > maxScroll then
                self._currentScroll = maxScroll
                self.scrollChild:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, self._currentScroll)
                self.scrollChild:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, self._currentScroll)
            end
        end

        self._heightOverridden = true
    end

    self._captured = true
end

-- [ APPLY SETTINGS ]---------------------------------------------------------------------------------
function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then return end

    if InCombatLockdown() then
        Orbit.CombatManager:QueueUpdate(function() self:ApplySettings() end)
        return
    end

    self:CaptureTracker()

    local scale = self:GetSetting(SYSTEM_ID, "Scale") or C.DEFAULT_SCALE
    local width = self:GetSetting(SYSTEM_ID, "Width") or C.DEFAULT_WIDTH
    local height = self:GetSetting(SYSTEM_ID, "Height") or C.DEFAULT_HEIGHT
    frame:SetScale(scale / 100)
    frame:Show()

    -- Border must be applied before width/anchors so borderPixelSize is available for inset calc
    self:ApplyBorder()

    -- Background backdrop
    self:ApplyBackdrop()

    -- Apply size and re-anchor tracker inside border
    local s = frame:GetEffectiveScale()
    local snappedWidth = OrbitEngine.Pixel:Snap(width, s)
    local snappedHeight = OrbitEngine.Pixel:Snap(height, s)
    frame:SetSize(snappedWidth, snappedHeight)

    if ObjectiveTrackerFrame then
        local pad = self:GetContentInset()
        local innerWidth = snappedWidth - (pad * 2)

        ObjectiveTrackerFrame:ClearAllPoints()
        ObjectiveTrackerFrame:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", pad, -pad)
        ObjectiveTrackerFrame:SetPoint("TOPRIGHT", self.scrollChild, "TOPRIGHT", -pad, -pad)
        ObjectiveTrackerFrame:SetWidth(innerWidth)
    end

    -- Re-apply skins with current settings
    self:ApplySkins()

    -- Restore collapse state (always persist)
    self:RestoreCollapseState()

    -- Apply MouseOver
    self:ApplyMouseOver(frame, SYSTEM_ID)
end

-- [ BORDER ]------------------------------------------------------------------------------------------
function Plugin:ApplyBorder()
    local frame = self.frame
    local showBorder = self:GetSetting(SYSTEM_ID, "ShowBorder")
    if showBorder == false then
        if Orbit.Skin.ClearNineSliceBorder then Orbit.Skin:ClearNineSliceBorder(frame) end
        if frame._borderFrame then frame._borderFrame:Hide() end
        return
    end

    local gs = Orbit.db and Orbit.db.GlobalSettings
    local borderSize = gs and gs.BorderSize or 1
    Orbit.Skin:SkinBorder(frame, frame, borderSize)
end

-- [ CONTENT INSET ]-----------------------------------------------------------------------------------
function Plugin:GetContentInset()
    local showBorder = self:GetSetting(SYSTEM_ID, "ShowBorder")
    local borderInset = 0
    if showBorder ~= false then
        borderInset = OrbitEngine.Pixel:BorderInset(self.frame, 1)
    end
    return borderInset + C.CONTENT_PADDING
end

-- [ BACKDROP ]----------------------------------------------------------------------------------------
function Plugin:ApplyBackdrop()
    local frame = self.frame
    local opacity = (self:GetSetting(SYSTEM_ID, "BackgroundOpacity") or C.BG_OPACITY_DEFAULT) / 100

    if not frame._backdrop then
        frame._backdrop = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        frame._backdrop:SetAllPoints(frame)
    end

    if opacity > 0 then
        local gs = Orbit.db and Orbit.db.GlobalSettings
        local bgColor = gs and gs.BackdropColour or { r = 0, g = 0, b = 0 }
        frame._backdrop:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, opacity)
        frame._backdrop:Show()
    else
        frame._backdrop:Hide()
    end
end

-- [ COLLAPSE PERSISTENCE ]----------------------------------------------------------------------------
function Plugin:SaveCollapseState()
    if not Orbit.db or not Orbit.db.AccountSettings then return end
    local state = {}

    -- Main tracker collapse
    if ObjectiveTrackerFrame then
        state._main = ObjectiveTrackerFrame.isCollapsed or false
    end

    -- Per-module collapse
    for _, moduleName in pairs(C.TRACKER_MODULES) do
        local tracker = _G[moduleName]
        if tracker then
            state[moduleName] = tracker.isCollapsed or false
        end
    end

    Orbit.db.AccountSettings.ObjectivesCollapseState = state
end

function Plugin:RestoreCollapseState()
    local state = Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.ObjectivesCollapseState
    if not state then return end

    -- Main tracker
    if ObjectiveTrackerFrame and state._main and ObjectiveTrackerFrame.SetCollapsed then
        if ObjectiveTrackerFrame.isCollapsed ~= state._main then
            ObjectiveTrackerFrame:SetCollapsed(state._main)
        end
    end

    -- Per-module
    for _, moduleName in pairs(C.TRACKER_MODULES) do
        local tracker = _G[moduleName]
        if tracker and state[moduleName] ~= nil and tracker.SetCollapsed then
            if tracker.isCollapsed ~= state[moduleName] then
                tracker:SetCollapsed(state[moduleName])
            end
        end
    end
end

function Plugin:InstallCollapseHooks()
    if self._collapseHooksInstalled then return end

    -- Hook the main tracker header collapse
    if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header and ObjectiveTrackerFrame.Header.SetCollapsed then
        hooksecurefunc(ObjectiveTrackerFrame.Header, "SetCollapsed", function()
            self:SaveCollapseState()
        end)
    end

    -- Hook per-module collapse via their headers
    for _, moduleName in pairs(C.TRACKER_MODULES) do
        local tracker = _G[moduleName]
        if tracker and tracker.Header and tracker.Header.SetCollapsed then
            hooksecurefunc(tracker.Header, "SetCollapsed", function()
                self:SaveCollapseState()
            end)
        end
    end

    self._collapseHooksInstalled = true
end

-- [ AUTO-COLLAPSE IN COMBAT ]------------------------------------------------------------------------
function Plugin:InstallCombatCollapseHooks()
    if self._combatCollapseInstalled then return end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        local enabled = self:GetSetting(SYSTEM_ID, "AutoCollapseCombat")
        if not enabled then return end
        if not ObjectiveTrackerFrame then return end

        if event == "PLAYER_REGEN_DISABLED" then
            -- Save current state before collapsing
            self._preCombatCollapsed = ObjectiveTrackerFrame.isCollapsed
            if not ObjectiveTrackerFrame.isCollapsed and ObjectiveTrackerFrame.SetCollapsed then
                ObjectiveTrackerFrame:SetCollapsed(true)
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Restore pre-combat state
            if self._preCombatCollapsed == false and ObjectiveTrackerFrame.SetCollapsed then
                ObjectiveTrackerFrame:SetCollapsed(false)
            end
            self._preCombatCollapsed = nil
        end
    end)

    self._combatCollapseInstalled = true
end

-- [ BLIZZARD HIDER ]---------------------------------------------------------------------------------
Orbit:RegisterBlizzardHider("Objectives", function()
    if ObjectiveTrackerFrame then OrbitEngine.NativeFrame:SecureHide(ObjectiveTrackerFrame) end
end)
