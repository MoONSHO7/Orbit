local MAJOR_VERSION = "LibOrbitGlow-1.0"
local MINOR_VERSION = 2
local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local GlowParent = UIParent

-- [ UTILITIES ] ---------------------------------------------------------------
local function GetColorRGBA(colorTable)
    if not colorTable then return 1, 1, 1, 1 end
    if type(colorTable) == "table" and colorTable.GetRGBA then
        return colorTable:GetRGBA()
    elseif colorTable.r then
        return colorTable.r, colorTable.g, colorTable.b, colorTable.a or 1
    else
        return colorTable[1] or 1, colorTable[2] or 1, colorTable[3] or 1, colorTable[4] or 1
    end
end

local function Snap(val, scale)
    if _G.Orbit and _G.Orbit.Engine and _G.Orbit.Engine.Pixel then
        return _G.Orbit.Engine.Pixel:Snap(val, scale or 1)
    end
    return math.floor(val + 0.5)
end

-- [ POOLS ] -------------------------------------------------------------------
local GlowMaskPool = {
    activeObjects = {}, inactiveObjects = {}, activeObjectCount = 0,
    createFunc = function(self) return GlowParent:CreateMaskTexture() end,
    resetFunc = function(self, mask) mask:Hide(); mask:ClearAllPoints() end,
    Release = function(self, object)
        local active = self.activeObjects[object] ~= nil
        if active then
            self:resetFunc(object)
            tinsert(self.inactiveObjects, object)
            self.activeObjects[object] = nil
            self.activeObjectCount = self.activeObjectCount - 1
        end
        return active
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
    local maskNum = tex:GetNumMaskTextures()
    for i = maskNum , 1, -1 do tex:RemoveMaskTexture(tex:GetMaskTexture(i)) end
    tex:Hide()
    tex:ClearAllPoints()
end
local GlowTexPool = CreateTexturePool(GlowParent, "ARTWORK", 7, nil, TexPoolResetter)

local function FramePoolResetter(framePool, frame)
    frame:SetScript("OnUpdate", nil)
    if frame.animIn and frame.animIn:IsPlaying() then frame.animIn:Stop() end
    if frame.animOut and frame.animOut:IsPlaying() then frame.animOut:Stop() end
    if frame.animGroup and frame.animGroup:IsPlaying() then frame.animGroup:Stop() end
    
    local parent = frame:GetParent()
    if frame.name and parent and parent[frame.name] then parent[frame.name] = nil end
    
    if frame.textures then
        for _, texture in pairs(frame.textures) do GlowTexPool:Release(texture) end
        table.wipe(frame.textures)
    end
    if frame.bg then GlowTexPool:Release(frame.bg); frame.bg = nil end
    if frame.masks then
        for _, mask in pairs(frame.masks) do GlowMaskPool:Release(mask) end
        table.wipe(frame.masks)
    end
    if frame.info then table.wipe(frame.info) end
    frame.name = nil
    frame.timer = nil
    frame:Hide()
    frame:ClearAllPoints()
end
local GlowFramePool = CreateFramePool("Frame", GlowParent, nil, FramePoolResetter)

-- [ CORE INITIALIZER ] --------------------------------------------------------
local function AcquireFrameAndTex(parent, nameKey, N, texture, texCoord, isDesaturated, frameLevel, r, g, b, a, blendMode)
    frameLevel = frameLevel or 8
    if not parent[nameKey] then
        parent[nameKey] = GlowFramePool:Acquire()
        parent[nameKey]:SetParent(parent)
        parent[nameKey].name = nameKey
    end
    local f = parent[nameKey]
    f:SetFrameLevel(parent:GetFrameLevel() + frameLevel)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0.05, 0.05)
    f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -0.05, -0.05)
    f:Show()
    local texObj = parent.icon or parent.Icon
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
function lib.Flipbook:Show(frame, options)
    options = options or {}
    local r, g, b, a = GetColorRGBA(options.color)
    local nameKey = "_LibGlowFlipbook" .. (options.key or "Default")
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
    rows = rows or 6
    cols = cols or 5
    frames = frames or (rows * cols)
    
    local N = options.N or 1
    local blendMode = options.blendMode or "BLEND"
    local f = AcquireFrameAndTex(frame, nameKey, N, nil, nil, true, options.frameLevel, r, g, b, a, blendMode, options.maskIcon, options.maskInset, options.clampGlow)
    f:ClearAllPoints()
    local scale = options.scale or 1.4
    local offsetScale = options.offsetScale or 0
    local padX = (options.padding or 0) + offsetScale + (frame:GetWidth() * (scale - 1) / 2)
    local padY = (options.padding or 0) + offsetScale + (frame:GetHeight() * (scale - 1) / 2)
    local shiftX = options.offsetX or 0
    local shiftY = options.offsetY or 0
    f:SetPoint("TOPLEFT", frame, "TOPLEFT", -padX + shiftX, padY + shiftY)
    f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", padX + shiftX, -padY + shiftY)
    
    for i = 1, N do
        local tex = f.textures[i]
        -- Clear any old manual texcoords returning from pool
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
        f:SetScript("OnUpdate", function(self, el)
            self.elapsed = self.elapsed + el
            local progress = (self.elapsed / self.flipData.dur) % 1
            local frameIndex = math.floor((1 - progress) * self.flipData.f) % self.flipData.f
            for i = 1, #(self.textures) do
                UpdateFlipbookTexture(self.textures[i], frameIndex, self.flipData.r, self.flipData.c)
            end
        end)
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
            
            texLoop.animGroup:Play()
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
    local N = options.N or 1
    local blendMode = options.blendMode or "BLEND"
    local f = AcquireFrameAndTex(frame, nameKey, N, nil, nil, true, options.frameLevel, r, g, b, a, blendMode, options.maskIcon, options.maskInset, options.clampGlow)
    f:ClearAllPoints()
    local scale = options.scale or 1.4
    local offsetScale = options.offsetScale or 0
    local padX = (options.padding or 0) + offsetScale + (frame:GetWidth() * (scale - 1) / 2)
    local padY = (options.padding or 0) + offsetScale + (frame:GetHeight() * (scale - 1) / 2)
    local shiftX = options.offsetX or 0
    local shiftY = options.offsetY or 0
    f:SetPoint("TOPLEFT", frame, "TOPLEFT", -padX + shiftX, padY + shiftY)
    f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", padX + shiftX, -padY + shiftY)
    
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
local function acUpdate(self, elapsed)
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
        self.timer[k] = self.timer[k] + (elapsed / (self.info.period * k)) * dir
        if self.timer[k] > 1 or self.timer[k] < -1 then
            self.timer[k] = self.timer[k] % 1
        end
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
    local N = options.particles or 4
    local period = options.frequency and (options.frequency ~= 0 and 1/math.abs(options.frequency) or 8) or 8
    local scale = options.scale or 1
    local xOffset = options.xOffset or 0
    local yOffset = options.yOffset or 0
    local key = options.key or "Default"
    
    local nameKey = "_LibGlowAutocast" .. key
    local texture = "Interface\\Artifacts\\Artifacts"
    local texCoord = {0.8115234375,0.9169921875,0.8798828125,0.9853515625}

    local f = AcquireFrameAndTex(frame, nameKey, N * 4, texture, texCoord, nil, options.frameLevel, r, g, b, a, options.blendMode or "ADD", options.maskIcon, options.maskInset, options.clampGlow)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", frame, "TOPLEFT", -xOffset, yOffset)
    f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", xOffset, -yOffset)
    
    local sizes = {7, 6, 5, 4}
    for k, size in pairs(sizes) do
        for i = 1, N do
            f.textures[i + N * (k - 1)]:SetSize(size * scale, size * scale)
        end
    end
    
    f.timer = f.timer or {0, 0, 0, 0}
    f.info = f.info or {}
    f.info.N = N
    f.info.period = period
    f.info.direction = options.reverse and -1 or 1
    
    f:SetScript("OnUpdate", acUpdate)
    acUpdate(f, 0)
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

local BUTTON_GLOW_TEXTURES = {["spark"]=true, ["innerGlow"]=true, ["innerGlowOver"]=true, ["outerGlow"]=true, ["outerGlowOver"]=true, ["ants"]=true}

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
    if appear then table.insert(group.appear, alpha) else table.insert(group.fade, alpha) end
end

local function AnimIn_OnPlay(group)
    local frame = group:GetParent()
    local w, h = frame:GetSize()
    frame.spark:SetSize(w, h)
    frame.spark:SetAlpha(not(frame.color) and 1.0 or 0.3*(frame.color[4] or 1))
    frame.innerGlow:SetSize(w / 2, h / 2)
    frame.innerGlow:SetAlpha(not(frame.color) and 1.0 or (frame.color[4] or 1))
    frame.innerGlowOver:SetAlpha(not(frame.color) and 1.0 or (frame.color[4] or 1))
    frame.outerGlow:SetSize(w * 2, h * 2)
    frame.outerGlow:SetAlpha(not(frame.color) and 1.0 or (frame.color[4] or 1))
    frame.outerGlowOver:SetAlpha(not(frame.color) and 1.0 or (frame.color[4] or 1))
    frame.ants:SetSize(w * 0.85, h * 0.85)
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

local function updateAlphaAnim(f, alpha)
    for _, anim in pairs(f.animIn.appear) do anim:SetToAlpha(alpha) end
    for _, anim in pairs(f.animIn.fade) do anim:SetFromAlpha(alpha) end
    for _, anim in pairs(f.animOut.appear) do anim:SetToAlpha(alpha) end
    for _, anim in pairs(f.animOut.fade) do anim:SetFromAlpha(alpha) end
end

local function configureButtonGlow(f, alpha)
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

local ButtonGlowPool = CreateFramePool("Frame", GlowParent, nil, function(pool, frame)
    frame:SetScript("OnUpdate", nil)
    local parent = frame:GetParent()
    if parent._LibGlowButton then
        parent._LibGlowButton = nil
    end
    frame:Hide()
    frame:ClearAllPoints()
end)

function lib.Button:Show(frame, options)
    options = options or {}
    local r, g, b, a = GetColorRGBA(options.color)
    local freq = options.frequency or 0.25
    local throttle = (freq and freq > 0) and (0.25 / freq * 0.01) or 0.01
    
    if frame._LibGlowButton then
        local f = frame._LibGlowButton
        local w, h = frame:GetSize()
        f:SetFrameLevel(frame:GetFrameLevel() + (options.frameLevel or 8))
        f:SetSize(w * 1.4, h * 1.4)
        f:SetPoint("TOPLEFT", frame, "TOPLEFT", -w * 0.2, h * 0.2)
        f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", w * 0.2, -h * 0.2)
        f.ants:SetSize(w * 1.4 * 0.85, h * 1.4 * 0.85)
        
        if options.reverse then
            f.reverseElapsed = 0
            f.frameIndex = 22
            f:SetScript("OnUpdate", function(self, elapsed)
                self.reverseElapsed = self.reverseElapsed + elapsed
                if self.reverseElapsed >= self.throttle then
                    self.frameIndex = self.frameIndex - 1
                    if self.frameIndex < 1 then self.frameIndex = 22 end
                    self.reverseElapsed = self.reverseElapsed - self.throttle
                    
                    local currentFrame = self.frameIndex - 1
                    local col = currentFrame % 5
                    local row = math.floor(currentFrame / 5)
                    local frameW = 48 / 256
                    local frameH = 48 / 256
                    self.ants:SetTexCoord(col * frameW, (col + 1) * frameW, row * frameH, (row + 1) * frameH)
                end
            end)
        else
            f:SetScript("OnUpdate", function(self, elapsed)
                AnimateTexCoords(self.ants, 256, 256, 48, 48, 22, elapsed, self.throttle)
            end)
        end
        
        AnimIn_OnFinished(f.animIn)
        if f.animOut:IsPlaying() then
            f.animOut:Stop()
            f.animIn:Play()
        end
        f.color = {r, g, b, a}
        for texName in pairs(BUTTON_GLOW_TEXTURES) do
            f[texName]:SetDesaturated(1)
            f[texName]:SetVertexColor(r, g, b)
            local currentAlpha = f[texName]:GetAlpha()
            local rawAlpha = f.color[4] and (f.color[4] == 0 and 0.001 or f.color[4]) or 1
            f[texName]:SetAlpha(math.min(currentAlpha / rawAlpha * a, 1))
            updateAlphaAnim(f, a)
        end
        f.throttle = throttle
    else
        local f, new = ButtonGlowPool:Acquire()
        if new then
            configureButtonGlow(f, a)
            f.animOut:SetScript("OnFinished", function(self) ButtonGlowPool:Release(self:GetParent()) end)
            f:SetScript("OnHide", function(self)
                if self.animOut:IsPlaying() then
                    self.animOut:Stop()
                    ButtonGlowPool:Release(self)
                end
            end)
        else
            updateAlphaAnim(f, a)
        end
        
        frame._LibGlowButton = f
        local w, h = frame:GetSize()
        f:SetParent(frame)
        f:SetFrameLevel(frame:GetFrameLevel() + (options.frameLevel or 8))
        f:SetSize(w * 1.4, h * 1.4)
        f:SetPoint("TOPLEFT", frame, "TOPLEFT", -w * 0.2, h * 0.2)
        f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", w * 0.2, -h * 0.2)
        
        f.color = {r, g, b, a}
        for texName in pairs(BUTTON_GLOW_TEXTURES) do
            f[texName]:SetDesaturated(1)
            f[texName]:SetVertexColor(r, g, b)
        end
        
        f.throttle = throttle
        if options.reverse then
            f.reverseElapsed = 0
            f.frameIndex = 22
            f:SetScript("OnUpdate", function(self, elapsed)
                self.reverseElapsed = self.reverseElapsed + elapsed
                if self.reverseElapsed >= self.throttle then
                    self.frameIndex = self.frameIndex - 1
                    if self.frameIndex < 1 then self.frameIndex = 22 end
                    self.reverseElapsed = self.reverseElapsed - self.throttle
                    
                    local currentFrame = self.frameIndex - 1
                    local col = currentFrame % 5
                    local row = math.floor(currentFrame / 5)
                    local frameW = 48 / 256
                    local frameH = 48 / 256
                    self.ants:SetTexCoord(col * frameW, (col + 1) * frameW, row * frameH, (row + 1) * frameH)
                end
            end)
        else
            f:SetScript("OnUpdate", function(self, elapsed)
                AnimateTexCoords(self.ants, 256, 256, 48, 48, 22, elapsed, self.throttle)
            end)
        end
        f.animIn:Play()
    end
end

function lib.Button:Hide(frame)
    if frame._LibGlowButton then
        if frame._LibGlowButton.animIn:IsPlaying() then
            frame._LibGlowButton.animIn:Stop()
            ButtonGlowPool:Release(frame._LibGlowButton)
        elseif frame:IsVisible() then
            frame._LibGlowButton.animOut:Play()
        else
            ButtonGlowPool:Release(frame._LibGlowButton)
        end
    end
end

-- [ PIXEL AND OTHERS ] --------------------------------------------------------
lib.Pixel = {}
function lib.Pixel:Show(frame, options)
    options = options or {}
    local r, g, b, a = GetColorRGBA(options.color)
    local N = options.lines or 8
    local period = options.frequency and (options.frequency > 0 and 0.25 / options.frequency or 4) or 4
    local th = options.thickness or 2
    local xOffset = options.xOffset or 0
    local yOffset = options.yOffset or 0
    local key = options.key or "Default"
    
    local w, h = frame:GetSize()
    local length = options.length or math.floor((w+h)*(2/N-0.1) * 3)
    
    local nameKey = "_PixelGlow" .. key
    local f = AcquireFrameAndTex(frame, nameKey, N, "Interface\\BUTTONS\\WHITE8X8", {0, 1, 0, 1}, nil, options.frameLevel, r, g, b, a, nil)
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
        f.masks[2]:SetPoint("TOPLEFT", f, "TOPLEFT", th+1, -th-1)
        f.masks[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -th-1, th+1)
        
        if not f.bg then
            f.bg = GlowTexPool:Acquire()
            f.bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)
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
    
    for _, tex in pairs(f.textures) do
        if tex:GetNumMaskTextures() < 1 then tex:AddMaskTexture(f.masks[1]) end
    end

    local function pCalc1(progress, s, th, p, scale)
        if progress > p[3] or progress < p[0] then return 0 end
        if progress > p[2] then return Snap(s - th - (progress - p[2]) / (p[3] - p[2]) * (s - th), scale) end
        if progress > p[1] then return Snap(s - th, scale) end
        return Snap((progress - p[0]) / (p[1] - p[0]) * (s - th), scale)
    end
    local function pCalc2(progress, s, th, p, scale)
        if progress > p[3] then return Snap(s - th - (progress - p[3]) / (p[0] + 1 - p[3]) * (s - th), scale) end
        if progress > p[2] then return Snap(s - th, scale) end
        if progress > p[1] then return Snap((progress - p[1]) / (p[2] - p[1]) * (s - th), scale) end
        if progress > p[0] then return 0 end
        return Snap(s - th - (progress + 1 - p[3]) / (p[0] + 1 - p[3]) * (s - th), scale)
    end

    f.timer = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self.timer = (self.timer + (elapsed / self.info.period) * self.info.direction) % 1
        local w_cur, h_cur = self:GetSize()
        if w_cur ~= self.info.width or h_cur ~= self.info.height then
            local perim = 2 * (w_cur + h_cur)
            if perim <= 0 then return end
            self.info.width, self.info.height = w_cur, h_cur
            local lenHalf = self.info.length / 2
            self.info.pTLx = { [0] = (h_cur + lenHalf)/perim, [1] = (h_cur + w_cur + lenHalf)/perim, [2] = (2*h_cur + w_cur - lenHalf)/perim, [3] = 1 - lenHalf/perim }
            self.info.pTLy = { [0] = (h_cur - lenHalf)/perim, [1] = (h_cur + w_cur + lenHalf)/perim, [2] = (2*h_cur + w_cur + lenHalf)/perim, [3] = 1 - lenHalf/perim }
            self.info.pBRx = { [0] = lenHalf/perim, [1] = (h_cur - lenHalf)/perim, [2] = (h_cur + w_cur - lenHalf)/perim, [3] = (2*h_cur + w_cur + lenHalf)/perim }
            self.info.pBRy = { [0] = lenHalf/perim, [1] = (h_cur + lenHalf)/perim, [2] = (h_cur + w_cur - lenHalf)/perim, [3] = (2*h_cur + w_cur - lenHalf)/perim }
        end
        local effScale = self:GetEffectiveScale()
        for k, line in ipairs(self.textures) do
            local p = (self.timer + self.info.step * (k - 1)) % 1
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", self, "TOPLEFT", pCalc1(p, w_cur, self.info.th, self.info.pTLx, effScale), -pCalc2(p, h_cur, self.info.th, self.info.pTLy, effScale))
            line:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", self.info.th + pCalc2(p, w_cur, self.info.th, self.info.pBRx, effScale), -h_cur + pCalc1(p, h_cur, self.info.th, self.info.pBRy, effScale))
        end
    end)
end
function lib.Pixel:Hide(frame, key)
    local nameKey = "_PixelGlow" .. (key or "Default")
    if frame[nameKey] then
        GlowFramePool:Release(frame[nameKey])
        frame[nameKey] = nil
    end
end

-- [ CORE API ] ----------------------------------------------------------------
function lib.Show(frame, glowType, options)
    options = options or {}
    if glowType == "Thin" then
        options.atlas = options.atlas or "RotationHelper_Ants_Flipbook_2x"
        options.scale = 1.4
        options.offsetScale = 4
        lib.Flipbook:Show(frame, options)
    elseif glowType == "Thick" then
        options.atlas = options.atlas or "RotationHelper-ProcLoopBlue-Flipbook-2x"
        options.scale = 1.4
        options.offsetScale = 1
        lib.Flipbook:Show(frame, options)
    elseif glowType == "Medium" then
        options.atlas = options.atlas or "UI-HUD-ActionBar-Proc-Loop-Flipbook"
        options.scale = 1.4
        options.offsetScale = 1
        lib.Flipbook:Show(frame, options)
    elseif glowType == "Static" then
        options.isAtlas = true
        options.texture = options.texture or "UI-CooldownManager-ActiveGlow"
        options.scale = 1.4
        options.offsetScale = 5
        options.offsetX = 1
        options.offsetY = -1
        lib.Static:Show(frame, options)
    elseif glowType == "Autocast" then
        lib.Autocast:Show(frame, options)
    elseif glowType == "Classic" then
        lib.Button:Show(frame, options)
    elseif glowType == "Pixel" then
        lib.Pixel:Show(frame, options)
    end
end

function lib.Hide(frame, glowType, key)
    if glowType == "Thin" or glowType == "Thick" or glowType == "Medium" then
        lib.Flipbook:Hide(frame, key)
    elseif glowType == "Static" then
        lib.Static:Hide(frame, key)
    elseif glowType == "Autocast" then
        lib.Autocast:Hide(frame, key)
    elseif glowType == "Classic" then
        lib.Button:Hide(frame)
    elseif glowType == "Pixel" then
        lib.Pixel:Hide(frame, key)
    end
end

-- [ GLOBALS ] -----------------------------------------------------------------
_G.LibOrbitGlow = lib
