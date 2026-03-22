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

        container.isIconFrame = true
        return container
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

        local texturePath = iconTexture and iconTexture:GetTexture()
        local StatusMixin = Orbit.StatusIconMixin
        if texturePath then btn.Icon:SetTexture(texturePath)
        elseif StatusMixin and key == "DefensiveIcon" then btn.Icon:SetTexture(StatusMixin:GetDefensiveTexture())
        elseif StatusMixin and key == "CrowdControlIcon" then btn.Icon:SetTexture(StatusMixin:GetCrowdControlTexture())
        elseif StatusMixin and key == "PrivateAuraAnchor" then btn.Icon:SetTexture(StatusMixin:GetPrivateAuraTexture())
        else local previewAtlases = Orbit.IconPreviewAtlases or {} if previewAtlases[key] then btn.Icon:SetAtlas(previewAtlases[key], false)
        else btn.Icon:SetColorTexture(CC.FALLBACK_GRAY[1], CC.FALLBACK_GRAY[2], CC.FALLBACK_GRAY[3], CC.FALLBACK_GRAY[4]) end
        end

        visual = btn
        container.isIconFrame = true
    end

    local overrides = data and data.overrides
    local savedSize = overrides and overrides.IconSize
    local w, h = GetSourceSize(source, CC.DEFAULT_ICON_SIZE, CC.DEFAULT_ICON_SIZE)
    if savedSize and savedSize > 0 and key ~= "PrivateAuraAnchor" then w, h = savedSize, savedSize end
    container:SetSize(w, h)

    if container.isIconFrame and visual and Orbit.Skin and Orbit.Skin.Icons and key ~= "PrivateAuraAnchor" then
        visual:SetSize(w, h)
        Orbit.Skin.Icons:ApplyCustom(visual, Orbit.Constants.Aura.SkinNoTimer)
    end

    return visual
end

CanvasMode:RegisterCreator("IconFrame", Create)
