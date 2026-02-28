-- [ ACTION BARS - CONTAINER FACTORY ]--------------------------------------------------------------
---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine

local INITIAL_FRAME_SIZE = 40
local PET_BAR_INDEX = 9
local VEHICLE_EXIT_INDEX = 13
local VEHICLE_EXIT_ICON = "Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up"
local VEHICLE_EXIT_ICON_DOWN = "Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down"
local VEHICLE_EXIT_HIGHLIGHT = "Interface\\Buttons\\ButtonHilight-Square"
local VEHICLE_EXIT_TEXCOORDS = { 0.140625, 0.859375, 0.140625, 0.859375 }
local VEHICLE_EXIT_VISIBILITY = "[canexitvehicle] show; hide"
local BUTTON_SIZE = 36
local BASE_VISIBILITY_DRIVER = "[petbattle][vehicleui] hide; show"
local PET_BAR_BASE_DRIVER = "[petbattle][vehicleui] hide; [nopet] hide; show"
local BAR1_BASE_DRIVER = "[petbattle][overridebar] hide; show"

local function GetVisibilityDriver(baseDriver)
    return Orbit.MountedVisibility:GetMountedDriver(baseDriver)
end

Orbit.ActionBarsContainer = {}
local ABC = Orbit.ActionBarsContainer

function ABC:Create(plugin, config)
    local frame = CreateFrame("Frame", config.orbitName, UIParent, "SecureHandlerStateTemplate")
    frame:SetSize(INITIAL_FRAME_SIZE, INITIAL_FRAME_SIZE)
    frame.systemIndex = config.index
    frame.editModeName = config.label
    frame.blizzBarName = config.blizzName
    frame.isSpecial = config.isSpecial
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame.anchorOptions = { x = true, y = true, syncScale = false, syncDimensions = false }
    if config.index == PET_BAR_INDEX then RegisterStateDriver(frame, "visibility", GetVisibilityDriver(PET_BAR_BASE_DRIVER))
    elseif config.index ~= 1 then RegisterStateDriver(frame, "visibility", GetVisibilityDriver(BASE_VISIBILITY_DRIVER)) end
    OrbitEngine.Frame:AttachSettingsListener(frame, plugin, config.index)
    frame.Selection = frame:CreateTexture(nil, "OVERLAY")
    frame.Selection:SetColorTexture(1, 1, 1, 0.1)
    frame.Selection:SetAllPoints()
    frame.Selection:Hide()
    local yOffset = -150 - ((config.index - 1) * 50)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, yOffset)
    plugin.blizzBars[config.index] = _G[config.blizzName]
    frame.GetSpellFlyoutDirection = function(f)
        local direction = "UP"
        local screenHeight, screenWidth = GetScreenHeight(), GetScreenWidth()
        local x, y = f:GetCenter()
        if x and y then
            local isTop = y > (screenHeight / 2)
            local isLeft = x < (screenWidth / 2)
            direction = isTop and "DOWN" or "UP"
            if f:GetHeight() > f:GetWidth() then direction = isLeft and "RIGHT" or "LEFT" end
        end
        return direction
    end
    if config.index == 1 then
        local pagingDriver = table.concat({
            "[vehicleui] 12", "[overridebar] 14", "[possessbar] 12", "[shapeshift] 13",
            "[bar:2] 2", "[bar:3] 3", "[bar:4] 4", "[bar:5] 5", "[bar:6] 6",
            "[bonusbar:1] 7", "[bonusbar:2] 8", "[bonusbar:3] 9", "[bonusbar:4] 10", "[bonusbar:5] 11",
            "1",
        }, "; ")
        frame:SetAttribute("_onstate-page", [[ self:SetAttribute("actionpage", newstate); control:ChildUpdate("actionpage", newstate) ]])
        RegisterStateDriver(frame, "page", pagingDriver)
        RegisterStateDriver(frame, "visibility", BAR1_BASE_DRIVER)
    end
    frame:Show()
    if config.index ~= PET_BAR_INDEX then
        local enableHover = plugin:GetSetting(config.index, "ShowOnMouseover") ~= false
        Orbit.OOCFadeMixin:ApplyOOCFade(frame, plugin, config.index, "OutOfCombatFade", enableHover)
    end
    return frame
end

function ABC:CreateVehicleExit(plugin)
    if InCombatLockdown() then return end
    local container = CreateFrame("Frame", "OrbitVehicleExit", UIParent, "SecureHandlerStateTemplate")
    container:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    container.systemIndex = VEHICLE_EXIT_INDEX
    container.editModeName = "Vehicle Exit"
    container:EnableMouse(true)
    container:SetClampedToScreen(true)
    container.anchorOptions = { x = true, y = true, syncScale = false, syncDimensions = false }
    if OrbitEngine.Pixel then OrbitEngine.Pixel:Enforce(container) end
    container.Selection = container:CreateTexture(nil, "OVERLAY")
    container.Selection:SetColorTexture(1, 1, 1, 0.1)
    container.Selection:SetAllPoints()
    container.Selection:Hide()
    OrbitEngine.Frame:AttachSettingsListener(container, plugin, VEHICLE_EXIT_INDEX)
    local btn = CreateFrame("Button", "OrbitVehicleExitButton", container)
    btn:SetAllPoints(container)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetScript("OnClick", function() if UnitOnTaxi("player") then TaxiRequestEarlyLanding() else VehicleExit() end end)
    btn:SetNormalTexture(VEHICLE_EXIT_ICON)
    btn:GetNormalTexture():SetTexCoord(unpack(VEHICLE_EXIT_TEXCOORDS))
    btn:SetPushedTexture(VEHICLE_EXIT_ICON_DOWN)
    btn:GetPushedTexture():SetTexCoord(unpack(VEHICLE_EXIT_TEXCOORDS))
    btn:SetHighlightTexture(VEHICLE_EXIT_HIGHLIGHT, "ADD")
    btn:GetHighlightTexture():SetTexCoord(unpack(VEHICLE_EXIT_TEXCOORDS))
    local bar1 = plugin.containers[1]
    if bar1 then container:SetPoint("LEFT", bar1, "RIGHT", 4, 0)
    else container:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 40) end
    RegisterStateDriver(container, "visibility", VEHICLE_EXIT_VISIBILITY)
    plugin.containers[VEHICLE_EXIT_INDEX] = container
    plugin.vehicleExitButton = container
end

function ABC:ReparentButtons(plugin, index, barConfig)
    if InCombatLockdown() then return end
    local container = plugin.containers[index]
    local config = barConfig[index]
    if not plugin.blizzBars[index] and config then plugin.blizzBars[index] = _G[config.blizzName] end
    local blizzBar = plugin.blizzBars[index]
    if not container or not config then return end
    local buttons = {}
    for i = 1, config.count do
        local btn = _G[config.buttonPrefix .. i]
        if btn then table.insert(buttons, btn) end
    end
    if blizzBar then
        OrbitEngine.NativeFrame:SecureHide(blizzBar)
        if blizzBar.BorderArt and blizzBar.BorderArt.Hide then blizzBar.BorderArt:Hide() end
        if blizzBar.EndCaps and blizzBar.EndCaps.Hide then blizzBar.EndCaps:Hide() end
        if blizzBar.ActionBarPageNumber and blizzBar.ActionBarPageNumber.Hide then blizzBar.ActionBarPageNumber:Hide() end
    end
    if #buttons == 0 then return end
    plugin.buttons[index] = buttons
    for _, button in ipairs(buttons) do
        button:SetParent(container)
        button:Show()
        if config and config.buttonPrefix == "ExtraActionButton" and button.style then button.style:SetAlpha(0) end
    end
end
