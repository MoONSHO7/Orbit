---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Bar v2")

-- [ ALERT TOASTS ]-----------------------------------------------------------------------------------
-- One hooksecurefunc on AlertFrame_ShowNewAlert that recognises the reward alert templates by their
-- SetUp-populated fields, captures the rendered icon + name, dismisses Blizzard's frame (taint-free, like
-- the social/loot hooks), and replays the moment as a centre icon flourish through the queue. The
-- matchers are precise id-field checks so they never claim social (TopLine/BottomLine) or loot (lootItem)
-- frames — those keep their own hooks.
local function Tex(t) return t and t.GetTexture and t:GetTexture() or nil end
local function Txt(t) return t and t.GetText and t:GetText() or nil end

-- Ordered; first match wins. get(frame) -> iconTexture, name, FlourishColors key.
local MATCHERS = {
    { -- achievement earned
      detect = function(f) return f.Shield and f.Unlocked and f.Name end,
      get = function(f) return Tex(f.Shield.Icon), Txt(f.Name), "gold" end },
    { -- new recipe learned
      detect = function(f) return f.tradeSkillID and f.Name and f.Icon end,
      get = function(f) return Tex(f.Icon), Txt(f.Name), "collect" end },
    { -- collectibles: mount / pet / toy / transmog appearance / warband scene
      detect = function(f) return (f.mountID or f.petID or f.toyID or f.itemModifiedAppearanceID or f.warbandSceneID) and (f.Name or f.Title) and f.Icon end,
      get = function(f) return Tex(f.Icon), Txt(f.Name or f.Title), "collect" end },
    { -- housing decor earned
      detect = function(f) return f.DecorName and f.Icon end,
      get = function(f) return Tex(f.Icon), Txt(f.DecorName), "gold" end },
    { -- entitlement delivered (store / warband-bound)
      detect = function(f) return f.payloadID and f.Title and f.Icon end,
      get = function(f) return Tex(f.Icon), Txt(f.Title), "gold" end },
}

local function DismissAlert(frame)
    if frame.animIn then frame.animIn:Stop() end
    if frame.glow and frame.glow.animIn then frame.glow.animIn:Stop() end
    if frame.shine and frame.shine.animIn then frame.shine.animIn:Stop() end
    if frame.waitAndAnimOut then frame.waitAndAnimOut:Stop() end
    frame:Hide()
end

function Plugin:SetupAlertToasts()
    if not AlertFrame_ShowNewAlert or self._alertToastsHooked then return end
    self._alertToastsHooked = true
    local plugin = self
    hooksecurefunc("AlertFrame_ShowNewAlert", function(frame)
        if not frame or plugin._disabled or not plugin:GetSetting(plugin.system, "ShowRewardToasts") then return end
        for _, m in ipairs(MATCHERS) do
            if m.detect(frame) then
                local icon, name, colorKey = m.get(frame)
                DismissAlert(frame)
                if name and name ~= "" then
                    plugin:PlayIconFlourish(icon, plugin.FlourishColors[colorKey], name)
                end
                return
            end
        end
    end)
end

-- [ TEST COMMAND ]-----------------------------------------------------------------------------------
SLASH_ORBITTOAST1 = "/orbittoast"
SlashCmdList["ORBITTOAST"] = function()
    Plugin:PlayIconFlourish(134400, Plugin.FlourishColors.collect, L.PLU_SB_V2_REWARD_TEST)   -- a sample icon
end
