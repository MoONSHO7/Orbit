local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout

--[[
    Slider Widget
    3-Column Layout: [Label: Fixed, Left] [Control: Dynamic, Fill] [Value: Fixed, Right]
]]
function Layout:CreateSlider(parent, label, min, max, step, formatter, initialValue, callback)
    -- Pool retrieval
    if not self.sliderPool then
        self.sliderPool = {}
    end
    local frame = table.remove(self.sliderPool)

    -- Frame creation
    if not frame then
        frame = CreateFrame("Frame", nil, parent, "EditModeSettingSliderTemplate")
        frame.OrbitType = "Slider"

        -- Neutralize native handlers
        frame.OnSliderValueChanged = function() end
        frame.OnSliderInteractStart = function() end
        frame.OnSliderInteractEnd = function() end

        -- Create Value display (yellow text like Blizzard)
        frame.Value = frame:CreateFontString(nil, "OVERLAY", Orbit.Constants.UI.ValueFont)
        frame.Value:SetTextColor(1, 0.82, 0, 1) -- Blizzard gold
    end

    -- Set parent
    frame:SetParent(parent)

    -- Configure control logic
    frame.valueFormatter = formatter or function(value)
        return math.floor(value * 10 or 0) / 10
    end
    frame.OnOrbitChange = callback

    if frame.Slider then
        -- Register value change listener
        frame.Slider:RegisterCallback("OnValueChanged", function(_, value)
            if frame.Value and frame.valueFormatter then
                frame.Value:SetText(frame.valueFormatter(value))
            end
            if frame.OnOrbitChange then
                frame.OnOrbitChange(value)
            end
        end, frame)

        -- Initialize slider
        local steps = (max - min) / step
        local startValue = initialValue or min
        frame.Slider:Init(startValue, min, max, steps, {})

        -- Hide native value display
        local innerSlider = frame.Slider.Slider
        if innerSlider then
            for _, region in pairs({ innerSlider:GetRegions() }) do
                if region:GetObjectType() == "FontString" then
                    region:Hide()
                end
            end
        end

        -- Set initial value display
        if frame.Value then
            frame.Value:SetText(frame.valueFormatter(startValue))
        end
    end

    -- Apply 3-column layout
    local C = Engine.Constants

    if frame.Label then
        frame.Label:SetText(label)
        frame.Label:SetFontObject(Orbit.Constants.UI.LabelFont)
        frame.Label:SetWidth(C.Widget.LabelWidth)
        frame.Label:SetJustifyH("LEFT")
        frame.Label:ClearAllPoints()
        frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    end

    if frame.Slider then
        frame.Slider:ClearAllPoints()
        frame.Slider:SetPoint("LEFT", frame.Label, "RIGHT", C.Widget.LabelGap, 0)
        frame.Slider:SetPoint("RIGHT", frame, "RIGHT", -C.Widget.ValueWidth, 0)
    end

    if frame.Value then
        frame.Value:ClearAllPoints()
        frame.Value:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        frame.Value:SetWidth(C.Widget.ValueWidth)
        frame.Value:SetJustifyH("RIGHT")
    end

    frame:SetHeight(32)
    return frame
end
