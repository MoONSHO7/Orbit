-- [ ORBIT HANDLE CORE ]--------------------------------------------------------------------------
-- Shared infrastructure for drag handles. Used by ComponentHandle and PreviewHandle.
-- Provides frame pooling, border textures, and visual state helpers.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.HandleCore = {}
local HandleCore = Engine.HandleCore

-- [ CONFIGURATION ]-----------------------------------------------------------------------------

local DEFAULT_BORDER_SIZE = 1
local MIN_HANDLE_WIDTH = 50
local MIN_HANDLE_HEIGHT = 20

-- Default colors (green theme)
local COLOR_IDLE = { r = 0.3, g = 0.8, b = 0.3, bgA = 0, borderA = 0 }
local COLOR_HOVER = { r = 0.3, g = 0.8, b = 0.3, bgA = 0.1, borderA = 0.4 }
local COLOR_SELECTED = { r = 0.5, g = 0.9, b = 0.3, bgA = 0.1, borderA = 0.5 }
local COLOR_DRAG = { r = 0.3, g = 1.0, b = 0.3, bgA = 0.35, borderA = 0.8 }

HandleCore.Colors = {
    IDLE = COLOR_IDLE,
    HOVER = COLOR_HOVER,
    SELECTED = COLOR_SELECTED,
    DRAG = COLOR_DRAG,
}

HandleCore.MIN_WIDTH = MIN_HANDLE_WIDTH
HandleCore.MIN_HEIGHT = MIN_HANDLE_HEIGHT

-- [ FRAME POOL ]--------------------------------------------------------------------------------

local handlePool = {}

function HandleCore:AcquireFromPool()
    return table.remove(handlePool)
end

function HandleCore:ReturnToPool(handle)
    if not handle then
        return
    end

    -- Clear scripts
    handle:SetScript("OnEnter", nil)
    handle:SetScript("OnLeave", nil)
    handle:SetScript("OnMouseDown", nil)
    handle:SetScript("OnMouseUp", nil)
    handle:SetScript("OnDragStart", nil)
    handle:SetScript("OnDragStop", nil)
    handle:SetScript("OnUpdate", nil)

    -- Reset state
    handle:Hide()
    handle:ClearAllPoints()
    handle.component = nil
    handle.container = nil
    handle.callbacks = nil
    handle.isDragging = false

    table.insert(handlePool, handle)
end

function HandleCore:ClearPool()
    for _, h in ipairs(handlePool) do
        h:SetParent(nil)
    end
    wipe(handlePool)
end

-- [ CREATE HANDLE FRAME ]-----------------------------------------------------------------------

-- Create a new handle frame with borders and color helper
-- @param options: { strata, level, borderSize }
-- @return handle frame
function HandleCore:CreateFrame(options)
    options = options or {}
    local strata = options.strata or "FULLSCREEN_DIALOG"
    local level = options.level or 200
    local borderSize = options.borderSize or DEFAULT_BORDER_SIZE

    local handle = CreateFrame("Frame", nil, UIParent)
    handle:SetFrameStrata(strata)
    handle:SetFrameLevel(level)

    -- Background texture
    handle.bg = handle:CreateTexture(nil, "BACKGROUND")
    handle.bg:SetAllPoints()
    handle.bg:SetColorTexture(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, COLOR_IDLE.bgA)

    -- Border textures
    handle.borderTop = handle:CreateTexture(nil, "BORDER")
    handle.borderTop:SetColorTexture(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, COLOR_IDLE.borderA)
    handle.borderTop:SetPoint("TOPLEFT", 0, 0)
    handle.borderTop:SetPoint("TOPRIGHT", 0, 0)
    handle.borderTop:SetHeight(borderSize)

    handle.borderBottom = handle:CreateTexture(nil, "BORDER")
    handle.borderBottom:SetColorTexture(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, COLOR_IDLE.borderA)
    handle.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    handle.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    handle.borderBottom:SetHeight(borderSize)

    handle.borderLeft = handle:CreateTexture(nil, "BORDER")
    handle.borderLeft:SetColorTexture(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, COLOR_IDLE.borderA)
    handle.borderLeft:SetPoint("TOPLEFT", 0, 0)
    handle.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    handle.borderLeft:SetWidth(borderSize)

    handle.borderRight = handle:CreateTexture(nil, "BORDER")
    handle.borderRight:SetColorTexture(COLOR_IDLE.r, COLOR_IDLE.g, COLOR_IDLE.b, COLOR_IDLE.borderA)
    handle.borderRight:SetPoint("TOPRIGHT", 0, 0)
    handle.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    handle.borderRight:SetWidth(borderSize)

    -- Store reference to border size for UpdateSize
    handle.borderSize = borderSize

    -- Color helper method
    function handle:SetHandleColor(r, g, b, bgAlpha, borderAlpha)
        self.bg:SetColorTexture(r, g, b, bgAlpha)
        self.borderTop:SetColorTexture(r, g, b, borderAlpha)
        self.borderBottom:SetColorTexture(r, g, b, borderAlpha)
        self.borderLeft:SetColorTexture(r, g, b, borderAlpha)
        self.borderRight:SetColorTexture(r, g, b, borderAlpha)
    end

    -- Apply color preset
    function handle:ApplyColorPreset(preset)
        self:SetHandleColor(preset.r, preset.g, preset.b, preset.bgA, preset.borderA)
    end

    return handle
end

-- [ UTILITY FUNCTIONS ]-------------------------------------------------------------------------

-- Safely get size, handling secret values
function HandleCore:SafeGetSize(frame)
    if not frame then
        return MIN_HANDLE_WIDTH, MIN_HANDLE_HEIGHT
    end

    local width, height = MIN_HANDLE_WIDTH, MIN_HANDLE_HEIGHT

    local ok, w = pcall(function()
        return frame:GetWidth()
    end)
    if ok and w and type(w) == "number" then
        -- Check for secret value BEFORE comparing
        if not (issecretvalue and issecretvalue(w)) then
            if w > 0 then
                width = w
            end
        end
    end

    local ok2, h = pcall(function()
        return frame:GetHeight()
    end)
    if ok2 and h and type(h) == "number" then
        -- Check for secret value BEFORE comparing
        if not (issecretvalue and issecretvalue(h)) then
            if h > 0 then
                height = h
            end
        end
    end

    return width, height
end

-- Position handle over component with minimum size enforcement
function HandleCore:PositionOverComponent(handle, component)
    if not handle or not component then
        return
    end

    local width, height = self:SafeGetSize(component)
    width = math.max(width, MIN_HANDLE_WIDTH)
    height = math.max(height, MIN_HANDLE_HEIGHT)

    handle:SetSize(width, height)
    handle:ClearAllPoints()
    handle:SetPoint("CENTER", component, "CENTER", 0, 0)
end
