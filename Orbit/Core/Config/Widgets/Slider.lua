local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local Layout = Engine.Layout
local math_floor = math.floor

-- [ SLIDER WIDGET ]---------------------------------------------------------------------------------
function Layout:CreateSlider(parent, label, min, max, step, formatter, initialValue, callback, options)
    if not self.sliderPool then
        self.sliderPool = {}
    end
    local frame = table.remove(self.sliderPool)

    if not frame then
        frame = CreateFrame("Frame", nil, parent, "EditModeSettingSliderTemplate")
        frame.OrbitType = "Slider"

        frame.OnSliderValueChanged = function() end
        frame.OnSliderInteractStart = function() end
        frame.OnSliderInteractEnd = function() end

        frame.Value = frame:CreateFontString(nil, "OVERLAY", Orbit.Constants.UI.ValueFont)
        frame.Value:SetTextColor(1, 0.82, 0, 1)
    end

    frame:SetParent(parent)

    frame.valueFormatter = formatter or function(value)
        return math_floor(value * 10 or 0) / 10
    end
    frame.OnOrbitChange = callback

    if frame.Slider then
        -- Unregister before re-registering — pool reuse would otherwise stack callbacks each acquire.
        if frame._callbackRegistered then
            frame.Slider:UnregisterCallback("OnValueChanged", frame)
        end

        -- Slider:Init fires OnValueChanged synchronously; guard prevents that fire from reaching onChange.
        frame._isInitializing = true

        frame.Slider:RegisterCallback("OnValueChanged", function(_, value)
            if frame.Value and frame.valueFormatter then
                frame.Value:SetText(frame.valueFormatter(value))
            end

            if frame._isInitializing then
                return
            end

            if options and options.updateOnRelease then
                return
            end

            if frame.OnOrbitChange then
                frame.OnOrbitChange(value)
            end
        end, frame)
        frame._callbackRegistered = true

        local steps = (max - min) / step
        local startValue = initialValue or min
        frame.Slider:Init(startValue, min, max, steps, {})

        frame._isInitializing = false

        -- Handle Release for deferred updates
        local innerSlider = frame.Slider.Slider
        if innerSlider then
            if options and options.updateOnRelease then
                innerSlider:SetScript("OnMouseUp", function()
                    local val = innerSlider:GetValue()
                    if frame.OnOrbitChange then
                        frame.OnOrbitChange(val)
                    end
                end)
            else
                innerSlider:SetScript("OnMouseUp", nil)
            end

            -- Hide native value display (re-apply safely)
            for _, region in pairs({ innerSlider:GetRegions() }) do
                if region:GetObjectType() == "FontString" then
                    region:Hide()
                end
            end
        end

        -- Handle stepper buttons (Back/Forward)
        -- FIX: Use HookScript with a flag guard to prevent hook accumulation on pooled sliders
        -- We can't use SetScript because it overwrites Blizzard's native increment/decrement handler
        local back = frame.Back or (frame.Slider and frame.Slider.Back)
        local forward = frame.Forward or (frame.Slider and frame.Slider.Forward)

        if options and options.updateOnRelease then
            -- Create debounced stepper callback to prevent rapid-click spam
            local function createStepperCallback()
                return function()
                    -- Cancel any pending stepper timer
                    if frame._stepperTimer then
                        frame._stepperTimer:Cancel()
                    end
                    -- Debounce: Wait 100ms before applying (coalesces rapid clicks)
                    frame._stepperTimer = C_Timer.NewTimer(0.1, function()
                        frame._stepperTimer = nil
                        local val = innerSlider and innerSlider:GetValue() or 0
                        if frame.OnOrbitChange then
                            frame.OnOrbitChange(val)
                        end
                    end)
                end
            end

            -- Hook only once per button (use flag to prevent accumulation on pool reuse)
            if back and not back._orbitHooked then
                back:HookScript("OnClick", createStepperCallback())
                back._orbitHooked = true
            end
            if forward and not forward._orbitHooked then
                forward:HookScript("OnClick", createStepperCallback())
                forward._orbitHooked = true
            end
        end

        -- Set initial value display
        if frame.Value then
            frame.Value:SetText(frame.valueFormatter(startValue))
        end
    end

    -- Apply 3-column layout
    local C = Constants

    if frame.Label then
        frame.Label:SetText(label)
        frame.Label:SetFontObject(Constants.UI.LabelFont)
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
