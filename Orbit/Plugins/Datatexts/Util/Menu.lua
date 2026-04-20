-- Menu.lua
-- Context menu helper for datatext right-click menus
local _, Orbit = ...
local DT = Orbit.Datatexts

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local MENU_TAG = "ORBIT_datatext_CONTEXT"

-- [ MENU ] ------------------------------------------------------------------------------------------
local Menu = {}
DT.Menu = Menu

function Menu:Open(ownerFrame, items, datatextName)
    MenuUtil.CreateContextMenu(ownerFrame, function(_, rootDescription)
        rootDescription:SetTag(MENU_TAG .. (datatextName or ""))
        for _, data in ipairs(items) do
            if data.isSeparator then
                rootDescription:CreateDivider()
            elseif data.checked ~= nil then
                rootDescription:CreateCheckbox(data.text, function() return data.checked end, function()
                    data.checked = not data.checked
                    if data.func then data.func() end
                end)
            else
                local btn = rootDescription:CreateButton(data.text, function() if data.func then data.func() end end)
                if data.disabled then btn:SetEnabled(false) end
            end
        end
    end)
end
