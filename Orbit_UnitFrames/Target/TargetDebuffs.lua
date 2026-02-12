---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

local SYSTEM_ID = "Orbit_TargetDebuffs"
local SYSTEM_INDEX = 1

local Constants = Orbit.Constants

local Plugin = Orbit:RegisterPlugin("Target Debuffs", SYSTEM_ID, {
    defaults = {
        IconsPerRow = 5,
        MaxRows = 2,
        Spacing = 2,
        Width = 200,
        Scale = 100,
        PandemicGlowType = Constants.PandemicGlow.DefaultType,
        PandemicGlowColor = Constants.PandemicGlow.DefaultColor,
        PandemicGlowColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.8, b = 0, a = 1 } } } },
    },
}, Orbit.Constants.PluginGroups.UnitFrames)

Mixin(Plugin, Orbit.AuraMixin)

local Frame

-- [ HELPERS ]----------------------------------------------------------------------------------------
function Plugin:IsEnabled()
    local targetPlugin = Orbit:GetPlugin("Orbit_TargetFrame")
    local TARGET_FRAME_INDEX = Enum.EditModeUnitFrameSystemIndices.Target
    if targetPlugin and targetPlugin.GetSetting then
        local enabled = targetPlugin:GetSetting(TARGET_FRAME_INDEX, "EnableDebuffs")
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
    local schema = { hideNativeSettings = true, controls = {} }

    WL:SetTabRefreshCallback(dialog, self, systemFrame)
    local currentTab = WL:AddSettingsTabs(schema, dialog, { "Layout", "Glows" }, "Layout")

    if currentTab == "Layout" then
        table.insert(schema.controls, {
            type = "slider", key = "IconsPerRow", label = "Icons Per Row",
            min = 4, max = 10, step = 1, default = 5,
            onChange = function(val)
                self:SetSetting(systemIndex, "IconsPerRow", val)
                self:ApplySettings()
            end,
        })
        table.insert(schema.controls, {
            type = "slider", key = "MaxRows", label = "Max Rows",
            min = 1, max = 4, step = 1, default = 2,
        })
        table.insert(schema.controls, {
            type = "slider", key = "Spacing", label = "Spacing",
            min = 0, max = 10, step = 1, default = 2,
        })
        local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil
        if not isAnchored then
            table.insert(schema.controls, {
                type = "slider", key = "Scale", label = "Scale",
                min = 50, max = 200, step = 5, default = 100,
            })
        end
    elseif currentTab == "Glows" then
        local GlowType = Constants.PandemicGlow.Type
        table.insert(schema.controls, {
            type = "dropdown", key = "PandemicGlowType", label = "Pandemic Glow",
            options = {
                { text = "None", value = GlowType.None },
                { text = "Pixel Glow", value = GlowType.Pixel },
                { text = "Proc Glow", value = GlowType.Proc },
                { text = "Autocast Shine", value = GlowType.Autocast },
                { text = "Button Glow", value = GlowType.Button },
            },
            default = Constants.PandemicGlow.DefaultType,
        })
        WL:AddColorCurveSettings(self, schema, systemIndex, systemFrame, {
            key = "PandemicGlowColorCurve", label = "Pandemic Colour",
            default = { pins = { { position = 0, color = { r = 1, g = 0.8, b = 0, a = 1 } } } },
            singleColor = true,
        })
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    Frame = CreateFrame("Frame", "OrbitTargetDebuffsFrame", UIParent)
    Frame:SetSize(200, 20)
    if OrbitEngine.Pixel then
        OrbitEngine.Pixel:Enforce(Frame)
    end

    RegisterUnitWatch(Frame)

    self.frame = Frame
    Frame.unit = "target"
    Frame:SetAttribute("unit", "target")

    -- Edit Mode
    Frame.editModeName = "Target Debuffs"
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
        Frame:SetPoint("TOPLEFT", targetFrame, "BOTTOMLEFT", 0, -50)
        OrbitEngine.Frame:CreateAnchor(Frame, targetFrame, "BOTTOM", 50, nil, "LEFT")
    else
        Frame:SetPoint("CENTER", UIParent, "CENTER", 200, -220)
    end

    self:ApplySettings()

    Frame:HookScript("OnShow", function()
        if not Orbit:IsEditMode() then
            self:UpdateDebuffs()
        end
    end)

    Frame:HookScript("OnSizeChanged", function()
        if Orbit:IsEditMode() then
            self:ShowPreviewAuras()
        else
            self:UpdateDebuffs()
        end
    end)


    Frame:RegisterUnitEvent("UNIT_AURA", "target")
    Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    Frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    Frame:SetScript("OnEvent", function(f, event, unit)
        if Orbit:IsEditMode() then
            if event == "UNIT_AURA" then
                return
            end
        end

        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            self:UpdateVisibility()
            self:UpdateDebuffs()
        elseif event == "UNIT_AURA" then
            if unit == f.unit then
                self:UpdateDebuffs()
            end
        end
    end)

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

-- [ UPDATE DEBUFFS ]---------------------------------------------------------------------------------------
function Plugin:UpdateDebuffs()
    if not Frame then
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

    local totalSpacing = (iconsPerRow - 1) * spacing
    local iconSize = math.floor((maxWidth - totalSpacing) / iconsPerRow)
    if iconSize < 1 then
        iconSize = 1
    end

    local maxDebuffs = iconsPerRow * maxRows
    local debuffs = self:FetchAuras("target", "HARMFUL|PLAYER", maxDebuffs)

    if not Frame.auraPool then
        self:CreateAuraPool(Frame, "BackdropTemplate")
    end
    Frame.auraPool:ReleaseAll()

    if #debuffs == 0 then
        return
    end

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
        showTimer = true,
        enablePandemic = true,
        pandemicGlowType = self:GetSetting(SYSTEM_INDEX, "PandemicGlowType") or Constants.PandemicGlow.DefaultType,
        pandemicGlowColor = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(self:GetSetting(SYSTEM_INDEX, "PandemicGlowColorCurve")) or self:GetSetting(SYSTEM_INDEX, "PandemicGlowColor") or Constants.PandemicGlow.DefaultColor,
    }

    local activeIcons = {}
    for i, aura in ipairs(debuffs) do
        local icon = Frame.auraPool:Acquire()
        self:SetupAuraIcon(icon, aura, iconSize, "target", skinSettings)

        self:SetupAuraTooltip(icon, aura, "target", "HARMFUL|PLAYER")

        table.insert(activeIcons, icon)
    end

    local anchorConfig = {
        size = iconSize,
        spacing = spacing,
        maxPerRow = iconsPerRow,
        anchor = anchor,
        growthX = "RIGHT",
        growthY = growthY,
        yOffset = 0,
    }

    self:LayoutAurasGrid(Frame, activeIcons, anchorConfig)
end

-- [ VISIBILITY ]-------------------------------------------------------------------------------------
function Plugin:UpdateVisibility()
    if not Frame then
        return
    end
    local enabled = self:IsEnabled()
    local isEditMode = Orbit:IsEditMode()

    if isEditMode then
        if not InCombatLockdown() then
            UnregisterUnitWatch(Frame)
        end

        if enabled then
            OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false)
            if not UnitExists("target") then
                Frame.unit = "player"
            end
            Orbit:SafeAction(function()
                Frame:Show()
                Frame:SetAlpha(1)
            end)
            self:ShowPreviewAuras()
        else
            OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
            Orbit:SafeAction(function()
                Frame:Hide()
            end)
        end
        return
    end

    Frame.unit = "target"

    if Frame.previewPool then
        Frame.previewPool:ReleaseAll()
    end

    if enabled then
        if not InCombatLockdown() then
            RegisterUnitWatch(Frame)
        end

        if UnitExists("target") then
            self:UpdateDebuffs()
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
            isHarmful = true,
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
        yOffset = 0,
    }
    self:LayoutAurasGrid(Frame, previews, anchorConfig)
end

-- [ APPLY SETTINGS ]---------------------------------------------------------------------------------
function Plugin:ApplySettings()
    if not Frame or InCombatLockdown() then
        return
    end
    local width = self:GetSetting(SYSTEM_INDEX, "Width")
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil
    if not isAnchored then
        local scale = self:GetSetting(SYSTEM_INDEX, "Scale") or 100
        Frame:SetScale(scale / 100)
        Frame:SetWidth(width)
    else
        Frame:SetScale(1)
        local parent = OrbitEngine.Frame:GetAnchorParent(Frame)
        if parent then
            Frame:SetWidth(parent:GetWidth())
        end
    end

    local iconsPerRow = self:GetSetting(SYSTEM_INDEX, "IconsPerRow") or 5
    local maxRows = self:GetSetting(SYSTEM_INDEX, "MaxRows") or 2
    local spacing = self:GetSetting(SYSTEM_INDEX, "Spacing") or 2
    local maxWidth = Frame:GetWidth()

    local totalSpacing = (iconsPerRow - 1) * spacing
    local iconSize = math.floor((maxWidth - totalSpacing) / iconsPerRow)
    Frame.iconSize = iconSize

    local height = (maxRows * iconSize) + ((maxRows - 1) * spacing)
    if height < 1 then
        height = 1
    end
    Frame:SetHeight(height)

    OrbitEngine.Frame:RestorePosition(Frame, self, SYSTEM_INDEX)
    self:UpdateVisibility()
end

-- [ UPDATE LAYOUT ]-----------------------------------------------------------------------------------
-- Called by Anchor:SyncChildren when parent frame dimensions change
function Plugin:UpdateLayout()
    if not Frame then
        return
    end

    -- Recalculate icon layout based on current width
    local iconsPerRow = self:GetSetting(SYSTEM_INDEX, "IconsPerRow") or 5
    local maxRows = self:GetSetting(SYSTEM_INDEX, "MaxRows") or 2
    local spacing = self:GetSetting(SYSTEM_INDEX, "Spacing") or 2
    local maxWidth = Frame:GetWidth()

    local totalSpacing = (iconsPerRow - 1) * spacing
    local iconSize = math.floor((maxWidth - totalSpacing) / iconsPerRow)
    if iconSize < 1 then
        iconSize = 1
    end
    Frame.iconSize = iconSize

    local height = (maxRows * iconSize) + ((maxRows - 1) * spacing)
    if height < 1 then
        height = 1
    end
    Frame:SetHeight(height)

    -- Refresh display
    local isEditMode = Orbit:IsEditMode()

    if isEditMode then
        self:ShowPreviewAuras()
    else
        self:UpdateDebuffs()
    end
end
