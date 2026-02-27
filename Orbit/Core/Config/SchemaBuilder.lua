-- [ ORBIT SCHEMA BUILDER ]--------------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine
local tinsert = table.insert
local InCombatLockdown = InCombatLockdown
Engine.SchemaBuilder = {}
local SB = Engine.SchemaBuilder

-- [ SHARED HELPERS ]--------------------------------------------------------------------------------
local function Get(plugin, index, key, default)
    local val = plugin:GetSetting(index, key)
    if val == nil then return default end
    return val
end

local function IsInCanvasMode(frame)
    if Engine.CanvasMode and Engine.CanvasMode.IsFrameInCanvasMode then return Engine.CanvasMode:IsFrameInCanvasMode(frame) end
    return frame and frame.orbitCanvasOriginal ~= nil
end

local function ApplyIfNotCanvas(plugin, systemFrame)
    local frame = systemFrame or plugin.Frame
    if not IsInCanvasMode(frame) and plugin.ApplySettings then plugin:ApplySettings(systemFrame) end
    return frame
end

local function SyncAndUpdate(plugin, systemFrame, frame)
    if frame and Engine.Frame and Engine.Frame.SyncChildren then Engine.Frame:SyncChildren(frame) end
    local target = systemFrame
    if not target or (Engine.Frame and not Engine.Frame.selections[target]) then target = plugin.Frame end
    if Engine.Frame and target then Engine.Frame:ForceUpdateSelection(target) end
end

local function ApplyAndSync(plugin, systemFrame, realFrame)
    local frame = ApplyIfNotCanvas(plugin, systemFrame)
    SyncAndUpdate(plugin, systemFrame, realFrame or frame)
end

local function CreateDefaultOnChange(plugin, systemIndex, key, systemFrame)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        local frame = ApplyIfNotCanvas(plugin, systemFrame)
        SyncAndUpdate(plugin, systemFrame, frame)
    end
end

-- [ ANCHOR ]----------------------------------------------------------------------------------------
local function CreateAnchorOnChange(plugin, systemIndex, key, systemFrame, dialog)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        ApplyIfNotCanvas(plugin, systemFrame)
        if Engine.Frame then Engine.Frame:ForceUpdateSelection(systemFrame or plugin.Frame) end
        if key == "AnchorMode" and dialog and plugin.AddSettings then
            Engine.Layout:Reset(dialog)
            plugin:AddSettings(dialog, systemFrame, val)
        end
    end
end

function SB:AddAnchorSettings(plugin, schema, systemIndex, dialog, systemFrame, currentAnchor, anchorTargets)
    tinsert(schema.controls, {
        type = "dropdown", key = "AnchorMode", label = "Anchor",
        options = { { text = "Unlocked", value = 0 }, { text = "Anchored Top", value = 1 }, { text = "Anchored Bottom", value = 2 } },
        default = 0,
        onChange = CreateAnchorOnChange(plugin, systemIndex, "AnchorMode", systemFrame, dialog),
    })
    if currentAnchor and currentAnchor > 0 and anchorTargets then
        tinsert(schema.controls, {
            type = "dropdown", key = "AnchorTarget", label = "Anchor To",
            options = anchorTargets, default = anchorTargets[1] and anchorTargets[1].value,
            onChange = CreateAnchorOnChange(plugin, systemIndex, "AnchorTarget", systemFrame, nil),
        })
        local defaults = Engine.Constants.Settings.Padding
        tinsert(schema.controls, {
            type = "slider", key = "AnchorPadding", label = "Padding",
            min = defaults.Min, max = defaults.Max, step = defaults.Step, default = defaults.Default,
            onChange = CreateAnchorOnChange(plugin, systemIndex, "AnchorPadding", systemFrame, nil),
        })
    end
end

-- [ SIZE ]-------------------------------------------------------------------------------------------
local function CreateScaleOnChange(plugin, systemIndex, key, systemFrame)
    return function(val)
        local oldScalePercent = plugin:GetSetting(systemIndex, key) or 100
        local newScalePercent = tonumber(val) or 100
        if oldScalePercent and newScalePercent and oldScalePercent ~= newScalePercent and newScalePercent > 0 then
            local frame = systemFrame
            if frame and not frame.GetCenter and frame.systemFrame then frame = frame.systemFrame end
            if not frame or not frame.GetCenter then frame = plugin.frames and plugin.frames[systemIndex] or plugin.Frame end
            if frame and frame.GetPoint and frame.GetSize and not InCombatLockdown() then
                local point, relativeTo, relativePoint, x, y = frame:GetPoint()
                if point and x ~= nil and y ~= nil then
                    local relName = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent"
                    local width, height = frame:GetSize()
                    local ratio = oldScalePercent / newScalePercent
                    local dx, dy = 0, 0
                    if point:find("LEFT") then dx = width / 2 elseif point:find("RIGHT") then dx = -width / 2 end
                    if point:find("TOP") then dy = -height / 2 elseif point:find("BOTTOM") then dy = height / 2 end
                    local newX = x * ratio + dx * (ratio - 1)
                    local newY = y * ratio + dy * (ratio - 1)
                    plugin:SetSetting(systemIndex, "Position", { point = point, relativeTo = relName, relativePoint = relativePoint, x = newX, y = newY })
                    frame:ClearAllPoints()
                    frame:SetPoint(point, relativeTo, relativePoint, newX, newY)
                end
            end
        end
        plugin:SetSetting(systemIndex, key, val)
        local frame = systemFrame
        if frame and not frame.SetScale and frame.systemFrame then frame = frame.systemFrame end
        if not frame or not frame.SetScale then frame = plugin.frames and plugin.frames[systemIndex] or plugin.Frame end
        if frame and frame.SetScale and not InCombatLockdown() then
            frame:SetScale(val / 100)
            if Engine.Frame and Engine.Frame.SyncChildren then Engine.Frame:SyncChildren(frame) end
        end
        if plugin.ApplySettings then plugin:ApplySettings(systemFrame) end
        local frameToUpdate = systemFrame
        if not frameToUpdate or (Engine.Frame and not Engine.Frame.selections[frameToUpdate]) then frameToUpdate = plugin.Frame end
        if Engine.Frame and frameToUpdate then Engine.Frame:ForceUpdateSelection(frameToUpdate) end
    end
end

function SB:AddSizeSettings(plugin, schema, systemIndex, systemFrame, widthParams, heightParams, scaleParams)
    local widthDefaults = Engine.Constants.Settings.Width
    if widthParams then
        local key = widthParams.key or "Width"
        tinsert(schema.controls, { type = "slider", key = key, label = widthParams.label or "Width",
            min = widthParams.min or widthDefaults.Min, max = widthParams.max or widthDefaults.Max,
            step = widthParams.step or widthDefaults.Step, default = widthParams.default or widthDefaults.Default,
            onChange = widthParams.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame) })
    end
    local heightDefaults = Engine.Constants.Settings.Height
    if heightParams then
        local key = heightParams.key or "Height"
        tinsert(schema.controls, { type = "slider", key = key, label = heightParams.label or "Height",
            min = heightParams.min or heightDefaults.Min, max = heightParams.max or heightDefaults.Max,
            step = heightParams.step or heightDefaults.Step, default = heightParams.default or heightDefaults.Default,
            onChange = heightParams.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame) })
    end
    local scaleDefaults = Engine.Constants.Settings.Scale
    if scaleParams then
        local key = scaleParams.key or "Scale"
        tinsert(schema.controls, { type = "slider", key = key, label = scaleParams.label or "Scale",
            min = scaleParams.min or scaleDefaults.Min, max = scaleParams.max or scaleDefaults.Max,
            step = scaleParams.step or scaleDefaults.Step, formatter = function(v) return v .. "%" end,
            default = scaleParams.default or scaleDefaults.Default,
            onChange = scaleParams.onChange or CreateScaleOnChange(plugin, systemIndex, key, systemFrame) })
    end
end

-- [ TEXT ]-------------------------------------------------------------------------------------------
local function CreateTextOnChange(plugin, systemIndex, key, systemFrame, dialog, currentAnchor, isToggle)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        ApplyIfNotCanvas(plugin, systemFrame)
        if Engine.Frame then Engine.Frame:ForceUpdateSelection(systemFrame or plugin.Frame) end
        if isToggle and dialog and plugin.AddSettings then Engine.Layout:Reset(dialog); plugin:AddSettings(dialog, systemFrame, currentAnchor) end
    end
end

function SB:AddTextSettings(plugin, schema, systemIndex, dialog, systemFrame, currentAnchor, showKeyOverride, sizeKeyOverride)
    local showKey = showKeyOverride or "ShowText"
    local sizeKey = sizeKeyOverride or "TextSize"
    tinsert(schema.controls, { type = "checkbox", key = showKey, label = "Show Text", default = true,
        onChange = CreateTextOnChange(plugin, systemIndex, showKey, systemFrame, dialog, currentAnchor, true) })
    local show = Get(plugin, systemIndex, showKey, true)
    if show ~= false then
        local defaults = Engine.Constants.Settings.TextSize
        tinsert(schema.controls, { type = "slider", key = sizeKey, label = "Text Size",
            min = defaults.Min, max = defaults.Max, step = defaults.Step, default = defaults.Default,
            onChange = CreateTextOnChange(plugin, systemIndex, sizeKey, systemFrame, nil, nil, false) })
    end
end

-- [ APPEARANCE ]------------------------------------------------------------------------------------
local function CreateBorderOnChange(plugin, systemIndex, key, systemFrame)
    return function(val) plugin:SetSetting(systemIndex, key, val); ApplyAndSync(plugin, systemFrame) end
end

local function CreateSpacingOnChange(plugin, systemIndex, key, systemFrame)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        local frame = systemFrame or plugin.Frame
        if frame then frame.orbitSpacing = val end
        ApplyAndSync(plugin, systemFrame)
    end
end

local function CreateTextureOnChange(plugin, systemIndex, key, systemFrame, textureTarget)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        if textureTarget and not InCombatLockdown() then
            local LSM = LibStub("LibSharedMedia-3.0", true)
            if LSM then
                local texturePath = LSM:Fetch("statusbar", val) or val
                if textureTarget.SetStatusBarTexture then textureTarget:SetStatusBarTexture(texturePath)
                elseif textureTarget.SetTexture then textureTarget:SetTexture(texturePath) end
            end
        end
        ApplyAndSync(plugin, systemFrame)
    end
end

local function CreateColorOnChange(plugin, systemIndex, key, systemFrame, colorTarget)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        if colorTarget then
            if colorTarget.SetStatusBarColor then colorTarget:SetStatusBarColor(val.r, val.g, val.b)
            elseif colorTarget.SetVertexColor then colorTarget:SetVertexColor(val.r, val.g, val.b) end
        end
        ApplyAndSync(plugin, systemFrame)
    end
end

local function CreateFontOnChange(plugin, systemIndex, key, systemFrame, fontTarget)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        if fontTarget and not InCombatLockdown() then
            local LSM = LibStub("LibSharedMedia-3.0", true)
            if LSM then
                local fontPath = LSM:Fetch("font", val)
                if fontPath and fontTarget.SetFont then
                    local _, size, flags = fontTarget:GetFont()
                    fontTarget:SetFont(fontPath, size or 12, flags or "")
                end
            end
        end
        ApplyAndSync(plugin, systemFrame)
    end
end

local function CreateOrientationOnChange(plugin, systemIndex, key, systemFrame, dialog, refreshOnChange)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        ApplyAndSync(plugin, systemFrame)
        if refreshOnChange and dialog and plugin.AddSettings then Engine.Layout:Reset(dialog); plugin:AddSettings(dialog, systemFrame) end
    end
end

function SB:AddBorderSpacingSettings(plugin, schema, systemIndex, systemFrame, borderParams, spacingParams)
    local borderDefaults = Engine.Constants.Settings.BorderSize
    if borderParams then
        local key = borderParams.key or "BorderSize"
        tinsert(schema.controls, { type = "slider", key = key, label = borderParams.label or "Border Size",
            min = borderParams.min or borderDefaults.Min, max = borderParams.max or borderDefaults.Max,
            step = borderParams.step or borderDefaults.Step, default = borderParams.default or borderDefaults.Default,
            onChange = borderParams.onChange or CreateBorderOnChange(plugin, systemIndex, key, systemFrame) })
    end
    local spacingDefaults = Engine.Constants.Settings.Spacing
    if spacingParams then
        local key = spacingParams.key or "Spacing"
        tinsert(schema.controls, { type = "slider", key = key, label = spacingParams.label or "Spacing",
            min = spacingParams.min or spacingDefaults.Min, max = spacingParams.max or spacingDefaults.Max,
            step = spacingParams.step or spacingDefaults.Step, default = spacingParams.default or spacingDefaults.Default,
            onChange = spacingParams.onChange or CreateSpacingOnChange(plugin, systemIndex, key, systemFrame) })
    end
end

function SB:AddTextureSettings(plugin, schema, systemIndex, systemFrame, keyOverride, previewColor, textureTarget)
    local key = keyOverride or "Texture"
    tinsert(schema.controls, { type = "texture", key = key, label = "Texture",
        default = Engine.Constants.Settings.Texture.Default, previewColor = previewColor,
        onChange = CreateTextureOnChange(plugin, systemIndex, key, systemFrame, textureTarget or systemFrame) })
end

function SB:AddFontSettings(plugin, schema, systemIndex, systemFrame, keyOverride, fontTarget)
    local key = keyOverride or "Font"
    tinsert(schema.controls, { type = "font", key = key, label = "Font",
        default = Engine.Constants.Settings.Font.Default,
        onChange = CreateFontOnChange(plugin, systemIndex, key, systemFrame, fontTarget) })
end

function SB:AddColorSettings(plugin, schema, systemIndex, systemFrame, colorParams, colorTarget)
    colorParams = colorParams or {}
    local key = colorParams.key or "Color"
    tinsert(schema.controls, { type = "color", key = key, label = colorParams.label or "Color",
        default = colorParams.default or { r = 1, g = 1, b = 1 },
        onChange = CreateColorOnChange(plugin, systemIndex, key, systemFrame, colorTarget) })
end

local function CreateColorCurveOnChange(plugin, systemIndex, key, systemFrame)
    return function(curveData) plugin:SetSetting(systemIndex, key, curveData); ApplyAndSync(plugin, systemFrame) end
end

function SB:AddColorCurveSettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "ColorCurve"
    tinsert(schema.controls, { type = "colorcurve", key = key, label = params.label or "Color Gradient",
        default = params.default, singleColor = params.singleColor, tooltip = params.tooltip,
        onChange = CreateColorCurveOnChange(plugin, systemIndex, key, systemFrame) })
end

function SB:AddOrientationSettings(plugin, schema, systemIndex, dialog, systemFrame, params)
    params = params or {}
    local key = params.key or "Orientation"
    local options = params.options or { { text = "Horizontal", value = 0 }, { text = "Vertical", value = 1 } }
    tinsert(schema.controls, { type = "dropdown", key = key, label = params.label or "Orientation",
        options = options, default = params.default or 0,
        onChange = params.onChange or CreateOrientationOnChange(plugin, systemIndex, key, systemFrame, dialog, params.refreshOnChange) })
end

-- [ VISIBILITY ]------------------------------------------------------------------------------------
local function CreateOpacityOnChange(plugin, systemIndex, key, systemFrame)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        local realFrame = systemFrame
        if systemFrame and not systemFrame.SetAlpha then realFrame = plugin.frames and plugin.frames[systemIndex] or plugin.Frame end
        if realFrame and realFrame.SetAlpha and not InCombatLockdown() then
            local minAlpha = val / 100
            if Orbit and Orbit.Animation then Orbit.Animation:ApplyHoverFade(realFrame, minAlpha, 1, Orbit:IsEditMode())
            else realFrame:SetAlpha(minAlpha) end
        end
        ApplyAndSync(plugin, systemFrame, realFrame)
    end
end

local function CreateVisibilityOnChange(plugin, systemIndex, key, systemFrame)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        local realFrame = systemFrame
        if systemFrame and not systemFrame.SetAlpha then realFrame = plugin.frames and plugin.frames[systemIndex] or plugin.Frame end
        if realFrame and Orbit and Orbit.Visibility then Orbit.Visibility:ApplyState(realFrame, val) end
        ApplyAndSync(plugin, systemFrame, realFrame)
    end
end

function SB:AddOpacitySettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local defaults = Engine.Constants.Settings.Opacity
    local key = params.key or "Opacity"
    tinsert(schema.controls, { type = "slider", key = key, label = "Opacity",
        min = params.min or defaults.Min, max = params.max or defaults.Max, step = params.step or defaults.Step,
        formatter = function(v) return v .. "%" end, default = params.default or defaults.Default,
        onChange = params.onChange or CreateOpacityOnChange(plugin, systemIndex, key, systemFrame) })
end

function SB:AddVisibilitySettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "Visibility"
    local options = params.options or {
        { text = "Always Visible", value = 0 }, { text = "In Combat", value = 1 },
        { text = "Out of Combat", value = 2 }, { text = "Hidden", value = 3 },
    }
    tinsert(schema.controls, { type = "dropdown", key = key, label = params.label or "Visibility",
        options = options, default = params.default or 0,
        onChange = params.onChange or CreateVisibilityOnChange(plugin, systemIndex, key, systemFrame) })
end

-- [ COOLDOWN-SPECIFIC ]-----------------------------------------------------------------------------
function SB:AddAspectRatioSettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "aspectRatio"
    local options = params.options or {
        { text = "Square (1:1)", value = "1:1" }, { text = "Landscape (16:9)", value = "16:9" },
        { text = "Landscape (4:3)", value = "4:3" }, { text = "Ultrawide (21:9)", value = "21:9" },
        { text = "Portrait (9:16)", value = "9:16" }, { text = "Portrait (3:4)", value = "3:4" },
    }
    tinsert(schema.controls, { type = "dropdown", key = key, label = params.label or "Icon Aspect Ratio",
        options = options, default = params.default or "1:1",
        onChange = params.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame) })
end

function SB:AddIconSizeSettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "IconSize"
    tinsert(schema.controls, { type = "slider", key = key, label = params.label or "Icon Size",
        min = params.min or 20, max = params.max or 80, step = params.step or 1, default = params.default or 40,
        onChange = params.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame) })
end

function SB:AddIconZoomSettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "Zoom"
    tinsert(schema.controls, { type = "slider", key = key, label = params.label or "Icon Zoom",
        min = params.min or 0, max = params.max or 50, step = params.step or 1,
        formatter = function(v) return v .. "%" end, default = params.default or 0,
        onChange = params.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame) })
end

function SB:AddIconPaddingSettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "IconPadding"
    tinsert(schema.controls, { type = "slider", key = key, label = params.label or "Icon Padding",
        min = params.min or -5, max = params.max or 15, step = params.step or 1, default = params.default or 2,
        onChange = params.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame) })
end

function SB:AddColumnsSettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "IconLimit"
    tinsert(schema.controls, { type = "slider", key = key, label = params.label or "# Columns",
        min = params.min or 1, max = params.max or 20, step = params.step or 1, default = params.default or 10,
        onChange = params.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame) })
end

function SB:AddCooldownDisplaySettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    if params.showTimer ~= false then
        local timerKey = params.timerKey or "ShowTimer"
        tinsert(schema.controls, { type = "checkbox", key = timerKey, label = params.timerLabel or "Show Timer",
            default = params.timerDefault ~= false,
            onChange = params.timerOnChange or CreateDefaultOnChange(plugin, systemIndex, timerKey, systemFrame) })
    end
    if params.showTooltips ~= false then
        local tooltipKey = params.tooltipKey or "ShowTooltips"
        tinsert(schema.controls, { type = "checkbox", key = tooltipKey, label = params.tooltipLabel or "Show Tooltips",
            default = params.tooltipDefault ~= false,
            onChange = params.tooltipOnChange or CreateDefaultOnChange(plugin, systemIndex, tooltipKey, systemFrame) })
    end
end

-- [ SETTINGS TABS ]---------------------------------------------------------------------------------
function SB:SetTabRefreshCallback(dialog, plugin, systemFrame)
    dialog.orbitTabCallback = function() Engine.Layout:Reset(dialog); plugin:AddSettings(dialog, systemFrame) end
end

function SB:AddSettingsTabs(schema, dialog, tabsList, defaultTab)
    dialog.orbitCurrentTab = dialog.orbitCurrentTab or defaultTab
    tinsert(schema.controls, {
        type = "tabs", tabs = tabsList, activeTab = dialog.orbitCurrentTab,
        onTabSelected = function(tabName) dialog.orbitCurrentTab = tabName; if dialog.orbitTabCallback then dialog.orbitTabCallback() end end,
    })
    return dialog.orbitCurrentTab
end

-- [ PLUGIN ON-CHANGE ]------------------------------------------------------------------------------
function SB:MakePluginOnChange(plugin, systemIndex, key, preApply)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        if preApply then preApply(val) end
        plugin:ApplySettings()
        if plugin.frames and plugin.frames[1] and plugin.frames[1].preview then plugin:SchedulePreviewUpdate() end
    end
end
