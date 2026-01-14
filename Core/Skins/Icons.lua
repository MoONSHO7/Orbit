local _, addonTable = ...
local Orbit = addonTable
local Skin = Orbit.Skin
local Icons = {}
Skin.Icons = Icons

local Constants = Orbit.Constants

local STANDARD_ACTION_BUTTON_SIZE = 45

local function ResetRegion(region)
    if region then
        region:SetAlpha(0)
        if region.Hide then
            region:Hide()
        end
    end
end

-- Weak-keyed tables: entries are auto-cleaned when frame keys are garbage collected
Icons.iconSettings = setmetatable({}, { __mode = "k" })
Icons.regionCache = setmetatable({}, { __mode = "k" })
Icons.borderCache = setmetatable({}, { __mode = "k" })
Icons.monitorTickers = {}

function Icons:ApplyManualLayout(frame, icons, settings)
    local padding = tonumber(settings.padding)
    if not padding then
        return
    end

    local limit = tonumber(settings.limit) or 10
    local orientation = tonumber(settings.orientation) or 0

    local totalIcons = #icons
    if totalIcons == 0 then
        return
    end

    local w, h = Constants.Skin.DefaultIconSize, Constants.Skin.DefaultIconSize
    if icons[1] then
        w, h = icons[1]:GetSize()
    end
    if w < 1 then
        w = 40
    end
    if h < 1 then
        h = 40
    end

    -- "Major" is the primary flow direction (Rows for Horiz, Cols for Vert)
    -- "Minor" is the secondary wrapping direction
    local majorCount, minorCount

    -- Calculate layout dimensions
    local numGroups = math.ceil(totalIcons / limit)

    if orientation == 0 then -- Horizontal (Row Major)
        minorCount = math.min(totalIcons, limit) -- Columns
        majorCount = numGroups -- Rows
    else -- Vertical (Column Major)
        majorCount = math.min(totalIcons, limit) -- Rows (actually items in col)
        minorCount = numGroups -- Cols
    end

    -- Calculate max dimensions for centering
    local maxMajorSize = (math.min(totalIcons, limit) * (orientation == 0 and w or h))
        + ((math.min(totalIcons, limit) - 1) * padding)

    for i, icon in ipairs(icons) do
        icon:ClearAllPoints()

        local groupIdx = math.floor((i - 1) / limit) -- 0..N (Row or Col index)
        local itemIdx = (i - 1) % limit -- 0..Limit-1 (Item within row/col)

        local col, row
        if orientation == 0 then
            row, col = groupIdx, itemIdx
        else
            col, row = groupIdx, itemIdx
        end

        -- Centering Logic
        local itemsInGroup = limit
        local itemsPrior = groupIdx * limit
        local itemsRemaining = totalIcons - itemsPrior
        if itemsRemaining < limit then
            itemsInGroup = itemsRemaining
        end

        local currentGroupSize = (itemsInGroup * (orientation == 0 and w or h)) + ((itemsInGroup - 1) * padding)
        local centeringOffset = (maxMajorSize - currentGroupSize) / 2

        local x = 0
        local y = 0

        if settings.verticalGrowth == "UP" then
            if orientation == 0 then
                x = centeringOffset + (col * (w + padding))
                y = row * (h + padding)
            else
                x = col * (w + padding)
                y = centeringOffset + (row * (h + padding))
            end
            icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, y)
        else
            if orientation == 0 then
                x = centeringOffset + (col * (w + padding))
                y = -row * (h + padding)
            else
                x = col * (w + padding)
                y = -(centeringOffset + (row * (h + padding)))
            end
            icon:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        end
    end

    -- Resize Container
    local finalCols, finalRows = 0, 0
    if orientation == 0 then
        finalCols = minorCount
        finalRows = majorCount
    else
        finalCols = minorCount
        finalRows = majorCount
    end

    -- Correction for correct container sizing logic
    if orientation == 0 then
        -- Horizontal: Width depends on columns, Height depends on rows
        finalCols = math.min(totalIcons, limit)
        finalRows = math.ceil(totalIcons / limit)
    else
        -- Vertical: Width depends on columns (groups), Height depends on rows (items)
        finalRows = math.min(totalIcons, limit)
        finalCols = math.ceil(totalIcons / limit)
    end

    local finalW = (finalCols * w) + ((finalCols - 1) * padding)
    local finalH = (finalRows * h) + ((finalRows - 1) * padding)

    if finalW < 1 then
        finalW = w
    end
    if finalH < 1 then
        finalH = h
    end

    local curW, curH = frame:GetSize()
    if math.abs(curW - finalW) > 1 or math.abs(curH - finalH) > 1 then
        frame._orbitResizing = true
        frame:SetSize(finalW, finalH)
        frame._orbitResizing = false
    end

    frame.orbitRowHeight = h
    frame.orbitColumnWidth = w
end

function Icons:Apply(frame, settings)
    if not frame then
        return
    end

    local CM = Orbit and Orbit.CombatManager
    if CM and CM:IsInCombat() then
        CM:QueueUpdate(function()
            self:Apply(frame, settings)
        end)
        return
    end

    self.frameSettings = self.frameSettings or setmetatable({}, { __mode = "k" })
    self.frameSettings[frame] = settings

    if not self.monitoredFrames then
        self.monitoredFrames = setmetatable({}, { __mode = "k" })
    end

    if not self.monitoredFrames[frame] then
        self:StartMonitoring(frame)
        self.monitoredFrames[frame] = true
    end

    self:SkinIcons(frame)
end

function Icons:StartMonitoring(frame)
    if not frame then
        return
    end
    -- Cancel existing ticker if any
    if self.monitorTickers[frame] then
        self.monitorTickers[frame]:Cancel()
        self.monitorTickers[frame] = nil
    end

    local lastIconCount = 0
    local monitorInterval = Constants.Timing.IconMonitorInterval

    self.monitorTickers[frame] = C_Timer.NewTicker(monitorInterval, function()
        if InCombatLockdown() then
            return
        end

        -- Cleanup check: stop monitoring if frame is gone or hidden for too long
        if not frame or not frame:IsShown() then
            -- Give hidden frames a grace period but cancel if they stay hidden
            if not frame then
                self:StopMonitoring(frame)
            end
            return
        end

        local icons = frame.GetLayoutChildren and frame:GetLayoutChildren() or { frame:GetChildren() }
        local currentCount = #icons

        if currentCount ~= lastIconCount then
            self:SkinIcons(frame)
            lastIconCount = currentCount
        end
    end)
end

-- Cleanup function for when frames are destroyed or no longer need monitoring
function Icons:StopMonitoring(frame)
    if self.monitorTickers[frame] then
        self.monitorTickers[frame]:Cancel()
        self.monitorTickers[frame] = nil
    end
    -- Also cleanup from monitoredFrames if we stored by key
end

function Icons:SkinIcons(frame)
    local CM = Orbit and Orbit.CombatManager
    if CM and CM:IsInCombat() then
        CM:QueueUpdate(function()
            self:SkinIcons(frame)
        end)
        return
    end

    local s = self.frameSettings and self.frameSettings[frame]
    if not s then
        return
    end

    local icons = {}
    if frame.GetLayoutChildren then
        icons = frame:GetLayoutChildren()
    elseif frame.icons then
        icons = frame.icons
    else
        icons = { frame:GetChildren() }
    end

    for _, icon in ipairs(icons) do
        if icon then
            if not self.iconSettings then
                self.iconSettings = setmetatable({}, { __mode = "k" })
            end
            self.iconSettings[icon] = s
            self:ApplyCustom(icon, s) -- Always use custom style
        end
    end

    if not InCombatLockdown() and s.padding then
        self:ApplyManualLayout(frame, icons, s)
    end
end

function Icons:FindRegions(icon)
    -- Use icon frame directly as key (enables weak-table GC)
    if self.regionCache[icon] then
        return self.regionCache[icon]
    end

    local regions = {
        icon = icon.Icon or icon.icon,
        cooldown = icon.Cooldown,
        outOfRange = icon.OutOfRange or icon.outOfRange,
        border = icon.Border or icon.IconBorder,
        proc = icon.SpellActivationAlert,
        pandemic = icon.PandemicIcon,
        mask = nil,
        masks = {},
    }

    if icon.IconMask then
        table.insert(regions.masks, icon.IconMask)
        regions.mask = icon.IconMask
    end

    local kids = { icon:GetRegions() }
    for _, region in ipairs(kids) do
        local objType = region:GetObjectType()
        if objType == "Texture" then
            local atlas = region:GetAtlas()
            local name = region:GetName()

            if atlas == Constants.Atlases.CooldownBorder then
                regions.border = region
            elseif not regions.icon then
                -- Priority: Name contains "Icon"
                if name and (string.find(name, "Icon") or string.find(name, "icon")) then
                    regions.icon = region
                end
            end
        elseif objType == "MaskTexture" then
            regions.mask = region
            local exists = false
            for _, m in ipairs(regions.masks) do
                if m == region then
                    exists = true
                    break
                end
            end
            if not exists then
                table.insert(regions.masks, region)
            end
        end
    end

    -- Final Fallback: First valid texture (BACKGROUND/BORDER/ARTWORK) if still no icon
    if not regions.icon then
        for _, region in ipairs(kids) do
            if region:IsObjectType("Texture") and region ~= regions.border and region ~= regions.procs then
                local layer = region:GetDrawLayer()
                if layer == "BACKGROUND" or layer == "BORDER" or layer == "ARTWORK" then
                    regions.icon = region
                    break
                end
            end
        end
    end

    local children = { icon:GetChildren() }
    for _, child in ipairs(children) do
        if
            not regions.flash
            and (child == icon.CooldownFlash or (child:GetName() and string.find(child:GetName(), "CooldownFlash")))
        then
            regions.flash = child
        end
        if not regions.proc and (child == icon.SpellActivationAlert) then
            regions.proc = child
        end
    end

    -- Use icon frame directly as key (enables weak-table GC)
    self.regionCache[icon] = regions
    return regions
end

function Icons:CalculateGeometry(frame, settings)
    if not frame then
        return Constants.Skin.DefaultIconSize, Constants.Skin.DefaultIconSize
    end
    local w, h = frame:GetSize()
    if w <= 0 then
        w = Constants.Skin.DefaultIconSize
    end

    local newWidth, newHeight = w, w
    local aspectRatio = settings and settings.aspectRatio or "1:1"
    local rw, rh = 1, 1

    if aspectRatio ~= "1:1" then
        local sw, sh = strsplit(":", aspectRatio)
        if sw and sh then
            rw, rh = tonumber(sw), tonumber(sh)
        elseif sw then
            -- Support decimal ratio (e.g. "1.5")
            local ratio = tonumber(sw)
            if ratio then
                rw, rh = ratio, 1
            end
        end
    end

    if rw ~= rh then
        newHeight = newWidth * (rh / rw)
    end
    return newWidth, newHeight, rw, rh
end

function Icons:ApplyCustom(icon, settings)
    local r = self:FindRegions(icon)
    local tex = r.icon

    if tex then
        local newWidth, newHeight, rw, rh = self:CalculateGeometry(icon, settings)

        -- Use generic OrbSkin for base icon skinning
        Skin:SkinIcon(tex, settings)

        -- Domain specific geometry & cropping
        local trim = Constants.Texture.BlizzardIconBorderTrim
        local zoom = settings.zoom or 0
        trim = trim + ((zoom / 100) / 2)
        local left, right, top, bottom = trim, 1 - trim, trim, 1 - trim
        local validW, validH = right - left, bottom - top

        if rw > rh then
            local newH = validW * (rh / rw)
            local centerY = (top + bottom) / 2
            top, bottom = centerY - (newH / 2), centerY + (newH / 2)
        elseif rh > rw then
            local newW = validH * (rw / rh)
            local centerX = (left + right) / 2
            left, right = centerX - (newW / 2), centerX + (newW / 2)
        end

        if tex.SetTexCoord then
            tex:SetTexCoord(left, right, top, bottom)
        end

        icon:SetSize(newWidth, newHeight)
        tex:ClearAllPoints()
        tex:SetAllPoints(icon)

        if r.masks then
            for _, mask in ipairs(r.masks) do
                if tex.RemoveMaskTexture then
                    tex:RemoveMaskTexture(mask)
                end
                mask:Hide()
            end
        elseif r.mask then -- Handle single mask case safely
            if tex.RemoveMaskTexture then
                tex:RemoveMaskTexture(r.mask)
            end
            r.mask:Hide()
        end

        if icon.IconMask then
            if tex.RemoveMaskTexture then
                tex:RemoveMaskTexture(icon.IconMask)
            end
            icon.IconMask:Hide()
        end

        if icon.spellOutOfRange then
            icon:RefreshIconColor()
        end

        if r.cooldown then
            r.cooldown:ClearAllPoints()
            r.cooldown:SetAllPoints(icon)

            -- Get desired swipe settings
            local desiredTexture = Constants.Assets.SwipeCustom
            local desiredColor = settings.swipeColor or { r = 0, g = 0, b = 0, a = 0.8 }

            -- Store desired values on cooldown for hooks to reference
            r.cooldown.orbitDesiredSwipe = {
                texture = desiredTexture,
                r = desiredColor.r,
                g = desiredColor.g,
                b = desiredColor.b,
                a = desiredColor.a,
            }

            -- Force-apply swipe settings immediately (for settings changes)
            r.cooldown.orbitUpdating = true
            r.cooldown:SetSwipeTexture(desiredTexture)
            if r.cooldown.SetSwipeColor then
                r.cooldown:SetSwipeColor(desiredColor.r, desiredColor.g, desiredColor.b, desiredColor.a)
            end
            r.cooldown.orbitUpdating = false

            -- Hook swipe setters directly to immediately catch Blizzard's resets
            -- This prevents the flash that occurs when waiting for SetCooldown hooks
            if not r.cooldown.orbitHooked then
                local cooldownRef = r.cooldown

                -- Hook SetSwipeTexture: if Blizzard sets wrong texture, immediately correct it
                hooksecurefunc(r.cooldown, "SetSwipeTexture", function(self, texture)
                    if self.orbitUpdating then
                        return
                    end
                    local desired = self.orbitDesiredSwipe
                    if not desired then
                        return
                    end

                    -- Only re-apply if Blizzard set a different texture
                    if texture ~= desired.texture then
                        self.orbitUpdating = true
                        self:SetSwipeTexture(desired.texture)
                        self.orbitUpdating = false
                    end
                end)

                -- Hook SetSwipeColor: if Blizzard sets wrong color, immediately correct it
                if r.cooldown.SetSwipeColor then
                    hooksecurefunc(r.cooldown, "SetSwipeColor", function(self, cr, cg, cb, ca)
                        if self.orbitUpdating then
                            return
                        end
                        local desired = self.orbitDesiredSwipe
                        if not desired then
                            return
                        end

                        -- Only re-apply if Blizzard set a different color
                        if cr ~= desired.r or cg ~= desired.g or cb ~= desired.b or ca ~= desired.a then
                            self.orbitUpdating = true
                            self:SetSwipeColor(desired.r, desired.g, desired.b, desired.a)
                            self.orbitUpdating = false
                        end
                    end)
                end

                r.cooldown.orbitHooked = true
            end
        end

        if r.flash then
            r.flash:ClearAllPoints()
            r.flash:SetAllPoints(icon)
            -- Raise above border (which uses MEDIUM strata)
            r.flash:SetFrameStrata("HIGH")
            r.flash:SetFrameLevel(50)
            if r.flash.Flipbook then
                r.flash.Flipbook:ClearAllPoints()
                r.flash.Flipbook:SetPoint("CENTER")
                r.flash.Flipbook:SetSize(
                    newWidth * Constants.IconScale.FlashScale,
                    newHeight * Constants.IconScale.FlashScale
                )
            end
        end

        if r.proc then
            r.proc:ClearAllPoints()
            r.proc:SetPoint("CENTER")
            r.proc:SetSize(newWidth * Constants.IconScale.ProcGlowScale, newHeight * Constants.IconScale.ProcGlowScale)
            -- Raise above border (which uses MEDIUM strata)
            r.proc:SetFrameStrata("HIGH")
            r.proc:SetFrameLevel(50)
        end

        if r.pandemic then
            r.pandemic:ClearAllPoints()
            r.pandemic:SetPoint("CENTER")
            r.pandemic:SetSize(
                newWidth + Constants.IconScale.PandemicPadding,
                newHeight + Constants.IconScale.PandemicPadding
            )
            -- Raise above border (which uses MEDIUM strata)
            r.pandemic:SetFrameStrata("HIGH")
            r.pandemic:SetFrameLevel(50)
        end

        local borderStyle = settings.borderStyle or 0
        local borderSize = settings.borderSize or 1

        if r.border then
            if borderStyle == 1 then
                r.border:SetAlpha(0)
            else
                r.border:SetAlpha(1)
                r.border:ClearAllPoints()
                r.border:SetPoint("CENTER")
                r.border:SetSize(
                    newWidth + Constants.IconScale.BorderPaddingH,
                    newHeight + Constants.IconScale.BorderPaddingV
                )
            end
        end

        if borderStyle == 1 then
            -- Use icon frame directly as key (enables weak-table GC)
            if not self.borderCache[icon] then
                self.borderCache[icon] = Skin:CreateBackdrop(icon, nil)
            end

            local b = self.borderCache[icon]
            -- Border should be: above icon/swipe, but below procs
            -- Use MEDIUM strata - procs use HIGH strata to appear above
            b:SetFrameStrata("MEDIUM")
            b:SetFrameLevel(icon:GetFrameLevel() + 5)
            b:Show()
            Skin:SkinBorder(icon, b, borderSize, { r = 0, g = 0, b = 0, a = 1 })
        else
            -- Use icon frame directly as key
            if self.borderCache[icon] then
                self.borderCache[icon]:Hide()
            end
        end
    end

    if icon.Cooldown and icon.Cooldown.SetHideCountdownNumbers then
        local hide = not (settings.showTimer ~= false)
        icon.Cooldown:SetHideCountdownNumbers(hide)
    end

    if icon.DebuffBorder then
        icon.DebuffBorder:SetAlpha(0)
        icon.DebuffBorder:Hide()
    end

    -- Tooltip Handling
    if settings.showTooltip == false then
        if not icon.orbitTooltipHooked then
            icon:HookScript("OnEnter", function(self)
                if GameTooltip:IsOwned(self) then
                    GameTooltip:Hide()
                end
            end)
            icon.orbitTooltipHooked = true
        end
    end
end

function Icons:ApplyActionButtonCustom(button, settings)
    if not button then
        return
    end

    local w, h = button:GetSize()

    -- Reset Blizzard textures using helper
    ResetRegion(button.NormalTexture)
    ResetRegion(button.PushedTexture)
    ResetRegion(button.HighlightTexture)
    ResetRegion(button.CheckedTexture)

    -- Fix: Re-anchor CheckedTexture (Selected/Active State) to match icon scale
    local checkedTexture = button.CheckedTexture
    if not checkedTexture and button.GetCheckedTexture then
        checkedTexture = button:GetCheckedTexture()
    end

    if checkedTexture then
        checkedTexture:ClearAllPoints()
        checkedTexture:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
        checkedTexture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -2)
        checkedTexture:SetAlpha(1)
        checkedTexture:SetDrawLayer("OVERLAY", 7)
    end

    ResetRegion(button.FloatingBG)
    ResetRegion(button.SlotBackground)
    ResetRegion(button.SlotArt)

    -- Create/update custom backdrop that fills to border
    if not button.orbitBackdrop then
        button.orbitBackdrop = button:CreateTexture(nil, "BACKGROUND", nil, Constants.Layers.BackdropDeep)
        local bgColor = settings.backdropColor or Constants.Colors.Background
        button.orbitBackdrop:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    end
    button.orbitBackdrop:SetDrawLayer("BACKGROUND", Constants.Layers.BackdropDeep)
    button.orbitBackdrop:ClearAllPoints()
    button.orbitBackdrop:SetAllPoints(button)

    local bgColor = settings.backdropColor or Constants.Colors.Background
    button.orbitBackdrop:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a)

    button.orbitBackdrop:Show()

    -- Resize icon texture
    local icon = button.icon or button.Icon
    if icon then
        icon:ClearAllPoints()
        icon:SetAllPoints(button)
    end

    -- Resize cooldown frame
    local cooldown = button.cooldown or button.Cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(button)
    end

    -- Resize proc glow (SpellActivationAlert)
    if button.SpellActivationAlert then
        button.SpellActivationAlert:ClearAllPoints()
        button.SpellActivationAlert:SetPoint("CENTER", button, "CENTER", 0, 0)
        local procScale = w * Constants.IconScale.ProcGlowScale
        button.SpellActivationAlert:SetSize(procScale, procScale)
        button.SpellActivationAlert:SetFrameStrata("HIGH")
        button.SpellActivationAlert:SetFrameLevel(Constants.Levels.ProcOverlay)
    end

    -- Resize autoCast shine
    -- Locate the frame (Standard buttons use AutoCastOverlay, others might use AutoCastFrame or Shine)
    local autoCast = button.AutoCastOverlay or button.AutoCastFrame or button.Shine
    if not autoCast and button:GetName() then
        autoCast = _G[button:GetName() .. "Shine"]
    end

    if autoCast then
        autoCast:ClearAllPoints()
        -- Match CheckedTexture offsets: Shift right to fix alignment (Left 0, Right 1)
        autoCast:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 1)
        autoCast:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
        autoCast:SetFrameStrata("HIGH")
        autoCast:SetFrameLevel(Constants.Levels.ProcOverlay)

        -- Also force the Shine texture inside (if accessible) to match
        if autoCast.Shine then
            autoCast.Shine:ClearAllPoints()
            autoCast.Shine:SetAllPoints(autoCast)
        end
        if autoCast.Corners then
            autoCast.Corners:ClearAllPoints()
            autoCast.Corners:SetAllPoints(autoCast)
        end
    end

    -- Scale casting overlays
    local scaleRatio = w / STANDARD_ACTION_BUTTON_SIZE

    local overlays = {
        button.TargetReticleAnimFrame,
        button.SpellCastAnimFrame,
        button.CooldownFlash,
        button.InterruptDisplay,
    }

    for _, overlay in ipairs(overlays) do
        if overlay then
            overlay:ClearAllPoints()
            overlay:SetPoint("CENTER", button, "CENTER", 0, 0)
            overlay:SetScale(scaleRatio)
        end
    end

    -- Apply base icon skin (texcoord, border, swipe)
    self:ApplyCustom(button, settings)

    -- Apply fonts (HotKey, Name)
    if button.HotKey then
        local fontName = (Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font)
            or Constants.Settings.Font.Default
        local fontPath = (Orbit.Fonts and Orbit.Fonts[fontName]) or Constants.Settings.Font.FallbackPath
        local fontSize = math.max(8, w * 0.28)
        button.HotKey:SetFont(fontPath, fontSize, "OUTLINE")
        button.HotKey:SetTextColor(1, 1, 1, 1)
        button.HotKey:ClearAllPoints()
        button.HotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    end

    if button.Name then
        local fontName = (Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font)
            or Constants.Settings.Font.Default
        local fontPath = (Orbit.Fonts and Orbit.Fonts[fontName]) or Constants.Settings.Font.FallbackPath
        local fontSize = math.max(7, w * 0.22)
        button.Name:SetFont(fontPath, fontSize, "OUTLINE")
        if settings.hideName then
            button.Name:Hide()
        else
            button.Name:Show()
            button.Name:SetTextColor(1, 1, 1, 0.9)
            button.Name:ClearAllPoints()
            button.Name:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
        end
    end

    -- Highlight
    if not button.orbitHighlight then
        button.orbitHighlight = button:CreateTexture(nil, "OVERLAY")
        button.orbitHighlight:SetAllPoints(button)
        button.orbitHighlight:SetColorTexture(1, 1, 1, 0.3)
        button.orbitHighlight:Hide()

        button:HookScript("OnEnter", function(self)
            if self.orbitHighlight then
                self.orbitHighlight:Show()
            end
        end)
        button:HookScript("OnLeave", function(self)
            if self.orbitHighlight then
                self.orbitHighlight:Hide()
            end
        end)
    end

    -- [ FLYOUT ARROW FIX ]
    -- Ensure FlyoutArrow and BorderShadow are above the custom border (which is a Frame at Level+5)
    if button.FlyoutArrow then
        if not button.orbitOverlayFrame then
            button.orbitOverlayFrame = CreateFrame("Frame", nil, button)
            button.orbitOverlayFrame:SetAllPoints(button)
            button.orbitOverlayFrame:SetFrameStrata("TOOLTIP")
            button.orbitOverlayFrame:SetFrameLevel(100)
        end

        button.FlyoutArrow:SetParent(button.orbitOverlayFrame)
        button.FlyoutArrow:ClearAllPoints()
        button.FlyoutArrow:SetPoint("TOP", button.orbitOverlayFrame, "TOP", 0, 2) -- Re-anchor to be sure

        if button.FlyoutBorderShadow then
            button.FlyoutBorderShadow:SetParent(button.orbitOverlayFrame)
        end
    end
end
