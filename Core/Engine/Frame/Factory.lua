-- [ ORBIT FRAME FACTORY ]---------------------------------------------------------------------------
-- Standardized frame creation for Orbit plugins.
-- Reduces boilerplate and ensures consistent frame setup.

local _, Orbit = ...
local Engine = Orbit.Engine

Engine.FrameFactory = Engine.FrameFactory or {}
local FrameFactory = Engine.FrameFactory

-- [ FRAME CREATION ]--------------------------------------------------------------------------------

--- Create a standard Orbit frame with all required properties
-- @param name string: Unique name for the frame (will be prefixed with "Orbit")
-- @param plugin table: The plugin that owns this frame
-- @param opts table: Options table with:
--   - frameType string: Frame type (default: "Frame")
--   - template string: Frame template (optional)
--   - parent Frame: Parent frame (default: UIParent)
--   - width number: Initial width (default: 200)
--   - height number: Initial height (default: 40)
--   - x number: Initial X offset (default: 0)
--   - y number: Initial Y offset (default: -200)
--   - point string: Anchor point (default: "CENTER")
--   - strata string: Frame strata (default: "MEDIUM")
--   - systemIndex number: System index for settings (default: 1)
--   - anchorOptions table: Anchoring options (default: {horizontal=true, vertical=false})
--   - autoAttach boolean: Auto-attach to Orbit.Frame (default: true)
--   - autoRestore boolean: Auto-restore position (default: true)
-- @return Frame: The created frame
function FrameFactory:Create(name, plugin, opts)
    opts = opts or {}

    -- Validate inputs
    if not name then
        error("FrameFactory:Create requires a name")
    end
    if not plugin then
        error("FrameFactory:Create requires a plugin")
    end

    -- Defaults
    local frameType = opts.frameType or "Frame"
    local template = opts.template
    local parent = opts.parent or UIParent
    local width = opts.width or 200
    local height = opts.height or 40
    local x = opts.x or 0
    local y = opts.y or -200
    local point = opts.point or "CENTER"
    local strata = opts.strata or "MEDIUM"
    local systemIndex = opts.systemIndex or 1
    local autoAttach = opts.autoAttach ~= false -- default true
    local autoRestore = opts.autoRestore ~= false -- default true

    -- Create frame
    local frameName = "Orbit" .. name
    local frame
    if template then
        frame = CreateFrame(frameType, frameName, parent, template)
    else
        frame = CreateFrame(frameType, frameName, parent)
    end

    -- Basic setup
    frame:SetSize(width, height)
    frame:SetPoint(point, parent, point, x, y)
    frame:SetFrameStrata(strata)
    frame:SetClampedToScreen(true) -- Prevent dragging off-screen

    -- Orbit metadata
    frame.systemIndex = systemIndex
    frame.orbitName = plugin.name
    frame.editModeName = plugin.name
    frame.orbitPlugin = plugin

    -- Anchor options (default: vertical stacking only)
    frame.anchorOptions = opts.anchorOptions or { horizontal = true, vertical = false }

    -- Store Default Position for Reset
    frame.defaultPosition = {
        point = point,
        relativeTo = parent,
        relativePoint = point,
        x = x,
        y = y,
    }

    -- Store reference on plugin
    plugin.Frame = frame

    -- Auto-attach to Frame system
    if autoAttach then
        Engine.Frame:AttachSettingsListener(frame, plugin, systemIndex)
    end

    -- Auto-restore position (debounced)
    if autoRestore then
        Orbit.Async:Debounce(frameName .. "_RestorePos", function()
            Engine.Frame:RestorePosition(frame, plugin, systemIndex)
        end, 0.1)
    end

    -- Border Helper (Clean pixel-perfect borders)
    frame.SetBorderHidden = function(self, edge, hidden)
        if not self.Borders then
            return
        end
        local border = self.Borders[edge]
        if border then
            border:SetShown(not hidden)
        end
    end

    frame.SetBorder = function(self, size)
        -- Calculation: Convert desired physical pixels (size) to frame-local units
        -- Use new Pixel Engine (or fallback during init)
        local pixelScale = (Engine.Pixel and Engine.Pixel:GetScale())
            or (768.0 / (select(2, GetPhysicalScreenSize()) or 768.0))

        local scale = self:GetEffectiveScale()
        if not scale or scale < 0.01 then
            scale = 1
        end

        local mult = pixelScale / scale
        local pixelSize = (size or 1) * mult
        self.borderPixelSize = pixelSize

        -- Create borders if needed
        if not self.Borders then
            self.Borders = {}
            local function CreateLine()
                local t = self:CreateTexture(nil, "BORDER")
                t:SetColorTexture(0, 0, 0, 1)
                return t
            end
            self.Borders.Top = CreateLine()
            self.Borders.Bottom = CreateLine()
            self.Borders.Left = CreateLine()
            self.Borders.Right = CreateLine()
        end

        local b = self.Borders

        -- Non-overlapping Layout
        -- Top/Bottom: Full Width
        b.Top:ClearAllPoints()
        b.Top:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        b.Top:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
        b.Top:SetHeight(pixelSize)

        b.Bottom:ClearAllPoints()
        b.Bottom:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
        b.Bottom:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
        b.Bottom:SetHeight(pixelSize)

        -- Left/Right: Inset by Top/Bottom height
        b.Left:ClearAllPoints()
        b.Left:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -pixelSize)
        b.Left:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, pixelSize)
        b.Left:SetWidth(pixelSize)

        b.Right:ClearAllPoints()
        b.Right:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -pixelSize)
        b.Right:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, pixelSize)
        b.Right:SetWidth(pixelSize)

        -- Handle Bar Inset (use calculated pixelSize)
        local bar = self.orbitBar or self.Bar
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", pixelSize, -pixelSize)
            bar:SetPoint("BOTTOMRIGHT", -pixelSize, pixelSize)
        end
    end

    -- Enforce Pixel Perfection on Sizing
    if Engine.Pixel then
        Engine.Pixel:Enforce(frame)
    end

    return frame
end

--- Create a StatusBar Orbit frame
-- Convenience wrapper for StatusBar frames with common setup
-- @param name string: Unique name for the frame
-- @param plugin table: The plugin that owns this frame
-- @param opts table: Same options as Create, plus:
--   - minValue number: Min value (default: 0)
--   - maxValue number: Max value (default: 1)
--   - value number: Initial value (default: 0)
-- @return StatusBar: The created StatusBar frame
function FrameFactory:CreateStatusBar(name, plugin, opts)
    opts = opts or {}
    opts.frameType = "StatusBar"

    local frame = self:Create(name, plugin, opts)

    -- StatusBar specific setup
    local minVal = opts.minValue or 0
    local maxVal = opts.maxValue or 1
    local val = opts.value or 0

    frame:SetMinMaxValues(minVal, maxVal)
    frame:SetValue(val)

    -- Default to no texture (let skin handle it)
    frame:SetStatusBarTexture("")

    return frame
end

--- Create a container frame with child bar (common pattern)
-- Used by PlayerPower, PlayerResources, etc.
-- @param name string: Unique name for the frame
-- @param plugin table: The plugin that owns this frame
-- @param opts table: Same options as Create, plus:
--   - barName string: Name for the child bar (default: name.."Bar")
--   - bgColor table: Background color {r,g,b,a} (optional)
-- @return Frame, StatusBar: The container frame and child bar
function FrameFactory:CreateWithBar(name, plugin, opts)
    opts = opts or {}
    opts.template = opts.template or "BackdropTemplate"

    local container = self:Create(name, plugin, opts)

    -- Create child bar
    local barName = opts.barName or (name .. "Bar")
    local bar = CreateFrame("StatusBar", "Orbit" .. barName, container)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)

    container.Bar = bar
    container.orbitBar = bar

    -- Background
    if opts.bgColor then
        local bg = container:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(opts.bgColor.r, opts.bgColor.g, opts.bgColor.b, opts.bgColor.a or 0.9)
        container.bg = bg
    elseif Orbit.Colors and Orbit.Colors.Background then
        local c = Orbit.Colors.Background
        local bg = container:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(c.r, c.g, c.b, c.a or 0.9)
        container.bg = bg
    end

    return container, bar
end

--- Create a button container frame (for PlayerResources style)
-- @param name string: Unique name for the frame
-- @param plugin table: The plugin that owns this frame
-- @param opts table: Same options as Create, plus:
--   - maxButtons number: Pre-create this many buttons (default: 0)
-- @return Frame: The container frame with .buttons array
function FrameFactory:CreateButtonContainer(name, plugin, opts)
    opts = opts or {}

    local container = self:Create(name, plugin, opts)
    container.buttons = {}

    -- Pre-create buttons if requested
    local maxButtons = opts.maxButtons or 0
    for i = 1, maxButtons do
        local btn = CreateFrame("Frame", nil, container)
        btn:SetScript("OnEnter", function() end)

        -- Standard SetActive API
        btn.SetActive = function(self, active)
            self.isActive = active
            if self.orbitBar then
                if active then
                    self.orbitBar:Show()
                else
                    self.orbitBar:Hide()
                end
            end
        end

        container.buttons[i] = btn
    end

    return container
end

-- [ HELPERS ]---------------------------------------------------------------------------------------

--- Add a text overlay to a frame
-- @param frame Frame: The frame to add text to
-- @param opts table: Options for text (optional):
--   - point string: Anchor point (default: "CENTER")
--   - font string: Font template (default: "GameFontHighlight")
--   - layer string: Draw layer (default: "OVERLAY")
-- @return FontString: The created text
function FrameFactory:AddText(frame, opts)
    opts = opts or {}

    local point = opts.point or "CENTER"
    local font = opts.font or "GameFontHighlight"
    local layer = opts.layer or "OVERLAY"

    -- Allow full anchor customization
    local relativeTo = opts.relativeTo or frame
    local relativePoint = opts.relativePoint or point
    local x = opts.x or 0
    local y = opts.y or 0

    if opts.useOverlay then
        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints()
        overlay:SetFrameStrata("HIGH")
        overlay:SetFrameLevel(frame:GetFrameLevel() + 20)
        frame.Overlay = overlay

        local text = overlay:CreateFontString(nil, layer, font)
        text:SetPoint(point, relativeTo, relativePoint, x, y)
        frame.Text = text
        return text
    end

    local text = frame:CreateFontString(nil, layer, font)
    text:SetPoint(point, relativeTo, relativePoint, x, y)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    frame.Text = text

    return text
end
