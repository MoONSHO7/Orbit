local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local Layout = Engine.Layout

local MAX_TEXT_LENGTH = 22

-- [ DROPDOWN WIDGET ]-------------------------------------------------------------------------------
function Layout:CreateDropdown(parent, label, options, initialValue, callback, valueCheckboxCfg, valueColorCfg)
    -- Pool retrieval
    if not self.dropdownPool then
        self.dropdownPool = {}
    end
    local frame = table.remove(self.dropdownPool)

    -- Frame creation
    if not frame then
        frame = CreateFrame("Frame", nil, parent, "EditModeSettingDropdownTemplate")
        frame.OrbitType = "Dropdown"
    end

    -- Set parent
    frame:SetParent(parent)

    -- Configure control logic
    if frame.Dropdown then
        frame.currentValue = initialValue

        local function GetTextForValue(val)
            local text = tostring(val)
            for _, opt in ipairs(options) do
                if opt.value == val then
                    text = opt.label or opt.text or tostring(val)
                    break
                end
            end

            if #text > MAX_TEXT_LENGTH then
                text = string.sub(text, 1, MAX_TEXT_LENGTH - 2) .. ".."
            end
            return text
        end

        frame.Dropdown:SetText(GetTextForValue(initialValue))

        frame.Dropdown:SetupMenu(function(dropdown, rootDescription)
            rootDescription:SetTag("OrbitDropdown")

            for _, option in ipairs(options) do
                local text = option.label or option.text or tostring(option.value)
                local value = option.value

                local radio = rootDescription:CreateRadio(text, function(data)
                    return frame.currentValue == data
                end, function(data)
                    frame.currentValue = data
                    frame.Dropdown:SetText(GetTextForValue(data))
                    if callback then
                        callback(data)
                    end
                end, value)

                if option.font then
                    radio:AddInitializer(function(button, description, menu)
                        if button.fontString then
                            button.fontString:SetFont(option.font, 14)
                        end
                    end)
                end
            end
        end)

        -- Ensure dropdown menu closes if parent is hidden/recycled
        frame:SetScript("OnHide", function()
            if frame.Dropdown then
                frame.Dropdown:CloseMenu()
            end
        end)
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

    if frame.Dropdown then
        frame.Dropdown:ClearAllPoints()
        frame.Dropdown:SetPoint("LEFT", frame.Label, "RIGHT", C.Widget.LabelGap, 0)
        frame.Dropdown:SetPoint("RIGHT", frame, "RIGHT", -C.Widget.ValueWidth, 0)
    end

    -- Value column: optional inline checkbox or color swatch
    if valueCheckboxCfg then
        if not frame.ValueCheckbox then
            frame.ValueCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
            frame.ValueCheckbox:SetSize(22, 22)
        end
        local vcb = frame.ValueCheckbox
        vcb:ClearAllPoints()
        vcb:SetPoint("CENTER", frame, "RIGHT", -C.Widget.ValueWidth / 2, 0)
        vcb:SetChecked(valueCheckboxCfg.initialValue or false)
        vcb:SetScript("OnClick", function(self)
            if valueCheckboxCfg.callback then valueCheckboxCfg.callback(self:GetChecked()) end
        end)
        if valueCheckboxCfg.tooltip then
            vcb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(valueCheckboxCfg.tooltip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            vcb:SetScript("OnLeave", GameTooltip_Hide)
        end
        vcb:Show()
        if frame.ValueColorSwatch then frame.ValueColorSwatch:Hide() end
    elseif valueColorCfg then
        if not frame.ValueColorSwatch then
            frame.ValueColorSwatch = CreateFrame("Button", nil, frame, "BackdropTemplate")
            frame.ValueColorSwatch:SetSize(21, 21)
            frame.ValueColorSwatch:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            frame.ValueColorSwatch:SetBackdropBorderColor(0, 0, 0, 1)

            frame.ValueColorSwatch.Color = frame.ValueColorSwatch:CreateTexture(nil, "OVERLAY")
            frame.ValueColorSwatch.Color.SetVertexColor = nil -- Clean up if this was a recycled frame with custom methods mapped
            frame.ValueColorSwatch.Color:SetPoint("TOPLEFT", 1, -1)
            frame.ValueColorSwatch.Color:SetPoint("BOTTOMRIGHT", -1, 1)
            frame.ValueColorSwatch.Color:SetColorTexture(1, 1, 1, 1)
        end
        local swatch = frame.ValueColorSwatch
        swatch:ClearAllPoints()
        swatch:SetPoint("CENTER", frame, "RIGHT", -C.Widget.ValueWidth / 2, 0)
        
        local initialColor = valueColorCfg.initialValue or { r = 1, g = 1, b = 1, a = 1 }
        swatch.r, swatch.g, swatch.b, swatch.a = initialColor.r or 1, initialColor.g or 1, initialColor.b or 1, initialColor.a or 1
        swatch.Color:SetVertexColor(swatch.r, swatch.g, swatch.b, swatch.a)
        
        swatch:SetScript("OnClick", function()
            local lib = LibStub and LibStub("LibOrbitColorPicker-1.0", true)
            if not lib then return end
            
            if Orbit.db and not Orbit.db.RecentColors then
                Orbit.db.RecentColors = {}
            end

            lib:Open({
                initialData = { r = swatch.r, g = swatch.g, b = swatch.b, a = swatch.a },
                hasOpacity = true,
                forceSingleColor = true,
                recentColorsDb = Orbit.db and Orbit.db.RecentColors,
                callback = function(result, wasCancelled)
                    if wasCancelled or not result then return end
                    local pin = result.pins and result.pins[1]
                    if pin and pin.color then
                        swatch.r, swatch.g, swatch.b, swatch.a = pin.color.r, pin.color.g, pin.color.b, pin.color.a
                        swatch.Color:SetVertexColor(swatch.r, swatch.g, swatch.b, swatch.a)
                        if valueColorCfg.callback then valueColorCfg.callback(pin.color) end
                    end
                end,
            })
        end)
        
        if valueColorCfg.tooltip then
            swatch:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(valueColorCfg.tooltip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            swatch:SetScript("OnLeave", GameTooltip_Hide)
        end
        swatch:Show()
        if frame.ValueCheckbox then frame.ValueCheckbox:Hide() end
    else
        if frame.ValueCheckbox then frame.ValueCheckbox:Hide() end
        if frame.ValueColorSwatch then frame.ValueColorSwatch:Hide() end
    end

    frame:SetHeight(32)
    return frame
end
