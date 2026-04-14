-- [ METATALENTS / TREE LAYOUT ]-----------------------------------------------------------
-- Blizzard talent-tree layout tweaks that belong to the MetaTalents feature: rewriting the
-- SpendText on every button so capstone pips/masters and standard nodes each get their
-- own formatting, pulling apex (capstone) buttons underneath the hero talent container so
-- the percent badges have breathing room, and flattening the apex pip array into a straight
-- row so our circular badges stop colliding with the curved native track.

local _, Orbit = ...
local MT = Orbit.MetaTalents

local Layout = {}
MT.TreeLayout = Layout

local CAPSTONE_PIP_SPACING = 55
local CAPSTONE_PIP_Y = -30
local STANDARD_TEXT_DELTA = -2
local CAPSTONE_TEXT_DELTA = 2
local MIN_FONT_SIZE = 6

-- [ SPEND TEXT HOOK ]-------------------------------------------------------------------
-- Three cases: capstone pip children (suppressed entirely), capstone master nodes
-- (aggregate counter to the right), and standard nodes (scaled-down TOPRIGHT badge).
local function HandleCapstonePip(button)
    button.SpendText:SetText("")
    if button.spendTextShadows then
        for _, shadow in ipairs(button.spendTextShadows) do shadow:SetAlpha(0) end
    end
    button:SetAlpha(0)
    button:EnableMouse(false)
    if button._orbitMetaBadge then button._orbitMetaBadge:Hide() end
    if button._orbitShapeGlow then button._orbitShapeGlow:Hide() end
end

local function HandleCapstoneMaster(button)
    local current = button.nodeInfo.ranksPurchased or 0
    local maxRanks = button.nodeInfo.totalMaxRanks or 4
    button.SpendText:SetText(current .. "/" .. maxRanks)
    button.SpendText:Show()
    button.SpendText:ClearAllPoints()
    button.SpendText:SetPoint("LEFT", button, "RIGHT", 8, 0)

    if button._orbitCapstoneTextAdjusted then return end
    button._orbitCapstoneTextAdjusted = true
    local _, size = button.SpendText:GetFont()
    if not size then return end
    local fontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
    Orbit.Skin:SkinText(button.SpendText, { font = fontName, textSize = size + CAPSTONE_TEXT_DELTA })
    if button.spendTextShadows then
        for _, shadow in ipairs(button.spendTextShadows) do shadow:SetAlpha(0) end
    end
end

local function HandleStandardNode(button)
    if not button._orbitSpendTextAdjusted then
        button._orbitSpendTextAdjusted = true
        local _, size = button.SpendText:GetFont()
        if size then
            local newSize = math.max(MIN_FONT_SIZE, size + STANDARD_TEXT_DELTA)
            local fontName = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.Font
            Orbit.Skin:SkinText(button.SpendText, { font = fontName, textSize = newSize })
            if button.spendTextShadows then
                for _, shadow in ipairs(button.spendTextShadows) do shadow:SetAlpha(0) end
            end
        end
    end
    button.SpendText:ClearAllPoints()
    button.SpendText:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
end

function Layout.HookSpendText()
    hooksecurefunc(TalentButtonUtil, "SetSpendText", function(button)
        if not button.SpendText then return end
        if button.CalculateSpendStateForPip then HandleCapstonePip(button); return end
        if button.trackPipArray and button.nodeInfo then HandleCapstoneMaster(button); return end
        HandleStandardNode(button)
    end)
end

-- [ APEX RELOCATION ]-------------------------------------------------------------------
-- Apex/capstone buttons live inside a scrolled container that clips them near the edge of
-- the tree. Reparent to the hero container (escaping the scroll clip) and anchor to the
-- bottom of its expanded box. Wrapped in C_Timer.After(0) so the reparent lands after the
-- native layout settles on the same frame.
local function RelocateApexButton(button)
    if not (button.nodeInfo and button.Track and button.Track.ProgressBar) then return end
    local heroContainer = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame and PlayerSpellsFrame.TalentsFrame.HeroTalentsContainer
    if not (heroContainer and heroContainer:IsShown()) then return end
    local targetBox = heroContainer.ExpandedContainer or heroContainer
    C_Timer.After(0, function()
        button:SetParent(heroContainer)
        button:SetFrameLevel(heroContainer:GetFrameLevel() + 5)
        button:ClearAllPoints()
        button:SetPoint("TOP", targetBox, "BOTTOM", 0, -10)
    end)
end

function Layout.HookApplyPosition(setupDropdownsFn)
    hooksecurefunc(TalentButtonUtil, "ApplyPosition", function(button)
        setupDropdownsFn()
        RelocateApexButton(button)
    end)
end

-- [ CAPSTONE PIP FLATTENING ]-----------------------------------------------------------
-- Straightens the three-pip array Blizzard curves along the native progress track so the
-- Orbit pick-rate badges below each pip don't overlap. The native progress bar itself is
-- alpha'd out to hide the leftover arc.
function Layout.HookCapstoneTrack()
    if not TalentButtonCapstoneWithTrackMixin then return end
    hooksecurefunc(TalentButtonCapstoneWithTrackMixin, "UpdateTrack", function(button)
        if not button.trackPipArray then return end
        for index, pipFrame in ipairs(button.trackPipArray) do
            pipFrame:ClearAllPoints()
            if index == 1 then
                pipFrame:SetPoint("CENTER", button, "BOTTOM", -CAPSTONE_PIP_SPACING, CAPSTONE_PIP_Y)
            elseif index == 2 then
                pipFrame:SetPoint("CENTER", button, "BOTTOM", 0, CAPSTONE_PIP_Y)
            elseif index == 3 then
                pipFrame:SetPoint("CENTER", button, "BOTTOM", CAPSTONE_PIP_SPACING, CAPSTONE_PIP_Y)
            end
        end
        if button.Track and button.Track.ProgressBar then
            button.Track.ProgressBar:SetAlpha(0)
        end
    end)
end
