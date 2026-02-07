---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local VIEWER_MAP = CDM.viewerMap
local LSM = LibStub("LibSharedMedia-3.0", true)

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local TEXT_SCALE_SIZES = { Small = 10, Medium = 12, Large = 14, ExtraLarge = 16 }
local FALLBACK_FONT = STANDARD_TEXT_FONT
local FALLBACK_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"

-- [ FONT HELPERS ]----------------------------------------------------------------------------------
function CDM:GetBaseFontSize()
    local scale = Orbit.db.GlobalSettings.TextScale
    return TEXT_SCALE_SIZES[scale] or 12
end

function CDM:GetGlobalFont()
    local fontName = Orbit.db.GlobalSettings.Font
    return LSM and LSM:Fetch("font", fontName) or FALLBACK_FONT
end

-- [ TEXT OVERLAY ]---------------------------------------------------------------------------------
function CDM:GetTextOverlay(icon)
    if icon.OrbitTextOverlay then return icon.OrbitTextOverlay end
    local overlay = CreateFrame("Frame", nil, icon)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(icon:GetFrameLevel() + 20)
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

-- [ APPLY TEXT SETTINGS ]---------------------------------------------------------------------------
function CDM:ApplyTextSettings(icon, systemIndex)
    local fontPath = self:GetGlobalFont()
    local baseSize = self:GetBaseFontSize()
    local positions = self:GetSetting(systemIndex, "ComponentPositions") or {}

    local function GetComponentStyle(key, defaultOffset)
        local pos = positions[key] or {}
        local overrides = pos.overrides or {}
        local font = (overrides.Font and LSM) and LSM:Fetch("font", overrides.Font) or fontPath
        local size = overrides.FontSize or math.max(6, baseSize + (defaultOffset or 0))
        local flags = overrides.ShowShadow and "" or Orbit.Skin:GetFontOutline()
        return font, size, flags, pos, overrides
    end

    local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition

    -- Timer
    local cooldown = icon.Cooldown or (icon.GetCooldownFrame and icon:GetCooldownFrame())
    if cooldown then
        if self:IsComponentDisabled("Timer", systemIndex) then
            if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
        else
            local timerFont, timerSize, timerFlags, timerPos, timerOverrides = GetComponentStyle("Timer", 2)
            local timerText = cooldown.Text
            if not timerText then
                for _, region in ipairs({ cooldown:GetRegions() }) do
                    if region:GetObjectType() == "FontString" then timerText = region; break end
                end
            end
            if timerText then
                timerText:SetFont(timerFont, timerSize, timerFlags)
                timerText:SetDrawLayer("OVERLAY", 7)
                CooldownUtils:ApplyTextColor(timerText, timerOverrides)
                if ApplyTextPosition then ApplyTextPosition(timerText, icon, timerPos) end
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
                hooksecurefunc(icon.ChargeCount.Current, "SetAlpha", function(t, a) if icon.ChargeCount.orbitForceHide and a > 0 then t:SetAlpha(0) end end)
            end
            if not icon.ChargeCount.Current.orbitTextHooked then
                icon.ChargeCount.Current.orbitTextHooked = true
                hooksecurefunc(icon.ChargeCount.Current, "SetText", function(t) if icon.ChargeCount.orbitForceHide then t:SetAlpha(0) end end)
            end
        else
            icon.ChargeCount.orbitForceHide = nil
            icon.ChargeCount:SetAlpha(1)
            icon.ChargeCount.Current:SetAlpha(1)
            local chargesFont, chargesSize, chargesFlags, chargesPos, chargesOverrides = GetComponentStyle("Charges", 0)
            icon.ChargeCount.Current:SetFont(chargesFont, chargesSize, chargesFlags)
            icon.ChargeCount.Current:SetDrawLayer("OVERLAY", 7)
            CooldownUtils:ApplyTextColor(icon.ChargeCount.Current, chargesOverrides)
            if icon.ChargeCount.SetFrameLevel then icon.ChargeCount:SetFrameLevel(icon:GetFrameLevel() + 20) end
            if ApplyTextPosition then ApplyTextPosition(icon.ChargeCount.Current, icon, chargesPos) end
        end
    end

    -- Stacks
    if icon.Applications then
        if self:IsComponentDisabled("Stacks", systemIndex) then
            icon.Applications.orbitForceHide = true
            icon.Applications:Hide()
            if not icon.Applications.orbitShowHooked then
                icon.Applications.orbitShowHooked = true
                hooksecurefunc(icon.Applications, "Show", function(s) if s.orbitForceHide then s:Hide() end end)
            end
        else
            icon.Applications.orbitForceHide = nil
            local stacksFont, stacksSize, stacksFlags, stacksPos, stacksOverrides = GetComponentStyle("Stacks", 0)
            local stackText = icon.Applications.Applications or icon.Applications
            if stackText and stackText.SetFont then
                stackText:SetFont(stacksFont, stacksSize, stacksFlags)
                if stackText.SetDrawLayer then stackText:SetDrawLayer("OVERLAY", 7) end
                CooldownUtils:ApplyTextColor(stackText, stacksOverrides)
                if icon.Applications.SetFrameLevel then icon.Applications:SetFrameLevel(icon:GetFrameLevel() + 20) end
                if ApplyTextPosition then ApplyTextPosition(stackText, icon, stacksPos) end
            end
        end
    end

    -- Keybind
    local showKeybinds = not self:IsComponentDisabled("Keybind", systemIndex)
    local keybindFont, keybindSize, keybindFlags, keybindPos, keybindOverrides = GetComponentStyle("Keybind", -2)
    if showKeybinds then
        local keybind = icon.OrbitKeybind or self:CreateKeybindText(icon)
        keybind:SetFont(keybindFont, keybindSize, keybindFlags)
        CooldownUtils:ApplyTextColor(keybind, keybindOverrides)
        if ApplyTextPosition then ApplyTextPosition(keybind, icon, keybindPos) end
        local spellID = icon.GetSpellID and icon:GetSpellID()
        local keyText = self.GetSpellKeybind and self:GetSpellKeybind(spellID)
        if keyText then keybind:SetText(keyText); keybind:Show() else keybind:Hide() end
    elseif icon.OrbitKeybind then
        icon.OrbitKeybind:Hide()
    end
end

-- [ CANVAS PREVIEW ]--------------------------------------------------------------------------------
function CDM:SetupCanvasPreview(anchor, systemIndex)
    local plugin = self
    anchor.CreateCanvasPreview = function(self, options)
        local entry = VIEWER_MAP[systemIndex]
        if not entry or not entry.viewer then return nil end

        local w, h = nil, nil
        for _, child in ipairs({ entry.viewer:GetChildren() }) do
            if child:IsShown() and child.Icon then w, h = child:GetSize(); break end
        end

        if not w or not h then
            local aspectRatio = plugin:GetSetting(systemIndex, "aspectRatio") or "1:1"
            local iconSize = plugin:GetSetting(systemIndex, "IconSize") or Constants.Cooldown.DefaultIconSize
            local baseSize = Constants.Skin.DefaultIconSize or 40
            local scaledSize = baseSize * (iconSize / 100)
            w, h = scaledSize, scaledSize
            if aspectRatio == "16:9" then h = scaledSize * (9 / 16)
            elseif aspectRatio == "4:3" then h = scaledSize * (3 / 4)
            elseif aspectRatio == "21:9" then h = scaledSize * (9 / 21) end
        end

        local parent = options.parent or UIParent
        local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        preview:SetSize(w, h)
        preview.sourceFrame = self

        local borderSize = Orbit.db.GlobalSettings.BorderSize
        preview.sourceWidth = w - (borderSize * 2)
        preview.sourceHeight = h - (borderSize * 2)
        preview.previewScale = 1
        preview.components = {}

        local iconTexture = FALLBACK_TEXTURE
        for _, child in ipairs({ entry.viewer:GetChildren() }) do
            if child:IsShown() and child.Icon then
                local tex = child.Icon:GetTexture()
                if tex then iconTexture = tex; break end
            end
        end

        local icon = preview:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(iconTexture)

        local backdrop = { bgFile = "Interface\\BUTTONS\\WHITE8x8", insets = { left = 0, right = 0, top = 0, bottom = 0 } }
        if borderSize > 0 then backdrop.edgeFile = "Interface\\BUTTONS\\WHITE8x8"; backdrop.edgeSize = borderSize end
        preview:SetBackdrop(backdrop)
        preview:SetBackdropColor(0, 0, 0, 0)
        if borderSize > 0 then preview:SetBackdropBorderColor(0, 0, 0, 1) end

        local savedPositions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
        local fontPath = plugin:GetGlobalFont()

        local textComponents = {
            { key = "Timer", preview = string.format("%.1f", 3 + math.random() * 7), anchorX = "CENTER", anchorY = "CENTER", offsetX = 0, offsetY = 0 },
            { key = "Charges", preview = "2", anchorX = "RIGHT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
            { key = "Stacks", preview = "3", anchorX = "LEFT", anchorY = "BOTTOM", offsetX = 2, offsetY = 2 },
            { key = "Keybind", preview = "Q", anchorX = "RIGHT", anchorY = "TOP", offsetX = 2, offsetY = 2 },
        }

        local CreateDraggableComponent = OrbitEngine.CanvasMode and OrbitEngine.CanvasMode.CreateDraggableComponent
        local halfW, halfH = preview.sourceWidth / 2, preview.sourceHeight / 2

        for _, def in ipairs(textComponents) do
            local fs = preview:CreateFontString(nil, "OVERLAY", nil, 7)
            fs:SetFont(fontPath, 12, Orbit.Skin:GetFontOutline())
            fs:SetText(def.preview)
            fs:SetTextColor(1, 1, 1, 1)
            fs:SetPoint("CENTER", preview, "CENTER", 0, 0)

            local saved = savedPositions[def.key] or {}
            local defaultJustifyH = def.anchorX == "LEFT" and "LEFT" or def.anchorX == "RIGHT" and "RIGHT" or "CENTER"
            local data = {
                anchorX = saved.anchorX or def.anchorX,
                anchorY = saved.anchorY or def.anchorY,
                offsetX = saved.offsetX or def.offsetX,
                offsetY = saved.offsetY or def.offsetY,
                justifyH = saved.justifyH or defaultJustifyH,
                overrides = saved.overrides,
            }

            local startX = saved.posX or 0
            local startY = saved.posY or 0
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
            else
                fs:ClearAllPoints()
                fs:SetPoint("CENTER", preview, "CENTER", startX, startY)
            end
        end

        return preview
    end
end
