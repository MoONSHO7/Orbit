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
})

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
    WL:AddOpacitySettings(self, schema, systemIndex, systemFrame)

    Orbit.Config:Render(dialog, systemFrame, self, schema)

    -- 3. Coloring
    table.insert(schema.controls, {
        type = "checkbox",
        key = "Colorize",
        label = "Colorize Stats",
        default = true,
    })
end

function Plugin:OnLoad()
    self.frame = CreateFrame("Frame", "OrbitPerformanceFrame", UIParent)
    self.frame:SetSize(100, 20)
    self.frame:SetClampedToScreen(true)
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Performance Info"
    self.frame.Text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.frame.Text:SetPoint("CENTER", self.frame, "CENTER")

    self.frame.anchorOptions = { horizontal = true, vertical = true, syncScale = false, syncDimensions = false }
    self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -300, 40)
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)
    self:EnableSmartAlignment(self.frame, self.frame.Text, 2)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()
    self.mountedFrame = self.frame
    self.mountedHoverReveal = true
    self:ApplySettings()
    self:StartLoop()
end

function Plugin:StartLoop()
    if self.timer then
        self.timer:Cancel()
        self.timer = nil
    end
    self.timer = C_Timer.NewTicker(1, function()
        if not self.timer then
            return
        end
        self:UpdateStats()
    end)
    self:UpdateStats()
end

-- [ LOGIC ]-----------------------------------------------------------------------------------------
function Plugin:UpdateStats()
    local colorize = self:GetSetting(SYSTEM_ID, "Colorize")
    local fps = GetFramerate()
    local fpsStr, fpsColor = math.floor(fps), COLORS.WHITE
    if colorize then
        fpsColor = fps < 30 and COLORS.RED or fps <= 60 and COLORS.ORANGE or COLORS.WHITE
    end
    local _, _, latencyHome = GetNetStats()
    local ms, msColor = latencyHome, COLORS.WHITE
    if colorize then
        msColor = ms <= 60 and COLORS.GREEN or ms < 200 and COLORS.ORANGE or COLORS.RED
    end
    if not self.frame:IsVisible() then
        return
    end

    local text = colorize and string.format("%s%d|r%sfps|r | %s%d|r%sms|r", fpsColor, fpsStr, COLORS.WHITE, msColor, ms, COLORS.WHITE)
        or string.format("%dfps | %dms", fpsStr, ms)
    self.frame.Text:SetText(text)
    local width = self.frame.Text:GetStringWidth() + 10
    if InCombatLockdown() then Orbit.CombatManager:QueueUpdate(function() self.frame:SetSize(width, 20) end) else self.frame:SetSize(width, 20) end
end

function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then
        return
    end
    frame:SetScale((self:GetSetting(SYSTEM_ID, "Scale") or 100) / 100)
    local s = Orbit.db.GlobalSettings.TextScale
    local textMultiplier = s == "Small" and 0.85 or s == "Large" and 1.15 or s == "ExtraLarge" and 1.30 or 1
    Orbit.Skin:SkinText(frame.Text, { font = Orbit.db.GlobalSettings.Font, textSize = 14 * textMultiplier })
    self:UpdateStats()
    frame:Show()
    self:ApplyMouseOver(frame, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)
end
