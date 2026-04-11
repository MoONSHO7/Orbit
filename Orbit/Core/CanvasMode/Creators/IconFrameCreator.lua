-- [ CANVAS MODE - ICON FRAME CREATOR ]--------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local CC = CanvasMode.CreatorConstants
local GetSourceSize = CanvasMode.GetSourceSize

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local ZOOM_BUTTON_GAP = 2
local ZOOM_IN_W, ZOOM_IN_H = 17, 17
local ZOOM_OUT_W, ZOOM_OUT_H = 17, 9
local FLIPBOOK_ROWS_DEFAULT = 7
local FLIPBOOK_COLS_DEFAULT = 6
local FLIPBOOK_DURATION_DEFAULT = 1.5

local function GetActiveDifficultyFrame(source)
    if source.ChallengeMode and source.ChallengeMode:IsShown() then return source.ChallengeMode end
    if source.Guild and source.Guild:IsShown() then return source.Guild end
    return source.Default
end

local function CopyDifficultyTexture(texture, source, alphaOverride)
    local atlas = source.GetAtlas and source:GetAtlas()
    if atlas then
        local info = C_Texture.GetAtlasInfo(atlas)
        if info and info.file then
            texture:SetTexture(info.file)
            texture:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
        else
            texture:SetAtlas(atlas, false)
        end
    else
        texture:SetTexture(source:GetTexture())
        texture:SetTexCoord(source:GetTexCoord())
    end
    texture:SetVertexColor(source:GetVertexColor())
    texture:SetBlendMode(source:GetBlendMode())
    texture:SetAlpha(alphaOverride or source:GetAlpha() or 1)
    if texture.SetDesaturated and source.IsDesaturated then texture:SetDesaturated(source:IsDesaturated()) end
end

-- [ CREATOR ]---------------------------------------------------------------------------------------
local function Create(container, preview, key, source, data)
    local iconTexture = source.Icon
    local hasFlipbook = iconTexture and iconTexture.orbitPreviewTexCoord
    local visual

    -- Zoom component: render stacked zoom-in / zoom-out icons matching Blizzard's real proportions
    if key == "Zoom" then
        local overrides = data and data.overrides
        local savedSize = overrides and overrides.IconSize
        -- Scale both buttons proportionally if IconSize override is set (based on width)
        local scale = (savedSize and savedSize > 0) and (savedSize / ZOOM_IN_W) or 1
        local inW = math.floor(ZOOM_IN_W * scale + 0.5)
        local inH = math.floor(ZOOM_IN_H * scale + 0.5)
        local outW = math.floor(ZOOM_OUT_W * scale + 0.5)
        local outH = math.floor(ZOOM_OUT_H * scale + 0.5)
        local totalH = inH + ZOOM_BUTTON_GAP + outH

        container:SetSize(inW, totalH)

        local zoomInTex = container:CreateTexture(nil, "ARTWORK")
        zoomInTex:SetSize(inW, inH)
        zoomInTex:SetPoint("TOP", container, "TOP", 0, 0)
        zoomInTex:SetAtlas("ui-hud-minimap-zoom-in", false)

        local zoomOutTex = container:CreateTexture(nil, "ARTWORK")
        zoomOutTex:SetSize(outW, outH)
        zoomOutTex:SetPoint("TOP", zoomInTex, "BOTTOM", 0, -ZOOM_BUTTON_GAP)
        zoomOutTex:SetAtlas("ui-hud-minimap-zoom-out", false)

        container.UpdateZoomSize = function(self, newSize)
            local s = (newSize and newSize > 0) and (newSize / ZOOM_IN_W) or 1
            local w = math.floor(ZOOM_IN_W * s + 0.5)
            local hin = math.floor(ZOOM_IN_H * s + 0.5)
            local wout = math.floor(ZOOM_OUT_W * s + 0.5)
            local hout = math.floor(ZOOM_OUT_H * s + 0.5)
            self:SetSize(w, hin + ZOOM_BUTTON_GAP + hout)
            zoomInTex:SetSize(w, hin)
            zoomOutTex:SetSize(wout, hout)
        end

        container.isIconFrame = true
        container.skipIconSkin = true
        return container
    elseif key == "DifficultyIcon" then
        container.skipIconSkin = true
        container.isIconFrame = true
        container.skipSourceSizeRestore = true

        container.iconVisual = CreateFrame("Frame", nil, container)
        local baseWidth, baseHeight = GetSourceSize(source, 16, 16)
        local activeFrame = GetActiveDifficultyFrame(source)
        container.iconVisual:SetSize(baseWidth, baseHeight)
        container.iconVisual:SetPoint("CENTER", container, "CENTER", 0, 0)

        local function Attach(region, alphaOverride)
            if not region or region:GetObjectType() ~= "Texture" then return end
            local drawLayer, subLevel = region:GetDrawLayer()
            local texture = container.iconVisual:CreateTexture(nil, drawLayer, nil, subLevel or 0)
            texture:SetSize(region:GetWidth(), region:GetHeight())
            if region:GetNumPoints() == 0 then
                texture:SetPoint("CENTER", container.iconVisual, "CENTER")
            else
                for index = 1, region:GetNumPoints() do
                    local point, _, relativePoint, offsetX, offsetY = region:GetPoint(index)
                    texture:SetPoint(point, container.iconVisual, relativePoint, offsetX or 0, offsetY or 0)
                end
            end
            CopyDifficultyTexture(texture, region, alphaOverride)
            if not alphaOverride and (texture:GetAlpha() or 0) <= 0 then texture:SetAlpha(1) end
            return true
        end

        local attached = 0
        local skullTexture  -- icon texture reference used to anchor the preview label
        -- Respect DifficultyShowBackground: skip Background/Border art when disabled.
        local savedOverrides = data and data.overrides or {}
        local showBg = savedOverrides.DifficultyShowBackground
        if showBg == nil then
            local plugin = Orbit:GetPlugin("Orbit_Minimap")
            showBg = plugin and plugin:GetSetting("Orbit_Minimap", "DifficultyShowBackground")
        end

        if activeFrame then
            if showBg then
                Attach(activeFrame.Background, 1)
                Attach(activeFrame.Border, 1)
            end
            for _, region in ipairs({ activeFrame:GetRegions() }) do
                if region ~= activeFrame.Background and region ~= activeFrame.Border and region:IsShown() and Attach(region) then
                    attached = attached + 1
                    local regions = { container.iconVisual:GetRegions() }  -- skull anchor: last-created texture
                    skullTexture = regions[#regions]
                    break
                end
            end
        end
        if attached == 0 and source.Icon then
            local texture = container.iconVisual:CreateTexture(nil, source.Icon:GetDrawLayer())
            texture:SetSize(source.Icon:GetWidth(), source.Icon:GetHeight())
            texture:SetPoint("CENTER", container.iconVisual, "CENTER")
            CopyDifficultyTexture(texture, source.Icon, 1)
            skullTexture = texture
        end

        local labelAnchor = skullTexture or container.iconVisual  -- placeholder "25" beneath skull
        local previewLabel = container.iconVisual:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        previewLabel:SetText("25")
        previewLabel:SetPoint("TOP", labelAnchor, "BOTTOM", 0, 2)

        local function UpdateDifficultySize(self, size)
            local targetWidth = (size and size > 0) and size or baseWidth
            local scale = (baseWidth > 0) and (targetWidth / baseWidth) or 1
            container.iconVisual:SetScale(scale)
            self:SetSize(targetWidth, baseHeight * scale)
        end

        container.UpdateZoomSize = UpdateDifficultySize

        local overrides = data and data.overrides
        local savedSize = overrides and overrides.IconSize
        UpdateDifficultySize(container, savedSize and savedSize > 0 and savedSize or baseWidth)
        container.visual = container.iconVisual

        return container.iconVisual
    end

    if hasFlipbook then
        visual = container:CreateTexture(nil, "OVERLAY")
        visual:SetAllPoints(container)
        local atlasName = iconTexture.GetAtlas and iconTexture:GetAtlas()
        if atlasName then visual:SetAtlas(atlasName, false)
        elseif iconTexture:GetTexture() then visual:SetTexture(iconTexture:GetTexture()) end
        -- Animate flipbook in canvas mode via child frame (avoids conflicting with drag OnUpdate)
        local rows = source.flipbookRows or FLIPBOOK_ROWS_DEFAULT
        local cols = source.flipbookCols or FLIPBOOK_COLS_DEFAULT
        local total = source.flipbookFrames or (rows * cols)
        local perFrame = (source.flipbookDuration or FLIPBOOK_DURATION_DEFAULT) / total
        local fw, fh = 1 / cols, 1 / rows
        local curFrame, elapsed = 0, 0
        local ticker = CreateFrame("Frame", nil, container)
        ticker:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed >= perFrame then
                elapsed = elapsed - perFrame
                curFrame = (curFrame + 1) % total
                local col = curFrame % cols
                local row = math.floor(curFrame / cols)
                visual:SetTexCoord(col * fw, (col + 1) * fw, row * fh, (row + 1) * fh)
            end
        end)
    else
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetAllPoints(container)
        btn:EnableMouse(false)
        btn.Icon = btn:CreateTexture(nil, "ARTWORK")
        btn.Icon:SetAllPoints()
        btn.icon = btn.Icon

        local atlasName = iconTexture and iconTexture.GetAtlas and iconTexture:GetAtlas()
        local texturePath = iconTexture and iconTexture:GetTexture()
        local StatusMixin = Orbit.StatusIconMixin
        local previewAtlases = Orbit.IconPreviewAtlases or {}
        
        if atlasName then
            local info = C_Texture.GetAtlasInfo(atlasName)
            if info and info.file then
                btn.Icon:SetTexture(info.file)
                btn.Icon:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
            else
                btn.Icon:SetAtlas(atlasName, false)
            end
        elseif texturePath then btn.Icon:SetTexture(texturePath)
        elseif StatusMixin and key == "DefensiveIcon" then btn.Icon:SetTexture(StatusMixin:GetDefensiveTexture())
        elseif StatusMixin and key == "CrowdControlIcon" then btn.Icon:SetTexture(StatusMixin:GetCrowdControlTexture())
        elseif StatusMixin and key == "PrivateAuraAnchor" then btn.Icon:SetTexture(StatusMixin:GetPrivateAuraTexture())
        elseif previewAtlases[key] then
            local info = C_Texture.GetAtlasInfo(previewAtlases[key])
            if info and info.file then
                btn.Icon:SetTexture(info.file)
                btn.Icon:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
            else
                btn.Icon:SetAtlas(previewAtlases[key], false)
            end
        else btn.Icon:SetColorTexture(CC.FALLBACK_GRAY[1], CC.FALLBACK_GRAY[2], CC.FALLBACK_GRAY[3], CC.FALLBACK_GRAY[4]) end

        visual = btn
        container.isIconFrame = true
    end

    local overrides = data and data.overrides
    local savedSize = overrides and overrides.IconSize
    local w, h = GetSourceSize(source, CC.DEFAULT_ICON_SIZE, CC.DEFAULT_ICON_SIZE)
    if savedSize and savedSize > 0 and key ~= "PrivateAuraAnchor" then w, h = savedSize, savedSize end
    container:SetSize(w, h)
    
    if container.isIconFrame then container.skipSourceSizeRestore = true end

    local unskinnedKeys = { PrivateAuraAnchor = true, Zoom = true, CraftingOrder = true, Mail = true, Difficulty = true }
    if unskinnedKeys[key] then
        container.skipIconSkin = true
    end

    if container.isIconFrame and visual and Orbit.Skin and Orbit.Skin.Icons then
        if not container.skipIconSkin then
            visual:SetSize(w, h)
            Orbit.Skin.Icons:ApplyCustom(visual, Orbit.Constants.Aura.SkinNoTimer)
        end
    end

    return visual
end

CanvasMode:RegisterCreator("IconFrame", Create)
