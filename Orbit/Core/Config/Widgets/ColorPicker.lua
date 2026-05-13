local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local Layout = Engine.Layout

-- [ COLOR PICKER WIDGET ] ---------------------------------------------------------------------------
-- Uses LibOrbitColorPicker for consistent Orbit UI styling
-- 3-Column Layout: [Label: Fixed, Left] [Control: Dynamic, Fill] [Value: Fixed, Right (reserved)]

local SWATCH_HEIGHT = 20
local COMPACT_SWATCH_SIZE = 21
local COMPACT_ROW_HEIGHT = 26
local WIDGET_SIZE = { width = 260, height = 32 }
local CHECKERBOARD = "Interface\\AddOns\\Orbit\\Core\\assets\\Other\\Orbit_Checkerboard.tga"

function Layout:CreateColorPicker(parent, label, initialColor, callback, opts)
    if not self.colorPool then self.colorPool = {} end
    local frame = table.remove(self.colorPool)

    if not frame then
        frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        frame.OrbitType = "Color"

        frame.Label = frame:CreateFontString(nil, "ARTWORK", Orbit.Constants.UI.LabelFont)

        frame.Swatch = CreateFrame("Button", nil, frame, "BackdropTemplate")
        frame.Swatch:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        frame.Swatch:SetBackdropBorderColor(0, 0, 0, 1)
        frame.Swatch:SetBackdropColor(0, 0, 0, 0)

        frame.Swatch.Checkerboard = frame.Swatch:CreateTexture(nil, "BACKGROUND")
        frame.Swatch.Checkerboard:SetPoint("TOPLEFT", 1, -1)
        frame.Swatch.Checkerboard:SetPoint("BOTTOMRIGHT", -1, 1)
        frame.Swatch.Checkerboard:SetTexture(CHECKERBOARD, "REPEAT", "REPEAT")
        frame.Swatch.Checkerboard:SetHorizTile(true)
        frame.Swatch.Checkerboard:SetVertTile(true)

        frame.Swatch.Color = frame.Swatch:CreateTexture(nil, "ARTWORK")
        frame.Swatch.Color:SetPoint("TOPLEFT", 1, -1)
        frame.Swatch.Color:SetPoint("BOTTOMRIGHT", -1, 1)
        frame.Swatch.Color:SetColorTexture(1, 1, 1, 1)

        frame.Swatch:SetScript("OnClick", function()
            local lib = LibStub and LibStub("LibOrbitColorPicker-1.0", true)
            if not lib then return end
            
            if Orbit.db and Orbit.db.AccountSettings and not Orbit.db.AccountSettings.RecentColors then
                Orbit.db.AccountSettings.RecentColors = {}
            end

            local initData = { r = frame.r, g = frame.g, b = frame.b, a = frame.a }
            if frame.pinType then initData.type = frame.pinType end
            lib:Open({
                initialData = initData,
                hasOpacity = true,
                forceSingleColor = true,
                recentColorsDb = Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.RecentColors,
                onOpen = function(picker)
                    local as = Orbit.db and Orbit.db.AccountSettings
                    if as and not as.ColorPickerTourComplete then
                        as.ColorPickerTourComplete = true
                        C_Timer.After(0.1, function() if picker:IsOpen() then picker:StartTour() end end)
                    end
                end,
                callback = function(result, wasCancelled)
                    if wasCancelled or not result then return end
                    local pin = result.pins and result.pins[1]
                    if pin and pin.color then
                        frame.UpdateColor(pin.color.r, pin.color.g, pin.color.b, pin.color.a, pin.type)
                    else
                        if opts.allowClear then
                            frame.ClearColor()
                        end
                    end
                end,
            })
        end)
    end

    frame:SetParent(parent)

    local c = initialColor or { r = 1, g = 1, b = 1, a = 1 }
    frame.pinType = c.type
    if c.type == "class" and Engine.ClassColor then
        local resolved = Engine.ClassColor:GetCurrentClassColor()
        frame.r, frame.g, frame.b, frame.a = resolved.r, resolved.g, resolved.b, c.a or 1
    else
        frame.r, frame.g, frame.b, frame.a = c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end
    frame.oldR, frame.oldG, frame.oldB, frame.oldA = frame.r, frame.g, frame.b, frame.a
    frame.Swatch.Color:SetVertexColor(frame.r, frame.g, frame.b, frame.a)

    frame.UpdateColor = function(r, g, b, a, pinType)
        frame.r, frame.g, frame.b, frame.a = r, g, b, a
        frame.pinType = pinType
        frame.Swatch.Color:SetVertexColor(r, g, b, a)
        local result = { r = r, g = g, b = b, a = a }
        if pinType then result.type = pinType end
        if callback then callback(result) end
    end

    frame.ClearColor = function()
        if callback then callback(nil) end
    end

    frame.SetColorQuiet = function(_, r, g, b, a)
        frame.r, frame.g, frame.b, frame.a = r, g, b, a
        frame.Swatch.Color:SetVertexColor(r, g, b, a)
    end

    local C = Constants
    opts = opts or {}

    frame.Label:SetText(label)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:ClearAllPoints()
    frame.Swatch:ClearAllPoints()

    if opts.compact then
        frame:SetHeight(COMPACT_ROW_HEIGHT)
        frame.Swatch:SetSize(COMPACT_SWATCH_SIZE, COMPACT_SWATCH_SIZE)
        frame.Swatch:SetPoint("LEFT", frame, "LEFT", 0, 0)

        frame.Label:SetWidth(0)
        frame.Label:SetPoint("LEFT", frame.Swatch, "RIGHT", 4, 0)

        frame:SetSize(Engine.Pixel:Snap(COMPACT_SWATCH_SIZE + 4 + frame.Label:GetStringWidth(), frame:GetEffectiveScale()), COMPACT_ROW_HEIGHT)
    else
        -- Standard 3-column layout
        frame.Label:SetWidth(C.Widget.LabelWidth)
        frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)

        frame.Swatch:SetPoint("LEFT", frame.Label, "RIGHT", C.Widget.LabelGap, 0)
        frame.Swatch:SetPoint("RIGHT", frame, "RIGHT", -C.Widget.ValueWidth, 0)
        frame.Swatch:SetHeight(SWATCH_HEIGHT)

        frame:SetSize(WIDGET_SIZE.width, WIDGET_SIZE.height)
    end

    return frame
end
