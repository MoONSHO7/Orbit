-- [ CANVAS MODE - DRAG COMPONENT ]------------------------------------------------------
-- Draggable component creation and interaction handlers for Canvas Mode
--------------------------------------------------------------------------------

local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog
local C = CanvasMode.Constants
local LSM = LibStub("LibSharedMedia-3.0")

-- Use shared position utilities
local CalculateAnchor = OrbitEngine.PositionUtils.CalculateAnchor
local CalculateAnchorWithWidthCompensation = OrbitEngine.PositionUtils.CalculateAnchorWithWidthCompensation
local BuildAnchorPoint = OrbitEngine.PositionUtils.BuildAnchorPoint
local BuildComponentSelfAnchor = OrbitEngine.PositionUtils.BuildComponentSelfAnchor
local NeedsEdgeCompensation = OrbitEngine.PositionUtils.NeedsEdgeCompensation

-- SmartGuides for visual snap feedback
local SmartGuides = OrbitEngine.SmartGuides

-- [ CONSTANTS ]--------------------------------------------------------------------------

local SNAP_SIZE = 5
local EDGE_THRESHOLD = 3

-- [ TEXT ALIGNMENT ]---------------------------------------------------------------------

local function ApplyTextAlignment(container, visual, justifyH)
    visual:ClearAllPoints()
    visual:SetPoint(justifyH, container, justifyH, 0, 0)
    visual:SetJustifyH(justifyH)
end

-- Export for other modules
CanvasMode.ApplyTextAlignment = ApplyTextAlignment

-- [ SPRITE SHEET HELPER ]----------------------------------------------------------------

local function ApplySpriteSheetCell(texture, index, rows, cols)
    if not texture or not index then
        return
    end
    rows = rows or 4
    cols = cols or 4

    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)
    local width = 1 / cols
    local height = 1 / rows
    local left = col * width
    local right = left + width
    local top = row * height
    local bottom = top + height

    texture:SetTexCoord(left, right, top, bottom)
end

-- [ PREVIEW FALLBACK VALUES ]------------------------------------------------------------

local PREVIEW_TEXT_VALUES = {
    Name = "Name",
    HealthText = "100%",
    LevelText = "80",
    GroupPositionText = "G1",
    PowerText = "100%",
    Text = "100",
    Keybind = "Q",
}

local PREVIEW_TEXT_COLORS = {
    LevelText = { 1.0, 0.82, 0.0 },
}

-- [ CREATE DRAGGABLE COMPONENT ]---------------------------------------------------------

local function CreateDraggableComponent(preview, key, sourceComponent, startX, startY, data)
    local container = CreateFrame("Frame", nil, preview)
    container:SetSize(100, 20)
    container:EnableMouse(true)
    container:SetMovable(true)
    container:RegisterForDrag("LeftButton")

    local visual
    local isFontString = sourceComponent and sourceComponent.GetFont ~= nil
    local isTexture = sourceComponent and sourceComponent.GetTexture ~= nil and not isFontString
    local isIconFrame = sourceComponent and sourceComponent.Icon and sourceComponent.Icon.GetTexture and key ~= "CastBar"

    if isFontString then
        visual = container:CreateFontString(nil, "OVERLAY")

        local fontPath, fontSize, fontFlags = sourceComponent:GetFont()
        local flags = (fontFlags and fontFlags ~= "") and fontFlags or Orbit.Skin:GetFontOutline()
        if fontPath and fontSize then
            visual:SetFont(fontPath, fontSize, flags)
        else
            local globalFontName = Orbit.db.GlobalSettings.Font
            local fallbackPath = LSM:Fetch("font", globalFontName) or Orbit.Constants.Settings.Font.FallbackPath
            local fallbackSize = Orbit.Constants.UI.UnitFrameTextSize or 12
            visual:SetFont(fallbackPath, fallbackSize, Orbit.Skin:GetFontOutline())
        end

        local text = PREVIEW_TEXT_VALUES[key] or "Text"
        local ok, t = pcall(function() return sourceComponent:GetText() end)
        if ok and t and type(t) == "string" and (not issecretvalue or not issecretvalue(t)) and t ~= "" then
            text = t
        end
        visual:SetText(text)

        local r, g, b, a = sourceComponent:GetTextColor()
        local fallback = PREVIEW_TEXT_COLORS[key]
        if fallback and r and r > 0.95 and g > 0.95 and b > 0.95 then
            visual:SetTextColor(fallback[1], fallback[2], fallback[3], 1)
        elseif r then
            visual:SetTextColor(r, g, b, a or 1)
        end

        local sr, sg, sb, sa = sourceComponent:GetShadowColor()
        if sr then
            visual:SetShadowColor(sr, sg, sb, sa or 1)
        end
        local sx, sy = sourceComponent:GetShadowOffset()
        if sx then
            visual:SetShadowOffset(sx, sy)
        end

        -- Auto-size container to tightly fit text (minimal footprint)
        local text = visual:GetText() or ""
        local fontSize = select(2, visual:GetFont()) or 12
        -- Maximum reasonable width: 0.8 * fontSize * charCount (accounts for wide chars)
        local maxReasonableWidth = fontSize * #text * 0.8
        -- Tight fallback: ~0.55 per character for most fonts
        local textWidth = fontSize * #text * 0.55
        local textHeight = fontSize
        local ok, w = pcall(function() return visual:GetStringWidth() end)
        if ok and w and type(w) == "number" and w > 0 and w <= maxReasonableWidth * 2 and (not issecretvalue or not issecretvalue(w)) then
            textWidth = w
        end
        local ok2, h = pcall(function() return visual:GetStringHeight() end)
        if ok2 and h and type(h) == "number" and h > 0 and h <= fontSize * 2 and (not issecretvalue or not issecretvalue(h)) then
            textHeight = h
        end
        container:SetSize(textWidth, textHeight)

        visual:SetPoint("CENTER", container, "CENTER", 0, 0)
        container.isFontString = true
    elseif isTexture then
        -- Clone Texture
        visual = container:CreateTexture(nil, "OVERLAY")
        visual:SetAllPoints(container)

        local atlasName = sourceComponent.GetAtlas and sourceComponent:GetAtlas()
        local texturePath = sourceComponent:GetTexture()

        if atlasName then
            visual:SetAtlas(atlasName, false) -- false = don't use atlas native size
        elseif texturePath then
            visual:SetTexture(texturePath)

            if sourceComponent.orbitSpriteIndex then
                ApplySpriteSheetCell(visual, sourceComponent.orbitSpriteIndex, sourceComponent.orbitSpriteRows or 4, sourceComponent.orbitSpriteCols or 4)
            else
                local ok, l, r, t, b = pcall(function() return sourceComponent:GetTexCoord() end)
                if ok and l then
                    visual:SetTexCoord(l, r, t, b)
                end
            end
        else
            local previewAtlases = Orbit.IconPreviewAtlases or {}
            local fallbackAtlas = previewAtlases[key]

            if fallbackAtlas then
                if key == "MarkerIcon" then
                    visual:SetTexture(fallbackAtlas)
                    ApplySpriteSheetCell(visual, 8, 4, 4)
                else
                    visual:SetAtlas(fallbackAtlas, false)
                end
            else
                visual:SetColorTexture(0.5, 0.5, 0.5, 0.5)
            end
        end

        local vr, vg, vb, va = sourceComponent:GetVertexColor()
        if vr then
            visual:SetVertexColor(vr, vg, vb, va or 1)
        end

        local srcWidth, srcHeight = 20, 20
        if sourceComponent.orbitOriginalWidth and sourceComponent.orbitOriginalWidth > 0 then
            srcWidth = sourceComponent.orbitOriginalWidth
        else
            local ok, w = pcall(function() return sourceComponent:GetWidth() end)
            if ok and w and type(w) == "number" and w > 0 then
                srcWidth = w
            end
        end
        if sourceComponent.orbitOriginalHeight and sourceComponent.orbitOriginalHeight > 0 then
            srcHeight = sourceComponent.orbitOriginalHeight
        else
            local ok2, h = pcall(function() return sourceComponent:GetHeight() end)
            if ok2 and h and type(h) == "number" and h > 0 then
                srcHeight = h
            end
        end

        container:SetSize(srcWidth, srcHeight)
    elseif isIconFrame then
        local iconTexture = sourceComponent.Icon
        local hasFlipbook = iconTexture and iconTexture.orbitPreviewTexCoord

        if hasFlipbook then
            -- Flipbook atlas (e.g. RestingIcon): plain texture clone with single-frame texcoord
            visual = container:CreateTexture(nil, "OVERLAY")
            visual:SetAllPoints(container)
            local atlasName = iconTexture.GetAtlas and iconTexture:GetAtlas()
            if atlasName then
                visual:SetAtlas(atlasName, false)
            elseif iconTexture:GetTexture() then
                visual:SetTexture(iconTexture:GetTexture())
            end
            local tc = iconTexture.orbitPreviewTexCoord
            visual:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        else
            -- Standard icon: skinned Button with ApplyCustom (proven working for party frame icons)
            local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
            btn:SetAllPoints(container)
            btn:EnableMouse(false)
            btn.Icon = btn:CreateTexture(nil, "ARTWORK")
            btn.Icon:SetAllPoints()
            btn.icon = btn.Icon

            local texturePath = iconTexture and iconTexture:GetTexture()
            local StatusMixin = Orbit.StatusIconMixin
            if texturePath then
                btn.Icon:SetTexture(texturePath)
            elseif StatusMixin and key == "DefensiveIcon" then
                btn.Icon:SetTexture(StatusMixin:GetDefensiveTexture())
            elseif StatusMixin and key == "CrowdControlIcon" then
                btn.Icon:SetTexture(StatusMixin:GetCrowdControlTexture())
            elseif StatusMixin and key == "PrivateAuraAnchor" then
                btn.Icon:SetTexture(StatusMixin:GetPrivateAuraTexture())
            else
                local previewAtlases = Orbit.IconPreviewAtlases or {}
                if previewAtlases[key] then
                    btn.Icon:SetAtlas(previewAtlases[key], false)
                else
                    btn.Icon:SetColorTexture(0.5, 0.5, 0.5, 0.5)
                end
            end

            local scale = btn:GetEffectiveScale() or 1
            local globalBorder = Orbit.db.GlobalSettings.BorderSize or Orbit.Engine.Pixel:Multiple(1, scale)
            if Orbit.Skin and Orbit.Skin.Icons then
                Orbit.Skin.Icons:ApplyCustom(btn, { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false })
            end

            visual = btn
            container.isIconFrame = true
        end

        local srcWidth, srcHeight = 24, 24
        if sourceComponent.orbitOriginalWidth and sourceComponent.orbitOriginalWidth > 0 then
            srcWidth = sourceComponent.orbitOriginalWidth
        else
            local ok, w = pcall(function() return sourceComponent:GetWidth() end)
            if ok and w and type(w) == "number" and w > 0 then
                srcWidth = w
            end
        end
        if sourceComponent.orbitOriginalHeight and sourceComponent.orbitOriginalHeight > 0 then
            srcHeight = sourceComponent.orbitOriginalHeight
        else
            local ok2, h = pcall(function() return sourceComponent:GetHeight() end)
            if ok2 and h and type(h) == "number" and h > 0 then
                srcHeight = h
            end
        end

        container:SetSize(srcWidth, srcHeight)
    elseif key == "Portrait" then
        visual = container:CreateTexture(nil, "ARTWORK")
        visual:SetAllPoints()
        SetPortraitTexture(visual, "player")
        local portraitSize = 32
        if sourceComponent and sourceComponent.orbitOriginalWidth then portraitSize = sourceComponent.orbitOriginalWidth end
        container:SetSize(portraitSize, portraitSize)
    elseif key == "Buffs" or key == "Debuffs" then
        -- Aura container: render sample icons in a grid (refreshable)
        local sampleIcons
        if key == "Buffs" then
            sampleIcons = { 135936, 136051, 135994 } -- Renew, PW:Shield, Rejuvenation
        else
            sampleIcons = { 132122, 136207, 135824 } -- Corruption, Shadow Word: Pain, Moonfire
        end

        container.auraIconPool = {}
        container.isAuraContainer = true

        -- Reusable refresh: reads overrides from pendingOverrides > existingOverrides > fallback
        container.RefreshAuraIcons = function(self)
            local AURA_BASE_ICON_SIZE = Orbit.PartyFrameHelpers and Orbit.PartyFrameHelpers.LAYOUT.AuraBaseIconSize or 10
            local AURA_SPACING = 2
            local overrides = self.pendingOverrides or self.existingOverrides or {}
            local maxIcons = overrides.MaxIcons or 3
            local maxRows = overrides.MaxRows or 2
            local iconSize = math.max(10, overrides.IconSize or AURA_BASE_ICON_SIZE)

            -- Calculate grid layout matching runtime CalculateSmartAuraLayout
            local preview = self:GetParent()
            local parentWidth = preview and (preview.sourceWidth or preview:GetWidth()) or 200
            local parentHeight = preview and (preview.sourceHeight or preview:GetHeight()) or 40
            local Helpers = Orbit.PartyFrameHelpers
            local position = Helpers and Helpers.AnchorToPosition and Helpers:AnchorToPosition(self.posX, self.posY, parentWidth / 2, parentHeight / 2)
                or "Right"
            local isHorizontal = (position == "Above" or position == "Below")

            local rows, iconsPerRow, containerWidth, containerHeight
            if isHorizontal then
                iconsPerRow = math.max(1, math.floor((parentWidth + AURA_SPACING) / (iconSize + AURA_SPACING)))
                iconsPerRow = math.min(iconsPerRow, maxIcons)
                rows = math.min(maxRows, math.ceil(maxIcons / iconsPerRow))
                local displayCount = math.min(maxIcons, iconsPerRow * rows)
                local displayCols = math.min(displayCount, iconsPerRow)
                containerWidth = (displayCols * iconSize) + ((displayCols - 1) * AURA_SPACING)
                containerHeight = (rows * iconSize) + ((rows - 1) * AURA_SPACING)
            else
                -- Left/Right: rows capped by maxRows, icons distributed across rows
                rows = math.min(maxRows, math.max(1, maxIcons))
                iconsPerRow = math.ceil(maxIcons / rows)
                containerWidth = math.max(iconSize, (iconsPerRow * iconSize) + ((iconsPerRow - 1) * AURA_SPACING))
                containerHeight = (rows * iconSize) + ((rows - 1) * AURA_SPACING)
            end
            self:SetSize(containerWidth, containerHeight)

            -- Hide all pooled icons
            for _, btn in ipairs(self.auraIconPool) do
                btn:Hide()
            end

            local scale = self:GetEffectiveScale() or 1
            local globalBorder = Orbit.db.GlobalSettings.BorderSize or Orbit.Engine.Pixel:Multiple(1, scale)
            local skinSettings = { zoom = 0, borderStyle = 1, borderSize = globalBorder, showTimer = false }

            -- Create or reuse sample icons
            local iconIndex = 0
            for i = 1, maxIcons do
                local col = (i - 1) % iconsPerRow
                local row = math.floor((i - 1) / iconsPerRow)
                if row >= rows then
                    break
                end
                iconIndex = iconIndex + 1

                local btn = self.auraIconPool[iconIndex]
                if not btn then
                    btn = CreateFrame("Button", nil, self, "BackdropTemplate")
                    btn:EnableMouse(false)
                    btn.Icon = btn:CreateTexture(nil, "ARTWORK")
                    btn.Icon:SetAllPoints()
                    btn.icon = btn.Icon
                    self.auraIconPool[iconIndex] = btn
                end

                btn:SetSize(iconSize, iconSize)

                local texIndex = ((i - 1) % #sampleIcons) + 1
                btn.Icon:SetTexture(sampleIcons[texIndex])

                if Orbit.Skin and Orbit.Skin.Icons then
                    Orbit.Skin.Icons:ApplyCustom(btn, skinSettings)
                end

                btn:ClearAllPoints()
                local xOffset = col * (iconSize + AURA_SPACING)
                local yOffset = row * (iconSize + AURA_SPACING)

                -- Growth direction based on justifyH + anchorY
                local growDown = (self.anchorY ~= "BOTTOM")
                if self.justifyH == "RIGHT" then
                    if growDown then
                        btn:SetPoint("TOPRIGHT", self, "TOPRIGHT", -xOffset, -yOffset)
                    else
                        btn:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -xOffset, yOffset)
                    end
                else -- LEFT or CENTER
                    if growDown then
                        btn:SetPoint("TOPLEFT", self, "TOPLEFT", xOffset, -yOffset)
                    else
                        btn:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", xOffset, yOffset)
                    end
                end
                btn:Show()
            end
        end

        -- Set all layout properties before RefreshAuraIcons (growDown reads anchorY, icons read justifyH, AnchorToPosition reads posX/posY)
        container.posX = (data and data.posX) or startX
        container.posY = (data and data.posY) or startY
        container.anchorX = data and data.anchorX
        container.anchorY = data and data.anchorY
        container.justifyH = data and data.justifyH
        container.existingOverrides = data and data.overrides
        container:RefreshAuraIcons()
        visual = container.auraIconPool[1]
    elseif key == "CastBar" then
        local plugin = Dialog.targetPlugin
        local sysIdx = Dialog.targetSystemIndex or 1
        local cbWidth = (plugin and plugin:GetSetting(sysIdx, "CastBarWidth")) or 120
        local cbHeight = (plugin and plugin:GetSetting(sysIdx, "CastBarHeight")) or 18
        local showIcon = plugin and plugin:GetSetting(sysIdx, "CastBarIcon")

        container:SetSize(cbWidth, cbHeight)

        local bar = CreateFrame("StatusBar", nil, container)
        bar:SetAllPoints()
        bar:SetMinMaxValues(0, 2.0)
        bar:SetValue(1.2)

        local textureName = plugin and (plugin:GetSetting(sysIdx, "Texture") or plugin:GetPlayerSetting("Texture"))
        local texturePath = textureName and LSM:Fetch("statusbar", textureName)
        if texturePath then bar:SetStatusBarTexture(texturePath) end

        local cbColorCurve = plugin and plugin:GetSetting(sysIdx, "CastBarColorCurve")
        local cbColor = plugin and plugin:GetSetting(sysIdx, "CastBarColor") or { r = 1, g = 0.7, b = 0 }
        if cbColorCurve and OrbitEngine.WidgetLogic then
            local c = OrbitEngine.WidgetLogic:GetFirstColorFromCurve(cbColorCurve)
            if c then bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1) end
        else
            bar:SetStatusBarColor(cbColor.r, cbColor.g, cbColor.b, 1)
        end

        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints()
        local gs = Orbit.db.GlobalSettings or {}
        Orbit.Skin:ApplyGradientBackground(bar, gs.BackdropColourCurve, Orbit.Constants.Colors.Background)

        local iconOffset = 0
        if showIcon then
            bar.Icon = bar:CreateTexture(nil, "ARTWORK")
            bar.Icon:SetSize(cbHeight, cbHeight)
            bar.Icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
            bar.Icon:SetTexture(136243)
            bar.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
            bar.Icon:Show()
            iconOffset = cbHeight
        end

        local statusBarTex = bar:GetStatusBarTexture()
        if statusBarTex then
            statusBarTex:ClearAllPoints()
            statusBarTex:SetPoint("TOPLEFT", bar, "TOPLEFT", iconOffset, 0)
            statusBarTex:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", iconOffset, 0)
            statusBarTex:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
            statusBarTex:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        end

        local borderSize = plugin and (plugin:GetSetting(sysIdx, "BorderSize") or plugin:GetPlayerSetting("BorderSize"))
            or (Orbit.Engine.Pixel and Orbit.Engine.Pixel:Multiple(1, UIParent:GetEffectiveScale() or 1) or 1)
        if Orbit.Skin and Orbit.Skin.SkinBorder then
            Orbit.Skin:SkinBorder(bar, bar, borderSize, nil, true)
        end

        local fontName = plugin and (plugin:GetSetting(sysIdx, "Font") or plugin:GetPlayerSetting("Font"))
        local fontPath = fontName and LSM:Fetch("font", fontName)
            or LSM:Fetch("font", Orbit.db.GlobalSettings.Font)
            or Orbit.Constants.Settings.Font.FallbackPath
        local cbTextSize = Orbit.Skin:GetAdaptiveTextSize(cbHeight, 10, 18, 0.40)
        local fontFlags = Orbit.Skin:GetFontOutline()

        local subData = data and data.subComponents or {}
        local textData = subData.Text or { anchorX = "LEFT", anchorY = "CENTER", offsetX = 4, offsetY = 0 }
        local timerData = subData.Timer or { anchorX = "RIGHT", anchorY = "CENTER", offsetX = 4, offsetY = 0 }

        local function CreateSubText(parent, subKey, subPos, text, justify)
            local subFrame = CreateFrame("Frame", nil, parent)
            subFrame:SetFrameLevel(parent:GetFrameLevel() + 5)
            subFrame:EnableMouse(true)
            subFrame:SetMovable(true)
            subFrame:RegisterForDrag("LeftButton")

            local fs = subFrame:CreateFontString(nil, "OVERLAY")
            fs:SetFont(fontPath, cbTextSize, fontFlags)
            fs:SetShadowColor(0, 0, 0, 1)
            fs:SetShadowOffset(1, -1)
            fs:SetText(text)
            fs:SetJustifyH(justify)
            fs:SetPoint(justify, subFrame, justify, 0, 0)

            local textWidth = math.max(20, (fs:GetStringWidth() or 20) + 4)
            subFrame:SetSize(textWidth, cbTextSize + 2)

            subFrame.visual = fs
            subFrame.key = subKey
            subFrame.isFontString = true
            subFrame.isSubComponent = true
            subFrame.subComponentParent = parent
            subFrame.parentKey = "CastBar"

            local subBorder = subFrame:CreateTexture(nil, "BACKGROUND")
            subBorder:SetAllPoints()
            subBorder:SetColorTexture(0.3, 0.8, 0.3, 0)
            subFrame.border = subBorder

            local anchorX = subPos.anchorX or justify
            local anchorY = subPos.anchorY or "CENTER"
            local offX = subPos.offsetX or 4
            local offY = subPos.offsetY or 0
            local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
            local selfAnchor = BuildComponentSelfAnchor(true, false, anchorY, justify)
            local finalX = offX
            local finalY = offY
            if anchorX == "RIGHT" then finalX = -finalX end
            if anchorY == "TOP" then finalY = -finalY end

            subFrame:ClearAllPoints()
            subFrame:SetPoint(selfAnchor, parent, anchorPoint, finalX, finalY)

            subFrame.anchorX = anchorX
            subFrame.anchorY = anchorY
            subFrame.offsetX = offX
            subFrame.offsetY = offY
            subFrame.justifyH = justify

            if SmartGuides then subFrame.guides = SmartGuides:Create(parent) end

            subFrame:SetScript("OnEnter", function(s)
                s.border:SetColorTexture(0.3, 0.8, 0.3, 0.2)
                Dialog.hoveredComponent = s
            end)
            subFrame:SetScript("OnLeave", function(s)
                s.border:SetColorTexture(0.3, 0.8, 0.3, 0)
                if Dialog.hoveredComponent == s then Dialog.hoveredComponent = nil end
            end)

            subFrame:SetScript("OnMouseDown", function(s, button)
                if button ~= "LeftButton" then return end
                s.mouseDownTime = GetTime()
                s.wasDragged = false
            end)

            subFrame:SetScript("OnMouseUp", function(s, button)
                if button ~= "LeftButton" then return end
                if not s.wasDragged and s.mouseDownTime and (GetTime() - s.mouseDownTime) < 0.3 then
                    if OrbitEngine.CanvasComponentSettings then
                        OrbitEngine.CanvasComponentSettings:Open("CastBar", container, Dialog.targetPlugin, Dialog.targetSystemIndex)
                    end
                end
                s.mouseDownTime = nil
            end)

            subFrame:SetScript("OnDragStart", function(s)
                s.isDragging = true
                s.wasDragged = true
                s.border:SetColorTexture(0.3, 0.8, 0.3, 0.3)
                local mx, my = GetCursorPosition()
                local sc = s:GetEffectiveScale()
                local cx, cy = s:GetCenter()
                s.dragOffX = cx - mx / sc
                s.dragOffY = cy - my / sc
            end)

            subFrame:SetScript("OnDragStop", function(s)
                s.isDragging = false
                s.border:SetColorTexture(0.3, 0.8, 0.3, 0)
                if SmartGuides and s.guides then SmartGuides:Hide(s.guides) end

                if Dialog.DisabledDock and Dialog.DisabledDock:IsMouseOver() then
                    Dialog.DisabledDock.DropHighlight:Hide()
                    s:Hide()
                    local dockKey = "CastBar." .. subKey
                    Dialog:AddToDock(dockKey, s.visual)
                    Dialog.dockComponents[dockKey].storedSubFrame = s
                    Dialog.dockComponents[dockKey].parentContainer = container
                    return
                end

                local parentW, parentH = parent:GetWidth(), parent:GetHeight()
                local halfW, halfH = parentW / 2, parentH / 2
                local cx, cy = s:GetCenter()
                local px, py = parent:GetCenter()
                local relX = cx - px
                local relY = cy - py
                local aX, aY, oX, oY, jH = CalculateAnchorWithWidthCompensation(relX, relY, halfW, halfH, true, s:GetWidth())
                s.anchorX = aX
                s.anchorY = aY
                s.offsetX = oX
                s.offsetY = oY
                s.justifyH = jH
                ApplyTextAlignment(s, s.visual, jH)
                if plugin then
                    local positions = plugin:GetSetting(sysIdx, "ComponentPositions") or {}
                    if not positions.CastBar then positions.CastBar = {} end
                    if not positions.CastBar.subComponents then positions.CastBar.subComponents = {} end
                    positions.CastBar.subComponents[subKey] = {
                        anchorX = aX, anchorY = aY,
                        offsetX = oX, offsetY = oY,
                        justifyH = jH,
                    }
                    plugin:SetSetting(sysIdx, "ComponentPositions", positions)
                end
            end)

            subFrame:SetScript("OnUpdate", function(s)
                if not s.isDragging then return end
                local mx, my = GetCursorPosition()
                local sc = s:GetEffectiveScale()
                local targetX = mx / sc + s.dragOffX
                local targetY = my / sc + s.dragOffY
                local px, py = parent:GetCenter()
                local relX = targetX - px
                local relY = targetY - py
                local halfW = parent:GetWidth() / 2
                local halfH = parent:GetHeight() / 2
                local SUB_PAD_X, SUB_PAD_Y = 20, 10
                relX = math.max(-halfW - SUB_PAD_X, math.min(halfW + SUB_PAD_X, relX))
                relY = math.max(-halfH - SUB_PAD_Y, math.min(halfH + SUB_PAD_Y, relY))

                local snapX, snapY
                local compHalfW = (s:GetWidth() or 40) / 2
                local compHalfH = (s:GetHeight() or 12) / 2
                if not IsShiftKeyDown() then
                    local distR = math.abs((relX + compHalfW) - halfW)
                    local distL = math.abs((relX - compHalfW) + halfW)
                    if distR <= EDGE_THRESHOLD then relX = halfW - compHalfW; snapX = "RIGHT"
                    elseif distL <= EDGE_THRESHOLD then relX = -halfW + compHalfW; snapX = "LEFT"
                    elseif math.abs(relX) <= EDGE_THRESHOLD then relX = 0; snapX = "CENTER" end

                    local distT = math.abs((relY + compHalfH) - halfH)
                    local distB = math.abs((relY - compHalfH) + halfH)
                    if distT <= EDGE_THRESHOLD then relY = halfH - compHalfH; snapY = "TOP"
                    elseif distB <= EDGE_THRESHOLD then relY = -halfH + compHalfH; snapY = "BOTTOM"
                    elseif math.abs(relY) <= EDGE_THRESHOLD then relY = 0; snapY = "CENTER" end
                end

                if SmartGuides and s.guides then
                    SmartGuides:Update(s.guides, snapX, snapY, parent:GetWidth(), parent:GetHeight())
                end

                if Dialog.DisabledDock then
                    Dialog.DisabledDock.DropHighlight:SetShown(Dialog.DisabledDock:IsMouseOver())
                end

                local aX, aY, oX, oY, jH = CalculateAnchorWithWidthCompensation(relX, relY, halfW, halfH, true, s:GetWidth())
                if OrbitEngine.SelectionTooltip then
                    OrbitEngine.SelectionTooltip:ShowComponentPosition(s, subKey, aX, aY, relX, relY, oX, oY, jH)
                end

                s:ClearAllPoints()
                s:SetPoint("CENTER", parent, "CENTER", relX, relY)
            end)

            return subFrame
        end

        local textIconOffset = showIcon and cbHeight or 0
        container.TextSub = CreateSubText(bar, "Text",
            { anchorX = textData.anchorX, anchorY = textData.anchorY, offsetX = (textData.offsetX or 4) + textIconOffset, offsetY = textData.offsetY },
            "Boss Ability", "LEFT")
        container.TimerSub = CreateSubText(bar, "Timer", timerData, "1.5", "RIGHT")

        visual = bar
    else
        -- Fallback
        visual = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        visual:SetPoint("CENTER", container, "CENTER", 0, 0)
        visual:SetText(key or "?")
        container:SetSize(60, 20)
    end

    container.visual = visual

    -- Border (visible on hover/drag)
    container.border = container:CreateTexture(nil, "BACKGROUND")
    container.border:SetAllPoints()
    container.border:SetColorTexture(0.3, 0.8, 0.3, 0)

    -- Store position data
    container.posX = container.posX or startX
    container.posY = container.posY or startY
    container.key = key
    container.isFontString = isFontString
    container.existingOverrides = data and data.overrides

    -- Calculate anchor data
    local halfW = preview.sourceWidth / 2
    local halfH = preview.sourceHeight / 2
    local anchorX, anchorY, offsetX, offsetY, justifyH

    if data and data.anchorX then
        anchorX = data.anchorX
        anchorY = data.anchorY
        offsetX = data.offsetX
        offsetY = data.offsetY
        justifyH = data.justifyH
    else
        anchorX, anchorY, offsetX, offsetY, justifyH = CalculateAnchor(startX, startY, halfW, halfH)
    end

    container.anchorX = anchorX
    container.anchorY = anchorY
    container.offsetX = offsetX
    container.offsetY = offsetY
    container.justifyH = justifyH
    container.anchorY = anchorY

    -- Position the container
    local anchorPoint = BuildAnchorPoint(anchorX, anchorY)
    local posX, posY = startX, startY

    local finalX, finalY
    if anchorX == "CENTER" then
        finalX = posX
    else
        finalX = offsetX
        if anchorX == "RIGHT" then
            finalX = -finalX
        end
    end

    if anchorY == "CENTER" then
        finalY = posY
    else
        finalY = offsetY
        if anchorY == "TOP" then
            finalY = -finalY
        end
    end

    container:ClearAllPoints()
    local selfAnchor = BuildComponentSelfAnchor(isFontString, container.isAuraContainer, anchorY, justifyH)
    container:SetPoint(selfAnchor, preview, anchorPoint, finalX, finalY)

    if isFontString and visual then
        ApplyTextAlignment(container, visual, justifyH)
    end

    -- [ CLICK/DRAG HANDLERS ]------------------------------------------------------------

    local DRAG_THRESHOLD = 3 -- Custom threshold (WoW default is ~15px)

    container:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.mouseDownTime = GetTime()
            self.wasDragged = false
            self.pendingDrag = true
            local mx, my = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            self.mouseDownX = Orbit.Engine.Pixel:Snap(mx / scale, scale)
            self.mouseDownY = Orbit.Engine.Pixel:Snap(my / scale, scale)
        end
    end)

    container:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.pendingDrag = false

            -- If we were dragging, stop the drag
            if self.isDragging then
                self.isDragging = false
                self.border:SetColorTexture(0.3, 0.8, 0.3, 0)

                -- Hide SmartGuides
                if SmartGuides and preview.guides then
                    SmartGuides:Hide(preview.guides)
                end

                Dialog.DisabledDock.DropHighlight:Hide()
            elseif not self.wasDragged and self.mouseDownTime then
                -- Click behavior (not a drag)
                local clickDuration = GetTime() - self.mouseDownTime
                if clickDuration < 0.3 then
                    if OrbitEngine.CanvasComponentSettings then
                        OrbitEngine.CanvasComponentSettings:Open(self.key, self, Dialog.targetPlugin, Dialog.targetSystemIndex)
                    end
                end
            end

            self.mouseDownTime = nil
            self.mouseDownX = nil
            self.mouseDownY = nil
        end
    end)

    -- Helper to start dragging (shared logic)
    local function StartDrag(self)
        if InCombatLockdown() then
            return
        end

        self.wasDragged = true
        self.pendingDrag = false

        local mX, mY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        mX, mY = Orbit.Engine.Pixel:Snap(mX / scale, scale), Orbit.Engine.Pixel:Snap(mY / scale, scale)

        local parentCenterX, parentCenterY = preview:GetCenter()
        local zoomLevel = Dialog.zoomLevel or 1
        local itemScreenX = parentCenterX + (self.posX or 0) * zoomLevel
        local itemScreenY = parentCenterY + (self.posY or 0) * zoomLevel

        self.dragGripX = itemScreenX - mX
        self.dragGripY = itemScreenY - mY
        self.isDragging = true
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0.3)
    end

    -- Keep OnDragStart as fallback (for accessibility/edge cases)
    container:SetScript("OnDragStart", function(self)
        if not self.isDragging and not self.wasDragged then
            StartDrag(self)
        end
    end)

    container:SetScript("OnUpdate", function(self)
        -- Check for pending drag with custom threshold (faster than WoW's ~15px default)
        if self.pendingDrag and self.mouseDownX and self.mouseDownY then
            local mX, mY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            mX, mY = Orbit.Engine.Pixel:Snap(mX / scale, scale), Orbit.Engine.Pixel:Snap(mY / scale, scale)

            local dx = math.abs(mX - self.mouseDownX)
            local dy = math.abs(mY - self.mouseDownY)

            if dx > DRAG_THRESHOLD or dy > DRAG_THRESHOLD then
                StartDrag(self)
            end
        end

        if self.isDragging then
            local halfW = preview.sourceWidth / 2
            local halfH = preview.sourceHeight / 2

            local mX, mY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            mX, mY = Orbit.Engine.Pixel:Snap(mX / scale, scale), Orbit.Engine.Pixel:Snap(mY / scale, scale)

            -- 2. Calculate where the Center SHOULD be (Mouse + Grip)
            local targetWorldX = mX + (self.dragGripX or 0)
            local targetWorldY = mY + (self.dragGripY or 0)

            -- 3. Normalize to Parent Frame (Convert to local coords, 0,0 at center)
            local parentCenterX, parentCenterY = preview:GetCenter()
            local screenOffsetX = targetWorldX - parentCenterX
            local screenOffsetY = targetWorldY - parentCenterY

            -- 4. Account for zoom level (screen pixels -> local pixels)
            local zoomLevel = Dialog.zoomLevel or 1
            local relativeX = screenOffsetX / zoomLevel
            local relativeY = screenOffsetY / zoomLevel

            -- 5. Clamp to bounds
            local CLAMP_PADDING_X = 100
            local CLAMP_PADDING_Y = 50
            relativeX = math.max(-halfW - CLAMP_PADDING_X, math.min(halfW + CLAMP_PADDING_X, relativeX))
            relativeY = math.max(-halfH - CLAMP_PADDING_Y, math.min(halfH + CLAMP_PADDING_Y, relativeY))

            -- Alias for consistency with rest of code
            local centerRelX, centerRelY = relativeX, relativeY

            -- [ TIERED SNAP LOGIC ]------------------------------------------------------
            local snapX, snapY = nil, nil
            local compWidth = self:GetWidth() or 40
            local compHeight = self:GetHeight() or 16
            local compHalfW = compWidth / 2
            local compHalfH = compHeight / 2

            if IsShiftKeyDown() then
                -- Precision mode: no snapping
            else
                -- Edge Magnet X (snap when near edge, show guide when beyond)
                local rightEdgePos = halfW - compHalfW
                local leftEdgePos = -halfW + compHalfW
                local distRight = math.abs(centerRelX - rightEdgePos)
                local distLeft = math.abs(centerRelX - leftEdgePos)
                local beyondRight = centerRelX > rightEdgePos
                local beyondLeft = centerRelX < leftEdgePos

                if distRight <= EDGE_THRESHOLD and not beyondRight then
                    centerRelX = rightEdgePos
                    snapX = "RIGHT"
                elseif distLeft <= EDGE_THRESHOLD and not beyondLeft then
                    centerRelX = leftEdgePos
                    snapX = "LEFT"
                elseif math.abs(centerRelX) <= EDGE_THRESHOLD then
                    centerRelX = 0
                    snapX = "CENTER"
                elseif beyondRight then
                    snapX = "RIGHT" -- Show guide only, no snap
                elseif beyondLeft then
                    snapX = "LEFT" -- Show guide only, no snap
                end
                if not snapX then
                    local scale = UIParent:GetEffectiveScale()
                    centerRelX = OrbitEngine.Pixel:Snap(math.floor(centerRelX / SNAP_SIZE + 0.5) * SNAP_SIZE, scale)
                end

                -- Edge Magnet Y (snap when near edge, show guide when beyond)
                local topEdgePos = halfH - compHalfH
                local bottomEdgePos = -halfH + compHalfH
                local distTop = math.abs(centerRelY - topEdgePos)
                local distBottom = math.abs(centerRelY - bottomEdgePos)
                local beyondTop = centerRelY > topEdgePos
                local beyondBottom = centerRelY < bottomEdgePos

                if distTop <= EDGE_THRESHOLD and not beyondTop then
                    centerRelY = topEdgePos
                    snapY = "TOP"
                elseif distBottom <= EDGE_THRESHOLD and not beyondBottom then
                    centerRelY = bottomEdgePos
                    snapY = "BOTTOM"
                elseif math.abs(centerRelY) <= EDGE_THRESHOLD then
                    centerRelY = 0
                    snapY = "CENTER"
                elseif beyondTop then
                    snapY = "TOP" -- Show guide only, no snap
                elseif beyondBottom then
                    snapY = "BOTTOM" -- Show guide only, no snap
                end
                if not snapY then
                    local scale = UIParent:GetEffectiveScale()
                    centerRelY = OrbitEngine.Pixel:Snap(math.floor(centerRelY / SNAP_SIZE + 0.5) * SNAP_SIZE, scale)
                end
            end

            local needsWidthComp = NeedsEdgeCompensation(self.isFontString, self.isAuraContainer)
            local anchorX, anchorY, edgeOffX, edgeOffY, justifyH =
                CalculateAnchorWithWidthCompensation(centerRelX, centerRelY, halfW, halfH, needsWidthComp, self:GetWidth(), self:GetHeight(), self.isAuraContainer)

            -- Update SmartGuides
            if SmartGuides and preview.guides then
                SmartGuides:Update(preview.guides, snapX, snapY, preview.sourceWidth, preview.sourceHeight)
            end

            if self.isFontString and self.visual then
                ApplyTextAlignment(self, self.visual, justifyH)
            end

            -- Always position by CENTER during drag for smooth movement
            self:ClearAllPoints()
            self:SetPoint("CENTER", preview, "CENTER", centerRelX, centerRelY)

            -- Store values for OnDragStop
            local prevAnchorX = self.anchorX
            local prevAnchorY = self.anchorY
            local prevJustifyH = self.justifyH
            self.anchorX = anchorX
            self.anchorY = anchorY
            self.offsetX = edgeOffX
            self.offsetY = edgeOffY
            self.justifyH = justifyH
            self.posX = centerRelX
            self.posY = centerRelY

            -- Refresh icon layout when growth direction or position changes during drag
            if self.isAuraContainer and self.RefreshAuraIcons and (prevAnchorX ~= anchorX or prevAnchorY ~= anchorY or prevJustifyH ~= justifyH) then
                self:RefreshAuraIcons()
            end

            -- Show/hide dock drop highlight
            if Dialog.DisabledDock:IsMouseOver() then
                Dialog.DisabledDock.DropHighlight:Show()
            else
                Dialog.DisabledDock.DropHighlight:Hide()
            end

            -- Show tooltip
            if OrbitEngine.SelectionTooltip then
                OrbitEngine.SelectionTooltip:ShowComponentPosition(self, key, anchorX, anchorY, centerRelX, centerRelY, edgeOffX, edgeOffY, justifyH)
            end
        end
    end)

    container:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self.dragStartLocalX = nil
        self.dragStartLocalY = nil
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0)

        Dialog.DisabledDock.DropHighlight:Hide()

        -- Hide SmartGuides
        if SmartGuides and preview.guides then
            SmartGuides:Hide(preview.guides)
        end

        -- Check if dropped over the disabled dock
        if Dialog.DisabledDock:IsMouseOver() then
            local compKey = self.key
            local sourceComponent = data and data.component

            self:Hide()
            self:SetParent(nil)
            Dialog.previewComponents[compKey] = nil

            Dialog:AddToDock(compKey, sourceComponent)
            return
        end

        -- Snap to grid
        local SNAP = 5
        local snappedX = math.floor((self.posX or 0) / SNAP + 0.5) * SNAP
        local snappedY = math.floor((self.posY or 0) / SNAP + 0.5) * SNAP
        local scale = UIParent:GetEffectiveScale()
        self.posX = OrbitEngine.Pixel:Snap(snappedX, scale)
        self.posY = OrbitEngine.Pixel:Snap(snappedY, scale)

        self.offsetX = OrbitEngine.Pixel:Snap(math.floor((self.offsetX or 0) / SNAP + 0.5) * SNAP, scale)
        self.offsetY = OrbitEngine.Pixel:Snap(math.floor((self.offsetY or 0) / SNAP + 0.5) * SNAP, scale)

        self:ClearAllPoints()
        self:SetPoint("CENTER", preview, "CENTER", self.posX, self.posY)

        if self.visual and self.isFontString then
            ApplyTextAlignment(self, self.visual, self.justifyH or "CENTER")
        end
    end)

    -- Hover effects
    container:SetScript("OnEnter", function(self)
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0.2)
        Dialog.hoveredComponent = self
    end)

    container:SetScript("OnLeave", function(self)
        self.border:SetColorTexture(0.3, 0.8, 0.3, 0)
        if Dialog.hoveredComponent == self then
            Dialog.hoveredComponent = nil
        end
    end)

    -- Apply existing overrides
    if container.existingOverrides and OrbitEngine.CanvasComponentSettings and OrbitEngine.CanvasComponentSettings.ApplyAll then
        OrbitEngine.CanvasComponentSettings:ApplyAll(container, container.existingOverrides)
    end

    return container
end

-- Export for use by other modules
CanvasMode.CreateDraggableComponent = CreateDraggableComponent
