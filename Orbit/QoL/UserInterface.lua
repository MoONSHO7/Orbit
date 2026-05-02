-- [ USER INTERFACE TWEAKS ] -------------------------------------------------------------------------
local _, Orbit = ...
local Engine = Orbit.Engine

-- [ MODULE ]-----------------------------------------------------------------------------------------
Orbit.UserInterface = {}
local UI = Orbit.UserInterface

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local SCALE_MIN = 0.30
local SCALE_MAX = 1.15
local SCALE_STEP = 0.01
local CVAR_FLOOR = 0.65
local APPLY_DELAY = 0.5

-- [ APPLY ]------------------------------------------------------------------------------------------
-- Below CVAR_FLOOR, the CVar clamps but UIParent:SetScale honors the lower value — that's how addons
-- like ElvUI break Blizzard's 0.65 floor for pixel-perfect rendering on 1440p+ monitors.
local function Apply(scale)
    local cvarValue = scale < CVAR_FLOOR and CVAR_FLOOR or scale
    SetCVar("useUiScale", "1")
    SetCVar("uiScale", tostring(cvarValue))
    UIParent:SetScale(scale)
    Orbit.EventBus:Fire("ORBIT_DISPLAY_SIZE_CHANGED")
end

local function Clamp(scale)
    if scale < SCALE_MIN then return SCALE_MIN end
    if scale > SCALE_MAX then return SCALE_MAX end
    return scale
end

function UI:SetScale(scale)
    scale = Clamp(scale)
    Orbit.CombatManager:QueueUpdate(function() Apply(scale) end)
    if Orbit.db and Orbit.db.AccountSettings then
        Orbit.db.AccountSettings.UIScale = scale
    end
end

function UI:GetScale()
    local saved = Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.UIScale
    if saved then return saved end
    return UIParent:GetScale()
end

-- Pixel-perfect = WOW_REFERENCE_HEIGHT / physicalHeight; one logical pixel maps to one physical pixel.
function UI:GetPixelPerfectScale()
    return Clamp(Engine.Pixel:GetScale())
end

function UI:ScaleRange()
    return SCALE_MIN, SCALE_MAX, SCALE_STEP
end

local KNOWN_RESOLUTIONS = {
    [3840] = { [2160] = "4K" },
    [2560] = { [1440] = "2K" },
    [1920] = { [1080] = "1080p" },
    [1680] = { [1050] = "WSXGA+" },
    [1366] = { [768]  = "HD" },
}

function UI:GetResolution()
    local w, h = GetPhysicalScreenSize()
    local row = KNOWN_RESOLUTIONS[w]
    local label = row and row[h] or string.format("%dx%d", w, h)
    return label, w, h
end

-- [ AUTO-APPLY ON LOGIN ]----------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    C_Timer.After(APPLY_DELAY, function()
        local saved = Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.UIScale
        if saved then UI:SetScale(saved) end
    end)
    loader:UnregisterAllEvents()
end)
