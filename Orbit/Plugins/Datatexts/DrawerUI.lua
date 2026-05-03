local _, Orbit = ...
local DT = Orbit.Datatexts
local L = Orbit.L

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local CORNER_SIZE = 4
local DRAWER_WIDTH = 420
local DRAWER_HEADER_HEIGHT = 40
local DRAWER_CELL_WIDTH = 90
local DRAWER_CELL_HEIGHT = 24
local DRAWER_COLS = 4
local DRAWER_PAD = 10
local DRAWER_OUTER_PAD = 15
local DRAWER_BOTTOM_PAD = 40
local SLIDE_DURATION = 0.25
local CORNER_STRATA = "TOOLTIP"
local DRAWER_STRATA = "DIALOG"
local DRAWER_FRAME_LEVEL = 100
local HIGHLIGHT_R, HIGHLIGHT_G, HIGHLIGHT_B, HIGHLIGHT_A = 0, 0.8, 1, 0.15

-- [ STATE ] -----------------------------------------------------------------------------------------
local drawerPanel = nil
local cornerButtons = {}
local isOpen = false
local cellPool = {}
local headerPool = {}
local activeCells = {}
local activeHeaders = {}

-- [ DRAWER UI ] -------------------------------------------------------------------------------------
local DrawerUI = {}
DT.DrawerUI = DrawerUI

-- [ CORNER TRIGGERS ] -------------------------------------------------------------------------------
function DrawerUI:CreateCornerTriggers()
    local anchors = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
    for _, anchor in ipairs(anchors) do
        local btn = CreateFrame("Button", "OrbitdatatextCorner" .. anchor, UIParent)
        btn:SetSize(CORNER_SIZE, CORNER_SIZE)
        btn:SetPoint(anchor, UIParent, anchor)
        btn:SetFrameStrata(CORNER_STRATA)
        btn:RegisterForClicks("LeftButtonUp")
        btn:SetScript("OnClick", function() self:Toggle(anchor) end)
        btn:SetScript("OnEnter", function(f)
            GameTooltip:SetOwner(f, "ANCHOR_CURSOR")
            GameTooltip:AddLine(L.PLU_DT_DRAWER_TITLE, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        cornerButtons[#cornerButtons + 1] = btn
    end
end

function DrawerUI:DestroyCornerTriggers()
    for _, btn in ipairs(cornerButtons) do btn:Hide(); btn:SetParent(nil) end
    cornerButtons = {}
end

-- [ PANEL CREATION ] --------------------------------------------------------------------------------
function DrawerUI:CreatePanel()
    if drawerPanel then return end
    drawerPanel = CreateFrame("Frame", "OrbitDatatexts", UIParent)
    drawerPanel:SetFrameStrata(DRAWER_STRATA)
    drawerPanel:SetFrameLevel(DRAWER_FRAME_LEVEL)
    drawerPanel:SetClampedToScreen(true)
    drawerPanel:SetWidth(DRAWER_WIDTH)
    drawerPanel:EnableMouse(true)
    tinsert(UISpecialFrames, "OrbitDatatexts")
    drawerPanel.Border = CreateFrame("Frame", nil, drawerPanel, "DialogBorderTranslucentTemplate")
    drawerPanel.Border:SetAllPoints(drawerPanel)
    drawerPanel.Border:SetFrameLevel(drawerPanel:GetFrameLevel())
    drawerPanel.header = drawerPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    drawerPanel.header:SetPoint("TOP", drawerPanel, "TOP", 0, -15)
    drawerPanel.header:SetText(L.PLU_DT_DRAWER_TITLE)
    drawerPanel.CloseButton = CreateFrame("Button", nil, drawerPanel, "UIPanelCloseButton")
    drawerPanel.CloseButton:SetPoint("TOPRIGHT", drawerPanel, "TOPRIGHT", -2, -2)
    drawerPanel.CloseButton:SetScript("OnClick", function() self:Close() end)
    drawerPanel:SetMovable(true)
    local dragFrame = CreateFrame("Frame", nil, drawerPanel)
    dragFrame:SetPoint("TOPLEFT")
    dragFrame:SetPoint("TOPRIGHT")
    dragFrame:SetHeight(DRAWER_HEADER_HEIGHT)
    dragFrame:EnableMouse(true)
    dragFrame:RegisterForDrag("LeftButton")
    dragFrame:SetScript("OnDragStart", function() drawerPanel:StartMoving() end)
    dragFrame:SetScript("OnDragStop", function() drawerPanel:StopMovingOrSizing() end)
    drawerPanel:SetScript("OnShow", function() DT.DatatextManager:EnableDrawerDatatexts() end)
    drawerPanel:SetScript("OnHide", function()
        DT.DatatextManager:DisableDrawerDatatexts()
        DT.DatatextManager:SetLocked(true)
        isOpen = false
    end)
    drawerPanel.dropGlow = drawerPanel:CreateTexture(nil, "OVERLAY")
    drawerPanel.dropGlow:SetAllPoints()
    drawerPanel.dropGlow:SetAtlas("transmog-setCard-transmogrified-pending")
    drawerPanel.dropGlow:SetBlendMode("ADD")
    drawerPanel.dropGlow:SetVertexColor(HIGHLIGHT_R, HIGHLIGHT_G, HIGHLIGHT_B, 0.7)
    drawerPanel.dropGlow:Hide()
    local FO_INSET = 12
    drawerPanel.Footer = CreateFrame("Frame", nil, drawerPanel)
    drawerPanel.Footer:SetPoint("BOTTOMLEFT", drawerPanel, "BOTTOMLEFT", FO_INSET, FO_INSET)
    drawerPanel.Footer:SetPoint("BOTTOMRIGHT", drawerPanel, "BOTTOMRIGHT", -FO_INSET, FO_INSET)

    local footerDivider = drawerPanel.Footer:CreateTexture(nil, "ARTWORK")
    local panelScale = drawerPanel:GetEffectiveScale()
    footerDivider:SetSize(Orbit.Engine.Pixel:Snap(drawerPanel:GetWidth() - (FO_INSET * 2) - 40, panelScale), Orbit.Constants.Panel.DividerHeight)
    footerDivider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
    footerDivider:SetPoint("TOP", drawerPanel.Footer, "TOP", 0, Orbit.Constants.Footer.DividerOffset)

    local schema = {
        width = drawerPanel:GetWidth() - (FO_INSET * 2),
        hideResetButton = true,
        extraButtons = {
            {
                text = "Reset to Defaults",
                callback = function()
                    DT.DatatextManager:ResetToDefaults()
                end
            }
        }
    }
    drawerPanel.footerHeight = Orbit.Engine.Config:RenderFooter(drawerPanel.Footer, nil, nil, nil, schema)
    
    drawerPanel:Hide()
end

function DrawerUI:GetPanel() return drawerPanel end

-- [ LAYOUT ] ----------------------------------------------------------------------------------------
function DrawerUI:LayoutDrawer()
    if not drawerPanel then return end
    
    for _, cell in ipairs(activeCells) do cell:Hide(); cellPool[#cellPool + 1] = cell end
    activeCells = {}
    for _, hdr in ipairs(activeHeaders) do hdr:Hide(); headerPool[#headerPool + 1] = hdr end
    activeHeaders = {}
    
    local alldatatexts = {}
    for _, datatext in pairs(DT.DatatextManager:GetAllDatatexts()) do
        alldatatexts[#alldatatexts + 1] = datatext
    end
    table.sort(alldatatexts, function(a, b) return a.name < b.name end)
    
    local yOffset = -DRAWER_HEADER_HEIGHT - DRAWER_OUTER_PAD
    local col = 0
    
    for _, datatext in ipairs(alldatatexts) do
        local cell = table.remove(cellPool)
        if not cell then
            cell = CreateFrame("Frame", nil, drawerPanel)
            cell:SetSize(DRAWER_CELL_WIDTH, DRAWER_CELL_HEIGHT)
            cell.bg = cell:CreateTexture(nil, "BACKGROUND")
            cell.bg:SetAllPoints()
            cell.label = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cell.label:SetPoint("CENTER")
            cell.label:SetWordWrap(false)
            cell.label:SetWidth(DRAWER_CELL_WIDTH - 4)
            cell:EnableMouse(true)
            cell:RegisterForDrag("LeftButton")
        end
        cell:ClearAllPoints()
        local cellScale = drawerPanel:GetEffectiveScale()
        local cellX = Orbit.Engine.Pixel:Snap(DRAWER_OUTER_PAD + col * (DRAWER_CELL_WIDTH + DRAWER_PAD), cellScale)
        local cellY = Orbit.Engine.Pixel:Snap(yOffset, cellScale)
        cell:SetPoint("TOPLEFT", drawerPanel, "TOPLEFT", cellX, cellY)
        cell:SetParent(drawerPanel)
        
        if datatext.isPlaced then
            cell.bg:SetColorTexture(0, 0, 0, 0.3)
            cell.label:SetTextColor(0.4, 0.4, 0.4, 1)
            cell.label:SetText(datatext.name)
            cell:SetAlpha(0.6)
            cell:SetScript("OnEnter", nil)
            cell:SetScript("OnLeave", nil)
            cell:SetScript("OnDragStart", nil)
            cell:SetScript("OnDragStop", nil)
        else
            cell.bg:SetColorTexture(1, 1, 1, 0.05)
            cell.label:SetTextColor(1, 1, 1, 1)
            cell.label:SetText(datatext.name)
            cell:SetAlpha(1)
            
            cell:SetScript("OnEnter", function(f)
                f.bg:SetColorTexture(HIGHLIGHT_R, HIGHLIGHT_G, HIGHLIGHT_B, HIGHLIGHT_A)
                GameTooltip:SetOwner(f, "ANCHOR_TOP")
                GameTooltip:AddLine(datatext.name, 1, 1, 1)
                GameTooltip:AddLine("Drag to place on screen", 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end)
            cell:SetScript("OnLeave", function(f) f.bg:SetColorTexture(1, 1, 1, 0.05); GameTooltip:Hide() end)
            cell:SetScript("OnDragStart", function()
                local wf = datatext.frame
                if not wf then return end
                datatext.isPlaced = true
                wf:SetFrameStrata(Orbit.Constants.Strata.Topmost)
                wf:SetMovable(true)
                wf:Show()
                if wf.overlay then wf.overlay:Show() end
                DT.DatatextManager:EnableDatatext(datatext.name)
                -- Force an update via onEnable so the datatext refreshes (since it might have skipped updating if it was previously enabled)
                if datatext.onEnable then datatext.onEnable() end
                
                cell.bg:SetColorTexture(0, 0, 0, 0.3)
                cell.label:SetTextColor(0.4, 0.4, 0.4, 1)
                cell:SetAlpha(0.6)
                cell.isDraggingFromDrawer = true
                if not cell.dragTicker then
                    cell.dragTicker = C_Timer.NewTicker(0.05, function()
                        local cx, cy = GetCursorPosition()
                        local uipScale = UIParent:GetEffectiveScale()
                        local uipX = UIParent:GetWidth() / 2
                        local uipY = UIParent:GetHeight() / 2
                        local offsetX = ((cx / uipScale) - uipX) / wf:GetScale()
                        local offsetY = ((cy / uipScale) - uipY) / wf:GetScale()
                        offsetX, offsetY = Orbit.Engine.Pixel:SnapPosition(offsetX, offsetY, "CENTER", wf:GetWidth(), wf:GetHeight(), wf:GetEffectiveScale())

                        wf:ClearAllPoints()
                        wf:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
                        DT.DrawerUI:OnDatatextDragUpdate(datatext.name)
                        if Orbit.Engine.SelectionTooltip then
                            Orbit.Engine.SelectionTooltip:ShowPosition(wf, nil, true)
                        end
                    end)
                end
            end)
            cell:SetScript("OnDragStop", function()
                if not cell.isDraggingFromDrawer then return end
                local wf = datatext.frame
                if not wf then return end
                cell.isDraggingFromDrawer = false
                wf:SetFrameStrata(Orbit.Constants.Strata.HUD)
                wf:SetFrameLevel(500)
                
                local cx, cy = GetCursorPosition()
                local uipScale = UIParent:GetEffectiveScale()
                local uipX = UIParent:GetWidth() / 2
                local uipY = UIParent:GetHeight() / 2
                
                local offsetX = ((cx / uipScale) - uipX) / wf:GetScale()
                local offsetY = ((cy / uipScale) - uipY) / wf:GetScale()
                
                if Orbit.Engine.Pixel then
                    offsetX, offsetY = Orbit.Engine.Pixel:SnapPosition(offsetX, offsetY, "CENTER", wf:GetWidth(), wf:GetHeight(), wf:GetEffectiveScale())
                end
                
                wf:ClearAllPoints()
                wf:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
                if cell.dragTicker then cell.dragTicker:Cancel(); cell.dragTicker = nil end
                if Orbit.Engine.SelectionTooltip then Orbit.Engine.SelectionTooltip:ShowPosition(wf, nil, false) end
                DT.DatatextManager:OnDatatextDragStop(datatext.name)
                self:LayoutDrawer()
                if drawerPanel and drawerPanel.dropGlow then drawerPanel.dropGlow:Hide() end
            end)
        end
        
        cell:Show()
        activeCells[#activeCells + 1] = cell
        col = col + 1
        if col >= DRAWER_COLS then col = 0; yOffset = yOffset - (DRAWER_CELL_HEIGHT + DRAWER_PAD) end
    end
    
    local FO_INSET = 12
    local panelScale = drawerPanel:GetEffectiveScale()
    if #alldatatexts > 0 then
        local rows = math.ceil(#alldatatexts / DRAWER_COLS)
        drawerPanel:SetHeight(Orbit.Engine.Pixel:Snap(DRAWER_HEADER_HEIGHT + DRAWER_OUTER_PAD + (rows * DRAWER_CELL_HEIGHT) + ((rows - 1) * DRAWER_PAD) + DRAWER_BOTTOM_PAD + drawerPanel.footerHeight + FO_INSET, panelScale))
    else
        drawerPanel:SetHeight(Orbit.Engine.Pixel:Snap(DRAWER_HEADER_HEIGHT + DRAWER_OUTER_PAD + DRAWER_BOTTOM_PAD + drawerPanel.footerHeight + FO_INSET, panelScale))
    end
end

-- [ ANIMATION ] -------------------------------------------------------------------------------------
function DrawerUI:Toggle(anchor)
    if isOpen then self:Close() else self:Open(anchor) end
end

function DrawerUI:Open(anchor)
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("Datatexts cannot be opened in combat.", 1, 0, 0)
        return
    end
    if isOpen then return end
    isOpen = true
    self:CreatePanel()
    
    drawerPanel:ClearAllPoints()
    if anchor == "TOPLEFT" then drawerPanel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -20)
    elseif anchor == "BOTTOMLEFT" then drawerPanel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 20)
    elseif anchor == "TOPRIGHT" then drawerPanel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
    elseif anchor == "BOTTOMRIGHT" then drawerPanel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 20)
    else drawerPanel:SetPoint("CENTER") end
    
    self:LayoutDrawer()
    DT.DatatextManager:SetLocked(false)
    
    drawerPanel:SetAlpha(0)
    drawerPanel:Show()
    UIFrameFadeIn(drawerPanel, SLIDE_DURATION, 0, 1)
end

function DrawerUI:Close()
    if not isOpen then return end
    isOpen = false
    DT.DatatextManager:SetLocked(true)
    DT.DatatextManager:SavePositions()
    
    UIFrameFadeOut(drawerPanel, SLIDE_DURATION, 1, 0)
    C_Timer.After(SLIDE_DURATION, function()
        if not isOpen and drawerPanel then drawerPanel:Hide() end
    end)
end

function DrawerUI:IsOpen() return isOpen end

-- [ DRAG UPDATE ] -----------------------------------------------------------------------------------
function DrawerUI:OnDatatextDragUpdate(datatextId)
    -- Highlight drawer if cursor is over it during drag
    if not drawerPanel or not drawerPanel:IsShown() then return end
    if DT.DatatextManager:IsCursorOverFrame(drawerPanel) then
        drawerPanel.dropGlow:Show()
    else
        drawerPanel.dropGlow:Hide()
    end
end

-- [ TEARDOWN ] --------------------------------------------------------------------------------------
function DrawerUI:Destroy()
    self:DestroyCornerTriggers()
    if drawerPanel then drawerPanel:Hide(); drawerPanel = nil end
    isOpen = false
end

local combatGuard = CreateFrame("Frame")
combatGuard:RegisterEvent("PLAYER_REGEN_DISABLED")
combatGuard:SetScript("OnEvent", function()
    if isOpen then
        DrawerUI:Close()
        UIErrorsFrame:AddMessage("Datatexts closed due to combat.", 1, 1, 0)
    end
end)
