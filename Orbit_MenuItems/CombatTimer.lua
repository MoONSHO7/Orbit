---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_CombatTimer"

local Plugin = Orbit:RegisterPlugin("Combat Timer", SYSTEM_ID, {
    defaults = {
        Scale = 100,
        Opacity = 100,
        ShowIcon = true,
    },
})

-- Apply NativeBarMixin for common helpers
Mixin(Plugin, Orbit.NativeBarMixin)

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
        max = 300,
    })

    -- 2. Opacity
    WL:AddOpacitySettings(self, schema, systemIndex, systemFrame, { step = 5 })

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

function Plugin:OnLoad()
    self.frame = CreateFrame("Frame", "OrbitCombatTimerFrame", UIParent)
    self.frame:SetSize(100, 20)
    self.frame:SetClampedToScreen(true)
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Combat Timer"
    self.frame.Text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.frame.Text:SetPoint("CENTER", self.frame, "CENTER")
    self.frame.Text:SetText("0:00")
    self.frame.anchorOptions = { horizontal = true, vertical = true, syncScale = false, syncDimensions = false }
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:EnableSmartAlignment(self.frame, self.frame.Text, 2)
    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()
    self.mountedFrame = self.frame
    self.mountedHoverReveal = true
    if Orbit.EventBus then
        Orbit.EventBus:On("PLAYER_REGEN_DISABLED", self.PLAYER_REGEN_DISABLED, self)
        Orbit.EventBus:On("PLAYER_REGEN_ENABLED", self.PLAYER_REGEN_ENABLED, self)
    end
    self:ApplySettings()
end

function Plugin:PLAYER_REGEN_DISABLED()
    self.startTime = GetTime()
    self.inCombat = true
    self:StartLoop()
end

function Plugin:PLAYER_REGEN_ENABLED()
    self.inCombat = false
    if self.timer then
        self.timer:Cancel()
    end
    self:UpdateTimer()
end

function Plugin:StartLoop()
    if self.timer then
        self.timer:Cancel()
        self.timer = nil
    end
    self.timer = C_Timer.NewTicker(0.1, function()
        if not self.timer then
            return
        end
        self:UpdateTimer()
    end)
    self:UpdateTimer()
end

-- [ LOGIC ]-----------------------------------------------------------------------------------------
function Plugin:UpdateTimer()
    if not self.startTime then
        self.frame.Text:SetText("0:00")
        return
    end
    local duration = GetTime() - self.startTime
    self.frame.Text:SetText(string.format("%d:%02d", math.floor(duration / 60), math.floor(duration % 60)))
    self.frame:SetSize(self.frame.Text:GetStringWidth() + 8, 20)
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then
        return
    end
    frame:SetScale((self:GetSetting(SYSTEM_ID, "Scale") or 100) / 100)
    local s = Orbit.db.GlobalSettings.TextScale
    local textMultiplier = s == "Small" and 0.85 or s == "Large" and 1.15 or s == "ExtraLarge" and 1.30 or 1
    Orbit.Skin:SkinText(frame.Text, { font = Orbit.db.GlobalSettings.Font, textSize = 14 * textMultiplier })
    frame:Show()
    self:ApplyMouseOver(frame, SYSTEM_ID)
    self:UpdateTimer()
    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)
end
