-- [ ICON CANVAS PREVIEW ]--------------------------------------------------------------------------
-- Shared builder for single-icon Canvas Mode previews.
-- Used by Action Bars, Cooldown Manager (Essential/Utility/BuffIcon), and Tracked Abilities.

local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local AnchorToCenter = OrbitEngine.PositionUtils.AnchorToCenter
local OverrideUtils = OrbitEngine.OverrideUtils

local IconCanvasPreview = {}
OrbitEngine.IconCanvasPreview = IconCanvasPreview

-- [ CREATE ]------------------------------------------------------------------------------------
-- Creates a BackdropTemplate preview frame with icon texture and border.
-- sourceFrame=anchor, parent=viewport parent, width/height=raw icon dimensions, iconTexture=texture path
function IconCanvasPreview:Create(sourceFrame, parent, width, height, iconTexture)
    local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    preview:SetSize(width, height)
    preview.sourceFrame = sourceFrame

    local borderSize = Orbit.db.GlobalSettings.BorderSize
    local borderPixels = OrbitEngine.Pixel:Multiple(borderSize)
    preview.sourceWidth = width
    preview.sourceHeight = height
    preview.borderInset = borderPixels
    preview.previewScale = 1
    preview.components = {}

    local icon = preview:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(iconTexture)

    local backdrop = { bgFile = "Interface\\BUTTONS\\WHITE8x8", insets = { left = 0, right = 0, top = 0, bottom = 0 } }
    preview:SetBackdrop(backdrop)
    preview:SetBackdropColor(0, 0, 0, 0)
    Orbit.Skin:SkinBorder(preview, preview, borderSize, nil, true)

    return preview
end

-- [ ATTACH TEXT COMPONENTS ]----------------------------------------------------------------
-- Attaches FontStrings and CreateDraggableComponent wrappers onto a preview frame.
function IconCanvasPreview:AttachTextComponents(preview, textComponents, savedPositions, fontPath)
    local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent
    local halfW, halfH = preview.sourceWidth / 2, preview.sourceHeight / 2

    for _, def in ipairs(textComponents) do
        local fs = preview:CreateFontString(nil, "OVERLAY", nil, 7)
        fs:SetFont(fontPath, 12, Orbit.Skin:GetFontOutline())
        Orbit.Skin:ApplyFontShadow(fs)
        fs:SetText(def.preview)
        fs:SetTextColor(1, 1, 1, 1)
        fs:SetPoint("CENTER", preview, "CENTER", 0, 0)

        local saved = savedPositions[def.key] or {}
        local defaultJustifyH = def.anchorX == "LEFT" and "LEFT" or def.anchorX == "RIGHT" and "RIGHT" or "CENTER"
        local data = {
            anchorX = saved.anchorX or def.anchorX,
            anchorY = saved.anchorY or def.anchorY,
            offsetX = saved.offsetX or def.offsetX,
            offsetY = saved.offsetY or def.offsetY,
            justifyH = saved.justifyH or defaultJustifyH,
            overrides = saved.overrides,
        }

        local startX, startY = saved.posX or 0, saved.posY or 0
        if not saved.posX or not saved.posY then
            local cx, cy = AnchorToCenter(data.anchorX, data.anchorY, data.offsetX, data.offsetY, halfW, halfH)
            if not saved.posX then startX = cx end
            if not saved.posY then startY = cy end
        end

        -- Re-hydrate saved overrides onto the preview FontString
        if saved.overrides and OverrideUtils then
            OverrideUtils.ApplyOverrides(fs, saved.overrides, { fontSize = 12, fontPath = fontPath })
        end

        if CreateDraggableComponent then
            local comp = CreateDraggableComponent(preview, def.key, fs, startX, startY, data)
            if comp then
                comp:SetFrameLevel(preview:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
                preview.components[def.key] = comp
                fs:Hide()
            end
        else
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", preview, "CENTER", startX, startY)
        end
    end
end
