-- [ PROFILES TAB ]----------------------------------------------------------------------------------
-- Profile management for the Orbit Options dialog. Active profile, spec profiles, create/clone/
-- delete/import/export. Registers tab-local widget types (profileactive, profileselect,
-- collapseheader, checkheader, statusmessage).
--
-- LOCALIZATION WARNING: the "Global" profile name on line ~337 is a reserved identifier,
-- not a generic label. When migrating, keep the `value = "Global"` literal and only localize
-- the `text`. See Orbit/Localization/PHASE_0_DROPDOWN_AUDIT.md.

local _, Orbit = ...
local L = Orbit.L
local OrbitEngine = Orbit.Engine
local Layout = OrbitEngine.Layout
local Constants = Orbit.Constants

local Panel = Orbit.OptionsPanel

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local DROPDOWN_WIDTH = 200
local SPACER_SMALL = 10
local SPACER_LARGE = 20
local ICON_BUTTON_SIZE = 14
local ARROW_SIZE = 16
local ARROW_DOWN = -math.pi / 2
local ARROW_UP = math.pi / 2
local CHECKBOX_SIZE = 20
local DISABLED_ALPHA = 0.4
local HOVER_ALPHA = 0.8

-- [ WIDGET: PROFILE ACTIVE ]------------------------------------------------------------------------
-- Composite widget: dropdown for active profile (greyed out when spec profiles control it)
Layout:RegisterWidgetType("profileactive", function(container, def, getValue, callback)
    local options = type(def.options) == "function" and def.options() or def.options or {}
    local initialValue = getValue and getValue() or def.default or ""
    local frame = Layout:CreateDropdown(container, def.label, options, initialValue, function(value)
        if callback then callback(value) end
    end)
    frame.OrbitType = "ProfileActive"
    if Orbit.Profile:IsSpecProfilesEnabled() then
        frame:SetAlpha(DISABLED_ALPHA)
        if frame.Dropdown then
            frame.Dropdown:SetEnabled(false)
            frame.Dropdown:EnableMouse(false)
        end
        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints()
        overlay:SetFrameLevel((frame.Dropdown and frame.Dropdown:GetFrameLevel() or frame:GetFrameLevel()) + 10)
        overlay:EnableMouse(true)
        overlay:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.CFG_SPEC_PROFILES_CONTROL)
            GameTooltip:Show()
        end)
        overlay:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return frame
end)

-- [ WIDGET: PROFILE SELECT ]------------------------------------------------------------------------
-- Composite widget: dropdown + reset/copy/delete icons
Layout:RegisterWidgetType("profileselect", function(container, def, getValue, callback)
    local options = type(def.options) == "function" and def.options() or def.options or {}
    local initialValue = getValue and getValue() or def.default or ""
    local UpdateButtonStates
    local frame = Layout:CreateDropdown(container, def.label, options, initialValue, function(value)
        if callback then callback(value) end
        C_Timer.After(0, function() if UpdateButtonStates then UpdateButtonStates() end end)
    end)
    frame.OrbitType = "ProfileSelect"

    UpdateButtonStates = function()
        if not frame.resetBtn then return end
        local val = frame.currentValue
        local isActive = val == Orbit.Profile:GetActiveProfileName()
        local isGlobal = val == "Global"
        -- Reset: only Global
        if isGlobal then
            frame.resetBtn:Enable()
            frame.resetBtn.Icon:SetDesaturated(false)
            frame.resetBtn.Icon:SetAlpha(1)
        else
            frame.resetBtn:Disable()
            frame.resetBtn.Icon:SetDesaturated(true)
            frame.resetBtn.Icon:SetAlpha(DISABLED_ALPHA)
        end
        -- Copy: always allowed
        frame.copyBtn:Enable()
        frame.copyBtn.Icon:SetDesaturated(false)
        frame.copyBtn.Icon:SetAlpha(1)
        -- Delete: blocked for active/Global
        if isActive or isGlobal then
            frame.xBtn:Disable()
            frame.xBtn.Icon:SetDesaturated(true)
            frame.xBtn.Icon:SetAlpha(DISABLED_ALPHA)
        else
            frame.xBtn:Enable()
            frame.xBtn.Icon:SetDesaturated(false)
            frame.xBtn.Icon:SetAlpha(1)
        end
    end

    local gap = Constants.Widget.ValueWidth
    local tripleWidth = ICON_BUTTON_SIZE * 3 + 4
    local tripleOffset = (gap - tripleWidth) / 2

    -- Reset button (undo icon)
    local resetBtn = CreateFrame("Button", nil, frame)
    resetBtn:SetSize(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE)
    resetBtn:SetPoint("LEFT", frame.Dropdown, "RIGHT", tripleOffset + 10, 0)
    frame.resetBtn = resetBtn
    local resetIcon = resetBtn:CreateTexture(nil, "ARTWORK")
    resetIcon:SetAllPoints()
    resetIcon:SetAtlas("talents-button-undo")
    resetBtn.Icon = resetIcon
    resetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self:IsEnabled() then
            self.Icon:SetAlpha(HOVER_ALPHA)
            GameTooltip:SetText(L.CMN_RESET_PROFILE_TOOLTIP)
        else
            GameTooltip:SetText(L.CMN_ONLY_GLOBAL_RESET)
        end
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function(self)
        if self:IsEnabled() then self.Icon:SetAlpha(1) end
        GameTooltip:Hide()
    end)
    resetBtn:SetScript("OnClick", function()
        if def.onReset then def.onReset(frame.currentValue) end
    end)

    -- Copy button (+ icon)
    local copyBtn = CreateFrame("Button", nil, frame)
    copyBtn:SetSize(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE)
    copyBtn:SetPoint("LEFT", resetBtn, "RIGHT", 2, 0)
    frame.copyBtn = copyBtn
    local copyIcon = copyBtn:CreateTexture(nil, "ARTWORK")
    copyIcon:SetAllPoints()
    copyIcon:SetAtlas("communities-chat-icon-plus")
    copyBtn.Icon = copyIcon
    copyBtn:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            self.Icon:SetAlpha(HOVER_ALPHA)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.CMN_COPY_PROFILE_TOOLTIP)
            GameTooltip:Show()
        end
    end)
    copyBtn:SetScript("OnLeave", function(self)
        if self:IsEnabled() then self.Icon:SetAlpha(1) end
        GameTooltip:Hide()
    end)
    copyBtn:SetScript("OnClick", function()
        if def.onCopy then def.onCopy(frame.currentValue) end
    end)

    -- Delete button (X icon)
    local xBtn = CreateFrame("Button", nil, frame)
    xBtn:SetSize(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE)
    xBtn:SetPoint("LEFT", copyBtn, "RIGHT", 2, 0)
    frame.xBtn = xBtn
    local xIcon = xBtn:CreateTexture(nil, "ARTWORK")
    xIcon:SetAllPoints()
    xIcon:SetAtlas("transmog-icon-remove")
    xBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self:IsEnabled() then
            self.Icon:SetAlpha(HOVER_ALPHA)
            GameTooltip:SetText(L.CMN_DELETE_PROFILE_TOOLTIP)
        else
            GameTooltip:SetText(L.CMN_CANNOT_DELETE_ACTIVE)
        end
        GameTooltip:Show()
    end)
    xBtn:SetScript("OnLeave", function(self)
        if self:IsEnabled() then self.Icon:SetAlpha(1) end
        GameTooltip:Hide()
    end)
    xBtn:SetScript("OnClick", function()
        if def.onDelete then def.onDelete(frame.currentValue) end
    end)
    xBtn.Icon = xIcon

    UpdateButtonStates()
    return frame
end)

-- [ WIDGET: COLLAPSE HEADER ]-----------------------------------------------------------------------
-- Collapsible header: text + toggle arrow (far right)
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

-- [ WIDGET: CHECK HEADER ]--------------------------------------------------------------------------
-- Header with checkbox toggle on the right (same visual as collapseheader)
Layout:RegisterWidgetType("checkheader", function(container, def, getValue, callback)
    local frame = CreateFrame("Frame", nil, container)
    frame:SetHeight(30)
    frame.OrbitType = "CheckHeader"
    local text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    text:SetPoint("LEFT", 0, 0)
    text:SetText(def.text or "")
    local cb = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    cb:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    cb:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    local checked = getValue and getValue() or false
    cb:SetChecked(checked)
    cb:SetScript("OnClick", function(self)
        if callback then callback(self:GetChecked()) end
    end)
    if def.tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(def.tooltip)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return frame
end)

-- [ STATE ]-----------------------------------------------------------------------------------------

local profilesSubView = nil -- nil, "export", "import", "clone", "delete"
local exportSelectedProfile = nil
local exportString = ""
local importString = ""
local importName = ""
local cloneSource = nil
local cloneName = ""
local deleteTarget = nil

-- [ PLUGIN ]----------------------------------------------------------------------------------------

local ProfilesPlugin = {
    name = "OrbitProfiles",
    settings = {},
    GetSetting = function(self, systemIndex, key)
        if key == "ActiveProfile" then return Orbit.Profile:GetActiveProfileName()
        elseif key == "UseSpecProfiles" then return Orbit.Profile:IsSpecProfilesEnabled()
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
        elseif key == "UseSpecProfiles" then
            Orbit.Profile:SetSpecProfilesEnabled(value)
            if value then
                Orbit.Profile:CheckSpecProfile()
            else
                if Orbit.db.specMappings then wipe(Orbit.db.specMappings) end
            end
            if Orbit.OptionsPanel then Orbit.OptionsPanel.lastTab = nil; Orbit.OptionsPanel.currentTab = nil; Orbit.OptionsPanel:Open("Profiles") end
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
                Orbit:Print(L.MSG_SPEC_MAPPED_F:format(specName or "?", value or "Global"))
                Orbit.Profile:CheckSpecProfile()
            end
        end
    end,
    ApplySettings = function(self, systemFrame) end,
}

-- [ HELPERS ]---------------------------------------------------------------------------------------

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

-- [ WIDGET: STATUS MESSAGE ]------------------------------------------------------------------------

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

-- [ SCHEMA ]----------------------------------------------------------------------------------------

local function GetProfilesSchema()
    -- Export sub-view
    if profilesSubView == "export" then
        return {
            hideNativeSettings = true,
            hideResetButton = true,
            controls = {
                { type = "header", text = L.CFG_EXPORT_PROFILE },
                { type = "dropdown", key = "ExportProfile", label = L.CFG_PROFILE_LABEL, options = GetProfileOptions, default = "Global", width = DROPDOWN_WIDTH },
                { type = "spacer", height = SPACER_SMALL },
                { type = "editbox", key = "ExportString", label = L.CFG_EXPORT_STRING, height = 120, multiline = true, readOnly = true, hideScrollBar = true },
                { type = "spacer", height = SPACER_SMALL },
            },
            extraButtons = {
                {
                    text = L.CMN_BACK,
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
                { type = "header", text = L.CFG_IMPORT_PROFILE },
                { type = "editbox", key = "ImportString", label = L.CFG_PASTE_STRING, height = 120, multiline = true, hideScrollBar = true },
                { type = "statusmessage" },
                { type = "editbox", key = "ImportName", label = L.CFG_PROFILE_NAME, height = 50 },
            },
            extraButtons = {
                {
                    text = L.CMN_BACK,
                    callback = function() profilesSubView = nil; importString = ""; importName = ""; ReopenProfiles() end,
                },
                {
                    text = L.CMN_APPLY,
                    callback = function()
                        if importString == "" then ShowFlashMessage(L.MSG_PASTE_IMPORT_STRING); return end
                        if importName == "" then ShowFlashMessage(L.MSG_ENTER_PROFILE_NAME); return end
                        for _, n in ipairs(Orbit.Profile:GetProfiles()) do
                            if n == importName then ShowFlashMessage(L.MSG_PROFILE_EXISTS_F:format(importName)); return end
                        end
                        local ok, err = Orbit.Profile:ImportProfile(importString, importName)
                        if ok then
                            Orbit:Print(L.MSG_IMPORT_SUCCESS)
                            profilesSubView = nil
                            importString = ""
                            importName = ""
                            ReopenProfiles()
                        else
                            ShowFlashMessage(L.MSG_INVALID_IMPORT)
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
                { type = "header", text = L.CFG_CLONE_PROFILE },
                { type = "description", text = L.CFG_CLONE_PROFILE_DESC_F:format(cloneSource or "?") },
                { type = "spacer", height = SPACER_SMALL },
                { type = "editbox", key = "CloneName", label = L.CFG_NEW_NAME, height = 50 },
            },
            extraButtons = {
                { text = L.CMN_BACK, callback = function() profilesSubView = nil; cloneName = ""; cloneSource = nil; ReopenProfiles() end },
                {
                    text = L.CMN_CREATE,
                    callback = function()
                        if cloneName == "" then Orbit:Print(L.MSG_ENTER_PROFILE_NAME); return end
                        local created = Orbit.Profile:CreateProfile(cloneName, cloneSource)
                        if created then
                            Orbit:Print(L.MSG_PROFILE_CREATED_F:format(cloneName, cloneSource or "?"))
                            profilesSubView = nil; cloneName = ""; cloneSource = nil
                            ReopenProfiles()
                        else
                            Orbit:Print(L.MSG_PROFILE_EXISTS_F:format(cloneName))
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
                { type = "header", text = L.CFG_DELETE_PROFILE_HEADER },
                { type = "description", text = L.CFG_DELETE_WARNING_F:format(deleteTarget or "?") },
            },
            extraButtons = {
                { text = L.CMN_BACK, callback = function() profilesSubView = nil; deleteTarget = nil; ReopenProfiles() end },
                {
                    text = L.CMN_DELETE,
                    callback = function()
                        if deleteTarget then
                            Orbit.Profile:DeleteProfile(deleteTarget)
                            Orbit:Print(L.MSG_PROFILE_DELETED_F:format(deleteTarget))
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
                { type = "header", text = L.CFG_RESET_GLOBAL },
                { type = "description", text = L.CFG_RESET_GLOBAL_WARNING },
            },
            extraButtons = {
                { text = L.CMN_BACK, callback = function() profilesSubView = nil; ReopenProfiles() end },
                {
                    text = L.CMN_RESET_TO_DEFAULTS,
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

    controls[#controls + 1] = { type = "header", text = L.CFG_PROFILE_LABEL }
    controls[#controls + 1] = {
        type = "profileactive", key = "ActiveProfile", label = L.CFG_ACTIVE,
        options = GetProfileOptions, default = "Global", width = DROPDOWN_WIDTH,
    }
    controls[#controls + 1] = {
        type = "profileselect", key = "CreateProfile", label = L.CFG_MANAGE,
        options = GetProfileOptions, default = "Global",
        onReset = function(selected)
            if selected == "Global" then profilesSubView = "resetglobal"; ReopenProfiles()
            else Orbit:Print(L.MSG_ONLY_GLOBAL_RESET) end
        end,
        onCopy = function(selected)
            cloneSource = selected
            cloneName = ""
            profilesSubView = "clone"
            ReopenProfiles()
        end,
        onDelete = function(selected)
            if selected == "Global" then Orbit:Print(L.MSG_CANNOT_DELETE_GLOBAL); return end
            if selected == Orbit.Profile:GetActiveProfileName() then Orbit:Print(L.MSG_CANNOT_DELETE_ACTIVE); return end
            deleteTarget = selected
            profilesSubView = "delete"
            ReopenProfiles()
        end,
    }
    controls[#controls + 1] = { type = "spacer", height = SPACER_LARGE }

    -- Spec Profiles (header with checkbox toggle)
    controls[#controls + 1] = {
        type = "checkheader", key = "UseSpecProfiles", text = L.CFG_SPEC_PROFILES, default = false,
        tooltip = L.CFG_SPEC_PROFILES_TT,
    }
    if Orbit.Profile:IsSpecProfilesEnabled() then
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
            { text = L.CMN_EXPORT, callback = function()
                local active = Orbit.Profile:GetActiveProfileName()
                exportSelectedProfile = active
                exportString = Orbit.Profile:ExportSingleProfile(active) or ""
                profilesSubView = "export"
                ReopenProfiles()
            end },
            { text = L.CMN_IMPORT, callback = function() profilesSubView = "import"; ReopenProfiles() end },
        },
    }
end

-- [ REGISTRATION ]----------------------------------------------------------------------------------

Panel.Tabs["Profiles"] = { plugin = ProfilesPlugin, schema = GetProfilesSchema }
