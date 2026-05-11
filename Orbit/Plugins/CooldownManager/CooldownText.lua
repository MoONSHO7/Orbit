---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then
    return
end

local VIEWER_MAP = CDM.viewerMap
local LSM = LibStub("LibSharedMedia-3.0", true)

local FALLBACK_FONT = STANDARD_TEXT_FONT
local FALLBACK_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"

local function FindFontStringRegion(...)
    for i = 1, select('#', ...) do
        local region = select(i, ...)
        if region:GetObjectType() == "FontString" then return region end
    end
end

local function FindFontStringInChildren(...)
    for i = 1, select('#', ...) do
        local child = select(i, ...)
        local region = FindFontStringRegion(child:GetRegions())
        if region then return region end
    end
end

-- [ FONT HELPERS ] ----------------------------------------------------------------------------------
function CDM:GetBaseFontSize()
    return 12
end

function CDM:GetGlobalFont()
    local fontName = Orbit.db.GlobalSettings.Font
    return LSM and LSM:Fetch("font", fontName) or FALLBACK_FONT
end

-- [ TEXT OVERLAY ] ----------------------------------------------------------------------------------
function CDM:GetTextOverlay(icon)
    if icon.OrbitTextOverlay then
        return icon.OrbitTextOverlay
    end
    local overlay = CreateFrame("Frame", nil, icon)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(icon:GetFrameLevel() + Constants.Levels.IconOverlay)
    icon.OrbitTextOverlay = overlay
    return overlay
end

function CDM:CreateKeybindText(icon)
    local overlay = self:GetTextOverlay(icon)
    local keybind = overlay:CreateFontString(nil, "OVERLAY", nil, 7)
    keybind:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)
    keybind:Hide()
    icon.OrbitKeybind = keybind
    return keybind
end

-- [ APPLY TEXT SETTINGS ] ---------------------------------------------------------------------------
function CDM:ApplyTextSettings(icon, systemIndex)
    local fontPath = self:GetGlobalFont()
    local baseSize = self:GetBaseFontSize()
    local positions = self:GetComponentPositions(systemIndex)
    local OverrideUtils = OrbitEngine.OverrideUtils

    local function GetComponentOverrides(key)
        local pos = positions[key] or {}
        return pos.overrides or {}, pos
    end

    local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition

    -- Timer
    local cooldown = icon.Cooldown or (icon.GetCooldownFrame and icon:GetCooldownFrame())
    local activeCooldown = icon.ActiveCooldown
    if cooldown or activeCooldown then
        local disabled = self:IsComponentDisabled("Timer", systemIndex)
        local timerOverrides, timerPos
        if not disabled then
            timerOverrides, timerPos = GetComponentOverrides("Timer")
        end
        local defaultSize = math.max(6, baseSize + 2)
        local overlay = self:GetTextOverlay(icon)

        for _, cd in ipairs({ cooldown, activeCooldown }) do
            if cd then
                if disabled then
                    if cd.SetHideCountdownNumbers then
                        cd:SetHideCountdownNumbers(true)
                    end
                else
                    if cd.SetHideCountdownNumbers then
                        cd:SetHideCountdownNumbers(false)
                    end
                    -- C++ may recreate the FontString after Clear/Set cycles; rediscover.
                    cd.Text = nil
                    local timerText = FindFontStringRegion(cd:GetRegions()) or FindFontStringInChildren(cd:GetChildren())
                    if timerText then
                        cd.Text = timerText
                        if not timerText:GetFont() then
                            timerText:SetFont(fontPath, defaultSize, "OUTLINE")
                        end
                        OverrideUtils.ApplyOverrides(timerText, timerOverrides, { fontSize = defaultSize, fontPath = fontPath })
                        timerText:SetDrawLayer("OVERLAY", 7)
                        if ApplyTextPosition then
                            ApplyTextPosition(timerText, icon, timerPos, "CENTER", 0, 0)
                        end
                    end
                end
            end
        end
    end

    -- Charges
    if icon.ChargeCount and icon.ChargeCount.Current then
        if self:IsComponentDisabled("Charges", systemIndex) then
            icon.ChargeCount.orbitForceHide = true
            icon.ChargeCount:SetAlpha(0)
            icon.ChargeCount.Current:SetAlpha(0)
            if not icon.ChargeCount.Current.orbitAlphaHooked then
                icon.ChargeCount.Current.orbitAlphaHooked = true
                hooksecurefunc(icon.ChargeCount.Current, "SetAlpha", function(t, a)
                    if icon.ChargeCount.orbitForceHide and a > 0 then
                        t:SetAlpha(0)
                    end
                end)
            end
            if not icon.ChargeCount.Current.orbitTextHooked then
                icon.ChargeCount.Current.orbitTextHooked = true
                hooksecurefunc(icon.ChargeCount.Current, "SetText", function(t)
                    if icon.ChargeCount.orbitForceHide then
                        t:SetAlpha(0)
                    end
                end)
            end
        else
            icon.ChargeCount.orbitForceHide = nil
            icon.ChargeCount:SetAlpha(1)
            icon.ChargeCount.Current:SetAlpha(1)
            local chargesOverrides, chargesPos = GetComponentOverrides("Charges")
            local defaultSize = math.max(6, baseSize)
            OverrideUtils.ApplyOverrides(icon.ChargeCount.Current, chargesOverrides, { fontSize = defaultSize, fontPath = fontPath })
            icon.ChargeCount.Current:SetDrawLayer("OVERLAY", 7)
            if icon.ChargeCount.SetFrameLevel then
                icon.ChargeCount:SetFrameLevel(icon:GetFrameLevel() + Constants.Levels.IconOverlay)
            end
            if ApplyTextPosition then
                ApplyTextPosition(icon.ChargeCount.Current, icon, chargesPos)
            end
        end
    end

    -- Stacks
    if icon.Applications then
        if self:IsComponentDisabled("Stacks", systemIndex) then
            icon.Applications.orbitForceHide = true
            icon.Applications:Hide()
            if not icon.Applications.orbitShowHooked then
                icon.Applications.orbitShowHooked = true
                hooksecurefunc(icon.Applications, "Show", function(s)
                    if s.orbitForceHide then
                        s:Hide()
                    end
                end)
            end
        else
            icon.Applications.orbitForceHide = nil
            local stacksOverrides, stacksPos = GetComponentOverrides("Stacks")
            local stackText = icon.Applications.Applications or icon.Applications
            if stackText and stackText.SetFont then
                local defaultSize = math.max(6, baseSize)
                OverrideUtils.ApplyOverrides(stackText, stacksOverrides, { fontSize = defaultSize, fontPath = fontPath })
                if stackText.SetDrawLayer then
                    stackText:SetDrawLayer("OVERLAY", 7)
                end
                if icon.Applications.SetFrameLevel then
                    icon.Applications:SetFrameLevel(icon:GetFrameLevel() + Constants.Levels.IconOverlay)
                end
                if ApplyTextPosition then
                    ApplyTextPosition(stackText, icon, stacksPos)
                end
            end
        end
    end

    -- Keybind
    local showKeybinds = not self:IsComponentDisabled("Keybind", systemIndex)
    local keybindOverrides, keybindPos = GetComponentOverrides("Keybind")
    if showKeybinds then
        local keybind = icon.OrbitKeybind or self:CreateKeybindText(icon)
        local defaultSize = math.max(6, baseSize - 2)
        OverrideUtils.ApplyOverrides(keybind, keybindOverrides, { fontSize = defaultSize, fontPath = fontPath })
        if ApplyTextPosition then
            ApplyTextPosition(keybind, icon, keybindPos)
        end
        local spellID = icon.GetSpellID and icon:GetSpellID()
        local keyText = self.GetSpellKeybind and self:GetSpellKeybind(spellID)
        if keyText then
            keybind:SetText(keyText)
            if keyText:find("|A:Gamepad_") then
                keybind:SetHeight(math.max(keybind:GetHeight() or 0, 16))
            end
            keybind:Show()
        else
            keybind:Hide()
        end
    elseif icon.OrbitKeybind then
        icon.OrbitKeybind:Hide()
    end
end

-- [ CANVAS PREVIEW ] --------------------------------------------------------------------------------
function CDM:SetupCanvasPreview(anchor, systemIndex)
    local plugin = self
    anchor.CreateCanvasPreview = function(self, options)
        local entry = VIEWER_MAP[systemIndex]
        if not entry or not entry.viewer then return nil end

        local aspectRatio = plugin:GetSetting(systemIndex, "aspectRatio") or "1:1"
        local iconSize = plugin:GetSetting(systemIndex, "IconSize") or Constants.Cooldown.DefaultIconSize
        local w, h = iconSize, iconSize
        if aspectRatio == "16:9" then h = iconSize * (9 / 16)
        elseif aspectRatio == "4:3" then h = iconSize * (3 / 4)
        elseif aspectRatio == "21:9" then h = iconSize * (9 / 21) end

        local iconTexture = FALLBACK_TEXTURE
        for _, child in ipairs({ entry.viewer:GetChildren() }) do
            if child:IsShown() and child.Icon and child.Icon.GetTexture then
                local tex = child.Icon:GetTexture()
                if tex then iconTexture = tex; break end
            end
        end

        local preview = OrbitEngine.IconCanvasPreview:Create(self, options.parent or UIParent, w, h, iconTexture)
        preview.systemIndex = systemIndex
        local savedPositions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
        local fontPath = plugin:GetGlobalFont()

        local kbPreview = (C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()) and "|A:Gamepad_Gen_1_32:14:14|a" or "Q"

        OrbitEngine.IconCanvasPreview:AttachTextComponents(preview, {
            { key = "Timer", preview = string.format("%.1f", 3 + math.random() * 7), anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0 },
            { key = "Charges", preview = "2", anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
            { key = "Stacks", preview = "3", anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
            { key = "Keybind", preview = kbPreview, anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2 },
        }, savedPositions, fontPath)

        return preview
    end
end
