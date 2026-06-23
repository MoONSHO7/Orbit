local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local Engine = Orbit.Engine
local Constants = Orbit.Constants

-- [ GRADIENT BACKGROUND ] ---------------------------------------------------------------------------
-- Flat-colour resolution of UnitFrameBackdropColourCurve — for surfaces that can't take a gradient. Frames with `.bg` should use ApplyGradientBackground.
function Skin:GetBackgroundColor()
    local gs = Orbit.db and Orbit.db.GlobalSettings
    return (gs and Engine.ColorCurve:GetFirstColorFromCurve(gs.UnitFrameBackdropColourCurve))
        or Constants.Colors.Background
end

local function ResolvePinColor(pin)
    local c = Engine.ClassColor:ResolveClassColorPin(pin)
    if pin.type == "class" and pin.color and pin.color.a then
        return { r = c.r, g = c.g, b = c.b, a = pin.color.a }
    end
    return c
end

function Skin:ApplyGradientBackground(frame, curveData, fallbackColor)
    if not frame then return end
    local pins = curveData and curveData.pins
    local pinCount = pins and #pins or 0

    if pinCount <= 1 then
        local c = (pinCount == 1 and Engine.ColorCurve:GetFirstColorFromCurve(curveData)) or fallbackColor or Constants.Colors.Background
        if frame.bg then frame.bg:SetColorTexture(c.r or 0, c.g or 0, c.b or 0, c.a or 0.5) end
        if frame._gradientSegments then
            for _, seg in ipairs(frame._gradientSegments) do seg:Hide() end
        end
        return
    end

    if frame.bg then frame.bg:SetColorTexture(0, 0, 0, 0) end

    frame._gradientSegments = frame._gradientSegments or {}
    local sorted = {}
    for _, p in ipairs(pins) do sorted[#sorted + 1] = p end
    table.sort(sorted, function(a, b) return a.position < b.position end)
    if sorted[1].position > 0 then table.insert(sorted, 1, { position = 0, color = ResolvePinColor(sorted[1]), type = sorted[1].type }) end
    if sorted[#sorted].position < 1 then sorted[#sorted + 1] = { position = 1, color = ResolvePinColor(sorted[#sorted]), type = sorted[#sorted].type } end

    local segCount = #sorted - 1
    local gradColorL = CreateColor(1, 1, 1, 1)
    local gradColorR = CreateColor(1, 1, 1, 1)
    for i = 1, segCount do
        local seg = frame._gradientSegments[i]
        if not seg then
            seg = frame:CreateTexture(nil, "BACKGROUND", nil, Constants.Layers and Constants.Layers.BackdropDeep or -8)
            frame._gradientSegments[i] = seg
        end
        local lc = ResolvePinColor(sorted[i])
        local rc = ResolvePinColor(sorted[i + 1])

        seg:ClearAllPoints()
        local width = frame:GetWidth()
        local scale = frame:GetEffectiveScale()
        seg:SetPoint("TOPLEFT", frame, "TOPLEFT", Engine.Pixel:Snap(width * sorted[i].position, scale), 0)
        seg:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", Engine.Pixel:Snap(width * sorted[i + 1].position, scale), -frame:GetHeight())
        seg:SetTexture("Interface\\BUTTONS\\WHITE8x8")
        gradColorL:SetRGBA(lc.r, lc.g, lc.b, lc.a or 0.5)
        gradColorR:SetRGBA(rc.r, rc.g, rc.b, rc.a or 0.5)
        seg:SetGradient("HORIZONTAL", gradColorL, gradColorR)
        seg:Show()
    end

    for i = segCount + 1, #frame._gradientSegments do
        frame._gradientSegments[i]:Hide()
    end
end
