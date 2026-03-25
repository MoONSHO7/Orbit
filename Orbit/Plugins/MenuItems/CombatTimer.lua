---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_CombatTimer"
local DEFAULT_OFFSET_Y = -200

local Plugin = Orbit:RegisterPlugin("Combat Timer", SYSTEM_ID, {
    liveToggle = true,
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
    local SB = OrbitEngine.SchemaBuilder

    local schema = {
        hideNativeSettings = true,
        controls = {},
    }

    -- 1. Scale
    SB:AddSizeSettings(self, schema, systemIndex, systemFrame, nil, nil, {
        key = "Scale",
        label = "Scale",
        default = 100,
        min = 80,
        max = 300,
    })

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

function Plugin:OnLoad()
    self.frame = CreateFrame("Frame", "OrbitCombatTimerFrame", UIParent)

    self.frame:SetClampedToScreen(true)
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Combat Timer"
    self.frame.Text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.frame.Text:SetPoint("CENTER", self.frame, "CENTER")
    self.frame.Text:SetText("0:00")
    self.frame.anchorOptions = { horizontal = true, vertical = true, syncScale = false, syncDimensions = false }
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_OFFSET_Y)
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:EnableSmartAlignment(self.frame, self.frame.Text, 2)
    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()
    self.mountedConfig = { frame = self.frame }
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(self.frame, self, SYSTEM_ID) end
    Orbit.EventBus:On("PLAYER_REGEN_DISABLED", self.PLAYER_REGEN_DISABLED, self)
    Orbit.EventBus:On("PLAYER_REGEN_ENABLED", self.PLAYER_REGEN_ENABLED, self)
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
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings()
    local frame = self.frame
    if not frame then return end
    if not Orbit:IsPluginEnabled(self.name) then frame:Hide(); return end
    frame:SetScale((self:GetSetting(SYSTEM_ID, "Scale") or 100) / 100)
    Orbit.Skin:SkinText(frame.Text, { font = Orbit.db.GlobalSettings.Font, textSize = 14 })
    frame.Text:SetText("99:59")
    frame:SetSize(frame.Text:GetStringWidth() + 8, frame.Text:GetStringHeight() + 4)
    frame:Show()
    self:ApplyMouseOver(frame, SYSTEM_ID)
    self:UpdateTimer()
    OrbitEngine.Frame:RestorePosition(frame, self, SYSTEM_ID)
end
