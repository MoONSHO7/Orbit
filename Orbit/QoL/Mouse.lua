-- [ MOUSE CURSOR HIGHLIGHT ] ------------------------------------------------------------------------
local _, Orbit = ...

-- [ MODULE ]-----------------------------------------------------------------------------------------
Orbit.Mouse = {}
local Mouse = Orbit.Mouse

Mouse._active = false
Mouse._frame = nil

-- Snapshot on Enable + CVAR_UPDATE; OnUpdate reads cached fields only — values change on settings edit, not 60Hz.
local CURSOR_SIZE_FOR_CVAR = { ["0"] = 32, ["1"] = 48, ["2"] = 64, ["3"] = 96, ["4"] = 128 }

local function RefreshSnapshot(frame)
    frame._cursorSize  = CURSOR_SIZE_FOR_CVAR[C_CVar.GetCVar("cursorSizePreferred")] or 32
    local db = (Orbit.db and Orbit.db.AccountSettings) or {}
    frame._customScale = db.CustomCursorScale or 0.55
    frame._customX     = db.CustomCursorX     or 2.10
    frame._customY     = db.CustomCursorY     or 1.40
end

local function OnUpdateCursor(self)
    local x, y = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    local size, customScale = self._cursorSize, self._customScale

    if self._currentSize ~= size or self._currentCustomScale ~= customScale then
        -- Atlas fills its full bounding box but the hardware pointer is narrow; customScale shrinks the gauntlet to match.
        local shrunkSize = size * customScale
        self:SetSize(shrunkSize, shrunkSize)
        self._currentSize = size
        self._currentCustomScale = customScale
    end

    if self._currentAtlasSize ~= size then
        self.tex:SetAtlas("Cursor_cast_" .. size)
        self._currentAtlasSize = size
    end

    -- Hide while the hardware cursor changes shape (mouseover unit, AoE targeting, item drag, tooltip owner).
    local shouldHide = UnitExists("mouseover") or SpellIsTargeting() or GetCursorInfo() or GameTooltip:IsOwned(UIParent)
    self.tex:SetAlpha(shouldHide and 0 or 1)

    self:ClearAllPoints()
    -- Physical pixel offsets applied before UI scale division so they're stable across scale changes.
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x + self._customX) / scale, (y + self._customY) / scale)
end

function Mouse:Enable()
    if self._active then return end
    self._active = true

    if not self._frame then
        self._frame = CreateFrame("Frame", "OrbitQoLCursorFrame", UIParent)
        Orbit.Engine.Pixel:Enforce(self._frame)
        self._frame:SetFrameStrata(Orbit.Constants.Strata.Topmost)
        self._frame:EnableMouse(false)

        local tex = self._frame:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        self._frame.tex = tex
    end

    RefreshSnapshot(self._frame)
    -- CVAR_UPDATE catches cursorSizePreferred via Blizzard's settings panel; SavedVariables edits go through Mouse:RefreshSnapshot directly.
    Orbit.EventBus:On("CVAR_UPDATE", function() RefreshSnapshot(self._frame) end, self)

    self._frame:Show()
    self._frame:SetScript("OnUpdate", OnUpdateCursor)
end

function Mouse:Disable()
    if not self._active then return end
    self._active = false
    Orbit.EventBus:OffContext(self)

    if self._frame then
        self._frame:SetScript("OnUpdate", nil)
        self._frame:Hide()
    end
end

-- Force-refresh after a CustomCursor* edit without /reload.
function Mouse:RefreshSnapshot()
    if self._frame then RefreshSnapshot(self._frame) end
end

-- [ AUTO-ENABLE ON LOGIN ]---------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    C_Timer.After(0.5, function()
        if Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.CustomCursor then
            Mouse:Enable()
        end
    end)
    loader:UnregisterAllEvents()
end)
