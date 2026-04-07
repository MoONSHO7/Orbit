-- Minimap Addon Compartment
-- Collects all LibDBIcon minimap buttons + legacy minimap children into a flyout drawer.
-- Uses the REPARENT approach: actual addon buttons are reparented into our container,
-- preserving their native click handlers, tooltips, and right-click menus intact.
-- Inspired by MinimapButtonButton (MBB) — the most reliable method for minimap button collection.

---@type Orbit
local Orbit = Orbit
local SYSTEM_ID = "Orbit_Minimap"
local Plugin = Orbit:GetPlugin(SYSTEM_ID)

-- [ CONSTANTS ]-------------------------------------------------------------------------------------

local BORDER_COLOR = Orbit.MinimapConstants.BORDER_COLOR
local COMPARTMENT_BUTTON_SIZE = 24
local COMPARTMENT_PADDING = 6
local FLYOUT_BUTTON_SIZE = 28       -- Size for each reparented button in the flyout grid
local FLYOUT_BUTTON_SPACING = 2     -- Spacing between buttons in the grid
local FLYOUT_COLUMNS = 6            -- Number of columns in the flyout grid

-- No-op function used to block addons from repositioning their buttons
local function doNothing() end

-- Blizzard-owned children of Minimap that must never be collected into the compartment.
-- Includes reparented Blizzard frames (Missions, Difficulty, etc.) so they are never
-- accidentally swept up even if timing or parent-chain quirks expose them as Minimap children.
local BLIZZARD_MINIMAP_CHILDREN = {
    ["MinimapBackdrop"] = true,
    ["MinimapCompassTexture"] = true,
    ["OrbitMinimapCompartmentButton"] = true,
    ["OrbitMinimapCompartmentFlyout"] = true,
    ["OrbitMinimapButtonHolder"] = true,
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

local function NormalizeCompartmentDisplayName(name)
    local displayName = name or "Unknown"
    displayName = displayName:gsub("^LibDBIcon10_", "")
    displayName = displayName:gsub("MinimapButton", "")
    displayName = displayName:gsub("Minimap", "")
    displayName = displayName:gsub("Button$", "")
    if displayName == "" then
        displayName = name or "Unknown"
    end
    return displayName
end

local function BuildCollectedButtonSignature(name, icon)
    if type(icon) ~= "string" or icon == "" then return nil end
    return string.lower((name or "unknown")) .. "|" .. icon
end

-- Minimum button width to be considered a real addon button (map pins are typically <20px).
local MIN_BUTTON_SIZE = 20

-- Store references to the real frame methods before we override them
local FrameClearAllPoints = UIParent.ClearAllPoints
local FrameSetPoint = UIParent.SetPoint

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

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints(btn)
    btn.highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    btn.highlight:SetAlpha(0.5)
    btn.highlight:SetBlendMode("ADD")

    -- Atlas icon: Blizzard's map-filter funnel (same as used by World Map filter button)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)
    btn.icon:SetAtlas("Map-Filter-Button", false)

    -- Setup visual for canvas mode
    btn.visual = btn.icon

    btn.iconPushed = btn:CreateTexture(nil, "ARTWORK")
    btn.iconPushed:SetAllPoints(btn)
    btn.iconPushed:SetAtlas("Map-Filter-Button-down", false)
    btn.iconPushed:Hide()

    btn:SetScript("OnMouseDown", function() btn.icon:Hide(); btn.iconPushed:Show() end)
    btn:SetScript("OnMouseUp",   function() btn.iconPushed:Hide(); btn.icon:Show() end)

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

-- [ HIDDEN BUTTON HOLDER ]--------------------------------------------------------------------------
-- A hidden frame that holds reparented addon buttons while the compartment is active.
-- Buttons are reparented here instead of being hidden via Hide(), which avoids all
-- Show/Hide hook issues. The holder is always hidden, so buttons inside it are invisible.

function Plugin:GetOrCreateButtonHolder()
    if self._buttonHolder then return self._buttonHolder end

    local holder = CreateFrame("Frame", "OrbitMinimapButtonHolder", UIParent)
    holder:SetSize(1, 1)
    holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)  -- offscreen
    holder:Hide()

    self._buttonHolder = holder
    return holder
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
    overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    overlay:SetScript("OnClick", function() self:HideCompartmentFlyout() end)
    flyout._clickOverlay = overlay

    flyout:SetScript("OnShow", function(f) f._clickOverlay:Show() end)
    flyout:SetScript("OnHide", function(f)
        f._clickOverlay:Hide()
        -- When flyout closes, reparent buttons back to the hidden holder
        self:RetractButtonsToHolder()
    end)

    self._compartmentFlyout = flyout
end

function Plugin:ToggleCompartmentFlyout()
    if not self._compartmentFlyout then
        self:CreateCompartmentFlyout()
    end
    local flyout = self._compartmentFlyout

    if flyout:IsShown() then
        self:HideCompartmentFlyout()
        return
    end

    self:ShowCompartmentFlyout()
end

function Plugin:HideCompartmentFlyout()
    if self._compartmentFlyout then
        self._compartmentFlyout:Hide()
    end
end

function Plugin:ShowCompartmentFlyout()
    if not self._compartmentFlyout then
        self:CreateCompartmentFlyout()
    end
    local flyout = self._compartmentFlyout

    self:LayoutButtonsInFlyout()
    flyout:Show()
end

-- [ FLYOUT LAYOUT ]---------------------------------------------------------------------------------
-- Reparent the actual buttons into the flyout and arrange them in a grid.
-- No proxy rows, no click forwarding — buttons handle everything natively.

function Plugin:LayoutButtonsInFlyout()
    local flyout = self._compartmentFlyout
    if not flyout then return end
    local btn = self._compartmentButton
    local anchor = btn and btn:IsShown() and btn or self.frame

    local collected = self._collectedButtons or {}
    -- Count visible buttons (respect LibDBIcon .db.hide)
    local visibleEntries = {}
    for _, entry in ipairs(collected) do
        if entry.button then
            local hidden = entry.button.db and entry.button.db.hide
            if not hidden then
                visibleEntries[#visibleEntries + 1] = entry
            end
        end
    end

    if #visibleEntries == 0 then
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

    local cols = math.min(FLYOUT_COLUMNS, #visibleEntries)
    local rows = math.ceil(#visibleEntries / cols)
    local cellSize = FLYOUT_BUTTON_SIZE + FLYOUT_BUTTON_SPACING

    local flyoutWidth = (cols * cellSize) + FLYOUT_BUTTON_SPACING + (COMPARTMENT_PADDING * 2)
    local flyoutHeight = (rows * cellSize) + FLYOUT_BUTTON_SPACING + (COMPARTMENT_PADDING * 2)
    flyout:SetSize(flyoutWidth, flyoutHeight)

    -- Reparent each button into the flyout and position in grid
    for i, entry in ipairs(visibleEntries) do
        local button = entry.button
        if button then
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local xOff = COMPARTMENT_PADDING + FLYOUT_BUTTON_SPACING + (col * cellSize)
            local yOff = -(COMPARTMENT_PADDING + FLYOUT_BUTTON_SPACING + (row * cellSize))

            -- Reparent into flyout — this makes the button visible and clickable inside the flyout
            button:SetParent(flyout)
            button:SetFrameStrata(flyout:GetFrameStrata())
            button:SetFrameLevel(flyout:GetFrameLevel() + 2)

            -- Position in grid using stored real methods (we overrode ClearAllPoints/SetPoint)
            FrameClearAllPoints(button)
            FrameSetPoint(button, "TOPLEFT", flyout, "TOPLEFT", xOff, yOff)

            -- Normalize size
            button:SetSize(FLYOUT_BUTTON_SIZE, FLYOUT_BUTTON_SIZE)
            button:SetIgnoreParentScale(false)
            button:SetScale(1)

            -- Strip the circular minimap button border/overlay textures for a cleaner look.
            -- LibDBIcon buttons typically have overlay/border textures we can hide.
            if not button._orbitSkinned then
                -- Hide common minimap button decoration textures
                for _, region in ipairs({ button:GetRegions() }) do
                    if region:IsObjectType("Texture") then
                        local tex = region:GetTexture()
                        if tex and type(tex) == "string" then
                            local texLower = tex:lower()
                            if texLower:find("border") or texLower:find("trackingborder")
                                or texLower:find("minimap%-trackingborder") or texLower:find("overlay") then
                                region:SetTexture(nil)
                            end
                        end
                        -- Also hide by draw layer — OVERLAY is typically the ring/border
                        local layer = region:GetDrawLayer()
                        if layer == "OVERLAY" and region ~= (button.icon or button.Icon) then
                            region:SetAlpha(0)
                        end
                    end
                end
                button._orbitSkinned = true
            end

            -- Disable drag scripts on collected buttons (they shouldn't be draggable in the flyout)
            button:SetScript("OnDragStart", nil)
            button:SetScript("OnDragStop", nil)

            -- Show the button — it's now a child of the visible flyout
            button:Show()
        end
    end

    -- Position the flyout intelligently based on available screen space
    local scale = anchor:GetEffectiveScale()
    local screenW = GetScreenWidth() * UIParent:GetEffectiveScale()
    local screenH = GetScreenHeight() * UIParent:GetEffectiveScale()
    local btnLeft = anchor:GetLeft() * scale
    local btnRight = anchor:GetRight() * scale
    local btnTop = anchor:GetTop() * scale
    local btnBottom = anchor:GetBottom() * scale
    local flyW = flyoutWidth * scale
    local flyH = flyoutHeight * scale
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

-- [ RETRACT BUTTONS TO HOLDER ]---------------------------------------------------------------------
-- When the flyout closes, reparent all buttons back to the hidden holder frame.
-- They remain invisible (holder is hidden) but their frames still exist and can be
-- reparented back into the flyout when it re-opens.

function Plugin:RetractButtonsToHolder()
    local holder = self:GetOrCreateButtonHolder()
    local collected = self._collectedButtons or {}
    for _, entry in ipairs(collected) do
        if entry.button and entry.button:GetParent() ~= holder then
            entry.button:SetParent(holder)
        end
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
    local seenSignatures = {}

    -- 1) LibDBIcon registered buttons
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib then
        local ownButtonName = "Orbit"
        for name, button in pairs(lib.objects) do
            if name ~= ownButtonName then
                local displayName = NormalizeCompartmentDisplayName(name)
                local icon = button.dataObject and button.dataObject.icon or nil
                local signature = BuildCollectedButtonSignature(displayName, icon)
                if not signature or not seenSignatures[signature] then
                    collected[#collected + 1] = {
                        name = displayName,
                        button = button,
                        icon = icon,
                        source = "libdbicon",
                    }
                end
                if signature then seenSignatures[signature] = true end
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
                        local displayName = NormalizeCompartmentDisplayName(frameName or tostring(child))
                        local signature = BuildCollectedButtonSignature(displayName, icon)
                        if not signature or not seenSignatures[signature] then
                            collected[#collected + 1] = {
                                name = displayName,
                                button = child,
                                icon = icon,
                                source = "minimap_child",
                            }
                        end
                        if signature then seenSignatures[signature] = true end
                        seen[child] = true
                    end
                end
            end
        end
    end

    table.sort(collected, function(a, b) return (a.name or "") < (b.name or "") end)
end

-- [ GRAB / RELEASE BUTTONS ]------------------------------------------------------------------------
-- GrabCollectedButtons: reparents buttons to the hidden holder and blocks repositioning.
-- ReleaseCollectedButtons: restores buttons to Minimap with their original positioning.

function Plugin:GrabCollectedButtons()
    if not self._collectedButtons then return end
    local holder = self:GetOrCreateButtonHolder()

    for _, entry in ipairs(self._collectedButtons) do
        local button = entry.button
        if button then
            -- Save original parent and position so we can restore later
            if not button._orbitOrigParent then
                button._orbitOrigParent = button:GetParent()
                local n = button:GetNumPoints()
                if n > 0 then
                    button._orbitOrigPoints = {}
                    for i = 1, n do
                        button._orbitOrigPoints[i] = { button:GetPoint(i) }
                    end
                end
                button._orbitOrigWidth = button:GetWidth()
                button._orbitOrigHeight = button:GetHeight()
                button._orbitOrigScale = button:GetScale()
            end

            -- Reparent to hidden holder — this hides the button without calling Hide()
            button:SetParent(holder)
            button:SetFrameStrata(holder:GetFrameStrata())

            -- Block addons from moving their buttons back.
            -- Like MBB, we override the positioning methods with no-ops.
            if not button._orbitMethodsOverridden then
                button.ClearAllPoints = doNothing
                button.SetPoint = doNothing
                button.SetParent = doNothing
                button._orbitMethodsOverridden = true
            end

            -- Disable drag scripts
            button:SetScript("OnDragStart", nil)
            button:SetScript("OnDragStop", nil)
            button:SetIgnoreParentScale(false)
        end
    end
end

function Plugin:ReleaseCollectedButtons()
    if not self._collectedButtons then return end

    for _, entry in ipairs(self._collectedButtons) do
        local button = entry.button
        if button then
            -- Restore original frame methods
            if button._orbitMethodsOverridden then
                button.ClearAllPoints = nil  -- removes override, restores metatable method
                button.SetPoint = nil
                button.SetParent = nil
                button._orbitMethodsOverridden = nil
            end

            -- Restore original parent and position
            local origParent = button._orbitOrigParent
            if origParent then
                button:SetParent(origParent)

                if button._orbitOrigPoints then
                    button:ClearAllPoints()
                    for _, pt in ipairs(button._orbitOrigPoints) do
                        button:SetPoint(unpack(pt))
                    end
                end
                if button._orbitOrigWidth and button._orbitOrigHeight then
                    button:SetSize(button._orbitOrigWidth, button._orbitOrigHeight)
                end
                if button._orbitOrigScale then
                    button:SetScale(button._orbitOrigScale)
                end
            end

            -- Clean up saved state
            button._orbitOrigParent = nil
            button._orbitOrigPoints = nil
            button._orbitOrigWidth = nil
            button._orbitOrigHeight = nil
            button._orbitOrigScale = nil

            -- Show the button if it wasn't explicitly hidden by the addon
            if not (button.db and button.db.hide) then
                button:Show()
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
        -- Release any previously-grabbed buttons before re-collecting, so stale state
        -- (e.g. on frames that are no longer eligible) are cleaned up each cycle.
        self._compartmentActive = false
        self:ReleaseCollectedButtons()
        self._compartmentActive = true
        self:CollectAddonButtons()
        self:GrabCollectedButtons()

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
                        self:ReleaseCollectedButtons()
                        self:CollectAddonButtons()
                        self:GrabCollectedButtons()
                    end
                end)
            end)
            self._addonLoadedHook = f
        end
    else
        self._compartmentActive = false
        if self._compartmentFlyout then self._compartmentFlyout:Hide() end
        self:ReleaseCollectedButtons()
        if self._compartmentButton then self._compartmentButton:Hide() end
    end
end
