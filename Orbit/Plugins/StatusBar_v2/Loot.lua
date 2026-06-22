---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local Plugin = Orbit:GetPlugin("Status Bar v2")

-- [ LOOT REEL ]--------------------------------------------------------------------------------------
-- The PLAYER'S OWN loot is replayed as a sequential reel through the orb's centre: each item's icon pops
-- in with a quality-coloured glow + its name beside the orb, then the next slides in. Encounter loot is
-- filtered to you (not the whole party); personal loot shows your own drops outside the encounter window.
local REEL_STEP = 1.2        -- seconds an item holds centre before the next slides in
local ENCOUNTER_WINDOW = 6   -- after your encounter loot, your personal SHOW_LOOT_TOAST is a dupe for this long
local FALLBACK_COLOR = { r = 0.62, g = 0.62, b = 0.62 }

-- An optional winner name (class-coloured) shown beneath an item. Your own loot has no winner line; this
-- is kept for the /orbitloot styling preview (and a possible future "show party loot" toggle).
local function ClassColoredName(playerName, className)
    if not playerName or playerName == "" then return nil end
    local cc = className and RAID_CLASS_COLORS and RAID_CLASS_COLORS[className]
    if not cc then return playerName end
    return ("|cff%02x%02x%02x%s|r"):format(cc.r * 255, cc.g * 255, cc.b * 255, playerName)
end

-- Resolve item display data (ContinueOnItemLoad fires immediately if cached) then queue a reel record.
local function EnqueueItem(itemLink, quantity, playerName, className)
    if not itemLink or itemLink == "" or not Item then return end
    local item = Item:CreateFromItemLink(itemLink)
    if item:IsItemEmpty() then return end
    item:ContinueOnItemLoad(function()
        if not Plugin.frame then return end
        local quality = item:GetItemQuality()
        local qc = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]) or FALLBACK_COLOR
        Plugin:PlayLootReel({ {
            icon = item:GetItemIcon(),
            title = item:GetItemName(),
            sub = ClassColoredName(playerName, className),
            count = quantity,
            color = { r = qc.r, g = qc.g, b = qc.b },
        } })
    end)
end

-- Append items and drive the reel through the flourish queue as one self-paced loot request that drains
-- the whole item queue. New items arriving mid-reel just append; loot is never interrupted by, nor
-- interrupts, another flourish — they serialize through the queue.
function Plugin:PlayLootReel(items)
    if not self.frame then return end
    self._lootQueue = self._lootQueue or {}
    for _, it in ipairs(items) do self._lootQueue[#self._lootQueue + 1] = it end
    if #self._lootQueue == 0 or self._lootActiveOrQueued then return end
    self._lootActiveOrQueued = true
    self:Enqueue({ kind = "loot", selfPaced = true, render = function(p) p:_LootReelStep() end })
end

function Plugin:_LootReelStep()
    local frame = self.frame
    local item = table.remove(self._lootQueue, 1)
    if not item then
        self._lootActiveOrQueued = false
        self:_FqBurstDone()   -- reel content done; queue applies the 3s buffer + idle linger
        return
    end
    if item.icon then
        frame.LootIcon:SetTexture(item.icon)
        frame.LootIcon:Show()
    else
        frame.LootIcon:Hide()
    end
    if item.count and item.count > 1 then
        frame.LootCount:SetText(item.count)
        frame.LootCount:Show()
    else
        frame.LootCount:Hide()
    end
    self:_PlayGlow(item.color)
    self:_ShowFlourishText(item.title, item.sub, item.color)
    self._lootTimer = C_Timer.NewTimer(REEL_STEP, function() self:_LootReelStep() end)
end

-- Called from _EnterEvent when a non-loot flourish takes the centre: drop the reel + its queue.
function Plugin:_CancelLootReel(name)
    if name == "loot" then return end
    if self._lootTimer then self._lootTimer:Cancel(); self._lootTimer = nil end
    self._lootActiveOrQueued = false
    if self._lootQueue then wipe(self._lootQueue) end
end

-- [ CAPTURE + SUPPRESSION ]--------------------------------------------------------------------------
local function IsEnabled()
    return not Plugin._disabled and Plugin:GetSetting(Plugin.system, "ReplaceLootToast")
end

-- A personal loot AlertFrame toast we replace: item wins (LootWonAlertFrame) and item upgrades
-- (LootUpgradeFrame). Currency rides the LootWon template too — leave it to Blizzard (out of reel scope).
local function IsLootAlert(frame)
    if not frame then return false end
    if frame.BaseQualityItemName then return true end
    return frame.lootItem and frame.ItemName and not frame.isCurrency
end

-- Dismiss a just-shown alert the way right-click does (stop its anims + hide); the post-hook runs in
-- the same execution before the next render, so there's no flash.
local function DismissAlert(frame)
    if frame.animIn then frame.animIn:Stop() end
    if frame.glow and frame.glow.animIn then frame.glow.animIn:Stop() end
    if frame.shine and frame.shine.animIn then frame.shine.animIn:Stop() end
    if frame.waitAndAnimOut then frame.waitAndAnimOut:Stop() end
    frame:Hide()
end

function Plugin:SetupLoot()
    if self._lootHooked then return end
    self._lootHooked = true
    self._lootQueue = {}

    -- Dedicated frame (never the shared EventBus): keeps any instance-fired loot dispatch isolated. Loot
    -- payloads are non-secret, so reading itemLink/playerName/className here is safe.
    local f = CreateFrame("Frame")
    f:RegisterEvent("BOSS_KILL")
    f:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
    f:RegisterEvent("SHOW_LOOT_TOAST")
    f:RegisterEvent("SHOW_LOOT_TOAST_UPGRADE")
    f:SetScript("OnEvent", function(_, event, ...) self:OnLootEvent(event, ...) end)
    self._lootFrame = f

    -- Suppress Blizzard's BossBanner; we replay encounter loot as the reel. Post-hook + Stop, never a
    -- global replace — mirrors the SocialToast taint fix. Data is captured independently via our frame.
    if BossBanner_Play and BossBanner_Stop then
        hooksecurefunc("BossBanner_Play", function(banner)
            if not IsEnabled() then return end
            BossBanner_Stop(banner)
            if TopBannerManager_BannerFinished then TopBannerManager_BannerFinished(banner) end
        end)
    end

    -- Suppress the personal loot AlertFrame toast: either we reel it (outside the window) or the group
    -- reel already covers it (inside). A second isolated hook, independent of SocialToast's.
    if AlertFrame_ShowNewAlert then
        hooksecurefunc("AlertFrame_ShowNewAlert", function(frame)
            if IsEnabled() and IsLootAlert(frame) then DismissAlert(frame) end
        end)
    end
end

function Plugin:_InEncounterWindow()
    return self._encounterUntil ~= nil and GetTime() < self._encounterUntil
end

-- True if an ENCOUNTER_LOOT_RECEIVED recipient is the LOCAL PLAYER — so the reel shows only your own loot,
-- not the whole party's. The event name is "Name" (same realm) or "Name-Realm" (cross-realm): match the
-- short name, and require the realm too when one is present.
local function IsLocalPlayerLoot(name)
    if not name or name == "" then return false end
    local short, realm = name:match("^([^%-]+)%-?(.*)$")
    if short ~= UnitName("player") then return false end
    if realm == "" then return true end
    local _, pRealm = UnitFullName("player")
    return not pRealm or pRealm == "" or realm:gsub("%s+", "") == pRealm:gsub("%s+", "")
end

-- ENCOUNTER_LOOT_RECEIVED args follow Blizzard's BossBanner (the generated docs mis-label 5-6 as
-- itemName/fileName): encounterID, itemID, itemLink, quantity, playerName, className.
function Plugin:OnLootEvent(event, ...)
    if not IsEnabled() then return end
    if event == "BOSS_KILL" then
        local _, name = ...
        self._encounterUntil = GetTime() + ENCOUNTER_WINDOW
        -- Enqueue the defeat banner now; it plays before the loot reel (which enqueues as items load).
        if name and name ~= "" then
            self:PlayBurst("BossBanner-SkullCircle", self.FlourishColors.defeat, L.PLU_SB_V2_DEFEATED_F:format(name))
        end
    elseif event == "ENCOUNTER_LOOT_RECEIVED" then
        local _, _, itemLink, quantity, playerName = ...
        if not IsLocalPlayerLoot(playerName) then return end   -- your own loot only, not the whole party
        local _, instanceType = GetInstanceInfo()
        if instanceType == "party" or instanceType == "raid" then
            self._encounterUntil = GetTime() + ENCOUNTER_WINDOW
            EnqueueItem(itemLink, quantity)   -- no winner line — it's you
        end
    elseif event == "SHOW_LOOT_TOAST" then
        local typeID, itemLink, quantity = ...
        if typeID == "item" and not self:_InEncounterWindow() then
            EnqueueItem(itemLink, quantity)
        end
    elseif event == "SHOW_LOOT_TOAST_UPGRADE" then
        local itemLink, quantity = ...
        if not self:_InEncounterWindow() then EnqueueItem(itemLink, quantity) end
    end
end

-- [ TEST COMMAND ]-----------------------------------------------------------------------------------
-- Dev affordance: reel a quality spread of YOUR OWN loot (no winner lines — matching the live behaviour),
-- one with a stack count. Item names/icons resolve live from the IDs.
SLASH_ORBITLOOT1 = "/orbitloot"
SlashCmdList["ORBITLOOT"] = function()
    local samples = {
        { id = 19019 },              -- Thunderfury (legendary)
        { id = 18832 },              -- Brutality Blade (epic)
        { id = 942 },                -- Silk Bandage (uncommon)
        { id = 6948,  count = 3 },   -- Hearthstone (common)
        { id = 2589,  count = 5 },   -- Linen Cloth (common)
    }
    for _, s in ipairs(samples) do
        EnqueueItem("item:" .. s.id, s.count or 1)
    end
end
