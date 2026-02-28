-- [ ACTION BARS - TEXT SETTINGS ]-------------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

local BUTTON_SIZE = 36

Orbit.ActionBarsText = {}
local ABText = Orbit.ActionBarsText

function ABText:Apply(plugin, button, systemIndex)
    if not button then return end
    local KeybindSystem = OrbitEngine.KeybindSystem
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local globalFontName = Orbit.db.GlobalSettings.Font
    local baseFontPath = (Orbit.Fonts and Orbit.Fonts[globalFontName]) or Orbit.Constants.Settings.Font.FallbackPath
    if LSM then baseFontPath = LSM:Fetch("font", globalFontName) or baseFontPath end
    local useGlobal = plugin:GetSetting(systemIndex, "UseGlobalTextStyle")
    local positions
    if useGlobal ~= false then positions = plugin:GetSetting(1, "GlobalComponentPositions") or {}
    else positions = plugin:GetSetting(systemIndex, "ComponentPositions") or {} end
    local w = button:GetWidth()
    if w < 20 then w = BUTTON_SIZE end
    local OverrideUtils = OrbitEngine.OverrideUtils

    local function GetComponentOverrides(key)
        local pos = positions[key] or {}
        return pos.overrides or {}, pos
    end

    local function ApplyComponentPosition(textElement, key, defaultAnchorX, defaultAnchorY, defaultOffsetX, defaultOffsetY)
        if not textElement then return end
        if plugin:IsComponentDisabled(key, systemIndex) then textElement:Hide(); return end
        textElement:Show()
        local pos = positions[key] or {}
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
        local textPoint
        if justifyH == "LEFT" then textPoint = "LEFT"
        elseif justifyH == "RIGHT" then textPoint = "RIGHT"
        else textPoint = "CENTER" end
        local finalOffsetX = anchorX == "LEFT" and offsetX or -offsetX
        local finalOffsetY = anchorY == "BOTTOM" and offsetY or -offsetY
        textElement:ClearAllPoints()
        textElement:SetPoint(textPoint, button, anchorPoint, finalOffsetX, finalOffsetY)
        if textElement.SetJustifyH then textElement:SetJustifyH(justifyH) end
    end

    if button.HotKey then
        local defaultSize = math.max(8, w * 0.28)
        local overrides = GetComponentOverrides("Keybind")
        OverrideUtils.ApplyOverrides(button.HotKey, overrides, { fontSize = defaultSize, fontPath = baseFontPath })
        button.HotKey:SetDrawLayer("OVERLAY", 7)
        if KeybindSystem then
            local shortKey = KeybindSystem:GetForButton(button)
            if shortKey and shortKey ~= "" then button.HotKey:SetText(shortKey) else button.HotKey:SetText("") end
        else button.HotKey:SetText("") end
        ApplyComponentPosition(button.HotKey, "Keybind", "RIGHT", "TOP", 2, 2)
    end

    if button.Name then
        local defaultSize = math.max(7, w * 0.22)
        local overrides = GetComponentOverrides("MacroText")
        OverrideUtils.ApplyOverrides(button.Name, overrides, { fontSize = defaultSize, fontPath = baseFontPath })
        button.Name:SetDrawLayer("OVERLAY", 7)
        if not button.orbitTextOverlay then
            button.orbitTextOverlay = CreateFrame("Frame", nil, button)
            button.orbitTextOverlay:SetAllPoints(button)
            button.orbitTextOverlay:SetFrameLevel(button:GetFrameLevel() + 10)
        end
        button.Name:SetParent(button.orbitTextOverlay)
        ApplyComponentPosition(button.Name, "MacroText", "CENTER", "BOTTOM", 0, 2)
    end

    local cooldown = button.cooldown or button.Cooldown
    if cooldown then
        if plugin:IsComponentDisabled("Timer", systemIndex) then
            if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
        else
            if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(false) end
            local timerText = cooldown.Text
            if not timerText then
                local regions = { cooldown:GetRegions() }
                for _, region in ipairs(regions) do if region:GetObjectType() == "FontString" then timerText = region; break end end
            end
            if timerText and timerText.SetFont then
                local defaultSize = math.max(10, w * 0.35)
                local overrides, pos = GetComponentOverrides("Timer")
                OverrideUtils.ApplyOverrides(timerText, overrides, { fontSize = defaultSize, fontPath = baseFontPath })
                timerText:SetDrawLayer("OVERLAY", 7)
                if pos.anchorX then ApplyComponentPosition(timerText, "Timer", "CENTER", "CENTER", 0, 0) end
            end
        end
    end

    if button.Count then
        local defaultSize = math.max(8, w * 0.28)
        local overrides = GetComponentOverrides("Stacks")
        OverrideUtils.ApplyOverrides(button.Count, overrides, { fontSize = defaultSize, fontPath = baseFontPath })
        button.Count:SetDrawLayer("OVERLAY", 7)
        ApplyComponentPosition(button.Count, "Stacks", "LEFT", "BOTTOM", 2, 2)
    end
end
