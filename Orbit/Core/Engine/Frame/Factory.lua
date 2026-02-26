-- [ ORBIT FRAME FACTORY ]---------------------------------------------------------------------------

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.FrameFactory = Engine.FrameFactory or {}
local FrameFactory = Engine.FrameFactory

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local DEFAULT_WIDTH = 200
local DEFAULT_HEIGHT = 40
local DEFAULT_Y_OFFSET = -200
local DEFAULT_STRATA = "MEDIUM"
local DEFAULT_SYSTEM_INDEX = 1
local RESTORE_DEBOUNCE = 0.1
local TEXT_OVERLAY_LEVEL_BOOST = 20

-- [ FRAME CREATION ]--------------------------------------------------------------------------------

function FrameFactory:Create(name, plugin, opts)
    if not name then error("FrameFactory:Create requires a name") end
    if not plugin then error("FrameFactory:Create requires a plugin") end
    opts = opts or {}

    local frameType = opts.frameType or "Frame"
    local parent = opts.parent or UIParent
    local width = opts.width or DEFAULT_WIDTH
    local height = opts.height or DEFAULT_HEIGHT
    local x = opts.x or 0
    local y = opts.y or DEFAULT_Y_OFFSET
    local point = opts.point or "CENTER"
    local strata = opts.strata or DEFAULT_STRATA
    local systemIndex = opts.systemIndex or DEFAULT_SYSTEM_INDEX

    local frameName = "Orbit" .. name
    local frame = CreateFrame(frameType, frameName, parent, opts.template)

    frame:SetSize(width, height)
    frame:SetPoint(point, parent, point, x, y)
    frame:SetFrameStrata(strata)
    frame:SetClampedToScreen(true)

    frame.systemIndex = systemIndex
    frame.orbitName = plugin.name
    frame.editModeName = plugin.name
    frame.orbitPlugin = plugin
    frame.anchorOptions = opts.anchorOptions or { horizontal = true, vertical = false }
    frame.defaultPosition = { point = point, relativeTo = parent, relativePoint = point, x = x, y = y }

    plugin.Frame = frame

    if opts.autoAttach ~= false then
        Engine.Frame:AttachSettingsListener(frame, plugin, systemIndex)
    end

    if opts.autoRestore ~= false then
        Orbit.Async:Debounce(frameName .. "_RestorePos", function()
            Engine.Frame:RestorePosition(frame, plugin, systemIndex)
        end, RESTORE_DEBOUNCE)
    end

    frame.SetBorder = function(self, size)
        Orbit.Skin:SkinBorder(self, self, size)
        local bar = self.orbitBar or self.Bar
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", 0, 0)
            bar:SetPoint("BOTTOMRIGHT", 0, 0)
        end
    end

    Engine.Pixel:Enforce(frame)
    return frame
end

-- [ STATUS BAR CREATION ]---------------------------------------------------------------------------

function FrameFactory:CreateStatusBar(name, plugin, opts)
    opts = opts or {}
    opts.frameType = "StatusBar"

    local frame = self:Create(name, plugin, opts)
    frame:SetMinMaxValues(opts.minValue or 0, opts.maxValue or 1)
    frame:SetValue(opts.value or 0)
    frame:SetStatusBarTexture("")
    return frame
end

-- [ CONTAINER WITH BAR ]----------------------------------------------------------------------------

function FrameFactory:CreateWithBar(name, plugin, opts)
    opts = opts or {}
    opts.template = opts.template or "BackdropTemplate"

    local container = self:Create(name, plugin, opts)

    local barName = opts.barName or (name .. "Bar")
    local bar = CreateFrame("StatusBar", "Orbit" .. barName, container)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)

    container.Bar = bar
    container.orbitBar = bar

    local bgColor = opts.bgColor or (Orbit.Colors and Orbit.Colors.Background)
    if bgColor then
        local bg = container:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.9)
        container.bg = bg
    end

    return container, bar
end

-- [ BUTTON CONTAINER ]------------------------------------------------------------------------------

function FrameFactory:CreateButtonContainer(name, plugin, opts)
    opts = opts or {}

    local container = self:Create(name, plugin, opts)
    container.buttons = {}

    for i = 1, (opts.maxButtons or 0) do
        local btn = CreateFrame("Frame", nil, container)
        btn.SetActive = function(self, active)
            self.isActive = active
            if self.orbitBar then self.orbitBar:SetShown(active) end
        end
        container.buttons[i] = btn
    end

    return container
end

-- [ TEXT HELPERS ]-----------------------------------------------------------------------------------

function FrameFactory:AddText(frame, opts)
    opts = opts or {}
    local point = opts.point or "CENTER"
    local font = opts.font or "GameFontHighlight"
    local layer = opts.layer or "OVERLAY"
    local relativeTo = opts.relativeTo or frame
    local relativePoint = opts.relativePoint or point

    if opts.useOverlay then
        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints()
        overlay:SetFrameLevel(frame:GetFrameLevel() + TEXT_OVERLAY_LEVEL_BOOST)
        frame.Overlay = overlay

        local text = overlay:CreateFontString(nil, layer, font)
        text:SetPoint(point, relativeTo, relativePoint, opts.x or 0, opts.y or 0)
        frame.Text = text
        return text
    end

    local text = frame:CreateFontString(nil, layer, font)
    text:SetPoint(point, relativeTo, relativePoint, opts.x or 0, opts.y or 0)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    frame.Text = text
    return text
end
