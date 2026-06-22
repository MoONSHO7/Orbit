---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Bar v2")

-- [ SOCIAL TOAST ]-----------------------------------------------------------------------------------
-- BN-friend / session-time / voice toasts all inherit SocialToastTemplate and display through the
-- global AlertFrame_ShowNewAlert(frame) after their FontStrings are set. We override it, recognise
-- those frames by their template structure, capture Blizzard's already-localised text, suppress the
-- toast, and replay it as a center flourish. Non-social alerts (achievements, loot, ...) pass through.
local LINE_KEYS = { "TopLine", "MiddleLine", "DoubleLine", "BottomLine" }

local function IsSocialToast(frame)
    return frame and frame.TopLine and frame.BottomLine and frame.CloseButton
end

local function CaptureLines(frame)
    local lines = {}
    for _, key in ipairs(LINE_KEYS) do
        local fs = frame[key]
        if fs and fs:IsShown() then
            local text = fs:GetText()
            if text and text ~= "" then lines[#lines + 1] = text end
        end
    end
    return lines[1], lines[2]
end

-- The toast's icon (BN logo / game / invite) is a sprite-sheet region; replicate texture + texcoords.
local function CaptureIcon(frame)
    local it = frame.IconTexture
    if it and it:IsShown() then
        local tex = it:GetTexture()
        if tex then return tex, { it:GetTexCoord() } end
    end
end

-- Dismiss a just-shown alert the way right-click does (stop its anims + hide) — no flash, since the
-- post-hook runs in the same execution before the next render.
local function DismissAlert(frame)
    if frame.animIn then frame.animIn:Stop() end
    if frame.glow and frame.glow.animIn then frame.glow.animIn:Stop() end
    if frame.shine and frame.shine.animIn then frame.shine.animIn:Stop() end
    if frame.waitAndAnimOut then frame.waitAndAnimOut:Stop() end
    frame:Hide()
end

function Plugin:SetupSocialToast()
    if not AlertFrame_ShowNewAlert or self._socialHooked then return end
    self._socialHooked = true

    local plugin = self
    -- hooksecurefunc, NOT a global replacement: replacing the Blizzard global taints it and bleeds into
    -- secure paths (e.g. EditMode party-frame refresh -> secret health-colour compare). The original runs
    -- (showing the toast), then we capture + dismiss it before it renders, taint-free.
    hooksecurefunc("AlertFrame_ShowNewAlert", function(frame)
        if not plugin._disabled and IsSocialToast(frame) and plugin:GetSetting(plugin.system, "ReplaceSocialToast") then
            local title, subtitle = CaptureLines(frame)
            local iconTex, coords = CaptureIcon(frame)
            DismissAlert(frame)   -- BN sound already played in ShowToast; only the visual is suppressed
            if title then plugin:PlaySocialFlourish(title, subtitle, iconTex, coords) end
        end
    end)
end

-- Replacing the toasts only works if Blizzard still GENERATES them for us to intercept. The master CVar
-- showToastWindow gates the whole BN toast system (read once into SetToastsEnabled at VARIABLES_LOADED,
-- with NO live CVar callback), so when our replacement is on we force it on AND re-register the events so
-- it takes hold this session rather than only after a /reload. Per-type prefs (showToastOnline, ...) are
-- left to the user. Called from ApplySettings, so it re-asserts on login and whenever the setting changes.
function Plugin:EnforceToastCVar()
    if not self:GetSetting(self.system, "ReplaceSocialToast") then return end
    if GetCVarBool("showToastWindow") then return end
    SetCVar("showToastWindow", "1")
    if BNToastFrame and BNToastFrame.SetToastsEnabled then BNToastFrame:SetToastsEnabled(true) end
end

-- [ TEST COMMAND ]-----------------------------------------------------------------------------------
-- Dev affordance: proc a sample social flourish with the Battle.net icon in the centre.
SLASH_ORBITSOCIAL1 = "/orbitsocial"
SlashCmdList["ORBITSOCIAL"] = function()
    Plugin:PlaySocialFlourish(L.PLU_SB_V2_SOCIAL_TEST, "", "Interface\\ChatFrame\\UI-ChatIcon-BattleNet")
end
