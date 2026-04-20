local _, Orbit = ...
local DT = Orbit.Datatexts

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local DEFAULT_WIDTH = 100
local DEFAULT_HEIGHT = 20
local DEFAULT_TEXT_SIZE = 12
local TEXT_PADDING = 0
local ICON_SIZE = 14
local ICON_PADDING = 4
local DRAG_TICKER_INTERVAL = 0.05

-- [ BASE DATATEXT ] ---------------------------------------------------------------------------------
local BaseDatatext = {}
BaseDatatext.__index = BaseDatatext
DT.BaseDatatext = BaseDatatext

function BaseDatatext:New(name)
    return setmetatable({
        name = name,
        events = {},
        unitEvents = {},
        isEnabled = false,
        frame = nil,
        text = nil,
        icon = nil,
        tooltipFunc = nil,
        updateFunc = nil,
        clickFunc = nil,
        category = "UTILITY",
        leftClickHint = nil,
        rightClickHint = nil,
        updateTier = nil,
        combatSafeTooltip = true,
        isHovered = false,
        tooltipUpdateQueued = false,
    }, BaseDatatext)
end

-- [ FRAME CREATION ] --------------------------------------------------------------------------------
function BaseDatatext:CreateFrame(width, height)
    if self.frame then return self.frame end
    local frameType = self.isSecure and "Button" or "Frame"
    local template = self.isSecure and "SecureActionButtonTemplate" or nil
    local f = CreateFrame(frameType, "Orbitdatatext" .. self.name, UIParent, template)
    f:SetSize(width or DEFAULT_WIDTH, height or DEFAULT_HEIGHT)
    f:SetClampedToScreen(true)
    f:Hide()
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Text:SetPoint("CENTER", f, "CENTER")
    self.text = f.Text
    if Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font then
        Orbit.Skin:SkinText(f.Text, { font = Orbit.db.GlobalSettings.Font, textSize = DEFAULT_TEXT_SIZE })
    end
    f:EnableMouse(true)
    f:SetScript("OnEnter", function() self:OnEnter() end)
    f:SetScript("OnLeave", function() self:OnLeave() end)
    
    if self.isSecure then
        f:RegisterForClicks("AnyUp", "AnyDown")
        f:SetScript("PostClick", function(_, button) self:OnClick(button) end)
    else
        f:SetScript("OnMouseUp", function(_, button) self:OnClick(button) end)
    end
    
    f.overlay = CreateFrame("Button", nil, f)
    f.overlay:SetAllPoints(f)
    f.overlay:SetFrameLevel(f:GetFrameLevel() + 20)
    f.overlay:RegisterForDrag("LeftButton")
    f.overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    f.overlay:SetScript("OnEnter", function()
        GameTooltip:SetOwner(f, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(self.name .. " (Edit Mode)", 1, 0.82, 0)
        GameTooltip:AddLine("Left Click: Drag", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right Click: Return to Drawer", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    f.overlay:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.overlay:SetScript("OnDragStart", function() self:OnDragStart() end)
    f.overlay:SetScript("OnDragStop", function() self:OnDragStop() end)
    f.overlay:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            DT.DatatextManager:UnplaceDatatext(self.name)
        end
    end)
    f.overlay:Hide()
    
    f.resizeHandle = CreateFrame("Button", nil, f)
    f.resizeHandle:SetSize(12, 12)
    f.resizeHandle:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
    f.resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    f.resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    f.resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    f.resizeHandle:SetFrameLevel(f.overlay:GetFrameLevel() + 5)
    f.resizeHandle:Hide()
    
    f.resizeHandle:SetScript("OnMouseDown", function()
        -- Force center anchor to ensure scale radiates evenly and prevents position drift
        local cx, cy = f:GetCenter()
        if cx and cy then
            local uipX = UIParent:GetWidth() / 2
            local uipY = UIParent:GetHeight() / 2
            local s = f:GetScale()
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "CENTER", (cx * s - uipX) / s, (cy * s - uipY) / s)
        end

        f.resizeHandle.startX, _ = GetCursorPosition()
        f.resizeHandle.startScale = self.scale or 1.0
        local point, _, _, ox, oy = f:GetPoint(1)
        f.resizeHandle.anchorPoint = point or "CENTER"
        f.resizeHandle.anchorX = ox or 0
        f.resizeHandle.anchorY = oy or 0
        
        f.resizeHandle.ticker = C_Timer.NewTicker(0.02, function()
            if InCombatLockdown() then return end
            local curX, _ = GetCursorPosition()
            local deltaX = curX - f.resizeHandle.startX
            local uipScale = UIParent:GetEffectiveScale()
            local scaleDelta = (deltaX / uipScale) / 150
            local newScale = f.resizeHandle.startScale + scaleDelta
            newScale = math.floor((math.max(1.0, math.min(2.5, newScale))) * 100 + 0.5) / 100
            self:SetScale(newScale)
            
            local ap = f.resizeHandle.anchorPoint
            local scaleRatio = f.resizeHandle.startScale / newScale
            f:ClearAllPoints()
            f:SetPoint(ap, UIParent, ap, f.resizeHandle.anchorX * scaleRatio, f.resizeHandle.anchorY * scaleRatio)
            
            if Orbit.Engine.SelectionTooltip then
                Orbit.Engine.SelectionTooltip:ShowResizeInfo(self.frame, math.floor(self.frame:GetWidth() * newScale + 0.5), math.floor(self.frame:GetHeight() * newScale + 0.5), true)
            end
        end)
    end)
    
    f.resizeHandle:SetScript("OnMouseUp", function()
        if f.resizeHandle.ticker then f.resizeHandle.ticker:Cancel(); f.resizeHandle.ticker = nil end
        if Orbit.Engine.SelectionTooltip then
            Orbit.Engine.SelectionTooltip:ShowResizeInfo(self.frame, math.floor(self.frame:GetWidth() * self.scale + 0.5), math.floor(self.frame:GetHeight() * self.scale + 0.5), false)
        end
        DT.DatatextManager:SavePositions()
    end)

    f.overlay:EnableKeyboard(true)
    f.overlay:SetScript("OnKeyDown", function(selfFrame, key)
        if InCombatLockdown() then return end
        
        if key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT" then
            if not selfFrame:IsMouseOver() then selfFrame:SetPropagateKeyboardInput(true); return end
            local datatextFrame = selfFrame:GetParent()
            local p, _, _, x, y = datatextFrame:GetPoint(1)
            local s = datatextFrame:GetEffectiveScale()
            local uipScale = UIParent:GetEffectiveScale()
            local rawX = x * s / uipScale
            local rawY = y * s / uipScale
            if key == "UP" then rawY = rawY + 1 elseif key == "DOWN" then rawY = rawY - 1
            elseif key == "LEFT" then rawX = rawX - 1 elseif key == "RIGHT" then rawX = rawX + 1 end
            rawX = rawX * uipScale / s
            rawY = rawY * uipScale / s
            datatextFrame:ClearAllPoints()
            datatextFrame:SetPoint(p, UIParent, p, rawX, rawY)
            if Orbit.Engine.SelectionTooltip then Orbit.Engine.SelectionTooltip:ShowPosition(datatextFrame, nil, false) end
            if datatextFrame.nudgeTimer then datatextFrame.nudgeTimer:Cancel() end
            datatextFrame.nudgeTimer = C_Timer.NewTimer(0.5, function() DT.DatatextManager:SavePositions() end)
            selfFrame:SetPropagateKeyboardInput(false)
            return
        end
        selfFrame:SetPropagateKeyboardInput(true)
    end)

    self.scale = 1.0
    self.frame = f
    return f
end

function BaseDatatext:SetScale(scale)
    scale = math.max(1.0, math.min(2.5, scale or 1.0))
    self.scale = scale
    if self.frame then self.frame:SetScale(scale) end
end

-- [ REGISTRATION ] ----------------------------------------------------------------------------------
function BaseDatatext:Register()
    if not self.frame then self:CreateFrame() end
    DT.DatatextManager:Register(self.name, {
        name = self.name,
        frame = self.frame,
        category = self.category,
        onEnable = function() self:Enable() end,
        onDisable = function() self:Disable() end,
        SetScale = function(_, scale) self:SetScale(scale) end,
    })
end

-- [ SETTERS ] ---------------------------------------------------------------------------------------
function BaseDatatext:SetCategory(category) self.category = category end
function BaseDatatext:SetUpdateFunc(func) self.updateFunc = func end
function BaseDatatext:SetTooltipFunc(func) self.tooltipFunc = func end
function BaseDatatext:SetClickFunc(func) self.clickFunc = func end
function BaseDatatext:SetCombatSafeTooltip(isSafe) self.combatSafeTooltip = isSafe end

function BaseDatatext:SetUpdateTier(tier)
    self.updateTier = tier
    DT.DatatextManager:RegisterForScheduler(self.name, tier, self.updateFunc)
end

-- [ ICON ] ------------------------------------------------------------------------------------------
function BaseDatatext:SetIcon(texturePath)
    if not self.icon then
        self.icon = self.frame:CreateTexture(nil, "ARTWORK")
        self.icon:SetSize(ICON_SIZE, ICON_SIZE)
        self.icon:SetPoint("LEFT", self.frame, "LEFT", 2, 0)
        self.text:SetPoint("CENTER", self.frame, "CENTER", (ICON_SIZE + ICON_PADDING) / 2, 0)
    end
    self.icon:SetTexture(texturePath)
    self.icon:Show()
end

-- [ EVENTS ] ----------------------------------------------------------------------------------------
function BaseDatatext:RegisterEvent(event, handler)
    self.events[event] = handler or self.updateFunc
    if self.isEnabled and self.eventFrame then self.eventFrame:RegisterEvent(event) end
end

function BaseDatatext:RegisterUnitEvent(event, unit, handler)
    self.events[event] = handler or self.updateFunc
    self.unitEvents[event] = unit
    if self.isEnabled and self.eventFrame then self.eventFrame:RegisterUnitEvent(event, unit) end
end

function BaseDatatext:UnregisterEvent(event)
    self.events[event] = nil
    self.unitEvents[event] = nil
    if self.eventFrame then self.eventFrame:UnregisterEvent(event) end
end

-- [ LIFECYCLE ] -------------------------------------------------------------------------------------
function BaseDatatext:Enable()
    if self.isEnabled then return end
    self.isEnabled = true
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "PLAYER_REGEN_ENABLED" and self.isHovered and self.tooltipUpdateQueued then
                self.tooltipUpdateQueued = false
                self:UpdateTooltip()
            end
            local handler = self.events[event]
            if handler then handler(self, event, ...)
            elseif self.updateFunc then self.updateFunc(self) end
        end)
    end
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    for event in pairs(self.events) do
        local unit = self.unitEvents[event]
        if unit then
            self.eventFrame:RegisterUnitEvent(event, unit)
        else
            self.eventFrame:RegisterEvent(event)
        end
    end
    if self.updateTier then DT.DatatextManager:RegisterForScheduler(self.name, self.updateTier, self.updateFunc) end
    if self.updateFunc then self.updateFunc(self) end
    if self.OnEnable then self:OnEnable() end
end

function BaseDatatext:Disable()
    if not self.isEnabled then return end
    self.isEnabled = false
    if self.eventFrame then self.eventFrame:UnregisterAllEvents() end
    if self.updateTier then DT.DatatextManager:UnregisterFromScheduler(self.name, self.updateTier) end
    if self.OnDisable then self:OnDisable() end
end

-- [ TEXT ] ------------------------------------------------------------------------------------------
function BaseDatatext:SetText(text)
    self.text:SetText(text)
    local width = self.text:GetStringWidth()
    local height = self.text:GetStringHeight()
    if self.icon then height = math.max(height, ICON_SIZE) end
    local iconOffset = self.icon and (ICON_SIZE + ICON_PADDING) or 0
    self.frame:SetSize(width + TEXT_PADDING + iconOffset, height)
end

-- [ TOOLTIP ] ---------------------------------------------------------------------------------------
function BaseDatatext:BuildTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    self:PopulateTooltip(GameTooltip)
    if self.leftClickHint or self.rightClickHint then
        GameTooltip:AddLine(" ")
        if self.leftClickHint then GameTooltip:AddDoubleLine("Left Click", self.leftClickHint, 0.7, 0.7, 0.7, 1, 1, 1) end
        if self.rightClickHint then GameTooltip:AddDoubleLine("Right Click", self.rightClickHint, 0.7, 0.7, 0.7, 1, 1, 1) end
    end
    GameTooltip:Show()
end

function BaseDatatext:PopulateTooltip(tooltip) tooltip:AddLine(self.name, 1, 0.82, 0) end

-- [ INTERACTION ] -----------------------------------------------------------------------------------
function BaseDatatext:UpdateTooltip()
    if self.tooltipFunc then self.tooltipFunc(self)
    else self:BuildTooltip() end
end

function BaseDatatext:OnEnter()
    self.isHovered = true
    
    if self.combatSafeTooltip == false and InCombatLockdown() then
        self.tooltipUpdateQueued = true
    else
        self:UpdateTooltip()
    end
    
    if self.tooltipTicker then self.tooltipTicker:Cancel() end
    self.tooltipTicker = C_Timer.NewTicker(0.5, function()
        if not self.isHovered then
            if self.tooltipTicker then self.tooltipTicker:Cancel(); self.tooltipTicker = nil end
            return
        end
        
        if self.combatSafeTooltip == false and InCombatLockdown() then
            self.tooltipUpdateQueued = true
            return
        end
        
        if not GameTooltip:IsOwned(self.frame) and not self.tooltipUpdateQueued then
            if self.tooltipTicker then self.tooltipTicker:Cancel(); self.tooltipTicker = nil end
            return
        end
        
        self.tooltipUpdateQueued = false
        self:UpdateTooltip()
    end)
end

function BaseDatatext:OnLeave() 
    self.isHovered = false
    self.tooltipUpdateQueued = false
    GameTooltip:Hide() 
    if self.tooltipTicker then self.tooltipTicker:Cancel(); self.tooltipTicker = nil end
end

function BaseDatatext:OnClick(button)
    if button == "LeftButton" and self.isDragging then return end
    if button == "RightButton" and not self.clickFunc then self:ShowContextMenu(); return end
    if self.clickFunc then self.clickFunc(self, button) end
end

-- [ CONTEXT MENU ] ----------------------------------------------------------------------------------
function BaseDatatext:ShowContextMenu()
    local items = self:BuildContextMenuItems()
    if #items > 0 then
        DT.Menu:Open(self.frame, items, self.name)
    end
end

function BaseDatatext:BuildContextMenuItems()
    local items = {}
    if self.GetMenuItems then
        for _, item in ipairs(self:GetMenuItems()) do items[#items + 1] = item end
    end
    return items
end

-- [ DRAGGING ] --------------------------------------------------------------------------------------
function BaseDatatext:OnDragStart()
    if not DT.DatatextManager:CanDrag() then return end
    GameTooltip:Hide()
    self.isDragging = true
    if Orbit.Engine.SelectionDrag then Orbit.Engine.SelectionDrag.isDragging = true end
    self.frame:SetFrameStrata(Orbit.Constants.Strata.Topmost)
    
    local cX, cY = GetCursorPosition()
    local fCX, fCY = self.frame:GetCenter()
    local eScale = self.frame:GetEffectiveScale()
    local uipScale = UIParent:GetEffectiveScale()
    
    if fCX and fCY then
        self.dragGripX = (fCX * eScale) - cX
        self.dragGripY = (fCY * eScale) - cY
    else
        self.dragGripX, self.dragGripY = 0, 0
    end
    
    if not self.dragTicker then
        self.dragTicker = C_Timer.NewTicker(0.02, function() 
            if InCombatLockdown() then return end
            local curX, curY = GetCursorPosition()
            local targetScreenX = curX + self.dragGripX
            local targetScreenY = curY + self.dragGripY
            
            local targetCX = targetScreenX / uipScale
            local targetCY = targetScreenY / uipScale
            
            local uipX = UIParent:GetWidth() / 2
            local uipY = UIParent:GetHeight() / 2
            local offsetX = (targetCX - uipX) / self.frame:GetScale()
            local offsetY = (targetCY - uipY) / self.frame:GetScale()
            
            self.frame:ClearAllPoints()
            self.frame:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
            
            DT.DrawerUI:OnDatatextDragUpdate(self.name)
            if Orbit.Engine.SelectionTooltip then
                Orbit.Engine.SelectionTooltip:ShowPosition(self.frame, nil, true)
            end
        end)
    end
end

function BaseDatatext:OnDragStop()
    self.frame:SetFrameStrata(Orbit.Constants.Strata.HUD)
    self.frame:SetFrameLevel(500)
    
    local cx, cy = self.frame:GetCenter()
    if cx and cy then
        local uipW = UIParent:GetWidth()
        local uipH = UIParent:GetHeight()
        local uipX = uipW / 2
        local uipY = uipH / 2
        local s = self.frame:GetScale()
        
        local centeredX = (cx * s - uipX) / s
        local centeredY = (cy * s - uipY) / s
        
        local point = "CENTER"
        local deadzone = 20
        if math.abs(centeredX) < deadzone or math.abs(centeredY) < deadzone then
            point = "CENTER"
        elseif centeredX < 0 and centeredY > 0 then
            point = "TOPLEFT"
        elseif centeredX > 0 and centeredY > 0 then
            point = "TOPRIGHT"
        elseif centeredX < 0 and centeredY < 0 then
            point = "BOTTOMLEFT"
        elseif centeredX > 0 and centeredY < 0 then
            point = "BOTTOMRIGHT"
        end
        
        local x, y = 0, 0
        if point == "CENTER" then
            x = centeredX
            y = centeredY
        elseif point == "TOPLEFT" then
            local fLeft = self.frame:GetLeft()
            local fTop = self.frame:GetTop()
            x = (fLeft * s - 0) / s
            y = (fTop * s - uipH) / s
        elseif point == "TOPRIGHT" then
            local fRight = self.frame:GetRight()
            local fTop = self.frame:GetTop()
            x = (fRight * s - uipW) / s
            y = (fTop * s - uipH) / s
        elseif point == "BOTTOMLEFT" then
            local fLeft = self.frame:GetLeft()
            local fBottom = self.frame:GetBottom()
            x = (fLeft * s - 0) / s
            y = (fBottom * s - 0) / s
        elseif point == "BOTTOMRIGHT" then
            local fRight = self.frame:GetRight()
            local fBottom = self.frame:GetBottom()
            x = (fRight * s - uipW) / s
            y = (fBottom * s - 0) / s
        end
        
        if Orbit.Engine.Pixel then
            x, y = Orbit.Engine.Pixel:SnapPosition(x, y, point, self.frame:GetWidth(), self.frame:GetHeight(), self.frame:GetEffectiveScale())
        end
        
        self.frame:ClearAllPoints()
        self.frame:SetPoint(point, UIParent, point, x, y)
    end
    
    self.isDragging = false
    if Orbit.Engine.SelectionDrag then Orbit.Engine.SelectionDrag.isDragging = false end
    if self.dragTicker then self.dragTicker:Cancel(); self.dragTicker = nil end
    if Orbit.Engine.SelectionTooltip then Orbit.Engine.SelectionTooltip:ShowPosition(self.frame, nil, false) end
    DT.DatatextManager:OnDatatextDragStop(self.name)
end
