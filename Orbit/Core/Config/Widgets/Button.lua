local _, Orbit = ...
local Engine = Orbit.Engine
local Layout = Engine.Layout

function Layout:CreateButton(parent, text, callback, width)
    -- Reuse from pool if available.
    if not self.buttonPool then
        self.buttonPool = {}
    end

    local frame = table.remove(self.buttonPool)

    if not frame then
        -- Use native button template which has 3 parts (Left/Middle/Right)
        frame = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        frame.OrbitType = "Button"
    end

    frame:SetParent(parent)
    frame:SetText(text)

    -- Setup script
    frame:SetScript("OnClick", function()
        if callback then
            callback(frame)
        end
    end)

    -- Width
    if width then
        frame:SetWidth(width)
    else
        -- Dynamic width based on text
        local fontString = frame:GetFontString()
        if fontString then
            local textWidth = fontString:GetStringWidth()
            frame:SetWidth(math.max(100, textWidth + 30))
        else
            frame:SetWidth(120)
        end
    end

    return frame
end
