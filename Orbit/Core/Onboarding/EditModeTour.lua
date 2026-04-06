-- [ EDIT MODE - GUIDED TOUR (PLAYGROUND) ]-------------------------------------------
---@type Orbit
local Orbit = Orbit
local Engine = Orbit.Engine

-- [ CONSTANTS ]----------------------------------------------------------------------
local OVERLAY_ALPHA = 0.98
local OVERLAY_STRATA = "MEDIUM"
local OVERLAY_LEVEL = 900
local FRAME_STRATA = "HIGH"
local FRAME_LEVEL = 500
local FRAME_W = 150
local FRAME_H = 50
local FRAME_OFFSET_X = 150
local TOOLTIP_PAD = 10
local TOOLTIP_MAX_WIDTH = 260
local TOOLTIP_BORDER = 1
local NEXT_BTN_HEIGHT = 20
local NEXT_BTN_WIDTH = 70
local NEXT_BTN_GAP = 6
local FADE_DURATION = 0.3
local NEXT_ENABLE_TIMER = 10
local STAR_COUNT = 150
local STAR_SIZE = 2
local STAR_SPEED_MIN = 0.10
local STAR_SPEED_MAX = 0.40
local STAR_HOLD_MIN = 2.0
local STAR_HOLD_MAX = 7.0
local STAR_ALPHA_MIN = 0.08
local STAR_ALPHA_MAX = 0.60
local DIALOG_STRATA = "DIALOG"
local DIALOG_LEVEL = 100
local BLOCKER_FRAME_LEVEL = 990
local ACCENT = { r = 0.3, g = 0.8, b = 0.3 }
local BG = { r = 0.08, g = 0.08, b = 0.08, a = 0.95 }
local BORDER_CLR = { r = 0.25, g = 0.25, b = 0.25, a = 0.9 }
local TEXT_CLR = { r = 0.85, g = 0.85, b = 0.85 }
local TITLE_CLR = ACCENT
local ACCENT_WIDTH = 2
local TOOLTIP_LEVEL = 999
local FONT = "GameFontNormalSmall"

-- [ LOCALIZATION ]-------------------------------------------------------------------
local LOCALE_STRINGS = {
    enUS = {
        NEXT = "Next", DONE = "Done",
        STEP1_TITLE = "Your Frames",
        STEP1_TEXT = "These are two Orbit frames.\nClick one to select it, then drag\nto reposition.",
        STEP2_TITLE = "Frame Settings",
        STEP2_TEXT = "A settings dialog opened!\nTry adjusting the width and height\nof the selected frame.",
        STEP3_TITLE = "Anchoring",
        STEP3_TEXT = "Drag the frames together around\nthe edges. Colored guidelines will\nappear showing where the frame\nwill anchor. The anchor direction\ncontrols how frames grow and\nresize together. Drop to anchor,\nor hold Shift for a precision\ndrop without anchoring.",
        STEP4_TITLE = "Parent & Child",
        STEP4_TEXT = "When frames are anchored, one\nbecomes the parent and the other\nthe child. Drag the parent - the\nchild follows! Dragging the child\nwill break the anchor.",
        STEP5_TITLE = "Adjust Distance",
        STEP5_TEXT = "Select the child frame, then scroll\nthe mouse wheel to change the gap\nbetween it and its parent.\nHold Shift for larger steps.\n\n|cFF66BB66Hint:|r Set Distance to 0 with\nSpacing at 0 and borders will merge\ninto a single shared edge!",
        STEP6_TITLE = "Arrow Nudge",
        STEP6_TEXT = "Select the parent frame and use\narrow keys to nudge it 1 pixel\nat a time. Both frames move\ntogether. Shift for 10px jumps.",
        STEP7_TITLE = "Drag Resize",
        STEP7_TEXT = "Grab the resize handle in the\nbottom-right corner of a selected\nframe. Drag to resize it within\nthe min/max bounds.\n\n|cFF66BB66Hint:|r Resize is based off your\nanchor position!",
        STEP8_TITLE = "Orbit Options",
        STEP8_TEXT = "This is the Orbit Options panel.\nChange your font, textures, colors,\nborders and more. All changes\napply globally across every frame.",
        STEP9_TITLE = "Explore!",
        STEP9_TEXT = "To get the most out of Orbit,\njust play around! Drag, drop,\nanchor and resize frames in\nEdit Mode. Every frame is yours\nto customize.",
        CANVAS_TITLE = "Canvas Mode",
        CANVAS_TEXT = "Right-click any frame to open\nCanvas Mode. This unlocks deeper\ncustomization per frame.",
    },
    deDE = {
        NEXT = "Weiter", DONE = "Fertig",
        STEP1_TITLE = "Deine Frames",
        STEP1_TEXT = "Das sind zwei Orbit-Frames.\nKlicke einen an, um ihn auszuwählen,\ndann ziehe ihn, um ihn zu verschieben.",
        STEP2_TITLE = "Frame-Einstellungen",
        STEP2_TEXT = "Ein Einstellungsdialog hat sich geöffnet!\nPasse die Breite und Höhe\ndes ausgewählten Frames an.",
        STEP3_TITLE = "Verankerung",
        STEP3_TEXT = "Ziehe die Frames an den\nRändern zusammen. Farbige Hilfslinien\nzeigen, wo der Frame verankert wird.\nDie Verankerungsrichtung bestimmt,\nwie Frames zusammen wachsen\nund sich vergrößern. Loslassen\nzum Verankern, Umschalttaste\nfür Präzision ohne Verankerung.",
        STEP4_TITLE = "Eltern & Kind",
        STEP4_TEXT = "Verankerte Frames bilden eine\nEltern-Kind-Beziehung. Ziehe den\nEltern-Frame – das Kind folgt!\nDas Kind zu ziehen löst die Verankerung.",
        STEP5_TITLE = "Abstand anpassen",
        STEP5_TEXT = "Wähle den Kind-Frame, dann scrolle\nmit dem Mausrad, um den Abstand\nzum Eltern-Frame zu ändern.\nUmschalttaste für größere Schritte.\n\n|cFF66BB66Tipp:|r Abstand 0 und\nAbstand 0 verschmelzen Ränder\nzu einer gemeinsamen Kante!",
        STEP6_TITLE = "Pfeilverschiebung",
        STEP6_TEXT = "Wähle den Eltern-Frame und nutze\ndie Pfeiltasten, um ihn pixelweise\nzu verschieben. Beide Frames bewegen\nsich zusammen. Umschalttaste für 10px.",
        STEP7_TITLE = "Größenänderung",
        STEP7_TEXT = "Greife den Griff unten rechts\nam ausgewählten Frame.\nZiehe ihn, um die Größe innerhalb\nder min/max Grenzen zu ändern.\n\n|cFF66BB66Tipp:|r Die Größenänderung\nbasiert auf der Verankerungsposition!",
        STEP8_TITLE = "Orbit-Optionen",
        STEP8_TEXT = "Das ist das Orbit-Optionsfenster.\nÄndere Schrift, Texturen, Farben,\nRahmen und mehr. Alle Änderungen\ngelten global für jeden Frame.",
        STEP9_TITLE = "Erkunden!",
        STEP9_TEXT = "Um Orbit optimal zu nutzen,\nprobiere einfach herum! Ziehe,\nverankere und ändere die Größe\nvon Frames im Bearbeitungsmodus.\nJeder Frame gehört dir.",
        CANVAS_TITLE = "Canvas-Modus",
        CANVAS_TEXT = "Rechtsklick auf einen Frame öffnet\nden Canvas-Modus. Dort lassen sich\nKomponenten detailliert anpassen.",
    },
    frFR = {
        NEXT = "Suivant", DONE = "Terminé",
        STEP1_TITLE = "Vos cadres",
        STEP1_TEXT = "Voici deux cadres Orbit.\nCliquez pour sélectionner, puis\nfaites glisser pour repositionner.",
        STEP2_TITLE = "Paramètres du cadre",
        STEP2_TEXT = "Un dialogue de paramètres s'est ouvert !\nEssayez d'ajuster la largeur et la\nhauteur du cadre sélectionné.",
        STEP3_TITLE = "Ancrage",
        STEP3_TEXT = "Rapprochez les cadres par les bords.\nDes guides colorés apparaissent pour\nmontrer l'ancrage. La direction d'ancrage\ncontrôle la croissance des cadres.\nRelâchez pour ancrer, ou maintenez\nMaj pour une pose de précision\nsans ancrage.",
        STEP4_TITLE = "Parent & Enfant",
        STEP4_TEXT = "Quand les cadres sont ancrés, l'un\ndevient le parent et l'autre l'enfant.\nDéplacez le parent – l'enfant suit !\nDéplacer l'enfant rompt l'ancrage.",
        STEP5_TITLE = "Ajuster la distance",
        STEP5_TEXT = "Sélectionnez le cadre enfant, puis\nutilisez la molette pour changer\nl'écart avec le parent.\nMaj pour de plus grands pas.\n\n|cFF66BB66Astuce :|r Distance à 0 avec\nespacement à 0 fusionne les bordures\nen un bord partagé !",
        STEP6_TITLE = "Touches directionnelles",
        STEP6_TEXT = "Sélectionnez le cadre parent et\nutilisez les flèches pour le déplacer\nde 1 pixel. Les deux cadres bougent\nensemble. Maj pour 10px.",
        STEP7_TITLE = "Redimensionner",
        STEP7_TEXT = "Saisissez la poignée en bas à\ndroite du cadre sélectionné.\nFaites glisser pour redimensionner\ndans les limites min/max.\n\n|cFF66BB66Astuce :|r Le redimensionnement\ndépend de la position d'ancrage !",
        STEP8_TITLE = "Options d'Orbit",
        STEP8_TEXT = "Voici le panneau d'options d'Orbit.\nModifiez la police, les textures, les\ncouleurs, les bordures et plus.\nTout s'applique globalement.",
        STEP9_TITLE = "Explorez !",
        STEP9_TEXT = "Pour profiter pleinement d'Orbit,\nexpérimentez ! Glissez, déposez,\nancrez et redimensionnez les cadres\nen mode Édition. Chaque cadre\nest personnalisable.",
        CANVAS_TITLE = "Mode Canevas",
        CANVAS_TEXT = "Clic droit sur un cadre pour ouvrir\nle mode Canevas. Personnalisation\nplus approfondie par cadre.",
    },
    esES = {
        NEXT = "Siguiente", DONE = "Hecho",
        STEP1_TITLE = "Tus marcos",
        STEP1_TEXT = "Estos son dos marcos de Orbit.\nHaz clic en uno para seleccionarlo\ny arrástralo para reposicionarlo.",
        STEP2_TITLE = "Ajustes del marco",
        STEP2_TEXT = "¡Se abrió un diálogo de ajustes!\nPrueba a ajustar el ancho y alto\ndel marco seleccionado.",
        STEP3_TITLE = "Anclaje",
        STEP3_TEXT = "Arrastra los marcos juntos por\nlos bordes. Aparecerán guías de\ncolor mostrando dónde se anclará.\nLa dirección de anclaje controla\ncómo crecen los marcos. Suelta\npara anclar o mantén Mayús para\nuna colocación precisa sin anclaje.",
        STEP4_TITLE = "Padre e Hijo",
        STEP4_TEXT = "Cuando los marcos están anclados,\nuno es el padre y el otro el hijo.\n¡Arrastra el padre y el hijo lo sigue!\nArrastrar el hijo rompe el anclaje.",
        STEP5_TITLE = "Ajustar distancia",
        STEP5_TEXT = "Selecciona el marco hijo, luego usa\nla rueda del ratón para cambiar\nla separación con el padre.\nMayús para pasos más grandes.\n\n|cFF66BB66Pista:|r Distancia 0 con\nespaciado 0 fusiona los bordes\nen un solo borde compartido.",
        STEP6_TITLE = "Desplazar con flechas",
        STEP6_TEXT = "Selecciona el marco padre y\nusa las flechas para moverlo\n1 píxel. Ambos marcos se mueven\njuntos. Mayús para 10px.",
        STEP7_TITLE = "Redimensionar",
        STEP7_TEXT = "Agarra el tirador en la esquina\ninferior derecha del marco\nseleccionado. Arrastra para\nredimensionar dentro de los\nlímites min/max.\n\n|cFF66BB66Pista:|r ¡El redimensionado\ndepende de la posición de anclaje!",
        STEP8_TITLE = "Opciones de Orbit",
        STEP8_TEXT = "Este es el panel de opciones de Orbit.\nCambia fuente, texturas, colores,\nbordes y más. Todos los cambios\nse aplican globalmente.",
        STEP9_TITLE = "¡Explora!",
        STEP9_TEXT = "Para sacar el máximo de Orbit,\n¡experimenta! Arrastra, suelta,\nancla y redimensiona marcos en\nel Modo de Edición. Cada marco\nes personalizable.",
        CANVAS_TITLE = "Modo Lienzo",
        CANVAS_TEXT = "Clic derecho en cualquier marco\npara abrir el Modo Lienzo.\nPersonalización más profunda por marco.",
    },
    ptBR = {
        NEXT = "Próximo", DONE = "Concluído",
        STEP1_TITLE = "Seus Quadros",
        STEP1_TEXT = "Estes são dois quadros do Orbit.\nClique para selecionar e arraste\npara reposicionar.",
        STEP2_TITLE = "Configurações do Quadro",
        STEP2_TEXT = "Um diálogo de configurações abriu!\nTente ajustar a largura e a altura\ndo quadro selecionado.",
        STEP3_TITLE = "Ancoragem",
        STEP3_TEXT = "Arraste os quadros pelas bordas.\nGuias coloridos aparecerão mostrando\nonde o quadro será ancorado.\nA direção da ancoragem controla\ncomo os quadros crescem juntos.\nSolte para ancorar ou segure Shift\npara posicionamento preciso\nsem ancoragem.",
        STEP4_TITLE = "Pai & Filho",
        STEP4_TEXT = "Quando os quadros estão ancorados,\num é o pai e o outro o filho.\nArraste o pai – o filho segue!\nArrastar o filho rompe a ancoragem.",
        STEP5_TITLE = "Ajustar Distância",
        STEP5_TEXT = "Selecione o quadro filho, depois\nuse a roda do mouse para mudar\no espaço entre ele e o pai.\nShift para passos maiores.\n\n|cFF66BB66Dica:|r Distância 0 com\nespaçamento 0 funde as bordas\nem uma única borda compartilhada!",
        STEP6_TITLE = "Mover com Setas",
        STEP6_TEXT = "Selecione o quadro pai e use as\nsetas para movê-lo 1 pixel por\nvez. Ambos os quadros se movem\njuntos. Shift para 10px.",
        STEP7_TITLE = "Redimensionar",
        STEP7_TEXT = "Pegue a alça no canto inferior\ndireito do quadro selecionado.\nArraste para redimensionar\ndentro dos limites min/max.\n\n|cFF66BB66Dica:|r O redimensionamento\ndepende da posição de ancoragem!",
        STEP8_TITLE = "Opções do Orbit",
        STEP8_TEXT = "Este é o painel de opções do Orbit.\nAltere fonte, texturas, cores,\nbordas e mais. Todas as alterações\nse aplicam globalmente.",
        STEP9_TITLE = "Explore!",
        STEP9_TEXT = "Para aproveitar o máximo do Orbit,\nexperimente! Arraste, solte, ancore\ne redimensione quadros no Modo\nde Edição. Cada quadro é seu\npara personalizar.",
        CANVAS_TITLE = "Modo Canvas",
        CANVAS_TEXT = "Clique direito em qualquer quadro\npara abrir o Modo Canvas.\nPersonalização mais profunda por quadro.",
    },
    ruRU = {
        NEXT = "Далее", DONE = "Готово",
        STEP1_TITLE = "Ваши фреймы",
        STEP1_TEXT = "Это два фрейма Orbit.\nНажмите на один, чтобы выбрать,\nзатем перетащите для перемещения.",
        STEP2_TITLE = "Настройки фрейма",
        STEP2_TEXT = "Открылось окно настроек!\nПопробуйте изменить ширину и высоту\nвыбранного фрейма.",
        STEP3_TITLE = "Привязка",
        STEP3_TEXT = "Перетащите фреймы к краям друг\nдруга. Цветные направляющие покажут,\nгде фрейм будет привязан.\nНаправление привязки определяет,\nкак фреймы растут вместе.\nОтпустите для привязки или\nудерживайте Shift для точного\nразмещения без привязки.",
        STEP4_TITLE = "Родитель и потомок",
        STEP4_TEXT = "При привязке один фрейм становится\nродителем, другой — потомком.\nПеретащите родителя — потомок\nследует! Перетаскивание потомка\nразрывает привязку.",
        STEP5_TITLE = "Изменить расстояние",
        STEP5_TEXT = "Выберите дочерний фрейм, затем\nпрокрутите колёсико мыши для\nизменения расстояния до родителя.\nShift для больших шагов.\n\n|cFF66BB66Подсказка:|r Расстояние 0 при\nотступе 0 объединяет границы\nв одну общую грань!",
        STEP6_TITLE = "Сдвиг стрелками",
        STEP6_TEXT = "Выберите родительский фрейм\nи стрелками сдвигайте на 1 пиксель.\nОба фрейма двигаются вместе.\nShift для 10px.",
        STEP7_TITLE = "Изменение размера",
        STEP7_TEXT = "Возьмите ручку в правом нижнем\nуглу выбранного фрейма.\nПеретащите для изменения размера\nв пределах мин/макс.\n\n|cFF66BB66Подсказка:|r Размер зависит\nот позиции привязки!",
        STEP8_TITLE = "Настройки Orbit",
        STEP8_TEXT = "Это панель настроек Orbit.\nИзмените шрифт, текстуры, цвета,\nрамки и многое другое. Все изменения\nприменяются глобально.",
        STEP9_TITLE = "Исследуйте!",
        STEP9_TEXT = "Чтобы получить максимум от Orbit,\nпросто экспериментируйте! Тащите,\nбросайте, привязывайте и изменяйте\nразмер фреймов в режиме редактирования.",
        CANVAS_TITLE = "Режим холста",
        CANVAS_TEXT = "Правый клик по фрейму откроет\nрежим холста. Глубокая настройка\nкаждого фрейма.",
    },
    koKR = {
        NEXT = "다음", DONE = "완료",
        STEP1_TITLE = "프레임 소개",
        STEP1_TEXT = "Orbit 프레임 두 개입니다.\n하나를 클릭하여 선택한 후\n드래그하여 위치를 변경하세요.",
        STEP2_TITLE = "프레임 설정",
        STEP2_TEXT = "설정 대화 상자가 열렸습니다!\n선택한 프레임의 너비와 높이를\n조정해 보세요.",
        STEP3_TITLE = "앵커링",
        STEP3_TEXT = "프레임을 가장자리 근처로\n드래그하세요. 색상 가이드가\n앵커 위치를 표시합니다.\n앵커 방향은 프레임의 성장\n방향을 결정합니다. 놓으면\n앵커, Shift를 누르면 앵커 없이\n정밀 배치됩니다.",
        STEP4_TITLE = "부모 & 자식",
        STEP4_TEXT = "프레임이 앵커되면 하나가 부모,\n다른 하나가 자식이 됩니다.\n부모를 드래그하면 자식이 따라옵니다!\n자식을 드래그하면 앵커가 해제됩니다.",
        STEP5_TITLE = "거리 조정",
        STEP5_TEXT = "자식 프레임을 선택한 후 마우스\n휠을 스크롤하여 부모와의 간격을\n변경합니다. Shift로 큰 단위 이동.\n\n|cFF66BB66힌트:|r 거리 0과 간격 0이면\n테두리가 하나의 공유 가장자리로\n병합됩니다!",
        STEP6_TITLE = "화살표 이동",
        STEP6_TEXT = "부모 프레임을 선택하고 화살표\n키로 1픽셀씩 이동합니다.\n두 프레임이 함께 움직입니다.\nShift로 10px 이동.",
        STEP7_TITLE = "드래그 크기 조절",
        STEP7_TEXT = "선택한 프레임의 오른쪽 하단\n핸들을 잡으세요. 드래그하여\n최소/최대 범위 내에서 크기를\n조절합니다.\n\n|cFF66BB66힌트:|r 크기 조절은 앵커\n위치에 기반합니다!",
        STEP8_TITLE = "Orbit 옵션",
        STEP8_TEXT = "Orbit 옵션 패널입니다.\n글꼴, 텍스처, 색상, 테두리 등을\n변경할 수 있습니다. 모든 변경사항이\n전역으로 적용됩니다.",
        STEP9_TITLE = "탐험하세요!",
        STEP9_TEXT = "Orbit을 최대한 활용하려면\n자유롭게 플레이하세요! 편집\n모드에서 프레임을 드래그,\n앵커, 크기 조절할 수 있습니다.",
        CANVAS_TITLE = "캔버스 모드",
        CANVAS_TEXT = "프레임을 우클릭하면 캔버스\n모드가 열립니다. 프레임별 세부\n사용자 설정을 할 수 있습니다.",
    },
    zhCN = {
        NEXT = "下一步", DONE = "完成",
        STEP1_TITLE = "您的框体",
        STEP1_TEXT = "这是两个 Orbit 框体。\n点击选择一个，然后拖动\n来重新定位。",
        STEP2_TITLE = "框体设置",
        STEP2_TEXT = "设置对话框已打开！\n尝试调整所选框体的\n宽度和高度。",
        STEP3_TITLE = "锚定",
        STEP3_TEXT = "将框体拖向彼此的边缘。\n彩色引导线将显示锚定位置。\n锚定方向控制框体如何共同\n增长和调整大小。松开以锚定，\n或按住 Shift 精确放置\n而不锚定。",
        STEP4_TITLE = "父级与子级",
        STEP4_TEXT = "框体锚定后，一个成为父级，\n另一个成为子级。拖动父级 ——\n子级跟随！拖动子级将\n断开锚定。",
        STEP5_TITLE = "调整距离",
        STEP5_TEXT = "选择子框体，然后滚动鼠标\n滚轮来改变与父级的间距。\n按住 Shift 以更大步进。\n\n|cFF66BB66提示:|r 距离为 0 且\n间距为 0 时，边框将合并\n为单一共享边缘！",
        STEP6_TITLE = "方向键微调",
        STEP6_TEXT = "选择父框体，使用方向键\n每次移动 1 像素。两个框体\n一起移动。Shift 跳 10 像素。",
        STEP7_TITLE = "拖动调整大小",
        STEP7_TEXT = "抓住所选框体右下角的\n调整手柄。拖动以在\n最小/最大范围内调整大小。\n\n|cFF66BB66提示:|r 大小调整基于\n锚定位置！",
        STEP8_TITLE = "Orbit 选项",
        STEP8_TEXT = "这是 Orbit 选项面板。\n更改字体、纹理、颜色、\n边框等。所有更改将全局\n应用于每个框体。",
        STEP9_TITLE = "探索！",
        STEP9_TEXT = "要充分利用 Orbit，\n尽情尝试！在编辑模式中\n拖动、放置、锚定和调整\n框体大小。每个框体都可\n自定义。",
        CANVAS_TITLE = "画布模式",
        CANVAS_TEXT = "右键点击任何框体以打开\n画布模式。为每个框体解锁\n更深层的自定义。",
    },
    zhTW = {
        NEXT = "下一步", DONE = "完成",
        STEP1_TITLE = "您的框架",
        STEP1_TEXT = "這是兩個 Orbit 框架。\n點擊選擇一個，然後拖動\n來重新定位。",
        STEP2_TITLE = "框架設定",
        STEP2_TEXT = "設定對話框已開啟！\n嘗試調整所選框架的\n寬度和高度。",
        STEP3_TITLE = "錨定",
        STEP3_TEXT = "將框架拖向彼此的邊緣。\n彩色引導線將顯示錨定位置。\n錨定方向控制框架如何共同\n增長和調整大小。放開以錨定，\n或按住 Shift 精確放置\n而不錨定。",
        STEP4_TITLE = "父級與子級",
        STEP4_TEXT = "框架錨定後，一個成為父級，\n另一個成為子級。拖動父級 ——\n子級跟隨！拖動子級將\n斷開錨定。",
        STEP5_TITLE = "調整距離",
        STEP5_TEXT = "選擇子框架，然後捲動滑鼠\n滾輪來改變與父級的間距。\n按住 Shift 以更大步進。\n\n|cFF66BB66提示:|r 距離為 0 且\n間距為 0 時，邊框將合併\n為單一共享邊緣！",
        STEP6_TITLE = "方向鍵微調",
        STEP6_TEXT = "選擇父框架，使用方向鍵\n每次移動 1 像素。兩個框架\n一起移動。Shift 跳 10 像素。",
        STEP7_TITLE = "拖動調整大小",
        STEP7_TEXT = "抓住所選框架右下角的\n調整控制點。拖動以在\n最小/最大範圍內調整大小。\n\n|cFF66BB66提示:|r 大小調整基於\n錨定位置！",
        STEP8_TITLE = "Orbit 選項",
        STEP8_TEXT = "這是 Orbit 選項面板。\n變更字型、紋理、顏色、\n邊框等。所有變更將全域\n套用於每個框架。",
        STEP9_TITLE = "探索！",
        STEP9_TEXT = "要充分利用 Orbit，\n盡情嘗試！在編輯模式中\n拖動、放置、錨定和調整\n框架大小。每個框架都可\n自訂。",
        CANVAS_TITLE = "畫布模式",
        CANVAS_TEXT = "右鍵點擊任何框架以開啟\n畫布模式。為每個框架解鎖\n更深層的自訂。",
    },
}
LOCALE_STRINGS.enGB = LOCALE_STRINGS.enUS
LOCALE_STRINGS.esMX = LOCALE_STRINGS.esES
local L = LOCALE_STRINGS[GetLocale()] or LOCALE_STRINGS.enUS

local isCJK = ({ koKR = true, zhCN = true, zhTW = true })[GetLocale()]
if isCJK then TOOLTIP_MAX_WIDTH = 280 end

-- [ MODULE ]-------------------------------------------------------------------------
Engine.EditModeTour = Engine.EditModeTour or {}
local Tour = Engine.EditModeTour
Tour.active = false
Tour.index = 0

-- [ PLUGIN REFERENCE ]---------------------------------------------------------------
local function GetPlugin() return Orbit:GetPlugin("Orbit_Tour") end
local function GetFrameA() local p = GetPlugin(); return p and p.frameA end
local function GetFrameB() local p = GetPlugin(); return p and p.frameB end

-- [ DARK OVERLAY ]-------------------------------------------------------------------
local overlay = CreateFrame("Frame", "OrbitEditModeTourOverlay", UIParent)
overlay:SetFrameStrata(OVERLAY_STRATA)
overlay:SetFrameLevel(OVERLAY_LEVEL)
overlay:SetAllPoints(UIParent)
overlay:EnableMouse(true)
overlay:Hide()

overlay.bg = overlay:CreateTexture(nil, "BACKGROUND")
overlay.bg:SetAllPoints()
overlay.bg:SetColorTexture(0, 0, 0, OVERLAY_ALPHA)

-- [ STAR FIELD ]----------------------------------------------------------------------
local stars = {}
local function BuildStars()
    if #stars > 0 then return end
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    for i = 1, STAR_COUNT do
        local tex = overlay:CreateTexture(nil, "ARTWORK")
        tex:SetSize(STAR_SIZE, STAR_SIZE)
        tex:SetColorTexture(1, 1, 1, 1)
        tex:SetPoint("TOPLEFT", overlay, "TOPLEFT", math.random(0, math.floor(sw)), -math.random(0, math.floor(sh)))
        tex:SetAlpha(0)
        tex:Hide()
        stars[i] = {
            tex = tex,
            alpha = 0,
            maxAlpha = STAR_ALPHA_MIN + math.random() * (STAR_ALPHA_MAX - STAR_ALPHA_MIN),
            dir = 1,
            speed = STAR_SPEED_MIN + math.random() * (STAR_SPEED_MAX - STAR_SPEED_MIN),
            hold = math.random() * STAR_HOLD_MAX, -- staggered initial delay
        }
    end
end
local function ShowStars() BuildStars(); for _, s in ipairs(stars) do s.tex:Show() end end
local function HideStars() for _, s in ipairs(stars) do s.tex:Hide() end end

-- [ OPTIONS BLOCKER ]------------------------------------------------------------------
local optionsBlocker = CreateFrame("Frame", nil, UIParent)
optionsBlocker:SetFrameStrata(Orbit.Constants.Strata.Topmost)
optionsBlocker:SetFrameLevel(BLOCKER_FRAME_LEVEL)
optionsBlocker:EnableMouse(true)
optionsBlocker:Hide()

local function ShowOptionsBlocker()
    optionsBlocker:ClearAllPoints()
    optionsBlocker:SetAllPoints(Orbit.SettingsDialog)
    optionsBlocker:Show()
end
local function HideOptionsBlocker() optionsBlocker:Hide() end

overlay:SetScript("OnUpdate", function(self, elapsed)
    if not Tour.active then return end
    for _, s in ipairs(stars) do
        if s.hold and s.hold > 0 then
            s.hold = s.hold - elapsed
        else
            s.hold = nil
            s.alpha = s.alpha + s.dir * s.speed * elapsed
            if s.alpha >= s.maxAlpha then
                s.alpha = s.maxAlpha; s.dir = -1
            elseif s.alpha <= 0 then
                s.alpha = 0; s.dir = 1
                s.hold = STAR_HOLD_MIN + math.random() * (STAR_HOLD_MAX - STAR_HOLD_MIN)
            end
            s.tex:SetAlpha(s.alpha)
        end
    end
end)

-- [ WELCOME TITLE ]------------------------------------------------------------------

local BARLOW_BLACK = "Interface\\AddOns\\Orbit\\Core\\assets\\Fonts\\BarlowCondensed-Black.ttf"
overlay.welcomeTitle = overlay:CreateFontString(nil, "OVERLAY")
overlay.welcomeTitle:SetFont(BARLOW_BLACK, 42, "OUTLINE")
overlay.welcomeTitle:SetPoint("CENTER", overlay, "TOP", 0, -UIParent:GetHeight() * 0.25)
overlay.welcomeTitle:SetText("|cFFFFFFFFWelcome to |cFFAA77FFOrbit|r")
overlay.welcomeTitle:SetAlpha(0)
local BARLOW_BOLD = "Interface\\AddOns\\Orbit\\Core\\assets\\Fonts\\BarlowCondensed-Bold.ttf"
overlay.welcomeSub = overlay:CreateFontString(nil, "OVERLAY")
overlay.welcomeSub:SetFont(BARLOW_BOLD, 16)
overlay.welcomeSub:SetPoint("TOP", overlay.welcomeTitle, "BOTTOM", 0, -6)
overlay.welcomeSub:SetTextColor(0.75, 0.75, 0.75)
overlay.welcomeSub:SetText("Things are done differently here")
overlay.welcomeSub:SetAlpha(0)

-- [ TASK COMPLETION STATE ]----------------------------------------------------------
local taskState = {}
local savedDialogStrata = nil
local savedDialogLevel = nil

local function ResetTaskState()
    taskState.dragged = false
    taskState.settingsOpened = false
    taskState.settingsChanged = false
    taskState.anchored = false
    taskState.distanceChanged = false
    taskState.nudged = false
    taskState.resized = false
    taskState.parentDragged = false
    taskState.anchorBroken = false
    taskState.initialPadding = nil
end

-- [ TOUR STOPS ]---------------------------------------------------------------------
local TOUR_STOPS -- forward declaration, initialized after tooltip
local UpdateHierarchyLabels, ResetHierarchyLabels
local ShowResizePulse, HideResizePulse

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
tip:SetFrameStrata(Orbit.Constants.Strata.Topmost)
tip:SetFrameLevel(TOOLTIP_LEVEL)
tip:Hide()

tip.bg = tip:CreateTexture(nil, "BACKGROUND")
tip.bg:SetAllPoints()
tip.bg:SetColorTexture(BG.r, BG.g, BG.b, BG.a)
MakeBorderEdge(tip, true, "TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT")
MakeBorderEdge(tip, true, "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT")
MakeBorderEdge(tip, false, "TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT")
MakeBorderEdge(tip, false, "TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT")

-- Directional accent bars
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

local function ApplyAccentDirection(tooltipPoint)
    for _, bar in pairs(tip.accentBars) do bar:Hide() end
    local pt = tooltipPoint:upper()
    if pt:find("TOP") then tip.accentBars.top:Show() end
    if pt:find("BOTTOM") then tip.accentBars.bottom:Show() end
    if pt:find("LEFT") then tip.accentBars.left:Show() end
    if pt:find("RIGHT") then tip.accentBars.right:Show() end
end

-- Step counter
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

-- Next / Done button (hidden until task complete)
tip.nextBtn = CreateFrame("Button", nil, tip, "UIPanelButtonTemplate")
tip.nextBtn:SetSize(NEXT_BTN_WIDTH, NEXT_BTN_HEIGHT)
tip.nextBtn:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -TOOLTIP_PAD, TOOLTIP_PAD)
tip.nextBtn:SetScript("OnClick", function()
    if Tour.index < #TOUR_STOPS then
        Tour:ShowTourStop(Tour.index + 1)
    else
        Tour:EndTour()
        Tour:ShowCanvasHint()
    end
end)

-- [ SETTINGS CHANGE TRACKING ]------------------------------------------------------
local originalSetSetting = nil

local function TrackingSetSetting(self, systemIndex, key, value)
    originalSetSetting(self, systemIndex, key, value)
    if Tour.active then
        taskState.settingsChanged = true
        if key == "Width" or key == "Height" then taskState.resized = true end
    end
end

-- [ PARENT / CHILD HELPERS ]---------------------------------------------------------
local function GetParentFrame()
    local frameA, frameB = GetFrameA(), GetFrameB()
    local Anchor = Engine.FrameAnchor
    if not Anchor or not frameA or not frameB then return frameA end
    if Anchor.anchors[frameB] then return frameA end
    if Anchor.anchors[frameA] then return frameB end
    return frameA
end

local function GetChildFrame()
    local frameA, frameB = GetFrameA(), GetFrameB()
    local Anchor = Engine.FrameAnchor
    if not Anchor or not frameA or not frameB then return frameB end
    if Anchor.anchors[frameB] then return frameB end
    if Anchor.anchors[frameA] then return frameA end
    return frameB
end

-- [ TASK STATE POLLER ]---------------------------------------------------------------
local CHECK_INTERVAL = 0.1
local checkElapsed = 0
local stopElapsed = 0
tip:SetScript("OnUpdate", function(self, elapsed)
    if not Tour.active then return end
    checkElapsed = checkElapsed + elapsed
    stopElapsed = stopElapsed + elapsed
    if checkElapsed < CHECK_INTERVAL then return end
    checkElapsed = 0
    local stop = TOUR_STOPS[Tour.index]
    if not stop then return end
    local frameA, frameB = GetFrameA(), GetFrameB()
    if not frameA or not frameB then return end
    -- Poll anchor state
    local Anchor = Engine.FrameAnchor
    if Anchor then
        taskState.anchored = (Anchor.anchors[frameA] ~= nil) or (Anchor.anchors[frameB] ~= nil)
        if taskState.anchored and taskState.initialPadding == nil then
            local a = Anchor.anchors[frameA] or Anchor.anchors[frameB]
            taskState.initialPadding = a and a.padding or 0
        end
        if taskState.initialPadding ~= nil then
            local a = Anchor.anchors[frameA] or Anchor.anchors[frameB]
            local curPadding = a and a.padding or 0
            if curPadding ~= taskState.initialPadding then taskState.distanceChanged = true end
        end
    end
    -- Poll drag state
    local Selection = Engine.FrameSelection
    if Selection then
        local sel = Selection:GetSelectedFrame()
        if sel and (sel == frameA or sel == frameB) and sel.orbitIsDragging then
            taskState.dragged = true
            if sel == GetParentFrame() then taskState.parentDragged = true end
        end
        -- Hide non-tour selections that may reappear (e.g. shift release)
        for frame, s in pairs(Selection.selections) do
            if frame ~= frameA and frame ~= frameB then
                s:SetAlpha(0)
                s:EnableMouse(false)
            end
        end
    end
    -- Keep settings dialog elevated
    local dialog = Orbit.SettingsDialog
    if dialog and dialog:IsShown() then
        dialog:SetFrameStrata(DIALOG_STRATA)
        dialog:SetFrameLevel(DIALOG_LEVEL)
    end
    -- Enable Next button when check passes or fallback timer expires
    if (stop.check and stop.check()) or stopElapsed >= NEXT_ENABLE_TIMER then tip.nextBtn:Enable() end
end)

-- [ LAYOUT TOOLTIP ]-----------------------------------------------------------------
local TOOLTIP_OFFSET = 50

local function ComputeFrameAnchor(anchorFrame)
    local cx = anchorFrame:GetCenter()
    local screenW = UIParent:GetWidth()
    if cx and cx > screenW / 2 then
        return "LEFT", "RIGHT", TOOLTIP_OFFSET, 0
    end
    return "RIGHT", "LEFT", -TOOLTIP_OFFSET, 0
end

local function LayoutTooltip(anchorFrame, stop, idx, total)
    tip.counter:SetText(idx .. " / " .. total)
    tip.title:SetText(stop.title)
    tip.text:SetText(stop.text)
    local isLast = idx == total
    tip.nextBtn:SetText(isLast and L.DONE or L.NEXT)
    tip.nextBtn:Show()
    if stop.check and stop.check() then tip.nextBtn:Enable() else tip.nextBtn:Disable() end
    local textH = tip.counter:GetStringHeight() + 2 + tip.title:GetStringHeight() + 3 + tip.text:GetStringHeight()
    local h = textH + TOOLTIP_PAD * 2 + NEXT_BTN_GAP + NEXT_BTN_HEIGHT + TOOLTIP_PAD
    tip:SetSize(TOOLTIP_MAX_WIDTH, h)
    tip:ClearAllPoints()
    local tpPoint, tpRel, tpX, tpY
    if stop.tooltipPoint then
        tpPoint, tpRel, tpX, tpY = stop.tooltipPoint, stop.tooltipRel, stop.tpX, stop.tpY
    else
        tpPoint, tpRel, tpX, tpY = ComputeFrameAnchor(anchorFrame)
    end
    tip:SetPoint(tpPoint, anchorFrame, tpRel, tpX, tpY)
    ApplyAccentDirection(tpPoint)
    tip:Show()
end

-- [ SNAP ISOLATION ]------------------------------------------------------------------
local originalGetSnapTargets = nil

local function IsolatedGetSnapTargets(self, excludeFrame)
    local frameA, frameB = GetFrameA(), GetFrameB()
    local targets = {}
    if frameA and excludeFrame ~= frameA and frameA:IsVisible() then targets[#targets + 1] = frameA end
    if frameB and excludeFrame ~= frameB and frameB:IsVisible() then targets[#targets + 1] = frameB end
    return targets
end

-- [ NUDGE TRACKING ]-----------------------------------------------------------------
local originalNudgeFrame = nil

local function TrackingNudgeFrame(self, frame, direction, ...)
    local frameA, frameB = GetFrameA(), GetFrameB()
    if frame == frameA or frame == frameB then taskState.nudged = true end
    return originalNudgeFrame(self, frame, direction, ...)
end

-- [ RESIZE PULSE ]-------------------------------------------------------------------
local resizePulses = {}

local function CreateResizePulse()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata(Orbit.Constants.Strata.Topmost)
    f:SetFrameLevel(TOOLTIP_LEVEL)
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

HideResizePulse = function()
    for i = #resizePulses, 1, -1 do
        resizePulses[i].ag:Stop()
        resizePulses[i]:Hide()
        resizePulses[i] = nil
    end
end

ShowResizePulse = function()
    HideResizePulse()
    local Selection = Engine.FrameSelection
    if not Selection then return end
    for _, tf in ipairs({ GetFrameA(), GetFrameB() }) do
        if tf then
            local sel = Selection.selections[tf]
            if sel and sel.resizeHandle then
                sel.resizeHandle:Show()
                local p = CreateResizePulse()
                p:SetParent(sel.resizeHandle)
                p:ClearAllPoints()
                p:SetAllPoints(sel.resizeHandle)
                p:SetFrameLevel(sel.resizeHandle:GetFrameLevel() + 5)
                p:Show()
                p.ag:Play()
                resizePulses[#resizePulses + 1] = p
            end
        end
    end
end

-- [ TOUR STOPS (deferred init — needs frame refs) ]----------------------------------
TOUR_STOPS = {
    { anchorKey = "A",
      title = L.STEP1_TITLE, text = L.STEP1_TEXT,
      check = function() return taskState.dragged end,
      onLeave = function()
          -- Ensure frameA is selected so the settings dialog is open for step 2
          local frameA = GetFrameA()
          local Selection = Engine.FrameSelection
          if not frameA or not Selection then return end
          local sel = Selection.selections[frameA]
          if sel and not sel.isSelected then
              Selection:DeselectAll()
              sel.isSelected = true
              Selection:SetSelectedFrame(frameA, false)
              Selection:UpdateVisuals(nil, sel)
              if Selection.selectionCallbacks[frameA] then
                  Selection.selectionCallbacks[frameA](frameA)
              end
          end
      end },
    { anchorKey = "dialog", tooltipPoint = "LEFT", tooltipRel = "RIGHT", tpX = 8, tpY = 0,
      title = L.STEP2_TITLE, text = L.STEP2_TEXT,
      check = function() return taskState.settingsChanged end },
    { anchorKey = "B",
      title = L.STEP3_TITLE, text = L.STEP3_TEXT,
      check = function() return taskState.anchored end },
    { anchorKey = "parent",
      title = L.STEP4_TITLE, text = L.STEP4_TEXT,
      check = function() return taskState.parentDragged or taskState.anchorBroken end,
      onEnter = function()
          taskState.parentDragged = false
          taskState.anchorBroken = false
          local Anchor = Engine.FrameAnchor
          if not Anchor then return end
          local frameA, frameB = GetFrameA(), GetFrameB()
          for _, child in ipairs({ frameA, frameB }) do
              local a = child and Anchor.anchors[child]
              if a then
                  taskState.savedAnchor = { child = child, parent = a.parent, edge = a.edge, padding = a.padding, align = a.align }
                  return
              end
          end
      end,
      onLeave = function()
          local saved = taskState.savedAnchor
          if not saved then return end
          local Anchor = Engine.FrameAnchor
          if not Anchor then return end
          if not Anchor.anchors[saved.child] then
              Anchor:CreateAnchor(saved.child, saved.parent, saved.edge, saved.padding, nil, saved.align, true)
              UpdateHierarchyLabels()
          end
          taskState.savedAnchor = nil
      end },
    { anchorKey = "child",
      title = L.STEP5_TITLE, text = L.STEP5_TEXT,
      check = function() return taskState.distanceChanged end },
    { anchorKey = "parent",
      title = L.STEP6_TITLE, text = L.STEP6_TEXT,
      check = function() return taskState.nudged end },
    { anchorKey = "A",
      title = L.STEP7_TITLE, text = L.STEP7_TEXT,
      check = function() return taskState.resized end,
      onEnter = function() taskState.resized = false; ShowResizePulse() end,
      onLeave = function() HideResizePulse() end },
    { anchorKey = "options", tooltipPoint = "LEFT", tooltipRel = "RIGHT", tpX = 8, tpY = 0,
      title = L.STEP8_TITLE, text = L.STEP8_TEXT,
      check = function() return true end,
      onEnter = function()
          if Orbit.OptionsPanel then
              Orbit.OptionsPanel:Open("Global")
              C_Timer.After(0.05, ShowOptionsBlocker)
          end
      end,
      onLeave = function()
          HideOptionsBlocker()
          if Orbit.OptionsPanel then Orbit.OptionsPanel:Hide() end
      end },
    { anchorKey = "center", tooltipPoint = "CENTER", tooltipRel = "CENTER", tpX = 0, tpY = 0,
      title = L.STEP9_TITLE, text = L.STEP9_TEXT,
      check = function() return true end,
      onEnter = function()
          if Orbit.OptionsPanel then
              Orbit.OptionsPanel:Open("Global")
              C_Timer.After(0.05, ShowOptionsBlocker)
          end
      end,
      onLeave = function()
          HideOptionsBlocker()
          if Orbit.OptionsPanel then Orbit.OptionsPanel:Hide() end
      end },
}


local function ResolveAnchor(stop)
    if stop.anchorKey == "center" then return UIParent
    elseif stop.anchorKey == "A" then return GetFrameA()
    elseif stop.anchorKey == "B" then return GetFrameB()
    elseif stop.anchorKey == "parent" then return GetParentFrame()
    elseif stop.anchorKey == "child" then return GetChildFrame()
    elseif stop.anchorKey == "dialog" then return Orbit.SettingsDialog
    elseif stop.anchorKey == "options" then return Orbit.SettingsDialog end
end

-- [ HIERARCHY LABELS ]---------------------------------------------------------------
UpdateHierarchyLabels = function()
    local frameA, frameB = GetFrameA(), GetFrameB()
    if not frameA or not frameB then return end
    local parent = GetParentFrame()
    if parent == frameA then
        frameA.label:SetText("A (Parent)")
        frameB.label:SetText("B (Child)")
    elseif parent == frameB then
        frameB.label:SetText("B (Parent)")
        frameA.label:SetText("A (Child)")
    end
end

ResetHierarchyLabels = function()
    local frameA, frameB = GetFrameA(), GetFrameB()
    if frameA then frameA.label:SetText("A") end
    if frameB then frameB.label:SetText("B") end
end

-- [ ANCHOR TRACKING ]----------------------------------------------------------------
local originalBreakAnchor = nil

local function TrackingBreakAnchor(self, child, ...)
    local result = originalBreakAnchor(self, child, ...)
    if Tour.active then
        local frameA, frameB = GetFrameA(), GetFrameB()
        if child == frameA or child == frameB then
            taskState.anchorBroken = true
            local Anchor = Engine.FrameAnchor
            local hasAnchor = Anchor and ((Anchor.anchors[frameA] ~= nil) or (Anchor.anchors[frameB] ~= nil))
            if hasAnchor then UpdateHierarchyLabels() else ResetHierarchyLabels() end
        end
    end
    return result
end

-- [ TOOLTIP ANIMATION ]--------------------------------------------------------------
local SHRINK_SCALE = 0.7
local GROW_START = 0.85
local animFrame = CreateFrame("Frame")

local function AnimateTooltip(fromScale, toScale, fromAlpha, toAlpha, duration, onComplete)
    local elapsed = 0
    animFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / duration, 1)
        local ease = 1 - (1 - t) * (1 - t)
        tip:SetScale(fromScale + (toScale - fromScale) * ease)
        tip:SetAlpha(fromAlpha + (toAlpha - fromAlpha) * ease)
        if t >= 1 then
            self:SetScript("OnUpdate", nil)
            if onComplete then onComplete() end
        end
    end)
end

-- [ TOUR CONTROL ]-------------------------------------------------------------------
function Tour:ShowTourStop(idx)
    -- Clean up previous stop
    if self.index > 0 then
        local prevStop = TOUR_STOPS[self.index]
        if prevStop and prevStop.onLeave then prevStop.onLeave() end
    end
    local stop = TOUR_STOPS[idx]
    if not stop then self:EndTour(); return end
    self.index = idx
    checkElapsed = 0
    stopElapsed = 0
    taskCompleteAt = nil

    local anchor = ResolveAnchor(stop)
    if not anchor then self:EndTour(); return end

    -- Update hierarchy labels based on actual anchor state
    local Anchor = Engine.FrameAnchor
    local hasAnchor = Anchor and ((Anchor.anchors[GetFrameA()] ~= nil) or (Anchor.anchors[GetFrameB()] ~= nil))
    if hasAnchor then UpdateHierarchyLabels() else ResetHierarchyLabels() end
    local isFirst = (idx == 1 and not tip:IsShown())
    if isFirst then
        if stop.onEnter then stop.onEnter() end
        LayoutTooltip(anchor, stop, idx, #TOUR_STOPS)
        tip:SetScale(GROW_START)
        tip:SetAlpha(0)
        AnimateTooltip(GROW_START, 1, 0, 1, FADE_DURATION)
    else
        AnimateTooltip(1, SHRINK_SCALE, 1, 0, FADE_DURATION, function()
            if not Tour.active then return end
            if stop.onEnter then stop.onEnter() end
            LayoutTooltip(anchor, stop, idx, #TOUR_STOPS)
            tip:SetScale(GROW_START)
            AnimateTooltip(GROW_START, 1, 0, 1, FADE_DURATION)
        end)
    end
end

function Tour:StartTour(force)
    if self.active then return end
    if not force and Orbit.db and Orbit.db.AccountSettings and Orbit.db.AccountSettings.TourComplete then return end
    local plugin = GetPlugin()
    if not plugin or not plugin.frameA or not plugin.frameB then return end
    if not force and Orbit.db and Orbit.db.AccountSettings then
        Orbit.db.AccountSettings.TourComplete = true
    end

    local ok, err = xpcall(function()
        local frameA, frameB = plugin.frameA, plugin.frameB
        self.active = true
        self.index = 0
        ResetTaskState()
        local dialog = Orbit.SettingsDialog
        if dialog then
            savedDialogStrata = dialog:GetFrameStrata()
            savedDialogLevel = dialog:GetFrameLevel()
            dialog:SetFrameStrata(DIALOG_STRATA)
            dialog:SetFrameLevel(DIALOG_LEVEL)
        end
        if not originalSetSetting then
            originalSetSetting = plugin.SetSetting
            plugin.SetSetting = TrackingSetSetting
        end
        local Selection = Engine.FrameSelection
        if Selection then
            for _, sel in pairs(Selection.selections) do
                sel:SetAlpha(0)
                sel:EnableMouse(false)
            end
        end
        if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
            for _, sysFrame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
                if sysFrame.Selection then
                    sysFrame.Selection:SetAlpha(0)
                    sysFrame.Selection:EnableMouse(false)
                end
            end
        end
        if Selection and not originalGetSnapTargets then
            originalGetSnapTargets = Selection.GetSnapTargets
            Selection.GetSnapTargets = IsolatedGetSnapTargets
        end
        local Nudge = Engine.SelectionNudge
        if Nudge and not originalNudgeFrame then
            originalNudgeFrame = Nudge.NudgeFrame
            Nudge.NudgeFrame = TrackingNudgeFrame
        end
        local AnchorMod = Engine.FrameAnchor
        if AnchorMod and not originalBreakAnchor then
            originalBreakAnchor = AnchorMod.BreakAnchor
            AnchorMod.BreakAnchor = TrackingBreakAnchor
        end
        if Selection then
            for _, tf in ipairs({ frameA, frameB }) do
                local origCb = Selection.dragCallbacks[tf]
                if origCb then
                    Selection.dragCallbacks[tf] = function(...)
                        origCb(...)
                        C_Timer.After(0, function()
                            if not Tour.active then return end
                            local Anc = Engine.FrameAnchor
                            local hasAnchor = Anc and ((Anc.anchors[frameA] ~= nil) or (Anc.anchors[frameB] ~= nil))
                            if hasAnchor then UpdateHierarchyLabels() else ResetHierarchyLabels() end
                        end)
                    end
                end
            end
        end
        plugin:SetSetting("A", "Width", FRAME_W); plugin:SetSetting("A", "Height", FRAME_H)
        plugin:SetSetting("B", "Width", FRAME_W); plugin:SetSetting("B", "Height", FRAME_H)
        taskState.settingsChanged = false
        overlay:Show()
        ShowStars()
        overlay.welcomeTitle:SetAlpha(1)
        overlay.welcomeSub:SetAlpha(1)
        frameA:SetSize(FRAME_W, FRAME_H)
        frameB:SetSize(FRAME_W, FRAME_H)
        frameA:ClearAllPoints()
        frameA:SetPoint("CENTER", UIParent, "CENTER", -FRAME_OFFSET_X, 0)
        frameB:ClearAllPoints()
        frameB:SetPoint("CENTER", UIParent, "CENTER", FRAME_OFFSET_X, 0)
        frameA:SetFrameStrata(FRAME_STRATA)
        frameA:SetFrameLevel(FRAME_LEVEL)
        frameB:SetFrameStrata(FRAME_STRATA)
        frameB:SetFrameLevel(FRAME_LEVEL)
        frameA:Show()
        frameB:Show()
        if Selection then
            for _, tf in ipairs({ frameA, frameB }) do
                local s = Selection.selections[tf]
                if s then
                    s:SetAlpha(1)
                    s:Show()
                    s:ShowHighlighted()
                    s:EnableMouse(true)
                    tf:SetMovable(true)
                end
            end
        end
        self._hiddenFrames = {}
        for _, sys in ipairs(Engine.systems) do
            if sys ~= plugin then
                local frames = sys.frames or (sys.Frame and { sys.Frame }) or (sys.frame and { sys.frame }) or {}
                for _, f in ipairs(frames) do
                    if f and f:IsShown() then
                        f:Hide()
                        self._hiddenFrames[#self._hiddenFrames + 1] = f
                    end
                end
                if sys.containers then
                    for _, c in pairs(sys.containers) do
                        if c and c:IsShown() then
                            c:Hide()
                            self._hiddenFrames[#self._hiddenFrames + 1] = c
                        end
                    end
                end
            end
        end
        if EditModeManagerFrame then
            self._editModeWasShown = EditModeManagerFrame:IsShown()
            EditModeManagerFrame:SetAlpha(0)
            EditModeManagerFrame:EnableMouse(false)
        end
        self:ShowTourStop(1)
    end, function(e)
        self:EndTour()
        return e
    end)
    if not ok then error(err) end
end

function Tour:EndTour()
    -- Clean up current step
    if self.index > 0 then
        local curStop = TOUR_STOPS[self.index]
        if curStop and curStop.onLeave then curStop.onLeave() end
    end
    self.active = false
    self.index = 0
    tip:Hide()
    overlay.welcomeTitle:SetAlpha(0)
    overlay.welcomeSub:SetAlpha(0)
    overlay:Hide()
    HideStars()
    HideResizePulse()
    ResetHierarchyLabels()
    -- Restore settings dialog strata
    local dialog = Orbit.SettingsDialog
    if dialog then
        if savedDialogStrata then dialog:SetFrameStrata(savedDialogStrata) end
        if savedDialogLevel then dialog:SetFrameLevel(savedDialogLevel) end
        savedDialogStrata = nil
        savedDialogLevel = nil
    end

    -- Stop any running animation
    animFrame:SetScript("OnUpdate", nil)
    local frameA, frameB = GetFrameA(), GetFrameB()
    -- Restore SetSetting
    local plugin = GetPlugin()
    if plugin and originalSetSetting then
        plugin.SetSetting = originalSetSetting
        originalSetSetting = nil
    end
    -- Restore GetSnapTargets
    local Selection = Engine.FrameSelection
    if Selection and originalGetSnapTargets then
        Selection.GetSnapTargets = originalGetSnapTargets
        originalGetSnapTargets = nil
    end
    -- Restore NudgeFrame
    local Nudge = Engine.SelectionNudge
    if Nudge and originalNudgeFrame then
        Nudge.NudgeFrame = originalNudgeFrame
        originalNudgeFrame = nil
    end
    -- Restore BreakAnchor
    local AnchorMod = Engine.FrameAnchor
    if AnchorMod and originalBreakAnchor then
        AnchorMod.BreakAnchor = originalBreakAnchor
        originalBreakAnchor = nil
    end
    -- Break any anchors on playground frames
    if frameA and frameB and Engine.FrameAnchor then
        Engine.FrameAnchor:BreakAnchor(frameA, true)
        Engine.FrameAnchor:BreakAnchor(frameB, true)
    end
    -- Hide playground frame selection overlays (don't destroy — factory owns them)
    if Selection and frameA and frameB then
        Selection:DeselectAll()
        for _, tf in ipairs({ frameA, frameB }) do
            local s = Selection.selections[tf]
            if s then s:Hide() end
        end
    end
    if frameA then frameA:Hide() end
    if frameB then frameB:Hide() end
    -- Restore all hidden frames
    if self._hiddenFrames then
        for _, f in ipairs(self._hiddenFrames) do
            f:Show()
        end
        self._hiddenFrames = nil
    end
    if EditModeManagerFrame then
        EditModeManagerFrame:SetAlpha(1)
        EditModeManagerFrame:EnableMouse(true)
    end
    -- Restore Orbit and Blizzard selection overlays
    if Selection then Selection:RefreshVisuals() end
end

-- [ CANVAS MODE HINT ]---------------------------------------------------------------
local canvasTip = CreateFrame("Frame", nil, UIParent)
canvasTip:SetFrameStrata(Orbit.Constants.Strata.Topmost)
canvasTip:SetFrameLevel(TOOLTIP_LEVEL)
canvasTip:Hide()
canvasTip.bg = canvasTip:CreateTexture(nil, "BACKGROUND")
canvasTip.bg:SetAllPoints()
canvasTip.bg:SetColorTexture(BG.r, BG.g, BG.b, BG.a)
MakeBorderEdge(canvasTip, true, "TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT")
MakeBorderEdge(canvasTip, true, "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT")
MakeBorderEdge(canvasTip, false, "TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT")
MakeBorderEdge(canvasTip, false, "TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT")
do
    local B = 1
    for _, side in ipairs({
        { "top", true, "TOPLEFT", "TOPRIGHT", -1 },
        { "bottom", true, "BOTTOMLEFT", "BOTTOMRIGHT", 1 },
        { "left", false, "TOPLEFT", "BOTTOMLEFT", 1 },
        { "right", false, "TOPRIGHT", "BOTTOMRIGHT", -1 },
    }) do
        local t = canvasTip:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
        if side[2] then
            t:SetHeight(2)
            t:SetPoint(side[3], B, side[5] * B)
            t:SetPoint(side[4], -B, side[5] * B)
        else
            t:SetWidth(2)
            t:SetPoint(side[3], side[5] * B, -B)
            t:SetPoint(side[4], side[5] * B, B)
        end
    end
end
canvasTip.title = canvasTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
canvasTip.title:SetPoint("TOPLEFT", TOOLTIP_PAD + 4, -TOOLTIP_PAD)
canvasTip.title:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)
canvasTip.title:SetJustifyH("LEFT")
canvasTip.title:SetWidth(TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2 - 4)
canvasTip.text = canvasTip:CreateFontString(nil, "OVERLAY", FONT)
canvasTip.text:SetPoint("TOPLEFT", canvasTip.title, "BOTTOMLEFT", 0, -3)
canvasTip.text:SetTextColor(TEXT_CLR.r, TEXT_CLR.g, TEXT_CLR.b)
canvasTip.text:SetJustifyH("LEFT")
canvasTip.text:SetWidth(TOOLTIP_MAX_WIDTH - TOOLTIP_PAD * 2 - 4)
canvasTip.text:SetSpacing(2)

local originalCanvasToggle = nil

local function GetPlayerFrame()
    for _, sys in ipairs(Engine.systems) do
        if sys.system == "Orbit_PlayerFrame" then
            return sys.frames and sys.frames[1] or sys.Frame or sys.frame
        end
    end
    return nil
end

function Tour:ShowCanvasHint()
    local playerFrame = GetPlayerFrame()
    if not playerFrame then return end
    canvasTip.title:SetText(L.CANVAS_TITLE)
    canvasTip.text:SetText(L.CANVAS_TEXT)
    local textH = canvasTip.title:GetStringHeight() + 3 + canvasTip.text:GetStringHeight()
    canvasTip:SetSize(TOOLTIP_MAX_WIDTH, textH + TOOLTIP_PAD * 2)
    canvasTip:ClearAllPoints()
    canvasTip:SetPoint("BOTTOM", playerFrame, "TOP", 0, 8)
    canvasTip:Show()
    Tour.canvasHintActive = true
    -- Pulse player frame selection color
    local Selection = Engine.FrameSelection
    local sel = Selection and Selection.selections[playerFrame]
    if sel then
        sel:Show()
        sel:ShowHighlighted()
        local defaultClr = { 0.0, 0.44, 1.0 }
        local curveData = Orbit.db and Orbit.db.GlobalSettings and Orbit.db.GlobalSettings.EditModeColorCurve
        local custom = curveData and Engine.ColorCurve:GetFirstColorFromCurve(curveData)
        if custom then defaultClr = { custom.r, custom.g, custom.b } end
        local pulseElapsed = 0
        canvasTip:SetScript("OnUpdate", function(_, dt)
            pulseElapsed = pulseElapsed + dt
            local t = (math.sin(pulseElapsed * 3) + 1) / 2
            local r = defaultClr[1] + (ACCENT.r - defaultClr[1]) * t
            local g = defaultClr[2] + (ACCENT.g - defaultClr[2]) * t
            local b = defaultClr[3] + (ACCENT.b - defaultClr[3]) * t
            for i = 1, select("#", sel:GetRegions()) do
                local region = select(i, sel:GetRegions())
                if region:IsObjectType("Texture") and not region.isAnchorLine then
                    region:SetVertexColor(r, g, b, 1)
                end
            end
        end)
    end
    -- Hook CanvasMode:Toggle to dismiss hint
    local CM = Engine.CanvasMode
    if CM and not originalCanvasToggle then
        originalCanvasToggle = CM.Toggle
        CM.Toggle = function(self, ...)
            originalCanvasToggle(self, ...)
            Tour:HideCanvasHint()
        end
    end
    -- Dismiss on Edit Mode exit (one-shot hook)
    if EditModeManagerFrame and not Tour._editModeHideHooked then
        Tour._editModeHideHooked = true
        EditModeManagerFrame:HookScript("OnHide", function()
            if Tour.canvasHintActive then Tour:HideCanvasHint() end
        end)
    end
end

function Tour:HideCanvasHint()
    canvasTip:SetScript("OnUpdate", nil)
    canvasTip:Hide()
    Tour.canvasHintActive = false
    if Orbit.db and Orbit.db.GlobalSettings then Orbit.db.GlobalSettings.TourComplete = true end
    -- Restore selection color
    local Selection = Engine.FrameSelection
    if Selection then Selection:RefreshVisuals() end
    local CM = Engine.CanvasMode
    if CM and originalCanvasToggle then
        CM.Toggle = originalCanvasToggle
        originalCanvasToggle = nil
    end
end

-- [ SLASH COMMAND (testing) ]--------------------------------------------------------
SLASH_ORBITTOUR1 = "/orbittour"
SlashCmdList["ORBITTOUR"] = function()
    if not EditModeManagerFrame or not EditModeManagerFrame:IsShown() then
        print("|cFF66DD66Orbit:|r Enter Edit Mode first (Escape > Edit Mode)")
        return
    end
    if Tour.active then Tour:EndTour() end
    Tour:StartTour(true)
end
