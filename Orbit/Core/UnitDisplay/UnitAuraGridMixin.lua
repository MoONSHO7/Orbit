-- [ UNIT AURA GRID MIXIN ]--------------------------------------------------------------------------
-- Shared mixin for Target/Focus/Player buff and debuff grid plugins.
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants

Orbit.UnitAuraGridMixin = {}
local Mixin = Orbit.UnitAuraGridMixin

Mixin.sharedDebuffDefaults = {
    IconsPerRow = 8, MaxRows = 2, Spacing = 2, Width = 200, Scale = 100,
    PandemicGlowType = Constants.PandemicGlow.DefaultType,
    PandemicGlowColor = Constants.PandemicGlow.DefaultColor,
    PandemicGlowColorCurve = { pins = { { position = 0, color = { r = 1, g = 0.8, b = 0, a = 1 } } } },
}

Mixin.sharedBuffDefaults = {
    IconsPerRow = 8, MaxRows = 2, Spacing = 2, Width = 200, Scale = 100,
}

Mixin.playerBuffDefaults = {
    IconLimit = 20, Rows = 1, Spacing = 2, Scale = 100, aspectRatio = "1:1",
    ComponentPositions = {
        Timer = { anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0 },
        Stacks = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 1, offsetY = 1 },
    },
}

Mixin.playerDebuffDefaults = {
    IconLimit = 16, Rows = 1, Spacing = 2, Scale = 100, aspectRatio = "1:1",
    ComponentPositions = {
        Timer = { anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0 },
        Stacks = { anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 1, offsetY = 1 },
    },
}

local BASE_ICON_SIZE = 30
local ASPECT_RATIOS = {
    { text = "Square (1:1)", value = "1:1" }, { text = "Landscape (16:9)", value = "16:9" },
    { text = "Landscape (4:3)", value = "4:3" }, { text = "Ultrawide (21:9)", value = "21:9" },
}

local GetPreviewIcon = function() return Orbit.AuraPreview.GetSpellbookIcon() end

-- [ COLLAPSE ARROW ]--------------------------------------------------------------------------------
local ARROW_SIZE = 15
local ARROW_TEX_SIZE = { w = 10, h = 16 }
local COLLAPSED_AURA_COUNT = 3
local ARROW_ATLAS = "bag-arrow"

local function CreateCollapseArrow(frame, plugin)
    local btn = CreateFrame("Button", nil, frame)
    btn:SetSize(ARROW_SIZE, ARROW_SIZE * 2)
    btn:SetPoint("LEFT", frame, "TOPRIGHT", 4, -15)
    btn:SetFrameLevel(frame:GetFrameLevel() + 5)
    btn.tex = btn:CreateTexture(nil, "ARTWORK")
    btn.tex:SetSize(ARROW_TEX_SIZE.w, ARROW_TEX_SIZE.h)
    btn.tex:SetPoint("CENTER")
    btn.tex:SetAtlas(ARROW_ATLAS)
    btn.tex:SetAlpha(0.7)
    btn:SetScript("OnClick", function(self)
        local collapsed = not plugin:GetSetting(1, "Collapsed")
        plugin:SetSetting(1, "Collapsed", collapsed)
        plugin:UpdateAuras()
        if GameTooltip:IsOwned(self) then GameTooltip:SetText(self.tooltipText or "") end
    end)
    btn:SetScript("OnEnter", function(self)
        self.tex:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText or "")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self.tex:SetAlpha(0.6)
        GameTooltip:Hide()
    end)
    btn.tooltipText = plugin:GetSetting(1, "Collapsed") and "My Buffs" or "All Buffs"
    btn:Show()
    return btn
end

local function UpdateCollapseArrow(btn, collapsed, iconH, growthY)
    btn.tex:SetRotation(collapsed and math.rad(180) or 0)
    btn.tooltipText = collapsed and "My Buffs" or "All Buffs"
    btn:ClearAllPoints()
    if growthY == "UP" then
        btn:SetPoint("LEFT", btn:GetParent(), "BOTTOMRIGHT", 4, iconH / 2)
    else
        btn:SetPoint("LEFT", btn:GetParent(), "TOPRIGHT", 4, -(iconH / 2))
    end
end

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function ResolveGrowthDirection(frame)
    local anchors = OrbitEngine.FrameAnchor and OrbitEngine.FrameAnchor.anchors
    local a = anchors and anchors[frame]
    local growthX, growthY
    if a and a.parent then
        local edge = a.edge
        if edge == "TOP" then growthY = "UP"
        elseif edge == "BOTTOM" then growthY = "DOWN"
        elseif edge == "LEFT" then growthX = "LEFT"
        elseif edge == "RIGHT" then growthX = "RIGHT" end
    end
    if not growthX or not growthY then
        local point = frame:GetPoint(1)
        if point then
            if not growthX then
                if point:find("LEFT") then growthX = "RIGHT"
                elseif point:find("RIGHT") then growthX = "LEFT"
                else growthX = "CENTER" end
            end
            if not growthY then
                if point:find("TOP") then growthY = "DOWN"
                elseif point:find("BOTTOM") then growthY = "UP"
                else
                    local _, cy = frame:GetCenter()
                    local sh = UIParent:GetHeight()
                    growthY = (cy and cy > sh / 2) and "DOWN" or "UP"
                end
            end
        else
            growthX = growthX or "CENTER"
            growthY = growthY or "DOWN"
        end
    end
    local anchorY = (growthY == "UP") and "BOTTOM" or "TOP"
    if growthX == "CENTER" then return anchorY, growthX, growthY end
    local anchorX = (growthX == "LEFT") and "RIGHT" or "LEFT"
    return anchorY .. anchorX, growthX, growthY
end

local function CalculateIconSize(maxWidth, iconsPerRow, spacing)
    local totalSpacing = (iconsPerRow - 1) * spacing
    return math.max(1, math.floor((maxWidth - totalSpacing) / iconsPerRow))
end

local function CropIconTexture(icon, w, h)
    if not icon or not icon.Icon then return end
    if w == h then icon.Icon:SetTexCoord(0, 1, 0, 1); return end
    local crop = (1 - h / w) / 2
    icon.Icon:SetTexCoord(0, 1, crop, 1 - crop)
end

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Mixin:AddAuraGridSettings(dialog, systemFrame)
    local Frame = self._agFrame
    if not Frame then return end
    local cfg = self._agConfig
    local SB = OrbitEngine.SchemaBuilder
    local schema = { hideNativeSettings = true, controls = {} }

    if cfg.enablePandemic then
        SB:SetTabRefreshCallback(dialog, self, systemFrame)
        local currentTab = SB:AddSettingsTabs(schema, dialog, { "Layout", "Glows" }, "Layout")
        if currentTab == "Layout" then
            self:_addLayoutControls(schema)
        elseif currentTab == "Glows" then
            self:_addGlowControls(schema, SB, systemFrame)
        end
    else
        self:_addLayoutControls(schema)
    end

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

function Mixin:_addLayoutControls(schema)
    local cfg = self._agConfig
    if cfg.showIconLimit then
        table.insert(schema.controls, {
            type = "dropdown", key = "aspectRatio", label = "Icon Aspect Ratio",
            options = ASPECT_RATIOS, default = "1:1",
        })
        table.insert(schema.controls, {
            type = "slider", key = "IconLimit", label = "Icon Limit",
            min = 2, max = 40, step = 2, default = cfg.defaultIconLimit or 20,
            onChange = function(val) self:SetSetting(1, "IconLimit", val); self:ApplySettings() end,
        })
        local iconLimit = self:GetSetting(1, "IconLimit") or (cfg.defaultIconLimit or 20)
        local factors = {}
        for i = 1, iconLimit do if iconLimit % i == 0 then table.insert(factors, i) end end
        local currentRows = self:GetSetting(1, "Rows") or 1
        local currentIndex = 1
        for i, v in ipairs(factors) do if v == currentRows then currentIndex = i; break end end
        if #factors > 1 then
            table.insert(schema.controls, {
                type = "slider", key = "_RowsSlider", label = "Rows",
                min = 1, max = #factors, step = 1, default = currentIndex,
                formatter = function(v) return tostring(factors[math.floor(v)] or 1) end,
                onChange = function(val)
                    local newRows = factors[math.floor(val)] or 1
                    if newRows ~= self:GetSetting(1, "Rows") then
                        self:SetSetting(1, "Rows", newRows)
                        self:ApplySettings()
                    end
                end,
            })
        end
        table.insert(schema.controls, {
            type = "slider", key = "Scale", label = "Scale",
            min = 50, max = 200, step = 1, default = 100,
            formatter = function(v) return v .. "%" end,
            onChange = function(val) self:SetSetting(1, "Scale", val); self:ApplySettings() end,
        })
    else
        table.insert(schema.controls, {
            type = "slider", key = "IconsPerRow", label = "Icons Per Row",
            min = 4, max = 10, step = 1, default = 5,
            onChange = function(val) self:SetSetting(1, "IconsPerRow", val); self:ApplySettings() end,
        })
        table.insert(schema.controls, {
            type = "slider", key = "MaxRows", label = "Max Rows",
            min = 1, max = cfg.maxRowsMax or 4, step = 1, default = 2,
        })
        local isAnchored = OrbitEngine.Frame:GetAnchorParent(self._agFrame) ~= nil
        if not isAnchored then
            table.insert(schema.controls, {
                type = "slider", key = "Scale", label = "Scale",
                min = 50, max = 200, step = 1, default = 100,
            })
        end
    end
    table.insert(schema.controls, {
        type = "slider", key = "Spacing", label = "Spacing",
        min = -5, max = 50, step = 1, default = 2,
        onChange = function(val) self:SetSetting(1, "Spacing", val); self:ApplySettings() end,
    })

end

function Mixin:_addGlowControls(schema, SB, systemFrame)
    local GlowType = Constants.PandemicGlow.Type
    table.insert(schema.controls, {
        type = "dropdown", key = "PandemicGlowType", label = "Pandemic Glow",
        options = {
            { text = "None", value = GlowType.None },
            { text = "Pixel Glow", value = GlowType.Pixel },
            { text = "Proc Glow", value = GlowType.Proc },
            { text = "Autocast Shine", value = GlowType.Autocast },
            { text = "Button Glow", value = GlowType.Button },
        },
        default = Constants.PandemicGlow.DefaultType,
    })
    SB:AddColorCurveSettings(self, schema, 1, systemFrame, {
        key = "PandemicGlowColorCurve", label = "Pandemic Colour",
        default = { pins = { { position = 0, color = { r = 1, g = 0.8, b = 0, a = 1 } } } },
        singleColor = true,
    })
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Mixin:CreateAuraGridPlugin(config)
    self._agConfig = config
    local Frame = CreateFrame("Frame", config.frameName, UIParent)
    Frame:SetSize(config.initialWidth or 200, config.initialHeight or 20)
    OrbitEngine.Pixel:Enforce(Frame)
    RegisterUnitWatch(Frame)

    self.frame = Frame
    self._agFrame = Frame
    if config.exposeMountedConfig then self.mountedConfig = { frame = Frame } end
    Frame.unit = config.unit
    Frame:SetAttribute("unit", config.unit)

    Frame.editModeName = config.editModeName
    Frame.systemIndex = 1
    if config.anchorParent then
        Frame.anchorOptions = { horizontal = false, vertical = true }
    else
        Frame.anchorOptions = { syncScale = false, syncDimensions = false }
    end
    OrbitEngine.Frame:AttachSettingsListener(Frame, self, 1)

    -- Default position: anchor to parent frame or fallback
    local parentFrame = _G[config.anchorParent]
    if parentFrame then
        Frame:ClearAllPoints()
        Frame:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 0, config.anchorGap or -50)
        OrbitEngine.Frame:CreateAnchor(Frame, parentFrame, "BOTTOM", config.anchorGap or 50, nil, "LEFT")
    else
        Frame:SetPoint("CENTER", UIParent, "CENTER", config.defaultX or 0, config.defaultY or -220)
    end

    self:ApplySettings()

    -- [ CANVAS PREVIEW ]----------------------------------------------------------------------------
    if self.canvasMode then
        local plugin = self
        Frame.CreateCanvasPreview = function(self, options)
            local _, _, _, iconH, iconW = plugin:_resolveGrid()
            local parent = options.parent or UIParent
            local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            preview:SetSize(iconW, iconH)

            local borderSize = Orbit.db.GlobalSettings.BorderSize
            local borderPixels = OrbitEngine.Pixel:Multiple(borderSize)
            local contentW = iconW - (borderPixels * 2)
            local contentH = iconH - (borderPixels * 2)
            preview.sourceFrame = self
            preview.sourceWidth = contentW
            preview.sourceHeight = contentH
            preview.previewScale = 1
            preview.components = {}

            local icon = preview:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            icon:SetTexture(GetPreviewIcon())

            local backdrop = { bgFile = "Interface\\BUTTONS\\WHITE8x8", insets = { left = 0, right = 0, top = 0, bottom = 0 } }
            if borderSize > 0 then
                backdrop.edgeFile = "Interface\\BUTTONS\\WHITE8x8"
                backdrop.edgeSize = borderPixels
            end
            preview:SetBackdrop(backdrop)
            preview:SetBackdropColor(0, 0, 0, 0)
            if borderSize > 0 then preview:SetBackdropBorderColor(0, 0, 0, 1) end

            local savedPositions = plugin:GetSetting(1, "ComponentPositions") or {}
            local LSM = LibStub("LibSharedMedia-3.0")
            local fontPath = LSM:Fetch("font", Orbit.db.GlobalSettings.Font) or "Fonts\\FRIZQT__.TTF"
            local fontOutline = Orbit.Skin:GetFontOutline()

            local textComponents = {
                { key = "Timer", preview = string.format("%.1f", 3 + math.random() * 7), anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0 },
                { key = "Stacks", preview = "3", anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 1, offsetY = 1 },
            }

            local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent
            for _, def in ipairs(textComponents) do
                local fs = preview:CreateFontString(nil, "OVERLAY", nil, 7)
                fs:SetFont(fontPath, 12, fontOutline)
                fs:SetText(def.preview)
                fs:SetTextColor(1, 1, 1, 1)
                fs:SetPoint("CENTER", preview, "CENTER", 0, 0)

                local saved = savedPositions[def.key] or {}
                local data = {
                    anchorX = saved.anchorX or def.anchorX, anchorY = saved.anchorY or def.anchorY,
                    offsetX = saved.offsetX or def.offsetX, offsetY = saved.offsetY or def.offsetY,
                    justifyH = saved.justifyH or (def.anchorX == "LEFT" and "LEFT" or def.anchorX == "RIGHT" and "RIGHT" or "CENTER"),
                    overrides = saved.overrides,
                }

                local halfW, halfH = contentW / 2, contentH / 2
                local startX = saved.posX or (data.anchorX == "LEFT" and -halfW + data.offsetX or data.anchorX == "RIGHT" and halfW - data.offsetX or 0)
                local startY = saved.posY or (data.anchorY == "BOTTOM" and -halfH + data.offsetY or data.anchorY == "TOP" and halfH - data.offsetY or 0)

                if CreateDraggableComponent then
                    local comp = CreateDraggableComponent(preview, def.key, fs, startX, startY, data)
                    if comp then
                        comp:SetFrameLevel(preview:GetFrameLevel() + 10)
                        preview.components[def.key] = comp
                        fs:Hide()
                    end
                else
                    fs:ClearAllPoints()
                    fs:SetPoint("CENTER", preview, "CENTER", startX, startY)
                end
            end

            -- Dispel Icon (texture, not text)
            if config.isHarmful then
                local dispelTex = preview:CreateTexture(nil, "OVERLAY", nil, 7)
                dispelTex:SetSize(12, 12)
                dispelTex:SetAtlas("ui-debuff-border-magic-icon")
                dispelTex:SetPoint("CENTER", preview, "CENTER", 0, 0)

                local saved = savedPositions["DispelIcon"] or {}
                local data = {
                    anchorX = saved.anchorX or "LEFT", anchorY = saved.anchorY or "BOTTOM",
                    offsetX = saved.offsetX or 1, offsetY = saved.offsetY or 1,
                    overrides = saved.overrides,
                }
                local halfW, halfH = contentW / 2, contentH / 2
                local startX = saved.posX or (-halfW + data.offsetX)
                local startY = saved.posY or (-halfH + data.offsetY)

                if CreateDraggableComponent then
                    local comp = CreateDraggableComponent(preview, "DispelIcon", dispelTex, startX, startY, data)
                    if comp then
                        comp:SetFrameLevel(preview:GetFrameLevel() + 10)
                        preview.components["DispelIcon"] = comp
                        dispelTex:Hide()
                    end
                else
                    dispelTex:ClearAllPoints()
                    dispelTex:SetPoint("CENTER", preview, "CENTER", startX, startY)
                end
            end

            return preview
        end
    end

    function self:OnCanvasApply() self:UpdateAuras() end

    if config.showIconLimit and not config.isHarmful then
        Frame.collapseArrow = CreateCollapseArrow(Frame, self)
    end

    Frame:HookScript("OnShow", function()
        if not Orbit:IsEditMode() then self:UpdateAuras() end
    end)
    Frame:HookScript("OnSizeChanged", function()
        if Orbit:IsEditMode() then self:ResizePreviewAuras() else self:UpdateAuras() end
    end)

    Frame:RegisterUnitEvent("UNIT_AURA", config.unit)
    Frame:RegisterEvent(config.changeEvent)
    Frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    Frame:SetScript("OnEvent", function(f, event, unit)
        if Orbit:IsEditMode() and event == "UNIT_AURA" then return end
        if event == config.changeEvent or event == "PLAYER_ENTERING_WORLD" then
            self:UpdateVisibility()
            self:UpdateAuras()
        elseif event == "UNIT_AURA" and unit == f.unit then
            self:UpdateAuras()
        end
    end)

    OrbitEngine.EditMode:RegisterCallbacks({
        Enter = function() self._agFrame._previewTexCache = nil; self:UpdateVisibility() end,
        Exit = function() self:UpdateVisibility() end,
    }, self)

    self:UpdateVisibility()
end

-- [ UPDATE AURAS ]----------------------------------------------------------------------------------
function Mixin:_resolveGrid()
    local cfg = self._agConfig
    local spacing = self:GetSetting(1, "Spacing") or 2
    local maxAuras, iconsPerRow, iconH, iconW
    if cfg.showIconLimit then
        local iconLimit = self:GetSetting(1, "IconLimit") or (cfg.defaultIconLimit or 20)
        local rows = self:GetSetting(1, "Rows") or 1
        iconsPerRow = math.max(1, math.ceil(iconLimit / rows))
        maxAuras = iconLimit
        iconW = BASE_ICON_SIZE
        local ar = self:GetSetting(1, "aspectRatio") or "1:1"
        if ar == "16:9" then iconH = math.floor(iconW * 9 / 16)
        elseif ar == "4:3" then iconH = math.floor(iconW * 3 / 4)
        elseif ar == "21:9" then iconH = math.floor(iconW * 9 / 21)
        else iconH = iconW end
    else
        iconsPerRow = self:GetSetting(1, "IconsPerRow") or 5
        local maxRows = self:GetSetting(1, "MaxRows") or 2
        maxAuras = iconsPerRow * maxRows
        local maxWidth = self._agFrame:GetWidth()
        iconH = CalculateIconSize(maxWidth, iconsPerRow, spacing)
        iconW = iconH
    end
    return maxAuras, iconsPerRow, spacing, iconH, iconW
end

function Mixin:UpdateAuras()
    local Frame = self._agFrame
    local cfg = self._agConfig
    if not Frame then return end
    if not self:IsEnabled() then return end

    local collapsed = cfg.showIconLimit and not cfg.isHarmful and self:GetSetting(1, "Collapsed")

    local maxAuras, iconsPerRow, spacing, iconH, iconW = self:_resolveGrid()

    if not Frame.auraPool then self:CreateAuraPool(Frame, "BackdropTemplate") end
    Frame.auraPool:ReleaseAll()

    local anchor, growthX, growthY = ResolveGrowthDirection(Frame)
    if Frame.collapseArrow then
        UpdateCollapseArrow(Frame.collapseArrow, collapsed, iconH, growthY)
    end

    local auraFilter = collapsed and (cfg.auraFilter .. "|PLAYER|CANCELABLE") or cfg.auraFilter
    local auras = self:FetchAuras(cfg.unit, auraFilter, maxAuras)
    if #auras == 0 then
        if collapsed then Frame:SetSize(iconW, iconH) end
        return
    end
    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = Orbit.db.GlobalSettings.BorderSize, showTimer = cfg.showTimer }
    if cfg.enablePandemic then
        skinSettings.enablePandemic = true
        skinSettings.pandemicGlowType = self:GetSetting(1, "PandemicGlowType") or Constants.PandemicGlow.DefaultType
        skinSettings.pandemicGlowColor = OrbitEngine.ColorCurve:GetFirstColorFromCurve(self:GetSetting(1, "PandemicGlowColorCurve")) or self:GetSetting(1, "PandemicGlowColor") or Constants.PandemicGlow.DefaultColor
    end

    local componentPositions = self:GetSetting(1, "ComponentPositions")
    local activeIcons = {}
    local tooltipFilter = cfg.auraFilter
    for _, aura in ipairs(auras) do
        local icon = Frame.auraPool:Acquire()
        icon:SetSize(iconW, iconH)
        self:SetupAuraIcon(icon, aura, iconH, cfg.unit, skinSettings, componentPositions)
        icon:SetSize(iconW, iconH)
        CropIconTexture(icon, iconW, iconH)
        self:SetupAuraTooltip(icon, aura, cfg.unit, tooltipFilter)
        table.insert(activeIcons, icon)
    end

    Orbit.AuraLayout:LayoutGrid(Frame, activeIcons, {
        size = iconH, sizeW = iconW, spacing = spacing, maxPerRow = iconsPerRow,
        anchor = anchor, growthX = growthX, growthY = growthY, yOffset = 0,
    })
end

-- [ VISIBILITY ]-------------------------------------------------------------------------------------
function Mixin:UpdateVisibility()
    local Frame = self._agFrame
    local cfg = self._agConfig
    if not Frame then return end

    local enabled = self:IsEnabled()
    local isEditMode = Orbit:IsEditMode()

    if isEditMode then
        if not InCombatLockdown() then UnregisterUnitWatch(Frame) end
        if enabled then
            OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false)
            if not UnitExists(cfg.unit) then Frame.unit = "player" end
            Orbit:SafeAction(function() Frame:Show(); Frame:SetAlpha(1) end)
            self:ShowPreviewAuras()
        else
            OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
            Orbit:SafeAction(function() Frame:Hide() end)
        end
        return
    end

    Frame.unit = cfg.unit
    if Frame.previewPool then Frame.previewPool:ReleaseAll() end

    if enabled then
        if not InCombatLockdown() then RegisterUnitWatch(Frame) end
        if UnitExists(cfg.unit) then self:UpdateAuras() end
    else
        if not InCombatLockdown() then
            UnregisterUnitWatch(Frame)
            Frame:Hide()
            OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
        end
    end

    if enabled then OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, false) end
end

-- [ PREVIEW ]---------------------------------------------------------------------------------------


function Mixin:ShowPreviewAuras()
    if InCombatLockdown() then return end
    local Frame = self._agFrame
    local cfg = self._agConfig
    local maxAuras, iconsPerRow, spacing, iconH, iconW = self:_resolveGrid()

    -- Resize frame to tightly fit the icon grid
    local rows = cfg.showIconLimit and (self:GetSetting(1, "Rows") or 1) or (self:GetSetting(1, "MaxRows") or 2)
    local width = (iconsPerRow * iconW) + ((iconsPerRow - 1) * spacing)
    local height = (rows * iconH) + ((rows - 1) * spacing)
    Frame:SetSize(math.max(1, width), math.max(1, height))

    if not Frame.previewPool then Frame.previewPool = self:CreateAuraPool(Frame, "BackdropTemplate") end
    -- Snapshot existing textures before release
    Frame._previewTexCache = Frame._previewTexCache or {}
    local cache = Frame._previewTexCache
    Frame.previewPool:ReleaseAll()

    local isDebuff = cfg.isHarmful
    local renderCount = math.ceil(maxAuras * 0.6)
    local previews = {}
    for i = 1, renderCount do
        local icon = Frame.previewPool:Acquire()
        icon:SetSize(iconW, iconH)
        local tex = cache[i] or GetPreviewIcon()
        cache[i] = tex
        self:SetupAuraIcon(icon, {
            icon = tex, applications = i, duration = 0,
            expirationTime = 0, index = i, isHarmful = isDebuff,
        }, iconH, "player", Orbit.Constants.Aura.SkinNoTimer)
        icon:SetSize(iconW, iconH)
        CropIconTexture(icon, iconW, iconH)

        icon:SetScript("OnEnter", nil)
        icon:SetScript("OnLeave", nil)
        table.insert(previews, icon)
    end
    -- Trim cache if count decreased
    for i = renderCount + 1, #cache do cache[i] = nil end

    Frame._activePreviewIcons = previews
    local anchor, growthX, growthY = ResolveGrowthDirection(Frame)
    Orbit.AuraLayout:LayoutGrid(Frame, previews, {
        size = iconH, sizeW = iconW, spacing = spacing, maxPerRow = iconsPerRow,
        anchor = anchor, growthX = growthX, growthY = growthY, yOffset = 0,
    })
end

-- Lightweight resize: reuse existing preview icons, just resize and re-layout
function Mixin:ResizePreviewAuras()
    local Frame = self._agFrame
    if not Frame or not Frame._activePreviewIcons or #Frame._activePreviewIcons == 0 then return end
    local _, iconsPerRow, spacing, iconH, iconW = self:_resolveGrid()
    for _, icon in ipairs(Frame._activePreviewIcons) do
        icon:SetSize(iconW, iconH)
        CropIconTexture(icon, iconW, iconH)
    end
    local anchor, growthX, growthY = ResolveGrowthDirection(Frame)
    Orbit.AuraLayout:LayoutGrid(Frame, Frame._activePreviewIcons, {
        size = iconH, sizeW = iconW, spacing = spacing, maxPerRow = iconsPerRow,
        anchor = anchor, growthX = growthX, growthY = growthY, yOffset = 0,
    })
end

-- [ APPLY SETTINGS ]--------------------------------------------------------------------------------
function Mixin:ApplySettings()
    local Frame = self._agFrame
    if not Frame or InCombatLockdown() then return end

    local cfg = self._agConfig
    local isAnchored = OrbitEngine.Frame:GetAnchorParent(Frame) ~= nil
    local _, iconsPerRow, spacing, iconH, iconW = self:_resolveGrid()
    Frame.iconSize = iconH
    local rows
    if cfg.showIconLimit then
        local scale = self:GetSetting(1, "Scale") or 100
        Frame:SetScale(scale / 100)
        rows = self:GetSetting(1, "Rows") or 1
        local width = (iconsPerRow * iconW) + ((iconsPerRow - 1) * spacing)
        Frame:SetWidth(math.max(1, width))
    elseif not isAnchored then
        local scale = self:GetSetting(1, "Scale") or 100
        Frame:SetScale(scale / 100)
        local width = self:GetSetting(1, "Width")
        if width then Frame:SetWidth(width) end
        rows = self:GetSetting(1, "MaxRows") or 2
    else
        Frame:SetScale(1)
        local parent = OrbitEngine.Frame:GetAnchorParent(Frame)
        if parent then Frame:SetWidth(parent:GetWidth()) end
        rows = self:GetSetting(1, "MaxRows") or 2
    end
    local height = math.max(1, (rows * iconH) + ((rows - 1) * spacing))
    Frame:SetHeight(height)

    OrbitEngine.Frame:RestorePosition(Frame, self, 1)
    self:UpdateVisibility()
end

-- [ UPDATE LAYOUT ]---------------------------------------------------------------------------------
function Mixin:UpdateLayout()
    local Frame = self._agFrame
    if not Frame then return end

    local cfg = self._agConfig
    local _, iconsPerRow, spacing, iconH, iconW = self:_resolveGrid()
    Frame.iconSize = iconH
    local rows
    if cfg.showIconLimit then
        rows = self:GetSetting(1, "Rows") or 1
        local width = (iconsPerRow * iconW) + ((iconsPerRow - 1) * spacing)
        Frame:SetWidth(math.max(1, width))
    else
        rows = self:GetSetting(1, "MaxRows") or 2
    end
    local height = math.max(1, (rows * iconH) + ((rows - 1) * spacing))
    Frame:SetHeight(height)

    if Orbit:IsEditMode() then self:ResizePreviewAuras() else self:UpdateAuras() end
end
