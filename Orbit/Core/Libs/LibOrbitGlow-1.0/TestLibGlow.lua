local lib = LibStub("LibOrbitGlow-1.0")
if not lib then return end

-- [ GLOBALS / TEST MODE ] -----------------------------------------------------

_G.TestLibGlow = function(colorTest)
    local testManager = _G.LibGlowTestManager
    if not testManager then
        testManager = CreateFrame("Frame", "LibGlowTestManager", UIParent)
        testManager.colors = { {1,0,0,1}, {0,1,0,1}, {0,0,1,1}, {1,1,0,1}, {0,1,1,1}, {1,0,1,1}, {1,1,1,1} }
        testManager.cIndex = 1
        testManager.timer = 0
        testManager:SetScript("OnUpdate", function(self, el)
            self.timer = self.timer + el
            if self.timer >= 10 then
                self.timer = 0
                self.cIndex = (self.cIndex % #self.colors) + 1
                _G.TestLibGlow(self.colors[self.cIndex])
            end
        end)
    end
    local c = colorTest or testManager.colors[testManager.cIndex]
    
    local types = {
        { t="Thin", label="Thin" },
        { t="Thick", label="Thick" },
        { t="Medium", label="Medium" },
        { t="Classic", label="Classic" },
        { t="Static", label="Static" },
        { t="Autocast", label="Autocast" },
        { t="PixelFast", label="Pix Fast" },
        { t="PixelThick", label="Pix Thick" },
        { t="PixelSparse", label="Pix Sparse" },
        { t="PixelSlow", label="Pix Slow" }
    }
    
    local spacingX = 65
    local spacingY = 90
    local totalWidth = (#types - 1) * spacingX
    local startX = -(totalWidth / 2)
    
    local function SetupButton(rowName, i, labelText, isSquare, yOffset)
        local frameName = "LibGlowTest" .. rowName .. i
        local button = _G[frameName]
        if not button then
            button = CreateFrame("Frame", frameName, UIParent)
            button:SetSize(45, 45)
            
            if isSquare then
                button.icon = button:CreateTexture(nil, "BORDER")
                button.icon:SetPoint("TOPLEFT", -1, 1)
                button.icon:SetPoint("BOTTOMRIGHT", 1, -1)
                button.icon:SetTexture(134400)
                button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            else
                button.icon = button:CreateTexture(nil, "BACKGROUND")
                button.icon:SetAllPoints()
                button.icon:SetTexture(134400)
                
                local mask = button:CreateMaskTexture()
                mask:SetAtlas("UI-Frame-IconMask", true)
                if not mask:GetAtlas() then
                    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                end
                mask:Show()
                mask:SetAllPoints(button.icon)
                button.icon:AddMaskTexture(mask)
                
                local border = button:CreateTexture(nil, "OVERLAY")
                border:SetAllPoints()
                border:SetAtlas("UI-HUD-ActionBar-IconFrame", true)
            end
            
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("TOP", button, "BOTTOM", 0, -8)
            button.label = text
        end
        
        button:ClearAllPoints()
        button:SetPoint("CENTER", UIParent, "CENTER", startX + ((i - 1) * spacingX), yOffset)
        button.label:SetText(labelText)
        button:Show()
        
        lib.Hide(button, "Thin", "Test")
        lib.Hide(button, "Thick", "Test")
        lib.Hide(button, "Medium", "Test")
        lib.Hide(button, "Classic")
        lib.Hide(button, "Static", "Test")
        lib.Hide(button, "Autocast", "Test")
        lib.Hide(button, "Pixel", "Test")
        
        return button
    end
    
    for i, glowData in ipairs(types) do
        local sqButton = SetupButton("Square", i, glowData.label, true, spacingY)
        local standardButton = SetupButton("Standard", i, glowData.label, false, 0)
        local revButton = SetupButton("Reverse", i, glowData.label .. " Rev", true, -spacingY)
        
        local function ApplyGlow(button, isSquare, forceReverse)
            local t = glowData.t
            local passMask = isSquare == true
            local maskInset = isSquare and 2 or nil
            
            local opts = { key="Test", color=c, desaturated=true, maskIcon=passMask, maskInset=maskInset, reverse=forceReverse }
            
            if t == "PixelFast" then
                opts.lines = 8; opts.frequency = 0.5; opts.thickness = 2
                lib.Show(button, "Pixel", opts)
            elseif t == "PixelThick" then
                opts.lines = 8; opts.frequency = 0.25; opts.thickness = 4
                lib.Show(button, "Pixel", opts)
            elseif t == "PixelSparse" then
                opts.lines = 4; opts.frequency = 0.25; opts.thickness = 2
                lib.Show(button, "Pixel", opts)
            elseif t == "PixelSlow" then
                opts.lines = 16; opts.frequency = 0.05; opts.thickness = 1
                lib.Show(button, "Pixel", opts)
            else
                lib.Show(button, t, opts)
            end
        end
        
        ApplyGlow(sqButton, true, false)
        ApplyGlow(standardButton, false, false)
        ApplyGlow(revButton, true, true)
    end
end
