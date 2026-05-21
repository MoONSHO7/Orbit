-- [ MOUSE CURSOR HIGHLIGHT ] ------------------------------------------------------------------------
local _, Orbit = ...

-- [ MODULE ]-----------------------------------------------------------------------------------------
Orbit.Mouse = {}
local Mouse = Orbit.Mouse

Mouse._active = false
Mouse._frame = nil

-- S26-C1: snapshot on Enable + on CVAR_UPDATE; OnUpdate reads only cached fields. Previously the
-- cursor `OnUpdate` re-read `cursorSizePreferred` CVar through a 5-branch string-compare and 3
-- SavedVariables values 60×/sec — values that change only on a settings edit. Pattern mirrors the
-- canonical "snapshot+refresh" reference (IMPLEMENTATION-PLAN.md §3.1).
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
    -- CVAR_UPDATE fires when any CVar changes via SetCVar (incl. cursorSizePreferred via the
    -- Blizzard settings panel). The CustomCursorScale/X/Y SavedVariables change via Orbit's own
    -- account-settings UI — that panel can call Mouse:RefreshSnapshot() directly; otherwise the
    -- new values apply on next /reload or on the next Enable cycle.
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

-- Public: lets the QoL settings panel (or any caller) force-refresh the cached values after a
-- CustomCursor{Scale,X,Y} edit, without a /reload.
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
