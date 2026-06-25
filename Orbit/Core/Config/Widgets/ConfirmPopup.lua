local _, Orbit = ...
local L = Orbit.L
local Engine = Orbit.Engine
local Layout = Engine.Layout

-- [ CONSTANTS ] -------------------------------------------------------------------------------------
local WIDTH = 360
local PAD = 16
local BG_INSET_LEFT = 6
local BG_INSET_TOP = 21
local BG_INSET_RIGHT = 2
local BG_INSET_BOTTOM = 2
local STREAKS_OVERSHOOT_X = 2
local STREAKS_OVERSHOOT_Y = 7
local TITLE_OFFSET = 6
local BTN_HEIGHT = 24
local BTN_GAP = 8
local NINESLICE_LEVEL_OFFSET = 1
local CONTENT_LEVEL_OFFSET = 10

-- [ FRAME ] -----------------------------------------------------------------------------------------
local frame = CreateFrame("Frame", "OrbitConfirmPopup", UIParent)
frame:SetWidth(WIDTH)
frame:SetPoint("CENTER")
frame:SetFrameStrata(Orbit.Constants.Strata.Topmost)
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:Hide()

frame.NineSlice = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
frame.NineSlice.layoutType = "ButtonFrameTemplateNoPortrait"
NineSliceUtil.ApplyLayoutByName(frame.NineSlice, "ButtonFrameTemplateNoPortrait")
frame.NineSlice:SetFrameLevel(frame:GetFrameLevel() + NINESLICE_LEVEL_OFFSET)

frame.Bg = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
frame.Bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
frame.Bg:SetHorizTile(true)
frame.Bg:SetVertTile(true)
frame.Bg:SetPoint("TOPLEFT", BG_INSET_LEFT, -BG_INSET_TOP)
frame.Bg:SetPoint("BOTTOMRIGHT", -BG_INSET_RIGHT, BG_INSET_BOTTOM)

frame.TopTileStreaks = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
frame.TopTileStreaks:SetAtlas("_UI-Frame-TopTileStreaks", true)
frame.TopTileStreaks:SetPoint("TOPLEFT", frame.Bg, "TOPLEFT", -STREAKS_OVERSHOOT_X, STREAKS_OVERSHOOT_Y)
frame.TopTileStreaks:SetPoint("TOPRIGHT", frame.Bg, "TOPRIGHT", STREAKS_OVERSHOOT_X, STREAKS_OVERSHOOT_Y)

-- Title sits above the NineSlice so the metal top bar never overdraws it.
frame.TitleContainer = CreateFrame("Frame", nil, frame)
frame.TitleContainer:SetFrameLevel(frame.NineSlice:GetFrameLevel() + CONTENT_LEVEL_OFFSET)
frame.TitleContainer:SetPoint("TOPLEFT", BG_INSET_LEFT, -TITLE_OFFSET)
frame.TitleContainer:SetPoint("TOPRIGHT", -BG_INSET_LEFT, -TITLE_OFFSET)
frame.TitleContainer:SetHeight(BG_INSET_TOP)
frame.title = frame.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOP", frame.TitleContainer, "TOP")

frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.text:SetPoint("TOP", frame, "TOP", 0, -(BG_INSET_TOP + PAD))
frame.text:SetWidth(WIDTH - PAD * 2)
frame.text:SetJustifyH("CENTER")
frame.text:SetSpacing(2)

frame.acceptBtn = Layout:CreateButton(frame, "", function()
    frame:Hide()
    if frame._onAccept then frame._onAccept(frame._data) end
end)
frame.acceptBtn:SetHeight(BTN_HEIGHT)
frame.acceptBtn:SetFrameLevel(frame.NineSlice:GetFrameLevel() + CONTENT_LEVEL_OFFSET)

frame.cancelBtn = Layout:CreateButton(frame, L.CMN_CANCEL, function() frame:Hide() end)
frame.cancelBtn:SetHeight(BTN_HEIGHT)
frame.cancelBtn:SetFrameLevel(frame.NineSlice:GetFrameLevel() + CONTENT_LEVEL_OFFSET)

table.insert(UISpecialFrames, "OrbitConfirmPopup")

-- [ API ] -------------------------------------------------------------------------------------------
function Layout:ShowConfirm(opts)
    frame.title:SetText(opts.title or "")
    frame.text:SetText(opts.text or "")
    frame._onAccept = opts.onAccept
    frame._data = opts.data

    frame.acceptBtn:SetText(opts.acceptText or "")
    frame.cancelBtn:SetText(opts.cancelText or L.CMN_CANCEL)
    local btnWidth = (WIDTH - PAD * 2 - BTN_GAP) / 2
    frame.acceptBtn:SetWidth(btnWidth)
    frame.cancelBtn:SetWidth(btnWidth)
    frame.acceptBtn:ClearAllPoints()
    frame.acceptBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
    frame.cancelBtn:ClearAllPoints()
    frame.cancelBtn:SetPoint("BOTTOMLEFT", frame.acceptBtn, "BOTTOMRIGHT", BTN_GAP, 0)

    frame:SetHeight(BG_INSET_TOP + PAD + frame.text:GetStringHeight() + PAD + BTN_HEIGHT + PAD)
    frame:Show()
    frame:Raise()
    return frame
end
