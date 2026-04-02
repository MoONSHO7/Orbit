local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local MIN_BUTTON_WIDTH = 100
local BUTTON_TEXT_PADDING = 30
local DEFAULT_BUTTON_WIDTH = 120

-- [ BUTTON WIDGET ]---------------------------------------------------------------------------------
function Layout:CreateButton(parent, text, callback, width)
    if not self.buttonPool then self.buttonPool = {} end
    local frame = table.remove(self.buttonPool)
    if not frame then
        frame = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        frame.OrbitType = "Button"
    end
    frame:SetParent(parent)
    frame:SetText(text)
    frame:SetScript("OnClick", function()
        if callback then callback(frame) end
    end)
    if width then
        frame:SetWidth(width)
    else
        local fontString = frame:GetFontString()
        if fontString then
            frame:SetWidth(math.max(MIN_BUTTON_WIDTH, fontString:GetStringWidth() + BUTTON_TEXT_PADDING))
        else
            frame:SetWidth(DEFAULT_BUTTON_WIDTH)
        end
    end
    return frame
end
