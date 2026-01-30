---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

local SYSTEM_ID = "Orbit_TargetBuffs"
local SYSTEM_INDEX = 1

local Plugin = Orbit:RegisterPlugin("Target Buffs", SYSTEM_ID, {
    defaults = {
        IconsPerRow = 5,
        MaxRows = 2,
        Spacing = 2,
        Width = 200,
        Scale = 100,
    },
}, Orbit.Constants.PluginGroups.UnitFrames)

-- We still include AuraMixin for preview mode
Mixin(Plugin, Orbit.AuraMixin)

local Frame

-- [ HELPERS ]----------------------------------------------------------------------------------------
function Plugin:IsEnabled()
    local targetPlugin = Orbit:GetPlugin("Orbit_TargetFrame")
    local TARGET_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Target
    if targetPlugin and targetPlugin.GetSetting then
        local enabled = targetPlugin:GetSetting(TARGET_FRAME_INDEX, "EnableBuffs")
        if enabled ~= nil then
            return enabled
        end
    end
    return true
end

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    if not Frame then
        return
    end

    local systemIndex = SYSTEM_INDEX
    local WL = OrbitEngine.WidgetLogic

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    table.insert(schema.controls, {
        type = "slider",
        key = "IconsPerRow",
        label = "Icons Per Row",
        min = 4,
        max = 10,
        step = 1,
        default = 5,
        onChange = function(val)
            self:SetSetting(systemIndex, "IconsPerRow", val)
            self:ApplySettings()
        end,
    })

    table.insert(schema.controls, {
        type = "slider",
        key = "MaxRows",
        label = "Max Rows",
        min = 1,
        max = 6,
        step = 1,
        default = 2,
    })

    table.insert(schema.controls, {
        type = "slider",
        key = "Spacing",
        label = "Spacing",
        min = 0,
        max = 10,
        step = 1,
        default = 2,
    })

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil

    if not isAnchored then
        table.insert(schema.controls, {
            type = "slider",
            key = "Scale",
            label = "Scale",
            min = 50,
            max = 200,
            step = 1,
            default = 100,
        })
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Container for reparented Blizzard buff frames
    Frame = CreateFrame("Frame", "OrbitTargetBuffsFrame", UIParent)
    Frame:SetSize(200, 40)
    if OrbitEngine.Pixel then
        OrbitEngine.Pixel:Enforce(Frame)
    end

    RegisterUnitWatch(Frame)

    self.frame = Frame
    Frame.unit = "target"
    Frame:SetAttribute("unit", "target")

    -- Edit Mode
    Frame.editModeName = "Target Buffs"
    Frame.systemIndex = SYSTEM_INDEX
    Frame.anchorOptions = {
        horizontal = false,
        vertical = true,
    }
    OrbitEngine.Frame:AttachSettingsListener(Frame, self, SYSTEM_INDEX)

    -- Default Position
    local targetFrame = _G["OrbitTargetFrame"]
    if targetFrame then
        Frame:ClearAllPoints()
        Frame:SetPoint("TOPLEFT", targetFrame, "BOTTOMLEFT", 0, -4)
        OrbitEngine.Frame:CreateAnchor(Frame, targetFrame, "BOTTOM", 4, nil, "LEFT")
    else
        Frame:SetPoint("CENTER", UIParent, "CENTER", 200, -180)
    end

    self:ApplySettings()

    -- Live resize: recalculate icons when frame size changes
    Frame:HookScript("OnSizeChanged", function()
        local isEditMode = EditModeManagerFrame
            and EditModeManagerFrame.IsEditModeActive
            and EditModeManagerFrame:IsEditModeActive()
        if isEditMode then
            self:ShowPreviewAuras()
        else
            self:UpdateBuffs()
        end
    end)

    -- Events for visibility & updates
    Frame:RegisterUnitEvent("UNIT_AURA", "target")
    Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    Frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    Frame:SetScript("OnEvent", function(f, event, unit)
        if
            EditModeManagerFrame
            and EditModeManagerFrame.IsEditModeActive
            and EditModeManagerFrame:IsEditModeActive()
        then
            if event == "UNIT_AURA" then
                return
            end
        end

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            self:UpdateVisibility()
        elseif event == "UNIT_AURA" then
            if unit == f.unit then
                self:UpdateBuffs()
            end
        end
    end)

    -- Edit Mode Callbacks
    if OrbitEngine.EditMode then
        OrbitEngine.EditMode:RegisterCallbacks({
            Enter = function()
                self:UpdateVisibility()
            end,
            Exit = function()
                self:UpdateVisibility()
            end,
        }, self)
    end

    self:UpdateVisibility()
end

-- [ UPDATE BUFFS ]---------------------------------------------------------------------------------------
function Plugin:UpdateBuffs()
    if not Frame or not Frame:IsShown() then
        return
    end

    local enabled = self:IsEnabled()
    if not enabled then
        return
    end

    -- Get settings
    local iconsPerRow = self:GetSetting(SYSTEM_INDEX, "IconsPerRow") or 5
    local maxRows = self:GetSetting(SYSTEM_INDEX, "MaxRows") or 2
    local spacing = self:GetSetting(SYSTEM_INDEX, "Spacing") or 2
    local maxWidth = Frame:GetWidth()

    -- Calculate icon size (Pixel Perfect)
    -- Floor to avoid blurry sub-pixels.
    local totalSpacing = (iconsPerRow - 1) * spacing
    local iconSize = math.floor((maxWidth - totalSpacing) / iconsPerRow)
    if iconSize < 1 then
        iconSize = 1
    end

    -- Fetch Auras
    local maxBuffs = iconsPerRow * maxRows
    local buffs = self:FetchAuras("target", "HELPFUL", maxBuffs)

    -- Create pool if needed
    if not Frame.auraPool then
        self:CreateAuraPool(Frame, "BackdropTemplate")
    end
    Frame.auraPool:ReleaseAll()

    if #buffs == 0 then
        return
    end

    -- Determine anchor-aware growth direction
    local anchor = "TOPLEFT"
    local growthY = "DOWN"

    local myAnchor = OrbitEngine.Frame and OrbitEngine.Frame.anchors and OrbitEngine.Frame.anchors[Frame]
    if myAnchor then
        if myAnchor.edge == "TOP" then
            anchor = "BOTTOMLEFT"
            growthY = "UP"
        elseif myAnchor.edge == "BOTTOM" then
            anchor = "TOPLEFT"
            growthY = "DOWN"
        end
    end

    local skinSettings = {
        zoom = 0,
        borderStyle = 1, -- Pixel Perfect
        borderSize = Orbit.db.GlobalSettings.BorderSize,
        showTimer = false,
    }

    local activeIcons = {}
    for i, aura in ipairs(buffs) do
        local icon = Frame.auraPool:Acquire()
        self:SetupAuraIcon(icon, aura, iconSize, "target", skinSettings)

        -- Buffs typically use HELPFUL filter for tooltips
        self:SetupAuraTooltip(icon, aura, "target", "HELPFUL")

        table.insert(activeIcons, icon)
    end

    local anchorConfig = {
        size = iconSize,
        spacing = spacing,
        maxPerRow = iconsPerRow,
        anchor = anchor,
        growthX = "RIGHT",
        growthY = growthY,
    }

    self:LayoutAurasGrid(Frame, activeIcons, anchorConfig)
end

-- [ VISIBILITY ]-------------------------------------------------------------------------------------
function Plugin:UpdateVisibility()
    if not Frame then
        return
    end

    local enabled = self:IsEnabled()
    local isEditMode = EditModeManagerFrame
        and EditModeManagerFrame.IsEditModeActive
        and EditModeManagerFrame:IsEditModeActive()

    if isEditMode then
        if not InCombatLockdown() then
            UnregisterUnitWatch(Frame)
        end

        if enabled then
            if not UnitExists("target") then
                Frame.unit = "player"
            end
            -- In edit mode, show preview using our own icons
            Orbit:SafeAction(function()
                Frame:Show()
                Frame:SetAlpha(1)
            end)
            self:ShowPreviewAuras()
        else
            Orbit:SafeAction(function()
                Frame:Hide()
            end)
        end
        return
    end

    Frame.unit = "target"

    -- Clean up preview pool when not in edit mode
    if Frame.previewPool then
        Frame.previewPool:ReleaseAll()
    end

    if enabled then
        if not InCombatLockdown() then
            RegisterUnitWatch(Frame)
        end

        if UnitExists("target") then
            self:UpdateBuffs()
        end
    else
        if not InCombatLockdown() then
            UnregisterUnitWatch(Frame)
            Frame:Hide()
            OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
        end
    end

    if enabled then
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false)
    end
end

-- [ PREVIEW ]---------------------------------------------------------------------------------------
function Plugin:ShowPreviewAuras()
    -- For edit mode, show placeholder icons using our own pool
    local iconsPerRow = self:GetSetting(SYSTEM_INDEX, "IconsPerRow") or 5
    local maxRows = self:GetSetting(SYSTEM_INDEX, "MaxRows") or 2
    local maxBuffs = iconsPerRow * maxRows
    local spacing = self:GetSetting(SYSTEM_INDEX, "Spacing") or 2
    local maxWidth = Frame:GetWidth()

    local totalSpacing = (iconsPerRow - 1) * spacing
    local iconSize = math.floor((maxWidth - totalSpacing) / iconsPerRow)

    if not Frame.previewPool then
        Frame.previewPool = self:CreateAuraPool(Frame, "BackdropTemplate")
    end
    Frame.previewPool:ReleaseAll()

    local previews = {}
    for i = 1, maxBuffs do
        local icon = Frame.previewPool:Acquire()
        local aura = {
            icon = 136000,
            applications = i,
            duration = 0,
            expirationTime = 0,
            index = i,
            isHelpful = true,
        }
        self:SetupAuraIcon(icon, aura, iconSize, "player", {
            zoom = 0,
            borderStyle = 1,
            borderSize = 1,
            showTimer = false,
        })
        icon:SetScript("OnEnter", nil)
        icon:SetScript("OnLeave", nil)
        table.insert(previews, icon)
    end

    -- Determine anchor-aware growth direction (same as ReparentBlizzardBuffs)
    local anchor = "TOPLEFT"
    local growthY = "DOWN"

    local myAnchor = OrbitEngine.Frame and OrbitEngine.Frame.anchors and OrbitEngine.Frame.anchors[Frame]
    if myAnchor then
        if myAnchor.edge == "TOP" then
            anchor = "BOTTOMLEFT"
            growthY = "UP"
        elseif myAnchor.edge == "BOTTOM" then
            anchor = "TOPLEFT"
            growthY = "DOWN"
        end
    end

    local anchorConfig = {
        size = iconSize,
        spacing = spacing,
        maxPerRow = iconsPerRow,
        anchor = anchor,
        growthX = "RIGHT",
        growthY = growthY,
    }
    self:LayoutAurasGrid(Frame, previews, anchorConfig)
end

-- [ APPLY SETTINGS ]---------------------------------------------------------------------------------
function Plugin:ApplySettings()
    if not Frame then
        return
    end
    if InCombatLockdown() then
        return
    end

    local width = self:GetSetting(SYSTEM_INDEX, "Width")
    local scale = self:GetSetting(SYSTEM_INDEX, "Scale") or 100
    Frame:SetScale(scale / 100)

    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil

    if not isAnchored then
        Frame:SetWidth(width)
    else
        local parent = OrbitEngine.Frame:GetAnchorParent(Frame)
        if parent then
            Frame:SetWidth(parent:GetWidth())
        end
    end

    -- Calculate layout
    local iconsPerRow = self:GetSetting(SYSTEM_INDEX, "IconsPerRow") or 5
    local maxRows = self:GetSetting(SYSTEM_INDEX, "MaxRows") or 2
    local spacing = self:GetSetting(SYSTEM_INDEX, "Spacing") or 2
    local maxWidth = Frame:GetWidth()

    local totalSpacing = (iconsPerRow - 1) * spacing
    local iconSize = math.floor((maxWidth - totalSpacing) / iconsPerRow)
    Frame.iconSize = iconSize

    -- Set height based on maxRows (Fixed height)
    local height = (maxRows * iconSize) + ((maxRows - 1) * spacing)
    if height < 1 then
        height = 1
    end
    Frame:SetHeight(height)

    OrbitEngine.Frame:RestorePosition(Frame, self, SYSTEM_INDEX)
    self:UpdateVisibility()
end
