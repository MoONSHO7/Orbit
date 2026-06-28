local _, Orbit = ...
local Layout = Orbit.Engine.Layout

-- [ DUAL RANGE SLIDER WIDGET ]-----------------------------------------------------------------------
-- Two diamond thumbs (low/high) that can't cross (kept minGap apart). The drag is driven manually — OnMouseDown starts it and an OnUpdate poll on the mouse-button state stops it — because WoW's OnDragStart/OnDragStop fire unreliably mid-hold. Callbacks (set via Configure): onPreview(low,high) fires live while dragging, onCommit(low,high) fires once on release. The widget knows nothing about what it edits; the caller binds onCommit to its own data.
local STEP = 1
local FILL_H = 4
local HIT_PAD = 8
local EDGE_PAD = 6

function Layout:CreateRangeSlider(parent, width)
    local rs = CreateFrame("Frame", nil, parent)
    rs:SetSize(width, 20)
    rs.low, rs.high = 0, 100
    rs._minGap, rs._dual = 0, true

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

    -- Thumb travel is inset past the bar's end caps (EDGE_PAD) so the diamonds at 0%/100% sit inside the widget rather than off its edges. The width is set EXPLICITLY (not derived from a RIGHT anchor) so track:GetWidth() is valid even while the row is built under a momentarily-hidden accordion body — otherwise Reposition would read 0 and the high thumb would not render until the next interaction.
    local trackW = width - thumbW - 2 * EDGE_PAD
    local track = CreateFrame("Frame", nil, rs)
    track:SetPoint("LEFT", thumbW / 2 + EDGE_PAD, 0)
    track:SetSize(trackW, 1)

    local fill = rs:CreateTexture(nil, "ARTWORK")
    fill:SetColorTexture(1, 0.82, 0, 0.5)
    fill:SetHeight(FILL_H)

    local function Snap(v) return math.floor(v / STEP + 0.5) * STEP end
    local function ValueX(v) return (v / 100) * track:GetWidth() end

    local function MakeThumb()
        local t = CreateFrame("Button", nil, rs)
        t:SetSize(thumbW + HIT_PAD, thumbH + HIT_PAD)
        t.tex = t:CreateTexture(nil, "OVERLAY")
        t.tex:SetSize(thumbW, thumbH)
        t.tex:SetPoint("CENTER")
        t.tex:SetAtlas("Minimal_SliderBar_Button")
        local hl = t:CreateTexture(nil, "HIGHLIGHT")
        hl:SetSize(thumbW, thumbH)
        hl:SetPoint("CENTER")
        hl:SetAtlas("Minimal_SliderBar_Button")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.4)
        t:SetScript("OnEnter", function(self)
            if not self._tip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self._tip, 1, 1, 1, nil, true)
            GameTooltip:Show()
        end)
        t:SetScript("OnLeave", GameTooltip_Hide)
        return t
    end
    local lowThumb, highThumb = MakeThumb(), MakeThumb()

    local function Reposition()
        if track:GetWidth() <= 0 then return end
        lowThumb:ClearAllPoints()
        lowThumb:SetPoint("CENTER", track, "LEFT", ValueX(rs.low), 0)
        fill:ClearAllPoints()
        if rs._dual then
            highThumb:Show()
            highThumb:ClearAllPoints()
            highThumb:SetPoint("CENTER", track, "LEFT", ValueX(rs.high), 0)
            fill:SetPoint("LEFT", track, "LEFT", ValueX(rs.low), 0)
            fill:SetPoint("RIGHT", track, "LEFT", ValueX(rs.high), 0)
        else
            highThumb:Hide()
            fill:SetPoint("LEFT", track, "LEFT", 0, 0)
            fill:SetPoint("RIGHT", track, "LEFT", ValueX(rs.low), 0)
        end
    end

    -- GetCursorPosition is screen pixels; divide by effective scale to land in the track's coordinate space.
    local function CursorVal()
        local left, w = track:GetLeft(), track:GetWidth()
        if not left or w <= 0 then return nil end
        local frac = (GetCursorPosition() / rs:GetEffectiveScale() - left) / w
        return Snap(math.max(0, math.min(1, frac)) * 100)
    end

    local active
    local function Stop()
        if not active then return end
        active.tex:SetScale(1)
        active = nil
        rs:SetScript("OnUpdate", nil)
        if rs._onDragStop then rs._onDragStop() end
        if rs._onCommit then rs._onCommit(rs.low, rs.high) end
    end
    local function DragTick()
        if not IsMouseButtonDown("LeftButton") then Stop() return end
        local v = CursorVal()
        if not v then return end
        local oldLow, oldHigh = rs.low, rs.high
        if active == lowThumb then
            rs.low = math.max(0, math.min(v, rs._dual and rs.high - rs._minGap or 100))
        else
            rs.high = math.min(100, math.max(v, rs.low + rs._minGap))
        end
        -- Snapped to whole percents, so most frames land on the same value — skip repaint/preview unless it actually moved.
        if rs.low == oldLow and rs.high == oldHigh then return end
        Reposition()
        if rs._onPreview then rs._onPreview(rs.low, rs.high) end
    end
    local function StartDrag(t)
        if active then return end
        active = t
        t.tex:SetScale(1.2)
        if rs._onDragStart then rs._onDragStart() end
        rs:SetScript("OnUpdate", DragTick)
    end
    lowThumb:SetScript("OnMouseDown", function() StartDrag(lowThumb) end)
    highThumb:SetScript("OnMouseDown", function() StartDrag(highThumb) end)
    lowThumb:SetScript("OnMouseUp", Stop)
    highThumb:SetScript("OnMouseUp", Stop)
    -- Hidden mid-drag (recycled / panel closing) must end the drag so a pooled slider never resumes a stale drag on reuse.
    rs:SetScript("OnHide", Stop)
    rs:SetScript("OnShow", Reposition)
    rs:SetScript("OnSizeChanged", Reposition)

    -- Repositions only; never fires onPreview/onCommit (avoids drifting saved data on load/rebuild).
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
        self._dual = o.dual ~= false
        self._onPreview = o.onPreview
        self._onCommit = o.onCommit
        self._onDragStart = o.onDragStart
        self._onDragStop = o.onDragStop
        lowThumb._tip = o.lowTip
        highThumb._tip = o.highTip
    end

    return rs
end
