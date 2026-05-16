local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local Layout = Engine.Layout

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local CHECK_TEX = "Interface\\Buttons\\UI-CheckBox-Check"
local CROSS_TEX = "Interface\\RAIDFRAME\\ReadyCheck-NotReady"
local TRISTATE_YELLOW = { r = 1, g = 0.82, b = 0 }

-- [ CHECKBOX WIDGET ]--------------------------------------------------------------------------------
-- Supports two layout modes:
--   Standard (default): 3-column settings layout via EditModeSettingCheckboxTemplate.
--   Compact (opts.compact=true): Grid-friendly [icon][label] via UICheckButtonTemplate.
-- Supports tri-state (opts.triState=true): unchecked(0) → checked(1) → cross(2).
function Layout:CreateCheckbox(parent, label, tooltip, initialValue, callback, opts)
    opts = opts or {}
    local frame
    if opts.compact then
        -- Compact grid-friendly checkbox
        frame = CreateFrame("Frame", nil, parent)
        frame:SetHeight(26)
        frame.OrbitType = "Checkbox"
        local cb = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        cb:SetPoint("LEFT")
        frame._cb = cb
        local text = cb.text or cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetTextColor(1, 1, 1)
        text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb.text = text
        text:SetText(label)
        -- Public accessors
        frame.SetLabel = function(self, t) text:SetText(t) end
        frame.SetLabelColor = function(self, r, g, b) text:SetTextColor(r, g, b) end
        frame.SetEnabled = function(self, enabled) if enabled then cb:Enable() else cb:Disable() end end
        frame.SetChecked = function(self, v) cb:SetChecked(v) end
        frame.GetChecked = function(self) return cb:GetChecked() end
        frame.SetOnClick = function(self, fn) cb:SetScript("OnClick", fn) end
        frame.SetTooltip = function(self, enterFn, leaveFn)
            cb:SetScript("OnEnter", enterFn)
            cb:SetScript("OnLeave", leaveFn or GameTooltip_Hide)
        end
    else
        -- Standard 3-column settings layout
        if not self.checkboxPool then self.checkboxPool = {} end
        frame = table.remove(self.checkboxPool)
        if not frame then
            frame = CreateFrame("Frame", nil, parent, "EditModeSettingCheckboxTemplate")
            frame.OrbitType = "Checkbox"
        end
        frame:SetParent(parent)
        frame:SetHeight(30)
        local C = Constants
        if frame.Button then
            frame.Button:ClearAllPoints()
            frame.Button:SetPoint("LEFT", frame, "LEFT", 0, 0)
        end
        if frame.Label then
            frame.Label:SetText(label)
            frame.Label:SetFontObject(C.UI.LabelFont)
            frame.Label:SetWidth(0)
            frame.Label:SetJustifyH("LEFT")
            frame.Label:ClearAllPoints()
            frame.Label:SetPoint("LEFT", frame, "LEFT", C.Widget.LabelWidth + C.Widget.LabelGap, 0)
            -- Reserve space on the right for the optional value column.
            local rightInset = opts.valueText ~= nil and C.Widget.ValueWidth or 0
            frame.Label:SetPoint("RIGHT", frame, "RIGHT", -rightInset, 0)
        end
        -- Value column: optional right-aligned static text (e.g. a count badge).
        if opts.valueText ~= nil then
            if not frame.ValueText then
                frame.ValueText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            end
            frame.ValueText:ClearAllPoints()
            frame.ValueText:SetPoint("RIGHT", frame, "RIGHT", -C.Widget.ValueInset, 0)
            frame.ValueText:SetWidth(C.Widget.ValueWidth - C.Widget.ValueInset)
            frame.ValueText:SetJustifyH("RIGHT")
            frame.ValueText:SetText(tostring(opts.valueText))
            frame.ValueText:Show()
        elseif frame.ValueText then
            frame.ValueText:Hide()
        end
        -- Map standard accessors to template children
        frame._cb = frame.Button
        frame.SetLabel = function(self, t) if self.Label then self.Label:SetText(t) end end
        frame.SetLabelColor = function(self, r, g, b) if self.Label then self.Label:SetTextColor(r, g, b) end end
        frame.SetEnabled = function(self, enabled) if self.Button then if enabled then self.Button:Enable() else self.Button:Disable() end end end
        frame.SetChecked = function(self, v) if self.Button then self.Button:SetChecked(v) end end
        frame.GetChecked = function(self) return self.Button and self.Button:GetChecked() end
        frame.SetOnClick = function(self, fn) if self.Button then self.Button:SetScript("OnClick", fn) end end
        frame.SetTooltip = function(self, enterFn, leaveFn)
            if self.Button then
                self.Button:SetScript("OnEnter", enterFn)
                self.Button:SetScript("OnLeave", leaveFn or GameTooltip_Hide)
            end
        end
    end
    local cb = frame._cb
    -- Tri-state support
    if opts.triState then
        frame._triState = initialValue or 0
        local function ApplyVisual(state)
            if state == 0 then
                cb:SetChecked(false)
                cb:SetCheckedTexture(CHECK_TEX)
            elseif state == 1 then
                cb:SetChecked(true)
                cb:SetCheckedTexture(CHECK_TEX)
                cb:GetCheckedTexture():SetVertexColor(TRISTATE_YELLOW.r, TRISTATE_YELLOW.g, TRISTATE_YELLOW.b)
            else
                cb:SetChecked(true)
                cb:SetCheckedTexture(CROSS_TEX)
                cb:GetCheckedTexture():SetVertexColor(1, 0.3, 0.3)
            end
        end
        ApplyVisual(frame._triState)
        cb:SetScript("OnClick", function()
            frame._triState = (frame._triState + 1) % 3
            ApplyVisual(frame._triState)
            if callback then callback(frame._triState) end
        end)
        frame.SetTriState = function(self, state) self._triState = state; ApplyVisual(state) end
        frame.GetTriState = function(self) return self._triState end
    else
        -- Standard boolean toggle
        cb:SetChecked(initialValue or false)
        cb:SetCheckedTexture(CHECK_TEX)
        if initialValue then cb:GetCheckedTexture():SetVertexColor(1, 1, 1) end
        cb:SetScript("OnClick", function(self)
            local checked = self:GetChecked()
            if callback then callback(checked) end
        end)
    end
    -- Tooltip
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            if type(tooltip) == "function" then
                GameTooltip:AddLine(tooltip(frame), nil, nil, nil, true)
            else
                GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            end
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end
    return frame
end
