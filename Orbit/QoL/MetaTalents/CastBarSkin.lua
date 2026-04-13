-- [ METATALENTS / CAST BAR SKIN ]---------------------------------------------------------
-- Replaces the native OverlayPlayerCastingBarFrame (used by "Applying Talents") with a flat
-- 2px gold fill plus a rotating star-spark locked to the TalentsFrame.BottomBar. Blizzard's
-- cast bar asset aggressively resets its own textures on every SetValue, so we re-hide them
-- inside a SetValue hook rather than fighting them once at init. Native interrupt/flash/
-- shake animations are stubbed out via hooksecurefunc(...Play → Stop) because they'd still
-- fire on commit errors and yank the invisible frame on screen.

local _, Orbit = ...
local MT = Orbit.MetaTalents

local CastBarSkin = {}
MT.CastBarSkin = CastBarSkin

local SAFE_TYPE_INFO = { filling = "", full = "", glow = "" }
local FILL_COLOR_R, FILL_COLOR_G, FILL_COLOR_B = 1, 0.82, 0
local SPARK_COLOR_R, SPARK_COLOR_G, SPARK_COLOR_B, SPARK_COLOR_A = 1, 0.85, 0.2, 1

local function HideNativeRegions(bar)
    local regions = { "Border", "Background", "TextBorder", "Flash", "Spark", "EnergyGlow",
                      "ChargeGlow", "BorderShield", "DropShadow", "InterruptGlow" }
    for _, name in ipairs(regions) do
        if bar[name] then bar[name]:SetAlpha(0) end
    end
end

local function KillNativeAnimations(bar)
    local nativeAnims = { "InterruptGlowAnim", "InterruptShakeAnim", "InterruptSparkAnim", "FlashLoopingAnim", "FlashAnim" }
    for _, animName in ipairs(nativeAnims) do
        if bar[animName] then
            hooksecurefunc(bar[animName], "Play", function(self) self:Stop() end)
            bar[animName]:Stop()
        end
    end
end

local function StubNativeMethods(bar)
    bar.GetTypeInfo = function() return SAFE_TYPE_INFO end
    bar.ShowSpark = function() end
    bar.HideSpark = function() end
    bar.PlayFinishAnim = function() end
    bar.PlayFadeAnim = function(self)
        if self.FadeOutAnim and self:GetAlpha() > 0 and self:IsVisible() and not self.isInEditMode then
            self.FadeOutAnim:Play()
        end
    end
    bar.PlayInterruptAnims = function() end
    bar.StopFinishAnims = function(self)
        if self.FlashAnim then self.FlashAnim:Stop() end
        if self.FadeOutAnim then self.FadeOutAnim:Stop() end
        if self.StandardFinish then self.StandardFinish:Stop() end
        if self.ChannelFinish then self.ChannelFinish:Stop() end
        if self.StageFinish then self.StageFinish:Stop() end
        if self.CraftingFinish then self.CraftingFinish:Stop() end
    end
    bar.StopAnims = function(self)
        self:StopInterruptAnims()
        self:StopFinishAnims()
    end
end

local function CreateFillAndSpark(bar, host)
    if host.BottomBar then
        host.BottomBar:SetDrawLayer("BORDER", 7)
    end

    local fill = host:CreateTexture(nil, "BORDER", nil, 5)
    fill:SetColorTexture(FILL_COLOR_R, FILL_COLOR_G, FILL_COLOR_B, 1)
    fill:SetPoint("LEFT", host.BottomBar, "TOPLEFT", 0, 1)
    fill:SetHeight(2)
    fill:Hide()
    bar._orbitFill = fill

    local spark = host:CreateTexture(nil, "BORDER", nil, 6)
    spark:SetTexture("Interface\\Cooldown\\star4")
    spark:SetBlendMode("ADD")
    spark:SetSize(35, 35)
    spark:SetVertexColor(SPARK_COLOR_R, SPARK_COLOR_G, SPARK_COLOR_B, SPARK_COLOR_A)
    spark:Hide()

    local animGroup = spark:CreateAnimationGroup()
    local rot = animGroup:CreateAnimation("Rotation")
    rot:SetDegrees(-360)
    rot:SetDuration(1.5)
    animGroup:SetLooping("REPEAT")

    bar._orbitSparkGlow = spark
    bar._orbitAnimGroup = animGroup
end

local function WireVisibilityAndText(bar, spark)
    bar:HookScript("OnShow", function(self)
        if self._orbitFill then self._orbitFill:Show() end
        if self._orbitSparkGlow then self._orbitSparkGlow:Show() end
        if self._orbitAnimGroup then self._orbitAnimGroup:Play() end
    end)
    bar:HookScript("OnHide", function(self)
        if self._orbitFill then self._orbitFill:Hide() end
        if self._orbitSparkGlow then self._orbitSparkGlow:Hide() end
    end)
    if bar.Text then
        local fontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font or "Fonts\\FRIZQT__.TTF"
        bar.Text:SetFont(fontName, 12, "OUTLINE")
        bar.Text:ClearAllPoints()
        bar.Text:SetPoint("BOTTOM", spark, "TOP", 0, -46)
    end
end

local function HookSetValue(bar, host)
    hooksecurefunc(bar, "SetValue", function(self, value)
        local minV, maxV = self:GetMinMaxValues()
        if not minV or not maxV or maxV == 0 then return end

        local tex = self:GetStatusBarTexture()
        if tex then tex:SetAlpha(0) end
        if self.Spark then self.Spark:SetAlpha(0) end
        if self.Flash then self.Flash:SetAlpha(0) end
        if self.Border then self.Border:SetAlpha(0) end

        local progress = (value - minV) / (maxV - minV)
        local width = host.BottomBar:GetWidth()
        local offset = progress * width

        self._orbitFill:SetWidth(math.max(0.001, offset))
        self._orbitSparkGlow:ClearAllPoints()
        self._orbitSparkGlow:SetPoint("CENTER", host.BottomBar, "TOPLEFT", offset, 1)
    end)
end

function CastBarSkin.Apply()
    local bar = OverlayPlayerCastingBarFrame
    if not bar or bar._orbitSkinReskinned then return end
    bar._orbitSkinReskinned = true

    bar:SetStatusBarTexture("")
    HideNativeRegions(bar)
    KillNativeAnimations(bar)
    StubNativeMethods(bar)

    local host = PlayerSpellsFrame.TalentsFrame
    CreateFillAndSpark(bar, host)
    WireVisibilityAndText(bar, bar._orbitSparkGlow)
    HookSetValue(bar, host)

    hooksecurefunc(PlayerSpellsFrame.TalentsFrame, "SetCommitCastBarActive", function() end)
    hooksecurefunc(PlayerSpellsFrame.TalentsFrame, "SetCommitVisualsActive", function(self)
        if self.FxModelScene then self.FxModelScene:ClearEffects() end
    end)
end
