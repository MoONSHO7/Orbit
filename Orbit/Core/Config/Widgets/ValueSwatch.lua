local _, Orbit = ...
local Engine = Orbit.Engine
local Constants = Orbit.Constants
local Layout = Engine.Layout

-- [ VALUE-COLUMN CONTROLS ]--------------------------------------------------------------------------
-- Shared helpers for the value column of a 3-column widget row: ApplyValueColorSwatch (a color
-- swatch) and ApplyValueCheckbox (a toggle). Both right-align off Constants.Widget.ValueInset, so
-- every value-column control lines up regardless of which widget hosts it.

local WHITE8x8 = "Interface\\Buttons\\WHITE8x8"

local function ResolvePreviewColor(curveMode, value)
    if not value then return 1, 1, 1, 1 end
    if curveMode then
        local pins = value.pins
        if not pins or #pins == 0 then return 0.5, 0.5, 0.5, 1 end
        local first = pins[1]
        for i = 2, #pins do
            if pins[i].position < first.position then first = pins[i] end
        end
        local c = first.color or {}
        return c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end
    return value.r or 1, value.g or 1, value.b or 1, value.a or 1
end

-- cfg fields: curve (single color vs gradient), initialValue, enabled, callback(value), tooltip.
-- initialValue and enabled accept a value or a getter function; getters are resolved on every
-- (re)render so the swatch tracks current SavedVariables even when its schema was built earlier.
function Layout:ApplyValueColorSwatch(frame, cfg, anchorX)
    local enabled = cfg.enabled
    if type(enabled) == "function" then enabled = enabled() end
    if enabled == false then
        if frame.ValueColorSwatch then frame.ValueColorSwatch:Hide() end
        return
    end

    if not frame.ValueColorSwatch then
        local swatch = CreateFrame("Button", nil, frame, "BackdropTemplate")
        swatch:SetSize(Constants.Widget.ValueSwatchSize, Constants.Widget.ValueSwatchSize)
        swatch:SetBackdrop({ bgFile = WHITE8x8, edgeFile = WHITE8x8, edgeSize = 1 })
        swatch:SetBackdropBorderColor(0, 0, 0, 1)
        swatch.Color = swatch:CreateTexture(nil, "OVERLAY")
        swatch.Color:SetPoint("TOPLEFT", 1, -1)
        swatch.Color:SetPoint("BOTTOMRIGHT", -1, 1)
        swatch.Color:SetColorTexture(1, 1, 1, 1)
        frame.ValueColorSwatch = swatch
    end

    local C = Constants
    local swatch = frame.ValueColorSwatch
    swatch.curveMode = cfg.curve and true or false
    local initial = cfg.initialValue
    if type(initial) == "function" then initial = initial() end
    swatch.value = initial

    swatch:ClearAllPoints()
    -- value-column controls are right-aligned; a lone swatch flushes to the column's right edge
    local ax = anchorX or (C.Widget.ValueSwatchSize / 2 + C.Widget.ValueInset)
    swatch:SetPoint("CENTER", frame, "RIGHT", -Engine.Pixel:Snap(ax, frame:GetEffectiveScale()), 0)
    swatch.Color:SetVertexColor(ResolvePreviewColor(swatch.curveMode, swatch.value))

    swatch:SetScript("OnClick", function()
        local lib = LibStub and LibStub("LibOrbitColorPicker-1.0", true)
        if not lib then return end
        local as = Orbit.db and Orbit.db.AccountSettings
        if as and not as.RecentColors then as.RecentColors = {} end

        local initialData
        if swatch.curveMode then
            initialData = swatch.value
        else
            local v = swatch.value or {}
            initialData = { r = v.r or 1, g = v.g or 1, b = v.b or 1, a = v.a or 1 }
        end

        lib:Open({
            initialData = initialData,
            hasOpacity = true,
            forceSingleColor = not swatch.curveMode,
            recentColorsDb = as and as.RecentColors,
            onOpen = function(picker)
                if as and not as.ColorPickerTourComplete then
                    as.ColorPickerTourComplete = true
                    C_Timer.After(0.1, function() if picker:IsOpen() then picker:StartTour() end end)
                end
            end,
            callback = function(result, wasCancelled)
                if wasCancelled or not result then return end
                local newValue
                if swatch.curveMode then
                    if result.pins and #result.pins > 0 then
                        newValue = { pins = result.pins }
                        if result.desaturated ~= nil then newValue.desaturated = result.desaturated end
                    end
                else
                    local pin = result.pins and result.pins[1]
                    newValue = pin and pin.color
                end
                if not newValue then return end
                swatch.value = newValue
                swatch.Color:SetVertexColor(ResolvePreviewColor(swatch.curveMode, newValue))
                if cfg.callback then cfg.callback(newValue) end
            end,
        })
    end)

    if cfg.tooltip then
        swatch:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(cfg.tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", GameTooltip_Hide)
    else
        swatch:SetScript("OnEnter", nil)
        swatch:SetScript("OnLeave", nil)
    end

    swatch:Show()
    return swatch
end

-- [ VALUE-COLUMN CHECKBOX ]--------------------------------------------------------------------------
-- cfg fields: initialValue (value or getter), callback(checked), tooltip. tooltip is a string, or
-- a function(checked) -> title, subtext that re-resolves live as the box is toggled.
function Layout:ApplyValueCheckbox(frame, cfg, anchorX)
    if not frame.ValueCheckbox then
        frame.ValueCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        frame.ValueCheckbox:SetSize(Constants.Widget.ValueCheckboxSize, Constants.Widget.ValueCheckboxSize)
    end

    local C = Constants
    local vcb = frame.ValueCheckbox
    vcb:ClearAllPoints()
    local ax = anchorX or (C.Widget.ValueSwatchSize / 2 + C.Widget.ValueInset)
    vcb:SetPoint("CENTER", frame, "RIGHT", -Engine.Pixel:Snap(ax, frame:GetEffectiveScale()), 0)

    local initial = cfg.initialValue
    if type(initial) == "function" then initial = initial() end
    vcb:SetChecked(initial or false)

    -- A function tooltip re-resolves against the live checked state; rendering it from OnClick as
    -- well as OnEnter keeps the title/sub-line tracking the toggle while the cursor lingers.
    local function RenderTooltip(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local tt = cfg.tooltip
        if type(tt) == "function" then
            local title, subtext = tt(self:GetChecked())
            GameTooltip:SetText(title, 1, 1, 1, 1, true)
            if subtext then GameTooltip:AddLine(subtext, 0.6, 0.6, 0.6, true) end
        else
            GameTooltip:SetText(tt, 1, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end

    vcb:SetScript("OnClick", function(self)
        if cfg.callback then cfg.callback(self:GetChecked()) end
        if cfg.tooltip and GameTooltip:GetOwner() == self then RenderTooltip(self) end
    end)

    if cfg.tooltip then
        vcb:SetScript("OnEnter", RenderTooltip)
        vcb:SetScript("OnLeave", GameTooltip_Hide)
    else
        vcb:SetScript("OnEnter", nil)
        vcb:SetScript("OnLeave", nil)
    end

    vcb:Show()
    return vcb
end
