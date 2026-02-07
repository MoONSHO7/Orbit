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
            if not lib then return end

            lib:Open({
                initialData = self.curveData,
                hasOpacity = true,
                forceSingleColor = self.singleColorMode,
                callback = function(result, wasCancelled)
                    if wasCancelled then return end
                    if result and result.pins then
                        self.curveData = result
                        self:UpdatePreview()
                        if self.onChangeCallback then self.onChangeCallback(result) end
                    end
                end,
            })
        end)
    end

    frame:SetParent(parent)

    -- Store curve data
    frame.curveData = initialCurveData
    frame.onChangeCallback = callback

    -- Update preview based on curve data (only assign once, not on pooled reuse)
    if not frame.UpdatePreview then
    frame.UpdatePreview = function(self)
        local pins = self.curveData and self.curveData.pins
        if not pins or #pins == 0 then
            self.GradientTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
            self.GradientTexture:SetGradient("HORIZONTAL", CreateColor(0.5, 0.5, 0.5, 1), CreateColor(0.5, 0.5, 0.5, 1))
            return
        end
        
        -- Resolve class color pins dynamically
        local function ResolvePin(pin)
            if pin.type == "class" then
                local _, classFile = UnitClass("player")
                local classColor = RAID_CLASS_COLORS[classFile]
                if classColor then return { r = classColor.r, g = classColor.g, b = classColor.b, a = 1 } end
            end
            return pin.color
        end

        -- Sort pins by position (use copy to avoid mutating original)
        local sortedPins = {}
        for i, p in ipairs(pins) do sortedPins[i] = p end
        table.sort(sortedPins, function(a, b) return a.position < b.position end)
        
        local first = ResolvePin(sortedPins[1])
        local last = ResolvePin(sortedPins[#sortedPins])
        
        -- Always use SetTexture + SetGradient for consistent state reset
        self.GradientTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        self.GradientTexture:SetGradient("HORIZONTAL", CreateColor(first.r, first.g, first.b, first.a or 1), CreateColor(last.r, last.g, last.b, last.a or 1))
    end
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
