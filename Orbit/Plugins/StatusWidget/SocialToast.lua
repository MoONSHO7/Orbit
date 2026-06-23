---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Widget")

-- [ SOCIAL TOAST ]-----------------------------------------------------------------------------------
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

-- Dismiss a just-shown alert as right-click does (stop anims + hide); no flash since the post-hook runs before the next render.
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
    -- hooksecurefunc, NOT a global replacement: replacing the Blizzard global taints it and bleeds into secure paths (EditMode party-frame secret health-colour compare).
    hooksecurefunc("AlertFrame_ShowNewAlert", function(frame)
        if not plugin._disabled and IsSocialToast(frame) and plugin:GetSetting(plugin.system, "ReplaceSocialToast") then
            local title, subtitle = CaptureLines(frame)
            local iconTex, coords = CaptureIcon(frame)
            DismissAlert(frame)   -- BN sound already played in ShowToast; only the visual is suppressed
            if title then plugin:PlaySocialFlourish(title, subtitle, iconTex, coords) end
        end
    end)
end

-- showToastWindow is read only once at VARIABLES_LOADED with no live callback, so re-register events after forcing it to take hold without a /reload.
function Plugin:EnforceToastCVar()
    if not self:GetSetting(self.system, "ReplaceSocialToast") then return end
    if GetCVarBool("showToastWindow") then return end
    SetCVar("showToastWindow", "1")
    if BNToastFrame and BNToastFrame.SetToastsEnabled then BNToastFrame:SetToastsEnabled(true) end
end

-- [ TEST COMMAND ]-----------------------------------------------------------------------------------
SLASH_ORBITSOCIAL1 = "/orbitsocial"
SlashCmdList["ORBITSOCIAL"] = function()
    Plugin:PlaySocialFlourish(L.PLU_SB_V2_SOCIAL_TEST, "", "Interface\\ChatFrame\\UI-ChatIcon-BattleNet")
end
