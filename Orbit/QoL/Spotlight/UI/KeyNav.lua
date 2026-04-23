-- [ KEY NAV ]---------------------------------------------------------------------------------------
local _, Orbit = ...
local KeyNav = {}
Orbit.Spotlight.UI.KeyNav = KeyNav

-- [ ATTACH ]----------------------------------------------------------------------------------------
-- Three-way key handling (mirrors Orbit-Dock-Portal's input model in Core/Input/PortalNavigation.lua):
--   * UP/DOWN/ENTER/ESCAPE    consumed for list nav; propagation off so global bindings don't fire
--   * SPACE / alnum / edit    consumed so the EditBox owns typing + text editing (held backspace
--                             auto-repeats stop firing if propagation flips to true mid-key)
--   * everything else         propagated so F-keys, modifiers, and symbol-bound hotkeys still trigger
--                             bindings
-- The OnChar filter is a defensive second pass: any non-alphanumeric char that slips through is stripped
-- from the text, keeping the input strictly a-Z 0-9 plus space.
local EDIT_KEYS = {
    BACKSPACE = true, DELETE = true,
    LEFT = true, RIGHT = true, HOME = true, END = true,
    INSERT = true,
}

function KeyNav:Attach(editBox, callbacks)
    editBox:SetScript("OnKeyDown", function(self, key)
        if key == "UP" then
            self:SetPropagateKeyboardInput(false); callbacks.OnMovePrev()
        elseif key == "DOWN" then
            self:SetPropagateKeyboardInput(false); callbacks.OnMoveNext()
        elseif key == "ENTER" then
            self:SetPropagateKeyboardInput(false); callbacks.OnActivate()
        elseif key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false); callbacks.OnClose()
        elseif key == "SPACE" or EDIT_KEYS[key] then
            self:SetPropagateKeyboardInput(false)
        elseif #key == 1 and key:match("[%a%d]") then
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    editBox:SetScript("OnChar", function(self, char)
        if char and not char:match("[%a%d ]") then
            local pos = self:GetCursorPosition()
            local text = self:GetText()
            if pos >= 1 then
                self:SetText(text:sub(1, pos - 1) .. text:sub(pos + 1))
                self:SetCursorPosition(pos - 1)
            end
        end
    end)
end
