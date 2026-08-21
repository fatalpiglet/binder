; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: maingui                       ║
; ║  Главное окно приложения                        ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
BuildMainGui() {
    global MainGui, HoverButtons, THEME, STATE, CFG, STATS, APP_NAME, VERSION, AUTHOR
    global g_BtnSaveProfile, g_BtnSaveSettings, g_BtnGlobalSave 
    global SettingGroups := Map()

    try {
        if MainGui {
            CleanupHoverButtons(MainGui)
            MainGui.Destroy()
        }
    }
    
    A_TrayMenu.Delete() 
    A_TrayMenu.Add("Открыть меню", (*) => ShowMainGui())
    A_TrayMenu.Add("Перезагрузить", (*) => Reload())
    A_TrayMenu.Add("Выход", (*) => ExitApp())
    A_TrayMenu.Default := "Открыть меню"
    A_TrayMenu.ClickCount := 1 

    ; === 1. СОЗДАНИЕ ОКНА ===
    MainGui := Gui("-Caption +Border +OwnDialogs", APP_NAME " v" VERSION)
    MainGui.BackColor := THEME["bg"]
    MainGui.SetFont("s10 c" THEME["text"], THEME["fontFamily"])
    
    ; Фикс скролла
    try {
        if VerCompare(A_OSVersion, "10.0.17763") >= 0 {
            DWMWA_USE_IMMERSIVE_DARK_MODE := 20
            IsDark := 1
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", MainGui.Hwnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", IsDark, "Int", 4)
        }
    }

    ; === 2. ЗАГОЛОВОК ===
    TitleBar := MainGui.AddText("x0 y0 w920 h48 Background" THEME["surface"], "")
    MainGui.AddText("x0 y47 w960 h1 Background" THEME["border"], "")
    brandMark := MainGui.AddText("x18 y11 w26 h26 Center 0x200 Background" THEME["accent"] " c" THEME["bg"], "+")
    brandMark.SetFont("s14 bold", "Segoe UI")
    RoundCorners(brandMark, 26, 26, 8)
    MainGui.SetFont("s11 bold", "Segoe UI")
    MainGui.AddText("x54 y8 w280 h20 c" THEME["text"] " BackgroundTrans", APP_NAME)
    MainGui.SetFont("s8 norm", "Segoe UI")
    MainGui.AddText("x54 y27 w280 h14 c" THEME["textMuted"] " BackgroundTrans", "MEDICAL ROLEPLAY TOOL  /  v" VERSION)
    
    ; Статус автосохранения (справа от заголовка, слева от кнопки закрытия)
    MainGui.SetFont("s8 norm", "Segoe UI")
    MainGui.AddText("x610 y16 w292 Right c" THEME["success"] " BackgroundTrans vAutoSaveStatus",
        (CFG["autoSave"] ? "Автосохранение: вкл" : "Автосохранение: выкл"))

    CloseBtn := CreateStyledButton(MainGui, 920, 8, 32, 32, "x", (*) => MainGui.Hide(), "icon")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, MainGui.Hwnd))
    
    ; === 3. СТРАНИЦЫ ===
    ; Один стабильный Tab2 используется только как менеджер видимости страниц.
    ; Никаких пересозданий GUI и никаких принудительных WinRedraw при навигации.
    tabs := MainGui.AddTab2("x-2000 y-2000 w940 h700 -TabStop", ["Главная", "Бинды", "Настройки", "Статистика", "Справка"])
    tabs.Choose(1)

    ; ==============================================================================
    ; СОВРЕМЕННАЯ ШАПКА ВКЛАДКИ (единый компонент для всех разделов)
    ; Скруглённая панель + цветной акцент + плитка-иконка + заголовок +
    ; подзаголовок + статус-чип справа. Вместо старого Impact-стиля.
    ; ==============================================================================
    AddModernHeader(y, icon, iconColor, title, subtitle, chip := "", chipColor := THEME["textDim"]) {
        pnl := AddCardPanel(20, y, 920, 100, 16, iconColor)
        ; Плитка с иконкой
        tile := MainGui.AddText("x40 y" (y+22) " w56 h56 Center 0x200 Background" THEME["bgHighlight"] " c" iconColor, icon)
        tile.SetFont("s22", "Segoe UI Symbol")
        RoundCorners(tile, 56, 56, THEME["radius"])
        ; Заголовок раздела
        tit := MainGui.AddText("x116 y" (y+20) " w520 h32 c" THEME["textTitle"] " BackgroundTrans", title)
        tit.SetFont("s" THEME["fontTitle"] " bold", THEME["fontFamily"])
        ; Подзаголовок
        sub := MainGui.AddText("x118 y" (y+57) " w520 h20 c" THEME["textDim"] " BackgroundTrans", subtitle)
        sub.SetFont("s9", THEME["fontFamily"])
        ; Статус-чип справа
        if chip != "" {
            cw := Max(120, 24 + StrLen(chip) * 8)
            ch := MainGui.AddText("x" (940 - 20 - cw) " y" (y+36) " w" cw " h28 Center 0x200 BackgroundTrans c" chipColor, chip)
            ch.SetFont("s8 bold", THEME["fontFamily"])
        }
    }

    ; Одна карточка = один HWND. Контраст уровней заменяет старый frame/surface.
    AddCardPanel(x, y, w, h, radius := 14, accentColor := "") {
        card := MainGui.AddText("x" x " y" y " w" w " h" h " Background" THEME["card"], "")
        RoundCorners(card, w, h, Min(radius, THEME["radiusLg"]))
        SendPanelToBack(card)
        if accentColor != ""
            MainGui.AddText("x" x " y" y " w3 h" h " Background" accentColor, "")
        return card
    }

    ; ==============================================================================
    ; 1. ГЛАВНАЯ (компактная сетка: 3 карточки)
    ; ==============================================================================
    tabs.UseTab(1)

    yHead := 90

    ; --- ШАПКА ---
    AddModernHeader(yHead, "✚", THEME["accent"], "Doctor Binder",
        "Medical roleplay utility  ·  v" VERSION, "READY", THEME["success"])

    ; --- СЕТКА: 3 карточки в ряд ---
    yStart := 210
    cardH := 400
    gap := 12
    cw := (920 - gap * 2) // 3          ; ширина карточки = 298
    x1 := 20
    x2 := x1 + cw + gap
    x3 := x2 + cw + gap

    ; ---------- Карточка 1: Личное дело ----------
    c1 := AddCardPanel(x1, yStart, cw, cardH, THEME["radiusLg"], THEME["accent"])
    MainGui.SetFont("s13 bold", THEME["fontFamily"])
    MainGui.AddText("x" (x1+THEME["cardPad"]) " y" (yStart+15) " w" (cw-32) " c" THEME["text"] " BackgroundTrans", "Личное дело")
    MainGui.AddText("x" (x1+THEME["cardPad"]) " y" (yStart+42) " w" (cw-32) " h1 Background" THEME["border"], "")

    y := yStart + 58
    xIn := x1 + THEME["cardPad"]
    iw := cw - THEME["cardPad"] * 2     ; 266

    MainGui.SetFont("s9", THEME["fontFamily"])
    MainGui.AddText("x" xIn " y" y " w" iw " c" THEME["textDim"] " BackgroundTrans", "Имя Фамилия")
    MainGui.SetFont("s10", THEME["fontFamily"])
    MainGui.AddEdit("x" xIn " y" (y+16) " w" (iw-48) " h" THEME["inputH"] " Background" THEME["bgHighlight"] " c" THEME["text"] " vProfileName", STATE["myName"])
    MainGui["ProfileName"].OnEvent("Change", (*) => CheckProfileDirty())
    CreateStyledButton(MainGui, xIn + iw - 40, y + 16, 40, THEME["inputH"], "Авто", (*) => AutoFillSmart(), "info", "Определить ник из игры")

    y += 58
    MainGui.SetFont("s9", "Segoe UI")
    MainGui.AddText("x" xIn " y" y " w" iw " c" THEME["textDim"] " BackgroundTrans", "Больница")
    MainGui.SetFont("s10", "Segoe UI")
    MainGui.AddEdit("x" xIn " y" (y+16) " w" iw " h" THEME["inputH"] " Background" THEME["bgHighlight"] " c" THEME["text"] " vProfileHospital", STATE["hospital"])
    MainGui["ProfileHospital"].OnEvent("Change", (*) => CheckProfileDirty())

    y += 58
    MainGui.SetFont("s9", "Segoe UI")
    MainGui.AddText("x" xIn " y" y " w" iw " c" THEME["textDim"] " BackgroundTrans", "Специальность")
    MainGui.SetFont("s10", "Segoe UI")
    MainGui.AddEdit("x" xIn " y" (y+16) " w" iw " h" THEME["inputH"] " Background" THEME["bgHighlight"] " c" THEME["text"] " vProfileSpecialty", STATE["specialty"])
    MainGui["ProfileSpecialty"].OnEvent("Change", (*) => CheckProfileDirty())

    y += 56
    g_BtnSaveProfile := CreateStyledButton(MainGui, xIn, y, iw, 42, "Сохранить профиль", (*) => ApplyProfile(), "success", "Сохранить данные врача")
    g_BtnSaveProfile.ctrl.SetFont("s9 bold", "Segoe UI")
    UpdateButtonState(g_BtnSaveProfile, false)

    ; ---------- Карточка 2: Текущий пациент ----------
    c2 := AddCardPanel(x2, yStart, cw, cardH, THEME["radiusLg"], THEME["accent"])
    MainGui.SetFont("s13 bold", THEME["fontFamily"])
    MainGui.AddText("x" (x2+THEME["cardPad"]) " y" (yStart+15) " w" (cw-32) " c" THEME["text"] " BackgroundTrans", "Текущий пациент")
    MainGui.AddText("x" (x2+THEME["cardPad"]) " y" (yStart+42) " w" (cw-32) " h1 Background" THEME["border"], "")

    y := yStart + 58
    xIn := x2 + THEME["cardPad"]
    MainGui.SetFont("s9", "Segoe UI")
    MainGui.AddText("x" xIn " y" y " w" iw " c" THEME["textDim"] " BackgroundTrans", "ID пациента")
    MainGui.SetFont("s12 bold", "Consolas")
    MainGui.AddEdit("x" xIn " y" (y+16) " w" (iw-172) " h34 Center Background" THEME["bgHighlight"] " c" THEME["accent"] " vMainPatientId", STATE["patientId"])
    MainGui.SetFont("s10 bold", "Segoe UI")
    CreateStyledButton(MainGui, xIn + iw - 164, y + 16, 78, 34, "Принять", (*) => MainSetPatient(), "success")
    CreateStyledButton(MainGui, xIn + iw - 78, y + 16, 78, 34, "Сброс", (*) => MainClearPatient(), "danger")

    y += 70
    MainGui.SetFont("s9", "Segoe UI")
    MainGui.AddText("x" xIn " y" y " w" iw " c" THEME["textDim"] " BackgroundTrans", "Отображение в чате")
    MainGui.SetFont("s14 bold", "Consolas")
    MainGui.AddText("x" xIn " y" (y+16) " w" iw " c" THEME["success"] " BackgroundTrans vMainPatientDisplay", GetPatientDisplay() = "" ? "—" : GetPatientDisplay())

    y += 66
    MainGui.SetFont("s8", "Segoe UI")
    MainGui.AddText("x" xIn " y" y " w" iw " c" THEME["textMuted"] " BackgroundTrans", "ID подставится в сообщения как {P}")

    ; ---------- Карточка 3: Быстрое управление ----------
    c3 := AddCardPanel(x3, yStart, cw, cardH, THEME["radiusLg"], THEME["accent"])
    MainGui.SetFont("s13 bold", THEME["fontFamily"])
    MainGui.AddText("x" (x3+THEME["cardPad"]) " y" (yStart+15) " w" (cw-32) " c" THEME["text"] " BackgroundTrans", "Быстрое управление")
    MainGui.AddText("x" (x3+THEME["cardPad"]) " y" (yStart+42) " w" (cw-32) " h1 Background" THEME["border"], "")

    y := yStart + 58
    xIn := x3 + THEME["cardPad"]
    btnW := (iw - THEME["spacingSm"]) // 2

    CreateStyledButton(MainGui, xIn, y, btnW, THEME["btnH"], "Оверлей", (*) => ToggleOverlay(), "info", "Показать/скрыть внутриигровой оверлей")
    CreateStyledButton(MainGui, xIn + btnW + 8, y, btnW, THEME["btnH"], "Обновить бинды", (*) => RegisterAllHotkeys(), "info", "Перерегистрировать горячие клавиши биндов")

    y += 52
    MainGui.SetFont("s8 bold", "Segoe UI")
    MainGui.AddText("x" xIn " y" y " w" iw " c" THEME["textMuted"] " BackgroundTrans", "ПРОФИЛИ")
    y += 22
    CreateStyledButton(MainGui, xIn, y, btnW, THEME["btnH"], "Загрузить файл", (*) => LoadProfileDialog(), "info", "Импорт профиля из файла .ini или .aci")
    CreateStyledButton(MainGui, xIn + btnW + 8, y, btnW, THEME["btnH"], "Сохранить файл", (*) => SaveProfileDialog(), "info", "Экспорт биндов в отдельный файл .ini")

    y += 52
    CreateStyledButton(MainGui, xIn, y, iw, THEME["btnH"], "Справка и поддержка", (*) => NavSelect(5), "default", "Открыть раздел справки")

    ; ---------- Подвал: глобальные кнопки ----------
    yBottom := 674
    footerUndoW := 220
    footerSaveW := 300
    footerGap := 12
    footerX := 940 - footerUndoW - footerSaveW - footerGap
    CreateStyledButton(MainGui, footerX, yBottom, footerUndoW, 38, "Отменить действие", (*) => Undo(), "default", "Вернуть последнее изменение")
    g_BtnGlobalSave := CreateStyledButton(MainGui, footerX + footerUndoW + footerGap, yBottom, footerSaveW, 38, "Сохранить изменения", (*) => SaveEverything(), "success", "Сохранить бинды и настройки")
    g_BtnGlobalSave.ctrl.SetFont("s9 bold", "Segoe UI")

    if GlobalUnsavedChanges {
        UpdateButtonState(g_BtnGlobalSave, true, "warning")
        g_BtnGlobalSave.ctrl.Text := "Сохранить изменения (!)"
    } else {
        UpdateButtonState(g_BtnGlobalSave, false)
    }

    ; ==============================================================================
    ; 2. БИНДЫ (MODERN MANAGER LAYOUT)
    ; ==============================================================================
    tabs.UseTab(2)
    
    yHead := 90 
    
    ; --- ШАПКА (современная) ---
    AddModernHeader(yHead, "≡", THEME["accent"], "Бинды",
        "Управление и настройка", "ВСЕГО СЛОТОВ: " Constants.MAX_SLOTS)
    
    
    ; --- ОСНОВНАЯ РАБОЧАЯ ОБЛАСТЬ ---
    yStart := 210
    
    ; ======================= ЛЕВАЯ КОЛОНКА: СПИСОК (ШИРОКАЯ) =======================
    wList := 660
    
    ; Карточка списка
    cardList := AddCardPanel(20, yStart, wList, 500, 14, THEME["accent"])
    
    ; --- ПАНЕЛЬ ИНСТРУМЕНТОВ (TOOLBAR) ---
    yTool := yStart + 15
    xTool := 40
    
    MainGui.SetFont("s11 bold", "Segoe UI")
    MainGui.AddText("x" xTool " y" yTool " w150 c" THEME["accentLight"] " BackgroundTrans", "Поиск")
    
    ; Поле поиска
    MainGui.SetFont("s10 norm", "Segoe UI")
    MainGui.AddEdit("x" (xTool+100) " y" (yTool-3) " w230 h30 vBindSearch Background" THEME["bgHighlight"] " c" THEME["text"], "")
    MainGui["BindSearch"].OnEvent("Change", OnSearchChange)
    
    ; Кнопка очистки (Красный крестик)
    CreateClearBtn(MainGui, xTool+335, yTool-3, 30, (*) => ClearSearch())
    
    ; Фильтр (Справа)
    MainGui.AddText("x" (xTool+380) " y" yTool " w60 Right c" THEME["textDim"] " BackgroundTrans", "Фильтр:")
    
  
    global btnFilterDisplay
    btnFilterDisplay := CreateStyledButton(MainGui, xTool+450, yTool-3, 160, 30, "Фильтр: Все ▼", (*) => ShowModernFilterMenu(), "default")
    
    ; Разделитель под тулбаром
    MainGui.AddText("x20 y" (yTool+40) " w" wList " h2 Background" THEME["border"], "")
    
    ; --- ЗАГОЛОВОК ТАБЛИЦЫ (Кастомный) ---
    yList := yTool + 50
    hList := 400
    
    ; Фон заголовка
    MainGui.AddText("x30 y" yList " w" (wList-20) " h26 Background" THEME["bgLight"], "")
    MainGui.AddText("x30 y" (yList+26) " w" (wList-20) " h1 Background" THEME["borderGlow"], "")
    
    ; === ФИКСИРОВАННЫЕ ШИРИНЫ КОЛОНОК (Сумма = 600, чтобы влез скроллбар) ===
    col1 := 35    ; №
    col2 := 320   ; Название (Сузили, чтобы не было гор. скролла)
    col3 := 85    ; Категория
    col4 := 80    ; Клавиша
    col5 := 35    ; Стр
    col6 := 45    ; Статус
    
    ; Расчет координат X
    x1 := 30
    x2 := x1 + col1
    x3 := x2 + col2
    x4 := x3 + col3
    x5 := x4 + col4
    x6 := x5 + col5
    
    ; Текст заголовков (Координаты теперь совпадают с колонками)
    MainGui.SetFont("s8 bold", "Segoe UI")
    MainGui.AddText("x" (x1+4) " y" (yList+5) " w" col1 " c" THEME["textMuted"] " BackgroundTrans", "№")
    MainGui.AddText("x" (x2+4) " y" (yList+5) " w" col2 " c" THEME["textMuted"] " BackgroundTrans", "НАЗВАНИЕ")
    MainGui.AddText("x" (x3+4) " y" (yList+5) " w" col3 " c" THEME["textMuted"] " BackgroundTrans", "КАТЕГОРИЯ")
    MainGui.AddText("x" (x4+4) " y" (yList+5) " w" col4 " c" THEME["textMuted"] " BackgroundTrans", "КЛАВИША")
    MainGui.AddText("x" (x5+2) " y" (yList+5) " w" col5 " c" THEME["textMuted"] " BackgroundTrans", "СТР")
    MainGui.AddText("x" (x6+2) " y" (yList+5) " w" col6 " c" THEME["textMuted"] " BackgroundTrans", "СТАТУС")
    
    ; ListView
    lvTop := yList + 28
    lvH := hList - 28
    
    MainGui.SetFont("s9", "Segoe UI")
    lv := MainGui.AddListView("x30 y" lvTop " w" (wList-20) " h" lvH 
        " Background" THEME["bgLight"] " c" THEME["text"] 
        " vBindList -Hdr -Grid -Multi -HScroll +LV0x10000", 
        ["№", "Название", "Категория", "Клавиша", "Стр", "Статус"])
    
    SetDarkControl(lv)
    SetListViewRowHeight(lv, 26)
    
    ; Применяем ширины к самому ListView
    lv.ModifyCol(1, col1)
    lv.ModifyCol(2, col2)
    lv.ModifyCol(3, col3)
    lv.ModifyCol(4, col4)
    lv.ModifyCol(5, col5)
    lv.ModifyCol(6, col6)

    lv.OnEvent("DoubleClick", OnBindDoubleClick)
    lv.OnEvent("ContextMenu", OnBindContextMenu)
    ToggleSidebarButtons(false)
    lv.OnEvent("ItemSelect", (*) => SetTimer(UpdateSidebarState, -50))    

    ; Подвал списка
    MainGui.SetFont("s9", "Segoe UI")
    MainGui.AddText("x40 y" (yList+hList+10) " w200 c" THEME["textMuted"] " vListStatusLabel BackgroundTrans", "Загрузка списка...")


    ; ======================= ПРАВАЯ КОЛОНКА: ДЕЙСТВИЯ =======================
    xRight := 700
    wRight := 240
    
    ; Карточка действий
    cardActions := AddCardPanel(xRight, yStart, wRight, 500, 14, THEME["accent"])
    
    MainGui.SetFont("s12 bold", "Segoe UI")
    MainGui.AddText("x" (xRight+20) " y" (yStart+15) " w" (wRight-40) " c" THEME["warning"] " BackgroundTrans", "Действия")
    MainGui.AddText("x" (xRight+20) " y" (yStart+45) " w" (wRight-40) " h2 Background" THEME["border"], "")
    
    ySide := yStart + 60
    xSide := xRight + 20
    wSide := 200
    
    ; ОГРОМНАЯ КНОПКА СОЗДАНИЯ
    CreateStyledButton(MainGui, xSide, ySide, wSide, 50, "Создать бинд", (*) => CreateNewBind(), "success")
    
    ySide += 70
    MainGui.SetFont("s9 bold", "Segoe UI")
    MainGui.AddText("x" xSide " y" ySide " w" wSide " c" THEME["textDim"] " BackgroundTrans", "Выбранный элемент")
    
    ySide += 25
    gap := 8
    btnH := 40
    
    ; Все кнопки теперь "default" (Строгий темный стиль)
    CreateStyledButton(MainGui, xSide, ySide, wSide, btnH, "Изменить", (*) => EditSelectedBind(), "default")
    ySide += btnH + gap
    CreateStyledButton(MainGui, xSide, ySide, wSide, btnH, "Копировать", (*) => DuplicateBind(), "default")
    ySide += btnH + gap
    CreateStyledButton(MainGui, xSide, ySide, wSide, btnH, "Задать клавишу", (*) => ChangeBindHotkey(), "default")
    
    ySide += btnH + 30
    ; Удаление тоже в едином стиле (чтобы не выбивалось)
    CreateStyledButton(MainGui, xSide, ySide, wSide, btnH, "Удалить", (*) => DeleteSelectedBind(), "default")    
    ySide += btnH + 40
    ; Отмена в самом низу
    MainGui.AddText("x" xSide " y" (ySide-15) " w" wSide " h2 Background" THEME["border"], "")
    CreateStyledButton(MainGui, xSide, ySide, wSide, btnH, "Отменить действие", (*) => Undo(), "warning")

    ; ==============================================================================
    ; 3. НАСТРОЙКИ (FINAL POLISHED LAYOUT)
    ; ==============================================================================
    tabs.UseTab(3)
    
    yHead := 90
    
    ; --- ШАПКА (современная) ---
    AddModernHeader(yHead, "⚙", THEME["warning"], "Настройки",
        "Конфигурация биндера")
    
    yStart := 210
    
    ; --- ЛЕВОЕ МЕНЮ (НАВИГАЦИЯ) ---
    xMenu := 20
    wMenu := 240
    hMenu := 440 ; Высота меню и контента
    
    ; Фон под меню (скруглённая панель)
    menuPanel := AddCardPanel(xMenu, yStart, wMenu, hMenu, 14, THEME["warning"])
    
    SettingGroups := Map()
    SettingGroups["General"] := []
    SettingGroups["Notify"] := []
    SettingGroups["Timing"] := []
    SettingGroups["Hotkeys"] := []
    SettingGroups["Screenshots"] := []

    
    ; Функция создания кнопки меню (современная пилюля, как в верхней навигации)
    CreateSideBtn(yPos, text, id) {
        w := wMenu - 24
        btn := CreateStyledButton(MainGui, xMenu+12, yPos+4, w, 42, text, (*) => SwitchSettingTab(id), "default")
        btn.id := id
        btn.SetVisual(THEME["bgHighlight"], THEME["textDim"], THEME["bgSelected"])
        return btn
    }

    MenuBtns := []
    MenuBtns.Push(CreateSideBtn(yStart, "Основные", "General"))
    MenuBtns.Push(CreateSideBtn(yStart+50, "Уведомления", "Notify"))
    MenuBtns.Push(CreateSideBtn(yStart+100, "Тайминги", "Timing"))
    MenuBtns.Push(CreateSideBtn(yStart+150, "Клавиши", "Hotkeys"))
    MenuBtns.Push(CreateSideBtn(yStart+200, "Скриншоты", "Screenshots"))

    ; Переменная для текущей вкладки (объявляем глобально для доступа внутри функции)
    global CurrentSettingTab := "General"

    SwitchSettingTab(tabName) {
        CurrentSettingTab := tabName
        
        for btn in MenuBtns {
            isActive := (btn.id = tabName)
            if isActive {
                btn.SetVisual(THEME["bgSelected"], THEME["accent"], THEME["bgHover"])
                btn.ctrl.SetFont("s10 bold", "Segoe UI")
            } else {
                btn.SetVisual(THEME["bgHighlight"], THEME["textDim"], THEME["bgSelected"])
                btn.ctrl.SetFont("s10 norm", "Segoe UI")
            }
            btn.ctrl.Redraw()
        }
        
        ; Скрываем/показываем группы
        for name, ctrls in SettingGroups {
            for ctrl in ctrls {
                if IsObject(ctrl) && ctrl.HasMethod("SetVisible")
                    ctrl.SetVisible(false)
                else
                    try ctrl.Visible := false
            }
        }
        for ctrl in SettingGroups[tabName] {
            if IsObject(ctrl) && ctrl.HasMethod("SetVisible")
                ctrl.SetVisible(true)
            else
                try ctrl.Visible := true
        }
        ; Не перерисовываем всё окно принудительно — это вызывает мерцание.
    }
    
    
    ; --- ПРАВАЯ ОБЛАСТЬ (КОНТЕНТ) ---
    xContent := xMenu + wMenu + 20
    wContent := 640
    
    ; ФОНОВАЯ ПОДЛОЖКА ПОД КОНТЕНТ (ВИЗУАЛЬНЫЙ КОНТЕЙНЕР)
    contentPanel := AddCardPanel(xContent, yStart, wContent, hMenu, 14, THEME["warning"])
    
    AddToGroup(group, ctrl) {
        SettingGroups[group].Push(ctrl)
        return ctrl
    }

    CreateSegmentButton(name, xPos, yPos, label, callback) {
        btn := CreateStyledButton(MainGui, xPos, yPos, 100, 35, label, callback, "default")
        btn.ctrl.Name := name
        btn.SetVisual(THEME["bgHighlight"], THEME["textDim"], THEME["bgHover"])
        return btn
    }
    
    ; ======================= 1. ОСНОВНЫЕ =======================
    y := yStart + 20
    x := xContent + 30
    
    ; ЗАГОЛОВОК И ОПИСАНИЕ
    MainGui.SetFont("s14 bold", "Segoe UI")
    AddToGroup("General", MainGui.AddText("x" x " y" y " w400 c" THEME["accent"] " BackgroundTrans", "Основные параметры"))
    MainGui.SetFont("s9", "Segoe UI")
    AddToGroup("General", MainGui.AddText("x" x " y" (y+30) " w580 c" THEME["textDim"] " BackgroundTrans", "Настройте базовое поведение биндера, клавишу активации чата и формат отображения ID пациентов."))
    MainGui.SetFont("s10 norm", "Segoe UI")
    
    y += 70
    AddToGroup("General", MainGui.AddText("x" x " y" (y+3) " w150 c" THEME["textDim"] " BackgroundTrans", "Клавиша чата (F6/T):"))
    val := CFG["chatKey"]
    disp := val = "" ? "—" : FormatHotkey(val)
    hkChatBtn := CreateStyledButton(MainGui, x+160, y, 120, 28, disp, (*) => StartHotkeyCapture("ChatKey"), "default")
    hkChatBtn.ctrl.Name := "Display_ChatKey"
    hkChatBtn.SetVisual(THEME["bgHighlight"], val="" ? THEME["textMuted"] : THEME["accent"], THEME["bgHover"])
    hkChat := hkChatBtn.ctrl
    AddToGroup("General", hkChatBtn)
    MainGui.AddEdit("x0 y0 w0 h0 Hidden vValue_ChatKey", val) 
    ; Делаем чуть меньше и квадратным (30x30)
    btnCl := CreateClearBtn(MainGui, x+290, y-2, 30, (*) => ClearHotkey("ChatKey"))
    AddToGroup("General", btnCl) 
    
    y += 50
    AddToGroup("General", MainGui.AddText("x" x " y" (y-5) " w400 c" THEME["textDim"] " BackgroundTrans", "Формат ID пациента (как вставлять в чат):"))
    btnW := 100
    btnH := 35
    MainGui.SetFont("s9 bold", "Segoe UI")
    
    global IdFormatButtons := Map()
    b1 := CreateSegmentButton("BtnFmt_At", x, y+20, "@ID", (*) => SetIdFormatGUI("at"))
    IdFormatButtons["at"] := b1
    AddToGroup("General", b1)

    b2 := CreateSegmentButton("BtnFmt_Quote", x+btnW+10, y+20, "`"ID`"", (*) => SetIdFormatGUI("quote"))
    IdFormatButtons["quote"] := b2
    AddToGroup("General", b2)

    b3 := CreateSegmentButton("BtnFmt_Plain", x+btnW*2+20, y+20, "ID", (*) => SetIdFormatGUI("plain"))
    IdFormatButtons["plain"] := b3
    AddToGroup("General", b3)
    
    y += 90
    MainGui.SetFont("s10 norm", "Segoe UI")
    c1 := MainGui.AddCheckbox("x" x " y" y " vSettingsOnlyGTA c" THEME["text"] " Background" THEME["bgLight"] " Checked" (CFG["onlyGTA"] ? 1 : 0), " Работа только при активном окне GTA")
    AddToGroup("General", c1)
    c1.OnEvent("Click", (*) => CheckSettingsDirty())
    
    ; ======================= 2. УВЕДОМЛЕНИЯ =======================
    y := yStart + 20
    MainGui.SetFont("s14 bold", "Segoe UI")
    AddToGroup("Notify", MainGui.AddText("x" x " y" y " w400 c" THEME["warning"] " BackgroundTrans", "Система уведомлений"))
    MainGui.SetFont("s9", "Segoe UI")
    AddToGroup("Notify", MainGui.AddText("x" x " y" (y+30) " w580 c" THEME["textDim"] " BackgroundTrans", "Управляйте звуковыми и визуальными оповещениями. Полезно, если игра свернута."))
    MainGui.SetFont("s10 norm", "Segoe UI")
    
    y += 70
    c2 := MainGui.AddCheckbox("x" x " y" y " vSettingsNotifySms c" THEME["text"] " Background" THEME["bgLight"] " Checked" (CFG["notifySms"] ? 1 : 0), " Всплывающее SMS (если игра свернута)")
    AddToGroup("Notify", c2)
    c2.OnEvent("Click", (*) => CheckSettingsDirty())
    y += 40
    c3 := MainGui.AddCheckbox("x" x " y" y " vSettingsNotifyMention c" THEME["text"] " Background" THEME["bgLight"] " Checked" (CFG["notifyMention"] ? 1 : 0), " Звук при упоминании вашего ника в чате")
    AddToGroup("Notify", c3)
    c3.OnEvent("Click", (*) => CheckSettingsDirty())
    y += 40
    c4 := MainGui.AddCheckbox("x" x " y" y " vSettingsNotifyKeywords c" THEME["text"] " Background" THEME["bgLight"] " Checked" (CFG["notifyKeywords"] ? 1 : 0), " Реагировать на просьбы (врач, лечи, таблетку)")
    AddToGroup("Notify", c4)
    c4.OnEvent("Click", (*) => CheckSettingsDirty())
    y += 40
    c5 := MainGui.AddCheckbox("x" x " y" y " vSettingsConfirmDelete c" THEME["text"] " Background" THEME["bgLight"] " Checked" (EditorConfirmDelete ? 1 : 0), " Спрашивать подтверждение при удалении строк")
    AddToGroup("Notify", c5)
    c5.OnEvent("Click", (*) => CheckSettingsDirty())
    
    ; ======================= 3. ТАЙМИНГИ =======================
    y := yStart + 20
    MainGui.SetFont("s14 bold", "Segoe UI")
    AddToGroup("Timing", MainGui.AddText("x" x " y" y " w400 c" THEME["success"] " BackgroundTrans", "Тайминги и Интерфейс"))
    MainGui.SetFont("s9", "Segoe UI")
    AddToGroup("Timing", MainGui.AddText("x" x " y" (y+30) " w580 c" THEME["textDim"] " BackgroundTrans", "Настройка задержек между строками для обхода анти-флуда и прозрачность оверлея."))
    MainGui.SetFont("s10 norm", "Segoe UI")
    
    y += 70
    AddToGroup("Timing", MainGui.AddText("x" x " y" y " w150 c" THEME["textDim"] " BackgroundTrans", "Базовая (мс):"))
    AddToGroup("Timing", MainGui.AddText("x" (x+220) " y" y " w150 c" THEME["textDim"] " BackgroundTrans", "Разброс (Random):"))
    y += 25
    e1 := MainGui.AddEdit("x" x " y" y " w200 h30 Center Number Background" THEME["bgHighlight"] " c" THEME["text"] " vSettingsBaseDelay", CFG["baseDelay"])
    AddToGroup("Timing", e1)
    e1.OnEvent("Change", (*) => CheckSettingsDirty())
    e2 := MainGui.AddEdit("x" (x+220) " y" y " w200 h30 Center Number Background" THEME["bgHighlight"] " c" THEME["text"] " vSettingsJitter", CFG["jitter"])
    AddToGroup("Timing", e2)
    e2.OnEvent("Change", (*) => CheckSettingsDirty())
    
    y += 50
    AddToGroup("Timing", MainGui.AddText("x" x " y" y " w150 c" THEME["textDim"] " BackgroundTrans", "После чата (t):"))
    AddToGroup("Timing", MainGui.AddText("x" (x+220) " y" y " w150 c" THEME["textDim"] " BackgroundTrans", "После ввода (Enter):"))
    y += 25
    e3 := MainGui.AddEdit("x" x " y" y " w200 h30 Center Number Background" THEME["bgHighlight"] " c" THEME["text"] " vSettingsAfterChat", CFG["afterChatDelay"])
    AddToGroup("Timing", e3)
    e3.OnEvent("Change", (*) => CheckSettingsDirty())
    e4 := MainGui.AddEdit("x" (x+220) " y" y " w200 h30 Center Number Background" THEME["bgHighlight"] " c" THEME["text"] " vSettingsAfterEnter", CFG["afterEnterDelay"])
    AddToGroup("Timing", e4)
    e4.OnEvent("Change", (*) => CheckSettingsDirty())
    
    y += 50
    bFast := CreateStyledButton(MainGui, x, y, 130, 30, "Быстро", (*) => SetDelayPreset("fast"), "danger")
    AddToGroup("Timing", bFast)
    bNorm := CreateStyledButton(MainGui, x+140, y, 130, 30, "Норма", (*) => SetDelayPreset("norm"), "info")
    AddToGroup("Timing", bNorm)
    bSlow := CreateStyledButton(MainGui, x+280, y, 130, 30, "Full RP", (*) => SetDelayPreset("rp"), "success")
    AddToGroup("Timing", bSlow)
    
    y += 45
    cAutoSave := MainGui.AddCheckbox("x" x " y" y " vSettingsEditorAutoSave c" THEME["text"] " Background" THEME["bgLight"] " Checked" (CFG["editorAutoSaveDelay"] ? 1 : 0), " Авто-сохранение задержки в редакторе (без галочки)")
    AddToGroup("Timing", cAutoSave)
    cAutoSave.OnEvent("Click", (*) => CheckSettingsDirty())
    
    y += 40 
    AddToGroup("Timing", MainGui.AddText("x" x " y" y " w250 c" THEME["textDim"] " BackgroundTrans", "Прозрачность оверлея:"))
    slVal := MainGui.AddText("x" (x+300) " y" y " w100 Right c" THEME["accent"] " vOpacityDisplay BackgroundTrans", CFG["overlayOpacity"])
    AddToGroup("Timing", slVal)
    y += 25
    sl := MainGui.AddSlider("x" x " y" y " w420 h30 vSettingsOverlayOpacity Range100-255 AltSubmit" " Background" THEME["bgLight"], CFG["overlayOpacity"])
    AddToGroup("Timing", sl)
    sl.OnEvent("Change", (ctrl, *) => (
        MainGui["OpacityDisplay"].Text := ctrl.Value,
        CheckSettingsDirty()
    ))
    
    ; ======================= 4. КЛАВИШИ =======================
    y := yStart + 20
    MainGui.SetFont("s14 bold", "Segoe UI")
    AddToGroup("Hotkeys", MainGui.AddText("x" x " y" y " w400 c" THEME["text"] " BackgroundTrans", "Глобальные клавиши"))
    
    y += 40 

    ; --- ВОТ ЭТОЙ ФУНКЦИИ НЕ ХВАТАЛО ---
    AddGroupHotkey(label, type, yPos) {
        MainGui.SetFont("s10 norm", "Segoe UI")
        AddToGroup("Hotkeys", MainGui.AddText("x" x " y" (yPos+3) " w120 c" THEME["textDim"] " BackgroundTrans", label))
        
        val := CFG["hotkey" type]
        disp := val = "" ? "—" : FormatHotkey(val)
        
        ; Поле отображения клавиши
        hkBtn := CreateStyledButton(MainGui, x+130, yPos, 200, 28, disp, (*) => StartHotkeyCapture(type), "default")
        hkBtn.ctrl.Name := "Display_" type
        hkBtn.SetVisual(THEME["bgHighlight"], val="" ? THEME["textMuted"] : THEME["accent"], THEME["bgHover"])
        hk := hkBtn.ctrl
        AddToGroup("Hotkeys", hkBtn)
        
        ; Скрытое поле для хранения значения
        MainGui.AddEdit("x0 y0 w0 h0 Hidden vValue_" type, val)
        
        ; Кнопка очистки (Крестик)
        bn := CreateClearBtn(MainGui, x+340, yPos-1, 30, (*) => ClearHotkey(type))
        AddToGroup("Hotkeys", bn)
        
        ; Статус (для конфликтов)
        st := MainGui.AddText("x" (x+130) " y" (yPos+30) " w200 h15 c" THEME["error"] " vStatus_" type " BackgroundTrans", "")
        AddToGroup("Hotkeys", st)
        
    }
    ; -----------------------------------
    
    ; Теперь вызовы сработают:
    AddGroupHotkey("Оверлей:", "Overlay", y)
    y += 42
    AddGroupHotkey("Мини-вид:", "MiniOverlay", y)
    y += 42
    AddGroupHotkey("Стоп бинд:", "StopSending", y)
    y += 42
    AddGroupHotkey("Ответ SMS:", "ReplySms", y)
    
    y += 48 ; Отступ перед колесом
    AddGroupHotkey("Радиальное меню:", "Wheel", y)
    
    y += 50 ; Отступ перед секторами
    
    MainGui.SetFont("s10 bold", "Segoe UI")
    AddToGroup("Hotkeys", MainGui.AddText("x" x " y" y " w400 c" THEME["accent"] " BackgroundTrans", "Настройка секторов меню:"))
    y += 30
    
    ; Функция ячейки радиального меню
    AddWheelCell(label, cfgKey, xPos, yPos) {
        MainGui.SetFont("s9", "Segoe UI")
        AddToGroup("Hotkeys", MainGui.AddText("x" xPos " y" (yPos+4) " w60 c" THEME["textDim"] " BackgroundTrans", label))
        
        currentID := CFG[cfgKey]
        currentName := "— Пусто —"
        if (currentID > 0 && currentID <= Constants.MAX_SLOTS) {
            sName := SLOTS[currentID]["name"]
            currentName := "[" currentID "] " (StrLen(sName) > 10 ? SubStr(sName, 1, 8) ".." : sName)
        }
        
        btn := CreateStyledButton(MainGui, xPos+65, yPos-2, 145, 28, currentName, 
            ((k, b) => (*) => ShowBindSelector(k, b))(cfgKey, "btnWheel_" cfgKey), "default")
            
        btn.ctrl.Name := "btnWheel_" cfgKey
        AddToGroup("Hotkeys", btn)
    }
    
    col2_X := x + 230
    
    ; Ряд 1
    AddWheelCell("Верх:", "wheelTop", x, y)
    AddWheelCell("Право:", "wheelRight", col2_X, y)
    
    y += 35 ; Компактный отступ
    ; Ряд 2
    AddWheelCell("Лево:", "wheelLeft", x, y)
    AddWheelCell("Низ:",  "wheelBottom", col2_X, y)

    ; ======================= 5. СКРИНШОТЫ =======================
    y := yStart + 20
    MainGui.SetFont("s14 bold", "Segoe UI")
    ; Заголовок
    AddToGroup("Screenshots", MainGui.AddText("x" x " y" y " w400 c" THEME["accent"] " BackgroundTrans", "Автоматические отчеты"))
    
    y += 30
    MainGui.SetFont("s9", "Segoe UI")
    ; Описание
    AddToGroup("Screenshots", MainGui.AddText("x" x " y" y " w580 c" THEME["textDim"] " BackgroundTrans", "Биндер будет сам делать F8 при лечении и раскладывать скрины по папкам."))
    
    y += 40
    MainGui.SetFont("s11 bold", "Segoe UI")
    ; Чекбокс
    cScr := MainGui.AddCheckbox("x" x " y" y " vSettingsAutoScreen c" THEME["success"] " Background" THEME["bgLight"] " Checked" (CFG["autoScreen"] ? 1 : 0), " Включить авто-сортировку (Smart Sort)")
    AddToGroup("Screenshots", cScr)
    cScr.OnEvent("Click", (*) => CheckSettingsDirty())
    
    
    y += 40
    MainGui.SetFont("s9", "Segoe UI")
    AddToGroup("Screenshots", MainGui.AddText("x" x " y" y " w580 c" THEME["textDim"] " BackgroundTrans", "Создайте правила: какую фразу искать в чате и куда сохранять скриншот."))
    
    y += 25
    
    ; === 1. КРАСИВЫЙ ЗАГОЛОВОК ТАБЛИЦЫ (Как в Бинды) ===
    ; Фон заголовка
    AddToGroup("Screenshots", MainGui.AddText("x" x " y" y " w500 h26 Background" THEME["bgLight"], ""))
    ; Линия подчеркивания
    AddToGroup("Screenshots", MainGui.AddText("x" x " y" (y+26) " w500 h1 Background" THEME["borderGlow"], ""))
    
    ; Текст колонок
    MainGui.SetFont("s8 bold", "Segoe UI")
    AddToGroup("Screenshots", MainGui.AddText("x" (x+5)   " y" (y+5) " w135 c" THEME["textMuted"] " BackgroundTrans", "НАЗВАНИЕ"))
    AddToGroup("Screenshots", MainGui.AddText("x" (x+145) " y" (y+5) " w175 c" THEME["textMuted"] " BackgroundTrans", "ФРАЗА (ТРИГГЕР)"))
    AddToGroup("Screenshots", MainGui.AddText("x" (x+325) " y" (y+5) " w170 c" THEME["textMuted"] " BackgroundTrans", "ПАПКА"))
    
    ; === 2. САМА ТАБЛИЦА (Без стандартного заголовка) ===
    y += 28
    MainGui.SetFont("s9", "Segoe UI")
    ; Флаг -Hdr убирает стандартный заголовок, -Multi запрещает выбор нескольких, -Grid убирает сетку (для чистоты)
    lvRules := MainGui.AddListView("x" x " y" y " w500 h200 Background" THEME["bgLight"] " c" THEME["text"] " vScreenRulesList -Hdr -Multi -Grid", ["Name", "Phrase", "Path"])
    AddToGroup("Screenshots", lvRules)
    
    ; Применяем стили (Темная полоса прокрутки + Высокие строки)
    SetDarkControl(lvRules)
    SetListViewRowHeight(lvRules, 26)
    
    ; Настраиваем ширину колонок под наш нарисованный заголовок
    lvRules.ModifyCol(1, 140)
    lvRules.ModifyCol(2, 180)
    lvRules.ModifyCol(3, 160) ; Оставляем место под скролл
    
    ; === 3. КНОПКИ СПРАВА ===
    btnX := x + 510
    
    bAdd := CreateStyledButton(MainGui, btnX, y, 100, 30, "Добавить", (*) => AddScreenRule(), "success")
    AddToGroup("Screenshots", bAdd)
    
    bEdit := CreateStyledButton(MainGui, btnX, y+40, 100, 30, "Изменить", (*) => EditScreenRule(), "info")
    AddToGroup("Screenshots", bEdit)
    
    bDel := CreateStyledButton(MainGui, btnX, y+80, 100, 30, "Удалить", (*) => DeleteScreenRule(), "danger")
    AddToGroup("Screenshots", bDel)
    
    ; Заполнение данными
    RefreshScreenRulesList()    
    ; --- КНОПКИ ВНИЗУ (ВЫРОВНЕНЫ ПО ВЫСОТЕ) ---
    y := 675 ; <--- Подняли, чтобы точно влезали в h760
    MainGui.AddText("x20 y" y " w920 h2 Background" THEME["borderGlow"], "")
    y += 15
    
    CreateStyledButton(MainGui, 30, y, 140, 40, "Сброс КФГ", (*) => ResetSettingsDefault(), "warning")
    CreateStyledButton(MainGui, 180, y, 140, 40, "Сброс стат.", (*) => ResetStats(), "danger")
    CreateStyledButton(MainGui, 330, y, 140, 40, "Удал. бинды", (*) => ClearAllBindsAction(), "danger")
    
    g_BtnSaveSettings := CreateStyledButton(MainGui, 490, y, 440, 40, "Сохранить изменения", (*) => ApplyAndSaveSettings(), "success")
    UpdateButtonState(g_BtnSaveSettings, false)
    
    SwitchSettingTab("General")


    ; ==============================================================================
    ; 4. СТАТИСТИКА (SIDEBAR STYLE)
    ; ==============================================================================
    tabs.UseTab(4)
    
    yHead := 90
    
    ; --- ШАПКА (современная) ---
    AddModernHeader(yHead, "▲", THEME["success"], "Статистика",
        "Анализ сессии")
    
    ; --- ЛЕВОЕ МЕНЮ ---
    yStart := 200
    xMenu := 20
    wMenu := 240
    hMenu := 440
    
    statPanel := AddCardPanel(xMenu, yStart, wMenu, hMenu, THEME["radiusLg"], THEME["success"])
    
    StatGroups := Map()
    StatGroups["Dashboard"] := []
    StatGroups["Info"] := []
    
    ; Функция кнопки меню статистики (современная пилюля)
    CreateStatBtn(yPos, text, id) {
        w := wMenu - 24
        btn := CreateStyledButton(MainGui, xMenu+12, yPos+4, w, 42, text, (*) => SwitchStatTab(id), "default")
        btn.id := id
        btn.SetVisual(THEME["bgHighlight"], THEME["textDim"], THEME["bgSelected"])
        return btn
    }

    StatBtns := []
    StatBtns.Push(CreateStatBtn(yStart, "Дашборд", "Dashboard"))
    StatBtns.Push(CreateStatBtn(yStart+50, "Информация", "Info"))
    
    global CurrentStatTab := "Dashboard"
    
    SwitchStatTab(tabName) {
        CurrentStatTab := tabName
        for btn in StatBtns {
            isActive := (btn.id = tabName)
            if isActive {
                btn.SetVisual(THEME["success"], THEME["bg"], THEME["success"])
                btn.ctrl.SetFont("s10 bold", "Segoe UI")
            } else {
                btn.SetVisual(THEME["bgHighlight"], THEME["textDim"], THEME["bgSelected"])
                btn.ctrl.SetFont("s10 norm", "Segoe UI")
            }
            btn.ctrl.Redraw()
        }
        for name, ctrls in StatGroups {
            for ctrl in ctrls {
                try ctrl.Visible := false
            }
        }
        for ctrl in StatGroups[tabName] {
            try ctrl.Visible := true
        }
        ; Не перерисовываем всё окно принудительно — это вызывает мерцание.
    }
    
    ; --- ПРАВАЯ ОБЛАСТЬ ---
    xContent := xMenu + wMenu + 20
    wContent := 640
    
    statContent := AddCardPanel(xContent, yStart, wContent, hMenu, THEME["radiusLg"], THEME["success"])
    
    AddToStatGroup(group, ctrl) {
        StatGroups[group].Push(ctrl)
        return ctrl
    }
    
    ; === 1. ДАШБОРД (КАРТОЧКИ) ===
    y := yStart + 20
    x := xContent + 20
    
    CreateDashCard(x, y, w, h, title, varName, value, color) {
        bg := MainGui.AddText("x" x " y" y " w" w " h" h " Background" THEME["bgElevated"], "")
        RoundCorners(bg, w, h, THEME["radius"])
        
        MainGui.SetFont("s9 bold", "Segoe UI")
        tit := MainGui.AddText("x" (x+15) " y" (y+10) " w" (w-20) " c" THEME["textDim"] " BackgroundTrans", title)
        
        MainGui.SetFont("s30 bold", "Segoe UI")
        val := MainGui.AddText("x" (x+12) " y" (y+26) " w" (w-20) " h50 c" THEME["text"] " BackgroundTrans v" varName, value)
        
        AddToStatGroup("Dashboard", bg)
        AddToStatGroup("Dashboard", tit)
        AddToStatGroup("Dashboard", val)
    }
    
    ; Ряд 1
    cw := 190
    gap := 15
    CreateDashCard(x, y, cw, 100, "Лечение", "StatPatientsHealed", STATS["patientsHealed"], THEME["success"])
    CreateDashCard(x+cw+gap, y, cw, 100, "Операции", "StatOperations", STATS["operationsDone"], THEME["error"])
    CreateDashCard(x+(cw+gap)*2, y, cw, 100, "Всего", "StatTotalSent", STATS["totalSent"], THEME["accent"])
    
    y += 115
    ; Ряд 2
    CreateDashCard(x, y, cw, 100, "Уколы", "StatInjections", STATS["injectionsGiven"], THEME["warning"])
    CreateDashCard(x+cw+gap, y, cw, 100, "Медосмотры", "StatMedChecks", STATS["medChecks"], THEME["accentLight"])
    CreateDashCard(x+(cw+gap)*2, y, cw, 100, "Таблетки", "StatPills", STATS["pillsGiven"], THEME["textDim"])
    
    y += 115
    ; Ряд 3
    CreateDashCard(x, y, cw, 100, "Вакцинации", "StatVaccines", STATS["vaccinesGiven"], THEME["accent"])
    CreateDashCard(x+cw+gap, y, cw, 100, "Всего биндов", "StatTotalBinds", "—", THEME["textDim"])
    CreateDashCard(x+(cw+gap)*2, y, cw, 100, "Активных биндов", "StatActiveBinds", "—", THEME["success"])
    
    
    ; === 2. ИНФО ===
    y := yStart + 30
    x := xContent + 40
    MainGui.SetFont("s16 bold", "Segoe UI")
    AddToStatGroup("Info", MainGui.AddText("x" x " y" y " w400 c" THEME["accent"] " BackgroundTrans", "Информация о сессии"))
    
    y += 60
    MainGui.SetFont("s11 norm", "Segoe UI")
    AddToStatGroup("Info", MainGui.AddText("x" x " y" y " w200 c" THEME["textDim"] " BackgroundTrans", "Время запуска:"))
    MainGui.SetFont("s16 bold", "Consolas")
    AddToStatGroup("Info", MainGui.AddText("x" (x+200) " y" (y-5) " w300 c" THEME["text"] " BackgroundTrans", FormatTime(STATS["sessionStart"], "HH:mm:ss")))
    
    y += 50
    MainGui.SetFont("s11 norm", "Segoe UI")
    AddToStatGroup("Info", MainGui.AddText("x" x " y" y " w200 c" THEME["textDim"] " BackgroundTrans", "Текущее время:"))
    MainGui.SetFont("s16 bold", "Consolas")
    ; Часы
    clk := MainGui.AddText("x" (x+200) " y" (y-5) " w300 c" THEME["success"] " vRealTimeClock BackgroundTrans", FormatTime(A_Now, "HH:mm:ss"))
    AddToStatGroup("Info", clk)
    
    y += 100
    MainGui.SetFont("s10 italic", "Segoe UI")
    infoTxt := "Статистика автоматически сохраняется в файл конфигурации при каждом действии.`n`n" 
             . "При перезапуске скрипта, если не было сброса, статистика продолжается.`n`n"
             . "Используйте кнопку 'Сбросить всё' внизу для начала новой смены."
    AddToStatGroup("Info", MainGui.AddText("x" x " y" y " w560 h100 c" THEME["textDim"], infoTxt))
    
    
    ; --- КНОПКИ ВНИЗУ ---
    y := 675
    MainGui.AddText("x20 y" y " w920 h2 Background" THEME["borderGlow"], "")
    y += 15
    CreateStyledButton(MainGui, 740, y, 180, 40, "Сбросить всё", (*) => ResetStats(), "danger")
    CreateStyledButton(MainGui, 540, y, 180, 40, "Обновить", (*) => UpdateStatsDisplay(), "default")
    
    SwitchStatTab("Dashboard")

    ; ==============================================================================
    ; 5. СПРАВКА (FINAL LAYOUT WITH STATIC SIDEBAR)
    ; ==============================================================================
    tabs.UseTab(5)
    
    yHead := 90
    
    ; --- ШАПКА (современная) ---
    AddModernHeader(yHead, "?", THEME["accentLight"], "Справка",
        "База знаний и поддержка")
    
    yStart := 200
    
    ; --- ЛЕВОЕ МЕНЮ (НАВИГАЦИЯ) ---
    xMenu := 20
    wMenu := 200 ; Чуть уже
    hMenu := 460
    
    helpPanel := AddCardPanel(xMenu, yStart, wMenu, hMenu, THEME["radiusLg"], THEME["accentLight"])
    
    HelpGroups := Map()
    HelpGroups["Overlay"] := []
    HelpGroups["Syntax"] := []
    HelpGroups["About"] := []
    
    CreateHelpBtn(yPos, text, id) {
        w := wMenu - 24
        btn := CreateStyledButton(MainGui, xMenu+12, yPos+4, w, 42, text, (*) => SwitchHelpTab(id), "default")
        btn.id := id
        btn.SetVisual(THEME["bgHighlight"], THEME["textDim"], THEME["bgSelected"])
        return btn
    }

    HelpBtns := []
    HelpBtns.Push(CreateHelpBtn(yStart, "Оверлей", "Overlay"))
    HelpBtns.Push(CreateHelpBtn(yStart+50, "Синтаксис", "Syntax"))
    HelpBtns.Push(CreateHelpBtn(yStart+100, "О программе", "About"))
    
    global CurrentHelpTab := "Overlay"
    
    SwitchHelpTab(tabName) {
        CurrentHelpTab := tabName
        for btn in HelpBtns {
            isActive := (btn.id = tabName)
            if isActive {
                btn.SetVisual(THEME["accent"], THEME["bg"], THEME["accent"])
                btn.ctrl.SetFont("s10 bold", "Segoe UI")
            } else {
                btn.SetVisual(THEME["bgHighlight"], THEME["textDim"], THEME["bgSelected"])
                btn.ctrl.SetFont("s10 norm", "Segoe UI")
            }
            btn.ctrl.Redraw()
        }
        for name, ctrls in HelpGroups {
            for ctrl in ctrls {
                try ctrl.Visible := false
            }
        }
        for ctrl in HelpGroups[tabName] {
            try ctrl.Visible := true
        }
        ; Не перерисовываем всё окно принудительно — это вызывает мерцание.
    }
    
    ; --- ЦЕНТРАЛЬНАЯ ОБЛАСТЬ (МЕНЯЮЩИЙСЯ КОНТЕНТ) ---
    xCenter := xMenu + wMenu + 20
    wCenter := 440 ; Место под контент
    
    centerPanel := AddCardPanel(xCenter, yStart, wCenter, hMenu, THEME["radiusLg"], THEME["accentLight"])
    
    AddToHelp(group, ctrl) {
        HelpGroups[group].Push(ctrl)
        return ctrl
    }
    
    ; === 1. ОВЕРЛЕЙ ===
    y := yStart + 20
    x := xCenter + 30
    
    hkOver := CFG["hotkeyOverlay"] = "" ? "Не задано" : FormatHotkey(CFG["hotkeyOverlay"])
    hkMini := CFG["hotkeyMiniOverlay"] = "" ? "Не задано" : FormatHotkey(CFG["hotkeyMiniOverlay"])
    
    MainGui.SetFont("s14 bold", "Segoe UI")
    AddToHelp("Overlay", MainGui.AddText("x" x " y" y " w350 c" THEME["accent"] " BackgroundTrans", "Управление"))
    y += 50
    MainGui.SetFont("s9", "Consolas")
    helpText1 := 
    (
    hkOver " ...... Полный оверлей
    " hkMini " .. Мини‑оверлей
    F8 ........... Стоп бинд
    
    ↑ / ↓ ........ Выбор бинда
    Enter ........ Запуск
    1 – 0 ........ Быстрый выбор
    PgUp/Dn ...... Страницы
    
    P ............ Ввод ID
    C ............ Очистить ID
    Escape ....... Закрыть"
    )
    AddToHelp("Overlay", MainGui.AddText("x" x " y" y " w350 h350 c" THEME["textDim"] " BackgroundTrans", helpText1))
    
    ; === 2. СИНТАКСИС ===
    y := yStart + 20
    MainGui.SetFont("s14 bold", "Segoe UI")
    AddToHelp("Syntax", MainGui.AddText("x" x " y" y " w350 c" THEME["success"] " BackgroundTrans", "Переменные"))
    y += 50
    MainGui.SetFont("s10 bold", "Consolas")
    tags := [
        "{P}          ID пациента",
        "{MY}         Ваше имя",
        "{HOSPITAL}   Больница",
        "{SPECIALTY}  Должность"
    ]
    for tag in tags {
        t := AddToHelp("Syntax", MainGui.AddText("x" x " y" y " w350 h20 c" THEME["accentLight"], tag))
        y += 30
    }
    y += 20
    MainGui.SetFont("s9 italic", "Segoe UI")
    AddToHelp("Syntax", MainGui.AddText("x" x " y" y " w350 c" THEME["textDim"] " BackgroundTrans", "Пример: Привет, я {MY}. Что болит, {P}?"))
    
    ; === 3. О ПРОГРАММЕ ===
    y := yStart + 20
    MainGui.SetFont("s16 bold", "Segoe UI")
    AddToHelp("About", MainGui.AddText("x" x " y" y " w350 c" THEME["accent"] " BackgroundTrans", "О программе"))
    y += 40
    
    ; Лого-блок: плитка с крестом + крупное название биндера
    logo := MainGui.AddText("x" x " y" y " w56 h56 Center 0x200 Background" THEME["bgHighlight"] " c" THEME["error"], "✚")
    logo.SetFont("s26", "Segoe UI Symbol")
    RoundCorners(logo, 56, 56, 14)
    AddToHelp("About", logo)
    
    MainGui.SetFont("s26 bold", "Segoe UI")
    AddToHelp("About", MainGui.AddText("x" (x+70) " y" (y+4) " w280 c" THEME["text"] " BackgroundTrans", "Doctor Binder"))
    MainGui.SetFont("s11", "Segoe UI")
    AddToHelp("About", MainGui.AddText("x" (x+72) " y" (y+38) " w280 c" THEME["textDim"] " BackgroundTrans", "v" VERSION "  •  " AUTHOR))
    
    y += 78
    sepAbout := MainGui.AddText("x" x " y" y " w350 h2 Background" THEME["border"], "")
    AddToHelp("About", sepAbout)
    y += 20
    MainGui.SetFont("s10", "Segoe UI")
    AddToHelp("About", MainGui.AddText("x" x " y" y " w350 c" THEME["textDim"] " BackgroundTrans", "Версия: " VERSION))
    y += 28
    AddToHelp("About", MainGui.AddText("x" x " y" y " w350 c" THEME["textDim"] " BackgroundTrans", "Автор: " AUTHOR))
    y += 28
    AddToHelp("About", MainGui.AddText("x" x " y" y " w350 c" THEME["textDim"] " BackgroundTrans", "Год: 2026"))
    y += 40
    MainGui.SetFont("s9 italic", "Segoe UI")
    AddToHelp("About", MainGui.AddText("x" x " y" y " w350 h100 c" THEME["textDim"] " BackgroundTrans", "Разработано специально для медицинского сообщества SAMP ABS RP"))
    
    
    ; --- ПРАВАЯ ОБЛАСТЬ (КОНТАКТЫ - ВСЕГДА ВИДНЫ) ---
    xRight := xCenter + wCenter + 20
    wRight := 240
    y := yStart
    
    ; Фон правой панели
    rightPanel := AddCardPanel(xRight, y, wRight, hMenu, THEME["radiusLg"], THEME["accentLight"])
    
    y += 20
    xIn := xRight + 20
    
    MainGui.SetFont("s12 bold", "Segoe UI")
    MainGui.AddText("x" xIn " y" y " w200 c" THEME["accent"] " BackgroundTrans", "Связь")
    y += 40
    
    MainGui.SetFont("s10 norm", "Segoe UI")
    MainGui.AddLink("x" xIn " y" (y+5) " w180 c" THEME["accent"] " Background" THEME["card"], '<a href="https://t.me/maxon3r">Telegram</a>')
    y += 50
    MainGui.AddLink("x" xIn " y" (y+5) " w180 c" THEME["accent"] " Background" THEME["card"], '<a href="https://vk.com/20max19">ВКонтакте</a>')
    
    y += 70
    MainGui.AddText("x" xIn " y" y " w200 h1 Background" THEME["border"], "")
    y += 20
    
    MainGui.SetFont("s12 bold", "Segoe UI")
    MainGui.AddText("x" xIn " y" y " w200 c" THEME["error"] " BackgroundTrans", "Донат")
    y += 40
    
    MainGui.SetFont("s9", "Segoe UI")
    MainGui.AddText("x" xIn " y" y " w200 h40 c" THEME["textDim"] " BackgroundTrans", "Поддержите разработку копеечкой:")
    y += 50
    
    MainGui.SetFont("s10 bold", "Segoe UI")
    MainGui.AddLink("x" xIn " y" (y+5) " w180 c" THEME["accent"] " Background" THEME["card"], '<a href="https://www.donationalerts.com/r/maxon3r">DonationAlerts</a>')
    
    
    ; --- ПОДВАЛ ---
    y := 675
    MainGui.AddText("x20 y" y " w920 h1 Background" THEME["border"], "")
    
    SwitchHelpTab("Overlay")

    ; ==============================================================================
    ; СОВРЕМЕННАЯ ПАНЕЛЬ НАВИГАЦИИ (плоские вкладки + плавный индикатор)
    ; Никаких эмодзи (в GDI они рендерятся чёрными силуэтами), никаких
    ; скруглённых заливок через SetWindowRgn (дают пиксельные края).
    ; Только текст на прозрачном фоне и тонкая акцентная полоска-индикатор:
    ;   активная вкладка — акцентный текст + жирный, под ней полоска
    ;   индикатора, которая ПЛАВНО скользит к новой вкладке (ease-out)
    ;   неактивная — приглушённый текст, при наведении светлеет
    ; Панель — ребёнок окна (создаётся после tabs.UseTab()), поверх всего.
    ; ==============================================================================
    tabs.UseTab()   ; сброс: следующие контролы добавляются в окно, а не во вкладку
    MainGui.AddText("x0 y48 w960 h42 Background" THEME["bgLight"], "")
    MainGui.AddText("x0 y89 w960 h1 Background" THEME["border"], "")

    global NavItems := []
    global NavActive := 1
    tabs.Choose(1)
    navLabels := ["Обзор", "Бинды", "Настройки", "Статистика", "Помощь"]
    navCellW := 184
    navCellX0 := 20
    navPadX := 14          ; отступ индикатора от краёв ячейки
    navY := 54             ; y текста вкладки
    navH := 28
    indY := 85             ; y индикатора
    indH := 3

    ; Тонкая направляющая-рельса под вкладками
    MainGui.AddText("x20 y84 w920 h1 Background" THEME["border"], "")

    ; Индикатор активной вкладки (создаём раньше текста — он под ним)
    global NavInd := Map("x", navCellX0 + navPadX, "w", navCellW - 2 * navPadX)
    global NavIndicator := MainGui.AddText("x" NavInd["x"] " y" indY " w" NavInd["w"] " h" indH " Background" THEME["accent"], "")
    global NavAnimTimer := ""
    global NavAnimData := ""

    for i, label in navLabels {
        act := (i = NavActive)
        cx := navCellX0 + (i - 1) * navCellW
        tab := NavigationTab(MainGui, cx+8, navY-2, navCellW-16, 32, label, i,
            ((idx) => (*) => NavSelect(idx))(i), act)
        NavItems.Push(Map("btn", tab, "id", i))
    }

    AnimateNavIndicator(ind, targetX, targetW, aIndY, aIndH) {
        global NavIndicator, NavAnimTimer, NavAnimData
        ; остановить предыдущую анимацию индикатора
        if NavAnimTimer
            SetTimer(NavAnimTimer, 0)
        NavAnimData := Map(
            "ind", ind, "targetX", targetX, "targetW", targetW,
            "aIndY", aIndY, "aIndH", aIndH,
            "fromX", ind["x"], "fromW", ind["w"], "step", 0
        )
        NavAnimTimer := NavAnimTick
        SetTimer(NavAnimTimer, 0)
        SetTimer(NavAnimTimer, 12)
    }

    NavAnimTick() {
        global NavIndicator, NavAnimTimer, NavAnimData
        d := NavAnimData
        d["step"]++
        t := Min(1, d["step"] / 10)
        e := 1 - (1 - t) ** 3      ; ease-out cubic — плавное скольжение
        d["ind"]["x"] := Round(d["fromX"] + (d["targetX"] - d["fromX"]) * e)
        d["ind"]["w"] := Round(d["fromW"] + (d["targetW"] - d["fromW"]) * e)
        try NavIndicator.Move(d["ind"]["x"], d["aIndY"], d["ind"]["w"], d["aIndH"])
        if t >= 1 {
            SetTimer(NavAnimTimer, 0)
            NavAnimTimer := ""
        }
    }

    NavSelect(idx) {
        global NavItems, NavActive, HoverButtons, MainGui, THEME, NavInd
        if idx = NavActive
            return
        ToolTip(, , , 1)
        ; Переключаем только страницу. MainGui не скрывается, не уничтожается
        ; и не перерисовывается принудительно — это устраняет мигание.
        tabs.Choose(idx)
        NavActive := idx
        for item in NavItems {
            act := (item["id"] = idx)
            item["btn"].SetActive(act)
        }
        ; синхронизируем hover-состояния вкладок (чтобы подсветка не залипала)
        for hb in HoverButtons {
            if IsObject(hb) && hb.HasOwnProp("isNav") && hb.isNav
                hb.isHovered := false
        }
        ; Индикатор плавно перемещается от предыдущей вкладки к новой.
        targetX := navCellX0 + (idx - 1) * navCellW + navPadX
        targetW := navCellW - 2 * navPadX
        AnimateNavIndicator(NavInd, targetX, targetW, indY, indH)
    }
}

ClearSearch(*) {
    global CurrentSearch, MainGui
    
    if !MainGui
        return
    
    CurrentSearch := ""
    MainGui["BindSearch"].Value := ""
    RefreshBindList()
}


; ═══════════════════════════════════════════════════════════════════════════════
; ОБРАБОТЧИКИ LISTVIEW
; ═══════════════════════════════════════════════════════════════════════════════
AutoFillSmart(*) {
    global MainGui, STATE
    
    foundNick := ""
    
    ; СПОСОБ 1: Читаем параметры запуска процесса (Самый точный для текущей игры)
    try {
        if ProcessExist("gta_sa.exe") {
            ; Магия WMI: получаем командную строку процесса
            wmi := ComObjGet("winmgmts:")
            query := wmi.ExecQuery("Select CommandLine from Win32_Process Where Name = 'gta_sa.exe'")
            
            for proc in query {
                cmdLine := proc.CommandLine
                ; Ищем параметр -n (никнейм)
                if RegExMatch(cmdLine, "i)-n\s+([a-zA-Z0-9_]+)", &match) {
                    foundNick := match[1]
                    break ; Нашли - выходим
                }
            }
        }
    }
    
    ; СПОСОБ 2: Если игра не запущена или WMI не сработал -> читаем Реестр (Резерв)
    if (foundNick = "") {
        try {
            foundNick := RegRead("HKEY_CURRENT_USER\Software\SAMP", "PlayerName")
        }
    }
    
    ; Если совсем ничего не нашли
    if (foundNick = "") {
        ShowNotify("Не удалось определить ник (Запустите игру!)", "error")
        return
    }
    
    ; Форматируем: Max_Life -> Max Life
    cleanName := StrReplace(foundNick, "_", " ")
    
    ; Проверка: Изменилось ли имя?
    if (STATE["myName"] = cleanName) {
        ShowNotify("Ник актуален: " cleanName, "info")
        return
    }
    
    ; Применяем
    STATE["myName"] := cleanName
    try MainGui["ProfileName"].Value := cleanName
    
    CheckProfileDirty() ; Активируем кнопку сохранения
    ShowNotify("Определен ник: " cleanName, "success")
}

; ═══════════════════════════════════════════════════════════════════════════════
; ФУНКЦИИ ГЛАВНОГО ОКНА
; ═══════════════════════════════════════════════════════════════════════════════
RefreshMainGui() {
    global MainGui, STATE, CFG, STATS, THEME
    
    if !MainGui
        return
    
    try {
        MainGui["MainPatientId"].Value := STATE["patientId"]
        display := GetPatientDisplay()
        MainGui["MainPatientDisplay"].Text := display = "" ? "—" : display
        
        MainGui["ProfileName"].Value := STATE["myName"]
        MainGui["ProfileHospital"].Value := STATE["hospital"]
        MainGui["ProfileSpecialty"].Value := STATE["specialty"]
                   
        MainGui["Value_ChatKey"].Value := CFG["chatKey"]
        disp := CFG["chatKey"] = "" ? "—" : FormatHotkey(CFG["chatKey"])
        MainGui["Display_ChatKey"].Text := disp
        SetButtonVisualByControl(MainGui["Display_ChatKey"], CFG["chatKey"]="" ? THEME["textMuted"] : THEME["accent"])

        MainGui["SettingsOnlyGTA"].Value := CFG["onlyGTA"] ? 1 : 0
        MainGui["SettingsBaseDelay"].Value := CFG["baseDelay"]
        MainGui["SettingsAfterChat"].Value := CFG["afterChatDelay"]
        MainGui["SettingsAfterEnter"].Value := CFG["afterEnterDelay"]
        MainGui["SettingsJitter"].Value := CFG["jitter"]
        
        MainGui["SettingsOverlayOpacity"].Value := CFG["overlayOpacity"]
        MainGui["OpacityDisplay"].Text := CFG["overlayOpacity"]
        MainGui["SettingsConfirmDelete"].Value := EditorConfirmDelete ? 1 : 0
        
        MainGui["SettingsNotifySms"].Value := CFG["notifySms"] ? 1 : 0
        MainGui["SettingsNotifyMention"].Value := CFG["notifyMention"] ? 1 : 0
        MainGui["SettingsNotifyKeywords"].Value := CFG["notifyKeywords"] ? 1 : 0
        
        ; --- ИНИЦИАЛИЗАЦИЯ КНОПОК ID ---
        SetIdFormatGUI(CFG["patientFormat"])
        ; -------------------------------
        
        UpdateStatsDisplay()
        UpdateAutoSaveStatus()
    }
}

UpdateStatsDisplay() {
    global MainGui, STATS
    
    if !MainGui
        return
    
    try {
        ; Обновляем текст в контролах.
        ; Имена контролов совпадают с ключами в массиве STATS + префикс "Stat"
        ; Например: STATS["patientsHealed"] -> Control "StatPatientsHealed"
        
        MainGui["StatPatientsHealed"].Text := STATS["patientsHealed"]
        MainGui["StatOperations"].Text := STATS["operationsDone"]
        MainGui["StatTotalSent"].Text := STATS["totalSent"]
        
        MainGui["StatInjections"].Text := STATS["injectionsGiven"]
        MainGui["StatMedChecks"].Text := STATS["medChecks"]
        MainGui["StatPills"].Text := STATS["pillsGiven"]
        MainGui["StatVaccines"].Text := STATS["vaccinesGiven"]
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; ФУНКЦИЯ МОМЕНТАЛЬНОГО СОХРАНЕНИЯ СТАТИСТИКИ
; ═══════════════════════════════════════════════════════════════════════════════
IncrementAndSave(statKey) {
    global STATS, CONFIG_FILE
    
    ; 1. Увеличиваем значение в памяти
    if STATS.Has(statKey)
        STATS[statKey]++
    
    ; 2. Сразу обновляем интерфейс
    UpdateStatsDisplay()
    
    ; 3. Сразу пишем в файл (чтобы не потерять при вылете)
    try {
        IniWrite(STATS[statKey], CONFIG_FILE, "Stats", statKey)
    }
}

ResetStats(*) {
    global STATS
    
    result := MsgBox("Сбросить всю статистику?", "Подтверждение", "YesNo Icon!")
    if result = "Yes" {
        STATS["totalSent"] := 0
        STATS["patientsHealed"] := 0
        STATS["pillsGiven"] := 0
        STATS["injectionsGiven"] := 0
        STATS["operationsDone"] := 0
        STATS["medChecks"] := 0
        STATS["vaccinesGiven"] := 0
        STATS["sessionStart"] := A_Now
        
        UpdateStatsDisplay()
        UpdateOverlayData()
        ShowNotify("Статистика сброшена", "success")
    }
}

UpdateSidebarState() {
    global MainGui
    try {
        ; Проверяем, выбрана ли строка (Row > 0)
        hasSelection := MainGui["BindList"].GetNext() > 0
        ToggleSidebarButtons(hasSelection)
    }
}

ToggleSidebarButtons(isEnabled) {
    global MainGui, HoverButtons, THEME
    
    if !MainGui || !IsObject(HoverButtons)
        return
    
    mainHwnd := MainGui.Hwnd
    
    for btn in HoverButtons {
        if !IsObject(btn) || !btn.HasOwnProp("ctrl") || !IsObject(btn.ctrl)
            continue
            
        try { 
            if btn.parent.Hwnd != mainHwnd 
                continue 
        } catch { 
            continue 
        }

        text := btn.ctrl.Text
        
        if !(InStr(text, "Изменить") || InStr(text, "Копировать") || InStr(text, "Задать") || InStr(text, "Удалить"))
            continue
        
        btn.isClickable := isEnabled
        
        try {
            if isEnabled {
                ; ВКЛЮЧЕНО: Возвращаем красивые цвета
                style := "default"
                
                if InStr(text, "Изменить")
                    style := "info"      ; Синий
                else if InStr(text, "Копировать")
                    style := "info"      ; Синий
                else if InStr(text, "Задать")
                    style := "info"   ; Желтый (Охра)
                else if InStr(text, "Удалить")
                    style := "danger"    ; Красный
                colors := btn.GetColors(style)
                try btn.SetVisual(colors.bg, colors.text, colors.hover)
                
            } else {
                ; ВЫКЛЮЧЕНО: приглушённая карточка в общей дизайн-системе
                try btn.SetEnabledStyle(false)
            }
        }
    }
}

MainSetPatient(*) {
    global MainGui, STATE
    
    id := Trim(MainGui["MainPatientId"].Value)
    
    if id = "" {
        ShowNotify("Введите ID", "warning")
        return
    }
    
    if !RegExMatch(id, "^\d{1,5}$") {
        ShowNotify("ID должен быть числом 1-5 цифр!", "error")
        return
    }
    
    STATE["patientId"] := id
    MainGui["MainPatientDisplay"].Text := GetPatientDisplay()
    UpdateOverlayData()
    ShowNotify("ID установлен: " id, "success")
}

MainClearPatient(*) {
    global MainGui, STATE
    STATE["patientId"] := ""
    MainGui["MainPatientId"].Value := ""
    MainGui["MainPatientDisplay"].Text := "—"
    UpdateOverlayData()
    ShowNotify("ID очищен", "success")
}

ApplyProfile(*) {
    global MainGui, STATE, CFG, CONFIG_FILE, g_BtnSaveProfile
    
    STATE["myName"] := Trim(MainGui["ProfileName"].Value)
    STATE["hospital"] := Trim(MainGui["ProfileHospital"].Value)
    STATE["specialty"] := Trim(MainGui["ProfileSpecialty"].Value)
   
    try {
        IniWrite(STATE["myName"], CONFIG_FILE, "Settings", "myName")
        IniWrite(STATE["hospital"], CONFIG_FILE, "Profile", "hospital")
        IniWrite(STATE["specialty"], CONFIG_FILE, "Profile", "specialty")
    }
    
    ; === ОТПРАВЛЯЕМ СТАТИСТИКУ В ТЕЛЕГРАМ ===
    SendLaunchStats() 
    ; ========================================
    
    MarkUnsaved()
    ShowNotify("✅ Профиль сохранён: " STATE["myName"], "success")
    
    if g_BtnSaveProfile
        UpdateButtonState(g_BtnSaveProfile, false, "success")
}

ShowMainGui() {
    global MainGui
    
    if !MainGui
        BuildMainGui()
    
    RefreshMainGui()
    RefreshBindList()

    MainGui.Show("w960 h760")
    ; Без fade-in: повторный показ не должен мигать и перерисовывать окно.
    
    try {
        lv := MainGui["BindList"]
        style := DllCall("GetWindowLong", "Ptr", lv.Hwnd, "Int", -16, "Int")
        DllCall("SetWindowLong", "Ptr", lv.Hwnd, "Int", -16, "Int", style & ~0x100000)
        DllCall("ShowScrollBar", "Ptr", lv.Hwnd, "Int", 0, "Int", 0) 
    }
}

; Обновляет подпись статуса автосохранения в заголовке окна
UpdateAutoSaveStatus() {
    global MainGui, CFG, STATE, THEME
    if !MainGui
        return
    try {
        if !CFG["autoSave"] {
            MainGui["AutoSaveStatus"].Text := "Автосохранение: выкл"
            MainGui["AutoSaveStatus"].Opt("c" THEME["textMuted"])
            return
        }
        t := STATE["lastAutoSave"] != "" ? " • " FormatTime(STATE["lastAutoSave"], "HH:mm:ss") : ""
        MainGui["AutoSaveStatus"].Text := "Автосохранение: вкл" t
        MainGui["AutoSaveStatus"].Opt("c" THEME["success"])
    }
}

UpdateAppClock() {
    global MainGui
    try {
        if MainGui {
            MainGui["RealTimeClock"].Text := FormatTime(A_Now, "HH:mm:ss")
        }
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; ОТПРАВКА СООБЩЕНИЙ
; ═══════════════════════════════════════════════════════════════════════════════
