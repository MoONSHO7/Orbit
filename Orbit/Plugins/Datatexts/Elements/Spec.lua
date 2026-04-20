-- Spec.lua
-- Spec datatext: shows all specialization icons with the gold talent ring. Click to change.
local _, Orbit = ...
local DT = Orbit.Datatexts

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local BUTTON_SIZE = 25
local ICON_SIZE = 21
local RING_SIZE = 25
local PADDING = 2

-- [ DATATEXT ] --------------------------------------------------------------------------------------
local W = DT.BaseDatatext:New("Spec")

function W:Update()
    local currentSpec = GetSpecialization()
    local numSpecs = GetNumSpecializations()
    if not numSpecs or numSpecs == 0 then return end
    
    if not self.specButtons then self:CreateSpecButtons(numSpecs) end
    
    local changed = false
    if self.lastSpec then
        changed = (self.lastSpec ~= currentSpec)
    end
    self.lastSpec = currentSpec
    
    for i = 1, numSpecs do
        local btn = self.specButtons[i]
        btn.isActiveSpec = (currentSpec == i)
        if currentSpec == i then
            if changed and btn.eyeFx then
                btn.eyeFx:Play()
            end
            btn.icon:SetDesaturated(false)
            btn.icon:SetVertexColor(1, 1, 1)
            btn.ring:SetDesaturated(false)
            btn.ring:SetVertexColor(1, 1, 1)
        else
            btn.icon:SetDesaturated(true)
            btn.icon:SetVertexColor(0.6, 0.6, 0.6)
            btn.ring:SetDesaturated(true)
            btn.ring:SetVertexColor(0.6, 0.6, 0.6)
        end
    end
end

function W:CreateSpecButtons(numSpecs)
    self.specButtons = {}
    local totalWidth = (BUTTON_SIZE * numSpecs) + (PADDING * (numSpecs - 1))
    
    self.frame:SetSize(totalWidth, BUTTON_SIZE)
    self.text:Hide()
    if self.icon then self.icon:Hide() end
    
    for i = 1, numSpecs do
        local specId, name, _, icon, role = GetSpecializationInfo(i)
        
        local btn = CreateFrame("Button", nil, self.frame)
        btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        btn:RegisterForClicks("LeftButtonUp")
        
        if i == 1 then
            btn:SetPoint("LEFT", self.frame, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", self.specButtons[i-1], "RIGHT", PADDING, 0)
        end
        
        -- Icon
        local tex = btn:CreateTexture(nil, "BACKGROUND")
        tex:SetPoint("CENTER")
        tex:SetSize(ICON_SIZE, ICON_SIZE)
        tex:SetTexture(icon)
        
        -- Mask for circular icon
        local mask = btn:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(tex)
        tex:AddMaskTexture(mask)
        btn.icon = tex
        
        -- Gold Ring
        local ring = btn:CreateTexture(nil, "OVERLAY")
        ring:SetPoint("CENTER", tex, "CENTER", 0, 0)
        ring:SetSize(RING_SIZE, RING_SIZE)
        ring:SetAtlas("talents-node-circle-yellow")
        btn.ring = ring
        
        -- Flipbook FX for activation success
        local eyeFx = btn:CreateTexture(nil, "OVERLAY", nil, 7)
        eyeFx:SetPoint("CENTER", ring, "CENTER")
        eyeFx:SetSize(46, 46) -- Slightly larger than the ring
        eyeFx:SetAtlas("groupfinder-eye-flipbook-foundfx")
        eyeFx:SetBlendMode("ADD")
        eyeFx:Hide()
        btn.eyeFx = eyeFx
        
        btn.eyeFx.Play = function(self)
            self:SetAtlas("groupfinder-eye-flipbook-foundfx")
            self.elapsed = 0
            self.currentFrame = 0
            self:Show()
            self:UpdateFrame()
            btn:SetScript("OnUpdate", function(_, elapsed)
                self:OnUpdateAnim(elapsed)
            end)
        end
        
        btn.eyeFx.UpdateFrame = function(self)
            local ROWS = 5
            local COLS = 15
            
            local frameW = 1 / COLS
            local frameH = 1 / ROWS
            
            local col = self.currentFrame % COLS
            local row = math.floor(self.currentFrame / COLS)
            self:SetTexCoord(col * frameW, (col + 1) * frameW, row * frameH, (row + 1) * frameH)
        end
        
        btn.eyeFx.OnUpdateAnim = function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            local FRAMES = 75 -- 5 rows * 15 cols
            local frameTime = 1.0 / FRAMES -- 1.0s duration for 75 frames
            
            if self.elapsed >= frameTime then
                local ticks = math.floor(self.elapsed / frameTime)
                self.elapsed = self.elapsed - (ticks * frameTime)
                self.currentFrame = self.currentFrame + ticks
                
                if self.currentFrame >= FRAMES then
                    btn:SetScript("OnUpdate", nil)
                    self:Hide()
                    return
                end
                
                self:UpdateFrame()
            end
        end
        
        btn:SetScript("OnEnter", function()
            if not btn.isActiveSpec then
                btn.ring:SetDesaturated(false)
                btn.ring:SetVertexColor(1, 1, 1)
            end
            
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(name, 1, 0.82, 0)
            
            local displayRole = role == "DAMAGER" and "DAMAGE" or role
            GameTooltip:AddLine("Role: " .. (displayRole or "Unknown"), 1, 1, 1)
            GameTooltip:AddLine(" ")
            
            local currentSpec = GetSpecialization()
            if currentSpec ~= i then
                GameTooltip:AddLine("Left Click to activate spec", 0, 1, 0)
            else
                GameTooltip:AddLine("Active Spec", 0, 1, 0)
            end
            
            if currentSpec == i and C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID then
                local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specId)
                if configIDs and #configIDs > 0 then
                    GameTooltip:AddLine("Left Click to load talents", 0.7, 0.7, 0.7)
                end
            end
            
            GameTooltip:Show()
        end)
        
        btn:SetScript("OnLeave", function() 
            if not btn.isActiveSpec then
                btn.ring:SetDesaturated(true)
                btn.ring:SetVertexColor(0.6, 0.6, 0.6)
            end
            GameTooltip:Hide() 
        end)
        
        btn:SetScript("OnClick", function(_, button)
            if button ~= "LeftButton" then return end
            local currentSpec = GetSpecialization()
            if currentSpec ~= i then
                if not InCombatLockdown() then C_SpecializationInfo.SetSpecialization(i) end
                return
            end
            if not (C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID) then return end
            local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specId)
            if not configIDs or #configIDs == 0 then return end
            local items = {}
            for _, configID in ipairs(configIDs) do
                local configInfo = C_Traits.GetConfigInfo(configID)
                if configInfo then
                    items[#items + 1] = {
                        text = configInfo.name,
                        func = function()
                            if not InCombatLockdown() then C_ClassTalents.LoadConfig(configID, true) end
                        end
                    }
                end
            end
            if #items > 0 then DT.Menu:Open(btn, items, name .. " Loadouts") end
        end)
        
        self.specButtons[i] = btn
    end
end

function W:ShowTooltip()
    -- Handled per-button
end

function W:Init()
    self:CreateFrame()
    self:SetUpdateFunc(function() self:Update() end)
    self.frame:SetScript("OnEnter", nil) -- Disable default tooltip
    self.frame:SetScript("OnLeave", nil)
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetCategory("CHARACTER")
    self:Register()
    self:Update()
end

W:Init()
