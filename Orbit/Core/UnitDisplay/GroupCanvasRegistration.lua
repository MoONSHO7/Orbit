-- [ GROUP CANVAS REGISTRATION ]--------------------------------------------------------------------
-- Shared canvas mode component registration and icon position application for group frames

local _, Orbit = ...
local OrbitEngine = Orbit.Engine

Orbit.GroupCanvasRegistration = {}
local Reg = Orbit.GroupCanvasRegistration

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local STATUS_GROUP_KEYS = { "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" }

-- Propagates the StatusIcons grouped position to each individual status icon key.
function Reg:FanOutStatusIcons(positions)
    local sp = positions.StatusIcons
    if not sp then return end
    for _, subKey in ipairs(STATUS_GROUP_KEYS) do
        positions[subKey] = { anchorX = sp.anchorX, anchorY = sp.anchorY, offsetX = sp.offsetX, offsetY = sp.offsetY, justifyH = sp.justifyH, posX = sp.posX, posY = sp.posY }
    end
end

-- [ REGISTER COMPONENTS ]--------------------------------------------------------------------------
-- Registers text, icon, and aura container components on a group frame container for Canvas Mode.
local AURA_ICON_KEYS = { DefensiveIcon = true, CrowdControlIcon = true, PrivateAuraAnchor = true }

function Reg:RegisterComponents(plugin, container, firstFrame, textKeys, iconKeys, auraBaseIconSize)
    if not OrbitEngine.ComponentDrag or not firstFrame then return end

    for _, key in ipairs(textKeys) do
        local element = firstFrame[key]
        if element then
            OrbitEngine.ComponentDrag:Attach(element, container, {
                key = key,
                onPositionChange = OrbitEngine.ComponentDrag:MakePositionCallback(plugin, 1, key),
            })
        end
    end

    for _, key in ipairs(iconKeys) do
        local element = firstFrame[key]
        if element then
            local isAura = AURA_ICON_KEYS[key]
            OrbitEngine.ComponentDrag:Attach(element, container, {
                key = key, isAuraContainer = isAura or false,
                onPositionChange = isAura and OrbitEngine.ComponentDrag:MakeAuraPositionCallback(plugin, 1, key) or OrbitEngine.ComponentDrag:MakePositionCallback(plugin, 1, key),
            })
        end
    end

    -- StatusIcons: single grouped component that fans out to all 4 status icon keys
    if firstFrame.StatusIcons then
        OrbitEngine.ComponentDrag:Attach(firstFrame.StatusIcons, container, {
            key = "StatusIcons",
            onPositionChange = function(comp, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = plugin:GetSetting(1, "ComponentPositions") or {}
                positions.StatusIcons = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                Reg:FanOutStatusIcons(positions)
                plugin:SetSetting(1, "ComponentPositions", positions)
            end,
        })
    end

    for _, key in ipairs({ "Buffs", "Debuffs" }) do
        local containerKey = key == "Buffs" and "buffContainer" or "debuffContainer"
        if not firstFrame[containerKey] then
            firstFrame[containerKey] = CreateFrame("Frame", nil, firstFrame)
            firstFrame[containerKey]:SetSize(auraBaseIconSize, auraBaseIconSize)
        end
        OrbitEngine.ComponentDrag:Attach(firstFrame[containerKey], container, {
            key = key, isAuraContainer = true,
            onPositionChange = OrbitEngine.ComponentDrag:MakeAuraPositionCallback(plugin, 1, key),
        })
    end
end

-- [ APPLY ICON POSITIONS ]-------------------------------------------------------------------------
-- Applies saved component positions to all icon elements on each frame.
local AURA_POSITION_KEYS = { DefensiveIcon = true, CrowdControlIcon = true, PrivateAuraAnchor = true, Buffs = true, Debuffs = true, RaidBuff = true }
do local HR = Orbit.HealerAuraRegistry; if HR then for _, k in ipairs(HR:AllSlotKeys()) do AURA_POSITION_KEYS[k] = true end end end
function Reg:ApplyIconPositions(frames, savedPositions, iconKeys)
    if not savedPositions then return end
    local ApplyOverrides = OrbitEngine.OverrideUtils and OrbitEngine.OverrideUtils.ApplyOverrides
    local BuildAnchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint
    local BuildSelfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor
    for _, frame in ipairs(frames) do
        if frame.ApplyComponentPositions then
            frame:ApplyComponentPositions(savedPositions)
        end
        for _, iconKey in ipairs(iconKeys) do
            if frame[iconKey] and savedPositions[iconKey] then
                local pos = savedPositions[iconKey]
                local anchorX = pos.anchorX or "CENTER"
                local anchorY = pos.anchorY or "CENTER"
                local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
                local isAura = AURA_POSITION_KEYS[iconKey]
                local selfAnchor = isAura and BuildSelfAnchor(false, true, pos.selfAnchorY or anchorY, pos.justifyH or "CENTER") or "CENTER"

                local finalX = pos.offsetX or 0
                local finalY = pos.offsetY or 0
                if anchorX == "RIGHT" then finalX = -finalX end
                if anchorY == "TOP" then finalY = -finalY end

                frame[iconKey]:ClearAllPoints()
                frame[iconKey]:SetPoint(selfAnchor, frame, anchorPoint, finalX, finalY)
                if pos.overrides and ApplyOverrides then ApplyOverrides(frame[iconKey], pos.overrides) end
            end
        end
    end
end

-- [ PREPARE ICONS ]---------------------------------------------------------------------------------
-- Sets placeholder textures/atlases and sizes on frame icons so Canvas Mode can clone them.
-- healerSlots = HealerReg:ActiveSlots(), raidBuffs = HealerReg:ActiveRaidBuffs()
function Reg:PrepareIcons(plugin, frame, cfg, healerSlots, raidBuffs)
    local previewAtlases = Orbit.IconPreviewAtlases
    local StatusMixin = Orbit.StatusIconMixin
    for _, key in ipairs(cfg.statusIcons or {}) do
        if frame[key] then frame[key]:SetAtlas(previewAtlases[key]); frame[key]:SetSize(cfg.statusIconSize, cfg.statusIconSize) end
    end
    local savedPositions = plugin:GetSetting(1, "ComponentPositions") or {}
    for _, key in ipairs(cfg.roleIcons or {}) do
        if frame[key] then
            local atlas = previewAtlases[key]
            -- Respect HideDPS override for RoleIcon preview
            if key == "RoleIcon" then
                local roleOverrides = savedPositions.RoleIcon and savedPositions.RoleIcon.overrides
                if roleOverrides and roleOverrides.HideDPS then atlas = "UI-LFG-RoleIcon-Healer" end
            end
            if not frame[key]:GetAtlas() then frame[key]:SetAtlas(atlas) end
            frame[key]:SetSize(cfg.roleIconSize, cfg.roleIconSize)
        end
    end
    if frame.MarkerIcon then
        StatusMixin:ApplyMarkerSprite(frame.MarkerIcon, cfg.markerSpriteIndex or 8)
        frame.MarkerIcon.orbitSpriteIndex = cfg.markerSpriteIndex or 8
        frame.MarkerIcon.orbitSpriteRows = 4
        frame.MarkerIcon.orbitSpriteCols = 4
        frame.MarkerIcon:Show()
    end
    if frame.DefensiveIcon then
        frame.DefensiveIcon.Icon:SetTexture(StatusMixin:GetDefensiveTexture())
        frame.DefensiveIcon:SetSize(cfg.defensiveSize, cfg.defensiveSize)
        frame.DefensiveIcon:Show()
    end
    if frame.CrowdControlIcon then
        frame.CrowdControlIcon.Icon:SetTexture(StatusMixin:GetCrowdControlTexture())
        frame.CrowdControlIcon:SetSize(cfg.crowdControlSize, cfg.crowdControlSize)
        frame.CrowdControlIcon:Show()
    end
    if frame.PrivateAuraAnchor then
        frame.PrivateAuraAnchor:SetSize(cfg.privateAuraSize or cfg.defensiveSize, cfg.privateAuraSize or cfg.defensiveSize)
    end
    -- Create synthetic StatusIcons element for Canvas Mode creator to clone
    if not frame.StatusIcons then
        local si = CreateFrame("Button", nil, frame)
        si.Icon = si:CreateTexture(nil, "ARTWORK")
        si.Icon:SetAllPoints()
        si:SetSize(cfg.statusIconSize, cfg.statusIconSize)
        si.Icon:SetAtlas(previewAtlases.PhaseIcon or "RaidFrame-Icon-Phasing")
        si:Hide()
        frame.StatusIcons = si
    end
    if OrbitEngine.ComponentDrag and frame.StatusIcons and not frame.StatusIcons._canvasAttached then
        frame.StatusIcons._canvasAttached = true
        local container = frame:GetParent()
        OrbitEngine.ComponentDrag:Attach(frame.StatusIcons, container, {
            key = "StatusIcons",
            onPositionChange = function(comp, anchorX, anchorY, offsetX, offsetY, justifyH)
                local positions = plugin:GetSetting(1, "ComponentPositions") or {}
                positions.StatusIcons = { anchorX = anchorX, anchorY = anchorY, offsetX = offsetX, offsetY = offsetY, justifyH = justifyH }
                Reg:FanOutStatusIcons(positions)
                plugin:SetSetting(1, "ComponentPositions", positions)
            end,
        })
    end
    local container = frame:GetParent()
    local savedPositions = plugin:GetSetting(1, "ComponentPositions") or {}
    for _, slot in ipairs(healerSlots) do
        local slotPos = savedPositions[slot.key]
        local slotSize = (slotPos and slotPos.overrides and slotPos.overrides.IconSize) or cfg.healerAuraSize
        local icon = plugin:EnsureAuraIcon(frame, slot.key, slotSize)
        local tex = C_Spell.GetSpellTexture(slot.spellId)
        if tex then icon.Icon:SetTexture(tex) end
        icon:SetSize(slotSize, slotSize)
        icon:Show()
        if OrbitEngine.ComponentDrag and not icon._canvasAttached then
            icon._canvasAttached = true
            OrbitEngine.ComponentDrag:Attach(icon, container, { key = slot.key, isAuraContainer = true, onPositionChange = OrbitEngine.ComponentDrag:MakeAuraPositionCallback(plugin, 1, slot.key) })
        end
    end
    if raidBuffs and #raidBuffs > 0 then
        local rbPos = savedPositions["RaidBuff"]
        local rbSize = (rbPos and rbPos.overrides and rbPos.overrides.IconSize) or cfg.healerAuraSize
        local rb = plugin:EnsureRaidBuffContainer(frame, "RaidBuff", raidBuffs, rbSize)
        rb:Show()
        if OrbitEngine.ComponentDrag and not rb._canvasAttached then
            rb._canvasAttached = true
            OrbitEngine.ComponentDrag:Attach(rb, container, { key = "RaidBuff", isAuraContainer = true, onPositionChange = OrbitEngine.ComponentDrag:MakeAuraPositionCallback(plugin, 1, "RaidBuff") })
        end
    end
end

-- [ SHOW CANVAS MODE ICONS ]------------------------------------------------------------------------
-- Shows/hides canvas-mode preview icons during ApplyPreviewVisuals.
-- healerSlots = HealerReg:ActiveSlots(), raidBuffs = HealerReg:ActiveRaidBuffs()
-- healerKeys = HealerReg:ActiveKeys() (for hide path)
function Reg:ShowCanvasModeIcons(plugin, frame, isCanvasMode, cfg, healerSlots, raidBuffs, healerKeys)
    local isDisabled = plugin.IsComponentDisabled and function(k) return plugin:IsComponentDisabled(k) end or function() return false end
    if isCanvasMode then
        local previewAtlases = Orbit.IconPreviewAtlases or {}
        local savedPositions = plugin:GetComponentPositions(1)
        local StatusMixin = Orbit.StatusIconMixin
        local iconSize = cfg.statusIconSize
        local spacing = cfg.statusIconSpacing or (iconSize + 4)
        local statusIcons = cfg.statusIcons or { "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon" }
        -- Position all status icons at the grouped StatusIcons position (or default center)
        local groupPos = savedPositions.StatusIcons
        local BuildAnchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint
        for _, key in ipairs(statusIcons) do
            if frame[key] then
                frame[key]:SetAtlas(previewAtlases[key])
                frame[key]:SetSize(iconSize, iconSize)
                if groupPos then
                    local anchorX = groupPos.anchorX or "CENTER"
                    local anchorY = groupPos.anchorY or "CENTER"
                    local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
                    local finalX = groupPos.offsetX or 0
                    local finalY = groupPos.offsetY or 0
                    if anchorX == "RIGHT" then finalX = -finalX end
                    if anchorY == "TOP" then finalY = -finalY end
                    frame[key]:ClearAllPoints()
                    frame[key]:SetPoint("CENTER", frame, anchorPoint, finalX, finalY)
                elseif not savedPositions[key] then
                    frame[key]:ClearAllPoints()
                    frame[key]:SetPoint("CENTER", frame, "CENTER", 0, 0)
                end
                frame[key]:Show()
            end
        end
        local auraIconEntries = {
            { key = "DefensiveIcon", anchor = "LEFT", xMul = 0.5 },
            { key = "CrowdControlIcon", anchor = "TOP", yMul = -0.5 },
        }
        local ApplyTextPosition = OrbitEngine.PositionUtils.ApplyTextPosition
        for _, entry in ipairs(auraIconEntries) do
            local btn = frame[entry.key]
            if btn and not isDisabled(entry.key) then
                local texMethod = "Get" .. entry.key:gsub("Icon$", "") .. "Texture"
                btn.Icon:SetTexture(StatusMixin[texMethod](StatusMixin))
                btn:SetSize(iconSize, iconSize)
                local pos = savedPositions[entry.key]
                if pos then
                    ApplyTextPosition(btn, frame, pos, nil, nil, nil, true)
                else
                    btn:ClearAllPoints()
                    local xOff = OrbitEngine.Pixel:Snap((entry.xMul or 0) * (iconSize + 2), 1)
                    local yOff = OrbitEngine.Pixel:Snap((entry.yMul or 0) * (iconSize + 2), 1)
                    btn:SetPoint("CENTER", frame, entry.anchor, xOff, yOff)
                end
                if Orbit.Skin and Orbit.Skin.Icons then Orbit.Skin.Icons:ApplyCustom(btn, Orbit.Constants.Aura.SkinNoTimer) end
                btn:Show()
            elseif btn then btn:Hide() end
        end
        if frame.PrivateAuraAnchor then frame.PrivateAuraAnchor:Hide() end
        for _, slot in ipairs(healerSlots) do
            if not isDisabled(slot.key) then
                local slotPos = savedPositions[slot.key]
                local slotSize = (slotPos and slotPos.overrides and slotPos.overrides.IconSize) or cfg.healerAuraSize
                local hIcon = plugin:EnsureAuraIcon(frame, slot.key, slotSize)
                local tex = C_Spell.GetSpellTexture(slot.spellId)
                if tex then hIcon.Icon:SetTexture(tex) end
                hIcon:SetSize(slotSize, slotSize)
                if slotPos then ApplyTextPosition(hIcon, frame, slotPos, nil, nil, nil, true) end
                if Orbit.Skin and Orbit.Skin.Icons then Orbit.Skin.Icons:ApplyCustom(hIcon, Orbit.Constants.Aura.SkinNoTimer) end
                hIcon:Show()
            elseif frame[slot.key] then frame[slot.key]:Hide() end
        end
        if raidBuffs and #raidBuffs > 0 and not isDisabled("RaidBuff") then
            local rbPos = savedPositions["RaidBuff"]
            local rbSize = (rbPos and rbPos.overrides and rbPos.overrides.IconSize) or cfg.healerAuraSize
            local rb = plugin:EnsureRaidBuffContainer(frame, "RaidBuff", raidBuffs, rbSize)
            if rbPos then ApplyTextPosition(rb, frame, rbPos, nil, nil, nil, true) end
            rb:Show()
        elseif frame.RaidBuff then frame.RaidBuff:Hide() end
    else
        local hideKeys = cfg.hideKeys or { "PhaseIcon", "ReadyCheckIcon", "ResIcon", "SummonIcon", "DefensiveIcon", "CrowdControlIcon", "PrivateAuraAnchor" }
        for _, key in ipairs(hideKeys) do if frame[key] then frame[key]:Hide() end end
        for _, key in ipairs(healerKeys) do if frame[key] then frame[key]:Hide() end end
    end
end
