-- Mail.lua
-- Mail datatext: shows pending mail indicator
local _, Orbit = ...
local DT = Orbit.Datatexts
local L = Orbit.L

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local ICON_SIZE = 32

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("Mail")

function W:Update()
    local hasMail = HasNewMail()
    
    if hasMail and not self.lastHasMail then
        self.acknowledged = false
    end
    self.lastHasMail = hasMail
    
    local isUnlocked = DT.DatatextManager:CanDrag()
    local reg = DT.DatatextManager:GetDatatext(self.name)
    local isPlaced = reg and reg.isPlaced
    
    if not self.overlayHooked and self.frame.overlay then
        self.frame.overlay:HookScript("OnShow", function() self:Update() end)
        self.frame.overlay:HookScript("OnHide", function() self:Update() end)
        self.overlayHooked = true
    end
    
    -- Abort if the datatext is not actually placed on the screen
    if not isPlaced then
        self.frame:Hide()
        return
    end
    
    self.frame:Show()
    
    if hasMail then
        self.frame:EnableMouse(true)
        self.iconTexture:Show()
        self.iconTexture:SetAlpha(1)
        
        if self.acknowledged or self.isHovered then
            if self.mailAnim then self.mailAnim:Stop() end
            self.iconTexture:SetTexCoord(0, 0.25, 0, 0.3333)
        else
            if self.mailAnim and not self.mailAnim:IsPlaying() then
                self.iconTexture:SetTexCoord(0, 1, 0, 1)
                self.mailAnim:Play()
            end
        end
    else
        self.frame:EnableMouse(false)
        if isUnlocked then
            self.iconTexture:Show()
            self.iconTexture:SetAlpha(1)
            if self.mailAnim then self.mailAnim:Stop() end
            self.iconTexture:SetTexCoord(0, 0.25, 0, 0.3333)
        else
            self.iconTexture:Hide()
            if self.mailAnim then self.mailAnim:Stop() end
        end
    end
end

function W:OnEnter()
    DT.BaseDatatext.OnEnter(self)
    if HasNewMail() then
        self.acknowledged = true
    end
    self:Update()
end

function W:OnLeave()
    DT.BaseDatatext.OnLeave(self)
    self:Update()
end

function W:ShowTooltip()
    GameTooltip:SetOwner(self.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.PLU_DT_MAIL_TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    if HasNewMail() then
        local sender1, sender2, sender3 = GetLatestThreeSenders()
        if sender1 or sender2 or sender3 then
            GameTooltip:AddLine(L.PLU_DT_MAIL_UNREAD_FROM, 1, 0.7, 0)
            if sender1 then GameTooltip:AddLine("- " .. sender1, 1, 1, 1) end
            if sender2 then GameTooltip:AddLine("- " .. sender2, 1, 1, 1) end
            if sender3 then GameTooltip:AddLine("- " .. sender3, 1, 1, 1) end
        else
            GameTooltip:AddLine(L.PLU_DT_MAIL_UNREAD, 1, 0.7, 0)
        end
    else
        GameTooltip:AddLine(L.PLU_DT_MAIL_NONE, 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self:SetTooltipFunc(function() self:ShowTooltip() end)
    self:RegisterEvent("UPDATE_PENDING_MAIL")
    self:RegisterEvent("MAIL_INBOX_UPDATE")
    self:SetCategory("SOCIAL")
    self:Register()
    
    self.text:SetText("")
    self.text:Hide()
    self.frame:SetSize(ICON_SIZE, ICON_SIZE)
    
    self.iconTexture = self.frame:CreateTexture(nil, "ARTWORK")
    self.iconTexture:SetSize(ICON_SIZE, ICON_SIZE)
    self.iconTexture:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    self.iconTexture:SetAtlas("UI-HUD-Minimap-Mail-Reminder-Flipbook-2x")
    
    self.mailAnim = self.iconTexture:CreateAnimationGroup()
    self.mailAnim:SetLooping("REPEAT")
    local flipBook = self.mailAnim:CreateAnimation("FlipBook")
    flipBook:SetOrder(1)
    flipBook:SetDuration(1.5)
    flipBook:SetFlipBookRows(3)
    flipBook:SetFlipBookColumns(4)
    flipBook:SetFlipBookFrames(12)
    
    self:Update()
end

W:Init()
