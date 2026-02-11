---@type Orbit
local Orbit = Orbit
local OrbitEngine = Orbit.Engine
local Constants = Orbit.Constants
local CooldownUtils = OrbitEngine.CooldownUtils

local CDM = Orbit:GetPlugin("Orbit_CooldownViewer")
if not CDM then return end

local VIEWER_MAP = CDM.viewerMap

-- [ FLASH OVERLAY HELPERS ]-------------------------------------------------------------------------
local FLASH_DURATION = 0.15

local function EnsureFlashOverlay(icon)
    if icon.orbitCDMFlash then return end
    local flashFrame = CreateFrame("Frame", nil, icon)
    flashFrame:SetAllPoints(icon)
    flashFrame:SetFrameLevel(icon:GetFrameLevel() + 3)
    flashFrame:Hide()

    local tex = flashFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetAllPoints(flashFrame)
    tex:SetColorTexture(1, 1, 1, 0.4)

    local fadeGroup = flashFrame:CreateAnimationGroup()
    fadeGroup:SetToFinalAlpha(true)
    local fadeOut = fadeGroup:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(FLASH_DURATION)
    fadeOut:SetSmoothing("OUT")
    fadeGroup:SetScript("OnFinished", function() flashFrame:Hide() end)

    icon.orbitCDMFlash = flashFrame
    icon.orbitCDMFlashTex = tex
    icon.orbitCDMFlashFade = fadeGroup
end

local function FlashIcon(icon, color)
    if not icon.orbitCDMFlash then return end
    icon.orbitCDMFlashTex:SetColorTexture(color.r, color.g, color.b, color.a or 0.4)
    icon.orbitCDMFlash:SetAlpha(1)
    icon.orbitCDMFlash:Show()
    icon.orbitCDMFlashFade:Play()
end

local function FindIconBySpellID(spellID)
    for _, entry in pairs(VIEWER_MAP) do
        local viewer = entry.viewer
        if viewer then
            for _, child in ipairs({ viewer:GetChildren() }) do
                if child:IsShown() and child.orbitCachedSpellID == spellID then return child end
            end
        end
    end
    return nil
end

-- Keypress flash via ActionButtonDown (fires on every keypress, even during cooldown/GCD)
hooksecurefunc("ActionButtonDown", function(id)
    local button = GetActionButtonForID(id)
    if not button or not button.action then return end
    local actionType, spellID = GetActionInfo(button.action)
    if actionType ~= "spell" or not spellID then return end
    local icon = FindIconBySpellID(spellID)
    if not icon or not icon.orbitCDMSystemIndex then return end
    local c = CDM:GetSetting(icon.orbitCDMSystemIndex, "KeypressColor") or { r = 1, g = 1, b = 1, a = 0 }
    FlashIcon(icon, c)
end)

-- [ PROCESS CHILDREN ]------------------------------------------------------------------------------
function CDM:ProcessChildren(anchor)
    if not anchor then return end

    local entry = VIEWER_MAP[anchor.systemIndex]
    local blizzFrame = entry and entry.viewer
    if not blizzFrame then return end

    local systemIndex = anchor.systemIndex
    local activeChildren = {}
    local plugin = self

    for _, child in ipairs({ blizzFrame:GetChildren() }) do
        if child.layoutIndex then
            if not child.orbitOnShowHooked then
                child:HookScript("OnShow", function(c)
                    local parent = c:GetParent()
                    local anc = parent and parent:GetParent()
                    if Orbit.Skin.Icons and Orbit.Skin.Icons.frameSettings then
                        local s = Orbit.Skin.Icons.frameSettings[parent]
                        if s then Orbit.Skin.Icons:ApplyCustom(c, s) end
                    end
                    if anc and plugin.ProcessChildren then plugin:ProcessChildren(anc) end
                end)
                child.orbitOnShowHooked = true
            end
            if child:IsShown() then table.insert(activeChildren, child) end
        end
    end

    table.sort(activeChildren, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)

    if Orbit.Skin.Icons and #activeChildren > 0 then
        local skinSettings = CooldownUtils:BuildSkinSettings(self, systemIndex, { verticalGrowth = self:GetGrowthDirection(anchor) })

        if not Orbit.Skin.Icons.frameSettings then Orbit.Skin.Icons.frameSettings = setmetatable({}, { __mode = "k" }) end
        Orbit.Skin.Icons.frameSettings[blizzFrame] = skinSettings

        for _, icon in ipairs(activeChildren) do
            Orbit.Skin.Icons:ApplyCustom(icon, skinSettings)
            self:HookGCDSwipe(icon, systemIndex)
            self:ApplyTextSettings(icon, systemIndex)
            icon.orbitCDMSystemIndex = systemIndex
            if not InCombatLockdown() and icon.GetSpellID then icon.orbitCachedSpellID = icon:GetSpellID() end
            EnsureFlashOverlay(icon)
        end

        Orbit.Skin.Icons:ApplyManualLayout(blizzFrame, activeChildren, skinSettings)

        if not InCombatLockdown() then
            local w, h = blizzFrame:GetSize()
            if w and h and w > 0 and h > 0 then anchor:SetSize(w, h) end
            anchor.orbitRowHeight = blizzFrame.orbitRowHeight
            anchor.orbitColumnWidth = blizzFrame.orbitColumnWidth
        end
    end
end

-- [ GCD SWIPE HOOK ]--------------------------------------------------------------------------------
function CDM:HookGCDSwipe(icon, systemIndex)
    if icon.orbitGCDHooked or not icon.RefreshSpellCooldownInfo then return end
    icon.orbitSystemIndex = systemIndex
    icon.orbitPlugin = self

    hooksecurefunc(icon, "RefreshSpellCooldownInfo", function(self)
        local plugin = self.orbitPlugin
        local sysIdx = self.orbitSystemIndex
        if not plugin or not sysIdx then return end

        local showGCD = plugin:GetSetting(sysIdx, "ShowGCDSwipe")
        if showGCD then return end

        if self.isOnGCD and not self.wasSetFromAura then
            local cooldown = self:GetCooldownFrame()
            if cooldown then cooldown:SetDrawSwipe(false) end
        end
    end)
    icon.orbitGCDHooked = true
end

-- [ GROWTH DIRECTION ]------------------------------------------------------------------------------
function CDM:GetGrowthDirection(anchorFrame)
    if not anchorFrame then return "DOWN" end
    local anchorInfo = OrbitEngine.FrameAnchor and OrbitEngine.FrameAnchor.anchors[anchorFrame]
    if not anchorInfo then return "DOWN" end
    return anchorInfo.edge == "TOP" and "UP" or "DOWN"
end
