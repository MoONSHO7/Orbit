local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine

-- [ PLUGIN REGISTRATION ]---------------------------------------------------------------------------
local SYSTEM_ID = "Orbit_QueueStatus"

local Plugin = Orbit:RegisterPlugin("Queue Status", SYSTEM_ID, {
    defaults = {
        Scale = 100,
        Opacity = 100,
        MouseOver = false,
    },
}, Orbit.Constants.PluginGroups.MenuItems)

-- Apply NativeBarMixin for scale helper
Mixin(Plugin, Orbit.NativeBarMixin)

-- [ HELPERS ]---------------------------------------------------------------------------------------

local function NeutralizeNativeAnchoring()
    -- Stop MicroMenu from trying to position the Queue Status button/frame
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

-- [ LIFECYCLE ]-------------------------------------------------------------------------------------
function Plugin:OnLoad()
    -- Create Container
    self.frame = CreateFrame("Frame", "OrbitQueueStatusContainer", UIParent)
    self.frame:SetSize(45, 45) -- Approximate size of the eye
    self.frame:SetClampedToScreen(true) -- Prevent dragging off-screen
    self.frame.systemIndex = SYSTEM_ID
    self.frame.editModeName = "Queue Status"

    -- Anchor options: Allow anchoring but disable property sync
    self.frame.anchorOptions = {
        horizontal = true,
        vertical = true,
        syncScale = false,
        syncDimensions = false,
    }

    -- Default position (near MicroMenu usually)
    self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -250, 40)

    -- Register to Orbit
    OrbitEngine.Frame:AttachSettingsListener(self.frame, self, SYSTEM_ID)
    OrbitEngine.Frame:RestorePosition(self.frame, self, SYSTEM_ID)

    self:RegisterStandardEvents()
    self:RegisterVisibilityEvents()

    -- Neutralize immediately
    NeutralizeNativeAnchoring()

    -- Initial Capture
    self:ReparentAll()

    -- Watchdog: Ensure we keep ownership if Blizzard tries to steal it back
    if QueueStatusButton then
        hooksecurefunc(QueueStatusButton, "SetParent", function(btn, parent)
            -- Combat safe: QueueStatusButton is not protected
            if parent ~= self.frame and self.frame then
                -- Steal it back
                btn:SetParent(self.frame)
                -- Re-apply points just in case
                btn:ClearAllPoints()
                btn:SetPoint("CENTER", self.frame, "CENTER")
            end
        end)

        hooksecurefunc(QueueStatusButton, "SetPoint", function(btn)
            -- Combat safe
            if btn:GetParent() == self.frame then
                -- Ensure it is centered
                -- Check if point is correct?
                -- It's easier to just force it.
                -- Warning: Infinite loop risk if we don't check first.
                local point, relativeTo, relativePoint, x, y = btn:GetPoint()
                if relativeTo ~= self.frame or point ~= "CENTER" then
                    -- Force it
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
    -- Combat safe

    if button:GetParent() ~= self.frame then
        button:SetParent(self.frame)
        -- Don't force Show() here, respect native state logic (it hides involves no queue)
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", self.frame, "CENTER")
end

function Plugin:ReparentAll()
    -- Capture the main button
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
    -- Combat safe

    -- Ensure Neutralization
    NeutralizeNativeAnchoring()

    -- Capture
    self:ReparentAll()

    -- Get Settings
    local scale = self:GetSetting(SYSTEM_ID, "Scale") or 100
    local opacity = self:GetSetting(SYSTEM_ID, "Opacity") or 100

    -- Apply Visuals
    frame:SetScale(scale / 100)
    frame:SetAlpha(opacity / 100)

    -- Determine Visibility
    -- Native behavior: QueueStatusButton shows/hides itself based on LFG status.
    -- Orbit Container should probably show/hide to match?
    -- If the button is hidden, an empty container floating around is fine (invisible),
    -- unless it blocks clicks. 30x30 is small.
    -- Better: If in Edit Mode, ALWAYS show. If not, match button?
    -- Actually, frame is just a container. If button is hidden, frame is empty.
    -- In Edit Mode, Orbit overlay shows.
    -- So we just Show() frame always.
    frame:Show()

    -- Handle QueueStatusFrame (Dropdown/Tooltip) Anchoring
    if QueueStatusFrame and QueueStatusButton then
        QueueStatusFrame:ClearAllPoints()

        -- Smart Anchor Logic
        local x = frame:GetCenter()
        local screenWidth = GetScreenWidth()

        -- If button is invisible (no queue),GetCenter might be nil or old.
        -- But usually we re-anchor when it shows.

        if x then
            local growRight = (x < (screenWidth / 2))
            if growRight then
                QueueStatusFrame:SetPoint("BOTTOMLEFT", QueueStatusButton, "TOPRIGHT", 0, 0)
            else
                QueueStatusFrame:SetPoint("BOTTOMRIGHT", QueueStatusButton, "TOPLEFT", 0, 0)
            end
        end
    end

    -- Apply MouseOver
    self:ApplyMouseOver(frame, SYSTEM_ID)

    -- Force update of selection visuals (fix pixelation on scale change)
    if OrbitEngine.FrameSelection then
        OrbitEngine.FrameSelection:ForceUpdate(frame)
    end
end
