-- [ UNIT AURA GRID MIXIN ]--------------------------------------------------------------------------
-- Shared mixin for Target/Focus buff and debuff grid plugins.
-- Follows the CastBarMixin pattern: thin consumer wrappers call config methods.
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

Orbit.UnitAuraGridMixin = {}
local Mixin = Orbit.UnitAuraGridMixin

Mixin.sharedDebuffDefaults = {
    IconsPerRow = 8, MaxRows = 2, Spacing = 2, Width = 200, Scale = 100,
    PandemicGlowType = Constants.PandemicGlow.DefaultType,
    PandemicGlowColor = Constants.PandemicGlow.DefaultColor,
    PandemicGlowColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.8, b = 0, a = 1 } } } },
}

Mixin.sharedBuffDefaults = {
    IconsPerRow = 8, MaxRows = 2, Spacing = 2, Width = 200, Scale = 100,
}

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function GetAnchorGrowth(frame)
    local myAnchor = OrbitEngine.Frame and OrbitEngine.Frame.anchors and OrbitEngine.Frame.anchors[frame]
    if myAnchor and myAnchor.edge == "TOP" then return "BOTTOMLEFT", "UP" end
    return "TOPLEFT", "DOWN"
end

local function CalculateIconSize(maxWidth, iconsPerRow, spacing)
    local totalSpacing = (iconsPerRow - 1) * spacing
    return math.max(1, math.floor((maxWidth - totalSpacing) / iconsPerRow))
end

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Mixin:AddAuraGridSettings(dialog, systemFrame)
    local Frame = self._agFrame
    if not Frame then return end
    local cfg = self._agConfig
    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }

    if cfg.enablePandemic then
        SB:SetTabRefreshCallback(dialog, self, systemFrame)
        local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Glows" }, "Layout")
        if currentTab == "Layout" then
            self:_addLayoutControls(schema)
        elseif currentTab == "Glows" then
            self:_addGlowControls(schema, SB, systemFrame)
        end
    else
        self:_addLayoutControls(schema)
    end

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

function Mixin:_addLayoutControls(schema)
    local cfg = self._agConfig
    table.insert(schema.controls, {
        type = "slider", key = "IconsPerRow", label = "Icons Per Row",
        min = 4, max = 10, step = 1, default = 5,
        onChange = function(val) self:SetSetting(1, "IconsPerRow", val); self:ApplySettings() end,
    })
    table.insert(schema.controls, {
        type = "slider", key = "MaxRows", label = "Max Rows",
        min = 1, max = cfg.maxRowsMax or 4, step = 1, default = 2,
    })
    table.insert(schema.controls, {
        type = "slider", key = "Spacing", label = "Spacing",
        min = -5, max = 50, step = 1, default = 2,
    })
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(self._agFrame) ~= nil
    if not isAnchored then
        table.insert(schema.controls, {
            type = "slider", key = "Scale", label = "Scale",
            min = 50, max = 200, step = 1, default = 100,
        })
    end
end

function Mixin:_addGlowControls(schema, SB, systemFrame)
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
    SB:AddColorCurveSettings(self, schema, 1, systemFrame, {
        key = "PandemicGlowColorCurve", label = "Pandemic Colour",
        default = { pins = { { position = 0, color = { r = 1, g = 0.8, b = 0, a = 1 } } } },
        singleColor = true,
    })
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Mixin:CreateAuraGridPlugin(config)
    self._agConfig = config
    local Frame = CreateFrame("Frame", config.frameName, UIParent)
    Frame:SetSize(config.initialWidth or 200, config.initialHeight or 20)
    OrbitEngine.Pixel:Enforce(Frame)
    RegisterUnitWatch(Frame)

    self.frame = Frame
    self._agFrame = Frame
    if config.exposeMountedConfig then self.mountedConfig = { frame = Frame } end
    Frame.unit = config.unit
    Frame:SetAttribute("unit", config.unit)

    Frame.editModeName = config.editModeName
    Frame.systemIndex = 1
    Frame.anchorOptions = { horizontal = false, vertical = true }
    OrbitEngine.Frame:AttachSettingsListener(Frame, self, 1)

    -- Default position: anchor to parent frame or fallback
    local parentFrame = _G[config.anchorParent]
    if parentFrame then
        Frame:ClearAllPoints()
        Frame:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 0, config.anchorGap or -50)
        OrbitEngine.Frame:CreateAnchor(Frame, parentFrame, "BOTTOM", config.anchorGap or 50, nil, "LEFT")
    else
        Frame:SetPoint("CENTER", UIParent, "CENTER", config.defaultX or 0, config.defaultY or -220)
    end

    self:ApplySettings()

    Frame:HookScript("OnShow", function()
        if not Orbit:IsEditMode() then self:UpdateAuras() end
    end)
    Frame:HookScript("OnSizeChanged", function()
        if Orbit:IsEditMode() then self:ShowPreviewAuras() else self:UpdateAuras() end
    end)

    Frame:RegisterUnitEvent("UNIT_AURA", config.unit)
    Frame:RegisterEvent(config.changeEvent)
    Frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    Frame:SetScript("OnEvent", function(f, event, unit)
        if Orbit:IsEditMode() and event == "UNIT_AURA" then return end
        if event == config.changeEvent or event == "PLAYER_ENTERING_WORLD" then
            self:UpdateVisibility()
            self:UpdateAuras()
        elseif event == "UNIT_AURA" and unit == f.unit then
            self:UpdateAuras()
        end
    end)

    OrbitEngine.EditMode:RegisterCallbacks({
        Enter = function() self:UpdateVisibility() end,
        Exit = function() self:UpdateVisibility() end,
    }, self)

    self:UpdateVisibility()
end

-- [ UPDATE AURAS ]----------------------------------------------------------------------------------
function Mixin:UpdateAuras()
    local Frame = self._agFrame
    local cfg = self._agConfig
    if not Frame then return end
    if not self:IsEnabled() then return end

    local iconsPerRow = self:GetSetting(1, "IconsPerRow") or 5
    local maxRows = self:GetSetting(1, "MaxRows") or 2
    local spacing = self:GetSetting(1, "Spacing") or 2
    local maxWidth = Frame:GetWidth()
    local iconSize = CalculateIconSize(maxWidth, iconsPerRow, spacing)
    local maxAuras = iconsPerRow * maxRows

    local auras = self:FetchAuras(cfg.unit, cfg.auraFilter, maxAuras)

    if not Frame.auraPool then self:CreateAuraPool(Frame, "BackdropTemplate") end
    Frame.auraPool:ReleaseAll()
    if #auras == 0 then return end

    local anchor, growthY = GetAnchorGrowth(Frame)

    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = Orbit.db.GlobalSettings.BorderSize, showTimer = cfg.showTimer }
    if cfg.enablePandemic then
        skinSettings.enablePandemic = true
        skinSettings.pandemicGlowType = self:GetSetting(1, "PandemicGlowType") or Constants.PandemicGlow.DefaultType
        skinSettings.pandemicGlowColor = OrbitEngine.ColorCurve:GetFirstColorFromCurve(self:GetSetting(1, "PandemicGlowColorCurve")) or self:GetSetting(1, "PandemicGlowColor") or Constants.PandemicGlow.DefaultColor
    end

    local activeIcons = {}
    local tooltipFilter = cfg.auraFilter
    for _, aura in ipairs(auras) do
        local icon = Frame.auraPool:Acquire()
        self:SetupAuraIcon(icon, aura, iconSize, cfg.unit, skinSettings)
        self:SetupAuraTooltip(icon, aura, cfg.unit, tooltipFilter)
        table.insert(activeIcons, icon)
    end

    Orbit.AuraLayout:LayoutGrid(Frame, activeIcons, {
        size = iconSize, spacing = spacing, maxPerRow = iconsPerRow,
        anchor = anchor, growthX = "RIGHT", growthY = growthY, yOffset = 0,
    })
end

-- [ VISIBILITY ]-------------------------------------------------------------------------------------
function Mixin:UpdateVisibility()
    local Frame = self._agFrame
    local cfg = self._agConfig
    if not Frame then return end

    local enabled = self:IsEnabled()
    local isEditMode = Orbit:IsEditMode()

    if isEditMode then
        if not InCombatLockdown() then UnregisterUnitWatch(Frame) end
        if enabled then
            OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false)
            if not UnitExists(cfg.unit) then Frame.unit = "player" end
            Orbit:SafeAction(function() Frame:Show(); Frame:SetAlpha(1) end)
            self:ShowPreviewAuras()
        else
            OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
            Orbit:SafeAction(function() Frame:Hide() end)
        end
        return
    end

    Frame.unit = cfg.unit
    if Frame.previewPool then Frame.previewPool:ReleaseAll() end

    if enabled then
        if not InCombatLockdown() then RegisterUnitWatch(Frame) end
        if UnitExists(cfg.unit) then self:UpdateAuras() end
    else
        if not InCombatLockdown() then
            UnregisterUnitWatch(Frame)
            Frame:Hide()
            OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
        end
    end

    if enabled then OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false) end
end

-- [ PREVIEW ]---------------------------------------------------------------------------------------
function Mixin:ShowPreviewAuras()
    local Frame = self._agFrame
    local iconsPerRow = self:GetSetting(1, "IconsPerRow") or 5
    local maxRows = self:GetSetting(1, "MaxRows") or 2
    local spacing = self:GetSetting(1, "Spacing") or 2
    local maxWidth = Frame:GetWidth()
    local iconSize = CalculateIconSize(maxWidth, iconsPerRow, spacing)
    local maxAuras = iconsPerRow * maxRows

    if not Frame.previewPool then Frame.previewPool = self:CreateAuraPool(Frame, "BackdropTemplate") end
    Frame.previewPool:ReleaseAll()

    local previews = {}
    for i = 1, maxAuras do
        local icon = Frame.previewPool:Acquire()
        self:SetupAuraIcon(icon, {
            icon = 136000, applications = i, duration = 0,
            expirationTime = 0, index = i, isHarmful = self._agConfig.isHarmful,
        }, iconSize, "player", { zoom = 0, borderStyle = 1, borderSize = 1, showTimer = false })
        icon:SetScript("OnEnter", nil)
        icon:SetScript("OnLeave", nil)
        table.insert(previews, icon)
    end

    local anchor, growthY = GetAnchorGrowth(Frame)
    Orbit.AuraLayout:LayoutGrid(Frame, previews, {
        size = iconSize, spacing = spacing, maxPerRow = iconsPerRow,
        anchor = anchor, growthX = "RIGHT", growthY = growthY, yOffset = 0,
    })
end

-- [ APPLY SETTINGS ]--------------------------------------------------------------------------------
function Mixin:ApplySettings()
    local Frame = self._agFrame
    if not Frame or InCombatLockdown() then return end

    local width = self:GetSetting(1, "Width")
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil
    if not isAnchored then
        local scale = self:GetSetting(1, "Scale") or 100
        Frame:SetScale(scale / 100)
        Frame:SetWidth(width)
    else
        Frame:SetScale(1)
        local parent = OrbitEngine.Frame:GetAnchorParent(Frame)
        if parent then Frame:SetWidth(parent:GetWidth()) end
    end

    local iconsPerRow = self:GetSetting(1, "IconsPerRow") or 5
    local maxRows = self:GetSetting(1, "MaxRows") or 2
    local spacing = self:GetSetting(1, "Spacing") or 2
    local iconSize = CalculateIconSize(Frame:GetWidth(), iconsPerRow, spacing)
    Frame.iconSize = iconSize

    local height = math.max(1, (maxRows * iconSize) + ((maxRows - 1) * spacing))
    Frame:SetHeight(height)

    OrbitEngine.Frame:RestorePosition(Frame, self, 1)
    self:UpdateVisibility()
end

-- [ UPDATE LAYOUT ]---------------------------------------------------------------------------------
-- Called by Anchor:SyncChildren when parent frame dimensions change
function Mixin:UpdateLayout()
    local Frame = self._agFrame
    if not Frame then return end

    local iconsPerRow = self:GetSetting(1, "IconsPerRow") or 5
    local maxRows = self:GetSetting(1, "MaxRows") or 2
    local spacing = self:GetSetting(1, "Spacing") or 2
    local iconSize = CalculateIconSize(Frame:GetWidth(), iconsPerRow, spacing)
    Frame.iconSize = iconSize

    local height = math.max(1, (maxRows * iconSize) + ((maxRows - 1) * spacing))
    Frame:SetHeight(height)

    if Orbit:IsEditMode() then self:ShowPreviewAuras() else self:UpdateAuras() end
end
