local MAJOR_VERSION = "LibTransmogGlow-1.0"
local MINOR_VERSION = 5

local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

-- [ CONSTANTS ] ------------------------------------------------------------------------------------

local GLOW_KEY_PREFIX = "_TransmogGlow"
local DEFAULT_STRATA = "HIGH"
local DEFAULT_FRAME_LEVEL_OFFSET = 1
local DEFAULT_GLOW_INSET = 0
local FLIPBOOK_ROWS_SIDE = 3
local FLIPBOOK_COLS_SIDE = 30
local FLIPBOOK_ROWS_CAP = 7
local FLIPBOOK_COLS_CAP = 10
local FLIPBOOK_FRAMES = 70
local LOOP_DURATION = 2.33
local PULSE_FADE_IN = 1.0
local PULSE_FADE_OUT = 1.33
local FLIPBOOK_THICKNESS = 8
local PENDING_FX_PADDING = 10
local SMOKE_INSET = 5
local PENDING_FX_NATIVE_TINT = { 0.85, 0.5, 1.0, 1.0 }
local SMOKE_DRIFT_RATIO = 0.2

-- The warlock's phylactery pulses with unbound energy—choose your color wisely, adventurer
local function ResolveColor(color)
    if not color then return nil end
    if type(color) == "table" and color.GetRGBA then return { color:GetRGBA() } end
    if color.r then return { color.r, color.g, color.b, color.a or 1 } end
    return color
end

-- [ POOL ] -----------------------------------------------------------------------------------------

local GlowParent = UIParent

local function GlowResetter(_, frame)
    frame:SetScript("OnUpdate", nil)
    frame:SetScript("OnShow", nil)
    frame:SetScript("OnHide", nil)
    frame:SetScript("OnSizeChanged", nil)
    local parent = frame:GetParent()
    if frame.glowKey and parent[frame.glowKey] then parent[frame.glowKey] = nil end
    if frame.textures then for _, tex in ipairs(frame.textures) do tex:Hide() end end
    if frame.animLoop then frame.animLoop:Stop() end
    frame:Hide()
    frame:ClearAllPoints()
end

local GlowPool = CreateFramePool("Frame", GlowParent, nil, GlowResetter)

-- [ ANIMATION HELPERS ] ----------------------------------------------------------------------------

local function CreateFlipbook(anim, childKey, rows, cols, frames)
    local fb = anim:CreateAnimation("FlipBook")
    fb:SetChildKey(childKey)
    fb:SetDuration(LOOP_DURATION)
    fb:SetOrder(1)
    fb:SetFlipBookRows(rows)
    fb:SetFlipBookColumns(cols)
    fb:SetFlipBookFrames(frames)
    fb:SetFlipBookFrameWidth(0)
    fb:SetFlipBookFrameHeight(0)
end

local function CreateSmokeFade(anim, childKey, fadeIn, fadeOut)
    local alphaIn = anim:CreateAnimation("Alpha")
    alphaIn:SetChildKey(childKey)
    alphaIn:SetOrder(1)
    alphaIn:SetDuration(fadeIn)
    alphaIn:SetFromAlpha(0)
    alphaIn:SetToAlpha(1)

    local alphaOut = anim:CreateAnimation("Alpha")
    alphaOut:SetChildKey(childKey)
    alphaOut:SetOrder(1)
    alphaOut:SetDuration(fadeOut)
    alphaOut:SetStartDelay(fadeIn)
    alphaOut:SetFromAlpha(1)
    alphaOut:SetToAlpha(0)
end

local function CreateSmokeDrift(anim, childKey)
    local drift = anim:CreateAnimation("Translation")
    drift:SetChildKey(childKey)
    drift:SetOrder(1)
    drift:SetDuration(LOOP_DURATION)
    return drift
end

-- [ GLOW CONSTRUCTION ] ----------------------------------------------------------------------------

local function BuildGlowFrame()
    local f = GlowPool:Acquire()
    if f.built then return f end

    f.textures = {}

    -- Central pulsing glow — ARTWORK so sparkles render on top
    f.PendingFX = f:CreateTexture(nil, "OVERLAY", nil, -1)
    f.PendingFX:SetAtlas("transmog-itemCard-transmogrified-pending-FX1")
    f.PendingFX:SetBlendMode("ADD")
    f.PendingFX:SetVertexColor(unpack(PENDING_FX_NATIVE_TINT))
    f.PendingFX:SetPoint("TOPLEFT", f, "TOPLEFT", -PENDING_FX_PADDING, PENDING_FX_PADDING)
    f.PendingFX:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", PENDING_FX_PADDING, -PENDING_FX_PADDING)
    f.textures[#f.textures + 1] = f.PendingFX

    -- Edge flipbook sparkle strips — OVERLAY, centered on each edge
    f.FlipbookTop = f:CreateTexture(nil, "OVERLAY")
    f.FlipbookTop:SetAtlas("transmog-itemSlot-flipbook-loop-Top")
    f.FlipbookTop:SetPoint("LEFT", f, "TOPLEFT", 0, 0)
    f.FlipbookTop:SetPoint("RIGHT", f, "TOPRIGHT", 0, 0)
    f.textures[#f.textures + 1] = f.FlipbookTop

    f.FlipbookBottom = f:CreateTexture(nil, "OVERLAY")
    f.FlipbookBottom:SetAtlas("transmog-itemSlot-flipbook-loop-Bottom")
    f.FlipbookBottom:SetPoint("LEFT", f, "BOTTOMLEFT", 0, 0)
    f.FlipbookBottom:SetPoint("RIGHT", f, "BOTTOMRIGHT", 0, 0)
    f.textures[#f.textures + 1] = f.FlipbookBottom

    f.FlipbookLeft = f:CreateTexture(nil, "OVERLAY")
    f.FlipbookLeft:SetAtlas("transmog-itemSlot-flipbook-loop-Left")
    f.FlipbookLeft:SetPoint("TOP", f, "TOPLEFT", 0, 0)
    f.FlipbookLeft:SetPoint("BOTTOM", f, "BOTTOMLEFT", 0, 0)
    f.textures[#f.textures + 1] = f.FlipbookLeft

    f.FlipbookRight = f:CreateTexture(nil, "OVERLAY")
    f.FlipbookRight:SetAtlas("transmog-itemSlot-flipbook-loop-Right")
    f.FlipbookRight:SetPoint("TOP", f, "TOPRIGHT", 0, 0)
    f.FlipbookRight:SetPoint("BOTTOM", f, "BOTTOMRIGHT", 0, 0)
    f.textures[#f.textures + 1] = f.FlipbookRight

    -- Smoke wisps — ARTWORK, behind sparkles, sized dynamically
    f.SmokeFXTop = f:CreateTexture(nil, "ARTWORK")
    f.SmokeFXTop:SetAtlas("transmog-itemCard-transmogrified-pending-FX2")
    f.SmokeFXTop:SetBlendMode("ADD")
    f.textures[#f.textures + 1] = f.SmokeFXTop

    f.SmokeFXBottom = f:CreateTexture(nil, "ARTWORK")
    f.SmokeFXBottom:SetAtlas("transmog-itemCard-transmogrified-pending-FX2")
    f.SmokeFXBottom:SetBlendMode("ADD")
    f.textures[#f.textures + 1] = f.SmokeFXBottom

    f.SmokeFXLeft = f:CreateTexture(nil, "ARTWORK")
    f.SmokeFXLeft:SetAtlas("transmog-itemCard-transmogrified-pending-FX3")
    f.SmokeFXLeft:SetBlendMode("ADD")
    f.textures[#f.textures + 1] = f.SmokeFXLeft

    f.SmokeFXRight = f:CreateTexture(nil, "ARTWORK")
    f.SmokeFXRight:SetAtlas("transmog-itemCard-transmogrified-pending-FX3")
    f.SmokeFXRight:SetBlendMode("ADD")
    f.textures[#f.textures + 1] = f.SmokeFXRight

    -- Looping animation group
    f.animLoop = f:CreateAnimationGroup()
    f.animLoop:SetLooping("REPEAT")
    f.animLoop:SetToFinalAlpha(true)

    -- PendingFX pulse
    local pulseIn = f.animLoop:CreateAnimation("Alpha")
    pulseIn:SetChildKey("PendingFX")
    pulseIn:SetOrder(1)
    pulseIn:SetDuration(PULSE_FADE_IN)
    pulseIn:SetFromAlpha(0)
    pulseIn:SetToAlpha(1)

    local pulseOut = f.animLoop:CreateAnimation("Alpha")
    pulseOut:SetChildKey("PendingFX")
    pulseOut:SetOrder(1)
    pulseOut:SetDuration(PULSE_FADE_OUT)
    pulseOut:SetStartDelay(PULSE_FADE_IN)
    pulseOut:SetFromAlpha(1)
    pulseOut:SetToAlpha(0)

    -- Edge flipbooks
    CreateFlipbook(f.animLoop, "FlipbookTop", FLIPBOOK_ROWS_CAP, FLIPBOOK_COLS_CAP, FLIPBOOK_FRAMES)
    CreateFlipbook(f.animLoop, "FlipbookBottom", FLIPBOOK_ROWS_CAP, FLIPBOOK_COLS_CAP, FLIPBOOK_FRAMES)
    CreateFlipbook(f.animLoop, "FlipbookLeft", FLIPBOOK_ROWS_SIDE, FLIPBOOK_COLS_SIDE, FLIPBOOK_FRAMES)
    CreateFlipbook(f.animLoop, "FlipbookRight", FLIPBOOK_ROWS_SIDE, FLIPBOOK_COLS_SIDE, FLIPBOOK_FRAMES)

    -- Smoke drift refs — offsets set dynamically in UpdateSmokeDrift
    f.driftTop = CreateSmokeDrift(f.animLoop, "SmokeFXTop")
    f.driftBottom = CreateSmokeDrift(f.animLoop, "SmokeFXBottom")
    f.driftLeft = CreateSmokeDrift(f.animLoop, "SmokeFXLeft")
    f.driftRight = CreateSmokeDrift(f.animLoop, "SmokeFXRight")

    -- Smoke fades (staggered timing for seamless perimeter flow)
    CreateSmokeFade(f.animLoop, "SmokeFXTop", 1.0, 1.33)
    CreateSmokeFade(f.animLoop, "SmokeFXBottom", 0.83, 1.5)
    CreateSmokeFade(f.animLoop, "SmokeFXLeft", 1.0, 1.33)
    CreateSmokeFade(f.animLoop, "SmokeFXRight", 0.5, 1.83)

    f.built = true
    return f
end

-- [ SIZE UPDATE ] ----------------------------------------------------------------------------------

local function UpdateGlowLayout(f)
    local w, h = f:GetSize()
    if w <= 0 or h <= 0 then return end

    -- Flipbook thickness
    f.FlipbookTop:SetHeight(FLIPBOOK_THICKNESS)
    f.FlipbookBottom:SetHeight(FLIPBOOK_THICKNESS)
    f.FlipbookLeft:SetWidth(FLIPBOOK_THICKNESS)
    f.FlipbookRight:SetWidth(FLIPBOOK_THICKNESS)

    -- Smoke inside the frame, near each edge, sized to shorter dimension
    local smokeSize = math.min(w, h) * 0.6

    f.SmokeFXTop:ClearAllPoints()
    f.SmokeFXTop:SetSize(smokeSize, smokeSize)
    f.SmokeFXTop:SetPoint("TOP", f, "TOP", -w * 0.1, -SMOKE_INSET)

    f.SmokeFXBottom:ClearAllPoints()
    f.SmokeFXBottom:SetSize(smokeSize, smokeSize)
    f.SmokeFXBottom:SetPoint("BOTTOM", f, "BOTTOM", w * 0.1, SMOKE_INSET)

    f.SmokeFXLeft:ClearAllPoints()
    f.SmokeFXLeft:SetSize(smokeSize, smokeSize)
    f.SmokeFXLeft:SetPoint("LEFT", f, "LEFT", SMOKE_INSET, -h * 0.15)

    f.SmokeFXRight:ClearAllPoints()
    f.SmokeFXRight:SetSize(smokeSize, smokeSize)
    f.SmokeFXRight:SetPoint("RIGHT", f, "RIGHT", -SMOKE_INSET, h * 0.15)

    -- Smoke drift: horizontal smoke drifts along width, vertical smoke drifts along height
    local driftH = w * SMOKE_DRIFT_RATIO
    local driftV = h * SMOKE_DRIFT_RATIO
    f.driftTop:SetOffset(driftH, 0)
    f.driftBottom:SetOffset(-driftH, 0)
    f.driftLeft:SetOffset(0, driftV)
    f.driftRight:SetOffset(0, -driftV)
end

-- [ APPLY COLOR ] ----------------------------------------------------------------------------------

local function ApplyColor(f, color)
    local resolved = ResolveColor(color)
    for _, tex in ipairs(f.textures) do
        if resolved then
            tex:SetDesaturated(true)
            tex:SetVertexColor(resolved[1], resolved[2], resolved[3], resolved[4] or 1)
        else
            tex:SetDesaturated(false)
            if tex == f.PendingFX then
                tex:SetVertexColor(unpack(PENDING_FX_NATIVE_TINT))
            else
                tex:SetVertexColor(1, 1, 1, 1)
            end
        end
    end
end

-- [ PUBLIC API ] -----------------------------------------------------------------------------------

function lib.TransmogGlow_Start(r, color, xOffset, yOffset, key, frameLevel)
    if not r then return end

    key = key or ""
    xOffset = xOffset or DEFAULT_GLOW_INSET
    yOffset = yOffset or DEFAULT_GLOW_INSET
    frameLevel = frameLevel or DEFAULT_FRAME_LEVEL_OFFSET

    local glowKey = GLOW_KEY_PREFIX .. key

    local f = r[glowKey]
    if not f then
        f = BuildGlowFrame()
        f.glowKey = glowKey
        r[glowKey] = f
    end

    f:SetParent(r)
    f:SetFrameStrata(DEFAULT_STRATA)
    f:SetFrameLevel(r:GetFrameLevel() + frameLevel)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", r, "TOPLEFT", -xOffset, yOffset)
    f:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", xOffset, -yOffset)

    ApplyColor(f, color)
    UpdateGlowLayout(f)

    f:SetScript("OnSizeChanged", UpdateGlowLayout)
    f:Show()

    if not f.animLoop:IsPlaying() then f.animLoop:Restart() end
end

function lib.TransmogGlow_Stop(r, key)
    if not r then return end
    key = key or ""
    local glowKey = GLOW_KEY_PREFIX .. key
    if not r[glowKey] then return false end
    GlowPool:Release(r[glowKey])
end
