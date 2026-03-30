-- [ TRACKED CANVAS PREVIEW ] --------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local CooldownUtils = OrbitEngine.CooldownUtils

local TRACKED_PLACEHOLDER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local Plugin = Orbit:GetPlugin("Orbit_Tracked")
if not Plugin then return end

function Plugin:SetupTrackedCanvasPreview(anchor, systemIndex)
    local plugin = self
    local LSM = LibStub("LibSharedMedia-3.0")

    anchor.CreateCanvasPreview = function(self, options)
        local w, h = CooldownUtils:CalculateIconDimensions(plugin, systemIndex)

        -- Resolve icon texture from first tracked item
        local iconTexture = TRACKED_PLACEHOLDER_ICON
        local tracked = plugin:GetSetting(systemIndex, "TrackedItems") or {}
        for _, data in pairs(tracked) do
            if data and data.type and data.id then
                if data.type == "spell" then iconTexture = C_Spell.GetSpellTexture(data.id) or iconTexture
                elseif data.type == "item" then iconTexture = C_Item.GetItemIconByID(data.id) or iconTexture end
                break
            end
        end

        local preview = OrbitEngine.IconCanvasPreview:Create(self, options.parent or UIParent, w, h, iconTexture)
        preview.systemIndex = systemIndex
        preview.isTrackedIcon = true
        local savedPositions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
        local globalFontName = Orbit.db.GlobalSettings.Font
        local fontPath = LSM:Fetch("font", globalFontName) or "Fonts\\FRIZQT__.TTF"

        OrbitEngine.IconCanvasPreview:AttachTextComponents(preview, {
            { key = "Timer", preview = string.format("%.1f", 3 + math.random() * 7), anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0 },
            { key = "Stacks", preview = "3", anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
            { key = "Keybind", preview = "Q", anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2 },
        }, savedPositions, fontPath)

        return preview
    end
end
