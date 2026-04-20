-- [ MOUSE CURSOR HIGHLIGHT ] ------------------------------------------------------------------------
local _, Orbit = ...

-- [ MODULE ]----------------------------------------------------------------------------------------
Orbit.Mouse = {}
local Mouse = Orbit.Mouse

Mouse._active = false
Mouse._frame = nil

local function GetCurrentCursorSize()
    local cvar = C_CVar.GetCVar("cursorSizePreferred")
    if cvar == "0" then return 32
    elseif cvar == "1" then return 48
    elseif cvar == "2" then return 64
    elseif cvar == "3" then return 96
    elseif cvar == "4" then return 128
    end
    return 32
end

local function OnUpdateCursor(self)
    local x, y = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    
    local size = GetCurrentCursorSize()
    
    local db = Orbit.db and Orbit.db.AccountSettings or {}
    local customScale = db.CustomCursorScale or 0.55
    local customX = db.CustomCursorX or 2.10
    local customY = db.CustomCursorY or 1.40
    
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
    x = x + customX
    y = y + customY
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

function Mouse:Enable()
    if self._active then return end
    self._active = true

    if not self._frame then
        self._frame = CreateFrame("Frame", "OrbitQoLCursorFrame", UIParent)
        self._frame:SetFrameStrata(Orbit.Constants.Strata.Topmost)
        self._frame:EnableMouse(false)

        local tex = self._frame:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        self._frame.tex = tex
    end

    self._frame:Show()
    self._frame:SetScript("OnUpdate", OnUpdateCursor)
end

function Mouse:Disable()
    if not self._active then return end
    self._active = false

    if self._frame then
        self._frame:SetScript("OnUpdate", nil)
        self._frame:Hide()
    end
end

-- [ AUTO-ENABLE ON LOGIN ]--------------------------------------------------------------------------
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
