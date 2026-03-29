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

local BASE_ICON_SIZE = 32
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
    btn:SetFrameLevel(frame:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
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

local ARROW_OFFSET = 4
local function UpdateCollapseArrow(btn, collapsed, iconH, growthX, growthY)
    local onLeft = (growthX == "RIGHT")
    local baseRot = onLeft and math.rad(180) or 0
    btn.tex:SetRotation(collapsed and (math.pi - baseRot) or baseRot)
    btn.tooltipText = collapsed and "My Buffs" or "All Buffs"
    btn:ClearAllPoints()
    local parent = btn:GetParent()
    if onLeft then
        local anchorY = (growthY == "UP") and "BOTTOMLEFT" or "TOPLEFT"
        local yOff = (growthY == "UP") and (iconH / 2) or -(iconH / 2)
        btn:SetPoint("RIGHT", parent, anchorY, -ARROW_OFFSET, yOff)
    else
        local anchorY = (growthY == "UP") and "BOTTOMRIGHT" or "TOPRIGHT"
        local yOff = (growthY == "UP") and (iconH / 2) or -(iconH / 2)
        btn:SetPoint("LEFT", parent, anchorY, ARROW_OFFSET, yOff)
    end
end

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function ResolveGrowthDirection(frame, noCenterGrowth)
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
    if noCenterGrowth and growthX == "CENTER" then
        local cx = frame:GetCenter()
        local sw = UIParent:GetWidth()
        growthX = (cx and cx > sw / 2) and "LEFT" or "RIGHT"
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

local function CropIconTexture(iconFrame, w, h)
    local tex = iconFrame and (iconFrame.Icon or iconFrame.icon)
    if not tex then return end
    local trim = Orbit.Constants and Orbit.Constants.Texture and Orbit.Constants.Texture.BlizzardIconBorderTrim or 0.07
    if w == h then 
        tex:SetTexCoord(trim, 1 - trim, trim, 1 - trim)
        return 
    end
    -- Support for non-1:1 Aspect Ratios while respecting zoom/trim
    local validW = 1 - (2 * trim)
    local crop = (validW - validW * (h / w)) / 2
    tex:SetTexCoord(trim, 1 - trim, trim + crop, 1 - trim - crop)
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
        min = 0, max = 50, step = 1, default = 2,
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
            { text = "Blizzard", value = GlowType.Blizzard },
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
    Frame:SetClampedToScreen(true)
    RegisterUnitWatch(Frame)

    self.frame = Frame
    self._agFrame = Frame
    if config.exposeMountedConfig then self.mountedConfig = { frame = Frame } end
    local vePlugin = config.vePluginName and Orbit:GetPlugin(config.vePluginName) or self
    local veIndex = config.veSystemIndex or 1
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(Frame, vePlugin, veIndex) end
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
        local hasSavedAnchor = self:GetSetting(1, "Anchor")
        local hasSavedPosition = self:GetSetting(1, "Position")
        if not hasSavedAnchor and not hasSavedPosition then
            Frame:ClearAllPoints()
            Frame:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 0, config.anchorGap or -50)
            OrbitEngine.Frame:CreateAnchor(Frame, parentFrame, "BOTTOM", config.anchorGap or 50, nil, "LEFT")
        end
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
            preview.sourceFrame = self
            preview.sourceWidth = iconW
            preview.sourceHeight = iconH
            preview.borderInset = borderPixels
            preview.previewScale = 1
            preview.components = {}

            local icon = preview:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            icon:SetTexture(GetPreviewIcon())

            local backdrop = { bgFile = "Interface\\BUTTONS\\WHITE8x8", insets = { left = 0, right = 0, top = 0, bottom = 0 } }
            preview:SetBackdrop(backdrop)
            preview:SetBackdropColor(0, 0, 0, 0)
            Orbit.Skin:SkinBorder(preview, preview, borderSize, nil, true)

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

                local halfW, halfH = iconW / 2, iconH / 2
                local startX = saved.posX or (data.anchorX == "LEFT" and -halfW + data.offsetX or data.anchorX == "RIGHT" and halfW - data.offsetX or 0)
                local startY = saved.posY or (data.anchorY == "BOTTOM" and -halfH + data.offsetY or data.anchorY == "TOP" and halfH - data.offsetY or 0)

                if CreateDraggableComponent then
                    local comp = CreateDraggableComponent(preview, def.key, fs, startX, startY, data)
                    if comp then
                        comp:SetFrameLevel(preview:GetFrameLevel() + Orbit.Constants.Levels.Overlay)
                        preview.components[def.key] = comp
                        fs:Hide()
                    end
                else
                    fs:ClearAllPoints()
                    fs:SetPoint("CENTER", preview, "CENTER", startX, startY)
                end
            end



            return preview
        end
    end

    function self:OnCanvasApply() Frame._orbitSkinVersion = (Frame._orbitSkinVersion or 0) + 1; self:UpdateAuras() end

    if config.showIconLimit and not config.isHarmful then
        Frame.collapseArrow = CreateCollapseArrow(Frame, self)
    end

    Frame:HookScript("OnShow", function()
        if not Orbit:IsEditMode() then self:UpdateAuras() end
    end)
    Frame:HookScript("OnSizeChanged", function()
        if Orbit:IsEditMode() then self:ResizePreviewAuras() else self:UpdateAuras() end
    end)
    if config.useBlizzardButtons and EditModeManagerFrame then
        EditModeManagerFrame:HookScript("OnHide", function()
            Frame._orbitSkinVersion = (Frame._orbitSkinVersion or 0) + 1
            self:ApplySettings()
        end)
    end

    if config.useBlizzardButtons then
        -- Hook Blizzard's BuffFrame update cycle instead of our own events
        -- Defer to clean context: hooksecurefunc runs in tainted context where all API returns are secret
        local blizzFrame = config.blizzardFrame
        if blizzFrame then
            hooksecurefunc(blizzFrame, "Update", function()
                if Orbit:IsEditMode() then return end
                if not Frame._blizzDirty then
                    Frame._blizzDirty = true
                    C_Timer.After(0, function()
                        Frame._blizzDirty = false
                        self:UpdateAuras()
                    end)
                end
            end)
        end
        Frame:RegisterEvent(config.changeEvent)
        Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        Frame:SetScript("OnEvent", function(f, event)
            if Orbit:IsEditMode() then return end
            self:UpdateVisibility()
            self:UpdateAuras()
        end)
    else
        Frame:RegisterUnitEvent("UNIT_AURA", config.unit)
        Frame:RegisterEvent(config.changeEvent)
        Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        if config.unit == "player" and not config.isHarmful then
            Frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
        Frame:SetScript("OnEvent", function(f, event, unit)
            if Orbit:IsEditMode() then return end
            if event == config.changeEvent or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
                self:UpdateVisibility()
                self:UpdateAuras()
            elseif event == "UNIT_AURA" and unit == f.unit then
                self:UpdateAuras()
            end
        end)
    end

    OrbitEngine.EditMode:RegisterCallbacks({
        Enter = function()
            if config.useBlizzardButtons then self:_returnBlizzardButtons() end
            self._agFrame._previewTexCache = nil; self:UpdateVisibility()
        end,
        Exit = function()
            if config.useBlizzardButtons then self:_returnBlizzardButtons() end
            self:UpdateVisibility()
        end,
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
    local cfg = self._agConfig
    if cfg and cfg.useBlizzardButtons then return self:_updateBlizzardBuffs() end
    local Frame = self._agFrame
    if not Frame then return end
    if not self:IsEnabled() then return end

    local collapsed = cfg.showIconLimit and not cfg.isHarmful and self:GetSetting(1, "Collapsed")
    local cancelable = cfg.unit == "player" and not cfg.isHarmful
    local maxAuras, iconsPerRow, spacing, iconH, iconW = self:_resolveGrid()

    if not Frame.auraPool then self:CreateAuraPool(Frame, "BackdropTemplate") end
    Frame.auraPool:ReleaseAll()

    local anchor, growthX, growthY = ResolveGrowthDirection(Frame, cfg.showIconLimit)
    if Frame.collapseArrow then
        UpdateCollapseArrow(Frame.collapseArrow, collapsed, iconH, growthX, growthY)
    end

    local auraFilter = collapsed and (cfg.auraFilter .. "|PLAYER|CANCELABLE") or cfg.auraFilter
    local auras = self:FetchAuras(cfg.unit, auraFilter, maxAuras)
    if #auras == 0 then
        if collapsed and not InCombatLockdown() then Frame:SetSize(iconW, iconH) end
        if cancelable and not InCombatLockdown() then self:_hideCancelOverlays(Frame) end
        if Frame._gridGroupBorder then Frame._gridGroupBorder:Hide() end
        return
    end
    local isPlayerGrid = cfg.showIconLimit
    local skinBorderSize = isPlayerGrid and (Orbit.db.GlobalSettings.IconBorderSize or 2) or 1
    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = skinBorderSize, showTimer = cfg.showTimer, iconBorder = isPlayerGrid or nil, padding = spacing, aspectRatio = self:GetSetting(1, "aspectRatio") or "1:1" }
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
    if isPlayerGrid then skinSettings._maxPerRow = iconsPerRow; skinSettings._growthX = growthX; skinSettings._growthY = growthY; self:_applyGridGroupBorder(Frame, activeIcons, spacing, skinSettings) end

    if cancelable and not InCombatLockdown() then
        self:_syncCancelOverlays(Frame, auras, auraFilter, activeIcons)
    end
end

-- [ BLIZZARD BUTTON REPARENTING ]-------------------------------------------------------------------
function Mixin:_updateBlizzardBuffs()
    local Frame = self._agFrame
    local cfg = self._agConfig
    if not Frame then return end
    if not self:IsEnabled() then return end
    if Orbit:IsEditMode() then return end

    local blizzFrame = cfg.blizzardFrame
    if not blizzFrame or not blizzFrame.auraFrames then return end

    local collapsed = cfg.showIconLimit and self:GetSetting(1, "Collapsed")
    local maxAuras, iconsPerRow, spacing, iconH, iconW = self:_resolveGrid()
    local anchor, growthX, growthY = ResolveGrowthDirection(Frame, cfg.showIconLimit)
    if Frame.collapseArrow then UpdateCollapseArrow(Frame.collapseArrow, collapsed, iconH, growthX, growthY) end

    -- When collapsed, build a set of HELPFUL indices that are player-cast and not excluded
    -- auraInstanceID is the ONLY non-secret field; use C-side filter HELPFUL|PLAYER to identify player auras
    -- spellId may be non-secret from clean context; use issecretvalue guard
    local showIndices
    if collapsed then
        local IsSecret = issecretvalue
        local excludedSpells = Orbit.GroupAuraFilters and Orbit.GroupAuraFilters.AlwaysExcluded or {}
        local playerIDs = {}
        AuraUtil.ForEachAura("player", "HELPFUL|PLAYER", 40, function(aura)
            playerIDs[aura.auraInstanceID] = true
        end, true)
        showIndices = {}
        local idx = 0
        AuraUtil.ForEachAura("player", "HELPFUL", 40, function(aura)
            idx = idx + 1
            local sid = aura.spellId
            local isExcluded = not IsSecret(sid) and excludedSpells[sid]
            if playerIDs[aura.auraInstanceID] and not isExcluded then showIndices[idx] = true end
        end, true)
    end

    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    local fontPath = (LSM and fontName and LSM:Fetch("font", fontName)) or "Fonts\\FRIZQT__.TTF"
    local fontOutline = Orbit.Skin and Orbit.Skin.GetFontOutline and Orbit.Skin:GetFontOutline() or ""
    local timerFontSize = 8
    local countFontSize = 8
    local isPlayerGrid = self._agConfig and self._agConfig.unit == "player"
    local skinBorderSize = isPlayerGrid and (Orbit.db.GlobalSettings.IconBorderSize or 2) or 1
    local skinSettings = { zoom = 0, borderStyle = 1, borderSize = skinBorderSize, showTimer = true, iconBorder = isPlayerGrid or nil, padding = spacing, aspectRatio = self:GetSetting(1, "aspectRatio") or "1:1" }
    local componentPositions = self:GetSetting(1, "ComponentPositions") or {}
    local OverrideUtils = OrbitEngine.OverrideUtils

    local function ApplyComponentPosition(textElement, btn, key, defaultAnchorX, defaultAnchorY, defaultOffsetX, defaultOffsetY)
        if not textElement then return end
        local pos = componentPositions[key] or {}
        local anchorX = pos.anchorX or defaultAnchorX
        local anchorY = pos.anchorY or defaultAnchorY
        local offsetX = pos.offsetX or defaultOffsetX
        local offsetY = pos.offsetY or defaultOffsetY
        local justifyH = pos.justifyH or "CENTER"
        local anchorPoint
        if anchorY == "CENTER" and anchorX == "CENTER" then anchorPoint = "CENTER"
        elseif anchorY == "CENTER" then anchorPoint = anchorX
        elseif anchorX == "CENTER" then anchorPoint = anchorY
        else anchorPoint = anchorY .. anchorX end
        local textPoint = justifyH == "LEFT" and "LEFT" or justifyH == "RIGHT" and "RIGHT" or "CENTER"
        local finalOffsetX = anchorX == "LEFT" and offsetX or -offsetX
        local finalOffsetY = anchorY == "BOTTOM" and offsetY or -offsetY
        textElement:ClearAllPoints()
        textElement:SetPoint(textPoint, btn, anchorPoint, finalOffsetX, finalOffsetY)
        if textElement.SetJustifyH then textElement:SetJustifyH(justifyH) end
    end

    -- Build clean index→DurationObject map from untainted AuraUtil context
    local durObjByIndex = {}
    local durIdx = 0
    AuraUtil.ForEachAura(cfg.unit, "HELPFUL", 40, function(aura)
        durIdx = durIdx + 1
        if aura.auraInstanceID then
            local durObj = C_UnitAuras.GetAuraDuration(cfg.unit, aura.auraInstanceID)
            if durObj then durObjByIndex[durIdx] = durObj end
        end
    end, true)

    local skinVersion = (Frame._orbitSkinVersion or 0)
    local activeIcons = {}
    for _, btn in ipairs(blizzFrame.auraFrames) do
        if btn.hasValidInfo and not btn.isAuraAnchor then
            local bi = btn.buttonInfo
            -- When collapsed: hide temp enchants and non-player buffs
            local excluded = collapsed and (bi.auraType ~= "Buff" or not showIndices[bi.index])
            if excluded or #activeIcons >= maxAuras then
                if btn:GetParent() == Frame then
                    btn:SetParent(blizzFrame.AuraContainer)
                    btn._orbitSkinned = nil
                end
                btn:EnableMouse(false)
                btn:Hide()
            else
                -- Full setup only on first reparent or settings change
                if btn._orbitSkinned ~= skinVersion then
                    btn:SetParent(Frame)
                    btn:SetFrameLevel(Frame:GetFrameLevel() + Orbit.Constants.Levels.StatusBar)
                    btn:SetScale(1)
                    btn:SetAlpha(1)
                    btn:SetSize(iconW, iconH)
                    CropIconTexture(btn, iconW, iconH)
                    Orbit.Skin.Icons:ApplyCustom(btn, skinSettings)
                    btn.Duration:Hide()
                    if btn.TempEnchantBorder then btn.TempEnchantBorder:Hide() end
                    
                    -- Permanently suppress Blizzard's native border textures
                    local nt = btn.GetNormalTexture and btn:GetNormalTexture() or btn.NormalTexture
                    if nt then
                        nt:SetAlpha(0); nt:Hide()
                        if not btn.orbitNormalTextureHooked then
                            hooksecurefunc(nt, "Show", function(self) self:Hide(); self:SetAlpha(0) end)
                            btn.orbitNormalTextureHooked = true
                        end
                    end
                    local nativeBorder = btn.Border or btn.IconBorder
                    if nativeBorder then
                        nativeBorder:SetAlpha(0); nativeBorder:Hide()
                        if not btn.orbitBorderHooked then
                            hooksecurefunc(nativeBorder, "Show", function(self) self:Hide(); self:SetAlpha(0) end)
                            btn.orbitBorderHooked = true
                        end
                    end
                    
                    -- Resize Blizzard's DebuffBorder (already has dispel type color) to 1px larger all around
                    if btn.DebuffBorder then
                        btn.DebuffBorder:ClearAllPoints()
                        btn.DebuffBorder:SetPoint("CENTER", btn, "CENTER", 0, 0)
                        btn.DebuffBorder:SetSize(iconW + 2, iconH + 2)
                        btn.DebuffBorder:SetDrawLayer("OVERLAY", 6)
                    end
                    -- Cooldown frame for timer
                    if not btn.Cooldown then
                        btn.Cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
                        btn.Cooldown:SetAllPoints()
                        btn.Cooldown:SetHideCountdownNumbers(false)
                        btn.Cooldown:EnableMouse(false)
                        btn.cooldown = btn.Cooldown
                    end
                    -- Text overlay above border
                    if not btn.orbitTextOverlay then
                        btn.orbitTextOverlay = CreateFrame("Frame", nil, btn)
                        btn.orbitTextOverlay:SetAllPoints(btn)
                        btn.orbitTextOverlay:SetFrameLevel(btn:GetFrameLevel() + Orbit.Constants.Levels.IconOverlay)
                    end
                    -- Style timer text
                    local timerText = btn.Cooldown.Text
                    if not timerText then
                        for _, region in pairs({ btn.Cooldown:GetRegions() }) do
                            if region:IsObjectType("FontString") then timerText = region; break end
                        end
                        btn.Cooldown.Text = timerText
                    end
                    if timerText and timerText.SetFont then
                        timerText:SetParent(btn.orbitTextOverlay)
                        if OverrideUtils then OverrideUtils.ApplyOverrides(timerText, (componentPositions.Timer or {}).overrides or {}, { fontSize = timerFontSize, fontPath = fontPath }) end
                        timerText:SetDrawLayer("OVERLAY", 7)
                        ApplyComponentPosition(timerText, btn, "Timer", "CENTER", "CENTER", 0, 0)
                    end
                    -- Style stacks
                    btn.Count:SetParent(btn.orbitTextOverlay)
                    if OverrideUtils then OverrideUtils.ApplyOverrides(btn.Count, (componentPositions.Stacks or {}).overrides or {}, { fontSize = countFontSize, fontPath = fontPath }) end
                    btn.Count:SetShadowColor(0, 0, 0, 1)
                    btn.Count:SetShadowOffset(1, -1)
                    btn.Count:SetDrawLayer("OVERLAY", 7)
                    ApplyComponentPosition(btn.Count, btn, "Stacks", "RIGHT", "BOTTOM", 1, 1)
                    btn._orbitSkinned = skinVersion
                end
                -- Lightweight refresh: enforce size (Blizzard may resize between skin cycles)
                btn:EnableMouse(true)
                btn:SetSize(iconW, iconH)
                CropIconTexture(btn, iconW, iconH)
                btn.Cooldown:Clear()
                if btn.Cooldown.Text then btn.Cooldown.Text:SetText("") end
                local durObj = bi and bi.index and durObjByIndex[bi.index]
                if durObj then btn.Cooldown:SetCooldownFromDurationObject(durObj) end
                btn:Show()
                table.insert(activeIcons, btn)
            end
        end
    end

    if #activeIcons == 0 then
        if Frame._gridGroupBorder then Frame._gridGroupBorder:Hide() end
        return
    end
    Orbit.AuraLayout:LayoutGrid(Frame, activeIcons, {
        size = iconH, sizeW = iconW, spacing = spacing, maxPerRow = iconsPerRow,
        anchor = anchor, growthX = growthX, growthY = growthY, yOffset = 0,
    })
    skinSettings._maxPerRow = iconsPerRow
    skinSettings._growthX = growthX
    skinSettings._growthY = growthY
    self:_applyGridGroupBorder(Frame, activeIcons, spacing, skinSettings)
end

-- [ GRID GROUP BORDER ]-----------------------------------------------------------------------------
function Mixin:_applyGridGroupBorder(Frame, activeIcons, spacing, skinSettings)
    if not skinSettings.iconBorder or spacing ~= 0 or #activeIcons == 0 or Frame._groupBorderActive then
        if Frame._gridGroupBorder then Frame._gridGroupBorder:Hide() end
        return
    end
    local firstIcon = activeIcons[1]
    local iconW, iconH = firstIcon:GetWidth(), firstIcon:GetHeight()
    local maxPerRow = skinSettings._maxPerRow or math.huge
    local cols = math.min(#activeIcons, maxPerRow)
    local rows = math.ceil(#activeIcons / maxPerRow)
    local gridW = (cols * iconW) + (math.max(0, cols - 1) * spacing)
    local gridH = (rows * iconH) + (math.max(0, rows - 1) * spacing)
    local gx = skinSettings._growthX or "RIGHT"
    local gy = skinSettings._growthY or "DOWN"
    if not Frame._gridGroupBorder then
        Frame._gridGroupBorder = CreateFrame("Frame", nil, Frame, "BackdropTemplate")
    end
    local overlay = Frame._gridGroupBorder
    overlay:SetFrameLevel(Frame:GetFrameLevel() + Orbit.Constants.Levels.Border)
    local Skin = Orbit.Skin
    local gs = Orbit.db and Orbit.db.GlobalSettings
    local iconNineSlice = Skin:GetActiveIconBorderStyle()
    local scale = Frame:GetEffectiveScale()
    if not scale or scale < 0.01 then scale = 1 end
    -- Compute directional offsets from first icon's origin corner
    local extX = (gx == "LEFT") and -gridW or gridW
    local extY = (gy == "UP") and gridH or -gridH
    local iconAnchor = ((gy == "UP") and "BOTTOM" or "TOP") .. ((gx == "LEFT") and "RIGHT" or "LEFT")
    local outset = 0
    overlay:ClearAllPoints()
    if iconNineSlice and iconNineSlice.edgeFile then
        local style = Skin:BuildIconStyle(iconNineSlice)
        local edgeSize = style.edgeSize or 16
        local borderOffset = style.borderOffset or 0
        outset = Orbit.Engine.Pixel:Snap((edgeSize / 2) + borderOffset, scale)
        local osX = (gx == "LEFT") and outset or -outset
        local osY = (gy == "UP") and -outset or outset
        overlay:SetPoint("TOPLEFT", firstIcon, iconAnchor, math.min(osX, extX - osX), math.max(osY, extY - osY))
        overlay:SetPoint("BOTTOMRIGHT", firstIcon, iconAnchor, math.max(osX, extX - osX), math.min(osY, extY - osY))
        overlay:SetBackdrop({ edgeFile = style.edgeFile, edgeSize = edgeSize })
        overlay:SetBackdropBorderColor(1, 1, 1, 1)
    else
        local borderSize = gs and gs.IconBorderSize or 2
        if borderSize <= 0 then overlay:Hide(); return end
        overlay:SetPoint("TOPLEFT", firstIcon, iconAnchor, math.min(0, extX), math.max(0, extY))
        overlay:SetPoint("BOTTOMRIGHT", firstIcon, iconAnchor, math.max(0, extX), math.min(0, extY))
        local pixelSize = Orbit.Engine.Pixel:Multiple(borderSize, scale)
        overlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = pixelSize })
        local c = (gs and gs.IconBorderColor) or { r = 0, g = 0, b = 0, a = 1 }
        overlay:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
    end
    overlay:Show()
    for _, icon in ipairs(activeIcons) do
        if icon._borderFrame then icon._borderFrame:Hide() end
        if icon._edgeBorderOverlay then icon._edgeBorderOverlay:Hide() end
    end
end

function Mixin:_returnBlizzardButtons()
    local cfg = self._agConfig
    if not cfg or not cfg.useBlizzardButtons then return end
    local blizzFrame = cfg.blizzardFrame
    if not blizzFrame or not blizzFrame.auraFrames then return end
    for _, btn in ipairs(blizzFrame.auraFrames) do
        if not btn.isAuraAnchor then btn:SetParent(blizzFrame.AuraContainer) end
    end
end

-- [ CANCEL OVERLAYS ]-------------------------------------------------------------------------------
function Mixin:_syncCancelOverlays(frame, auras, auraFilter, icons)
    if not frame._cancelButtons then frame._cancelButtons = {} end
    local indexMap = {}
    for i = 1, 40 do
        local data = C_UnitAuras.GetAuraDataByIndex("player", i, auraFilter)
        if not data then break end
        indexMap[data.auraInstanceID] = i
    end
    for i, aura in ipairs(auras) do
        local btn = frame._cancelButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
            btn:RegisterForClicks("RightButtonUp")
            btn:SetAttribute("type2", "cancelaura")
            btn:SetAttribute("unit", "player")
            btn:EnableMouse(true)
            btn:SetMouseMotionEnabled(false)
            btn:SetPassThroughButtons("LeftButton")
            btn:SetAlpha(0)
            btn:SetFrameStrata("HIGH")
            frame._cancelButtons[i] = btn
        end
        local idx = indexMap[aura.auraInstanceID]
        local icon = icons[i]
        if idx and icon then
            btn:SetAttribute("index", idx)
            btn:SetAttribute("filter", auraFilter)
            btn:ClearAllPoints()
            local point, relativeTo, relativePoint, x, y = icon:GetPoint(1)
            btn:SetPoint(point, relativeTo, relativePoint, x, y)
            btn:SetSize(icon:GetSize())
            btn:Show()
        else
            btn:Hide()
        end
    end
    for i = #auras + 1, #frame._cancelButtons do
        frame._cancelButtons[i]:Hide()
    end
end

function Mixin:_hideCancelOverlays(frame)
    if not frame._cancelButtons then return end
    for _, btn in ipairs(frame._cancelButtons) do btn:Hide() end
end

-- [ VISIBILITY ]-------------------------------------------------------------------------------------
function Mixin:UpdateVisibility()
    local Frame = self._agFrame
    local cfg = self._agConfig
    if not Frame then return end
    if not Orbit:IsPluginEnabled(self.name) then
        if not InCombatLockdown() then UnregisterUnitWatch(Frame); Frame:Hide() end
        OrbitEngine.FrameAnchor:SetFrameDisabled(Frame, true)
        return
    end
    if self.mountedConfig and Orbit.MountedVisibility:IsCachedHidden() then
        local cfg = self._agConfig
        local vePlugin = cfg and cfg.vePluginName and Orbit:GetPlugin(cfg.vePluginName) or self
        local veIndex = cfg and cfg.veSystemIndex or 1
        local veKey = Orbit.VisibilityEngine and Orbit.VisibilityEngine:GetKeyForPlugin(vePlugin.name, veIndex)
        if veKey and Orbit.VisibilityEngine:GetFrameSetting(veKey, "hideMounted") then return end
    end

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
    local anchor, growthX, growthY = ResolveGrowthDirection(Frame, cfg.showIconLimit)
    if Frame.collapseArrow then UpdateCollapseArrow(Frame.collapseArrow, false, iconH, growthX, growthY) end
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
    local anchor, growthX, growthY = ResolveGrowthDirection(Frame, self._agConfig.showIconLimit)
    if Frame.collapseArrow then UpdateCollapseArrow(Frame.collapseArrow, false, iconH, growthX, growthY) end
    Orbit.AuraLayout:LayoutGrid(Frame, Frame._activePreviewIcons, {
        size = iconH, sizeW = iconW, spacing = spacing, maxPerRow = iconsPerRow,
        anchor = anchor, growthX = growthX, growthY = growthY, yOffset = 0,
    })
end

-- [ APPLY SETTINGS ]--------------------------------------------------------------------------------
function Mixin:ApplySettings()
    local Frame = self._agFrame
    if not Frame or InCombatLockdown() then return end
    Frame._orbitSkinVersion = (Frame._orbitSkinVersion or 0) + 1

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
