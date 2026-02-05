local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout

-- [ COLOR CURVE PICKER WIDGET ] ---------------------------------------------------------------------
-- Opens LibOrbitColorPicker for gradient editing
-- Stores curve data as serialized pins for persistence

local WIDGET_HEIGHT = 32
local GRADIENT_BAR_HEIGHT = 20

function Layout:CreateColorCurvePicker(parent, label, initialCurveData, callback)
    -- Pool retrieval
    if not self.colorCurvePool then self.colorCurvePool = {} end
    local frame = table.remove(self.colorCurvePool)

    if not frame then
        frame = CreateFrame("Button", nil, parent, "BackdropTemplate")
        frame.OrbitType = "ColorCurve"

        -- Label
        frame.Label = frame:CreateFontString(nil, "ARTWORK", Orbit.Constants.UI.LabelFont)

        -- Gradient preview bar (mini version of what's in the picker)
        frame.GradientBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.GradientBar:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        frame.GradientBar:SetBackdropBorderColor(0, 0, 0, 1)
        frame.GradientBar:SetBackdropColor(0.2, 0.2, 0.2, 1)

        -- Gradient texture (for simple preview)
        frame.GradientTexture = frame.GradientBar:CreateTexture(nil, "ARTWORK")
        frame.GradientTexture:SetPoint("TOPLEFT", 1, -1)
        frame.GradientTexture:SetPoint("BOTTOMRIGHT", -1, 1)
        frame.GradientTexture:SetTexture("Interface\\Buttons\\WHITE8x8")

        -- Click to open LibOrbitColorPicker
        frame:SetScript("OnClick", function(self)
            local lib = LibStub and LibStub("LibOrbitColorPicker-1.0", true)
            if not lib then
                print("LibOrbitColorPicker not found")
                return
            end

            lib:Open({
                initialCurve = self.curveData,
                hasOpacity = true,
                callback = function(result)
                    if result and result.pins then
                        self.curveData = result
                        self:UpdatePreview()
                        if self.onChangeCallback then
                            self.onChangeCallback(result)
                        end
                    end
                end,
            })
        end)
    end

    frame:SetParent(parent)

    -- Store curve data
    frame.curveData = initialCurveData
    frame.onChangeCallback = callback

    -- Update preview based on curve data
    frame.UpdatePreview = function(self)
        local pins = self.curveData and self.curveData.pins
        if not pins or #pins == 0 then
            self.GradientTexture:SetColorTexture(0.5, 0.5, 0.5, 1)
            return
        end

        if #pins == 1 then
            local c = pins[1].color
            self.GradientTexture:SetColorTexture(c.r, c.g, c.b, c.a or 1)
            return
        end

        -- Multi-pin: Show first and last color as gradient
        table.sort(pins, function(a, b) return a.position < b.position end)
        local first, last = pins[1].color, pins[#pins].color
        self.GradientTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        self.GradientTexture:SetGradient("HORIZONTAL", CreateColor(first.r, first.g, first.b, first.a or 1), CreateColor(last.r, last.g, last.b, last.a or 1))
    end

    frame:UpdatePreview()

    -- Apply 3-column layout
    local C = Engine.Constants

    frame.Label:SetText(label)
    frame.Label:SetWidth(C.Widget.LabelWidth)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:ClearAllPoints()
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)

    frame.GradientBar:ClearAllPoints()
    frame.GradientBar:SetPoint("LEFT", frame.Label, "RIGHT", C.Widget.LabelGap, 0)
    frame.GradientBar:SetPoint("RIGHT", frame, "RIGHT", -C.Widget.ValueWidth, 0)
    frame.GradientBar:SetHeight(GRADIENT_BAR_HEIGHT)

    frame:SetSize(260, WIDGET_HEIGHT)
    return frame
end
