-- [ CANVAS MODE - COMPONENT SETTINGS PREVIEW ]-----------------------------------------------------
-- Preview renderers and style applicators for component override settings.
-- Extends the Settings table created in ComponentSettings.lua.
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local LSM = LibStub("LibSharedMedia-3.0")

local PORTRAIT_RING_OVERSHOOT = OrbitEngine.PORTRAIT_RING_OVERSHOOT
local PORTRAIT_RING_DATA = OrbitEngine.PortraitRingData

local Settings = Orbit.CanvasComponentSettings

-- [ PORTRAIT PREVIEW ]------------------------------------------------------------------------------
function Settings:ApplyPortraitPreview()
    local ok, err = pcall(function()
    local canvasDialog = OrbitEngine.CanvasModeDialog
    if not canvasDialog or not canvasDialog.previewComponents then return end
    local comp = canvasDialog.previewComponents.Portrait
    if not comp or not comp.visual then return end

    local overrides = self.currentOverrides or {}
    local scale = (overrides.PortraitScale or 120) / 100
    local style = overrides.PortraitStyle or "3d"
    local mirror = overrides.PortraitMirror or false
    local ringAtlas = overrides.PortraitRing or "none"

    local size = 32 * scale
    local ringData = PORTRAIT_RING_DATA[ringAtlas]
    local ringOS = ((ringData and ringData.overshoot) or PORTRAIT_RING_OVERSHOOT) * scale
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
    end)
    if not ok then print("|cffff0000ORBIT_PORTRAIT_PREVIEW ERROR:|r", err) end
end

-- [ CAST BAR PREVIEW ]------------------------------------------------------------------------------
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
    comp:SetSize(w, h)
    if comp.visual and comp.visual.SetAllPoints then comp.visual:SetAllPoints() end
end

-- [ HEALTH TEXT PREVIEW ]----------------------------------------------------------------------------
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
        if plugin then
            if plugin.GetInheritedSetting then
                return plugin:GetInheritedSetting(sysIdx, key, true)
            end
            return plugin:GetSetting(sysIdx, key)
        end
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

-- [ FLUSH PENDING ]---------------------------------------------------------------------------------
function Settings:FlushPendingPluginSettings()
    if not self.pendingPluginSettings or not self.plugin then return end
    for k, v in pairs(self.pendingPluginSettings) do
        self.plugin:SetSetting(self.systemIndex, k, v)
    end
    self.pendingPluginSettings = nil
end

-- [ APPLY STYLE ]-----------------------------------------------------------------------------------
function Settings:ApplyStyle(container, key, value)
    if key == "MaxIcons" or key == "MaxRows" or key == "FilterDensity" then
        if self.container and self.container.RefreshAuraIcons then self.container:RefreshAuraIcons() end
        return
    end
    if key == "IconSize" then
        if self.container and self.container.RefreshAuraIcons then
            self.container:RefreshAuraIcons()
        elseif self.container then
            self.container:SetSize(value, value)
            if self.container.visual and self.container.visual.SetSize and not self.container._cyclingTicker then self.container.visual:SetSize(value, value) end
            if self.container.visual and Orbit.Skin and Orbit.Skin.Icons and self.container.visual.GetRegions then
                Orbit.Skin.Icons:ApplyCustom(self.container.visual, Orbit.Constants.Aura.SkinNoTimer)
            end
        end
        return
    end

    if not container or not container.visual then return end
    local visual = container.visual
    local layerTarget = (visual.SetFrameStrata or visual.SetDrawLayer) and visual or container

    if key == "FontSize" and visual.SetFont then
        local font, _, flags = visual:GetFont()
        flags = (flags and flags ~= "") and flags or Orbit.Skin:GetFontOutline()
        visual:SetFont(font, value, flags)
        C_Timer.After(0.01, function()
            if container and visual and visual.GetStringWidth then
                container:SetSize((visual:GetStringWidth() or (value * 3)) + 2, (visual:GetStringHeight() or value) + 2)
            end
        end)
    elseif key == "Font" and visual.SetFont then
        local fontPath = LSM:Fetch("font", value)
        if fontPath then
            local _, size, flags = visual:GetFont()
            flags = (flags and flags ~= "") and flags or Orbit.Skin:GetFontOutline()
            visual:SetFont(fontPath, size or 12, flags)
            C_Timer.After(0.01, function()
                if container and visual and visual.GetStringWidth then
                    container:SetSize((visual:GetStringWidth() or ((size or 12) * 3)) + 2, (visual:GetStringHeight() or (size or 12)) + 2)
                end
            end)
        end
    elseif key == "CustomColorCurve" and visual.SetTextColor then
        local color = OrbitEngine.ColorCurve:GetFirstColorFromCurve(value)
        if color then visual:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1) end
    elseif key == "Scale" then
        if container._cyclingTicker then
            if not container._originalSize then container._originalSize = container:GetWidth() end
            local newSize = (container._originalSize or 18) * value
            container:SetSize(newSize, newSize)
        elseif visual.GetObjectType and visual:GetObjectType() == "Texture" then
            if not container.originalVisualWidth then
                container.originalVisualWidth = visual:GetWidth()
                container.originalVisualHeight = visual:GetHeight()
            end
            visual:ClearAllPoints()
            visual:SetPoint("CENTER", container, "CENTER", 0, 0)
            visual:SetSize((container.originalVisualWidth or 18) * value, (container.originalVisualHeight or 18) * value)
        elseif visual.SetScale then
            visual:SetScale(value)
        end
    elseif key == "HideDPS" or key == "RoleIconStyle" or key == "CombatIconStyle" or key == "PvpIconStyle" then
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
                newAtlases = (overrides.RoleIconStyle == "round") and ROLE_ROUND or ROLE_DEFAULT
                if overrides.HideDPS then
                    local dpsAtlas = (newAtlases == ROLE_ROUND) and "icons_64x64_damage" or "UI-LFG-RoleIcon-DPS"
                    local filtered = {}
                    for _, e in ipairs(newAtlases) do if e.atlas ~= dpsAtlas then filtered[#filtered + 1] = e end end
                    newAtlases = filtered
                end
            elseif compKey == "PvpIcon" then
                local PVP = { default = { { atlas = "QuestPortraitIcon-Alliance" }, { atlas = "QuestPortraitIcon-Horde" } },
                    crest = { { atlas = "glues-characterSelect-icon-faction-alliance-selected" }, { atlas = "glues-characterSelect-icon-faction-horde-selected" } } }
                newAtlases = PVP[overrides.PvpIconStyle or "default"] or PVP.default
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
    elseif key == "Strata" or key == "Level" then
        OrbitEngine.OverrideUtils.ApplyLayerOverrides(layerTarget, self.currentOverrides or {})
    end
end

-- [ APPLY ALL ]-------------------------------------------------------------------------------------
function Settings:ApplyAll(container, overrides)
    if not container or not overrides then return end
    local previousOverrides = self.currentOverrides
    self.currentOverrides = overrides
    for key, value in pairs(overrides) do self:ApplyStyle(container, key, value) end
    self.currentOverrides = previousOverrides
end

-- [ INITIAL PLUGIN PREVIEWS ]-----------------------------------------------------------------------
function Settings:ApplyInitialPluginPreviews(plugin, systemIndex)
    if not plugin then return end
    local sysIdx = systemIndex or 1
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
    self.pendingPluginSettings = nil
    self:ApplyCastBarPreview()

    self.currentOverrides = nil

    local showValue = plugin.GetInheritedSetting and plugin:GetInheritedSetting(sysIdx, "ShowHealthValue", true) or plugin:GetSetting(sysIdx, "ShowHealthValue")
    local textMode = plugin.GetInheritedSetting and plugin:GetInheritedSetting(sysIdx, "HealthTextMode", true) or plugin:GetSetting(sysIdx, "HealthTextMode")

    self.currentOverrides = {
        ShowHealthValue = showValue,
        HealthTextMode = textMode or "percent_short",
    }
    if self.currentOverrides.ShowHealthValue == nil then self.currentOverrides.ShowHealthValue = true end
    self:ApplyHealthTextPreview()

    self.currentOverrides = nil
end
