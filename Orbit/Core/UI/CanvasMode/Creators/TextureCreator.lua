-- [ CANVAS MODE - TEXTURE CREATOR ]-----------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local CC = CanvasMode.CreatorConstants
local GetSourceSize = CanvasMode.GetSourceSize

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local SPRITE_ROWS_DEFAULT = 4
local SPRITE_COLS_DEFAULT = 4
local SPRITE_FALLBACK_INDEX = 8

-- [ HELPERS ]---------------------------------------------------------------------------------------

local function ApplySpriteSheetCell(texture, index, rows, cols)
    if not texture or not index then return end
    if issecretvalue and issecretvalue(index) then index = SPRITE_FALLBACK_INDEX end
    rows = rows or SPRITE_ROWS_DEFAULT
    cols = cols or SPRITE_COLS_DEFAULT
    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)
    local width = 1 / cols
    local height = 1 / rows
    texture:SetTexCoord(col * width, col * width + width, row * height, row * height + height)
end

CanvasMode.ApplySpriteSheetCell = ApplySpriteSheetCell

-- [ CREATOR ]---------------------------------------------------------------------------------------

local function Create(container, preview, key, source, data)
    local visual = container:CreateTexture(nil, "OVERLAY")
    visual:SetAllPoints(container)

    local atlasName = source.GetAtlas and source:GetAtlas()
    local texturePath = source:GetTexture()

    if atlasName then
        visual:SetAtlas(atlasName, false)
    elseif texturePath then
        visual:SetTexture(texturePath)
        if source.orbitSpriteIndex then
            ApplySpriteSheetCell(visual, source.orbitSpriteIndex, source.orbitSpriteRows or SPRITE_ROWS_DEFAULT, source.orbitSpriteCols or SPRITE_COLS_DEFAULT)
        else
            local ok, l, r, t, b = pcall(function() return source:GetTexCoord() end)
            if ok and l then visual:SetTexCoord(l, r, t, b) end
        end
    else
        local previewAtlases = Orbit.IconPreviewAtlases or {}
        local fallbackAtlas = previewAtlases[key]
        if fallbackAtlas then
            if key == "MarkerIcon" then
                visual:SetTexture(fallbackAtlas)
                ApplySpriteSheetCell(visual, SPRITE_FALLBACK_INDEX, SPRITE_ROWS_DEFAULT, SPRITE_COLS_DEFAULT)
            else
                visual:SetAtlas(fallbackAtlas, false)
            end
        else
            visual:SetColorTexture(CC.FALLBACK_GRAY[1], CC.FALLBACK_GRAY[2], CC.FALLBACK_GRAY[3], CC.FALLBACK_GRAY[4])
        end
    end

    local vr, vg, vb, va = source:GetVertexColor()
    if vr then visual:SetVertexColor(vr, vg, vb, va or 1) end

    local w, h = GetSourceSize(source, CC.DEFAULT_TEXTURE_SIZE, CC.DEFAULT_TEXTURE_SIZE)
    container:SetSize(w, h)

    return visual
end

CanvasMode:RegisterCreator("Texture", Create)
