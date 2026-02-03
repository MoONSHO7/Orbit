---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_QueueStatus"

local Plugin = Orbit:RegisterPlugin("Queue Status", SYSTEM_ID, {
    defaults = {
        Scale = 100,
        Opacity = 100,
    },
}, Orbit.Constants.PluginGroups.MenuItems)

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
        min = 50,
        max = 200,
    })

    -- 2. Opacity
    WL:AddOpacitySettings(self, schema, systemIndex, systemFrame, { step = 5 })

    Orbit.Config:Render(dialog, systemFrame, self, schema)
end

function Plugin:OnLoad()
    self.frame = CreateFrame("Frame", "OrbitQueueStatusContainer", UIParent)
    self.frame:SetSize(45, 45)
    self.frame:SetClampedToScreen(true)
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Queue Status"
    self.frame.anchorOptions = { horizontal = true, vertical = true, syncScale = false, syncDimensions = false }
    self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -250, 40)
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()
    NeutralizeNativeAnchoring()
    self:ReparentAll()

    if QueueStatusButton then
        hooksecurefunc(QueueStatusButton, "SetParent", function(btn, parent)
            if parent ~= self.frame and self.frame then
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
    if not button then
        return
    end
    if button:GetParent() ~= self.frame then
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
    if not frame then
        return
    end
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
    if OrbitEngine.FrameSelection then
        OrbitEngine.FrameSelection:ForceUpdate(frame)
    end
end
