---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_Performance"

local Plugin = Orbit:RegisterPlugin("Performance Info", SYSTEM_ID, {
    defaults = {
        Scale = 100,
        Opacity = 100,
        Colorize = true,
        UpdateInterval = 1,
    },
}, Orbit.Constants.PluginGroups.Misc)

-- Apply NativeBarMixin for common helpers
Mixin(Plugin, Orbit.NativeBarMixin)

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local COLORS = {
    WHITE = "|cffffffff",
    RED = "|cffff0000",
    ORANGE = "|cfffea300", -- Standard Orbit/WoW Orange
    GREEN = "|cff00ff00",
}

-- [ SETTINGS UI ]-----------------------------------------------------------------------------------
function Plugin:AddSettings(dialog, systemFrame)
    local systemIndex = systemFrame.systemIndex or SYSTEM_ID
    local WL = OrbitEngine.WidgetLogic

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- 1. Scale
    WL:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
        key = "Scale",
        label = "Scale",
        default = 100,
        min = 80,
        max = 120,
    })

    -- 2. Opacity
    WL:AddOpacitySettings(self, schema, systemIndex, systemFrame, { step = 5 })

    Orbit.Config:Render(dialog, systemFrame, self, schema)

    -- 3. Coloring
    table.insert(schema.controls, {
        type = "checkbox",
        key = "Colorize",
        label = "Colorize Stats",
        default = true,
    })
end

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create Container
    self.frame = CreateFrame("Frame", "OrbitPerformanceFrame", UIParent)
    self.frame:SetSize(100, 20)
    self.frame:SetClampedToScreen(true) -- Prevent dragging off-screen
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Performance Info"

    -- Text Display
    self.frame.Text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.frame.Text:SetPoint("CENTER", self.frame, "CENTER")

    -- Orbit Anchoring: Disable property sync to prevent dimension/scale inheritance
    self.frame.anchorOptions = {
        horizontal = true,
        vertical = true,
        syncScale = false,
        syncDimensions = false,
    }

    -- Default Position (Bottom Right near other tools)
    self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -300, 40)

    -- Register
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    -- Anchor Logic
    self:EnableSmartAlignment(self.frame, self.frame.Text, 2)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()
    self:ApplySettings()
    self:StartLoop()
end

function Plugin:StartLoop()
    if self.timer then
        self.timer:Cancel()
        self.timer = nil
    end

    -- Default to 1s update to avoid spam
    self.timer = C_Timer.NewTicker(1, function()
        if not self.timer then return end  -- Guard against cancelled timer firing
        self:UpdateStats()
    end)

    -- Immediate update
    self:UpdateStats()
end

-- [ LOGIC ]-----------------------------------------------------------------------------------------
function Plugin:UpdateStats()
    local colorize = self:GetSetting(SYSTEM_ID, "Colorize")

    -- FPS
    local fps = GetFramerate()
    local fpsStr = math.floor(fps)
    local fpsColor = COLORS.WHITE

    if colorize then
        if fps < 30 then
            fpsColor = COLORS.RED
        elseif fps <= 60 then
            fpsColor = COLORS.ORANGE
        else
            fpsColor = COLORS.WHITE
        end
    end

    -- Latency (Home)
    local _, _, latencyHome, _ = GetNetStats()
    local ms = latencyHome
    local msStr = ms
    local msColor = COLORS.WHITE

    if colorize then
        if ms <= 60 then
            msColor = COLORS.GREEN
        elseif ms < 200 then
            msColor = COLORS.ORANGE
        else
            msColor = COLORS.RED
        end
    end

    if not self.frame:IsVisible() then
        return
    end

    local text
    if colorize then
        -- Format: {COLOR}{fps}|r{WHITE}fps|r | {COLOR}{ms}|r{WHITE}ms|r
        text =
            string.format("%s%d|r%sfps|r | %s%d|r%sms|r", fpsColor, fpsStr, COLORS.WHITE, msColor, msStr, COLORS.WHITE)
    else
        text = string.format("%dfps | %dms", fpsStr, msStr)
    end

    self.frame.Text:SetText(text)

    -- Auto-resize frame to fit text (for easier dragging hit rect)
    local width = self.frame.Text:GetStringWidth()
    self.frame:SetSize(width + 10, 20)
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then
        return
    end

    local scale = self:GetSetting(SYSTEM_ID, "Scale") or 100
    -- Apply Opacity
    local opacity = self:GetSetting(SYSTEM_ID, "Opacity") or 100

    frame:SetScale(scale / 100)
    frame:SetAlpha(opacity / 100)

    -- Global Text Scale
    local textMultiplier = 1
    local s = Orbit.db.GlobalSettings.TextScale
    if s == "Small" then
        textMultiplier = 0.85
    elseif s == "Large" then
        textMultiplier = 1.15
    elseif s == "ExtraLarge" then
        textMultiplier = 1.30
    end

    -- Apply Global Font (Always, to enforce OUTLINE)
    local globalFont = Orbit.db.GlobalSettings.Font
    Orbit.Skin:SkinText(frame.Text, {
        font = globalFont, -- SkinText handles nil fallback to default font
        textSize = 14 * textMultiplier,
        -- textColor handled by dynamic coloring
    })

    -- Force update to reflect coloring change immediately
    self:UpdateStats()

    frame:Show()

    self:ApplyMouseOver(frame, SYSTEM_ID)

    -- Restore position (to ensure correct placement after settings applied)
    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)
end
