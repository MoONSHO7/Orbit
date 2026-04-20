-- [ ORBIT SELECTION - PEEK HIDE ] -------------------------------------------------------------------
-- Hold Left-Alt during Edit Mode to hide all selection overlays (Orbit + Blizzard native).
-- Release restores visual state via Selection:RefreshVisuals().

local _, Orbit = ...
local Engine = Orbit.Engine

local PeekHide = {}
Engine.SelectionPeekHide = PeekHide

-- MODIFIER_STATE_CHANGED emits raw modifier up/down regardless of keybindings,
-- unlike OnKeyDown/OnKeyUp which the binding system can swallow for bare modifiers.
local PEEK_KEY = "LALT"

local handler
local isHidden = false
local isActive = false

-- Only alpha — mutating EnableMouse mid-drag kills the overlay's OnDragStop.
local function HideAll(Selection)
    for _, selection in pairs(Selection.selections) do
        selection:SetAlpha(0)
    end
    if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
        for _, frame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            if frame.Selection then
                frame.Selection:SetAlpha(0)
            end
        end
    end
end

-- UpdateVisuals' isSelected branch sets alpha on regions but not the frame itself,
-- so we reset frame alpha first; RefreshVisuals then re-hides any that should stay hidden.
local function ShowAll(Selection)
    for _, selection in pairs(Selection.selections) do
        selection:SetAlpha(1)
    end
    if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
        for _, frame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            if frame.Selection then
                frame.Selection:SetAlpha(1)
            end
        end
    end
    Selection:RefreshVisuals()
end

function PeekHide:Enable(Selection)
    if not handler then
        handler = CreateFrame("Frame", "OrbitPeekHideWatcher", UIParent)
        handler:SetScript("OnEvent", function(_, _, key, state)
            if not isActive then return end
            if key ~= PEEK_KEY then return end
            if state == 1 and not isHidden then
                isHidden = true
                HideAll(Selection)
            elseif state == 0 and isHidden then
                isHidden = false
                ShowAll(Selection)
            end
        end)
        handler:RegisterEvent("MODIFIER_STATE_CHANGED")
    end
    isActive = true
    if IsLeftAltKeyDown() then
        isHidden = true
        HideAll(Selection)
    else
        isHidden = false
    end
end

function PeekHide:Disable(Selection)
    isActive = false
    if isHidden then
        isHidden = false
        Selection:RefreshVisuals()
    end
end
