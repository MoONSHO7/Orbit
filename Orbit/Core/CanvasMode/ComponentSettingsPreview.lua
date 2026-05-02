-- [ CANVAS MODE - COMPONENT SETTINGS PREVIEW ] ------------------------------------------------------
-- Preview renderers and style applicators for component override settings.
-- Extends the Settings table created in ComponentSettings.lua.
local _, Orbit = ...
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")
local AnchorToCenter = OrbitEngine.PositionUtils.AnchorToCenter
local BuildAnchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint
local BuildComponentSelfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor
local ApplyTextAlignment = OrbitEngine.CanvasMode.ApplyTextAlignment

local PORTRAIT_RING_OVERSHOOT = OrbitEngine.PORTRAIT_RING_OVERSHOOT
local PORTRAIT_RING_DATA = OrbitEngine.PortraitRingData

local Settings = Orbit.CanvasComponentSettings

local function ReanchorContainer(container)
    if not container or not container.GetParent or not container.anchorX or not container.anchorY then return end
    local parent = container:GetParent()
    if not parent then return end
    local selfAnchor = BuildComponentSelfAnchor(container.isFontString, container.isAuraContainer, container.selfAnchorY, container.justifyH)
    local anchorPoint = BuildAnchorPoint(container.anchorX, container.anchorY)
    local finalX, finalY

    if container.anchorX == "CENTER" then
        finalX = container.posX or 0
    else
        finalX = container.offsetX or 0
        if container.anchorX == "RIGHT" then finalX = -finalX end
    end

    if container.anchorY == "CENTER" then
        finalY = container.posY or 0
    else
        finalY = container.offsetY or 0
        if container.anchorY == "TOP" then finalY = -finalY end
    end

    container:ClearAllPoints()
    local cScale = container:GetEffectiveScale()
    finalX, finalY = OrbitEngine.Pixel:SnapPosition(finalX, finalY, selfAnchor, container:GetWidth(), container:GetHeight(), cScale)
    container:SetPoint(selfAnchor, parent, anchorPoint, finalX, finalY)
    if container.visual and container.isFontString then
        ApplyTextAlignment(container, container.visual, container.justifyH or "CENTER")
    end
end

local function ApplyDifficultySavedPosition(settings, container, display)
    if not ((settings.componentKey == "DifficultyIcon") or (settings.componentKey == "DifficultyText")) or not settings.plugin or not settings.plugin.GetComponentPositions or not container then return end
    local parent = container:GetParent()
    if not parent then return end

    local activeKey = display == "text" and "DifficultyText" or "DifficultyIcon"
    local positions = settings.plugin:GetComponentPositions(settings.systemIndex) or {}
    local pos = positions[activeKey]
    if not pos or not pos.anchorX then return end

    local borderInset = parent.borderInset or 0
    local halfW = (parent.sourceWidth or parent:GetWidth() or 0) / 2 - borderInset
    local halfH = (parent.sourceHeight or parent:GetHeight() or 0) / 2 - borderInset
    local posX, posY = AnchorToCenter(pos.anchorX, pos.anchorY or "CENTER", pos.offsetX or 0, pos.offsetY or 0, halfW, halfH)

    container.anchorX = pos.anchorX
    container.anchorY = pos.anchorY or "CENTER"
    container.offsetX = pos.offsetX or 0
    container.offsetY = pos.offsetY or 0
    container.justifyH = pos.justifyH or "CENTER"
    container.selfAnchorY = pos.selfAnchorY or container.anchorY
    container.posX = pos.posX or posX
    container.posY = pos.posY or posY
    ReanchorContainer(container)
end

-- [ PORTRAIT PREVIEW ]-------------------------------------------------------------------------------
function Settings:ApplyPortraitPreview()
    local canvasDialog = OrbitEngine.CanvasModeDialog
    if not canvasDialog or not canvasDialog.previewComponents then return end
    local comp = canvasDialog.previewComponents.Portrait
    if not comp or not comp.visual then return end

    local overrides = self.currentOverrides or {}
    local scale = (overrides.PortraitScale or 120) / 100
    local style = overrides.PortraitStyle or "3d"
    local mirror = overrides.PortraitMirror or false
    local ringAtlas = overrides.PortraitRing or "none"

    local pScale = comp:GetEffectiveScale()
    local size = OrbitEngine.Pixel:Snap(32 * scale, pScale)
    local ringData = PORTRAIT_RING_DATA[ringAtlas]
    local ringOS = OrbitEngine.Pixel:Snap(((ringData and ringData.overshoot) or PORTRAIT_RING_OVERSHOOT) * scale, pScale)
    comp:SetSize(size, size)

    if not comp._ring then
        comp._ring = comp:CreateTexture(nil, "OVERLAY")
    end
    comp._ring:ClearAllPoints()
    comp._ring:SetPoint("TOPLEFT", -ringOS, ringOS)
    comp._ring:SetPoint("BOTTOMRIGHT", ringOS, -ringOS)

    if style == "3d" then
        if not comp._model then
            comp._model = CreateFrame("PlayerModel", nil, comp)
            comp._model:SetAllPoints()
        end
        comp.visual:Hide()
        comp._model:Show()
        comp._model:SetUnit("player")
        comp._model:SetPortraitZoom(mirror and 0.85 or 1)
        comp._model:SetCamDistanceScale(0.8)
        comp._model:SetFacing(mirror and -1.05 or 0)
        comp._model:SetPosition(mirror and 0.3 or 0, 0, mirror and -0.05 or 0)
        comp._ring:Hide()
        if comp._flipDriver then comp._flipDriver:Hide() end
        local showBorder = overrides.PortraitBorder
        if showBorder == nil then showBorder = true end
        local borderSize = showBorder and (Orbit.db.GlobalSettings.BorderSize or 0) or 0
        Orbit.Skin:SkinBorder(comp, comp, borderSize)
    else
        if comp._model then comp._model:Hide() end
        comp.visual:Show()
        SetPortraitTexture(comp.visual, "player")
        comp.visual:SetTexCoord(mirror and 1 or 0, mirror and 0 or 1, 0, 1)
        Orbit.Skin:SkinBorder(comp, comp, 0)
        local ringData = PORTRAIT_RING_DATA[ringAtlas]
        if ringData and ringData.atlas then
            comp._ring:Show()
            if ringData.rows then
                local info = C_Texture.GetAtlasInfo(ringData.atlas)
                if not info then comp._ring:Hide(); return end
                comp._ring:SetTexture(info.file)
                local aL, aR = info.leftTexCoord, info.rightTexCoord
                local aT, aB = info.topTexCoord, info.bottomTexCoord
                local cellW, cellH = (aR - aL) / ringData.cols, (aB - aT) / ringData.rows
                local frameTime = ringData.duration / ringData.frames
                if not comp._flipDriver then
                    comp._flipDriver = CreateFrame("Frame", nil, comp)
                end
                comp._flipDriver._current = 0
                comp._flipDriver._elapsed = 0
                local function SetFrame(idx)
                    local c = idx % ringData.cols
                    local r = math.floor(idx / ringData.cols)
                    comp._ring:SetTexCoord(aL + c * cellW, aL + (c + 1) * cellW, aT + r * cellH, aT + (r + 1) * cellH)
                end
                SetFrame(0)
                comp._flipDriver:SetScript("OnUpdate", function(driver, elapsed)
                    driver._elapsed = driver._elapsed + elapsed
                    if driver._elapsed >= frameTime then
                        driver._elapsed = driver._elapsed - frameTime
                        driver._current = (driver._current + 1) % ringData.frames
                        SetFrame(driver._current)
                    end
                end)
                comp._flipDriver:Show()
            else
                comp._ring:SetTexCoord(0, 1, 0, 1)
                comp._ring:SetAtlas(ringData.atlas)
                if comp._flipDriver then comp._flipDriver:Hide() end
            end
        else
            comp._ring:Hide()
            if comp._flipDriver then comp._flipDriver:Hide() end
        end
    end
end

-- [ CAST BAR PREVIEW ]-------------------------------------------------------------------------------
function Settings:ApplyCastBarPreview()
    local canvasDialog = OrbitEngine.CanvasModeDialog
    if not canvasDialog or not canvasDialog.previewComponents then return end
    local comp = canvasDialog.previewComponents.CastBar
    if not comp then return end

    local pending = self.pendingPluginSettings or {}
    local plugin = self.plugin
    local sysIdx = self.systemIndex or 1
    local w = pending.CastBarWidth or (plugin and plugin:GetSetting(sysIdx, "CastBarWidth")) or 120
    local h = pending.CastBarHeight or (plugin and plugin:GetSetting(sysIdx, "CastBarHeight")) or 18
    local cScale = comp:GetEffectiveScale()
    comp:SetSize(OrbitEngine.Pixel:Snap(w + h, cScale), OrbitEngine.Pixel:Snap(h, cScale))
end

-- [ HEALTH TEXT PREVIEW ] ---------------------------------------------------------------------------
function Settings:ApplyHealthTextPreview()
    local canvasDialog = OrbitEngine.CanvasModeDialog
    if not canvasDialog or not canvasDialog.previewComponents then return end
    local comp = canvasDialog.previewComponents.HealthText
    if not comp or not comp.visual then return end
    local visual = comp.visual

    local pending = self.pendingPluginSettings or {}
    local plugin = self.plugin
    local sysIdx = self.systemIndex or 1

    local function GetValue(key)
        if pending[key] ~= nil then return pending[key] end
        if plugin then return plugin:GetSetting(sysIdx, key) end
        return nil
    end

    local showValue = GetValue("ShowHealthValue")
    if showValue == nil then showValue = true end
    local mode = GetValue("HealthTextMode") or "percent_short"

    if showValue then
        local SAMPLE_TEXT = {
            percent = "100%", short = "106K", raw = "106000",
            short_and_percent = "106K - 100%",
            percent_short = "100%", percent_raw = "100%",
            short_percent = "106K", short_raw = "106K",
            raw_short = "106000", raw_percent = "106000",
        }
        visual:SetText(SAMPLE_TEXT[mode] or "100%")
    else
        visual:SetText("Offline")
    end
    visual:Show()
end

-- [ ZONE TEXT PREVIEW ]------------------------------------------------------------------------------
function Settings:ApplyZoneTextPreview()
    local canvasDialog = OrbitEngine.CanvasModeDialog
    if not canvasDialog or not canvasDialog.previewComponents then return end
    local comp = canvasDialog.previewComponents.ZoneText
    if not comp or not comp.visual then return end
    local visual = comp.visual

    local pending = self.pendingPluginSettings or {}
    local coloring = pending.ZoneTextColoring
    if coloring == nil then
        local plugin = self.plugin
        local sysIdx = self.systemIndex or 1
        coloring = plugin and plugin:GetSetting(sysIdx, "ZoneTextColoring")
    end

    if coloring then
        local ZONE_PVP_COLORS = {
            sanctuary = { r = 0.41, g = 0.80, b = 0.94 },
            friendly   = { r = 0.10, g = 1.00, b = 0.10 },
            hostile    = { r = 1.00, g = 0.10, b = 0.10 },
            contested  = { r = 1.00, g = 0.70, b = 0.00 },
        }
        local pvpType = GetZonePVPInfo()
        local color = ZONE_PVP_COLORS[pvpType]
        if color then
            visual:SetTextColor(color.r, color.g, color.b, 1)
        else
            visual:SetTextColor(1, 1, 1, 1)
        end
    else
        local overrides = self.currentOverrides or {}
        if overrides.CustomColorCurve then
            local color = OrbitEngine.ColorCurve:GetFirstColorFromCurve(overrides.CustomColorCurve)
            if color then
                visual:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
            end
        else
            visual:SetTextColor(1, 1, 1, 1)
        end
    end
end

-- [ FLUSH PENDING ]----------------------------------------------------------------------------------
function Settings:FlushPendingPluginSettings()
    if not self.pendingPluginSettings or not self.plugin then return end
    for k, v in pairs(self.pendingPluginSettings) do
        self.plugin:SetSetting(self.systemIndex, k, v)
    end
    self.pendingPluginSettings = nil
end

-- [ APPLY STYLE ]------------------------------------------------------------------------------------
function Settings:ApplyStyle(container, key, value)
    if key == "MaxIcons" or key == "MaxRows" or key == "FilterDensity" then
        if self.container and self.container.RefreshAuraIcons then self.container:RefreshAuraIcons() end
        return
    end
    if key == "DifficultyDisplay" and self.container and self.container.SetDifficultyDisplay then
        self.container:SetDifficultyDisplay(value)
        ApplyDifficultySavedPosition(self, self.container, value)
        ReanchorContainer(self.container)
        return
    end
    if key == "IconSize" then
        if self.container and self.container.RefreshAuraIcons then
            self.container:RefreshAuraIcons()
        elseif self.container then
            if self.container.UpdateZoomSize then
                self.container:UpdateZoomSize(value)
            else
                local cScale = self.container:GetEffectiveScale()
                local snappedV = OrbitEngine.Pixel:Snap(value, cScale)
                self.container:SetSize(snappedV, snappedV)
                if self.container.visual and self.container.visual.SetSize and not self.container._cyclingTicker then self.container.visual:SetSize(snappedV, snappedV) end
                if self.container.visual and Orbit.Skin and Orbit.Skin.Icons and self.container.visual.GetRegions then
                    if not self.container.skipIconSkin then
                        Orbit.Skin.Icons:ApplyCustom(self.container.visual, Orbit.Constants.Aura.SkinNoTimer)
                    end
                end
            end
        end
        return
    end

    if not container or not container.visual then return end
    local visual = container.visual

    if key == "FontSize" and visual.SetFont then
        local font, _, flags = visual:GetFont()
        flags = (flags and flags ~= "") and flags or Orbit.Skin:GetFontOutline()
        visual:SetFont(font, value, flags)
        Orbit.Skin:ApplyFontShadow(visual)
        C_Timer.After(0.01, function()
            if container and visual and visual.GetStringWidth then
                local cScale = container:GetEffectiveScale()
                container:SetSize(OrbitEngine.Pixel:Snap((visual:GetStringWidth() or (value * 3)) + 2, cScale), OrbitEngine.Pixel:Snap((visual:GetStringHeight() or value) + 2, cScale))
                ReanchorContainer(container)
            end
        end)
    elseif key == "Font" and visual.SetFont then
        local fontPath = LSM:Fetch("font", value)
        if fontPath then
            local _, size, flags = visual:GetFont()
            flags = (flags and flags ~= "") and flags or Orbit.Skin:GetFontOutline()
            visual:SetFont(fontPath, size or 12, flags)
            Orbit.Skin:ApplyFontShadow(visual)
            C_Timer.After(0.01, function()
                if container and visual and visual.GetStringWidth then
                    local cScale = container:GetEffectiveScale()
                    container:SetSize(OrbitEngine.Pixel:Snap((visual:GetStringWidth() or ((size or 12) * 3)) + 2, cScale), OrbitEngine.Pixel:Snap((visual:GetStringHeight() or (size or 12)) + 2, cScale))
                    ReanchorContainer(container)
                end
            end)
        end
    elseif key == "CustomColorCurve" and visual.SetTextColor then
        local color = OrbitEngine.ColorCurve:GetFirstColorFromCurve(value)
        if color then visual:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1) end
    elseif key == "Scale" then
        if container._cyclingTicker then
            if not container._originalSize then container._originalSize = container:GetWidth() end
            local cScale = container:GetEffectiveScale()
            local newSize = OrbitEngine.Pixel:Snap((container._originalSize or 18) * value, cScale)
            container:SetSize(newSize, newSize)
        elseif visual.GetObjectType and visual:GetObjectType() == "Texture" then
            if not container.originalVisualWidth then
                container.originalVisualWidth = visual:GetWidth()
                container.originalVisualHeight = visual:GetHeight()
            end
            visual:ClearAllPoints()
            visual:SetPoint("CENTER", container, "CENTER", 0, 0)
            local cScale = container:GetEffectiveScale()
            visual:SetSize(OrbitEngine.Pixel:Snap((container.originalVisualWidth or 18) * value, cScale), OrbitEngine.Pixel:Snap((container.originalVisualHeight or 18) * value, cScale))
        elseif visual.SetScale then
            visual:SetScale(value)
        end
    elseif key == "HideDPS" or key == "RoleIconStyle" or key == "CombatIconStyle" or key == "LeaderIconStyle" then
        local cont = self.container
        local overrides = self.currentOverrides or {}
        local compKey = self.componentKey
        if compKey == "CombatIcon" and cont and cont.visual then
            local COMBAT = { default = "UI-HUD-UnitFrame-Player-CombatIcon", pvp = "UI-EventPoi-pvp" }
            cont.visual:SetAtlas(COMBAT[overrides.CombatIconStyle or "default"] or COMBAT.default, false)
        elseif cont and cont._cyclingAtlases then
            local newAtlases
            if compKey == "RoleIcon" then
                local ROLE_DEFAULT = { { atlas = "UI-LFG-RoleIcon-Tank" }, { atlas = "UI-LFG-RoleIcon-Healer" }, { atlas = "UI-LFG-RoleIcon-DPS" } }
                local ROLE_ROUND = { { atlas = "icons_64x64_tank" }, { atlas = "icons_64x64_heal" }, { atlas = "icons_64x64_damage" } }
                local ROLE_HEADER = { { atlas = "GO-icon-role-Header-Tank" }, { atlas = "GO-icon-role-Header-Healer" }, { atlas = "GO-icon-role-Header-DPS" }, { atlas = "GO-icon-role-Header-DPS-Ranged" } }
                local style = overrides.RoleIconStyle or "default"
                newAtlases = (style == "round") and ROLE_ROUND or (style == "header") and ROLE_HEADER or ROLE_DEFAULT
                if overrides.HideDPS then
                    local dpsAtlas = (style == "round") and "icons_64x64_damage" or (style == "header") and "GO-icon-role-Header-DPS" or "UI-LFG-RoleIcon-DPS"
                    local rangedAtlas = (style == "header") and "GO-icon-role-Header-DPS-Ranged" or nil
                    local filtered = {}
                    for _, e in ipairs(newAtlases) do if e.atlas ~= dpsAtlas and e.atlas ~= rangedAtlas then filtered[#filtered + 1] = e end end
                    newAtlases = filtered
                end
            elseif compKey == "LeaderIcon" then
                local LEADER_DEFAULT = { { atlas = "UI-HUD-UnitFrame-Player-Group-LeaderIcon" } }
                local LEADER_HEADER = { { atlas = "GO-icon-Header-Assist-Applied" }, { atlas = "GO-icon-Header-Assist-Available" } }
                newAtlases = (overrides.LeaderIconStyle == "header") and LEADER_HEADER or LEADER_DEFAULT
            end
            if newAtlases and #newAtlases > 0 then
                cont._cyclingAtlases = newAtlases
                cont._cyclingTexA:SetAtlas(newAtlases[1].atlas, false)
                cont._cyclingTexA:SetAlpha(1)
                if cont._cyclingTexB then cont._cyclingTexB:SetAlpha(0) end
            end
        end
        local plugin = self.plugin
        if plugin and plugin.SchedulePreviewUpdate then plugin:SchedulePreviewUpdate() end
    end
end

-- [ APPLY ALL ]--------------------------------------------------------------------------------------
function Settings:ApplyAll(container, overrides)
    if not container or not overrides then return end
    local previousOverrides = self.currentOverrides
    self.currentOverrides = overrides
    if overrides.DifficultyDisplay then self:ApplyStyle(container, "DifficultyDisplay", overrides.DifficultyDisplay) end
    for key, value in pairs(overrides) do if key ~= "DifficultyDisplay" then self:ApplyStyle(container, key, value) end end
    self.currentOverrides = previousOverrides
end

-- [ INITIAL PLUGIN PREVIEWS ]------------------------------------------------------------------------
function Settings:ApplyInitialPluginPreviews(plugin, systemIndex)
    if not plugin then return end
    local sysIdx = systemIndex or 1
    local pendingPluginSettings = self.pendingPluginSettings
    self.plugin = plugin
    self.systemIndex = sysIdx

    local portraitStyle = plugin:GetSetting(sysIdx, "PortraitStyle") or "3d"
    self.currentOverrides = {
        PortraitStyle = portraitStyle,
        PortraitScale = plugin:GetSetting(sysIdx, "PortraitScale") or 120,
        PortraitBorder = plugin:GetSetting(sysIdx, "PortraitBorder"),
        PortraitMirror = plugin:GetSetting(sysIdx, "PortraitMirror") or false,
        PortraitRing = plugin:GetSetting(sysIdx, "PortraitRing") or "none",
    }
    if self.currentOverrides.PortraitBorder == nil then self.currentOverrides.PortraitBorder = true end
    self:ApplyPortraitPreview()

    self.currentOverrides = {
        CastBarWidth = plugin:GetSetting(sysIdx, "CastBarWidth") or 120,
        CastBarHeight = plugin:GetSetting(sysIdx, "CastBarHeight") or 18,
    }
    self.pendingPluginSettings = pendingPluginSettings
    self:ApplyCastBarPreview()

    self.currentOverrides = nil

    local showValue = plugin:GetSetting(sysIdx, "ShowHealthValue")
    local textMode = plugin:GetSetting(sysIdx, "HealthTextMode")

    self.currentOverrides = {
        ShowHealthValue = showValue,
        HealthTextMode = textMode or "percent_short",
    }
    if self.currentOverrides.ShowHealthValue == nil then self.currentOverrides.ShowHealthValue = true end
    self:ApplyHealthTextPreview()

    self.currentOverrides = nil
    self.pendingPluginSettings = pendingPluginSettings
end
