-- [ UNIT BUTTON - PORTRAIT MODULE ]-----------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

-- [ CONSTANTS ]-------------------------------------------------------------------------------------
local PORTRAIT_DEFAULT_SIZE = 32
local PORTRAIT_LEVEL_OFFSET = 15
local PORTRAIT_RING_OVERSHOOT = Engine.PORTRAIT_RING_OVERSHOOT
local PORTRAIT_3D_MIRROR_FACING = -1.05
local PORTRAIT_3D_MIRROR_OFFSET = 0.3
local PORTRAIT_3D_MIRROR_VERT = -0.05
local PORTRAIT_3D_MIRROR_ZOOM = 0.85
local PORTRAIT_RING_DATA = Engine.PortraitRingData
local PORTRAIT_RING_OPTIONS = Engine.PortraitRingOptions

Engine.UnitButton = Engine.UnitButton or {}
local UnitButton = Engine.UnitButton

-- [ PORTRAIT MIXIN ]--------------------------------------------------------------------------------

local PortraitMixin = {}

function PortraitMixin:CreatePortrait()
    if self.Portrait then return end

    local container = CreateFrame("Frame", nil, self.OverlayFrame or self)
    container:SetSize(PORTRAIT_DEFAULT_SIZE, PORTRAIT_DEFAULT_SIZE)
    container:SetPoint("RIGHT", self, "LEFT", -4, 0)
    container:SetFrameLevel(self:GetFrameLevel() + PORTRAIT_LEVEL_OFFSET)

    container.StaticTexture = container:CreateTexture(nil, "ARTWORK")
    container.StaticTexture:SetAllPoints()
    container.orbitOriginalWidth = PORTRAIT_DEFAULT_SIZE
    container.orbitOriginalHeight = PORTRAIT_DEFAULT_SIZE

    container.bg = container:CreateTexture(nil, "BACKGROUND")
    container.bg:SetAllPoints()

    container.Ring = container:CreateTexture(nil, "OVERLAY")
    container.Ring:SetPoint("TOPLEFT", -PORTRAIT_RING_OVERSHOOT, PORTRAIT_RING_OVERSHOOT)
    container.Ring:SetPoint("BOTTOMRIGHT", PORTRAIT_RING_OVERSHOOT, -PORTRAIT_RING_OVERSHOOT)
    container.Ring:SetAtlas("hud-PlayerFrame-portraitring-large")
    container.Ring:Hide()

    self.Portrait = container

    local parentFrame = self
    local ALPHA_THRESHOLD = 0.01
    hooksecurefunc(parentFrame, "SetAlpha", function(_, alpha)
        if alpha and alpha < ALPHA_THRESHOLD then
            if container:IsShown() then
                container.orbitAlphaHidden = true
                container:Hide()
            end
        elseif container.orbitAlphaHidden then
            container.orbitAlphaHidden = nil
            container:SetAlpha(alpha)
            container:Show()
        elseif container:IsShown() then
            container:SetAlpha(alpha)
        end
    end)
end

function PortraitMixin:UpdatePortrait()
    local portrait = self.Portrait
    if not portrait then return end

    local plugin = self.orbitPlugin
    if not plugin then return end
    local systemIndex = self.systemIndex or 1

    if plugin.IsComponentDisabled and plugin:IsComponentDisabled("Portrait") then
        portrait:Hide()
        return
    end

    if self.orbitMountedSuppressed then
        if portrait.Model then portrait.Model:ClearModel() end
        portrait:Hide()
        return
    end

    local unit = self.unit
    if not unit or not UnitExists(unit) then
        portrait:Hide()
        return
    end

    local parentAlpha = self:GetAlpha()
    if parentAlpha < 0.01 then
        portrait:Hide()
        return
    end

    local scale = (plugin:GetSetting(systemIndex, "PortraitScale") or 120) / 100
    local style = plugin:GetSetting(systemIndex, "PortraitStyle") or "3d"
    local mirror = plugin:GetSetting(systemIndex, "PortraitMirror") or false
    local ringAtlas = plugin:GetSetting(systemIndex, "PortraitRing") or "none"

    local size = PORTRAIT_DEFAULT_SIZE * scale
    local ringData = PORTRAIT_RING_DATA[ringAtlas]
    local ringOS = ((ringData and ringData.overshoot) or PORTRAIT_RING_OVERSHOOT) * scale
    portrait:SetSize(size, size)
    portrait.Ring:ClearAllPoints()
    portrait.Ring:SetPoint("TOPLEFT", -ringOS, ringOS)
    portrait.Ring:SetPoint("BOTTOMRIGHT", ringOS, -ringOS)

    self:ApplyPortraitContent(style, unit, mirror)
    self:ApplyPortraitRing(style, ringAtlas)
    self:ApplyPortraitBackdrop(style)

    if style == "3d" then
        local showBorder = plugin:GetSetting(systemIndex, "PortraitBorder")
        if showBorder == nil then showBorder = true end
        local borderSize = showBorder and (Orbit.db.GlobalSettings.BorderSize or 0) or 0
        Orbit.Skin:SkinBorder(portrait, portrait, borderSize)
    else
        Orbit.Skin:SkinBorder(portrait, portrait, 0)
    end

    portrait:SetAlpha(parentAlpha)
    portrait:Show()
end

function PortraitMixin:ApplyPortraitContent(style, unit, mirror)
    local portrait = self.Portrait
    if not portrait.Model then
        portrait.Model = CreateFrame("PlayerModel", nil, portrait)
        portrait.Model:SetAllPoints()
    end
    if style == "3d" then
        portrait.StaticTexture:Hide()
        portrait.Model:Show()
        portrait.Model:SetUnit(unit)
        portrait.Model:SetPortraitZoom(mirror and PORTRAIT_3D_MIRROR_ZOOM or 1)
        portrait.Model:SetFacing(mirror and PORTRAIT_3D_MIRROR_FACING or 0)
        portrait.Model:SetPosition(mirror and PORTRAIT_3D_MIRROR_OFFSET or 0, 0, mirror and PORTRAIT_3D_MIRROR_VERT or 0)
    else
        portrait.Model:Hide()
        portrait.StaticTexture:Show()
        SetPortraitTexture(portrait.StaticTexture, unit)
        if mirror then
            portrait.StaticTexture:SetTexCoord(1, 0, 0, 1)
        else
            portrait.StaticTexture:SetTexCoord(0, 1, 0, 1)
        end
    end
end



function PortraitMixin:ApplyPortraitRing(style, ringKey)
    local portrait = self.Portrait
    local data = PORTRAIT_RING_DATA[ringKey]
    if style ~= "2d" or not data or not data.atlas then
        portrait.Ring:Hide()
        portrait:SetScript("OnUpdate", nil)
        return
    end
    portrait.Ring:Show()
    if data.rows then
        local info = C_Texture.GetAtlasInfo(data.atlas)
        if not info then portrait.Ring:Hide(); return end
        portrait.Ring:SetTexture(info.file)
        local aL, aR = info.leftTexCoord, info.rightTexCoord
        local aT, aB = info.topTexCoord, info.bottomTexCoord
        local cellW, cellH = (aR - aL) / data.cols, (aB - aT) / data.rows
        local frameTime = data.duration / data.frames
        portrait._flipCurrent = 0
        portrait._flipElapsed = 0
        local function SetFrame(idx)
            local col = idx % data.cols
            local row = math.floor(idx / data.cols)
            portrait.Ring:SetTexCoord(aL + col * cellW, aL + (col + 1) * cellW, aT + row * cellH, aT + (row + 1) * cellH)
        end
        SetFrame(0)
        portrait:SetScript("OnUpdate", function(_, elapsed)
            portrait._flipElapsed = portrait._flipElapsed + elapsed
            if portrait._flipElapsed >= frameTime then
                portrait._flipElapsed = portrait._flipElapsed - frameTime
                portrait._flipCurrent = (portrait._flipCurrent + 1) % data.frames
                SetFrame(portrait._flipCurrent)
            end
        end)
    else
        portrait.Ring:SetTexCoord(0, 1, 0, 1)
        portrait.Ring:SetAtlas(data.atlas)
        portrait:SetScript("OnUpdate", nil)
    end
end

function PortraitMixin:ApplyPortraitBackdrop(style)
    local portrait = self.Portrait
    if not portrait or not portrait.bg then return end
    if style == "2d" then
        portrait.bg:Hide()
        return
    end
    portrait.bg:Show()
    local globalSettings = Orbit.db.GlobalSettings or {}
    Orbit.Skin:ApplyGradientBackground(portrait, globalSettings.UnitFrameBackdropColourCurve, Orbit.Constants.Colors.Background)
end

UnitButton.PortraitMixin = PortraitMixin
