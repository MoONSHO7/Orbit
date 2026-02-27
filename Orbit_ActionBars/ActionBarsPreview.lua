-- [ ACTION BARS - CANVAS PREVIEW ]----------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

local BUTTON_SIZE = 36

Orbit.ActionBarsPreview = {}
local ABPreview = Orbit.ActionBarsPreview

function ABPreview:Setup(plugin, container, systemIndex)
    local LSM = LibStub("LibSharedMedia-3.0")
    container.CreateCanvasPreview = function(self, options)
        local w, h = BUTTON_SIZE, BUTTON_SIZE
        local parent = options.parent or UIParent
        local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        preview:SetSize(w, h)
        preview.sourceFrame = self
        local borderSize = Orbit.db.GlobalSettings.BorderSize
        local borderPixels = OrbitEngine.Pixel:Multiple(borderSize)
        local contentW = w - (borderPixels * 2)
        local contentH = h - (borderPixels * 2)
        preview.sourceWidth, preview.sourceHeight, preview.previewScale = contentW, contentH, 1
        preview.components = {}
        local iconTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
        local buttons = plugin.buttons[systemIndex]
        if buttons then
            for _, btn in ipairs(buttons) do
                if btn:IsShown() and btn.icon then
                    local tex = btn.icon:GetTexture()
                    if tex then iconTexture = tex; break end
                end
            end
        end
        local icon = preview:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(iconTexture)
        local backdrop = { bgFile = "Interface\\BUTTONS\\WHITE8x8", insets = { left = 0, right = 0, top = 0, bottom = 0 } }
        if borderSize > 0 then backdrop.edgeFile = "Interface\\BUTTONS\\WHITE8x8"; backdrop.edgeSize = borderPixels end
        preview:SetBackdrop(backdrop)
        preview:SetBackdropColor(0, 0, 0, 0)
        if borderSize > 0 then preview:SetBackdropBorderColor(0, 0, 0, 1) end
        local useGlobal = plugin:GetSetting(systemIndex, "UseGlobalTextStyle")
        local savedPositions
        if useGlobal ~= false then savedPositions = plugin:GetSetting(1, "GlobalComponentPositions") or {}
        else savedPositions = plugin:GetSetting(systemIndex, "ComponentPositions") or {} end
        local globalFontName = Orbit.db.GlobalSettings.Font
        local fontPath = LSM:Fetch("font", globalFontName) or "Fonts\\FRIZQT__.TTF"
        local textComponents = {
            { key = "Keybind", preview = "Q", anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2 },
            { key = "MacroText", preview = "Macro", anchorX = "CENTER", anchorY = "BOTTOM", offsetX = 0, offsetY = 2 },
            { key = "Timer", preview = "5", anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0 },
            { key = "Stacks", preview = "3", anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
        }
        local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent
        for _, def in ipairs(textComponents) do
            local fs = preview:CreateFontString(nil, "OVERLAY", nil, 7)
            fs:SetFont(fontPath, 12, Orbit.Skin:GetFontOutline())
            fs:SetText(def.preview)
            fs:SetTextColor(1, 1, 1, 1)
            fs:SetPoint("CENTER", preview, "CENTER", 0, 0)
            local saved = savedPositions[def.key] or {}
            local data = { anchorX = saved.anchorX or def.anchorX, anchorY = saved.anchorY or def.anchorY, offsetX = saved.offsetX or def.offsetX, offsetY = saved.offsetY or def.offsetY, justifyH = saved.justifyH or "CENTER", overrides = saved.overrides }
            local halfW, halfH = contentW / 2, contentH / 2
            local startX, startY = saved.posX or 0, saved.posY or 0
            if not saved.posX then
                if data.anchorX == "LEFT" then startX = -halfW + data.offsetX
                elseif data.anchorX == "RIGHT" then startX = halfW - data.offsetX end
            end
            if not saved.posY then
                if data.anchorY == "BOTTOM" then startY = -halfH + data.offsetY
                elseif data.anchorY == "TOP" then startY = halfH - data.offsetY end
            end
            if CreateDraggableComponent then
                local comp = CreateDraggableComponent(preview, def.key, fs, startX, startY, data)
                if comp then comp:SetFrameLevel(preview:GetFrameLevel() + 10); preview.components[def.key] = comp; fs:Hide() end
            end
        end
        return preview
    end
end
