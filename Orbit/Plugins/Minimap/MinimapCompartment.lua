-- Minimap Addon Compartment — proxy-icon flyout for LibDBIcon + legacy minimap buttons.

---@type Orbit
local Orbit = Orbit
local L = Orbit.L
local SYSTEM_ID = "Orbit_Minimap"
local Plugin = Orbit:GetPlugin(SYSTEM_ID)

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local COMPARTMENT_BUTTON_SIZE = 24
local COMPARTMENT_PADDING = 6
local FLYOUT_BUTTON_SIZE = 28       -- Size for each proxy button in the flyout grid
local FLYOUT_BUTTON_SPACING = 2     -- Spacing between buttons in the grid
local FLYOUT_COLUMNS = 6            -- Number of columns in the flyout grid
local FLYOUT_GAP = 4                -- Pixel gap between flyout and minimap edge
local FLYOUT_CLOSE_DELAY = 0.35     -- Seconds of mouse-outside before auto-closing
local FADE_IN_DURATION = 0.15
local FADE_OUT_DURATION = 0.3
local HOLDER_OFFSCREEN = -500       -- Offscreen position for hidden button holder
local EMPTY_FLYOUT_W = 140
local EMPTY_FLYOUT_H = 30
local PRESSED_ALPHA = 0.6

-- No-op function used to block addons from repositioning their buttons
local function doNothing() end

-- True while any context/dropdown menu is open — covers both the modern Menu system and legacy UIDropDownMenu.
-- Used by the flyout auto-close timer to keep the flyout alive while the user is interacting with a menu
-- that was spawned from a proxy (e.g. right-click context menu); closing the flyout would orphan the menu's anchor.
local function IsAnyMenuOpen()
    if Menu and Menu.GetManager and Menu.GetManager():IsAnyMenuOpen() then return true end
    if DropDownList1 and DropDownList1:IsShown() then return true end
    if DropDownList2 and DropDownList2:IsShown() then return true end
    return false
end

-- Blizzard-owned Minimap children that must never be collected into the compartment.
-- Names without a "Minimap"/"MiniMap" prefix won't be caught by the generic prefix filter
-- below, so we enumerate them explicitly here.
local BLIZZARD_MINIMAP_CHILDREN = {
    ["MinimapBackdrop"] = true,
    ["MinimapCompassTexture"] = true,
    ["OrbitMinimapCompartmentButton"] = true,
    ["OrbitMinimapCompartmentFlyout"] = true,
    ["OrbitMinimapButtonHolder"] = true,
    ["ExpansionLandingPageMinimapButton"] = true,
    ["TimeManagerClockButton"] = true,
    ["GameTimeFrame"] = true,
    ["QueueStatusButton"] = true,
    ["BossBanner"] = true,
}

-- Name-prefix patterns for map pin/POI frames (not addon buttons).
local PIN_FRAME_PATTERNS = {
    "^HandyNotes",
    "^TomTom",
    "^HereBeDragons",
    "^Questie",
    "^GatherMate",
}

-- Candidate parent frames scanned for legacy (non-LibDBIcon) minimap buttons.
-- Only Minimap itself — that's where LibDBIcon parents its buttons and where
-- virtually all non-LDB third-party addons anchor. MinimapCluster / MinimapBackdrop
-- are Blizzard-structured and scanning them pulls in native frames like the clock.
local LEGACY_PARENTS = { "Minimap" }

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

-- Store references to raw frame methods before they are overridden on individual collected buttons.
local FrameSetParent      = UIParent.SetParent
local FrameClearAllPoints = UIParent.ClearAllPoints
local FrameSetPoint       = UIParent.SetPoint

-- [ COMPARTMENT BUTTON ]-----------------------------------------------------------------------------
function Plugin:CreateCompartmentButton()
    if self._compartmentButton then return end
    local frame = self.frame

    -- Drawer toggle — parented to Overlay so it renders above the Minimap surface
    local btn = CreateFrame("Button", "OrbitMinimapCompartmentButton", frame.Overlay or frame)
    btn:SetSize(COMPARTMENT_BUTTON_SIZE, COMPARTMENT_BUTTON_SIZE)
    btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    btn:SetFrameLevel(self.frame.ClickCapture:GetFrameLevel() + 2)
    btn.orbitOriginalWidth = COMPARTMENT_BUTTON_SIZE
    btn.orbitOriginalHeight = COMPARTMENT_BUTTON_SIZE

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints(btn)
    btn.highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    btn.highlight:SetAlpha(0.5)
    btn.highlight:SetBlendMode("ADD")

    -- Atlas icon: Blizzard's map-filter funnel
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)
    btn.icon:SetAtlas("Map-Filter-Button", false)

    -- Setup visual for canvas mode
    btn.visual = btn.icon

    btn:SetScript("OnMouseDown", function() btn.icon:SetAlpha(PRESSED_ALPHA) end)
    btn:SetScript("OnMouseUp",   function() btn.icon:SetAlpha(1) end)

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

-- [ HIDDEN BUTTON HOLDER ]---------------------------------------------------------------------------
function Plugin:GetOrCreateButtonHolder()
    if self._buttonHolder then return self._buttonHolder end

    local holder = CreateFrame("Frame", "OrbitMinimapButtonHolder", UIParent)
    holder:SetSize(1, 1)
    holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", HOLDER_OFFSCREEN, -HOLDER_OFFSCREEN)
    holder:Hide()

    self._buttonHolder = holder
    return holder
end

-- [ COMPARTMENT FLYOUT ]-----------------------------------------------------------------------------
function Plugin:CreateCompartmentFlyout()
    if self._compartmentFlyout then return end

    local flyout = CreateFrame("Frame", "OrbitMinimapCompartmentFlyout", self.frame)
    flyout:SetFrameStrata(Orbit.Constants.Strata.Dialog)
    flyout:SetFrameLevel(self.frame:GetFrameLevel() + 20)
    flyout:SetClampedToScreen(true)
    flyout:Hide()

    -- Backdrop texture — colour applied via ApplyCompartmentFlyoutSkin (called on every show).
    flyout.bg = flyout:CreateTexture(nil, "BACKGROUND")
    flyout.bg:SetAllPoints(flyout)
    self:ApplyCompartmentFlyoutSkin(flyout)

    -- Auto-close via OnUpdate polling when mouse leaves the flyout + minimap area.
    local outsideTimer = 0

    flyout:SetScript("OnUpdate", function(f, elapsed)
        if not f:IsShown() then return end

        local mouseOverFlyout = f:IsMouseOver()
        local mouseOverBtn = self._compartmentButton and self._compartmentButton:IsMouseOver()
        -- Use our container (not Minimap surface) — FarmHud reparents Minimap away from our frame.
        local mouseOverMinimap = self.frame:IsMouseOver()

        local tooltipShown = GameTooltip:IsShown() and GameTooltip:GetOwner() and GameTooltip:GetOwner():GetParent() == f  -- proxy tooltip open

        if mouseOverFlyout or mouseOverBtn or mouseOverMinimap or tooltipShown or f._tooltipForwardActive or IsAnyMenuOpen() then
            outsideTimer = 0
        else
            outsideTimer = outsideTimer + elapsed
            if outsideTimer >= FLYOUT_CLOSE_DELAY then
                outsideTimer = 0
                self:HideCompartmentFlyout()
            end
        end
    end)

    flyout:SetScript("OnShow", function(f) outsideTimer = 0; f._tooltipForwardActive = false end)
    flyout:SetScript("OnHide", function(f) outsideTimer = 0; f._tooltipForwardActive = false end)

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

    -- Re-apply global skin each open so theme changes (backdrop colour, border size/style/colour)
    -- take effect without a /reload.
    self:ApplyCompartmentFlyoutSkin(flyout)
    self:LayoutButtonsInFlyout()
    flyout:Show()
end

-- Pull backdrop colour + border size/style/colour from Orbit.db.GlobalSettings.
-- SkinBorder auto-resolves colour and nineslice style from globals when `color` is omitted.
function Plugin:ApplyCompartmentFlyoutSkin(flyout)
    flyout = flyout or self._compartmentFlyout
    if not flyout or not flyout.bg then return end

    local c = Orbit.db.GlobalSettings.BackdropColour or { r = 0.145, g = 0.145, b = 0.145, a = 0.7 }
    flyout.bg:SetColorTexture(c.r, c.g, c.b, c.a or 0.7)

    local borderSize = Orbit.db.GlobalSettings.BorderSize or 2
    Orbit.Skin:SkinBorder(flyout, flyout, borderSize)
end

-- [ FLYOUT LAYOUT ]----------------------------------------------------------------------------------
local proxyButtonPool = {}  -- Reusable pool of proxy buttons keyed by original button

local function GetProxyIcon(originalBtn)
    if originalBtn.icon and originalBtn.icon.GetTexture then
        local t = originalBtn.icon:GetTexture()
        if t then return t end
    end
    if originalBtn.dataObject and originalBtn.dataObject.icon then
        return originalBtn.dataObject.icon
    end
    for _, region in ipairs({ originalBtn:GetRegions() }) do
        if region and region:IsObjectType("Texture") then
            local t = region:GetTexture()
            if t and region ~= originalBtn.background and region ~= originalBtn.border then
                return t
            end
        end
    end
    if originalBtn.GetNormalTexture and originalBtn:GetNormalTexture() then
        return originalBtn:GetNormalTexture():GetTexture()
    end
    return nil
end

local function GetOrCreateProxyButton(originalBtn, parent)
    if proxyButtonPool[originalBtn] then
        local proxy = proxyButtonPool[originalBtn]
        proxy:SetParent(parent)
        proxy:SetSize(FLYOUT_BUTTON_SIZE, FLYOUT_BUTTON_SIZE)
        -- Refresh icon in case the addon updated it
        local tex = GetProxyIcon(originalBtn)
        if tex then proxy._icon:SetTexture(tex) end
        return proxy
    end

    local proxy = CreateFrame("Button", nil, parent)
    proxy:SetSize(FLYOUT_BUTTON_SIZE, FLYOUT_BUTTON_SIZE)
    -- Explicit strata so proxy renders above the flyout backdrop regardless of the original's strata.
    proxy:SetFrameStrata(parent:GetFrameStrata())
    proxy._originalBtn = originalBtn

    local icon = proxy:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    proxy._icon = icon

    local tex = GetProxyIcon(originalBtn)
    icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    if originalBtn.icon and originalBtn.icon.GetTexCoord then
        icon:SetTexCoord(originalBtn.icon:GetTexCoord())
    end
    icon:SetDesaturated(false)
    icon:SetAlpha(1)
    icon:SetVertexColor(1, 1, 1, 1)

    local highlight = proxy:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.15)

    proxy:RegisterForClicks("AnyUp")
    proxy:SetScript("OnClick", function(self, button, down)
        -- Pass proxy (self) not originalBtn so any dropdown/menu anchors to the visible button.
        local b = button or "LeftButton"
        local btn = originalBtn
        if btn.dataObject and btn.dataObject.OnClick then
            btn.dataObject.OnClick(self, b, down)
        elseif btn:GetScript("OnClick") then
            pcall(function() btn:GetScript("OnClick")(self, b, down) end)
        else
            pcall(function() btn:Click(b, down) end)
        end
    end)

    -- Forward press events for addons whose primary action is on mouse down/up rather than OnClick.
    proxy:SetScript("OnMouseDown", function(_, button)
        local s = originalBtn:GetScript("OnMouseDown")
        if s then pcall(function() s(originalBtn, button) end) end
    end)
    proxy:SetScript("OnMouseUp", function(_, button)
        local s = originalBtn:GetScript("OnMouseUp")
        if s then pcall(function() s(originalBtn, button) end) end
    end)

    proxy:SetScript("OnEnter", function(self)
        local flyout = self:GetParent()
        if flyout then flyout._tooltipForwardActive = true end

        if originalBtn.dataObject then
            local dObj = originalBtn.dataObject
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if dObj.OnTooltipShow then
                dObj.OnTooltipShow(GameTooltip)
            elseif dObj.text then
                GameTooltip:SetText(dObj.text)
            end
            GameTooltip:Show()
            return
        end

        local script = originalBtn:GetScript("OnEnter")
        if not script then return end
        -- Retarget SetOwner so the tooltip anchors to the visible proxy instead of the offscreen original.
        local tt = GameTooltip
        local origSetOwner = tt.SetOwner
        tt.SetOwner = function(t, owner, ...)
            if owner == originalBtn then return origSetOwner(t, self, ...) end
            return origSetOwner(t, owner, ...)
        end
        pcall(function() script(originalBtn) end)
        tt.SetOwner = origSetOwner
    end)
    proxy:SetScript("OnLeave", function(self)
        local flyout = self:GetParent()
        if flyout then flyout._tooltipForwardActive = false end
        GameTooltip:Hide()
        local script = originalBtn:GetScript("OnLeave")
        if script then pcall(function() script(originalBtn) end) end
    end)

    proxyButtonPool[originalBtn] = proxy
    return proxy
end

function Plugin:LayoutButtonsInFlyout()
    local flyout = self._compartmentFlyout
    if not flyout then return end

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

    -- Hide stale proxies from a previous layout pass.
    for _, proxy in pairs(proxyButtonPool) do
        proxy:Hide()
    end

    if #visibleEntries == 0 then
        if not flyout._emptyText then
            flyout._emptyText = flyout:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            flyout._emptyText:SetPoint("CENTER")
            flyout._emptyText:SetText(L.MSG_NO_ADDON_BUTTONS)
        end
        flyout._emptyText:Show()
        return
    end
    if flyout._emptyText then flyout._emptyText:Hide() end

    local n = #visibleEntries
    local cellSize = FLYOUT_BUTTON_SIZE + FLYOUT_BUTTON_SPACING
    local paddingTotal = FLYOUT_BUTTON_SPACING + (COMPARTMENT_PADDING * 2)

    -- Unconstrained size — used only to pick which side of the minimap the flyout anchors to.
    local unconstrainedCols = math.min(FLYOUT_COLUMNS, n)
    local unconstrainedRows = math.ceil(n / unconstrainedCols)
    local unconstrainedW = (unconstrainedCols * cellSize) + paddingTotal
    local unconstrainedH = (unconstrainedRows * cellSize) + paddingTotal

    local mmFrame = self.frame
    local scale = mmFrame:GetEffectiveScale()
    local uiScale = UIParent:GetEffectiveScale()
    local screenW = GetScreenWidth() * uiScale
    local screenH = GetScreenHeight() * uiScale
    local mmLeft = (mmFrame:GetLeft() or 0) * scale
    local mmRight = (mmFrame:GetRight() or screenW) * scale
    local mmTop = (mmFrame:GetTop() or screenH) * scale
    local mmBottom = (mmFrame:GetBottom() or 0) * scale
    local spaceLeft = mmLeft
    local spaceRight = screenW - mmRight
    local spaceAbove = screenH - mmTop
    local spaceBelow = mmBottom

    local anchor  -- "below" | "above" | "left" | "right"
    if spaceBelow >= unconstrainedH * scale + FLYOUT_GAP then anchor = "below"
    elseif spaceAbove >= unconstrainedH * scale + FLYOUT_GAP then anchor = "above"
    elseif spaceLeft >= unconstrainedW * scale + FLYOUT_GAP then anchor = "left"
    elseif spaceRight >= unconstrainedW * scale + FLYOUT_GAP then anchor = "right"
    else anchor = "below" end

    -- Match minimap dimension on the stacked axis so the drawer visually spans the minimap.
    local mmWidth = mmFrame:GetWidth()
    local mmHeight = mmFrame:GetHeight()
    local flyoutWidth, flyoutHeight, cols, rows
    if anchor == "below" or anchor == "above" then
        flyoutWidth = math.max(mmWidth, cellSize + paddingTotal)
        cols = math.max(1, math.floor((flyoutWidth - paddingTotal) / cellSize))
        rows = math.ceil(n / cols)
        flyoutHeight = (rows * cellSize) + paddingTotal
    else
        flyoutHeight = math.max(mmHeight, cellSize + paddingTotal)
        rows = math.max(1, math.floor((flyoutHeight - paddingTotal) / cellSize))
        cols = math.ceil(n / rows)
        flyoutWidth = (cols * cellSize) + paddingTotal
    end
    flyout:SetSize(flyoutWidth, flyoutHeight)

    -- Create/reuse proxy buttons with explicit strata so rendering is independent of the original button.
    for i, entry in ipairs(visibleEntries) do
        local originalBtn = entry.button
        if originalBtn then
            local proxy = GetOrCreateProxyButton(originalBtn, flyout)
            proxy:SetFrameLevel(flyout:GetFrameLevel() + 5)

            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local xOff = COMPARTMENT_PADDING + FLYOUT_BUTTON_SPACING + (col * cellSize)
            local yOff = -(COMPARTMENT_PADDING + FLYOUT_BUTTON_SPACING + (row * cellSize))

            proxy:ClearAllPoints()
            proxy:SetPoint("TOPLEFT", flyout, "TOPLEFT", xOff, yOff)
            proxy:Show()
        end
    end

    flyout:ClearAllPoints()
    if anchor == "below" then
        flyout:SetPoint("TOPRIGHT", mmFrame, "BOTTOMRIGHT", 0, -FLYOUT_GAP)
    elseif anchor == "above" then
        flyout:SetPoint("BOTTOMRIGHT", mmFrame, "TOPRIGHT", 0, FLYOUT_GAP)
    elseif anchor == "left" then
        flyout:SetPoint("TOPRIGHT", mmFrame, "TOPLEFT", -FLYOUT_GAP, 0)
    else
        flyout:SetPoint("TOPLEFT", mmFrame, "TOPRIGHT", FLYOUT_GAP, 0)
    end
end

-- [ BUTTON COLLECTION ]------------------------------------------------------------------------------
function Plugin:ScanParentChildren(parent, collected, seen, seenSignatures, seenNames)
    for _, child in ipairs({ parent:GetChildren() }) do
        if not seen[child] then
            local frameName = child:GetName()
            local isButton = child:IsObjectType("Button")
            local isLibDBFrame = (not isButton) and frameName and frameName:match("^LibDBIcon10_")

            if isButton or isLibDBFrame then
                local isBlizzard = false
                if frameName then
                    local lower = frameName:lower()
                    isBlizzard = BLIZZARD_MINIMAP_CHILDREN[frameName]
                        or lower:find("^minimap") ~= nil
                        or lower:find("^orbitminimap") ~= nil
                end
                local isPin = IsPinFrame(frameName)
                local tooSmall = (child:GetWidth() or 0) < MIN_BUTTON_SIZE
                local isProtected = child:IsProtected()
                local isHidden = not child:IsShown()

                if not isBlizzard and not isPin and not tooSmall and not isProtected and not isHidden then
                    -- Require a discoverable icon on the button itself (icon/Icon field, direct region, dataObject, or NormalTexture).
                    -- Addons that nest their icon on a child frame don't follow the standard pattern and are intentionally skipped.
                    local icon = GetProxyIcon(child)
                    if icon then
                        local displayName = NormalizeCompartmentDisplayName(frameName or tostring(child))
                        local signature = BuildCollectedButtonSignature(displayName, icon)
                        if (not signature or not seenSignatures[signature]) and not seenNames[displayName] then
                            collected[#collected + 1] = {
                                name = displayName,
                                button = child,
                                icon = icon,
                                source = "legacy_child",
                            }
                        end
                        if signature then seenSignatures[signature] = true end
                        seenNames[displayName] = true
                        seen[child] = true
                    end
                end
            end
        end
    end
end

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
    local seenNames = {}  -- catches duplicates even when icon is nil

    -- 1) LibDBIcon registered buttons
    --    Hidden entries are skipped so addons that register *both* an LDB button and a custom Minimap button
    --    (toggling between the two via LibDBIcon:Hide) aren't collected twice.
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib then
        local ownButtonName = "Orbit"
        for name, button in pairs(lib.objects) do
            if name ~= ownButtonName and button:IsShown() then
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
                seenNames[displayName] = true
                seen[button] = true
            end
        end
    end

    -- 2) Legacy (non-LibDBIcon) children of Minimap, MinimapCluster, and MinimapBackdrop.
    --    Also handles the edge case where LibDBIcon uses a Frame instead of a Button.
    for _, parentName in ipairs(LEGACY_PARENTS) do
        local parent = _G[parentName]
        if parent and parent.GetChildren then
            self:ScanParentChildren(parent, collected, seen, seenSignatures, seenNames)
        end
    end

    table.sort(collected, function(a, b) return (a.name or "") < (b.name or "") end)
end

-- [ GRAB / RELEASE BUTTONS ]-------------------------------------------------------------------------
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

            -- Reparent to hidden holder via raw SetParent (ours is overridden with doNothing)
            FrameSetParent(button, holder)
            button:SetFrameStrata(holder:GetFrameStrata())

            -- Block addons from repositioning their buttons back.
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

-- [ COMPARTMENT ORCHESTRATOR ]-----------------------------------------------------------------------
function Plugin:ApplyAddonCompartment()
    local frame = self.frame
    local useClickAction = self:UsesAddonClickAction()

    if useClickAction or not self:IsComponentDisabled("Compartment") then
        -- Release then re-collect to purge stale state each cycle.
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
                UIFrameFadeIn(btn, FADE_IN_DURATION, btn:GetAlpha(), 1)
            end
            local function HideCompartmentButton()
                if not btn:IsShown() then return end
                if btn:IsMouseOver() then return end
                if minimap and minimap:IsMouseOver() then return end
                if self._compartmentFlyout and self._compartmentFlyout:IsShown() then return end
                UIFrameFadeOut(btn, FADE_OUT_DURATION, btn:GetAlpha(), 0)
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

        -- Re-collect when new addons attach buttons after the initial scan, or when
        -- the player zones in and late-initialising addons finally show their button.
        if not self._rescanHook then
            local f = CreateFrame("Frame")
            f:RegisterEvent("ADDON_LOADED")
            f:RegisterEvent("PLAYER_ENTERING_WORLD")
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
            self._rescanHook = f
        end
    else
        self._compartmentActive = false
        if self._compartmentFlyout then self._compartmentFlyout:Hide() end
        self:ReleaseCollectedButtons()
        if self._compartmentButton then self._compartmentButton:Hide() end
    end
end
