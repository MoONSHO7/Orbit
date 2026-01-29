local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout

--[[
    ColorPicker Widget
    3-Column Layout: [Label: Fixed, Left] [Control: Dynamic, Fill] [Value: Fixed, Right (reserved)]
]]
function Layout:CreateColorPicker(parent, label, initialColor, callback)
    -- Pool retrieval
    if not self.colorPool then
        self.colorPool = {}
    end
    local frame = table.remove(self.colorPool)

    -- Frame creation
    if not frame then
        frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        frame.OrbitType = "Color"

        -- Label
        frame.Label = frame:CreateFontString(nil, "ARTWORK", Orbit.Constants.UI.LabelFont)

        -- Control: Swatch button
        frame.Swatch = CreateFrame("Button", nil, frame, "BackdropTemplate")
        frame.Swatch:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        frame.Swatch:SetBackdropBorderColor(0, 0, 0, 1)

        -- Color texture inside swatch
        frame.Swatch.Color = frame.Swatch:CreateTexture(nil, "OVERLAY")
        frame.Swatch.Color:SetPoint("TOPLEFT", 1, -1)
        frame.Swatch.Color:SetPoint("BOTTOMRIGHT", -1, 1)
        frame.Swatch.Color:SetColorTexture(1, 1, 1, 1)

        -- Click handler
        frame.Swatch:SetScript("OnClick", function()
            if ColorPickerFrame.SetupColorPickerAndShow then
                -- Modern API (10.2.5+)
                local wasCancelled = false
                local info = {
                    swatchFunc = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        local a = ColorPickerFrame:GetColorAlpha()
                        if frame.UpdateColor then
                            frame.UpdateColor(r, g, b, a, true) -- Preview only
                        end
                    end,
                    opacityFunc = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        local a = ColorPickerFrame:GetColorAlpha()
                        if frame.UpdateColor then
                            frame.UpdateColor(r, g, b, a, true) -- Preview only
                        end
                    end,
                    cancelFunc = function(restore)
                        wasCancelled = true
                        if frame.UpdateColor then
                            frame.UpdateColor(restore.r, restore.g, restore.b, restore.a, false) -- Restore = final
                        end
                    end,
                    hasOpacity = true,
                    r = frame.r,
                    g = frame.g,
                    b = frame.b,
                    opacity = frame.a,
                }
                
                -- Hook OnHide to trigger final callback when picker closes (if not cancelled)
                if not frame.colorPickerHooked then
                    ColorPickerFrame:HookScript("OnHide", function()
                        if not wasCancelled and frame.UpdateColor then
                            -- Commit the current preview values as final
                            frame.UpdateColor(frame.r, frame.g, frame.b, frame.a, false)
                        end
                        wasCancelled = false -- Reset for next use
                    end)
                    frame.colorPickerHooked = true
                end
                
                ColorPickerFrame:SetupColorPickerAndShow(info)
                ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            else
                -- Pre-10.2.5 API
                ColorPickerFrame:SetColorRGB(frame.r, frame.g, frame.b)
                ColorPickerFrame.hasOpacity = true
                ColorPickerFrame.opacity = frame.a
                ColorPickerFrame.func = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = OpacityFrame:GetValue()
                    if frame.UpdateColor then
                        frame.UpdateColor(r, g, b, a, true) -- Preview only
                    end
                end
                ColorPickerFrame.opacityFunc = ColorPickerFrame.func
                ColorPickerFrame.cancelFunc = function()
                    if frame.UpdateColor then
                        frame.UpdateColor(frame.oldR, frame.oldG, frame.oldB, frame.oldA, false)
                    end
                end
                ColorPickerFrame:Show()
                ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            end
        end)
    end

    -- Set parent
    frame:SetParent(parent)

    -- Configure control logic
    local c = initialColor or { r = 1, g = 1, b = 1, a = 1 }
    frame.r = c.r or 1
    frame.g = c.g or 1
    frame.b = c.b or 1
    frame.a = c.a or 1
    frame.oldR, frame.oldG, frame.oldB, frame.oldA = frame.r, frame.g, frame.b, frame.a

    frame.Swatch.Color:SetVertexColor(frame.r, frame.g, frame.b, frame.a)

    frame.UpdateColor = function(r, g, b, a, isPreview)
        frame.r, frame.g, frame.b, frame.a = r, g, b, a
        frame.Swatch.Color:SetVertexColor(r, g, b, a)
        -- Always trigger callback for live preview (consistent with slider behavior)
        if callback then
            callback({ r = r, g = g, b = b, a = a })
        end
    end

    -- Apply 3-column layout
    local C = Engine.Constants

    frame.Label:SetText(label)
    frame.Label:SetWidth(C.Widget.LabelWidth)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:ClearAllPoints()
    frame.Label:SetPoint("LEFT", frame, "LEFT", 0, 0)

    frame.Swatch:ClearAllPoints()
    frame.Swatch:SetPoint("LEFT", frame.Label, "RIGHT", C.Widget.LabelGap, 0)
    frame.Swatch:SetPoint("RIGHT", frame, "RIGHT", -C.Widget.ValueWidth, 0)
    frame.Swatch:SetHeight(20)

    -- Value column reserved (empty for color picker)

    frame:SetSize(260, 32)
    return frame
end
