---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_QueueStatus"
local DEFAULT_POSITION_X = -250
local DEFAULT_POSITION_Y = 40

local Plugin = Orbit:RegisterPlugin("Queue Status", SYSTEM_ID, {
    defaults = {
        Scale = 100,
        Opacity = 100,
    },
})

-- Apply NativeBarMixin for scale helper
Mixin(Plugin, Orbit.NativeBarMixin)

-- [ HELPERS ]---------------------------------------------------------------------------------------

local function NeutralizeNativeAnchoring()
    if MicroMenuMixin then
        MicroMenuMixin.UpdateQueueStatusAnchors = function() end
    end
    if MicroMenuContainerMixin and MicroMenuContainerMixin.UpdateQueueStatusAnchors then
        MicroMenuContainerMixin.UpdateQueueStatusAnchors = function() end
    end
end

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
        label = L.PLU_QUEUE_SCALE,
        default = 100,
        min = 50,
        max = 200,
    })

    OrbitEngine.Config:Render(dialog, systemFrame, self, schema)
end

function Plugin:OnLoad()
    self.frame = CreateFrame("Frame", "OrbitQueueStatusContainer", UIParent)
    self.frame:SetSize(45, 45)
    self.frame:SetClampedToScreen(true)
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Queue Status"
    self.frame.anchorOptions = { horizontal = true, vertical = true, syncScale = false, syncDimensions = false }
    self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", DEFAULT_POSITION_X, DEFAULT_POSITION_Y)
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()
    Orbit.EventBus:On("PLAYER_REGEN_ENABLED", function() self:ApplySettings() end, self)
    self.mountedConfig = { frame = self.frame }
    if Orbit.OOCFadeMixin then Orbit.OOCFadeMixin:ApplyOOCFade(self.frame, self, SYSTEM_ID) end
    NeutralizeNativeAnchoring()
    self:ReparentAll()

    if QueueStatusButton then
        hooksecurefunc(QueueStatusButton, "SetParent", function(btn, parent)
            -- Only recapture from native Blizzard parents, never from another addon's container
            if parent ~= self.frame and self.frame and (parent == MicroMenu or parent == MicroMenuContainer or parent == UIParent) then
                btn:SetParent(self.frame)
                btn:ClearAllPoints()
                btn:SetPoint("CENTER", self.frame, "CENTER")
            end
        end)
        hooksecurefunc(QueueStatusButton, "SetPoint", function(btn)
            if btn:GetParent() == self.frame then
                local point, relativeTo = btn:GetPoint()
                if relativeTo ~= self.frame or point ~= "CENTER" then
                    btn:ClearAllPoints()
                    btn:SetPoint("CENTER", self.frame, "CENTER")
                end
            end
        end)
    end
end

-- [ LOGIC ]-----------------------------------------------------------------------------------------
function Plugin:CaptureButton(button)
    if not button then return end
    local parent = button:GetParent()
    -- Only capture from native Blizzard parents, never from another addon's container
    if parent ~= self.frame and parent ~= MicroMenu and parent ~= MicroMenuContainer and parent ~= UIParent then
        self.conflicted = true
        return
    end
    if parent ~= self.frame then
        button:SetParent(self.frame)
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", self.frame, "CENTER")
end

function Plugin:ReparentAll()
    if QueueStatusButton then
        self:CaptureButton(QueueStatusButton)
    end
end

-- [ SETTINGS APPLICATION ]--------------------------------------------------------------------------
function Plugin:ApplySettings()
    local frame = self.frame
    if not frame or InCombatLockdown() then return end
    NeutralizeNativeAnchoring()
    self:ReparentAll()
    local scale = self:GetSetting(SYSTEM_ID, "Scale") or 100
    frame:SetScale(scale / 100)
    frame:Show()

    if QueueStatusFrame and QueueStatusButton then
        QueueStatusFrame:ClearAllPoints()
        local x = frame:GetCenter()
        if x then
            if x < (GetScreenWidth() / 2) then
                QueueStatusFrame:SetPoint("BOTTOMLEFT", QueueStatusButton, "TOPRIGHT", 0, 0)
            else
                QueueStatusFrame:SetPoint("BOTTOMRIGHT", QueueStatusButton, "TOPLEFT", 0, 0)
            end
        end
    end

    self:ApplyMouseOver(frame, SYSTEM_ID)
    OrbitEngine.FrameSelection:ForceUpdate(frame)
end
