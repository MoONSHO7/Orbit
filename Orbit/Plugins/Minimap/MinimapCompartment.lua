-- Minimap Addon Compartment
-- Collects all LibDBIcon minimap buttons + legacy minimap children into a hover-reveal drawer.

---@type Orbit
local Orbit = Orbit
local SYSTEM_ID = "Orbit_Minimap"
local Plugin = Orbit:GetPlugin(SYSTEM_ID)

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local BORDER_COLOR = Orbit.MinimapConstants.BORDER_COLOR
local COMPARTMENT_BUTTON_SIZE = 24
local COMPARTMENT_ICON_SIZE = 20
local COMPARTMENT_ROW_HEIGHT = 22
local COMPARTMENT_PADDING = 6
local COMPARTMENT_ICON_PADDING = 4
local COMPARTMENT_MAX_WIDTH = 220
local COMPARTMENT_HIGHLIGHT_TEXTURE = 136810 -- Blizzard white highlight (Interface\BUTTONS\WHITE8x8)

-- Blizzard-owned children of Minimap that must never be collected into the compartment.
-- Includes reparented Blizzard frames (Missions, Difficulty, etc.) so they are never
-- accidentally swept up even if timing or parent-chain quirks expose them as Minimap children.
local BLIZZARD_MINIMAP_CHILDREN = {
    ["MinimapBackdrop"] = true,
    ["MinimapCompassTexture"] = true,
    ["OrbitMinimapCompartmentButton"] = true,
    ["OrbitMinimapCompartmentFlyout"] = true,
    ["ExpansionLandingPageMinimapButton"] = true,
}

-- Name-prefix patterns for map pin/POI overlay frames that get parented to Minimap
-- but are not addon buttons (HandyNotes, TomTom, Questie, GatherMate, etc.).
local PIN_FRAME_PATTERNS = {
    "^HandyNotes",
    "^TomTom",
    "^HereBeDragons",
    "^Questie",
    "^GatherMate",
    "^pin",
    "^Pin",
}

local function IsPinFrame(name)
    if not name then return false end
    for _, pat in ipairs(PIN_FRAME_PATTERNS) do
        if name:match(pat) then return true end
    end
    return false
end

-- Minimum button width to be considered a real addon button (map pins are typically <20px).
local MIN_BUTTON_SIZE = 20

-- [ COMPARTMENT BUTTON ]----------------------------------------------------------------------------

function Plugin:CreateCompartmentButton()
    if self._compartmentButton then return end
    local frame = self.frame

    -- Drawer toggle button (bottom-right corner of minimap, hidden until hover)
    -- Parented to Overlay so it renders above the Minimap render surface
    local btn = CreateFrame("Button", "OrbitMinimapCompartmentButton", frame.Overlay or frame)
    btn:SetSize(COMPARTMENT_BUTTON_SIZE, COMPARTMENT_BUTTON_SIZE)
    btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    btn:SetFrameLevel(frame:GetFrameLevel() + 10)
    btn.orbitOriginalWidth = COMPARTMENT_BUTTON_SIZE
    btn.orbitOriginalHeight = COMPARTMENT_BUTTON_SIZE

    -- Background
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints(btn)
    btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints(btn)
    btn.highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    btn.highlight:SetAlpha(0.5)
    btn.highlight:SetBlendMode("ADD")

    -- Atlas icon: Blizzard's map-filter funnel (same as used by World Map filter button)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)
    btn.icon:SetAtlas("Map-Filter-Button", false)

    btn.iconPushed = btn:CreateTexture(nil, "ARTWORK")
    btn.iconPushed:SetAllPoints(btn)
    btn.iconPushed:SetAtlas("Map-Filter-Button-down", false)
    btn.iconPushed:Hide()

    btn:SetScript("OnMouseDown", function() btn.icon:Hide(); btn.iconPushed:Show() end)
    btn:SetScript("OnMouseUp",   function() btn.iconPushed:Hide(); btn.icon:Show() end)

    -- Border
    Orbit.Skin:SkinBorder(btn, btn, 1, BORDER_COLOR)

    -- Start hidden; revealed on minimap hover
    btn:SetAlpha(0)

    btn:SetScript("OnClick", function() self:ToggleCompartmentFlyout() end)
    btn:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_LEFT")
        GameTooltip:SetText("Addon Buttons", 1, 1, 1)
        GameTooltip:AddLine("Click to expand addon buttons", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(b)
        GameTooltip:Hide()
    end)

    self._compartmentButton = btn
end

-- [ COMPARTMENT FLYOUT ]----------------------------------------------------------------------------

function Plugin:CreateCompartmentFlyout()
    if self._compartmentFlyout then return end

    local flyout = CreateFrame("Frame", "OrbitMinimapCompartmentFlyout", self.frame)
    flyout:SetFrameStrata(Orbit.Constants.Strata.Dialog)
    flyout:SetFrameLevel(self.frame:GetFrameLevel() + 20)
    flyout:SetClampedToScreen(true)
    flyout:Hide()

    -- Background
    flyout.bg = flyout:CreateTexture(nil, "BACKGROUND")
    flyout.bg:SetAllPoints(flyout)
    local c = Orbit.db.GlobalSettings.BackdropColour or { r = 0.145, g = 0.145, b = 0.145, a = 0.7 }
    flyout.bg:SetColorTexture(c.r, c.g, c.b, 0.95)

    -- Border
    Orbit.Skin:SkinBorder(flyout, flyout, Orbit.db.GlobalSettings.BorderSize or 2, BORDER_COLOR)

    -- Close on click-away via fullscreen overlay
    local overlay = CreateFrame("Button", nil, UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata(Orbit.Constants.Strata.Dialog)
    overlay:SetFrameLevel(flyout:GetFrameLevel() - 1)
    overlay:Hide()
    overlay:RegisterForClicks("AnyUp")
    overlay:SetScript("OnClick", function() flyout:Hide() end)
    flyout._clickOverlay = overlay

    flyout:SetScript("OnShow", function(f) f._clickOverlay:Show() end)
    flyout:SetScript("OnHide", function(f) f._clickOverlay:Hide() end)

    flyout.rows = {}
    self._compartmentFlyout = flyout
end

function Plugin:ToggleCompartmentFlyout()
    if not self._compartmentFlyout then
        self:CreateCompartmentFlyout()
    end
    local flyout = self._compartmentFlyout

    if flyout:IsShown() then
        flyout:Hide()
        return
    end

    self:PopulateCompartmentFlyout()
    flyout:Show()
end

function Plugin:PopulateCompartmentFlyout()
    local flyout = self._compartmentFlyout
    if not flyout then return end
    local btn = self._compartmentButton
    local anchor = btn and btn:IsShown() and btn or self.frame

    -- Hide existing rows
    for _, row in ipairs(flyout.rows) do
        row:Hide()
    end

    local collected = self._collectedButtons or {}
    if #collected == 0 then
        flyout:SetSize(140, 30)
        flyout:ClearAllPoints()
        flyout:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 2)
        if not flyout._emptyText then
            flyout._emptyText = flyout:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            flyout._emptyText:SetPoint("CENTER")
            flyout._emptyText:SetText("No addon buttons found")
        end
        flyout._emptyText:Show()
        return
    end
    if flyout._emptyText then flyout._emptyText:Hide() end

    local maxTextWidth = 0
    for i, entry in ipairs(collected) do
        local row = flyout.rows[i]
        if not row then
            row = CreateFrame("Button", nil, flyout)
            row:SetHeight(COMPARTMENT_ROW_HEIGHT)
            row:RegisterForClicks("AnyUp")
            row:SetHighlightTexture(COMPARTMENT_HIGHLIGHT_TEXTURE, "ADD")
            row:GetHighlightTexture():SetAlpha(0.15)

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(COMPARTMENT_ICON_SIZE, COMPARTMENT_ICON_SIZE)
            row.icon:SetPoint("LEFT", COMPARTMENT_PADDING, 0)

            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", row.icon, "RIGHT", COMPARTMENT_ICON_PADDING, 0)
            row.label:SetJustifyH("LEFT")

            flyout.rows[i] = row
        end

        -- Icon
        local iconTexture = entry.icon
        if iconTexture then
            if type(iconTexture) == "string" and C_Texture.GetAtlasInfo(iconTexture) then
                row.icon:SetAtlas(iconTexture)
            else
                row.icon:SetTexture(iconTexture)
            end
            row.icon:SetTexCoord(0, 1, 0, 1)
            row.icon:Show()
        else
            row.icon:Hide()
        end

        -- Label
        local displayName = entry.name or "Unknown"
        row.label:SetText(displayName)
        Orbit.Skin:SkinText(row.label, { font = Orbit.db.GlobalSettings.Font, textSize = 11 })

        local textWidth = row.label:GetStringWidth()
        if textWidth > maxTextWidth then
            maxTextWidth = textWidth
        end

        -- Click handler: trigger the original addon button's OnClick
        -- RegisterForClicks("AnyUp") is set on row creation so right-clicks are received.
        row:SetScript("OnClick", function(_, button)
            if not entry.button then return end
            local btn = entry.button
            local b = button or "LeftButton"
            if btn.dataObject and btn.dataObject.OnClick then
                btn.dataObject.OnClick(btn, b)
            elseif btn:GetScript("OnClick") then
                btn:GetScript("OnClick")(btn, b)
            end
            -- Close flyout on left-click; leave open on right-click so context
            -- menus (which open over the flyout) can appear without losing context.
            if b ~= "RightButton" then
                flyout:Hide()
            end
        end)

        -- Tooltip passthrough
        row:SetScript("OnEnter", function(r)
            if not entry.button then return end
            local btn = entry.button
            local obj = btn.dataObject
            if obj and obj.OnTooltipShow then
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                obj.OnTooltipShow(GameTooltip)
                GameTooltip:Show()
            elseif obj and obj.OnEnter then
                obj.OnEnter(btn)
            elseif btn:GetScript("OnEnter") then
                btn:GetScript("OnEnter")(btn)
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
            local btn = entry.button
            if btn then
                local obj = btn.dataObject
                if obj and obj.OnLeave then
                    obj.OnLeave(btn)
                elseif btn:GetScript("OnLeave") then
                    btn:GetScript("OnLeave")(btn)
                end
            end
        end)

        -- Position
        row:ClearAllPoints()
        if i == 1 then
            row:SetPoint("TOPLEFT", flyout, "TOPLEFT", 0, -COMPARTMENT_PADDING)
            row:SetPoint("TOPRIGHT", flyout, "TOPRIGHT", 0, -COMPARTMENT_PADDING)
        else
            row:SetPoint("TOPLEFT", flyout.rows[i - 1], "BOTTOMLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", flyout.rows[i - 1], "BOTTOMRIGHT", 0, 0)
        end
        row:Show()
    end

    -- Size flyout to fit content
    local rowWidth = COMPARTMENT_PADDING + COMPARTMENT_ICON_SIZE + COMPARTMENT_ICON_PADDING + maxTextWidth + COMPARTMENT_PADDING + 10
    local width = math.min(math.max(rowWidth, 120), COMPARTMENT_MAX_WIDTH)
    local height = (#collected * COMPARTMENT_ROW_HEIGHT) + (COMPARTMENT_PADDING * 2)
    flyout:SetSize(width, height)

    -- Position the flyout intelligently based on available screen space
    local scale = anchor:GetEffectiveScale()
    local screenW = GetScreenWidth() * UIParent:GetEffectiveScale()
    local screenH = GetScreenHeight() * UIParent:GetEffectiveScale()
    local btnLeft = anchor:GetLeft() * scale
    local btnRight = anchor:GetRight() * scale
    local btnTop = anchor:GetTop() * scale
    local btnBottom = anchor:GetBottom() * scale
    local flyW = width * scale
    local flyH = height * scale
    local gap = 2

    -- Vertical: prefer expanding upward; fall back to downward if not enough room above
    local spaceAbove = screenH - btnTop
    local spaceBelow = btnBottom
    local expandUp = (spaceAbove >= flyH + gap) or (spaceAbove >= spaceBelow)

    -- Horizontal: prefer aligning to the right edge; fall back to left alignment if it would clip
    local expandLeft = (btnRight + flyW) > screenW

    flyout:ClearAllPoints()
    if expandUp and not expandLeft then
        flyout:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, gap)
    elseif expandUp and expandLeft then
        flyout:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, gap)
    elseif not expandUp and not expandLeft then
        flyout:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -gap)
    else
        flyout:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
    end
end

-- [ BUTTON COLLECTION ]-----------------------------------------------------------------------------

function Plugin:CollectAddonButtons()
    self._collectedButtons = self._collectedButtons or {}
    local collected = self._collectedButtons

    -- Clear previous state
    for i = #collected, 1, -1 do
        collected[i] = nil
    end

    -- Track already-collected frame references so we don't double-collect
    local seen = {}

    -- 1) LibDBIcon registered buttons
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib then
        local ownButtonName = "Orbit"
        for name, button in pairs(lib.objects) do
            if name ~= ownButtonName then
                collected[#collected + 1] = {
                    name = name,
                    button = button,
                    icon = button.dataObject and button.dataObject.icon or nil,
                    source = "libdbicon",
                }
                seen[button] = true
            end
        end
    end

    -- 2) Children parented directly to Minimap that are NOT LibDBIcon (legacy addons).
    --    Also handles the edge case where LibDBIcon uses a Frame instead of a Button.
    local minimap = Minimap
    if minimap then
        for _, child in ipairs({ minimap:GetChildren() }) do
            if not seen[child] then
                local frameName = child:GetName()
                local isButton = child:IsObjectType("Button")
                local isLibDBFrame = (not isButton) and frameName and frameName:match("^LibDBIcon10_")

                if isButton or isLibDBFrame then
                    -- Skip Blizzard structural frames
                    local isBlizzard = false
                    if frameName then
                        isBlizzard = BLIZZARD_MINIMAP_CHILDREN[frameName]
                            or frameName:find("^Minimap") ~= nil
                            or frameName:find("^OrbitMinimap") ~= nil
                    end

                    -- Skip map pin / POI overlay frames (HandyNotes, TomTom, Questie, etc.)
                    local isPin = IsPinFrame(frameName)

                    -- Skip frames smaller than a real button (map pins are typically <20px)
                    local tooSmall = (child:GetWidth() or 0) < MIN_BUTTON_SIZE

                    if not isBlizzard and not isPin and not tooSmall then
                        local icon = nil
                        local btnIcon = child.icon or child.Icon
                        if btnIcon and btnIcon.GetTexture then
                            icon = btnIcon:GetTexture()
                        elseif child.GetNormalTexture and child:GetNormalTexture() then
                            icon = child:GetNormalTexture():GetTexture()
                        end
                        local displayName = frameName or tostring(child)
                        displayName = displayName:gsub("^LibDBIcon10_", "")
                        displayName = displayName:gsub("MinimapButton", "")
                        displayName = displayName:gsub("Minimap", "")
                        displayName = displayName:gsub("Button$", "")
                        if displayName == "" then displayName = frameName or "Unknown" end
                        collected[#collected + 1] = {
                            name = displayName,
                            button = child,
                            icon = icon,
                            source = "minimap_child",
                        }
                        seen[child] = true
                    end
                end
            end
        end
    end

    table.sort(collected, function(a, b) return (a.name or "") < (b.name or "") end)
end

function Plugin:HideCollectedButtons()
    if not self._collectedButtons then return end
    for _, entry in ipairs(self._collectedButtons) do
        if entry.button then
            entry.button:Hide()
            -- Prevent re-showing by addons that call Show() periodically.
            -- hooksecurefunc is taint-safe; the hook fires after the original Show().
            -- We hide immediately afterwards when the compartment is active.
            if not entry.button._orbitOnShowHooked then
                hooksecurefunc(entry.button, "Show", function(b)
                    if self._compartmentActive then
                        b:Hide()
                    end
                end)
                entry.button._orbitOnShowHooked = true
            end
            -- For direct minimap children, also suppress SetShown
            if entry.source == "minimap_child" and not entry.button._orbitSetShownHooked then
                hooksecurefunc(entry.button, "SetShown", function(b, shown)
                    if shown and self._compartmentActive then
                        b:Hide()
                    end
                end)
                entry.button._orbitSetShownHooked = true
            end
        end
    end
end

function Plugin:RestoreCollectedButtons()
    if not self._collectedButtons then return end
    for _, entry in ipairs(self._collectedButtons) do
        if entry.button then
            -- Hooks installed via hooksecurefunc cannot be removed; just clear the
            -- flag so the hook body becomes a no-op after the compartment is inactive.
            entry.button._orbitOnShowHooked = nil
            entry.button._orbitSetShownHooked = nil
            if not (entry.button.db and entry.button.db.hide) then
                entry.button:Show()
            end
        end
    end
    self._collectedButtons = nil
end

-- [ COMPARTMENT ORCHESTRATOR ]----------------------------------------------------------------------

function Plugin:ApplyAddonCompartment()
    local frame = self.frame
    local useClickAction = self:UsesAddonClickAction()

    if useClickAction or not self:IsComponentDisabled("Compartment") then
        self._compartmentActive = true
        -- Restore any previously-hooked buttons before re-collecting, so stale hooks
        -- (e.g. on frames that are no longer eligible) are cleaned up each cycle.
        self:RestoreCollectedButtons()
        self:CollectAddonButtons()
        self:HideCollectedButtons()

        -- Setup hover reveal for the compartment button
        local btn = self._compartmentButton
    if useClickAction then btn:Hide() else btn:Show() end

        if not frame._compartmentHoverHooked then
            local minimap = Minimap
            local function ShowCompartmentButton()
                if not btn:IsShown() then return end
                UIFrameFadeIn(btn, 0.15, btn:GetAlpha(), 1)
            end
            local function HideCompartmentButton()
                if not btn:IsShown() then return end
                if btn:IsMouseOver() then return end
                if minimap and minimap:IsMouseOver() then return end
                if self._compartmentFlyout and self._compartmentFlyout:IsShown() then return end
                UIFrameFadeOut(btn, 0.3, btn:GetAlpha(), 0)
            end
            frame:HookScript("OnEnter", ShowCompartmentButton)
            frame:HookScript("OnLeave", HideCompartmentButton)
            if minimap then
                minimap:HookScript("OnEnter", ShowCompartmentButton)
                minimap:HookScript("OnLeave", HideCompartmentButton)
            end
            btn:HookScript("OnEnter", ShowCompartmentButton)
            btn:HookScript("OnLeave", HideCompartmentButton)
            frame._compartmentHoverHooked = true
        end

        -- Re-collect when new addons attach buttons after the initial scan.
        if not self._addonLoadedHook then
            local f = CreateFrame("Frame")
            f:RegisterEvent("ADDON_LOADED")
            local pending = false
            f:SetScript("OnEvent", function()
                if pending then return end
                pending = true
                C_Timer.After(0.1, function()
                    pending = false
                    if self._compartmentActive then
                        self:RestoreCollectedButtons()
                        self:CollectAddonButtons()
                        self:HideCollectedButtons()
                    end
                end)
            end)
            self._addonLoadedHook = f
        end
    else
        self._compartmentActive = false
        self:RestoreCollectedButtons()
        if self._compartmentButton then self._compartmentButton:Hide() end
        if self._compartmentFlyout then self._compartmentFlyout:Hide() end
    end
end
