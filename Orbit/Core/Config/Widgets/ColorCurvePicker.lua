local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local Layout = Engine.Layout

-- [ COLOR CURVE PICKER WIDGET ] ---------------------------------------------------------------------
-- Opens LibOrbitColorPicker for gradient editing
-- Stores curve data as serialized pins for persistence

local WIDGET_HEIGHT = 32
local GRADIENT_BAR_HEIGHT = 20
local CHECKERBOARD = "Interface\\AddOns\\Orbit\\Core\\assets\\Other\\Orbit_Checkerboard.tga"

function Layout:CreateColorCurvePicker(parent, label, initialCurveData, callback, valueCheckboxCfg)
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
        frame.GradientBar:SetBackdropColor(0, 0, 0, 0)

        frame.Checkerboard = frame.GradientBar:CreateTexture(nil, "BACKGROUND")
        frame.Checkerboard:SetPoint("TOPLEFT", 1, -1)
        frame.Checkerboard:SetPoint("BOTTOMRIGHT", -1, 1)
        frame.Checkerboard:SetTexture(CHECKERBOARD, "REPEAT", "REPEAT")
        frame.Checkerboard:SetHorizTile(true)
        frame.Checkerboard:SetVertTile(true)

        frame.GradientTexture = frame.GradientBar:CreateTexture(nil, "ARTWORK")
        frame.GradientTexture:SetPoint("TOPLEFT", 1, -1)
        frame.GradientTexture:SetPoint("BOTTOMRIGHT", -1, 1)
        frame.GradientTexture:SetTexture("Interface\\Buttons\\WHITE8x8")

        -- Click to open LibOrbitColorPicker
        frame:SetScript("OnClick", function(self)
            local lib = LibStub and LibStub("LibOrbitColorPicker-1.0", true)
            if not lib then return end

            if Orbit.db and Orbit.db.AccountSettings and not Orbit.db.AccountSettings.RecentColors then
                Orbit.db.AccountSettings.RecentColors = {}
            end

            lib:Open({
                initialData = self.curveData,
                hasOpacity = true,
                forceSingleColor = self.singleColorMode,
                hasDesaturation = self.hasDesaturation,
                recentColorsDb = Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.RecentColors,
                onOpen = function(picker)
                    local as = Orbit.db and Orbit.db.AccountSettings
                    if as and not as.ColorPickerTourComplete then
                        as.ColorPickerTourComplete = true
                        C_Timer.After(0.1, function() if picker:IsOpen() then picker:StartTour() end end)
                    end
                end,
                callback = function(result, wasCancelled)
                    if wasCancelled then return end
                    if result and result.pins and #result.pins > 0 then
                        self.curveData = { pins = result.pins }
                        if result.desaturated ~= nil then self.curveData.desaturated = result.desaturated end
                    else
                        self.curveData = nil
                    end
                    self:UpdatePreview()
                    if self.onChangeCallback then self.onChangeCallback(self.curveData) end
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
            local data = self.curveData
            local pins = data and data.pins
            self.GradientTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
            if not pins or #pins == 0 then
                -- Legacy single-color shape { r, g, b, a } — render as solid color so the
                -- swatch reflects SavedVariables on first paint instead of grey-until-clicked.
                if data and data.r then
                    local c = CreateColor(data.r, data.g, data.b, data.a or 1)
                    self.GradientTexture:SetGradient("HORIZONTAL", c, c)
                else
                    local grey = CreateColor(0.5, 0.5, 0.5, 1)
                    self.GradientTexture:SetGradient("HORIZONTAL", grey, grey)
                end
                return
            end
            local function ResolvePin(pin)
                if pin.type == "class" then
                    local _, classFile = UnitClass("player")
                    local classColor = RAID_CLASS_COLORS[classFile]
                    if classColor then return { r = classColor.r, g = classColor.g, b = classColor.b, a = 1 } end
                end
                return pin.color
            end
            local sortedPins = {}
            for i, p in ipairs(pins) do sortedPins[i] = p end
            table.sort(sortedPins, function(a, b) return a.position < b.position end)
            local first = ResolvePin(sortedPins[1])
            local last = ResolvePin(sortedPins[#sortedPins])
            self.GradientTexture:SetGradient("HORIZONTAL", CreateColor(first.r, first.g, first.b, first.a or 1), CreateColor(last.r, last.g, last.b, last.a or 1))
        end
    end

    frame:UpdatePreview()

    -- Apply 3-column layout
    local C = Constants

    frame.Label:SetText(label)
    frame.Label:SetWidth(C.Widget.LabelWidth)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:ClearAllPoints()
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)

    frame.GradientBar:ClearAllPoints()
    frame.GradientBar:SetPoint("LEFT", frame.Label, "RIGHT", C.Widget.LabelGap, 0)
    frame.GradientBar:SetPoint("RIGHT", frame, "RIGHT", -C.Widget.ValueWidth, 0)
    frame.GradientBar:SetHeight(GRADIENT_BAR_HEIGHT)

    -- Value column: optional inline checkbox
    if valueCheckboxCfg then
        self:ApplyValueCheckbox(frame, valueCheckboxCfg)
    elseif frame.ValueCheckbox then
        frame.ValueCheckbox:Hide()
    end

    frame:SetSize(260, WIDGET_HEIGHT)
    return frame
end
