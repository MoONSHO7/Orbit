local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local Layout = Engine.Layout

-- [ COLOR PICKER WIDGET ] ------------------------------------------------------------------------------------
-- Uses LibOrbitColorPicker for consistent Orbit UI styling
-- 3-Column Layout: [Label: Fixed, Left] [Control: Dynamic, Fill] [Value: Fixed, Right (reserved)]

local SWATCH_HEIGHT = 20
local WIDGET_SIZE = { width = 260, height = 32 }

function Layout:CreateColorPicker(parent, label, initialColor, callback)
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

        frame.Swatch.Color = frame.Swatch:CreateTexture(nil, "OVERLAY")
        frame.Swatch.Color:SetPoint("TOPLEFT", 1, -1)
        frame.Swatch.Color:SetPoint("BOTTOMRIGHT", -1, 1)
        frame.Swatch.Color:SetColorTexture(1, 1, 1, 1)

        frame.Swatch:SetScript("OnClick", function()
            local lib = LibStub and LibStub("LibOrbitColorPicker-1.0", true)
            if not lib then return end
            
            lib:Open({
                initialData = { r = frame.r, g = frame.g, b = frame.b, a = frame.a },
                hasOpacity = true,
                callback = function(result)
                    if not result then
                        if callback then callback(nil) end
                        return
                    end
                    local pin = result.pins and result.pins[1]
                    if pin and pin.color then
                        frame.UpdateColor(pin.color.r, pin.color.g, pin.color.b, pin.color.a)
                    end
                end,
            })
        end)
    end

    frame:SetParent(parent)

    local c = initialColor or { r = 1, g = 1, b = 1, a = 1 }
    frame.r, frame.g, frame.b, frame.a = c.r or 1, c.g or 1, c.b or 1, c.a or 1
    frame.oldR, frame.oldG, frame.oldB, frame.oldA = frame.r, frame.g, frame.b, frame.a
    frame.Swatch.Color:SetVertexColor(frame.r, frame.g, frame.b, frame.a)

    frame.UpdateColor = function(r, g, b, a)
        frame.r, frame.g, frame.b, frame.a = r, g, b, a
        frame.Swatch.Color:SetVertexColor(r, g, b, a)
        if callback then callback({ r = r, g = g, b = b, a = a }) end
    end

    local C = Constants
    frame.Label:SetText(label)
    frame.Label:SetWidth(C.Widget.LabelWidth)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:ClearAllPoints()
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)

    frame.Swatch:ClearAllPoints()
    frame.Swatch:SetPoint("LEFT", frame.Label, "RIGHT", C.Widget.LabelGap, 0)
    frame.Swatch:SetPoint("RIGHT", frame, "RIGHT", -C.Widget.ValueWidth, 0)
    frame.Swatch:SetHeight(SWATCH_HEIGHT)

    frame:SetSize(WIDGET_SIZE.width, WIDGET_SIZE.height)
    return frame
end
