local MAJOR_VERSION = "LibOrbitGlow-1.0"
local MINOR_VERSION = 5
local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

-- [ CONSTANTS ] ---------------------------------------------------------------
local GLOW_PARENT = UIParent
local DEFAULT_FRAME_LEVEL = 8
local SUBPIXEL_INSET = 0.05
local DEFAULT_FLIPBOOK_SCALE = 1.4
local DEFAULT_FLIPBOOK_ROWS = 6
local DEFAULT_FLIPBOOK_COLS = 5
local DEFAULT_AUTOCAST_PERIOD = 8
local DEFAULT_AUTOCAST_PARTICLES = 4
local AUTOCAST_PARTICLE_SIZES = { 7, 6, 5, 4 }
local DEFAULT_PIXEL_LINES = 8
local DEFAULT_PIXEL_PERIOD = 4
local DEFAULT_PIXEL_THICKNESS = 2
local PIXEL_BORDER_COLOR = { 0.05, 0.05, 0.05, 0.85 }
local PIXEL_FREQ_SCALAR = 0.25
local PIXEL_LENGTH_SCALAR = 3
local PIXEL_LENGTH_FACTOR = 0.1
local BUTTON_SCALE = 1.4
local BUTTON_OFFSET_RATIO = 0.2
local BUTTON_ANTS_RATIO = 0.85
local BUTTON_ANT_SHEET_SIZE = 256
local BUTTON_ANT_FRAME_SIZE = 48
local BUTTON_ANT_TOTAL_FRAMES = 22
local BUTTON_ANT_COLS = 5
local BUTTON_DEFAULT_FREQ = 0.25
local BUTTON_DEFAULT_THROTTLE = 0.01
local BUTTON_GLOW_TEXTURES = { "spark", "innerGlow", "innerGlowOver", "outerGlow", "outerGlowOver", "ants" }
local THIN_ATLAS = "RotationHelper_Ants_Flipbook_2x"
local THICK_ATLAS = "RotationHelper-ProcLoopBlue-Flipbook-2x"
local MEDIUM_ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook"
local STATIC_ATLAS = "UI-CooldownManager-ActiveGlow"
local TARGET_FRAME_TIME = 1 / 60 -- Lock math evaluation to maximum of 60 FPS

-- [ UTILITIES ] ---------------------------------------------------------------
local function Snap(val)
    return math.floor(val + 0.5)
end

local function GetColorRGBA(colorTable)
    if not colorTable then return 1, 1, 1, 1 end
    if type(colorTable) == "table" and colorTable.GetRGBA then return colorTable:GetRGBA() end
    if colorTable.r then return colorTable.r, colorTable.g, colorTable.b, colorTable.a or 1 end
    return colorTable[1] or 1, colorTable[2] or 1, colorTable[3] or 1, colorTable[4] or 1
end

local function ApplyPaddedAnchors(f, parent, scale, offsetScale, padding, shiftX, shiftY)
    f:ClearAllPoints()
    local padX = (padding or 0) + (offsetScale or 0) + (parent:GetWidth() * (scale - 1) / 2)
    local padY = (padding or 0) + (offsetScale or 0) + (parent:GetHeight() * (scale - 1) / 2)
    shiftX = shiftX or 0
    shiftY = shiftY or 0
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", -padX + shiftX, padY + shiftY)
    f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", padX + shiftX, -padY + shiftY)
end

-- [ POOLS ] -------------------------------------------------------------------
local GlowMaskPool = {
    activeObjects = {}, inactiveObjects = {}, activeObjectCount = 0,
    createFunc = function(self) return GLOW_PARENT:CreateMaskTexture() end,
    resetFunc = function(self, mask) mask:Hide(); mask:ClearAllPoints() end,
    Release = function(self, object)
        if not self.activeObjects[object] then return false end
        self:resetFunc(object)
        tinsert(self.inactiveObjects, object)
        self.activeObjects[object] = nil
        self.activeObjectCount = self.activeObjectCount - 1
        return true
    end,
    Acquire = function(self)
        local object = tremove(self.inactiveObjects)
        local new = object == nil
        if new then
            object = self:createFunc()
            self:resetFunc(object, new)
        end
        self.activeObjects[object] = true
        self.activeObjectCount = self.activeObjectCount + 1
        return object, new
    end
}

local function TexPoolResetter(pool, tex)
    if tex.animGroup and tex.animGroup:IsPlaying() then tex.animGroup:Stop() end
    for i = tex:GetNumMaskTextures(), 1, -1 do tex:RemoveMaskTexture(tex:GetMaskTexture(i)) end
    tex:Hide()
    tex:ClearAllPoints()
end
local GlowTexPool = CreateTexturePool(GLOW_PARENT, "ARTWORK", 7, nil, TexPoolResetter)

local function FramePoolResetter(framePool, frame)
    frame:SetScript("OnUpdate", nil)
    if frame.animIn and frame.animIn:IsPlaying() then frame.animIn:Stop() end
    if frame.animOut and frame.animOut:IsPlaying() then frame.animOut:Stop() end
    if frame.animGroup and frame.animGroup:IsPlaying() then frame.animGroup:Stop() end
    local parent = frame:GetParent()
    if frame.name and parent and parent[frame.name] then parent[frame.name] = nil end
    if frame.textures then
        for i = 1, #frame.textures do GlowTexPool:Release(frame.textures[i]) end
        table.wipe(frame.textures)
    end
    if frame.bg then GlowTexPool:Release(frame.bg); frame.bg = nil end
    if frame.masks then
        for i = 1, #frame.masks do GlowMaskPool:Release(frame.masks[i]) end
        table.wipe(frame.masks)
    end
    if frame.info then table.wipe(frame.info) end
    frame.name = nil
    frame.timer = nil
    frame:Hide()
    frame:ClearAllPoints()
end
local GlowFramePool = CreateFramePool("Frame", GLOW_PARENT, nil, FramePoolResetter)

-- [ CORE INITIALIZER ] --------------------------------------------------------
local function AcquireFrameAndTex(parent, nameKey, N, texture, texCoord, isDesaturated, frameLevel, r, g, b, a, blendMode)
    frameLevel = frameLevel or DEFAULT_FRAME_LEVEL
    if not parent[nameKey] then
        parent[nameKey] = GlowFramePool:Acquire()
        parent[nameKey]:SetParent(parent)
        parent[nameKey].name = nameKey
    end
    local f = parent[nameKey]
    f:SetFrameLevel(parent:GetFrameLevel() + frameLevel)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", SUBPIXEL_INSET, SUBPIXEL_INSET)
    f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -SUBPIXEL_INSET, -SUBPIXEL_INSET)
    f:Show()
    f.textures = f.textures or {}
    for i = 1, N do
        if not f.textures[i] then
            f.textures[i] = GlowTexPool:Acquire()
            if texCoord then
                f.textures[i]:SetTexture(texture)
                f.textures[i]:SetTexCoord(texCoord[1], texCoord[2], texCoord[3], texCoord[4])
            end
            f.textures[i]:SetParent(f)
            f.textures[i]:SetDrawLayer("ARTWORK", 7)
        end
        f.textures[i]:SetDesaturated(isDesaturated)
        f.textures[i]:SetVertexColor(r, g, b, a)
        if blendMode then f.textures[i]:SetBlendMode(blendMode) end
        f.textures[i]:Show()
    end
    while #f.textures > N do
        GlowTexPool:Release(f.textures[#f.textures])
        table.remove(f.textures)
    end
    return f
end

local function UpdateFlipbookTexture(texture, currentFrame, rows, cols)
    local frameW = 1 / cols
    local frameH = 1 / rows
    local col = currentFrame % cols
    local row = math.floor(currentFrame / cols)
    texture:SetTexCoord(col * frameW, (col + 1) * frameW, row * frameH, (row + 1) * frameH)
end

-- [ FLIPBOOK / PROC GLOW ] ----------------------------------------------------
lib.Flipbook = {}

local function FlipbookReverseOnUpdate(self, elapsed)
    self.throttle = (self.throttle or 0) + elapsed
    if self.throttle < TARGET_FRAME_TIME then return end
    self.elapsed = self.elapsed + self.throttle
    local progress = (self.elapsed / self.flipData.dur) % 1
    local frameIndex = math.floor((1 - progress) * self.flipData.f) % self.flipData.f
    for i = 1, #self.textures do
        UpdateFlipbookTexture(self.textures[i], frameIndex, self.flipData.r, self.flipData.c)
    end
    self.throttle = 0
end

function lib.Flipbook:Show(frame, options)
    options = options or {}
    local r, g, b, a = GetColorRGBA(options.color)
    local nameKey = "_LibGlowFlipbook" .. (options.key or "Default")
    local existing = frame[nameKey]
    if existing and existing:IsShown() and existing.textures and existing.textures[1] then
        local tex1 = existing.textures[1]
        local isAnimating = (tex1.animGroup and tex1.animGroup:IsPlaying()) or existing:GetScript("OnUpdate")
        if isAnimating then
            for i = 1, #existing.textures do existing.textures[i]:SetVertexColor(r, g, b, a) end
            return
        end
    end
    local atlas = options.atlas or "UI-HUD-ActionBar-Proc-Loop-Flipbook"
    local isTexture = options.isTexture or false
    local rows = options.rows
    local cols = options.cols
    local frames = options.frames
    local speed = options.speed or 1.0
    if not isTexture then
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
        if info then
            rows = rows or info.flipBookRows
            cols = cols or info.flipBookColumns
            frames = frames or info.flipBookFrames
        end
    end
    rows = rows or DEFAULT_FLIPBOOK_ROWS
    cols = cols or DEFAULT_FLIPBOOK_COLS
    frames = frames or (rows * cols)
    local N = options.N or 1
    local blendMode = options.blendMode or "BLEND"
    local f = AcquireFrameAndTex(frame, nameKey, N, nil, nil, true, options.frameLevel, r, g, b, a, blendMode)
    local scale = options.scale or DEFAULT_FLIPBOOK_SCALE
    ApplyPaddedAnchors(f, frame, scale, options.offsetScale, options.padding, options.offsetX, options.offsetY)
    for i = 1, N do
        local tex = f.textures[i]
        tex:SetTexCoord(0, 1, 0, 1)
        if isTexture then tex:SetTexture(atlas) else tex:SetAtlas(atlas) end
        tex:SetAllPoints(f)
        tex:SetDesaturated(options.desaturated ~= false)
        tex:SetVertexColor(r, g, b, a)
        tex:SetBlendMode(blendMode)
    end
    if options.reverse then
        for i = 1, N do
            if f.textures[i].animGroup and f.textures[i].animGroup:IsPlaying() then
                f.textures[i].animGroup:Stop()
            end
        end
        f.flipData = { dur = speed, r = rows, c = cols, f = frames }
        f.elapsed = 0
        f:SetScript("OnUpdate", FlipbookReverseOnUpdate)
    else
        f:SetScript("OnUpdate", nil)
        for i = 1, N do
            local texLoop = f.textures[i]
            if not texLoop.animGroup then
                texLoop.animGroup = texLoop:CreateAnimationGroup()
                texLoop.animGroup:SetLooping("REPEAT")
                local fbAnim = texLoop.animGroup:CreateAnimation("FlipBook")
                fbAnim:SetOrder(1)
                texLoop.flipbookAnim = fbAnim
            end
            texLoop.flipbookAnim:SetDuration(speed)
            texLoop.flipbookAnim:SetFlipBookRows(rows)
            texLoop.flipbookAnim:SetFlipBookColumns(cols)
            texLoop.flipbookAnim:SetFlipBookFrames(frames)
            if not texLoop.animGroup:IsPlaying() then texLoop.animGroup:Play() end
        end
    end
end

function lib.Flipbook:Hide(frame, key)
    local nameKey = "_LibGlowFlipbook" .. (key or "Default")
    if frame[nameKey] then
        GlowFramePool:Release(frame[nameKey])
        frame[nameKey] = nil
    end
end

-- [ STATIC GLOW ] -------------------------------------------------------------
lib.Static = {}

function lib.Static:Show(frame, options)
    options = options or {}
    local r, g, b, a = GetColorRGBA(options.color)
    local nameKey = "_LibGlowStatic" .. (options.key or "Default")
    local existing = frame[nameKey]
    if existing and existing:IsShown() and existing.textures then
        for i = 1, #existing.textures do existing.textures[i]:SetVertexColor(r, g, b, a) end
        return
    end
    local N = options.N or 1
    local blendMode = options.blendMode or "BLEND"
    local f = AcquireFrameAndTex(frame, nameKey, N, nil, nil, true, options.frameLevel, r, g, b, a, blendMode)
    local scale = options.scale or DEFAULT_FLIPBOOK_SCALE
    ApplyPaddedAnchors(f, frame, scale, options.offsetScale, options.padding, options.offsetX, options.offsetY)
    for i = 1, N do
        local tex = f.textures[i]
        if options.isAtlas then
            tex:SetAtlas(options.texture)
        else
            tex:SetTexture(options.texture or "Interface\\HUD\\uiactionbarfxx2")
            if options.texCoord then
                tex:SetTexCoord(options.texCoord[1], options.texCoord[2], options.texCoord[3], options.texCoord[4])
            else
                tex:SetTexCoord(0, 1, 0, 1)
            end
        end
        tex:SetAllPoints(f)
        tex:SetDesaturated(options.desaturated ~= false)
        tex:SetVertexColor(r, g, b, a)
        tex:SetBlendMode(blendMode)
    end
end

function lib.Static:Hide(frame, key)
    local nameKey = "_LibGlowStatic" .. (key or "Default")
    if frame[nameKey] then
        GlowFramePool:Release(frame[nameKey])
        frame[nameKey] = nil
    end
end

-- [ AUTOCAST GLOW ] -----------------------------------------------------------
lib.Autocast = {}

local function AutocastOnUpdate(self, elapsed)
    self.throttle = (self.throttle or 0) + elapsed
    if self.throttle < TARGET_FRAME_TIME then return end
    local dt = self.throttle
    self.throttle = 0
    local width, height = self:GetSize()
    if width ~= self.info.width or height ~= self.info.height then
        if width * height == 0 then return end
        self.info.width = width
        self.info.height = height
        self.info.perimeter = 2 * (width + height)
        self.info.bottomlim = height * 2 + width
        self.info.rightlim = height + width
        self.info.space = self.info.perimeter / self.info.N
    end
    local texIndex = 0
    local dir = self.info.direction
    for k = 1, 4 do
        self.timer[k] = self.timer[k] + (dt / (self.info.period * k)) * dir
        if self.timer[k] > 1 or self.timer[k] < -1 then self.timer[k] = self.timer[k] % 1 end
        for i = 1, self.info.N do
            texIndex = texIndex + 1
            local position = (self.info.space * i + self.info.perimeter * self.timer[k]) % self.info.perimeter
            if position > self.info.bottomlim then
                self.textures[texIndex]:SetPoint("CENTER", self, "BOTTOMRIGHT", -position + self.info.bottomlim, 0)
            elseif position > self.info.rightlim then
                self.textures[texIndex]:SetPoint("CENTER", self, "TOPRIGHT", 0, -position + self.info.rightlim)
            elseif position > self.info.height then
                self.textures[texIndex]:SetPoint("CENTER", self, "TOPLEFT", position - self.info.height, 0)
            else
                self.textures[texIndex]:SetPoint("CENTER", self, "BOTTOMLEFT", 0, position)
            end
        end
    end
end

function lib.Autocast:Show(frame, options)
    options = options or {}
    local r, g, b, a = GetColorRGBA(options.color)
    local key = options.key or "Default"
    local nameKey = "_LibGlowAutocast" .. key
    local existing = frame[nameKey]
    if existing and existing:IsShown() and existing.textures then
        for i = 1, #existing.textures do existing.textures[i]:SetVertexColor(r, g, b, a) end
        return
    end
    local N = options.particles or DEFAULT_AUTOCAST_PARTICLES
    local period = options.frequency and (options.frequency ~= 0 and 1 / math.abs(options.frequency) or DEFAULT_AUTOCAST_PERIOD) or DEFAULT_AUTOCAST_PERIOD
    local scale = options.scale or 1
    local xOffset = options.xOffset or 0
    local yOffset = options.yOffset or 0
    local texture = "Interface\\Artifacts\\Artifacts"
    local texCoord = { 0.8115234375, 0.9169921875, 0.8798828125, 0.9853515625 }
    local f = AcquireFrameAndTex(frame, nameKey, N * 4, texture, texCoord, nil, options.frameLevel, r, g, b, a, options.blendMode or "ADD")
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", frame, "TOPLEFT", -xOffset, yOffset)
    f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", xOffset, -yOffset)
    for k = 1, #AUTOCAST_PARTICLE_SIZES do
        local size = AUTOCAST_PARTICLE_SIZES[k]
        for i = 1, N do
            f.textures[i + N * (k - 1)]:SetSize(size * scale, size * scale)
        end
    end
    f.timer = f.timer or { 0, 0, 0, 0 }
    f.info = f.info or {}
    f.info.N = N
    f.info.period = period
    f.info.direction = options.reverse and -1 or 1
    f:SetScript("OnUpdate", AutocastOnUpdate)
    AutocastOnUpdate(f, 0)
end

function lib.Autocast:Hide(frame, key)
    local nameKey = "_LibGlowAutocast" .. (key or "Default")
    if frame[nameKey] then
        GlowFramePool:Release(frame[nameKey])
        frame[nameKey] = nil
    end
end

-- [ BUTTON GLOW ] -------------------------------------------------------------
lib.Button = {}

local function CreateScaleAnim(group, target, order, duration, x, y, delay)
    local scale = group:CreateAnimation("Scale")
    scale:SetChildKey(target)
    scale:SetOrder(order)
    scale:SetDuration(duration)
    scale:SetScale(x, y)
    if delay then scale:SetStartDelay(delay) end
end

local function CreateAlphaAnim(group, target, order, duration, fromAlpha, toAlpha, delay, appear)
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetChildKey(target)
    alpha:SetOrder(order)
    alpha:SetDuration(duration)
    alpha:SetFromAlpha(fromAlpha)
    alpha:SetToAlpha(toAlpha)
    if delay then alpha:SetStartDelay(delay) end
    if appear then tinsert(group.appear, alpha) else tinsert(group.fade, alpha) end
end

local function AnimIn_OnPlay(group)
    local frame = group:GetParent()
    local w, h = frame:GetSize()
    frame.spark:SetSize(w, h)
    frame.spark:SetAlpha(not(frame.color) and 1.0 or 0.3 * (frame.color[4] or 1))
    frame.innerGlow:SetSize(w / 2, h / 2)
    frame.innerGlow:SetAlpha(not(frame.color) and 1.0 or (frame.color[4] or 1))
    frame.innerGlowOver:SetAlpha(not(frame.color) and 1.0 or (frame.color[4] or 1))
    frame.outerGlow:SetSize(w * 2, h * 2)
    frame.outerGlow:SetAlpha(not(frame.color) and 1.0 or (frame.color[4] or 1))
    frame.outerGlowOver:SetAlpha(not(frame.color) and 1.0 or (frame.color[4] or 1))
    frame.ants:SetSize(w * BUTTON_ANTS_RATIO, h * BUTTON_ANTS_RATIO)
    frame.ants:SetAlpha(0)
    frame:Show()
end

local function AnimIn_OnFinished(group)
    local frame = group:GetParent()
    local w, h = frame:GetSize()
    frame.spark:SetAlpha(0)
    frame.innerGlow:SetAlpha(0)
    frame.innerGlow:SetSize(w, h)
    frame.innerGlowOver:SetAlpha(0.0)
    frame.outerGlow:SetSize(w, h)
    frame.outerGlowOver:SetAlpha(0.0)
    frame.outerGlowOver:SetSize(w, h)
    frame.ants:SetAlpha(not(frame.color) and 1.0 or (frame.color[4] or 1))
end

local function AnimIn_OnStop(group)
    local frame = group:GetParent()
    frame.spark:SetAlpha(0)
    frame.innerGlow:SetAlpha(0)
    frame.innerGlowOver:SetAlpha(0.0)
    frame.outerGlowOver:SetAlpha(0.0)
end

local function UpdateAlphaAnim(f, alpha)
    if f.animIn then
        for _, anim in ipairs(f.animIn.appear) do anim:SetToAlpha(alpha) end
        for _, anim in ipairs(f.animIn.fade) do anim:SetFromAlpha(alpha) end
    end
    if f.animOut then
        for _, anim in ipairs(f.animOut.appear) do anim:SetToAlpha(alpha) end
        for _, anim in ipairs(f.animOut.fade) do anim:SetFromAlpha(alpha) end
    end
end

local function ConfigureButtonGlow(f, alpha)
    f.spark = f:CreateTexture(nil, "BACKGROUND")
    f.spark:SetPoint("CENTER")
    f.spark:SetAlpha(0)
    f.spark:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    f.spark:SetTexCoord(0.00781250, 0.61718750, 0.00390625, 0.26953125)
    f.innerGlow = f:CreateTexture(nil, "ARTWORK")
    f.innerGlow:SetPoint("CENTER")
    f.innerGlow:SetAlpha(0)
    f.innerGlow:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    f.innerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    f.innerGlowOver = f:CreateTexture(nil, "ARTWORK")
    f.innerGlowOver:SetPoint("TOPLEFT", f.innerGlow, "TOPLEFT")
    f.innerGlowOver:SetPoint("BOTTOMRIGHT", f.innerGlow, "BOTTOMRIGHT")
    f.innerGlowOver:SetAlpha(0)
    f.innerGlowOver:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    f.innerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)
    f.outerGlow = f:CreateTexture(nil, "ARTWORK")
    f.outerGlow:SetPoint("CENTER")
    f.outerGlow:SetAlpha(0)
    f.outerGlow:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    f.outerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    f.outerGlowOver = f:CreateTexture(nil, "ARTWORK")
    f.outerGlowOver:SetPoint("TOPLEFT", f.outerGlow, "TOPLEFT")
    f.outerGlowOver:SetPoint("BOTTOMRIGHT", f.outerGlow, "BOTTOMRIGHT")
    f.outerGlowOver:SetAlpha(0)
    f.outerGlowOver:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    f.outerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)
    f.ants = f:CreateTexture(nil, "OVERLAY")
    f.ants:SetPoint("CENTER")
    f.ants:SetAlpha(0)
    f.ants:SetTexture([[Interface\SpellActivationOverlay\IconAlertAnts]])
    f.animIn = f:CreateAnimationGroup()
    f.animIn.appear = {}
    f.animIn.fade = {}
    CreateScaleAnim(f.animIn, "spark",          1, 0.2, 1.5, 1.5)
    CreateAlphaAnim(f.animIn, "spark",          1, 0.2, 0, alpha, nil, true)
    CreateScaleAnim(f.animIn, "innerGlow",      1, 0.3, 2, 2)
    CreateScaleAnim(f.animIn, "innerGlowOver",  1, 0.3, 2, 2)
    CreateAlphaAnim(f.animIn, "innerGlowOver",  1, 0.3, alpha, 0, nil, false)
    CreateScaleAnim(f.animIn, "outerGlow",      1, 0.3, 0.5, 0.5)
    CreateScaleAnim(f.animIn, "outerGlowOver",  1, 0.3, 0.5, 0.5)
    CreateAlphaAnim(f.animIn, "outerGlowOver",  1, 0.3, alpha, 0, nil, false)
    CreateScaleAnim(f.animIn, "spark",          1, 0.2, 2/3, 2/3, 0.2)
    CreateAlphaAnim(f.animIn, "spark",          1, 0.2, alpha, 0, 0.2, false)
    CreateAlphaAnim(f.animIn, "innerGlow",      1, 0.2, alpha, 0, 0.3, false)
    CreateAlphaAnim(f.animIn, "ants",           1, 0.2, 0, alpha, 0.3, true)
    f.animIn:SetScript("OnPlay", AnimIn_OnPlay)
    f.animIn:SetScript("OnStop", AnimIn_OnStop)
    f.animIn:SetScript("OnFinished", AnimIn_OnFinished)
    f.animOut = f:CreateAnimationGroup()
    f.animOut.appear = {}
    f.animOut.fade = {}
    CreateAlphaAnim(f.animOut, "outerGlowOver", 1, 0.2, 0, alpha, nil, true)
    CreateAlphaAnim(f.animOut, "ants",          1, 0.2, alpha, 0, nil, false)
    CreateAlphaAnim(f.animOut, "outerGlowOver", 2, 0.2, alpha, 0, nil, false)
    CreateAlphaAnim(f.animOut, "outerGlow",     2, 0.2, alpha, 0, nil, false)
end

local function ButtonReverseOnUpdate(self, elapsed)
    self.reverseElapsed = self.reverseElapsed + elapsed
    if self.reverseElapsed >= self.throttle then
        self.frameIndex = self.frameIndex - 1
        if self.frameIndex < 1 then self.frameIndex = BUTTON_ANT_TOTAL_FRAMES end
        self.reverseElapsed = self.reverseElapsed - self.throttle
        local currentFrame = self.frameIndex - 1
        local col = currentFrame % BUTTON_ANT_COLS
        local row = math.floor(currentFrame / BUTTON_ANT_COLS)
        local frameW = BUTTON_ANT_FRAME_SIZE / BUTTON_ANT_SHEET_SIZE
        local frameH = BUTTON_ANT_FRAME_SIZE / BUTTON_ANT_SHEET_SIZE
        self.ants:SetTexCoord(col * frameW, (col + 1) * frameW, row * frameH, (row + 1) * frameH)
    end
end

local function ButtonForwardOnUpdate(self, elapsed)
    AnimateTexCoords(self.ants, BUTTON_ANT_SHEET_SIZE, BUTTON_ANT_SHEET_SIZE, BUTTON_ANT_FRAME_SIZE, BUTTON_ANT_FRAME_SIZE, BUTTON_ANT_TOTAL_FRAMES, elapsed, self.throttle)
end

local ButtonGlowPool = CreateFramePool("Frame", GLOW_PARENT, nil, function(pool, frame)
    frame:SetScript("OnUpdate", nil)
    local parent = frame:GetParent()
    if frame.name and parent and parent[frame.name] then parent[frame.name] = nil end
    frame.name = nil
    frame:Hide()
    frame:ClearAllPoints()
end)

local function ApplyButtonLayout(f, frame, frameLevel)
    local w, h = frame:GetSize()
    f:SetFrameLevel(frame:GetFrameLevel() + (frameLevel or DEFAULT_FRAME_LEVEL))
    f:SetSize(w * BUTTON_SCALE, h * BUTTON_SCALE)
    f:SetPoint("TOPLEFT", frame, "TOPLEFT", -w * BUTTON_OFFSET_RATIO, h * BUTTON_OFFSET_RATIO)
    f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", w * BUTTON_OFFSET_RATIO, -h * BUTTON_OFFSET_RATIO)
    f.ants:SetSize(w * BUTTON_SCALE * BUTTON_ANTS_RATIO, h * BUTTON_SCALE * BUTTON_ANTS_RATIO)
end

function lib.Button:Show(frame, options)
    options = options or {}
    local r, g, b, a = GetColorRGBA(options.color)
    local freq = options.frequency or BUTTON_DEFAULT_FREQ
    local throttle = (freq > 0) and (PIXEL_FREQ_SCALAR / freq * BUTTON_DEFAULT_THROTTLE) or BUTTON_DEFAULT_THROTTLE
    local nameKey = "_LibGlowButton" .. (options.key or "Default")
    if frame[nameKey] then
        local f = frame[nameKey]
        f.color = { r, g, b, a }
        for _, texName in ipairs(BUTTON_GLOW_TEXTURES) do
            f[texName]:SetVertexColor(r, g, b)
        end
        UpdateAlphaAnim(f, a)
    else
        local f, new = ButtonGlowPool:Acquire()
        if new then
            ConfigureButtonGlow(f, a)
            f.animOut:SetScript("OnFinished", function(self) ButtonGlowPool:Release(self:GetParent()) end)
            f:SetScript("OnHide", function(self)
                if self.animOut:IsPlaying() then self.animOut:Stop(); ButtonGlowPool:Release(self) end
            end)
        else
            UpdateAlphaAnim(f, a)
        end
        frame[nameKey] = f
        f.name = nameKey
        f:SetParent(frame)
        ApplyButtonLayout(f, frame, options.frameLevel)
        f.color = { r, g, b, a }
        for _, texName in ipairs(BUTTON_GLOW_TEXTURES) do
            f[texName]:SetDesaturated(1)
            f[texName]:SetVertexColor(r, g, b)
        end
        f.throttle = throttle
        if options.reverse then f.reverseElapsed = 0; f.frameIndex = BUTTON_ANT_TOTAL_FRAMES end
        f:SetScript("OnUpdate", options.reverse and ButtonReverseOnUpdate or ButtonForwardOnUpdate)
        if f.animIn then f.animIn:Play() end
    end
end

function lib.Button:Hide(frame, key)
    local nameKey = "_LibGlowButton" .. (key or "Default")
    if frame[nameKey] then
        if frame[nameKey].animIn and frame[nameKey].animIn:IsPlaying() then
            frame[nameKey].animIn:Stop()
            ButtonGlowPool:Release(frame[nameKey])
        elseif frame:IsVisible() then
            frame[nameKey].animOut:Play()
        else
            ButtonGlowPool:Release(frame[nameKey])
        end
    end
end

-- [ PIXEL GLOW ] --------------------------------------------------------------
lib.Pixel = {}

local function PixelCalcTL(progress, s, th, p)
    if progress > p[3] or progress < p[0] then return 0 end
    if progress > p[2] then return Snap(s - th - (progress - p[2]) / (p[3] - p[2]) * (s - th)) end
    if progress > p[1] then return Snap(s - th) end
    return Snap((progress - p[0]) / (p[1] - p[0]) * (s - th))
end

local function PixelCalcBR(progress, s, th, p)
    if progress > p[3] then return Snap(s - th - (progress - p[3]) / (p[0] + 1 - p[3]) * (s - th)) end
    if progress > p[2] then return Snap(s - th) end
    if progress > p[1] then return Snap((progress - p[1]) / (p[2] - p[1]) * (s - th)) end
    if progress > p[0] then return 0 end
    return Snap(s - th - (progress + 1 - p[3]) / (p[0] + 1 - p[3]) * (s - th))
end

local function PixelOnUpdate(self, elapsed)
    self.throttle = (self.throttle or 0) + elapsed
    if self.throttle < TARGET_FRAME_TIME then return end
    local dt = self.throttle
    self.throttle = 0
    self.timer = (self.timer + (dt / self.info.period) * self.info.direction) % 1
    local w, h = self:GetSize()
    if w ~= self.info.width or h ~= self.info.height then
        local perim = 2 * (w + h)
        if perim <= 0 then return end
        self.info.width, self.info.height = w, h
        local lenHalf = self.info.length / 2
        self.info.pTLx = { [0] = (h + lenHalf) / perim, [1] = (h + w + lenHalf) / perim, [2] = (2 * h + w - lenHalf) / perim, [3] = 1 - lenHalf / perim }
        self.info.pTLy = { [0] = (h - lenHalf) / perim, [1] = (h + w + lenHalf) / perim, [2] = (2 * h + w + lenHalf) / perim, [3] = 1 - lenHalf / perim }
        self.info.pBRx = { [0] = lenHalf / perim, [1] = (h - lenHalf) / perim, [2] = (h + w - lenHalf) / perim, [3] = (2 * h + w + lenHalf) / perim }
        self.info.pBRy = { [0] = lenHalf / perim, [1] = (h + lenHalf) / perim, [2] = (h + w - lenHalf) / perim, [3] = (2 * h + w - lenHalf) / perim }
    end
    for k, line in ipairs(self.textures) do
        local p = (self.timer + self.info.step * (k - 1)) % 1
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", self, "TOPLEFT", PixelCalcTL(p, w, self.info.th, self.info.pTLx), -PixelCalcBR(p, h, self.info.th, self.info.pTLy))
        line:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", self.info.th + PixelCalcBR(p, w, self.info.th, self.info.pBRx), -h + PixelCalcTL(p, h, self.info.th, self.info.pBRy))
    end
end

function lib.Pixel:Show(frame, options)
    options = options or {}
    local r, g, b, a = GetColorRGBA(options.color)
    local key = options.key or "Default"
    local nameKey = "_PixelGlow" .. key
    local existing = frame[nameKey]
    if existing and existing:IsShown() and existing.textures then
        for i = 1, #existing.textures do existing.textures[i]:SetVertexColor(r, g, b, a) end
        return
    end
    local N = options.lines or DEFAULT_PIXEL_LINES
    local period = options.frequency and (options.frequency > 0 and PIXEL_FREQ_SCALAR / options.frequency or DEFAULT_PIXEL_PERIOD) or DEFAULT_PIXEL_PERIOD
    local th = options.thickness or DEFAULT_PIXEL_THICKNESS
    local xOffset = options.xOffset or 0
    local yOffset = options.yOffset or 0
    local w, h = frame:GetSize()
    local length = options.length or math.floor((w + h) * (2 / N - PIXEL_LENGTH_FACTOR) * PIXEL_LENGTH_SCALAR)
    local f = AcquireFrameAndTex(frame, nameKey, N, "Interface\\BUTTONS\\WHITE8X8", { 0, 1, 0, 1 }, nil, options.frameLevel, r, g, b, a, nil)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", frame, "TOPLEFT", -xOffset, yOffset)
    f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", xOffset, -yOffset)
    f.info = { step = 1 / N, period = period, direction = options.reverse and -1 or 1, th = th, length = length }
    f.masks = f.masks or {}
    if not f.masks[1] then
        f.masks[1] = GlowMaskPool:Acquire()
        f.masks[1]:SetTexture("Interface\\AdventureMap\\BrokenIsles\\AM_29", "CLAMPTOWHITE", "CLAMPTOWHITE")
        f.masks[1]:Show()
    end
    f.masks[1]:SetPoint("TOPLEFT", f, "TOPLEFT", th, -th)
    f.masks[1]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -th, th)
    if options.border ~= false then
        if not f.masks[2] then
            f.masks[2] = GlowMaskPool:Acquire()
            f.masks[2]:SetTexture("Interface\\AdventureMap\\BrokenIsles\\AM_29", "CLAMPTOWHITE", "CLAMPTOWHITE")
            f.masks[2]:Show()
        end
        f.masks[2]:SetPoint("TOPLEFT", f, "TOPLEFT", th + 1, -th - 1)
        f.masks[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -th - 1, th + 1)
        if not f.bg then
            f.bg = GlowTexPool:Acquire()
            f.bg:SetColorTexture(PIXEL_BORDER_COLOR[1], PIXEL_BORDER_COLOR[2], PIXEL_BORDER_COLOR[3], PIXEL_BORDER_COLOR[4])
            f.bg:SetParent(f)
            f.bg:SetAllPoints(f)
            f.bg:SetDrawLayer("ARTWORK", 6)
            f.bg:AddMaskTexture(f.masks[2])
            f.bg:Show()
        end
    else
        if f.bg then GlowTexPool:Release(f.bg); f.bg = nil end
        if f.masks[2] then GlowMaskPool:Release(f.masks[2]); f.masks[2] = nil end
    end
    for i = 1, #f.textures do
        if f.textures[i]:GetNumMaskTextures() < 1 then f.textures[i]:AddMaskTexture(f.masks[1]) end
    end
    f.timer = 0
    f:SetScript("OnUpdate", PixelOnUpdate)
end

function lib.Pixel:Hide(frame, key)
    local nameKey = "_PixelGlow" .. (key or "Default")
    if frame[nameKey] then
        GlowFramePool:Release(frame[nameKey])
        frame[nameKey] = nil
    end
end

-- [ CORE API ] ----------------------------------------------------------------
local GLOW_TYPE_MAP = {
    Thin = function(frame, options)
        options.atlas = options.atlas or THIN_ATLAS
        options.scale = DEFAULT_FLIPBOOK_SCALE
        options.offsetScale = 4
        lib.Flipbook:Show(frame, options)
    end,
    Thick = function(frame, options)
        options.atlas = options.atlas or THICK_ATLAS
        options.scale = DEFAULT_FLIPBOOK_SCALE
        options.offsetScale = 1
        lib.Flipbook:Show(frame, options)
    end,
    Medium = function(frame, options)
        options.atlas = options.atlas or MEDIUM_ATLAS
        options.scale = DEFAULT_FLIPBOOK_SCALE
        options.offsetScale = 1
        lib.Flipbook:Show(frame, options)
    end,
    Static = function(frame, options)
        options.isAtlas = true
        options.texture = options.texture or STATIC_ATLAS
        options.scale = DEFAULT_FLIPBOOK_SCALE
        options.offsetScale = 5
        options.offsetX = 1
        options.offsetY = -1
        lib.Static:Show(frame, options)
    end,
    Autocast = function(frame, options) lib.Autocast:Show(frame, options) end,
    Classic = function(frame, options) lib.Button:Show(frame, options) end,
    Pixel = function(frame, options) lib.Pixel:Show(frame, options) end,
}

local HIDE_TYPE_MAP = {
    Thin = function(frame, key) lib.Flipbook:Hide(frame, key) end,
    Thick = function(frame, key) lib.Flipbook:Hide(frame, key) end,
    Medium = function(frame, key) lib.Flipbook:Hide(frame, key) end,
    Static = function(frame, key) lib.Static:Hide(frame, key) end,
    Autocast = function(frame, key) lib.Autocast:Hide(frame, key) end,
    Classic = function(frame, key) lib.Button:Hide(frame, key) end,
    Pixel = function(frame, key) lib.Pixel:Hide(frame, key) end,
}

local WARMUP_DUMMY_PARENT

function lib.Show(frame, glowType, options)
    local handler = GLOW_TYPE_MAP[glowType]
    if not handler then error(MAJOR_VERSION .. ": Unknown glowType '" .. tostring(glowType) .. "'") end
    handler(frame, options or {})
end

function lib.Hide(frame, glowType, key)
    local handler = HIDE_TYPE_MAP[glowType]
    if not handler then error(MAJOR_VERSION .. ": Unknown glowType '" .. tostring(glowType) .. "'") end
    handler(frame, key)
end

function lib.PreLoad(glowType, count)
    local handler = GLOW_TYPE_MAP[glowType]
    if not handler then error(MAJOR_VERSION .. ": Unknown glowType '" .. tostring(glowType) .. "'") end
    if not WARMUP_DUMMY_PARENT then
        WARMUP_DUMMY_PARENT = CreateFrame("Frame", "LibOrbitGlowWarmupFrame", UIParent)
        WARMUP_DUMMY_PARENT:SetSize(40, 40)
        WARMUP_DUMMY_PARENT:Hide()
    end
    
    local keys = {}
    for i = 1, count do
        local key = "_warmup_" .. i
        tinsert(keys, key)
        handler(WARMUP_DUMMY_PARENT, { key = key })
    end
    for _, key in ipairs(keys) do
        lib.Hide(WARMUP_DUMMY_PARENT, glowType, key)
    end
end
