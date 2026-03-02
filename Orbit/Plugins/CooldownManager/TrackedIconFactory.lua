---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local TRACKED_PLACEHOLDER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PLACEHOLDER_ALPHA = 0.5

-- [ MODULE ]----------------------------------------------------------------------------------------
Orbit.TrackedIconFactory = {}
local Factory = Orbit.TrackedIconFactory

-- [ PLACEHOLDER CREATION ]--------------------------------------------------------------------------
function Factory:CreateTrackedIcons(plugin, anchor, systemIndex)
    anchor.activeIcons = {}
    anchor.recyclePool = {}
    anchor.edgeButtons = {}
    anchor.gridItems = {}

    local iconWidth, iconHeight = CooldownUtils:CalculateIconDimensions(plugin, systemIndex)

    for i = 1, 2 do
        local placeholder = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
        placeholder:SetSize(iconWidth, iconHeight)
        placeholder.Texture = placeholder:CreateTexture(nil, "ARTWORK")
        placeholder.Texture:SetAllPoints()
        placeholder.Texture:SetTexture(TRACKED_PLACEHOLDER_ICON)
        placeholder.Texture:SetDesaturated(true)
        placeholder.Texture:SetAlpha(PLACEHOLDER_ALPHA)
        self:ApplyTrackedIconSkin(plugin, placeholder, systemIndex)
        placeholder:Hide()
        anchor.placeholders[i] = placeholder
    end
end

-- [ ICON POOLING ]----------------------------------------------------------------------------------
function Factory:AcquireTrackedIcon(plugin, anchor, systemIndex)
    if #anchor.recyclePool > 0 then
        return table.remove(anchor.recyclePool)
    end
    return self:CreateTrackedIcon(plugin, anchor, systemIndex, 0, 0)
end

function Factory:ReleaseTrackedIcons(anchor)
    for _, icon in pairs(anchor.activeIcons or {}) do
        icon:Hide()
        icon:ClearAllPoints()
        table.insert(anchor.recyclePool, icon)
    end
    anchor.activeIcons = {}
end

-- [ ICON CREATION ]----------------------------------------------------------------------------------
function Factory:CreateTrackedIcon(plugin, anchor, systemIndex, x, y)
    local factory = self
    local icon = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
    OrbitEngine.Pixel:Enforce(icon)
    icon:SetSize(40, 40)
    icon.systemIndex = systemIndex
    icon.gridX = x
    icon.gridY = y
    icon.trackedType = nil
    icon.trackedId = nil

    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints()

    icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.Cooldown:SetAllPoints()
    icon.Cooldown:SetDrawSwipe(true)
    icon.Cooldown:SetDrawBling(false)

    icon.ActiveCooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.ActiveCooldown:SetAllPoints()
    icon.ActiveCooldown:SetDrawSwipe(true)
    icon.ActiveCooldown:SetDrawBling(false)

    local textOverlay = CreateFrame("Frame", nil, icon)
    textOverlay:SetAllPoints()
    textOverlay:SetFrameLevel(icon:GetFrameLevel() + 20)
    icon.TextOverlay = textOverlay

    icon.CountText = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    icon.CountText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    icon.CountText:SetFont(STANDARD_TEXT_FONT, 12, Orbit.Skin:GetFontOutline())
    icon.CountText:Hide()

    icon.DropHighlight = icon:CreateTexture(nil, "BORDER")
    icon.DropHighlight:SetAllPoints()
    icon.DropHighlight:SetColorTexture(0, 0, 0, 0)
    icon.DropHighlight:Hide()

    self:ApplyTrackedIconSkin(plugin, icon, systemIndex)

    icon:EnableMouse(false)
    icon.orbitClickThrough = true
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnReceiveDrag", function(self)
        plugin:OnTrackedIconReceiveDrag(self)
    end)
    icon:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() then
            plugin:ClearTrackedIcon(self)
        elseif GetCursorInfo() then
            plugin:OnTrackedIconReceiveDrag(self)
        end
    end)
    icon:Hide()
    return icon
end

-- [ ICON SKINNING ]---------------------------------------------------------------------------------
function Factory:ApplyTrackedIconSkin(plugin, icon, systemIndex, inheritOverrides)
    local skinSettings = CooldownUtils:BuildSkinSettings(plugin, systemIndex, { zoom = 8, inheritOverrides = inheritOverrides })
    if Orbit.Skin and Orbit.Skin.Icons then
        Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
    end
    self:ApplyTrackedTextSettings(plugin, icon, systemIndex)
end

-- [ TEXT STYLING ]-----------------------------------------------------------------------------------
function Factory:ApplyTrackedTextSettings(plugin, icon, systemIndex)
    CooldownUtils:ApplySimpleTextStyle(plugin, systemIndex, icon.CountText, "Stacks", "BOTTOMRIGHT", -2, 2)

    local fontPath = plugin:GetGlobalFont()
    local baseSize = plugin:GetBaseFontSize()
    local positions = plugin:GetSetting(systemIndex, "ComponentPositions") or {}
    local OverrideUtils = OrbitEngine.OverrideUtils
    local ApplyTextPosition = OrbitEngine.PositionUtils and OrbitEngine.PositionUtils.ApplyTextPosition

    local function StyleCooldownText(cd, posKey)
        if not cd then return end
        local fs = cd.Text
        if not fs then
            for _, region in ipairs({ cd:GetRegions() }) do
                if region:GetObjectType() == "FontString" then
                    fs = region
                    break
                end
            end
        end
        if not fs then return end
        local pos = positions[posKey] or positions["Timer"] or {}
        local overrides = pos.overrides or {}
        if OverrideUtils then
            OverrideUtils.ApplyOverrides(fs, overrides, { fontSize = math.max(6, baseSize + 2), fontPath = fontPath })
        end
        fs:SetDrawLayer("OVERLAY", 7)
        if ApplyTextPosition then
            ApplyTextPosition(fs, icon, pos)
        end
    end

    StyleCooldownText(icon.Cooldown, "Timer")
    StyleCooldownText(icon.ActiveCooldown, "Active")

    local showKeybinds = not plugin:IsComponentDisabled("Keybind", systemIndex)
    if showKeybinds then
        local keybind = icon.OrbitKeybind
        if not keybind then
            local overlay = icon.TextOverlay
            if overlay then
                keybind = overlay:CreateFontString(nil, "OVERLAY", nil, 7)
                keybind:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)
                keybind:Hide()
                icon.OrbitKeybind = keybind
            end
        end
        if keybind then
            local keybindPos = positions["Keybind"] or {}
            local keybindOverrides = keybindPos.overrides or {}
            local defaultSize = math.max(6, baseSize - 2)
            if OverrideUtils then
                OverrideUtils.ApplyOverrides(keybind, keybindOverrides, { fontSize = defaultSize, fontPath = fontPath })
            end
            if ApplyTextPosition then
                ApplyTextPosition(keybind, icon, keybindPos)
            end

            local keyText
            if icon.trackedType == "spell" and icon.trackedId then
                keyText = plugin.GetSpellKeybind and plugin:GetSpellKeybind(icon.trackedId)
            elseif icon.trackedType == "item" and icon.trackedId then
                keyText = plugin.GetItemKeybind and plugin:GetItemKeybind(icon.trackedId)
            end
            if keyText then
                keybind:SetText(keyText)
                keybind:Show()
            else
                keybind:Hide()
            end
        end
    elseif icon.OrbitKeybind then
        icon.OrbitKeybind:Hide()
    end
end
