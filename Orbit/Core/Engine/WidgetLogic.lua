-- [ ORBIT WIDGET LOGIC ]----------------------------------------------------------------------------
-- Provides reusable helper functions for building settings UIs.

local _, Orbit = ...
local Engine = Orbit.Engine
---@class OrbitWidgetLogic
Engine.WidgetLogic = {}
local WL = Engine.WidgetLogic

-- [ SHARED HELPERS ]--------------------------------------------------------------------------------

local function Get(plugin, index, key, default)
    local val = plugin:GetSetting(index, key)
    if val == nil then return default end
    return val
end

-- [ CLASS COLOR RESOLUTION ]------------------------------------------------------------------------
local function GetCurrentClassColor()
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class]
    if color then return { r = color.r, g = color.g, b = color.b, a = 1 } end
    return { r = 1, g = 1, b = 1, a = 1 }
end

local function ResolveClassColorPin(pin)
    if pin.type == "class" then return GetCurrentClassColor() end
    return pin.color
end

-- [ REACTION COLOR UTILITIES ]----------------------------------------------------------------------
local REACTION_HOSTILE_MAX = 2
local REACTION_NEUTRAL_MAX = 4

local REACTION_COLORS = {
    HOSTILE = { r = 1, g = 0.1, b = 0.1, a = 1 },
    NEUTRAL = { r = 1, g = 0.8, b = 0, a = 1 },
    FRIENDLY = { r = 0.1, g = 1, b = 0.1, a = 1 },
}

function WL:GetReactionColor(reaction)
    if reaction <= REACTION_HOSTILE_MAX then return REACTION_COLORS.HOSTILE end
    if reaction <= REACTION_NEUTRAL_MAX then return REACTION_COLORS.NEUTRAL end
    return REACTION_COLORS.FRIENDLY
end

function WL:CurveHasClassPin(curveData)
    if not curveData or not curveData.pins then return false end
    for _, pin in ipairs(curveData.pins) do
        if pin.type == "class" then return true end
    end
    return false
end

-- [ COLOR CURVE UTILITIES ]-------------------------------------------------------------------------
-- Hybrid Architecture:
--   Storage:       pins format { pins = [{ position, color, type? }] } (serializable to SavedVariables)
--   Native APIs:   ToNativeColorCurve() for UnitHealthPercent, GetAuraDispelTypeColor, etc.
--   Lua Sampling:  SampleColorCurve() for cast bars, power bars, resources (no native sampling API)
-- Shared helper: returns sorted copy of pins, cached on curveData._sorted
local function GetSortedPins(curveData)
    if curveData._sorted then return curveData._sorted end
    local sorted = {}
    for _, p in ipairs(curveData.pins) do sorted[#sorted + 1] = p end
    table.sort(sorted, function(a, b) return a.position < b.position end)
    curveData._sorted = sorted
    return sorted
end

-- Sample color from curve at position (0-1), returns { r, g, b, a } or nil
function WL:SampleColorCurve(curveData, position)
    if not curveData or not curveData.pins or #curveData.pins == 0 then return nil end
    
    local pins = curveData.pins
    if #pins == 1 then return ResolveClassColorPin(pins[1]) end
    
    local sorted = GetSortedPins(curveData)
    position = math.max(0, math.min(1, position))
    
    -- Find surrounding pins
    local left, right = sorted[1], sorted[#sorted]
    for i = 1, #sorted - 1 do
        if sorted[i].position <= position and sorted[i + 1].position >= position then
            left, right = sorted[i], sorted[i + 1]
            break
        end
    end
    
    -- Resolve class color for both pins
    local leftColor = ResolveClassColorPin(left)
    local rightColor = ResolveClassColorPin(right)
    
    -- Linear interpolation
    local range = right.position - left.position
    local t = (range > 0) and ((position - left.position) / range) or 0
    
    return {
        r = leftColor.r + (rightColor.r - leftColor.r) * t,
        g = leftColor.g + (rightColor.g - leftColor.g) * t,
        b = leftColor.b + (rightColor.b - leftColor.b) * t,
        a = (leftColor.a or 1) + ((rightColor.a or 1) - (leftColor.a or 1)) * t,
    }
end

-- Get first color from curve (for static display when no progress available)
function WL:GetFirstColorFromCurve(curveData)
    if not curveData or not curveData.pins or #curveData.pins == 0 then return nil end
    local sorted = GetSortedPins(curveData)
    return ResolveClassColorPin(sorted[1])
end

-- Preview class colors for Edit Mode (when units don't exist)
local PREVIEW_PARTY_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "HUNTER", "ROGUE" }

-- Get class color for a specific unit, falls back to reaction color for NPCs
local function GetClassColorForUnit(unit)
    -- Handle Edit Mode preview for non-existent units
    if not unit or not UnitExists(unit) then
        -- Boss frames: Show hostile reaction color (red)
        if unit and (unit:match("^boss") or unit:match("^arena")) then
            return { r = 1, g = 0.1, b = 0.1, a = 1 }
        end
        -- Party frames: Show varied class colors for preview
        if unit and unit:match("^party") then
            local index = tonumber(unit:match("party(%d)")) or 1
            local classFile = PREVIEW_PARTY_CLASSES[(index - 1) % #PREVIEW_PARTY_CLASSES + 1]
            local classColor = RAID_CLASS_COLORS[classFile]
            if classColor then return { r = classColor.r, g = classColor.g, b = classColor.b, a = 1 } end
        end
        -- Player frame fallback: Use player's actual class
        if unit == "player" then
            local _, classFile = UnitClass("player")
            local classColor = classFile and RAID_CLASS_COLORS[classFile]
            if classColor then return { r = classColor.r, g = classColor.g, b = classColor.b, a = 1 } end
        end
        return { r = 1, g = 1, b = 1, a = 1 }
    end
    
    -- Only players get class color - NPCs always get reaction color
    if UnitIsPlayer(unit) then
        local _, classFile = UnitClass(unit)
        local classColor = classFile and RAID_CLASS_COLORS[classFile]
        if classColor then return { r = classColor.r, g = classColor.g, b = classColor.b, a = 1 } end
        return { r = 1, g = 1, b = 1, a = 1 }
    end
    
    -- NPCs: Use reaction color
    local reaction = UnitReaction(unit, "player")
    if reaction then return WL:GetReactionColor(reaction) end
    
    -- UnitReaction returned nil - use UnitIsFriend as fallback
    if UnitIsFriend("player", unit) then return REACTION_COLORS.FRIENDLY end
    if UnitCanAttack("player", unit) then return REACTION_COLORS.HOSTILE end
    return REACTION_COLORS.NEUTRAL
end

-- Resolve class color pin for a specific unit
local function ResolveClassColorPinForUnit(pin, unit)
    if pin.type == "class" then return GetClassColorForUnit(unit) end
    return pin.color
end

-- Get first color from curve using unit-specific class color (for health bars etc)
function WL:GetFirstColorFromCurveForUnit(curveData, unit)
    if not curveData or not curveData.pins or #curveData.pins == 0 then return nil end
    local sorted = GetSortedPins(curveData)
    return ResolveClassColorPinForUnit(sorted[1], unit)
end

-- Build native color curve with unit-specific class color resolution (for gradients with class pins)
function WL:ToNativeColorCurveForUnit(curveData, unit)
    if not curveData or not curveData.pins or #curveData.pins == 0 then return nil end
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then return nil end
    
    local curve = C_CurveUtil.CreateColorCurve()
    for _, pin in ipairs(curveData.pins) do
        local color = ResolveClassColorPinForUnit(pin, unit)
        curve:AddPoint(pin.position, CreateColor(color.r, color.g, color.b, color.a or 1))
    end
    return curve
end

-- [ NATIVE COLORCURVE CONVERSION ]------------------------------------------------------------------
local nativeCurveCache = setmetatable({}, { __mode = "v" })

-- Convert pins format to native C_CurveUtil.CreateColorCurve()
function WL:ToNativeColorCurve(curveData)
    if not curveData or not curveData.pins or #curveData.pins == 0 then return nil end
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then return nil end
    
    -- Note: Native curves with class color pins should NOT be cached since class can change
    local hasClassPin = WL:CurveHasClassPin(curveData)
    
    if not hasClassPin and nativeCurveCache[curveData] then
        return nativeCurveCache[curveData]
    end
    
    local curve = C_CurveUtil.CreateColorCurve()
    for _, pin in ipairs(curveData.pins) do
        local color = ResolveClassColorPin(pin)
        curve:AddPoint(pin.position, CreateColor(color.r, color.g, color.b, color.a or 1))
    end
    
    if not hasClassPin then nativeCurveCache[curveData] = curve end
    return curve
end

-- Convert native ColorCurve back to pins format (for color picker display)
function WL:FromNativeColorCurve(nativeCurve)
    if not nativeCurve or not nativeCurve.GetPoints then return nil end
    local pins = {}
    for _, point in ipairs(nativeCurve:GetPoints()) do
        local color = point.y
        table.insert(pins, {
            position = point.x,
            color = { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
        })
    end
    return { pins = pins }
end

-- Invalidate cache when curve data changes (call after setting changes)
function WL:InvalidateNativeCurveCache(curveData)
    if curveData then nativeCurveCache[curveData] = nil end
end
-- Standard onChange that calls ApplySettings and updates selection
-- Skip ApplySettings if frame is in canvas mode to prevent exiting
local function IsInCanvasMode(frame)
    -- Use centralized API if available, fallback to direct check
    if Engine.CanvasMode and Engine.CanvasMode.IsFrameInCanvasMode then
        return Engine.CanvasMode:IsFrameInCanvasMode(frame)
    end
    return frame and frame.orbitCanvasOriginal ~= nil
end

local function CreateDefaultOnChange(plugin, systemIndex, key, systemFrame)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)

        -- Skip ApplySettings if frame is in canvas mode (would reset position)
        local frame = systemFrame or plugin.Frame
        if not IsInCanvasMode(frame) then
            if plugin.ApplySettings then
                plugin:ApplySettings(systemFrame)
            end
        end

        -- Sync to anchored children if applicable
        if frame and Engine.Frame and Engine.Frame.SyncChildren then
            Engine.Frame:SyncChildren(frame)
        end

        -- Update selection overlay
        local frameToUpdate = systemFrame
        if not frameToUpdate or (Engine.Frame and not Engine.Frame.selections[frameToUpdate]) then
            frameToUpdate = plugin.Frame
        end
        if Engine.Frame and frameToUpdate then
            Engine.Frame:ForceUpdateSelection(frameToUpdate)
        end
    end
end

-- [ ANCHORING ]-------------------------------------------------------------------------------------

local function CreateAnchorOnChange(plugin, systemIndex, key, systemFrame, dialog)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)

        -- Skip ApplySettings if frame is in canvas mode
        local frame = systemFrame or plugin.Frame
        if not IsInCanvasMode(frame) then
            if plugin.ApplySettings then
                plugin:ApplySettings(systemFrame)
            end
        end

        if Engine.Frame then
            Engine.Frame:ForceUpdateSelection(systemFrame or plugin.Frame)
        end
        if key == "AnchorMode" and dialog and plugin.AddSettings then
            Engine.Layout:Reset(dialog)
            plugin:AddSettings(dialog, systemFrame, val)
        end
    end
end

function WL:AddAnchorSettings(plugin, schema, systemIndex, dialog, systemFrame, currentAnchor, anchorTargets)
    table.insert(schema.controls, {
        type = "dropdown",
        key = "AnchorMode",
        label = "Anchor",
        options = {
            { text = "Unlocked", value = 0 },
            { text = "Anchored Top", value = 1 },
            { text = "Anchored Bottom", value = 2 },
        },
        default = 0,
        onChange = CreateAnchorOnChange(plugin, systemIndex, "AnchorMode", systemFrame, dialog),
    })

    if currentAnchor and currentAnchor > 0 and anchorTargets then
        table.insert(schema.controls, {
            type = "dropdown",
            key = "AnchorTarget",
            label = "Anchor To",
            options = anchorTargets,
            default = anchorTargets[1] and anchorTargets[1].value,
            onChange = CreateAnchorOnChange(plugin, systemIndex, "AnchorTarget", systemFrame, nil),
        })

        local defaults = Engine.Constants.Settings.Padding
        table.insert(schema.controls, {
            type = "slider",
            key = "AnchorPadding",
            label = "Padding",
            min = defaults.Min,
            max = defaults.Max,
            step = defaults.Step,
            default = defaults.Default,
            onChange = CreateAnchorOnChange(plugin, systemIndex, "AnchorPadding", systemFrame, nil),
        })
    end
end

-- [ SIZE ]-------------------------------------------------------------------------------------------
local function CreateScaleOnChange(plugin, systemIndex, key, systemFrame)
    return function(val)
        -- [ Visual Center Scaling ] --
        -- Preserve frame's visual center position when scale changes
        -- Frame grows/shrinks in-place instead of shifting toward anchor point
        local oldScalePercent = plugin:GetSetting(systemIndex, key) or 100
        local newScalePercent = tonumber(val) or 100

        if oldScalePercent and newScalePercent and oldScalePercent ~= newScalePercent and newScalePercent > 0 then
            -- Get the actual frame
            local frame = systemFrame
            if frame and not frame.GetCenter and frame.systemFrame then
                frame = frame.systemFrame
            end
            if not frame or not frame.GetCenter then
                frame = plugin.frames and plugin.frames[systemIndex] or plugin.Frame
            end

            if frame and frame.GetPoint and frame.GetSize and not InCombatLockdown() then
                local point, relativeTo, relativePoint, x, y = frame:GetPoint()

                if point and x ~= nil and y ~= nil then
                    local relName = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent"
                    local width, height = frame:GetSize()

                    -- Scale ratio: how much are we changing
                    local ratio = oldScalePercent / newScalePercent

                    -- Calculate center offset from frame's anchor point
                    -- This tells us which direction the center is from the anchor
                    local dx, dy = 0, 0

                    if point:find("LEFT") then
                        dx = width / 2 -- Center is to the right of anchor
                    elseif point:find("RIGHT") then
                        dx = -width / 2 -- Center is to the left of anchor
                    end

                    if point:find("TOP") then
                        dy = -height / 2 -- Center is below anchor
                    elseif point:find("BOTTOM") then
                        dy = height / 2 -- Center is above anchor
                    end

                    -- Formula: newOffset = (oldOffset + centerOffset) * ratio - centerOffset
                    -- Which simplifies to: newOffset = oldOffset * ratio + centerOffset * (ratio - 1)
                    local newX = x * ratio + dx * (ratio - 1)
                    local newY = y * ratio + dy * (ratio - 1)

                    local newPos = {
                        point = point,
                        relativeTo = relName,
                        relativePoint = relativePoint,
                        x = newX,
                        y = newY,
                    }

                    -- Save to settings
                    plugin:SetSetting(systemIndex, "Position", newPos)

                    -- Apply position IMMEDIATELY to the frame (before scale change)
                    frame:ClearAllPoints()
                    frame:SetPoint(point, relativeTo, relativePoint, newX, newY)
                end
            end
        end

        plugin:SetSetting(systemIndex, key, val)

        local frame = systemFrame

        -- Unwrap systemFrame if it's a wrapper
        if frame and not frame.SetScale and frame.systemFrame then
            frame = frame.systemFrame
        end

        if not frame or not frame.SetScale then
            frame = plugin.frames and plugin.frames[systemIndex] or plugin.Frame
        end

        if frame and frame.SetScale and not InCombatLockdown() then
            local scale = val / 100
            frame:SetScale(scale)
            if Engine.Frame and Engine.Frame.SyncChildren then
                Engine.Frame:SyncChildren(frame)
            end
        end

        if plugin.ApplySettings then
            plugin:ApplySettings(systemFrame)
        end

        local frameToUpdate = systemFrame
        if not frameToUpdate or (Engine.Frame and not Engine.Frame.selections[frameToUpdate]) then
            frameToUpdate = plugin.Frame
        end
        if Engine.Frame and frameToUpdate then
            Engine.Frame:ForceUpdateSelection(frameToUpdate)
        end
    end
end

function WL:AddSizeSettings(plugin, schema, systemIndex, systemFrame, widthParams, heightParams, scaleParams)
    local widthDefaults = Engine.Constants.Settings.Width
    if widthParams then
        local key = widthParams.key or "Width"
        table.insert(schema.controls, {
            type = "slider",
            key = key,
            label = widthParams.label or "Width",
            min = widthParams.min or widthDefaults.Min,
            max = widthParams.max or widthDefaults.Max,
            step = widthParams.step or widthDefaults.Step,
            default = widthParams.default or widthDefaults.Default,
            onChange = widthParams.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame),
        })
    end

    local heightDefaults = Engine.Constants.Settings.Height
    if heightParams then
        local key = heightParams.key or "Height"
        table.insert(schema.controls, {
            type = "slider",
            key = key,
            label = heightParams.label or "Height",
            min = heightParams.min or heightDefaults.Min,
            max = heightParams.max or heightDefaults.Max,
            step = heightParams.step or heightDefaults.Step,
            default = heightParams.default or heightDefaults.Default,
            onChange = heightParams.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame),
        })
    end

    local scaleDefaults = Engine.Constants.Settings.Scale
    if scaleParams then
        local key = scaleParams.key or "Scale"
        table.insert(schema.controls, {
            type = "slider",
            key = key,
            label = scaleParams.label or "Scale",
            min = scaleParams.min or scaleDefaults.Min,
            max = scaleParams.max or scaleDefaults.Max,
            step = scaleParams.step or scaleDefaults.Step,
            formatter = function(v)
                return v .. "%"
            end,
            default = scaleParams.default or scaleDefaults.Default,
            onChange = scaleParams.onChange or CreateScaleOnChange(plugin, systemIndex, key, systemFrame),
        })
    end
end

-- [ TEXT ]-------------------------------------------------------------------------------------------

local function CreateTextOnChange(plugin, systemIndex, key, systemFrame, dialog, currentAnchor, isToggle)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)

        -- Skip ApplySettings if frame is in canvas mode
        local frame = systemFrame or plugin.Frame
        if not IsInCanvasMode(frame) then
            if plugin.ApplySettings then
                plugin:ApplySettings(systemFrame)
            end
        end

        if Engine.Frame then
            Engine.Frame:ForceUpdateSelection(systemFrame or plugin.Frame)
        end
        if isToggle and dialog and plugin.AddSettings then
            Engine.Layout:Reset(dialog)
            plugin:AddSettings(dialog, systemFrame, currentAnchor)
        end
    end
end

function WL:AddTextSettings(plugin, schema, systemIndex, dialog, systemFrame, currentAnchor, showKeyOverride, sizeKeyOverride)
    local showKey = showKeyOverride or "ShowText"
    local sizeKey = sizeKeyOverride or "TextSize"

    table.insert(schema.controls, {
        type = "checkbox",
        key = showKey,
        label = "Show Text",
        default = true,
        onChange = CreateTextOnChange(plugin, systemIndex, showKey, systemFrame, dialog, currentAnchor, true),
    })

    local show = Get(plugin, systemIndex, showKey, true)
    if show ~= false then
        local defaults = Engine.Constants.Settings.TextSize
        table.insert(schema.controls, {
            type = "slider",
            key = sizeKey,
            label = "Text Size",
            min = defaults.Min,
            max = defaults.Max,
            step = defaults.Step,
            default = defaults.Default,
            onChange = CreateTextOnChange(plugin, systemIndex, sizeKey, systemFrame, nil, nil, false),
        })
    end
end

-- [ APPEARANCE ]------------------------------------------------------------------------------------

local function CreateBorderOnChange(plugin, systemIndex, key, systemFrame)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        if plugin.ApplySettings then
            plugin:ApplySettings(systemFrame)
        end
        if Engine.Frame then
            Engine.Frame:ForceUpdateSelection(systemFrame or plugin.Frame)
        end
    end
end

local function CreateSpacingOnChange(plugin, systemIndex, key, systemFrame)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        local frame = systemFrame or plugin.Frame
        if frame then
            frame.orbitSpacing = val
        end
        if plugin.ApplySettings then
            plugin:ApplySettings(systemFrame)
        end
        if Engine.Frame then
            Engine.Frame:ForceUpdateSelection(systemFrame or plugin.Frame)
        end
    end
end

local function CreateTextureOnChange(plugin, systemIndex, key, systemFrame, textureTarget)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        if textureTarget and not InCombatLockdown() then
            local LSM = LibStub("LibSharedMedia-3.0", true)
            if LSM then
                local texturePath = LSM:Fetch("statusbar", val) or val
                if textureTarget.SetStatusBarTexture then
                    textureTarget:SetStatusBarTexture(texturePath)
                elseif textureTarget.SetTexture then
                    textureTarget:SetTexture(texturePath)
                end
            end
        end
        if plugin.ApplySettings then
            plugin:ApplySettings(systemFrame)
        end
        if Engine.Frame then
            Engine.Frame:ForceUpdateSelection(systemFrame or plugin.Frame)
        end
    end
end

local function CreateColorOnChange(plugin, systemIndex, key, systemFrame, colorTarget)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        if colorTarget then
            if colorTarget.SetStatusBarColor then
                colorTarget:SetStatusBarColor(val.r, val.g, val.b)
            elseif colorTarget.SetVertexColor then
                colorTarget:SetVertexColor(val.r, val.g, val.b)
            end
        end
        if plugin.ApplySettings then
            plugin:ApplySettings(systemFrame)
        end
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
        if plugin.ApplySettings then
            plugin:ApplySettings(systemFrame)
        end
        if Engine.Frame then
            Engine.Frame:ForceUpdateSelection(systemFrame or plugin.Frame)
        end
    end
end

local function CreateOrientationOnChange(plugin, systemIndex, key, systemFrame, dialog, refreshOnChange)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)
        if plugin.ApplySettings then
            plugin:ApplySettings(systemFrame)
        end
        if Engine.Frame then
            Engine.Frame:ForceUpdateSelection(systemFrame or plugin.Frame)
        end
        if refreshOnChange and dialog and plugin.AddSettings then
            Engine.Layout:Reset(dialog)
            plugin:AddSettings(dialog, systemFrame)
        end
    end
end

function WL:AddBorderSpacingSettings(plugin, schema, systemIndex, systemFrame, borderParams, spacingParams)
    local borderDefaults = Engine.Constants.Settings.BorderSize
    if borderParams then
        local key = borderParams.key or "BorderSize"
        table.insert(schema.controls, {
            type = "slider",
            key = key,
            label = borderParams.label or "Border Size",
            min = borderParams.min or borderDefaults.Min,
            max = borderParams.max or borderDefaults.Max,
            step = borderParams.step or borderDefaults.Step,
            default = borderParams.default or borderDefaults.Default,
            onChange = borderParams.onChange or CreateBorderOnChange(plugin, systemIndex, key, systemFrame),
        })
    end

    local spacingDefaults = Engine.Constants.Settings.Spacing
    if spacingParams then
        local key = spacingParams.key or "Spacing"
        table.insert(schema.controls, {
            type = "slider",
            key = key,
            label = spacingParams.label or "Spacing",
            min = spacingParams.min or spacingDefaults.Min,
            max = spacingParams.max or spacingDefaults.Max,
            step = spacingParams.step or spacingDefaults.Step,
            default = spacingParams.default or spacingDefaults.Default,
            onChange = spacingParams.onChange or CreateSpacingOnChange(plugin, systemIndex, key, systemFrame),
        })
    end
end

function WL:AddTextureSettings(plugin, schema, systemIndex, systemFrame, keyOverride, previewColor, textureTarget)
    local key = keyOverride or "Texture"
    table.insert(schema.controls, {
        type = "texture",
        key = key,
        label = "Texture",
        default = Engine.Constants.Settings.Texture.Default,
        previewColor = previewColor,
        onChange = CreateTextureOnChange(plugin, systemIndex, key, systemFrame, textureTarget or systemFrame),
    })
end

function WL:AddFontSettings(plugin, schema, systemIndex, systemFrame, keyOverride, fontTarget)
    local key = keyOverride or "Font"
    table.insert(schema.controls, {
        type = "font",
        key = key,
        label = "Font",
        default = Engine.Constants.Settings.Font.Default,
        onChange = CreateFontOnChange(plugin, systemIndex, key, systemFrame, fontTarget),
    })
end

function WL:AddColorSettings(plugin, schema, systemIndex, systemFrame, colorParams, colorTarget)
    colorParams = colorParams or {}
    local key = colorParams.key or "Color"
    local label = colorParams.label or "Colour"
    local default = colorParams.default or { r = 1, g = 1, b = 1 }

    table.insert(schema.controls, {
        type = "color",
        key = key,
        label = label,
        default = default,
        onChange = CreateColorOnChange(plugin, systemIndex, key, systemFrame, colorTarget),
    })
end

local function CreateColorCurveOnChange(plugin, systemIndex, key, systemFrame)
    return function(curveData)
        plugin:SetSetting(systemIndex, key, curveData)
        if plugin.ApplySettings then plugin:ApplySettings(systemFrame) end
        if Engine.Frame then Engine.Frame:ForceUpdateSelection(systemFrame or plugin.Frame) end
    end
end

function WL:AddColorCurveSettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "ColorCurve"
    local label = params.label or "Colour Gradient"
    local default = params.default

    table.insert(schema.controls, {
        type = "colorcurve",
        key = key,
        label = label,
        default = default,
        singleColor = params.singleColor,
        tooltip = params.tooltip,
        onChange = CreateColorCurveOnChange(plugin, systemIndex, key, systemFrame),
    })
end

function WL:AddOrientationSettings(plugin, schema, systemIndex, dialog, systemFrame, params)
    params = params or {}
    local key = params.key or "Orientation"
    local options = params.options or {
        { text = "Horizontal", value = 0 },
        { text = "Vertical", value = 1 },
    }

    table.insert(schema.controls, {
        type = "dropdown",
        key = key,
        label = params.label or "Orientation",
        options = options,
        default = params.default or 0,
        onChange = params.onChange or CreateOrientationOnChange(plugin, systemIndex, key, systemFrame, dialog, params.refreshOnChange),
    })
end

-- [ VISIBILITY (Opacity, MouseOver, State) ]------------------------------------------------------

local function CreateOpacityOnChange(plugin, systemIndex, key, systemFrame)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)

        local realFrame = systemFrame
        if systemFrame and not systemFrame.SetAlpha then
            realFrame = plugin.frames and plugin.frames[systemIndex] or plugin.Frame
        end

        if realFrame and realFrame.SetAlpha and not InCombatLockdown() then
            local isEditMode = Orbit:IsEditMode()
            local minAlpha = val / 100

            if Orbit and Orbit.Animation then
                Orbit.Animation:ApplyHoverFade(realFrame, minAlpha, 1, isEditMode)
            else
                realFrame:SetAlpha(minAlpha)
            end
        end

        if plugin.ApplySettings then
            plugin:ApplySettings(systemFrame)
        end
        if Engine.Frame and realFrame then
            Engine.Frame:ForceUpdateSelection(realFrame)
        end
    end
end

local function CreateVisibilityOnChange(plugin, systemIndex, key, systemFrame)
    return function(val)
        plugin:SetSetting(systemIndex, key, val)

        local realFrame = systemFrame
        if systemFrame and not systemFrame.SetAlpha then
            realFrame = plugin.frames and plugin.frames[systemIndex] or plugin.Frame
        end

        if realFrame and Orbit and Orbit.Visibility then
            Orbit.Visibility:ApplyState(realFrame, val)
        end

        if plugin.ApplySettings then
            plugin:ApplySettings(systemFrame)
        end
        if Engine.Frame and realFrame then
            Engine.Frame:ForceUpdateSelection(realFrame)
        end
    end
end

function WL:AddOpacitySettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local defaults = Engine.Constants.Settings.Opacity
    local key = params.key or "Opacity"
    table.insert(schema.controls, {
        type = "slider",
        key = key,
        label = "Opacity",
        min = params.min or defaults.Min,
        max = params.max or defaults.Max,
        step = params.step or defaults.Step,
        formatter = function(v)
            return v .. "%"
        end,
        default = params.default or defaults.Default,
        onChange = params.onChange or CreateOpacityOnChange(plugin, systemIndex, key, systemFrame),
    })
end

function WL:AddVisibilitySettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "Visibility"
    local options = params.options
        or {
            { text = "Always Visible", value = 0 },
            { text = "In Combat", value = 1 },
            { text = "Out of Combat", value = 2 },
            { text = "Hidden", value = 3 },
        }
    table.insert(schema.controls, {
        type = "dropdown",
        key = key,
        label = params.label or "Visibility",
        options = options,
        default = params.default or 0,
        onChange = params.onChange or CreateVisibilityOnChange(plugin, systemIndex, key, systemFrame),
    })
end

-- [ COOLDOWN-SPECIFIC ]---------------------------------------------------------------------------

function WL:AddAspectRatioSettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "aspectRatio"
    local options = params.options
        or {
            { text = "Square (1:1)", value = "1:1" },
            { text = "Landscape (16:9)", value = "16:9" },
            { text = "Landscape (4:3)", value = "4:3" },
            { text = "Ultrawide (21:9)", value = "21:9" },
            { text = "Portrait (9:16)", value = "9:16" },
            { text = "Portrait (3:4)", value = "3:4" },
        }

    table.insert(schema.controls, {
        type = "dropdown",
        key = key,
        label = params.label or "Icon Aspect Ratio",
        options = options,
        default = params.default or "1:1",
        onChange = params.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame),
    })
end

function WL:AddIconSizeSettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "IconSize"
    table.insert(schema.controls, {
        type = "slider",
        key = key,
        label = params.label or "Icon Size",
        min = params.min or 20,
        max = params.max or 80,
        step = params.step or 1,
        default = params.default or 40,
        onChange = params.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame),
    })
end

function WL:AddIconZoomSettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "Zoom"
    table.insert(schema.controls, {
        type = "slider",
        key = key,
        label = params.label or "Icon Zoom",
        min = params.min or 0,
        max = params.max or 50,
        step = params.step or 1,
        formatter = function(v)
            return v .. "%"
        end,
        default = params.default or 0,
        onChange = params.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame),
    })
end

function WL:AddIconPaddingSettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "IconPadding"
    table.insert(schema.controls, {
        type = "slider",
        key = key,
        label = params.label or "Icon Padding",
        min = params.min or -1,
        max = params.max or 10,
        step = params.step or 1,
        default = params.default or 2,
        onChange = params.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame),
    })
end

function WL:AddColumnsSettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}
    local key = params.key or "IconLimit"
    table.insert(schema.controls, {
        type = "slider",
        key = key,
        label = params.label or "# Columns",
        min = params.min or 1,
        max = params.max or 20,
        step = params.step or 1,
        default = params.default or 10,
        onChange = params.onChange or CreateDefaultOnChange(plugin, systemIndex, key, systemFrame),
    })
end

function WL:AddCooldownDisplaySettings(plugin, schema, systemIndex, systemFrame, params)
    params = params or {}

    if params.showTimer ~= false then
        local timerKey = params.timerKey or "ShowTimer"
        table.insert(schema.controls, {
            type = "checkbox",
            key = timerKey,
            label = params.timerLabel or "Show Timer",
            default = params.timerDefault ~= false,
            onChange = params.timerOnChange or CreateDefaultOnChange(plugin, systemIndex, timerKey, systemFrame),
        })
    end

    if params.showTooltips ~= false then
        local tooltipKey = params.tooltipKey or "ShowTooltips"
        table.insert(schema.controls, {
            type = "checkbox",
            key = tooltipKey,
            label = params.tooltipLabel or "Show Tooltips",
            default = params.tooltipDefault ~= false,
            onChange = params.tooltipOnChange or CreateDefaultOnChange(plugin, systemIndex, tooltipKey, systemFrame),
        })
    end
end

-- [ SETTINGS TABS ]---------------------------------------------------------------------------------

function WL:SetTabRefreshCallback(dialog, plugin, systemFrame)
    dialog.orbitTabCallback = function()
        Engine.Layout:Reset(dialog)
        plugin:AddSettings(dialog, systemFrame)
    end
end

function WL:AddSettingsTabs(schema, dialog, tabsList, defaultTab)
    dialog.orbitCurrentTab = dialog.orbitCurrentTab or defaultTab
    table.insert(schema.controls, {
        type = "tabs",
        tabs = tabsList,
        activeTab = dialog.orbitCurrentTab,
        onTabSelected = function(tabName)
            dialog.orbitCurrentTab = tabName
            if dialog.orbitTabCallback then dialog.orbitTabCallback() end
        end,
    })
    return dialog.orbitCurrentTab
end
