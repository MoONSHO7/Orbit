-- [ ACTION BARS - CANVAS PREVIEW ]----------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

local BUTTON_SIZE = 32
local FALLBACK_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"

Orbit.ActionBarsPreview = {}
local ABPreview = Orbit.ActionBarsPreview

function ABPreview:Setup(plugin, container, systemIndex)
    local LSM = LibStub("LibSharedMedia-3.0")
    container.CreateCanvasPreview = function(self, options)
        -- Resolve icon texture from first visible button
        local iconTexture = FALLBACK_TEXTURE
        local buttons = plugin.buttons[systemIndex]
        if buttons then
            for _, btn in ipairs(buttons) do
                if btn:IsShown() and btn.icon then
                    local tex = btn.icon:GetTexture()
                    if tex then iconTexture = tex; break end
                end
            end
        end

        local preview = OrbitEngine.IconCanvasPreview:Create(self, options.parent or UIParent, BUTTON_SIZE, BUTTON_SIZE, iconTexture)
        preview.systemIndex = systemIndex

        -- Resolve saved positions (global sync aware)
        local useGlobal = plugin:GetSetting(systemIndex, "UseGlobalTextStyle")
        local savedPositions
        if useGlobal ~= false then savedPositions = plugin:GetSetting(1, "GlobalComponentPositions") or {}
        else savedPositions = plugin:GetSetting(systemIndex, "ComponentPositions") or {} end

        local globalFontName = Orbit.db.GlobalSettings.Font
        local fontPath = LSM:Fetch("font", globalFontName) or "Fonts\\FRIZQT__.TTF"

        OrbitEngine.IconCanvasPreview:AttachTextComponents(preview, {
            { key = "Keybind", preview = "Q", anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2 },
            { key = "MacroText", preview = "Macro", anchorX = "CENTER", anchorY = "BOTTOM", offsetX = 0, offsetY = 2 },
            { key = "Timer", preview = "5", anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0 },
            { key = "Stacks", preview = "3", anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
        }, savedPositions, fontPath)

        return preview
    end
end
