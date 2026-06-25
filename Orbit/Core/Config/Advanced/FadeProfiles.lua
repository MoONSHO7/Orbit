-- [ FADE PROFILES PANEL ]---------------------------------------------------------------------------
local _, Orbit = ...
Orbit._AC = Orbit._AC or {}
local L = Orbit.L
local Layout = Orbit.Engine.Layout
local A = Layout.Advanced
local FP = Orbit.FadeProfiles

-- [ CONSTANTS ]--------------------------------------------------------------------------------------
local PAD = 8
local INDENT = 16
local SUBINDENT = 26
local SECTION_GAP = 4
local ICON = 14
local WARN = 12
local MEMBER_COLS = 2
local ROW_H = 18
local FADE_MIN_GAP = 10
local SLIDER_W = 180
local SLIDER_LABEL_GAP = 8
local SLIDER_READOUT_GAP = 10
local CONNECTOR_W = 30

local CATEGORY_LABELS = {
    UnitFrames = L.CFG_FP_CAT_UNITFRAMES, ActionBars = L.CFG_FP_CAT_ACTIONBARS,
    Cooldowns = L.CFG_FP_CAT_COOLDOWNS, HUD = L.CFG_FP_CAT_HUD,
    Other = L.CFG_FP_CAT_OTHER,
}

local CONDITION_LABEL = {}
for _, d in ipairs(FP:GetConditionCatalog()) do
    CONDITION_LABEL[d.key] = L[d.labelKey]
end
local NEG_LABEL = {
    combat = L.CFG_FP_NEG_COMBAT, resting = L.CFG_FP_NEG_RESTING, mounted = L.CFG_FP_NEG_MOUNTED,
    flying = L.CFG_FP_NEG_FLYING, swimming = L.CFG_FP_NEG_SWIMMING, stealth = L.CFG_FP_NEG_STEALTH,
    vehicle = L.CFG_FP_NEG_VEHICLE, petbattle = L.CFG_FP_NEG_PETBATTLE, raid = L.CFG_FP_NEG_RAID,
    party = L.CFG_FP_NEG_PARTY, group = L.CFG_FP_NEG_GROUP, target = L.CFG_FP_NEG_TARGET,
    focus = L.CFG_FP_NEG_FOCUS, pet = L.CFG_FP_NEG_PET, dead = L.CFG_FP_NEG_DEAD,
    dungeon = L.CFG_FP_NEG_DUNGEON, mythicplus = L.CFG_FP_NEG_MYTHICPLUS, raidinst = L.CFG_FP_NEG_RAIDINST,
    delve = L.CFG_FP_NEG_DELVE, battleground = L.CFG_FP_NEG_BATTLEGROUND, arena = L.CFG_FP_NEG_ARENA,
}
local function CondLabel(c)
    if c.key == "mouseover" then
        return c.state == "group" and L.CFG_FP_COND_MOUSEOVER_GROUP or L.CFG_FP_COND_MOUSEOVER_SEPARATE
    end
    local pos = CONDITION_LABEL[c.key] or c.key
    if c.state == "false" then return NEG_LABEL[c.key] or pos end
    return pos
end

-- [ WIDGET RECYCLER ]--------------------------------------------------------------------------------
-- WoW frames/regions are never GC'd, so the per-profile widget tree is reused across rebuilds instead of orphaned. REC is set to the active content's recycler before each rebuild; helpers Acquire from it and Release them all at the start of the next rebuild.
local REC
local function NewRecycler()
    local rec = { free = {}, used = {} }
    function rec:Get(kind, create)
        local list = self.free[kind]
        local w = list and table.remove(list)
        if not w then w = create(); w._recKind = kind end
        self.used[#self.used + 1] = w
        return w
    end
    function rec:ReleaseAll()
        for _, w in ipairs(self.used) do
            local kind = w._recKind
            w:Hide(); w:ClearAllPoints(); w:SetParent(nil)
            self.free[kind] = self.free[kind] or {}
            self.free[kind][#self.free[kind] + 1] = w
        end
        wipe(self.used)
    end
    return rec
end

-- [ WIDGET HELPERS ]---------------------------------------------------------------------------------
local function PoolFS(parent, font, layer)
    local fs = REC:Get("fs_" .. (font or "GameFontHighlightSmall"), function() return parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlightSmall") end)
    fs:SetParent(parent); fs:Show()
    fs:SetTextColor(1, 1, 1); fs:SetJustifyH("LEFT"); fs:SetWidth(0); fs:SetWordWrap(true); fs:SetNonSpaceWrap(false)
    return fs
end

local function PoolTexture(parent)
    local tex = REC:Get("tex", function() return parent:CreateTexture(nil, "BACKGROUND") end)
    tex:SetParent(parent); tex:Show()
    return tex
end

local function IconButton(parent, atlas, tooltip, onClick)
    local btn = REC:Get("icon", function()
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(ICON, ICON)
        local icon = b:CreateTexture(nil, "ARTWORK"); icon:SetAllPoints(); b.Icon = icon
        b:SetScript("OnEnter", function(self)
            self.Icon:SetAlpha(0.8)
            if not self._tip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(self._tip, 1, 1, 1, 1, true); GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self) self.Icon:SetAlpha(1); GameTooltip:Hide() end)
        return b
    end)
    btn:SetParent(parent); btn:Show()
    btn.Icon:SetAtlas(atlas); btn.Icon:SetVertexColor(1, 1, 1)
    btn._tip = tooltip
    btn:SetScript("OnClick", onClick)
    return btn
end

local function AddLink(parent, text, onClick, atlas, iconColor)
    local btn = REC:Get("link", function()
        local b = CreateFrame("Button", nil, parent)
        b:SetHeight(16)
        b._icon = b:CreateTexture(nil, "ARTWORK"); b._icon:SetSize(WARN, WARN); b._icon:SetPoint("LEFT")
        b._label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b._label:SetPoint("LEFT", b._icon, "RIGHT", 3, 0)
        b:SetScript("OnEnter", function(self) self._label:SetTextColor(1, 1, 1) end)
        b:SetScript("OnLeave", function(self) self._label:SetTextColor(1, 0.82, 0) end)
        return b
    end)
    btn:SetParent(parent); btn:Show()
    btn._icon:SetAtlas(atlas or "communities-chat-icon-plus")
    btn._icon:SetVertexColor(iconColor and iconColor[1] or 1, iconColor and iconColor[2] or 1, iconColor and iconColor[3] or 1)
    btn._label:SetText(text); btn._label:SetTextColor(1, 0.82, 0)
    btn:SetWidth(WARN + 3 + btn._label:GetStringWidth() + 2)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function ConditionToggle(parent, text, onClick)
    local btn = REC:Get("condtoggle", function()
        local b = CreateFrame("Button", nil, parent)
        b:SetHeight(18)
        b._label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b._label:SetPoint("LEFT")
        b:SetScript("OnEnter", function(self)
            self._label:SetTextColor(1, 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(L.CFG_FP_COND_TOGGLE_TT, 1, 1, 1, nil, true); GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self) self._label:SetTextColor(0.55, 0.78, 1); GameTooltip:Hide() end)
        return b
    end)
    btn:SetParent(parent); btn:Show()
    btn._label:SetText(text); btn._label:SetTextColor(0.55, 0.78, 1)
    btn:SetWidth(btn._label:GetStringWidth() + 6)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function ConnectorToggle(parent, conn, onClick)
    local btn = REC:Get("conntoggle", function()
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(CONNECTOR_W, 18)
        b._label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b._label:SetPoint("LEFT")
        b:SetScript("OnEnter", function(self) self._label:SetTextColor(1, 1, 1) end)
        b:SetScript("OnLeave", function(self) self._label:SetTextColor(1, 0.7, 0.2) end)
        return b
    end)
    btn:SetParent(parent); btn:Show()
    btn._label:SetText(conn == "or" and L.CFG_FP_CONN_OR or L.CFG_FP_CONN_AND)
    btn._label:SetTextColor(1, 0.7, 0.2)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function ZebraRow(body, y, h)
    local bg = PoolTexture(body)
    bg:SetColorTexture(1, 1, 1, 0.03)
    bg:SetPoint("TOPLEFT", INDENT - 4, y)
    bg:SetPoint("TOPRIGHT", body, "TOPRIGHT", -(INDENT - 4), y)
    bg:SetHeight(h)
end

-- [ HELPERS ]----------------------------------------------------------------------------------------
local function BuildSentence(p)
    local fade = p.fade or 100
    local s, moPhrase
    for _, c in ipairs(p.conditions) do
        if c.key == "mouseover" then
            moPhrase = (c.state == "group") and L.CFG_FP_SENTENCE_MO_GROUP or L.CFG_FP_SENTENCE_MO_SEPARATE
        else
            local label = CondLabel(c)
            if not s then
                s = label
            else
                s = s .. ((c.connector == "or") and L.CFG_FP_OR or L.CFG_FP_AND) .. label
            end
        end
    end
    if not s then
        if moPhrase then return L.CFG_FP_SENTENCE_MO_ONLY_F:format(fade, moPhrase) end
        return L.CFG_FP_SENTENCE_EMPTY_F:format(fade)
    end
    if moPhrase then return L.CFG_FP_SENTENCE_MO_F:format(fade, s, moPhrase) end
    return L.CFG_FP_SENTENCE_F:format(fade, s)
end

local function FrameLookup()
    local VE = Orbit.VisibilityEngine
    local byKey, byCat = {}, {}
    local function add(list, gate)
        for _, e in ipairs(list) do
            if not gate or gate(e) then
                byKey[e.key] = e
                local cat = VE:GetCategory(e)
                byCat[cat] = byCat[cat] or {}
                byCat[cat][#byCat[cat] + 1] = e
            end
        end
    end
    add(VE:GetAllFrames(), function(e) return VE:GetPlugin(e) and Orbit:IsPluginEnabled(e.plugin) end)
    add(VE:GetBlizzardFrames())
    return byKey, byCat
end

StaticPopupDialogs["ORBIT_FP_DELETE_PROFILE"] = {
    text = L.CFG_FP_DELETE_CONFIRM_F,
    button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    OnAccept = function(_, data) FP:DeleteProfile(data) end,
}

StaticPopupDialogs["ORBIT_FP_NAME_PROFILE"] = {
    text = "%s",
    button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(self)
        local eb = self.EditBox or self.editBox
        local name = eb and strtrim(eb:GetText())
        if name and name ~= "" and self.data then self.data(name) end
    end,
    EditBoxOnEnterPressed = function(self)
        local dlg = self:GetParent()
        local name = strtrim(self:GetText())
        if name ~= "" and dlg.data then dlg.data(name) end
        dlg:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

local function PromptName(prompt, default, onName)
    local dlg = StaticPopup_Show("ORBIT_FP_NAME_PROFILE", prompt)
    if not dlg then return end
    dlg.data = onName
    local eb = dlg.EditBox or dlg.editBox
    if eb then
        eb:SetText(default or "")
        eb:HighlightText()
        eb:SetFocus()
    end
end

-- [ BUILD ]------------------------------------------------------------------------------------------
function Orbit._AC.CreateFadeProfilesContent(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    content:Hide()
    content._sections = {}
    content._rec = NewRecycler()

    local header = Layout:CreateSectionHeader(content, L.CFG_VISIBILITY_ENGINE)
    header:SetPoint("TOPLEFT", A.PADDING, A.TITLE_Y)
    header:SetPoint("TOPRIGHT", -A.PADDING, A.TITLE_Y)
    local desc = Layout:CreateDescription(content, L.CFG_FP_DESC, A.MUTED)
    desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)

    local revealCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    revealCheck:SetSize(24, 24)
    -- Right-align with the accordion bars' edge: A.PADDING + scrollbar reserve (14) + accordion bar inset (20).
    revealCheck:SetPoint("TOPRIGHT", content, "TOPRIGHT", -(A.PADDING + 34), A.TITLE_Y + 2)
    local revealLabel = revealCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    revealLabel:SetPoint("RIGHT", revealCheck, "LEFT", -2, 0)
    revealLabel:SetText(L.CFG_FP_REVEAL_ALL)
    revealCheck:SetScript("OnClick", function(self) FP:SetRevealAll(self:GetChecked()) end)
    revealCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.CFG_FP_REVEAL_ALL, 1, 0.82, 0, 1, true)
        GameTooltip:AddLine(L.CFG_FP_REVEAL_ALL_TT, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    revealCheck:SetScript("OnLeave", GameTooltip_Hide)

    local newBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    newBtn:SetSize(120, 24)
    newBtn:SetText(L.CFG_FP_NEW_PROFILE)
    newBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -A.PADDING, A.PADDING)
    newBtn:SetScript("OnClick", function()
        PromptName(L.CFG_FP_NEW_PROFILE_PROMPT, L.CFG_FP_NEW_PROFILE_NAME, function(name)
            content._pendingExpandId = FP:CreateProfile(name)
        end)
    end)

    local scrollFrame, scrollChild = Layout:CreateScrollArea(content, A.CONTENT_START_Y, A.PADDING + 34)

    local emptyHint = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyHint:SetPoint("TOP", scrollFrame, "TOP", 0, -24)
    emptyHint:SetText(L.CFG_FP_EMPTY)
    emptyHint:Hide()
    content._emptyHint = emptyHint

    local function Relayout()
        local y = 0
        for _, sec in ipairs(content._sections) do
            sec:ClearAllPoints()
            sec:SetPoint("TOPLEFT", 0, y)
            sec:SetPoint("TOPRIGHT", 0, y)
            y = y - sec:GetHeight() - SECTION_GAP
        end
        scrollFrame:UpdateContentHeight(-y + PAD)
    end

    local function BuildProfileBody(section, p, byKey, byCat, memberCount)
        local body = section:GetBody()
        local y = -PAD

        local sentence = PoolFS(body, "GameFontNormalSmall")
        sentence:SetPoint("TOPLEFT", INDENT, y)
        sentence:SetNonSpaceWrap(true)
        -- Wrap width = scroll width minus the accordion bar's 20px right inset and the text's L/R margin; advance by the measured wrapped height so long sentences flow onto extra lines without overlapping the controls below.
        local sentenceW = scrollFrame:GetWidth() - 20 - 2 * INDENT
        if sentenceW > 1 then sentence:SetWidth(sentenceW) end
        sentence:SetText("|cFFFFD100" .. BuildSentence(p) .. "|r")
        y = y - sentence:GetStringHeight() - 16

        local enabled = REC:Get("check", function()
            local c = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
            c:SetSize(20, 20)
            return c
        end)
        enabled:SetParent(body); enabled:Show()
        enabled:SetPoint("TOPLEFT", INDENT - 2, y)
        enabled:SetChecked(p.enabled)
        enabled:SetScript("OnClick", function(self) FP:SetEnabled(p.id, self:GetChecked()) end)
        local enLabel = PoolFS(enabled, "GameFontHighlightSmall")
        enLabel:SetPoint("LEFT", enabled, "RIGHT", 2, 0)
        enLabel:SetText(L.CFG_FP_ENABLED)
        local delBtn = AddLink(body, L.CFG_FP_DELETE, function()
            StaticPopup_Show("ORBIT_FP_DELETE_PROFILE", p.name, nil, p.id)
        end, "transmog-icon-remove", { 1, 0.45, 0.45 })
        delBtn:SetPoint("TOPRIGHT", body, "TOPRIGHT", -INDENT, y - 2)
        local copyBtn = AddLink(body, L.CFG_FP_DUPLICATE, function()
            PromptName(L.CFG_FP_DUPLICATE_PROMPT, p.name, function(name) FP:DuplicateProfile(p.id, name) end)
        end)
        copyBtn:SetPoint("RIGHT", delBtn, "LEFT", -12, 0)

        local fadeGroup = REC:Get("frame", function() return CreateFrame("Frame", nil, body) end)
        fadeGroup:SetParent(body); fadeGroup:Show()
        fadeGroup:SetHeight(20)
        local fadeLabel = PoolFS(fadeGroup, "GameFontHighlightSmall")
        fadeLabel:SetPoint("LEFT")
        fadeLabel:SetText(L.CFG_OPACITY)
        local sVal = PoolFS(fadeGroup, "GameFontHighlightSmall")
        local hasMouseover = false
        for _, c in ipairs(p.conditions) do if c.key == "mouseover" then hasMouseover = true; break end end
        local function FadeText(low, high)
            return low .. "% – " .. high .. "%"
        end
        local rangeSlider = REC:Get("rangeslider", function() return Layout:CreateRangeSlider(fadeGroup, SLIDER_W, {}) end)
        rangeSlider:SetParent(fadeGroup); rangeSlider:Show()
        rangeSlider:Configure({
            minGap = FADE_MIN_GAP, dual = true,
            lowTip = L.CFG_FP_THUMB_FADE, highTip = L.CFG_FP_THUMB_MAX,
            onChange = function(low, high)
                sVal:SetText(FadeText(low, high))
                Orbit.Async:Debounce("FP_Fade_" .. p.id, function() FP:SetFadeRange(p.id, low, high) end, 0.3)
            end,
        })
        rangeSlider:SetPoint("LEFT", fadeLabel, "RIGHT", SLIDER_LABEL_GAP, 0)
        sVal:SetPoint("LEFT", rangeSlider, "RIGHT", SLIDER_READOUT_GAP, 0)
        -- Reserve a constant readout width (the widest possible value) so a changing %-digit count never alters the group's width. The group is centered, so a width that tracked the live text would re-center it every commit and the whole slider would visibly jiggle while dragging.
        sVal:SetText("100% – 100%")
        local readoutW = math.ceil(sVal:GetStringWidth())
        sVal:SetWidth(readoutW)
        sVal:SetWordWrap(false)
        sVal:SetJustifyH("LEFT")
        sVal:SetTextColor(1, 0.82, 0)
        rangeSlider:SetRange(p.fade or 50, p.maxOpacity or 100)
        sVal:SetText(FadeText(rangeSlider.low, rangeSlider.high))
        -- Constant group width (fixed label + slider + gaps + fixed readout reserve) → stable centered position, immune to the live value.
        fadeGroup:SetWidth(fadeLabel:GetStringWidth() + (SLIDER_W + SLIDER_LABEL_GAP + SLIDER_READOUT_GAP) + readoutW)
        local fadeSpacer = REC:Get("frame", function() return CreateFrame("Frame", nil, body) end)
        fadeSpacer:SetParent(body); fadeSpacer:Show()
        fadeSpacer:SetPoint("LEFT", enLabel, "RIGHT", 0, 0)
        fadeSpacer:SetPoint("RIGHT", copyBtn, "LEFT", 0, 0)
        fadeSpacer:SetHeight(20)
        fadeGroup:SetPoint("CENTER", fadeSpacer, "CENTER")
        y = y - 30

        local whenLabel = PoolFS(body, "GameFontNormal")
        whenLabel:SetPoint("TOPLEFT", INDENT, y)
        whenLabel:SetText(L.CFG_FP_WHEN)
        whenLabel:SetTextColor(0.6, 0.8, 1)
        local addCond = AddLink(body, L.CFG_FP_ADD_CONDITION, function(self)
            MenuUtil.CreateContextMenu(self, function(_, root)
                local instanceSub
                for _, d in ipairs(FP:GetConditionCatalog()) do
                    if d.category == "Instance" then
                        instanceSub = instanceSub or root:CreateButton(L.CFG_FP_INSTANCE_TYPE)
                        instanceSub:CreateButton(L[d.labelKey], function() FP:AddCondition(p.id, d.key) end)
                    else
                        root:CreateButton(L[d.labelKey], function() FP:AddCondition(p.id, d.key) end)
                    end
                end
            end)
        end)
        addCond:SetPoint("TOPRIGHT", -INDENT, y)
        y = y - 18

        if #p.conditions == 0 then
            local hint = PoolFS(body, "GameFontDisableSmall")
            hint:SetPoint("TOPLEFT", SUBINDENT, y - 1)
            hint:SetText(L.CFG_FP_NO_CONDITIONS_HINT)
            y = y - 16
        end

        -- The engine ignores the connector on the FIRST non-mouseover condition (it opens the first group), so only show a toggle once a real condition already precedes this one — gating on raw index would render an inert toggle when a Mouseover sits at index 1.
        local seenReal = false
        for i, c in ipairs(p.conditions) do
            if i % 2 == 0 then ZebraRow(body, y, 20) end
            local isReal = c.key ~= "mouseover"
            if isReal and seenReal then
                local connBtn = ConnectorToggle(body, c.connector or "and", function()
                    FP:SetConditionConnector(p.id, i, c.connector == "or" and "and" or "or")
                end)
                connBtn:SetPoint("TOPLEFT", SUBINDENT, y - 1)
            end
            if isReal then seenReal = true end
            local condBtn = ConditionToggle(body, CondLabel(c), function()
                if c.key == "mouseover" then
                    FP:SetConditionState(p.id, i, c.state == "group" and "separate" or "group")
                else
                    FP:SetConditionState(p.id, i, c.state == "false" and "true" or "false")
                end
            end)
            condBtn:SetPoint("TOPLEFT", SUBINDENT + CONNECTOR_W + 6, y - 1)
            local rmBtn = IconButton(body, "transmog-icon-remove", nil, function() FP:RemoveCondition(p.id, i) end)
            rmBtn:SetPoint("TOPRIGHT", -INDENT, y - 3)
            y = y - 20
        end

        y = y - SECTION_GAP - 14

        local memberKeys = {}
        for key in pairs(p.members) do memberKeys[#memberKeys + 1] = key end
        table.sort(memberKeys, function(a, b)
            return (byKey[a] and byKey[a].display or a) < (byKey[b] and byKey[b].display or b)
        end)

        local framesLabel = PoolFS(body, "GameFontNormal")
        framesLabel:SetPoint("TOPLEFT", INDENT, y)
        framesLabel:SetText(L.CFG_FP_FRAMES .. " |cFF999999(" .. #memberKeys .. ")|r")
        framesLabel:SetTextColor(0.6, 0.8, 1)
        local addFrames = AddLink(body, L.CFG_FP_ADD_FRAMES, function(self)
            local VE = Orbit.VisibilityEngine
            MenuUtil.CreateContextMenu(self, function(_, root)
                for _, cat in ipairs(VE:GetCategoryOrder()) do
                    local entries = byCat[cat]
                    if entries then
                        local sub = root:CreateButton(CATEGORY_LABELS[cat] or cat)
                        sub:CreateButton("|cFFFFD100" .. L.CFG_CHECK_ALL .. "|r", function()
                            for _, e in ipairs(entries) do FP:SetMember(p.id, e.key, true) end
                        end)
                        for _, e in ipairs(entries) do
                            if not FP:IsMember(p.id, e.key) then
                                sub:CreateButton(e.display, function() FP:SetMember(p.id, e.key, true) end)
                            end
                        end
                    end
                end
            end)
        end)
        addFrames:SetPoint("TOPRIGHT", -INDENT, y)
        y = y - 18

        if #memberKeys == 0 then
            local cta = PoolFS(body, "GameFontDisableSmall")
            cta:SetPoint("TOPLEFT", SUBINDENT, y - 1)
            cta:SetText("|cFFFFA000" .. L.CFG_FP_NO_FRAMES_CTA .. "|r")
            y = y - 16
        end

        -- Two-column grid: the left column hugs the body's left margin, the right column the body's horizontal midpoint ("TOP"). The index math below generalizes to MEMBER_COLS columns, but this pixel anchoring is specialized for two.
        for i, key in ipairs(memberKeys) do
            local rowIdx = math.floor((i - 1) / MEMBER_COLS)
            local colIdx = (i - 1) % MEMBER_COLS
            local rowY = y - rowIdx * ROW_H
            if colIdx == 0 and rowIdx % 2 == 1 then ZebraRow(body, rowY, ROW_H) end
            local entry = byKey[key]
            local mLabel = PoolFS(body, "GameFontHighlightSmall")
            mLabel:SetText(entry and entry.display or key)
            local rmBtn = IconButton(body, "transmog-icon-remove", nil, function() FP:SetMember(p.id, key, false) end)
            if colIdx == 0 then
                mLabel:SetPoint("TOPLEFT", SUBINDENT, rowY - 3)
                rmBtn:SetPoint("TOPRIGHT", body, "TOP", -INDENT, rowY - 2)
            else
                mLabel:SetPoint("TOPLEFT", body, "TOP", INDENT, rowY - 3)
                rmBtn:SetPoint("TOPRIGHT", -INDENT, rowY - 2)
            end
            -- A Mouseover profile applies no fade at all to secure Blizzard frames (no hover ticker) — flag it rather than leaving a silent no-op.
            if hasMouseover and entry and entry.secure then
                mLabel:SetTextColor(1, 0.6, 0.2)
                local secureWarn = REC:Get("securewarn", function()
                    local b = CreateFrame("Button", nil, body)
                    b:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(self._display, 1, 0.6, 0.2)
                        GameTooltip:AddLine(L.CFG_FP_SECURE_WARN, 1, 1, 1, true)
                        GameTooltip:Show()
                    end)
                    b:SetScript("OnLeave", GameTooltip_Hide)
                    return b
                end)
                secureWarn:SetParent(body); secureWarn:Show()
                secureWarn:SetAllPoints(mLabel)
                secureWarn._display = entry.display
            end
            local count = memberCount[key] or 1
            if count > 1 then
                local resolvedPct = math.floor(FP:GetResolvedAlpha(key) * 100 + 0.5)
                local thisWins = FP:IsProfileFiring(p.id) and (math.floor((p.fade or 100) + 0.5) == resolvedPct)
                local res = PoolFS(body, "GameFontDisableSmall")
                res:SetPoint("RIGHT", rmBtn, "LEFT", -6, 0)
                res:SetText((thisWins and "|cFFFFD100" or "|cFF888888") .. "-> " .. resolvedPct .. "%|r")
                local warn = REC:Get("warn", function()
                    local b = CreateFrame("Button", nil, body)
                    b:SetSize(WARN, WARN)
                    local wtex = b:CreateTexture(nil, "ARTWORK")
                    wtex:SetAllPoints()
                    wtex:SetAtlas("transmog-icon-warning-small")
                    b:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(self._title, 1, 1, 1)
                        for _, prof in ipairs(FP:GetProfilesForMember(self._key)) do
                            local win = FP:IsProfileFiring(prof.id) and (math.floor((prof.fade or 100) + 0.5) == self._resolvedPct)
                            local cr, cg, cb = win and 1 or 0.7, win and 0.82 or 0.7, win and 0 or 0.7
                            GameTooltip:AddDoubleLine(prof.name, (prof.fade or 100) .. "%", cr, cg, cb, cr, cg, cb)
                        end
                        GameTooltip:Show()
                    end)
                    b:SetScript("OnLeave", GameTooltip_Hide)
                    return b
                end)
                warn:SetParent(body); warn:Show()
                warn:SetPoint("LEFT", mLabel, "RIGHT", 6, 0)
                warn._title = entry and entry.display or key
                warn._key = key
                warn._resolvedPct = resolvedPct
            end
        end
        y = y - math.ceil(#memberKeys / MEMBER_COLS) * ROW_H

        section:SetContentHeight(-y + PAD)
    end

    local function MembershipCounts()
        local counts = {}
        for _, p in ipairs(FP:GetProfiles()) do
            for key in pairs(p.members) do counts[key] = (counts[key] or 0) + 1 end
        end
        return counts
    end

    function content:Rebuild()
        -- Recycle every per-profile widget (sections and their body controls) from the previous build; WoW frames are never GC'd, so pooling is the only way to avoid an unbounded leak across rebuilds.
        REC = self._rec
        local expanded = {}
        for _, sec in ipairs(self._sections) do
            if sec._profileId then expanded[sec._profileId] = sec:IsExpanded() end
        end
        self._rec:ReleaseAll()
        wipe(self._sections)
        local byKey, byCat = FrameLookup()
        local memberCount = MembershipCounts()
        for _, p in ipairs(FP:GetProfiles()) do
            local firing = FP:IsProfileFiring(p.id)
            local title = (p.name or "?") .. "  |cFF999999" .. (p.fade or 100) .. "%|r"
            local sec = REC:Get("accordion", function() return Layout:CreateAccordion(scrollChild, "") end)
            sec:SetParent(scrollChild); sec:Show()
            sec:Reset(title)
            sec:SetStatus(firing and "|cFF40FF40" .. L.CFG_FP_ACTIVE .. "|r" or "|cFFFF5555" .. L.CFG_FP_INACTIVE .. "|r")
            sec._profileId = p.id
            sec._onToggle = Relayout
            sec._rightClickTip = L.CFG_FP_RENAME_HINT
            sec._onRightClick = function()
                PromptName(L.CFG_FP_RENAME_PROMPT, p.name, function(name) FP:SetName(p.id, name) end)
            end
            BuildProfileBody(sec, p, byKey, byCat, memberCount)
            if expanded[p.id] or p.id == self._pendingExpandId then sec:SetExpanded(true) end
            self._sections[#self._sections + 1] = sec
        end
        self._pendingExpandId = nil
        self._emptyHint:SetShown(#FP:GetProfiles() == 0)
        Relayout()
        revealCheck:SetChecked(FP:IsRevealAll())
    end

    local rebuildPending
    local function ScheduleRebuild()
        if rebuildPending then return end
        rebuildPending = true
        C_Timer.After(0, function()
            rebuildPending = false
            if content:IsShown() then content:Rebuild() end
        end)
    end

    content:SetScript("OnShow", function(self) self:Rebuild() end)
    if Orbit.EventBus then
        Orbit.EventBus:On("ORBIT_FADE_PROFILES_CHANGED", ScheduleRebuild)
        -- Game-state transitions only fire ORBIT_VISIBILITY_CHANGED; refresh so the Active/Inactive and resolved-% diagnostics don't freeze while the tab is open (ScheduleRebuild already no-ops when hidden).
        Orbit.EventBus:On("ORBIT_VISIBILITY_CHANGED", ScheduleRebuild)
    end
    return content
end
