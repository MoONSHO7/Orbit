local _, Orbit = ...
local Layout = Orbit.Engine.Layout

-- [ DUAL RANGE SLIDER WIDGET ]-----------------------------------------------------------------------
-- Two MinimalSliderWithSteppers diamond thumbs that can't cross (minGap apart); opts {onChange,minGap,dual,lowTip,highTip}, dual=false hides the high thumb.
local STEP = 1
local FILL_H = 4
local THUMB_HIT_PAD = 8

function Layout:CreateRangeSlider(parent, width, opts)
    opts = opts or {}
    local rs = CreateFrame("Frame", nil, parent)
    rs:SetSize(width, 20)
    rs.low, rs.high = 0, 100

    local bi = C_Texture.GetAtlasInfo("Minimal_SliderBar_Button")
    local thumbW, thumbH = (bi and bi.width or 14), (bi and bi.height or 14)

    local capL = rs:CreateTexture(nil, "BACKGROUND")
    capL:SetAtlas("Minimal_SliderBar_Left", true)
    capL:SetPoint("LEFT", thumbW / 2, 0)
    local capR = rs:CreateTexture(nil, "BACKGROUND")
    capR:SetAtlas("Minimal_SliderBar_Right", true)
    capR:SetPoint("RIGHT", -thumbW / 2, 0)
    local mid = rs:CreateTexture(nil, "BACKGROUND")
    mid:SetAtlas("_Minimal_SliderBar_Middle", true)
    mid:SetPoint("TOPLEFT", capL, "TOPRIGHT")
    mid:SetPoint("TOPRIGHT", capR, "TOPLEFT")

    local trackRef = CreateFrame("Frame", nil, rs)
    trackRef:SetPoint("LEFT", thumbW / 2, 0)
    trackRef:SetPoint("RIGHT", -thumbW / 2, 0)
    trackRef:SetHeight(1)

    local fill = rs:CreateTexture(nil, "ARTWORK")
    fill:SetColorTexture(1, 0.82, 0, 0.5)
    fill:SetHeight(FILL_H)

    local function Snap(v) return math.floor(v / STEP + 0.5) * STEP end

    local function Thumb()
        local t = CreateFrame("Button", nil, rs)
        t:SetSize(thumbW + THUMB_HIT_PAD, thumbH + THUMB_HIT_PAD)
        local tex = t:CreateTexture(nil, "OVERLAY")
        tex:SetSize(thumbW, thumbH)
        tex:SetPoint("CENTER")
        tex:SetAtlas("Minimal_SliderBar_Button")
        t.tex = tex
        local hl = t:CreateTexture(nil, "HIGHLIGHT")
        hl:SetSize(thumbW, thumbH)
        hl:SetPoint("CENTER")
        hl:SetAtlas("Minimal_SliderBar_Button")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.4)
        t:RegisterForDrag("LeftButton")
        -- Press/grab feedback — the diamond pops while held.
        t:SetScript("OnMouseDown", function(self) self.tex:SetScale(1.2) end)
        t:SetScript("OnMouseUp", function(self) self.tex:SetScale(1) end)
        t:SetScript("OnEnter", function(self)
            if not self._tip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self._tip, 1, 1, 1, nil, true)
            GameTooltip:Show()
        end)
        t:SetScript("OnLeave", GameTooltip_Hide)
        return t
    end
    local lowThumb, highThumb = Thumb(), Thumb()

    local function ValueX(v) return (v / 100) * trackRef:GetWidth() end
    local function Reposition()
        if trackRef:GetWidth() <= 0 then return end
        lowThumb:ClearAllPoints()
        lowThumb:SetPoint("CENTER", trackRef, "LEFT", ValueX(rs.low), 0)
        fill:ClearAllPoints()
        if rs._dual then
            highThumb:Show()
            highThumb:ClearAllPoints()
            highThumb:SetPoint("CENTER", trackRef, "LEFT", ValueX(rs.high), 0)
            fill:SetPoint("LEFT", trackRef, "LEFT", ValueX(rs.low), 0)
            fill:SetPoint("RIGHT", trackRef, "LEFT", ValueX(rs.high), 0)
        else
            highThumb:Hide()
            fill:SetPoint("LEFT", trackRef, "LEFT", 0, 0)
            fill:SetPoint("RIGHT", trackRef, "LEFT", ValueX(rs.low), 0)
        end
    end

    -- GetCursorPosition is screen pixels; divide by effective scale to land in trackRef's coordinate space.
    local function CursorVal()
        local left, w = trackRef:GetLeft(), trackRef:GetWidth()
        if not left or w <= 0 then return nil end
        local frac = (GetCursorPosition() / rs:GetEffectiveScale() - left) / w
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        return Snap(frac * 100)
    end

    local active
    local function DragUpdate()
        local v = active and CursorVal()
        if not v then return end
        local oldLow, oldHigh = rs.low, rs.high
        if active == lowThumb then
            local ceil = rs._dual and (rs.high - rs._minGap) or 100
            rs.low = math.max(0, math.min(v, ceil))
        else
            rs.high = math.min(100, math.max(v, rs.low + rs._minGap))
        end
        -- Values snap to whole percents, so most frames land on the same value — skip the repaint/callback unless it actually moved.
        if rs.low == oldLow and rs.high == oldHigh then return end
        Reposition()
        if rs._onChange then rs._onChange(rs.low, rs.high) end
    end
    local function Start(t) active = t; rs:SetScript("OnUpdate", DragUpdate) end
    local function Stop()
        if active then active.tex:SetScale(1) end
        active = nil
        rs:SetScript("OnUpdate", nil)
    end
    lowThumb:SetScript("OnDragStart", function() Start(lowThumb) end)
    highThumb:SetScript("OnDragStart", function() Start(highThumb) end)
    lowThumb:SetScript("OnDragStop", Stop)
    highThumb:SetScript("OnDragStop", Stop)

    -- Repositions only; never pushes a clamped value back into onChange (avoids drifting saved data on load).
    function rs:SetRange(low, high)
        self.low = math.max(0, math.min(100, Snap(low or 0)))
        self.high = math.max(0, math.min(100, Snap(high or 100)))
        if self._dual and self.high < self.low + self._minGap then
            self.high = math.min(100, self.low + self._minGap)
        end
        Reposition()
    end

    function rs:Configure(o)
        o = o or {}
        self._minGap = o.minGap or 0
        self._onChange = o.onChange
        self._dual = o.dual ~= false
        lowThumb._tip = o.lowTip
        highThumb._tip = o.highTip
    end

    rs:Configure(opts)
    rs:SetScript("OnShow", Reposition)
    rs:SetScript("OnSizeChanged", Reposition)
    return rs
end
