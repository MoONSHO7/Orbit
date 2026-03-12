-- [ CANVAS MODE - INFO SYSTEM ]-----------------------------------------------------
-- Sequential tour that cycles through help points with Next/Done
local _, addonTable = ...
local Orbit = addonTable
local OrbitEngine = Orbit.Engine
local CanvasMode = OrbitEngine.CanvasMode
local Dialog = CanvasMode.Dialog

-- [ CONSTANTS ]----------------------------------------------------------------------
local BUTTON_SIZE = 36
local PULSE_LEVEL = 512
local TOOLTIP_PAD = 8
local TOOLTIP_MAX_WIDTH = 220
local TOOLTIP_BORDER = 1
local NEXT_BTN_HEIGHT = 18
local NEXT_BTN_WIDTH = 60
local NEXT_BTN_GAP = 6
local ACCENT = { r = 0.3, g = 0.8, b = 0.3 }
local BG = { r = 0.08, g = 0.08, b = 0.08, a = 0.95 }
local BORDER_CLR = { r = 0.25, g = 0.25, b = 0.25, a = 0.9 }
local TEXT_CLR = { r = 0.85, g = 0.85, b = 0.85 }
local TITLE_CLR = { r = ACCENT.r, g = ACCENT.g, b = ACCENT.b }
local FONT = "GameFontNormalSmall"

-- [ LOCALIZATION ]-------------------------------------------------------------------
local LOCALE_STRINGS = {
    enUS = {
        TOUR_TOOLTIP = "Canvas Mode Tour",
        NEXT = "Next", DONE = "Done",
        DOCK_TITLE = "Component Dock",
        DOCK_TEXT = "Drag components here to disable them.\nClick a docked icon to re-enable it.",
        FILTER_TITLE = "Category Filters",
        FILTER_TEXT = "Filter which component types are visible.\nUse this to focus on text, icons, or auras.",
        COMP_TITLE = "Component Controls",
        COMP_TEXT = "Click and drag to reposition.\nHold Shift for 1px precision.\nArrow keys nudge 1px at a time.",
        VIEW_TITLE = "Viewport Navigation",
        VIEW_TEXT = "Scroll wheel to zoom in and out.\nClick and drag empty space to pan around.",
        OVER_TITLE = "Component Overrides",
        OVER_TEXT = "Click any component to open its settings.\nOverrides here take priority over your\nglobal settings for this component only.",
        RESIZE_TITLE = "Resize Window",
        RESIZE_TEXT = "Drag this handle to resize the canvas\nwindow for a larger or smaller workspace.",
    },
    deDE = {
        TOUR_TOOLTIP = "Canvas-Modus Tour",
        NEXT = "Weiter", DONE = "Fertig",
        DOCK_TITLE = "Komponentenablage",
        DOCK_TEXT = "Komponenten hierher ziehen zum Deaktivieren.\nAuf ein Symbol klicken zum Reaktivieren.",
        FILTER_TITLE = "Kategoriefilter",
        FILTER_TEXT = "Angezeigte Komponententypen filtern.\nText, Symbole oder Auren gezielt anzeigen.",
        COMP_TITLE = "Komponentensteuerung",
        COMP_TEXT = "Klicken und ziehen zum Verschieben.\nUmschalttaste für 1-Pixel-Präzision.\nPfeiltasten verschieben um 1 Pixel.",
        VIEW_TITLE = "Ansichtsnavigation",
        VIEW_TEXT = "Mausrad zum Zoomen.\nFreie Fläche klicken und ziehen zum Schwenken.",
        OVER_TITLE = "Komponentenüberschreibungen",
        OVER_TEXT = "Auf eine Komponente klicken für Einstellungen.\nÜberschreibungen haben Vorrang vor\nglobalen Einstellungen dieser Komponente.",
        RESIZE_TITLE = "Fenstergröße ändern",
        RESIZE_TEXT = "Diesen Griff ziehen, um das Fenster\nzu vergrößern oder zu verkleinern.",
    },
    frFR = {
        TOUR_TOOLTIP = "Visite du mode Canevas",
        NEXT = "Suivant", DONE = "Terminé",
        DOCK_TITLE = "Dock des composants",
        DOCK_TEXT = "Faites glisser les composants ici pour\nles désactiver. Cliquez pour réactiver.",
        FILTER_TITLE = "Filtres de catégorie",
        FILTER_TEXT = "Filtrez les types de composants affichés.\nConcentrez-vous sur le texte, les icônes ou les auras.",
        COMP_TITLE = "Contrôles des composants",
        COMP_TEXT = "Cliquez et faites glisser pour repositionner.\nMaintenez Maj pour une précision de 1px.\nLes flèches déplacent de 1px.",
        VIEW_TITLE = "Navigation de la vue",
        VIEW_TEXT = "Molette pour zoomer.\nCliquez et faites glisser l'espace vide pour naviguer.",
        OVER_TITLE = "Remplacements de composant",
        OVER_TEXT = "Cliquez sur un composant pour ses paramètres.\nLes remplacements ici ont priorité sur\nvos paramètres globaux pour ce composant.",
        RESIZE_TITLE = "Redimensionner la fenêtre",
        RESIZE_TEXT = "Faites glisser cette poignée pour\nredimensionner l'espace de travail.",
    },
    esES = {
        TOUR_TOOLTIP = "Tour del modo Lienzo",
        NEXT = "Siguiente", DONE = "Hecho",
        DOCK_TITLE = "Dock de componentes",
        DOCK_TEXT = "Arrastra componentes aquí para desactivarlos.\nHaz clic en un icono para reactivar.",
        FILTER_TITLE = "Filtros de categoría",
        FILTER_TEXT = "Filtra los tipos de componentes visibles.\nEnfócate en texto, iconos o auras.",
        COMP_TITLE = "Controles de componentes",
        COMP_TEXT = "Haz clic y arrastra para reposicionar.\nMantén Mayús para precisión de 1px.\nFlechas desplazan 1px.",
        VIEW_TITLE = "Navegación de vista",
        VIEW_TEXT = "Rueda del ratón para acercar y alejar.\nHaz clic y arrastra el espacio vacío para desplazar.",
        OVER_TITLE = "Ajustes de componente",
        OVER_TEXT = "Haz clic en un componente para su configuración.\nLos ajustes aquí tienen prioridad sobre\nla configuración global de este componente.",
        RESIZE_TITLE = "Redimensionar ventana",
        RESIZE_TEXT = "Arrastra esta esquina para cambiar\nel tamaño del espacio de trabajo.",
    },
    ptBR = {
        TOUR_TOOLTIP = "Tour do modo Canvas",
        NEXT = "Próximo", DONE = "Concluído",
        DOCK_TITLE = "Dock de componentes",
        DOCK_TEXT = "Arraste componentes aqui para desativar.\nClique num ícone para reativar.",
        FILTER_TITLE = "Filtros de categoria",
        FILTER_TEXT = "Filtre os tipos de componentes visíveis.\nConcentre-se em texto, ícones ou auras.",
        COMP_TITLE = "Controles de componentes",
        COMP_TEXT = "Clique e arraste para reposicionar.\nSegure Shift para precisão de 1px.\nSetas deslocam 1px.",
        VIEW_TITLE = "Navegação da vista",
        VIEW_TEXT = "Roda do mouse para zoom.\nClique e arraste o espaço vazio para mover.",
        OVER_TITLE = "Substituições de componente",
        OVER_TEXT = "Clique num componente para configurações.\nSubstituições aqui têm prioridade sobre\nsuas configurações globais deste componente.",
        RESIZE_TITLE = "Redimensionar janela",
        RESIZE_TEXT = "Arraste esta alça para redimensionar\na área de trabalho.",
    },
    ruRU = {
        TOUR_TOOLTIP = "Обзор режима холста",
        NEXT = "Далее", DONE = "Готово",
        DOCK_TITLE = "Панель компонентов",
        DOCK_TEXT = "Перетащите компоненты сюда, чтобы отключить.\nНажмите на значок, чтобы включить.",
        FILTER_TITLE = "Фильтры категорий",
        FILTER_TEXT = "Фильтруйте видимые типы компонентов.\nСосредоточьтесь на тексте, значках или аурах.",
        COMP_TITLE = "Управление компонентами",
        COMP_TEXT = "Нажмите и перетащите для перемещения.\nShift для точности в 1 пиксель.\nСтрелки сдвигают на 1 пиксель.",
        VIEW_TITLE = "Навигация по области",
        VIEW_TEXT = "Колёсико мыши для масштабирования.\nНажмите и перетащите пустое место для перемещения.",
        OVER_TITLE = "Переопределения компонента",
        OVER_TEXT = "Нажмите на компонент для настроек.\nПереопределения имеют приоритет над\nглобальными настройками этого компонента.",
        RESIZE_TITLE = "Изменить размер окна",
        RESIZE_TEXT = "Перетащите этот угол, чтобы изменить\nразмер рабочей области.",
    },
    koKR = {
        TOUR_TOOLTIP = "캔버스 모드 안내",
        NEXT = "다음", DONE = "완료",
        DOCK_TITLE = "구성요소 독",
        DOCK_TEXT = "구성요소를 여기로 끌어 비활성화합니다.\n아이콘을 클릭하면 다시 활성화됩니다.",
        FILTER_TITLE = "카테고리 필터",
        FILTER_TEXT = "표시되는 구성요소 유형을 필터링합니다.\n텍스트, 아이콘 또는 오라에 집중하세요.",
        COMP_TITLE = "구성요소 조작",
        COMP_TEXT = "클릭하고 드래그하여 위치를 변경합니다.\nShift를 누르면 1px 정밀 이동합니다.\n화살표 키로 1px씩 이동합니다.",
        VIEW_TITLE = "뷰포트 탐색",
        VIEW_TEXT = "마우스 휠로 확대/축소합니다.\n빈 공간을 클릭하고 드래그하여 이동합니다.",
        OVER_TITLE = "구성요소 재정의",
        OVER_TEXT = "구성요소를 클릭하면 설정이 열립니다.\n여기의 재정의는 이 구성요소의\n전역 설정보다 우선합니다.",
        RESIZE_TITLE = "창 크기 조절",
        RESIZE_TEXT = "이 핸들을 드래그하여 캔버스 창의\n크기를 조절합니다.",
    },
    zhCN = {
        TOUR_TOOLTIP = "画布模式导览",
        NEXT = "下一步", DONE = "完成",
        DOCK_TITLE = "组件停靠栏",
        DOCK_TEXT = "将组件拖到这里以禁用。\n点击图标重新启用。",
        FILTER_TITLE = "分类筛选",
        FILTER_TEXT = "筛选可见的组件类型。\n专注于文字、图标或光环。",
        COMP_TITLE = "组件控制",
        COMP_TEXT = "点击并拖动以重新定位。\n按住Shift进行1像素精确移动。\n方向键每次移动1像素。",
        VIEW_TITLE = "视口导航",
        VIEW_TEXT = "滚轮缩放。\n点击并拖动空白区域平移。",
        OVER_TITLE = "组件覆盖设置",
        OVER_TEXT = "点击组件打开其设置。\n此处的覆盖设置优先于\n该组件的全局设置。",
        RESIZE_TITLE = "调整窗口大小",
        RESIZE_TEXT = "拖动此手柄以调整\n画布窗口大小。",
    },
    zhTW = {
        TOUR_TOOLTIP = "畫布模式導覽",
        NEXT = "下一步", DONE = "完成",
        DOCK_TITLE = "元件停靠欄",
        DOCK_TEXT = "將元件拖到這裡以停用。\n點擊圖示重新啟用。",
        FILTER_TITLE = "分類篩選",
        FILTER_TEXT = "篩選可見的元件類型。\n專注於文字、圖示或光環。",
        COMP_TITLE = "元件控制",
        COMP_TEXT = "點擊並拖動以重新定位。\n按住Shift進行1像素精確移動。\n方向鍵每次移動1像素。",
        VIEW_TITLE = "視口導航",
        VIEW_TEXT = "滾輪縮放。\n點擊並拖動空白區域平移。",
        OVER_TITLE = "元件覆蓋設定",
        OVER_TEXT = "點擊元件開啟其設定。\n此處的覆蓋設定優先於\n該元件的全域設定。",
        RESIZE_TITLE = "調整視窗大小",
        RESIZE_TEXT = "拖動此控制點以調整\n畫布視窗大小。",
    },
}
LOCALE_STRINGS.enGB = LOCALE_STRINGS.enUS
LOCALE_STRINGS.esMX = LOCALE_STRINGS.esES
local L = LOCALE_STRINGS[GetLocale()] or LOCALE_STRINGS.enUS

-- CJK needs wider tooltips for multi-byte glyphs
local isCJK = ({ koKR = true, zhCN = true, zhTW = true })[GetLocale()]
if isCJK then TOOLTIP_MAX_WIDTH = 240 end

-- [ TOUR STOPS ]---------------------------------------------------------------------
local TOUR_STOPS = {
    { anchor = function() return Dialog.DisabledDock end,
      tooltipPoint = "BOTTOM", tooltipRel = "TOP", tpX = 0, tpY = 8,
      title = L.DOCK_TITLE, text = L.DOCK_TEXT },
    { anchor = function() return Dialog.FilterTabBar end,
      tooltipPoint = "TOP", tooltipRel = "BOTTOM", tpX = 0, tpY = -8,
      title = L.FILTER_TITLE, text = L.FILTER_TEXT },
    { anchor = function()
          if not Dialog.previewComponents then return nil end
          for _, comp in pairs(Dialog.previewComponents) do
              if comp:IsShown() then return comp end
          end
          return nil
      end,
      tooltipPoint = "TOPLEFT", tooltipRel = "TOPRIGHT", tpX = 8, tpY = 4,
      title = L.COMP_TITLE, text = L.COMP_TEXT,
      allAnchors = function()
          local list = {}
          if Dialog.previewComponents then
              for _, comp in pairs(Dialog.previewComponents) do
                  if comp:IsShown() then list[#list + 1] = comp end
              end
          end
          return list
      end },
    { anchor = function() return Dialog.Viewport end,
      tooltipPoint = "CENTER", tooltipRel = "CENTER", tpX = 0, tpY = 0,
      title = L.VIEW_TITLE, text = L.VIEW_TEXT },
    { anchor = function() return Dialog.OverrideContainer end,
      tooltipPoint = "BOTTOM", tooltipRel = "TOP", tpX = 0, tpY = 8,
      title = L.OVER_TITLE, text = L.OVER_TEXT,
      onEnter = function()
          Dialog._tourOpenedComp = nil
          if not Dialog.previewComponents then return end
          for key, comp in pairs(Dialog.previewComponents) do
              if comp:IsShown() and comp.key then
                  Dialog._tourOpenedComp = comp
                  OrbitEngine.CanvasComponentSettings:Open(comp.key, comp, Dialog.targetPlugin, Dialog.targetSystemIndex)
                  return
              end
          end
      end,
      onLeave = function()
          Dialog._tourOpenedComp = nil
          if OrbitEngine.CanvasComponentSettings and OrbitEngine.CanvasComponentSettings.componentKey then
              OrbitEngine.CanvasComponentSettings:Close()
          end
      end,
      allAnchors = function()
          local list = {}
          if Dialog.OverrideContainer and Dialog.OverrideContainer:IsShown() then
              list[#list + 1] = Dialog.OverrideContainer
          end
          if Dialog._tourOpenedComp and Dialog._tourOpenedComp:IsShown() then
              list[#list + 1] = Dialog._tourOpenedComp
          end
          return list
      end },
    { anchor = function() return Dialog.ResizeHandle end,
      tooltipPoint = "RIGHT", tooltipRel = "LEFT", tpX = -8, tpY = 0,
      title = L.RESIZE_TITLE, text = L.RESIZE_TEXT },
}

-- [ STATE ]--------------------------------------------------------------------------
Dialog.tourActive = false
Dialog.tourIndex = 0

-- [ CUSTOM TOOLTIP ]-----------------------------------------------------------------
local function MakeBorderEdge(parent, horiz, p1, r1, p2, r2)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(BORDER_CLR.r, BORDER_CLR.g, BORDER_CLR.b, BORDER_CLR.a)
    t:SetPoint(p1, parent, r1)
    t:SetPoint(p2, parent, r2)
    if horiz then t:SetHeight(TOOLTIP_BORDER) else t:SetWidth(TOOLTIP_BORDER) end
    return t
end

local tip = CreateFrame("Frame", nil, UIParent)
tip:SetFrameStrata("TOOLTIP")
tip:SetFrameLevel(999)
tip:Hide()

tip.bg = tip:CreateTexture(nil, "BACKGROUND")
tip.bg:SetAllPoints()
tip.bg:SetColorTexture(BG.r, BG.g, BG.b, BG.a)
MakeBorderEdge(tip, true, "TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT")
MakeBorderEdge(tip, true, "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT")
MakeBorderEdge(tip, false, "TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT")
MakeBorderEdge(tip, false, "TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT")

-- Directional accent bars (point toward the pulse highlight)
local ACCENT_WIDTH = 2
local B = TOOLTIP_BORDER
tip.accentBars = {}
tip.accentBars.top = tip:CreateTexture(nil, "ARTWORK")
tip.accentBars.top:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
tip.accentBars.top:SetHeight(ACCENT_WIDTH)
tip.accentBars.top:SetPoint("TOPLEFT", B, -B)
tip.accentBars.top:SetPoint("TOPRIGHT", -B, -B)
tip.accentBars.bottom = tip:CreateTexture(nil, "ARTWORK")
tip.accentBars.bottom:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
tip.accentBars.bottom:SetHeight(ACCENT_WIDTH)
tip.accentBars.bottom:SetPoint("BOTTOMLEFT", B, B)
tip.accentBars.bottom:SetPoint("BOTTOMRIGHT", -B, B)
tip.accentBars.left = tip:CreateTexture(nil, "ARTWORK")
tip.accentBars.left:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
tip.accentBars.left:SetWidth(ACCENT_WIDTH)
tip.accentBars.left:SetPoint("TOPLEFT", B, -B)
tip.accentBars.left:SetPoint("BOTTOMLEFT", B, B)
tip.accentBars.right = tip:CreateTexture(nil, "ARTWORK")
tip.accentBars.right:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
tip.accentBars.right:SetWidth(ACCENT_WIDTH)
tip.accentBars.right:SetPoint("TOPRIGHT", -B, -B)
tip.accentBars.right:SetPoint("BOTTOMRIGHT", -B, B)

-- Show accent bars pointing toward the highlight based on tooltipPoint
local function ApplyAccentDirection(tooltipPoint)
    for _, bar in pairs(tip.accentBars) do bar:Hide() end
    local pt = tooltipPoint:upper()
    -- CENTER = all sides
    if pt == "CENTER" then
        for _, bar in pairs(tip.accentBars) do bar:Show() end
        return
    end
    -- The tooltip's anchor point tells us which edge faces the highlight
    if pt:find("TOP") then tip.accentBars.top:Show() end
    if pt:find("BOTTOM") then tip.accentBars.bottom:Show() end
    if pt:find("LEFT") then tip.accentBars.left:Show() end
    if pt:find("RIGHT") then tip.accentBars.right:Show() end
end

-- Step counter (e.g. "1 / 3")
tip.counter = tip:CreateFontString(nil, "OVERLAY", FONT)
tip.counter:SetPoint("TOPLEFT", TOOLTIP_PAD + 4, -TOOLTIP_PAD)
tip.counter:SetTextColor(0.5, 0.5, 0.5)
tip.counter:SetJustifyH("LEFT")

tip.title = tip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tip.title:SetPoint("TOPLEFT", tip.counter, "BOTTOMLEFT", 0, -2)
tip.title:SetTextColor(TITLE_CLR.r, TITLE_CLR.g, TITLE_CLR.b)
tip.title:SetJustifyH("LEFT")
tip.title:SetWidth(TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2 - 4)

tip.text = tip:CreateFontString(nil, "OVERLAY", FONT)
tip.text:SetPoint("TOPLEFT", tip.title, "BOTTOMLEFT", 0, -3)
tip.text:SetTextColor(TEXT_CLR.r, TEXT_CLR.g, TEXT_CLR.b)
tip.text:SetJustifyH("LEFT")
tip.text:SetWidth(TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2 - 4)
tip.text:SetSpacing(2)

-- Next / Done button
tip.nextBtn = CreateFrame("Button", nil, tip, "UIPanelButtonTemplate")
tip.nextBtn:SetSize(NEXT_BTN_WIDTH, NEXT_BTN_HEIGHT)
tip.nextBtn:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -TOOLTIP_PAD, TOOLTIP_PAD)
tip.nextBtn:SetScript("OnClick", function()
    if Dialog.tourIndex < #TOUR_STOPS then
        Dialog:ShowTourStop(Dialog.tourIndex + 1)
    else
        Dialog:EndTour()
    end
end)

-- Pulse overlay pool (green glow covering anchors)
local pulsePool = {}
local activePulses = {}

local function CreatePulse()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(PULSE_LEVEL)
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    f.tex:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.3)
    f.ag = f:CreateAnimationGroup()
    f.ag:SetLooping("BOUNCE")
    local a = f.ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.2)
    a:SetDuration(0.6)
    a:SetSmoothing("IN_OUT")
    f:Hide()
    return f
end

local function AcquirePulse()
    local p = table.remove(pulsePool) or CreatePulse()
    activePulses[#activePulses + 1] = p
    return p
end

local function ReleaseAllPulses()
    for i = #activePulses, 1, -1 do
        local p = activePulses[i]
        p.ag:Stop()
        p:Hide()
        pulsePool[#pulsePool + 1] = p
        activePulses[i] = nil
    end
end

local function ShowPulseOn(anchor)
    local p = AcquirePulse()
    p:ClearAllPoints()
    p:SetAllPoints(anchor)
    p:SetParent(anchor:GetParent() or UIParent)
    p:SetFrameLevel(anchor:GetFrameLevel() + 5)
    p:Show()
    p.ag:Play()
end

local function LayoutTooltip(anchor, stop, idx, total)
    tip.counter:SetText(idx .. " / " .. total)
    tip.title:SetText(stop.title)
    tip.text:SetText(stop.text)
    local isLast = idx == total
    tip.nextBtn:SetText(isLast and L.DONE or L.NEXT)
    -- Size to fit
    local textH = tip.counter:GetStringHeight() + 2 + tip.title:GetStringHeight() + 3 + tip.text:GetStringHeight()
    local h = textH + TOOLTIP_PAD * 2 + NEXT_BTN_GAP + NEXT_BTN_HEIGHT + TOOLTIP_PAD
    tip:SetSize(TOOLTIP_MAX_WIDTH, h)
    tip:ClearAllPoints()
    tip:SetPoint(stop.tooltipPoint, anchor, stop.tooltipRel, stop.tpX, stop.tpY)
    ApplyAccentDirection(stop.tooltipPoint)
    tip:Show()
    -- Pulse all anchors
    ReleaseAllPulses()
    if stop.allAnchors then
        for _, a in ipairs(stop.allAnchors()) do ShowPulseOn(a) end
    else
        ShowPulseOn(anchor)
    end
end

-- [ TOUR CONTROL ]-------------------------------------------------------------------
function Dialog:ShowTourStop(idx)
    -- Clean up previous stop
    if self.tourIndex > 0 then
        local prevStop = TOUR_STOPS[self.tourIndex]
        if prevStop and prevStop.onLeave then prevStop.onLeave() end
    end
    local stop = TOUR_STOPS[idx]
    if not stop then self:EndTour(); return end
    -- Run onEnter before anchoring (may create/show the anchor)
    if stop.onEnter then stop.onEnter() end
    local anchor = stop.anchor()
    if not anchor or not anchor:IsShown() then
        -- Skip stops with missing anchors
        if idx < #TOUR_STOPS then self:ShowTourStop(idx + 1) else self:EndTour() end
        return
    end
    self.tourIndex = idx
    LayoutTooltip(anchor, stop, idx, #TOUR_STOPS)
end

function Dialog:StartTour()
    self.tourActive = true
    self.tourIndex = 0
    self:ShowTourStop(1)
end

function Dialog:EndTour()
    if self.tourIndex > 0 then
        local prevStop = TOUR_STOPS[self.tourIndex]
        if prevStop and prevStop.onLeave then prevStop.onLeave() end
    end
    self.tourActive = false
    self.tourIndex = 0
    tip:Hide()
    ReleaseAllPulses()
end

function Dialog:HideInfoMarkers()
    self:EndTour()
end

function Dialog:ToggleInfoMode()
    if not self.tourActive then
        self:StartTour()
    elseif self.tourIndex < #TOUR_STOPS then
        self:ShowTourStop(self.tourIndex + 1)
    else
        self:EndTour()
    end
end

-- [ INFO BUTTON (in dialog header, hard left) ]---------------------------------------
local btn = CreateFrame("Button", nil, Dialog.TitleContainer)
btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
btn:SetPoint("LEFT", Dialog.TitleContainer, "LEFT", -6, 0)
btn:SetFrameLevel(Dialog.TitleContainer:GetFrameLevel() + 1)
btn.Icon = btn:CreateTexture(nil, "ARTWORK")
btn.Icon:SetTexture("Interface\\common\\help-i")
btn.Icon:SetSize(BUTTON_SIZE, BUTTON_SIZE)
btn.Icon:SetPoint("CENTER")
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.TOUR_TOOLTIP, 1, 1, 1)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
btn:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    Dialog:ToggleInfoMode()
end)
Dialog.InfoButton = btn
