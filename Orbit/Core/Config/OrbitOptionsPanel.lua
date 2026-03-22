-- [ ORBIT OPTIONS PANEL ]---------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local Layout = OrbitEngine.Layout
local Config = OrbitEngine.Config
local Constants = Orbit.Constants

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local BUTTON_WIDTH = 180
local DROPDOWN_WIDTH = 200
local SPACER_SMALL = 10
local SPACER_LARGE = 20
local POPUP_PREFERRED_INDEX = 3

-- [ HELPERS ]---------------------------------------------------------------------------------------

Orbit.OptionsPanel = {}
local Panel = Orbit.OptionsPanel

local function RefreshAllPreviews()
    for _, plugin in ipairs(OrbitEngine.systems) do
        if plugin.ApplyPreviewVisuals then plugin:ApplyPreviewVisuals() end
    end
end

local function GetBorderStyleOptions()
    local opts = {}
    for _, entry in ipairs(Constants.BorderStyle.Styles) do
        opts[#opts + 1] = entry
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local existing = {}
        for _, entry in ipairs(opts) do existing[entry.label] = true end
        local borders = LSM:HashTable("border")
        if borders then
            for name, path in pairs(borders) do
                if not existing[name] and path and path ~= "" and name ~= "None" and not name:match("^Blizzard") then
                    opts[#opts + 1] = { label = name, value = "lsm:" .. name }
                end
            end
        end
    end
    table.sort(opts, function(a, b)
        if a.value == "flat" then return true end
        if b.value == "flat" then return false end
        return a.label < b.label
    end)
    return opts
end

local function CreateGlobalSettingsPlugin(name, onSetOverride)
    return {
        name = name,
        settings = {},
        GetSetting = function(self, systemIndex, key)
            if not Orbit.db or not Orbit.db.GlobalSettings then return nil end
            return Orbit.db.GlobalSettings[key]
        end,
        SetSetting = function(self, systemIndex, key, value)
            if not Orbit.db then return end
            if not Orbit.db.GlobalSettings then Orbit.db.GlobalSettings = {} end
            Orbit.db.GlobalSettings[key] = value
            if onSetOverride then onSetOverride(key, value) end
        end,
        ApplySettings = function(self, systemFrame)
            for _, plugin in ipairs(OrbitEngine.systems) do
                if plugin.ApplyAll then plugin:ApplyAll()
                elseif plugin.ApplySettings then plugin:ApplySettings() end
            end
            RefreshAllPreviews()
        end,
    }
end

-- [ GLOBAL TAB ]------------------------------------------------------------------------------------

local GlobalPlugin = CreateGlobalSettingsPlugin("OrbitGlobal")

local function GetGlobalSchema()
    local controls = {
        { type = "font", key = "Font", label = "Font", default = "PT Sans Narrow" },
        {
            type = "dropdown", key = "FontOutline", label = "Outline",
            options = {
                { label = "None", value = "" }, { label = "Outline", value = "OUTLINE" },
                { label = "Thick Outline", value = "THICKOUTLINE" }, { label = "Monochrome", value = "MONOCHROME" },
            },
            default = "OUTLINE",
        },
        {
            type = "dropdown", key = "BorderStyle", label = "Border Style", options = GetBorderStyleOptions(), default = Constants.BorderStyle.Default,
            onChange = function(val)
                GlobalPlugin:SetSetting(nil, "BorderStyle", val)
                GlobalPlugin:ApplySettings()
                Orbit.EventBus:Fire("ORBIT_BORDER_SIZE_CHANGED")
                local dialog = Orbit.SettingsDialog
                if dialog and dialog.OrbitPanel and dialog.OrbitPanel.Tabs then
                    local oldTab = dialog.OrbitPanel.Tabs["Global"]
                    if oldTab then
                        Layout:Reset(oldTab)
                        oldTab:Hide()
                    end
                    dialog.OrbitPanel.Tabs["Global"] = nil
                end
                Panel.lastTab = nil
                Panel:Open("Global")
            end,
        },
    }

    local currentStyle = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.BorderStyle or Constants.BorderStyle.Default
    local function borderSizeChanged(key, val)
        GlobalPlugin:SetSetting(nil, key, val)
        GlobalPlugin:ApplySettings()
        Orbit.EventBus:Fire("ORBIT_BORDER_SIZE_CHANGED")
    end
    if currentStyle == "flat" then
        tinsert(controls, { type = "slider", key = "BorderSize", label = "Border Size", default = 2, min = 0, max = 5, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("BorderSize", v) end })
    else
        tinsert(controls, { type = "slider", key = "BorderEdgeSize", label = "Border Edge Size", default = 16, min = 1, max = 32, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("BorderEdgeSize", v) end })
        tinsert(controls, { type = "slider", key = "BorderOffset", label = "Border Offset", default = 0, min = 0, max = 16, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("BorderOffset", v) end })
    end

    tinsert(controls, {
        type = "dropdown", key = "IconBorderStyle", label = "Icon Border Style", options = GetBorderStyleOptions(), default = Constants.BorderStyle.Default,
        onChange = function(val)
            GlobalPlugin:SetSetting(nil, "IconBorderStyle", val)
            GlobalPlugin:ApplySettings()
            Orbit.EventBus:Fire("ORBIT_BORDER_SIZE_CHANGED")
            local dialog = Orbit.SettingsDialog
            if dialog and dialog.OrbitPanel and dialog.OrbitPanel.Tabs then
                local oldTab = dialog.OrbitPanel.Tabs["Global"]
                if oldTab then Layout:Reset(oldTab); oldTab:Hide()
                    dialog.OrbitPanel.Tabs["Global"] = nil
                end
                Panel.lastTab = nil
                Panel:Open("Global")
            end
        end,
    })

    local currentIconStyle = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.IconBorderStyle or Constants.BorderStyle.Default
    if currentIconStyle == "flat" then
        tinsert(controls, { type = "slider", key = "IconBorderSize", label = "Icon Border Size", default = 2, min = 0, max = 5, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("IconBorderSize", v) end })
    else
        tinsert(controls, { type = "slider", key = "IconBorderEdgeSize", label = "Icon Border Edge Size", default = 16, min = 1, max = 32, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("IconBorderEdgeSize", v) end })
        tinsert(controls, { type = "slider", key = "IconBorderOffset", label = "Icon Border Offset", default = 0, min = 0, max = 16, step = 1, updateOnRelease = true, onChange = function(v) borderSizeChanged("IconBorderOffset", v) end })
    end

    table.insert(controls, {
        type = "checkbox", key = "HideWhenMounted", label = "Hide When Mounted", default = false,
        onChange = function(val)
            Orbit.db.GlobalSettings.HideWhenMounted = val
            Orbit.MountedVisibility:Refresh()
        end,
    })


    return {
        hideNativeSettings = true,
        hideResetButton = false,
        openPluginManager = true,
        controls = controls,
        onReset = function()
            local d = Orbit.db.GlobalSettings
            if d then
                d.Font = "PT Sans Narrow"
                d.FontOutline = "OUTLINE"
                d.BorderSize = 2
                d.BorderStyle = Constants.BorderStyle.Default
                d.BorderEdgeSize = 16
                d.BorderOffset = 0
                d.IconBorderStyle = Constants.BorderStyle.Default
                d.IconBorderSize = 2
                d.IconBorderEdgeSize = 16
                d.IconBorderOffset = 0
                d.HideWhenMounted = false
            end
            Orbit.MountedVisibility:Refresh()
            Orbit:Print("Global settings reset to defaults.")
        end,
    }
end

-- [ COLORS TAB ]------------------------------------------------------------------------------------

local ColorsPlugin = CreateGlobalSettingsPlugin("OrbitColors")

local function GetColorsSchema()
    local controls = {
        { type = "texture", key = "Texture", label = "Texture", default = "Melli", previewColor = { r = 0.8, g = 0.8, b = 0.8 } },
        { type = "texture", key = "OverlayTexture", label = "Overlay Texture", default = "None", previewColor = { r = 0.5, g = 0.5, b = 0.5 } },

        {
            type = "colorcurve", key = "FontColorCurve", label = "Font Color",
            default = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } },
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "FontColorCurve", val)
                Orbit.Async:Debounce("ColorsPanel_FontColor", function() ColorsPlugin:ApplySettings() end, 0.15)
            end,
        },
        {
            type = "colorcurve", key = "BarColorCurve", label = "Unit Frame Health",
            default = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.2, a = 1 } } } },
            tooltip = "Health bar color. Use the color picker to select class color or create custom gradients.",
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "BarColorCurve", val)
                Orbit.Async:Debounce("ColorsPanel_BarColor", function()
                    ColorsPlugin:ApplySettings()
                    RefreshAllPreviews()
                end, 0.15)
            end,
        },
        {
            type = "colorcurve", key = "UnitFrameBackdropColourCurve", label = "Unit Frame Background",
            default = { pins = { { position = 0, color = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 } } } },
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "UnitFrameBackdropColourCurve", val)
                Orbit.Async:Debounce("ColorsPanel_UnitFrameBg", function()
                    ColorsPlugin:ApplySettings()
                    RefreshAllPreviews()
                end, 0.15)
            end,
        },
        {
            type = "colorcurve", key = "BackdropColourCurve", label = "Backdrop Color",
            default = { pins = { { position = 0, color = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 } } } },
            tooltip = "Background color for castbars, action bars, resource bars, and other non-unit frame elements.",
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "BackdropColourCurve", val)
                Orbit.Async:Debounce("ColorsPanel_BackdropColour", function()
                    ColorsPlugin:ApplySettings()
                    RefreshAllPreviews()
                    Orbit.EventBus:Fire("ORBIT_GLOBAL_BACKDROP_CHANGED")
                end, 0.15)
            end,
        },
        {
            type = "color", key = "BorderColor", label = "Border Color",
            default = { r = 0, g = 0, b = 0, a = 1 },
            tooltip = "Border color for unit frames, cast bars, and other non-icon frames.",
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "BorderColor", val)
                Orbit.Async:Debounce("ColorsPanel_BorderColor", function()
                    ColorsPlugin:ApplySettings()
                    RefreshAllPreviews()
                    Orbit.EventBus:Fire("ORBIT_GLOBAL_BORDER_COLOR_CHANGED")
                end, 0.15)
            end,
        },
        {
            type = "color", key = "IconBorderColor", label = "Icon Border Color",
            default = { r = 0, g = 0, b = 0, a = 1 },
            tooltip = "Border color for aura icons, cooldown icons, and other icon frames.",
            onChange = function(val)
                ColorsPlugin:SetSetting(nil, "IconBorderColor", val)
                Orbit.Async:Debounce("ColorsPanel_IconBorderColor", function()
                    ColorsPlugin:ApplySettings()
                    RefreshAllPreviews()
                    Orbit.EventBus:Fire("ORBIT_GLOBAL_BORDER_COLOR_CHANGED")
                end, 0.15)
            end,
        },
    }

    return {
        hideNativeSettings = true,
        hideResetButton = false,
        openPluginManager = true,
        controls = controls,
        onReset = function()
            local d = Orbit.db.GlobalSettings
            if d then
                d.Texture = "Melli"

                d.OverlayTexture = "None"
                d.BarColorCurve = { pins = { { position = 0, color = { r = 0.2, g = 0.8, b = 0.2, a = 1 } } } }
                d.UnitFrameBackdropColourCurve = { pins = { { position = 0, color = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 } } } }
                d.BackdropColourCurve = { pins = { { position = 0, color = { r = 0.08, g = 0.08, b = 0.08, a = 0.5 } } } }
                d.FontColorCurve = { pins = { { position = 0, color = { r = 1, g = 1, b = 1, a = 1 } } } }
                d.BorderColor = { r = 0, g = 0, b = 0, a = 1 }
                d.IconBorderColor = { r = 0, g = 0, b = 0, a = 1 }
            end
            Orbit:Print("Colors settings reset to defaults.")
            if Orbit.OptionsPanel then Orbit.OptionsPanel:Refresh() end
        end,
    }
end

-- [ EDIT MODE TAB ]---------------------------------------------------------------------------------

local EditModePlugin = CreateGlobalSettingsPlugin("OrbitEditMode", function(key, value)
    if Orbit.Engine.FrameSelection then Orbit.Engine.FrameSelection:RefreshVisuals() end
end)

EditModePlugin.ApplySettings = function(self, systemFrame) end

local function GetEditModeSchema()
    return {
        hideNativeSettings = true,
        hideResetButton = false,
        openPluginManager = true,
        controls = {
            { type = "checkbox", key = "ShowBlizzardFrames", label = "Show Blizzard Frames", default = true, tooltip = "Show selection overlays for native Blizzard frames in Edit Mode." },
            { type = "checkbox", key = "ShowOrbitFrames", label = "Show Orbit Frames", default = true, tooltip = "Show selection overlays for Orbit-owned frames in Edit Mode." },
            { type = "checkbox", key = "AnchoringEnabled", label = "Enable Frame Anchoring", default = true, tooltip = "Allow frames to anchor to other frames. Disabling preserves existing anchors but prevents new ones.\n\nHold Shift while dragging to temporarily bypass anchoring." },
            {
                type = "colorcurve", key = "EditModeColorCurve", label = "Orbit Frame Color",
                default = { pins = { { position = 0, color = { r = 0.7, g = 0.6, b = 1.0, a = 1.0 } } } },
                tooltip = "Color of the selection overlay for Orbit-owned frames.",
            },
        },
        onReset = function()
            local d = Orbit.db.GlobalSettings
            if d then
                d.ShowBlizzardFrames = true
                d.ShowOrbitFrames = true
                d.AnchoringEnabled = true
                d.EditModeColor = { r = 0.7, g = 0.6, b = 1.0, a = 1.0 }
                d.EditModeColorCurve = { pins = { { position = 0, color = { r = 0.7, g = 0.6, b = 1.0, a = 1.0 } } } }
            end
            if Orbit.Engine.FrameSelection then Orbit.Engine.FrameSelection:RefreshVisuals() end
            Orbit:Print("Edit Mode settings reset to defaults.")
        end,
    }
end

-- [ PROFILES TAB ]----------------------------------------------------------------------------------

local ICON_BUTTON_SIZE = 20
local ICON_FONT_SIZE = 20

-- Composite widget: dropdown + reset icon for active profile
Layout:RegisterWidgetType("profileactive", function(container, def, getValue, callback)
    local options = type(def.options) == "function" and def.options() or def.options or {}
    local initialValue = getValue and getValue() or def.default or ""

    local UpdateResetState

    local frame = Layout:CreateDropdown(container, def.label, options, initialValue, function(value)
        if callback then callback(value) end
        C_Timer.After(0, function() if UpdateResetState then UpdateResetState() end end)
    end)
    frame.OrbitType = "ProfileActive"

    UpdateResetState = function()
        if not frame.resetBtn then return end
        local isGlobal = frame.currentValue == "Global"
        if isGlobal then
            frame.resetBtn:Enable()
            frame.resetBtn.Icon:SetDesaturated(false)
            frame.resetBtn.Icon:SetAlpha(1)
        else
            frame.resetBtn:Disable()
            frame.resetBtn.Icon:SetDesaturated(true)
            frame.resetBtn.Icon:SetAlpha(0.4)
        end
    end

    local resetBtn = CreateFrame("Button", nil, frame)
    resetBtn:SetSize(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE)
    resetBtn:SetPoint("LEFT", frame.Dropdown, "RIGHT", 5, 0)
    frame.resetBtn = resetBtn
    local icon = resetBtn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas("talents-button-undo")
    resetBtn.Icon = icon
    resetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self:IsEnabled() then
            self.Icon:SetAlpha(0.8)
            GameTooltip:SetText("Reset Global profile to defaults")
        else
            GameTooltip:SetText("Only the Global profile can be reset")
        end
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function(self)
        if self:IsEnabled() then self.Icon:SetAlpha(1) end
        GameTooltip:Hide()
    end)
    resetBtn:SetScript("OnClick", function()
        if def.onReset then def.onReset() end
    end)

    UpdateResetState(frame)
    return frame
end)

-- Composite widget: dropdown + copy icon + X delete button
Layout:RegisterWidgetType("profileselect", function(container, def, getValue, callback)
    local options = type(def.options) == "function" and def.options() or def.options or {}
    local initialValue = getValue and getValue() or def.default or ""

    -- Forward-declare so the closure below can reference it
    local UpdateDeleteState

    -- Use the standard dropdown factory for proper rendering
    local frame = Layout:CreateDropdown(container, def.label, options, initialValue, function(value)
        if callback then callback(value) end
        C_Timer.After(0, function() if UpdateDeleteState then UpdateDeleteState() end end)
    end)
    frame.OrbitType = "ProfileSelect"

    -- Assign to the forward-declared upvalue
    UpdateDeleteState = function()
        if not frame.xBtn then return end
        local val = frame.currentValue
        local isActive = val == Orbit.Profile:GetActiveProfileName()
        local isGlobal = val == "Global"
        -- Copy is always allowed; delete is blocked for active/Global
        frame.copyBtn:Enable()
        frame.copyBtn.Text:SetTextColor(0.2, 0.8, 0.2, 1)
        if isActive or isGlobal then
            frame.xBtn:Disable()
            frame.xBtn.Text:SetTextColor(0.4, 0.4, 0.4, 0.5)
        else
            frame.xBtn:Enable()
            frame.xBtn.Text:SetTextColor(1, 0.27, 0.27, 1)
        end
    end


    local gap = Constants.Widget.ValueWidth
    local pairWidth = ICON_BUTTON_SIZE * 2 + 2
    local pairOffset = (gap - pairWidth) / 2
    local copyBtn = CreateFrame("Button", nil, frame)
    copyBtn:SetSize(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE)
    copyBtn:SetPoint("LEFT", frame.Dropdown, "RIGHT", pairOffset + 10, 0)
    frame.copyBtn = copyBtn
    local copyText = copyBtn:CreateFontString(nil, "ARTWORK")
    copyText:SetFont(STANDARD_TEXT_FONT, ICON_FONT_SIZE, "OUTLINE")
    copyText:SetAllPoints()
    copyText:SetText("+")
    copyText:SetTextColor(0.2, 0.8, 0.2, 1)
    copyBtn.Text = copyText
    copyBtn:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            self.Text:SetTextColor(0.3, 1, 0.3, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Copy selected profile")
        end
        GameTooltip:Show()
    end)
    copyBtn:SetScript("OnLeave", function(self)
        if self:IsEnabled() then self.Text:SetTextColor(0.2, 0.8, 0.2, 1) end
        GameTooltip:Hide()
    end)
    copyBtn:SetScript("OnClick", function()
        if def.onCopy then def.onCopy(frame.currentValue) end
    end)

    -- X delete button
    local xBtn = CreateFrame("Button", nil, frame)
    xBtn:SetSize(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE)
    xBtn:SetPoint("LEFT", copyBtn, "RIGHT", 2, 0)
    frame.xBtn = xBtn
    local xText = xBtn:CreateFontString(nil, "ARTWORK")
    xText:SetFont(STANDARD_TEXT_FONT, ICON_FONT_SIZE, "OUTLINE")
    xText:SetAllPoints()
    xText:SetText("\195\151")
    xText:SetTextColor(1, 0.27, 0.27, 1)
    xBtn.Text = xText
    xBtn:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            self.Text:SetTextColor(1, 0.5, 0.5, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Delete selected profile")
        else
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Cannot delete active or Global profile")
        end
        GameTooltip:Show()
    end)
    xBtn:SetScript("OnLeave", function(self)
        if self:IsEnabled() then self.Text:SetTextColor(1, 0.27, 0.27, 1) end
        GameTooltip:Hide()
    end)
    xBtn:SetScript("OnClick", function()
        if def.onDelete then def.onDelete(frame.currentValue) end
    end)

    UpdateDeleteState()
    return frame
end)

-- Collapsible header: text + toggle arrow (far right)
local ARROW_SIZE = 16
local ARROW_DOWN = -math.pi / 2
local ARROW_UP = math.pi / 2

Layout:RegisterWidgetType("collapseheader", function(container, def)
    local frame = CreateFrame("Button", nil, container)
    frame:SetHeight(30)
    frame.OrbitType = "CollapseHeader"

    local text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    text:SetPoint("LEFT", 0, 0)
    text:SetText(def.text or "")

    local arrow = frame:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
    arrow:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    arrow:SetAtlas("shop-header-arrow")
    arrow:SetRotation(def.collapsed and ARROW_DOWN or ARROW_UP)

    frame:SetScript("OnClick", function()
        if def.onToggle then def.onToggle() end
    end)
    frame:SetScript("OnEnter", function()
        arrow:SetAtlas("shop-header-arrow-hover")
        arrow:SetRotation(def.collapsed and ARROW_DOWN or ARROW_UP)
    end)
    frame:SetScript("OnLeave", function()
        arrow:SetAtlas("shop-header-arrow")
        arrow:SetRotation(def.collapsed and ARROW_DOWN or ARROW_UP)
    end)
    frame:SetScript("OnMouseDown", function()
        arrow:SetAtlas("shop-header-arrow-pressed")
        arrow:SetRotation(def.collapsed and ARROW_DOWN or ARROW_UP)
    end)
    frame:SetScript("OnMouseUp", function()
        arrow:SetAtlas("shop-header-arrow-hover")
        arrow:SetRotation(def.collapsed and ARROW_DOWN or ARROW_UP)
    end)

    return frame
end)

local specProfilesExpanded = false
local profilesSubView = nil -- nil, "export", "import", "clone", "delete"
local exportSelectedProfile = nil
local exportString = ""
local importString = ""
local importName = ""
local cloneSource = nil
local cloneName = ""
local deleteTarget = nil

local ProfilesPlugin = {
    name = "OrbitProfiles",
    settings = {},
    GetSetting = function(self, systemIndex, key)
        if key == "ActiveProfile" then return Orbit.Profile:GetActiveProfileName()
        elseif key == "CreateProfile" then return Orbit.Profile._selectedToCreate or "Global"
        elseif key == "ExportProfile" then return exportSelectedProfile or "Global"
        elseif key == "ExportString" then return exportString
        elseif key == "ImportString" then return importString
        elseif key == "ImportName" then return importName
        elseif key == "CloneName" then return cloneName
        end
        local specID = key:match("^SpecMapping_(%d+)$")
        if specID then return Orbit.Profile:GetProfileForSpec(tonumber(specID)) or "Global" end
        return nil
    end,
    SetSetting = function(self, systemIndex, key, value)
        if key == "ActiveProfile" then
            Orbit.Profile:SetActiveProfile(value)
            if Orbit.OptionsPanel then
                Orbit.OptionsPanel.lastTab = nil
                Orbit.OptionsPanel:Open("Profiles")
            end
        elseif key == "CreateProfile" then
            Orbit.Profile._selectedToCreate = value
        elseif key == "ExportProfile" then
            exportSelectedProfile = value
            local str = Orbit.Profile:ExportSingleProfile(value)
            exportString = str or ""
            if Orbit.OptionsPanel then Orbit.OptionsPanel.lastTab = nil; Orbit.OptionsPanel:Open("Profiles") end
        elseif key == "ExportString" then
            exportString = value or ""
        elseif key == "ImportString" then
            importString = value or ""
        elseif key == "ImportName" then
            importName = value or ""
        elseif key == "CloneName" then
            cloneName = value or ""
        else
            local specID = key:match("^SpecMapping_(%d+)$")
            if specID then
                specID = tonumber(specID)
                local profileName = (value == "Global") and nil or value
                Orbit.Profile:SetProfileForSpec(specID, profileName)
                local _, specName = GetSpecializationInfoByID(specID)
                Orbit:Print("Spec '" .. (specName or "?") .. "' → " .. (value or "Global"))
                Orbit.Profile:CheckSpecProfile()
            end
        end
    end,
    ApplySettings = function(self, systemFrame) end,
}

local function GetProfileOptions()
    local opts = {}
    for _, n in ipairs(Orbit.Profile:GetProfiles()) do
        table.insert(opts, { text = n, value = n })
    end
    return opts
end

local function GetProfileOptionsWithDefault()
    local opts = { { text = "Global", value = "Global" } }
    for _, n in ipairs(Orbit.Profile:GetProfiles()) do
        if n ~= "Global" then
            table.insert(opts, { text = n, value = n })
        end
    end
    return opts
end


local flashLabel
Layout:RegisterWidgetType("statusmessage", function(container, def)
    local frame = CreateFrame("Frame", nil, container)
    frame:SetHeight(20)
    frame.OrbitType = "StatusMessage"
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetTextColor(1, 0.3, 0.3)
    text:SetText("")
    frame.Text = text
    flashLabel = frame
    return frame
end)

local flashActive = false
local function ShowFlashMessage(msg)
    if not flashLabel or flashActive then return end
    flashActive = true
    flashLabel.Text:SetText(msg)
    flashLabel:SetAlpha(0)
    flashLabel:Show()
    UIFrameFadeIn(flashLabel, 0.2, 0, 1)
    C_Timer.After(2, function()
        if not flashLabel then flashActive = false; return end
        UIFrameFadeOut(flashLabel, 0.5, 1, 0)
        C_Timer.After(0.5, function() flashActive = false end)
    end)
end

local function ReopenProfiles()
    if Orbit.OptionsPanel then
        Orbit.OptionsPanel.lastTab = nil
        Orbit.OptionsPanel.currentTab = nil
        Orbit.OptionsPanel:Open("Profiles")
    end
end

local function GetProfilesSchema()
    -- Export sub-view
    if profilesSubView == "export" then
        return {
            hideNativeSettings = true,
            hideResetButton = true,
            controls = {
                { type = "header", text = "Export Profile" },
                { type = "dropdown", key = "ExportProfile", label = "Profile", options = GetProfileOptions, default = "Global", width = DROPDOWN_WIDTH },
                { type = "spacer", height = SPACER_SMALL },
                { type = "editbox", key = "ExportString", label = "Export String", height = 120, multiline = true, readOnly = true, hideScrollBar = true },
                { type = "spacer", height = SPACER_SMALL },
            },
            extraButtons = {
                {
                    text = "\194\171 Back",
                    callback = function() profilesSubView = nil; exportString = ""; exportSelectedProfile = nil; ReopenProfiles() end,
                },
            },
        }
    end

    -- Import sub-view
    if profilesSubView == "import" then
        return {
            hideNativeSettings = true,
            hideResetButton = true,
            controls = {
                { type = "header", text = "Import Profile" },
                { type = "editbox", key = "ImportString", label = "Paste String", height = 120, multiline = true, hideScrollBar = true },
                { type = "statusmessage" },
                { type = "editbox", key = "ImportName", label = "Profile Name", height = 50 },
            },
            extraButtons = {
                {
                    text = "\194\171 Back",
                    callback = function() profilesSubView = nil; importString = ""; importName = ""; ReopenProfiles() end,
                },
                {
                    text = "Apply",
                    callback = function()
                        if importString == "" then ShowFlashMessage("Please paste an import string."); return end
                        if importName == "" then ShowFlashMessage("Please enter a profile name."); return end
                        for _, n in ipairs(Orbit.Profile:GetProfiles()) do
                            if n == importName then ShowFlashMessage("A profile named '" .. importName .. "' already exists."); return end
                        end
                        local ok, err = Orbit.Profile:ImportProfile(importString, importName)
                        if ok then
                            Orbit:Print("Import successful.")
                            profilesSubView = nil
                            importString = ""
                            importName = ""
                            ReopenProfiles()
                        else
                            ShowFlashMessage("Invalid Import String.")
                        end
                    end,
                },
            },
        }
    end

    -- Clone sub-view
    if profilesSubView == "clone" then
        return {
            hideNativeSettings = true,
            hideResetButton = true,
            controls = {
                { type = "header", text = "Clone Profile" },
                { type = "description", text = "Create a copy of '" .. (cloneSource or "?") .. "' with a new name." },
                { type = "spacer", height = SPACER_SMALL },
                { type = "editbox", key = "CloneName", label = "New Name", height = 50 },
            },
            extraButtons = {
                { text = "\194\171 Back", callback = function() profilesSubView = nil; cloneName = ""; cloneSource = nil; ReopenProfiles() end },
                {
                    text = "Create",
                    callback = function()
                        if cloneName == "" then Orbit:Print("Please enter a profile name."); return end
                        local created = Orbit.Profile:CreateProfile(cloneName, cloneSource)
                        if created then
                            Orbit:Print("Created profile '" .. cloneName .. "' (from '" .. (cloneSource or "?") .. "')")
                            profilesSubView = nil; cloneName = ""; cloneSource = nil
                            ReopenProfiles()
                        else
                            Orbit:Print("A profile named '" .. cloneName .. "' already exists.")
                        end
                    end,
                },
            },
        }
    end

    -- Delete sub-view
    if profilesSubView == "delete" then
        return {
            hideNativeSettings = true,
            hideResetButton = true,
            controls = {
                { type = "header", text = "Delete Profile" },
                { type = "description", text = "|cFFFF0000WARNING:|r You are about to delete '" .. (deleteTarget or "?") .. "'.\n\nThis cannot be undone." },
            },
            extraButtons = {
                { text = "\194\171 Back", callback = function() profilesSubView = nil; deleteTarget = nil; ReopenProfiles() end },
                {
                    text = "Delete",
                    callback = function()
                        if deleteTarget then
                            Orbit.Profile:DeleteProfile(deleteTarget)
                            Orbit:Print("Deleted profile '" .. deleteTarget .. "'")
                        end
                        profilesSubView = nil; deleteTarget = nil
                        ReopenProfiles()
                    end,
                },
            },
        }
    end

    -- Reset Global sub-view
    if profilesSubView == "resetglobal" then
        return {
            hideNativeSettings = true,
            hideResetButton = true,
            controls = {
                { type = "header", text = "Reset Global Profile" },
                { type = "description", text = "|cFFFF0000WARNING:|r You are about to reset the 'Global' profile back to its factory defaults.\n\nAll customizations on this profile will be lost. Your other profiles will not be affected.\n\nThis cannot be undone." },
            },
            extraButtons = {
                { text = "\194\171 Back", callback = function() profilesSubView = nil; ReopenProfiles() end },
                {
                    text = "Reset to Defaults",
                    callback = function()
                        Orbit.API:ResetProfile("Global")
                        profilesSubView = nil
                        ReopenProfiles()
                    end,
                },
            },
        }
    end

    -- Main profiles view
    local controls = {}

    controls[#controls + 1] = { type = "header", text = "Profile" }
    controls[#controls + 1] = {
        type = "profileactive", key = "ActiveProfile", label = "Active",
        options = GetProfileOptions, default = "Global", width = DROPDOWN_WIDTH,
        onReset = function() profilesSubView = "resetglobal"; ReopenProfiles() end,
    }
    controls[#controls + 1] = {
        type = "profileselect", key = "CreateProfile", label = "Manage",
        options = GetProfileOptions, default = "Global",
        onCopy = function(selected)
            cloneSource = selected
            cloneName = ""
            profilesSubView = "clone"
            ReopenProfiles()
        end,
        onDelete = function(selected)
            if selected == "Global" then Orbit:Print("Cannot delete the Global profile."); return end
            if selected == Orbit.Profile:GetActiveProfileName() then Orbit:Print("Cannot delete the active profile."); return end
            deleteTarget = selected
            profilesSubView = "delete"
            ReopenProfiles()
        end,
    }
    controls[#controls + 1] = { type = "spacer", height = SPACER_LARGE }

    -- Spec Profiles (collapsible)
    local expanded = specProfilesExpanded
    controls[#controls + 1] = {
        type = "collapseheader", text = "Spec Profiles", collapsed = not expanded,
        onToggle = function()
            specProfilesExpanded = not specProfilesExpanded
            ReopenProfiles()
        end,
    }
    if expanded then
        controls[#controls + 1] = {
            type = "description",
            text = "Assign a profile to each specialization. When you change spec, Orbit switches automatically.",
        }
        local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
        for i = 1, numSpecs do
            local specID, specName = GetSpecializationInfo(i)
            if specID and specName then
                controls[#controls + 1] = {
                    type = "dropdown", key = "SpecMapping_" .. specID, label = specName,
                    options = GetProfileOptionsWithDefault, default = "Global", width = DROPDOWN_WIDTH,
                }
            end
        end
    end
    controls[#controls + 1] = { type = "spacer", height = SPACER_SMALL }

    return {
        hideNativeSettings = true,
        hideResetButton = true,
        controls = controls,
        extraButtons = {
            { text = "Export", callback = function()
                local active = Orbit.Profile:GetActiveProfileName()
                exportSelectedProfile = active
                exportString = Orbit.Profile:ExportSingleProfile(active) or ""
                profilesSubView = "export"
                ReopenProfiles()
            end },
            { text = "Import", callback = function() profilesSubView = "import"; ReopenProfiles() end },
        },
    }
end



-- [ MAIN LOGIC ]------------------------------------------------------------------------------------

local TABS = {
    { name = "Global", plugin = GlobalPlugin, schema = GetGlobalSchema },
    { name = "Colors", plugin = ColorsPlugin, schema = GetColorsSchema },
    { name = "Edit Mode", plugin = EditModePlugin, schema = GetEditModeSchema },
    { name = "Profiles", plugin = ProfilesPlugin, schema = GetProfilesSchema },
}

function Panel:Open(tabName)
    if InCombatLockdown() then return end
    local dialog = Orbit.SettingsDialog
    if not dialog then return end

    tabName = tabName or self.lastTab or TABS[1].name

    local tabDef = nil
    for _, t in ipairs(TABS) do
        if t.name == tabName then tabDef = t; break end
    end
    tabDef = tabDef or TABS[1]

    if dialog:IsShown() and self.lastTab == tabDef.name and dialog.Title and dialog.Title:GetText() == "Orbit Options" then
        return
    end

    if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
        EditModeSystemSettingsDialog:Hide()
    end

    self.lastTab = tabDef.name
    dialog.orbitCurrentTab = tabDef.name
    dialog.attachedPlugin = nil
    dialog:Show()

    if dialog.Title then dialog.Title:SetText("Orbit Options") end

    local tabNames = {}
    for _, t in ipairs(TABS) do tabNames[#tabNames + 1] = t.name end

    local schema = tabDef.schema()
    table.insert(schema.controls, 1, {
        type = "tabs", tabs = tabNames, activeTab = tabDef.name,
        onTabSelected = function(newTab) Panel:Open(newTab) end,
    })

    local mockFrame = CreateFrame("Frame")
    mockFrame.systemIndex = 1
    mockFrame.system = "Orbit_" .. tabDef.name

    Config:Render(dialog, mockFrame, tabDef.plugin, schema, tabDef.name)
    dialog:PositionNearButton()
end

function Panel:Hide()
    local dialog = Orbit.SettingsDialog
    if dialog and dialog:IsShown() then dialog:Hide() end
end

-- [ TOGGLE LOGIC ]----------------------------------------------------------------------------------

function Panel:Toggle(tab)
    local dialog = Orbit.SettingsDialog
    if not dialog then Orbit:Print("Orbit Settings dialog not available"); return end

    if dialog:IsShown() and self.currentTab == tab then
        dialog:Hide()
        self.currentTab = nil
        return
    end

    if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
        EditModeSystemSettingsDialog:Hide()
    end

    self.currentTab = tab

    local systemFrame = CreateFrame("Frame")
    systemFrame.systemIndex = 1
    systemFrame.system = "Orbit_" .. tab

    if tab == "Profiles" and dialog.Title then
        dialog.Title:SetText("Profiles - " .. Orbit.Profile:GetActiveProfileName())
    end

    if tab == "Profiles" then
        Config:Render(dialog, systemFrame, ProfilesPlugin, GetProfilesSchema(), "Profiles")
    end

    dialog:Show()
    dialog:PositionNearButton()
end

function Panel:Refresh()
    local tabToRefresh = self.currentTab or self.lastTab
    if tabToRefresh then
        self.currentTab = nil
        self.lastTab = nil
        self:Open(tabToRefresh)
    end
end

-- [ SLASH COMMANDS ]--------------------------------------------------------------------------------

SLASH_ORBIT1 = "/orbit"
SLASH_ORBIT2 = "/orb"

StaticPopupDialogs["ORBIT_CONFIRM_HARD_RESET"] = {
    text = "|cFFFF0000DANGER|r\n\nYou are about to FACTORY RESET Orbit.\n\nAll profiles, settings, and data will be wiped.\nThe UI will reload immediately.\n\nAre you sure?",
    button1 = "Factory Reset", button2 = "Cancel",
    OnAccept = function(self) Orbit.API:HardReset() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = POPUP_PREFERRED_INDEX,
}

SlashCmdList["ORBIT"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do table.insert(args, word) end
    local cmd = args[1] and args[1]:lower() or ""

    if cmd == "" then
        if EditModeManagerFrame then
            if EditModeManagerFrame:IsShown() then
                HideUIPanel(EditModeManagerFrame)
                Panel:Hide()
            else
                ShowUIPanel(EditModeManagerFrame)
                Panel:Open("Global")
            end
        else
            Orbit:Print("Edit Mode not available.")
        end
        return
    end

    if cmd == "whatsnew" then Orbit:ShowWhatsNew(); return end

    if cmd == "plugins" then
        if Orbit._pluginSettingsCategoryID then
            Settings.OpenToCategory(Orbit._pluginSettingsCategoryID)
        else
            Orbit:Print("Plugin Manager not yet loaded.")
        end
    elseif cmd == "hardreset" then StaticPopup_Show("ORBIT_CONFIRM_HARD_RESET")
    elseif cmd == "portal" or cmd == "p" then
        local subCmd = args[2] and args[2]:lower() or ""
        Orbit.EventBus:Fire("ORBIT_PORTAL_COMMAND", subCmd)
    elseif cmd == "refresh" then
        local subCmd = args[2] or ""
        if subCmd == "" then
            Orbit:Print("Usage: /orbit refresh <plugin_system_id>")
            Orbit:Print("Example: /orbit refresh Orbit_CooldownViewer")
            return
        end
        if Orbit.Skin and Orbit.Skin.Icons then
            Orbit.Skin.Icons.regionCache = setmetatable({}, { __mode = "k" })
        end
        local plugin = Orbit:GetPlugin(subCmd)
        if plugin then
            if plugin.ReapplyParentage then plugin:ReapplyParentage() end
            if plugin.ApplyAll then plugin:ApplyAll()
            elseif plugin.ApplySettings then plugin:ApplySettings() end
            Orbit:Print(subCmd .. " refreshed.")
        else
            Orbit:Print("Plugin not found: " .. subCmd)
        end
    elseif cmd == "flush" then
        if Orbit.ViewerInjection then
            Orbit.ViewerInjection:FlushAll()
            Orbit:Print("Cleared all injected cooldown icons.")
        else
            Orbit:Print("ViewerInjection not loaded.")
        end
    else
        Orbit:Print("Unknown command: " .. cmd)
    end
end
