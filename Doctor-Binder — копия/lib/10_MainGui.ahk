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
    global g_SystemStatus, g_ProfileStatus, g_PatientStatus, g_SaveStatus, g_PatientGlow
    global GlobalUnsavedChanges, EditorConfirmDelete
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

    ; ══════════════════════════════════════════════════════════════════════════
    ; 2. ВЕРХНЯЯ ПАНЕЛЬ (TOP BAR)
    ; Слева — марка приложения, справа — состояние системы и автосохранения.
    ; Всё содержимое страниц позже сдвигается вправо, под sidebar.
    ; ══════════════════════════════════════════════════════════════════════════
    SIDEBAR_W := 240
    TOPBAR_H := 56
    WIN_W := 1200
    WIN_H := 736
    PAGE_DY := -28          ; страницы поднимаются под верхнюю панель

    TitleBar := MainGui.AddText("x0 y0 w" WIN_W " h" TOPBAR_H " Background" THEME["surface"], "")
    MainGui.AddText("x0 y" (TOPBAR_H - 1) " w" WIN_W " h1 Background" THEME["border"], "")

    brandGlow := MainGui.AddText("x20 y12 w32 h32 Background" BlendHex(THEME["surface"], THEME["accent"], 0.16), "")
    RoundCorners(brandGlow, 32, 32, THEME["radiusSm"] + 2)
    brandMark := MainGui.AddText("x21 y13 w30 h30 Center 0x200 Background" THEME["accentSoft"] " c" THEME["accent"], "✚")
    brandMark.SetFont("s12", "Segoe UI Symbol")
    RoundCorners(brandMark, 30, 30, THEME["radiusSm"] + 1)

    MainGui.SetFont("s12 bold", THEME["fontFamily"])
    MainGui.AddText("x62 y10 w360 h22 c" THEME["textTitle"] " BackgroundTrans", "Doctor Binder")
    MainGui.SetFont("s7 norm", THEME["fontFamily"])
    MainGui.AddText("x63 y32 w360 h14 c" THEME["textMuted"] " BackgroundTrans", "Медицинская консоль  ·  v" VERSION)

    ; Состояние системы — маленькая точка с очень мягким зелёным свечением
    g_SystemStatus := StatusDot(MainGui, WIN_W - 320, 15, "Система готова", THEME["success"], THEME["surface"], 8, 180, 8)
    MainGui.SetFont("s7 norm", THEME["fontFamily"])
    MainGui.AddText("x" (WIN_W - 302) " y33 w180 h14 c" THEME["textMuted"] " BackgroundTrans vAutoSaveStatus",
        (CFG["autoSave"] ? "АВТОСОХРАНЕНИЕ ВКЛ" : "АВТОСОХРАНЕНИЕ ВЫКЛ"))

    CloseBtn := CreateStyledButton(MainGui, WIN_W - 48, 12, 32, 32, "×", (*) => MainGui.Hide(), "icon")
    CloseBtn.SetBackdrop(THEME["surface"])
    try CloseBtn.ctrl.SetFont("s12 norm", "Segoe UI")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, MainGui.Hwnd))

    ; Запоминаем контролы верхней панели: их сдвигать не нужно.
    topBarHwnds := Map()
    for hwnd, ctrl in MainGui
        topBarHwnds[hwnd] := true

    ; === 3. СТРАНИЦЫ ===
    ; Один стабильный Tab2 используется только как менеджер видимости страниц.
    ; Контент страниц верстается в локальной сетке 20..940 и затем целиком
    ; сдвигается в рабочую область справа от боковой навигации.
    tabs := MainGui.AddTab2("x-2000 y-2000 w940 h700 -TabStop", ["Главная", "Бинды", "Настройки", "Статистика", "Справка"])
    tabs.Choose(1)

    ; ==============================================================================
    ; ЗАГОЛОВОК СТРАНИЦЫ (единый компонент для разделов)
    ; ==============================================================================
    AddModernHeader(y, icon, iconColor, title, subtitle, chip := "", chipColor := "") {
        if chipColor = ""
            chipColor := THEME["textDim"]
        tit := MainGui.AddText("x20 y" (y + 2) " w520 h26 c" THEME["textTitle"] " BackgroundTrans", title)
        tit.SetFont("s15 bold", THEME["fontFamily"])
        sub := MainGui.AddText("x21 y" (y + 32) " w520 h16 c" THEME["textDim"] " BackgroundTrans", subtitle)
        sub.SetFont("s9 norm", THEME["fontFamily"])

        if chip != "" {
            ch := MainGui.AddText("x620 y" (y + 16) " w320 h16 Right BackgroundTrans c" chipColor, chip)
            ch.SetFont("s8 norm", THEME["fontFamily"])
        }
    }

    ; Спокойная карточка (совместимость со старыми вызовами).
    AddCardPanel(x, y, w, h, radius := 0, accentColor := "") {
        card := CreateCard(MainGui, x, y, w, h, radius ? Min(radius, THEME["radiusLg"]) : THEME["radiusLg"])
        return card.surface
    }

    ; ==============================================================================
    ; 1. ОБЗОР — рабочий стол врача
    ; ==============================================================================
    tabs.UseTab(1)

    MainGui.SetFont("s15 bold", THEME["fontFamily"])
    MainGui.AddText("x20 y104 w620 h28 c" THEME["textTitle"] " BackgroundTrans vDashGreeting", GetGreetingText())
    MainGui.SetFont("s9 norm", THEME["fontFamily"])
    MainGui.AddText("x21 y136 w620 h18 c" THEME["textDim"] " BackgroundTrans", "Рабочая область готова. Ниже — состояние смены.")

    ; ─────────────────── Показатели смены (реальные данные) ───────────────────
    kpiY := 176
    kpiH := 96
    kpiW := 218
    kpiGap := 16

    AddKpiCard(kx, title, valueName, value, subName, sub, valueColor) {
        CreateCard(MainGui, kx, kpiY, kpiW, kpiH, THEME["radius"])
        MainGui.SetFont("s8 norm", THEME["fontFamily"])
        MainGui.AddText("x" (kx + 16) " y" (kpiY + 14) " w" (kpiW - 32) " h16 c" THEME["textDim"] " BackgroundTrans", title)
        MainGui.SetFont("s17 bold", THEME["fontFamily"])
        MainGui.AddText("x" (kx + 15) " y" (kpiY + 34) " w" (kpiW - 30) " h30 c" valueColor " BackgroundTrans v" valueName, value)
        MainGui.SetFont("s8 norm", THEME["fontFamily"])
        MainGui.AddText("x" (kx + 16) " y" (kpiY + 68) " w" (kpiW - 32) " h16 c" THEME["textMuted"] " BackgroundTrans v" subName, sub)
    }

    CountBinds(&bindsTotal, &bindsActive)
    AddKpiCard(20, "Текущий пациент", "KpiPatient",
        STATE["patientId"] = "" ? "—" : STATE["patientId"], "KpiPatientSub",
        STATE["patientId"] = "" ? "сессия не начата" : "сессия активна",
        STATE["patientId"] = "" ? THEME["textMuted"] : THEME["accent"])
    AddKpiCard(254, "Биндов в наборе", "KpiBinds", bindsTotal, "KpiBindsSub",
        "активных: " bindsActive, THEME["text"])
    AddKpiCard(488, "Отправлено строк", "KpiSent", STATS["totalSent"], "KpiSentSub",
        "за текущую сессию", THEME["text"])
    AddKpiCard(722, "Автосохранение", "KpiSave", CFG["autoSave"] ? "Вкл" : "Выкл", "KpiSaveSub",
        "интервал " CFG["autoSaveInterval"] " сек", CFG["autoSave"] ? THEME["success"] : THEME["textMuted"])

    ; ───────────────────────── Личное дело (левый блок) ───────────────────────
    profY := 292
    profH := 250
    CreateCard(MainGui, 20, profY, 596, profH)
    CreateCardHeader(MainGui, 20, profY, 596, "Личное дело", "профиль врача", 20)

    colA := 40
    colB := 328
    colW := 268

    CreateFieldLabel(MainGui, colA, profY + 58, colW, "Имя Фамилия", THEME["textDim"])
    inpName := CreateInput(MainGui, colA, profY + 76, colW - 58, THEME["inputH"], "vProfileName", STATE["myName"], 10)
    inpName.ctrl.OnEvent("Change", (*) => CheckProfileDirty())
    btnAuto := CreateStyledButton(MainGui, colA + colW - 50, profY + 76, 50, THEME["inputH"], "Авто",
        (*) => AutoFillSmart(), "default", "Определить ник из игры")
    btnAuto.SetBackdrop(THEME["card"])
    btnAuto.ctrl.SetFont("s8 norm", THEME["fontFamily"])

    CreateFieldLabel(MainGui, colB, profY + 58, colW, "Больница", THEME["textDim"])
    inpHospital := CreateInput(MainGui, colB, profY + 76, colW, THEME["inputH"], "vProfileHospital", STATE["hospital"], 10)
    inpHospital.ctrl.OnEvent("Change", (*) => CheckProfileDirty())

    CreateFieldLabel(MainGui, colA, profY + 126, colW, "Специальность", THEME["textDim"])
    inpSpecialty := CreateInput(MainGui, colA, profY + 144, colW, THEME["inputH"], "vProfileSpecialty", STATE["specialty"], 10)
    inpSpecialty.ctrl.OnEvent("Change", (*) => CheckProfileDirty())

    g_BtnSaveProfile := CreateStyledButton(MainGui, colB, profY + 144, colW, THEME["inputH"],
        "Сохранить профиль", (*) => ApplyProfile(), "primary", "Сохранить данные врача")
    g_BtnSaveProfile.SetBackdrop(THEME["card"])
    UpdateButtonState(g_BtnSaveProfile, false)

    g_ProfileStatus := StatusDot(MainGui, colA, profY + 200, "Профиль сохранён", THEME["success"], THEME["card"], 8, 300, 8)
    MainGui.SetFont("s8 norm", THEME["fontFamily"])
    MainGui.AddText("x" colB " y" (profY + 197) " w" colW " h16 Right c" THEME["textMuted"] " BackgroundTrans",
        "подставляется как {MY}, {HOSPITAL}, {SPECIALTY}")

    ; ──────────────────────── Текущий пациент (правый блок) ───────────────────
    patX := 632
    patW := 308
    CreateCard(MainGui, patX, profY, patW, profH)
    g_PatientGlow := CardGlow(MainGui, patX, profY, patW, profH, THEME["accent"], THEME["bg"])
    CreateCardHeader(MainGui, patX, profY, patW, "Текущий пациент", "", 20)

    patIn := patX + 20
    patW2 := patW - 40
    CreateFieldLabel(MainGui, patIn, profY + 58, patW2, "ID ПАЦИЕНТА")
    inpPatient := CreateInput(MainGui, patIn, profY + 76, patW2, 44, "vMainPatientId Center", STATE["patientId"], 14,
        THEME["card"], THEME["accent"])
    inpPatient.SetFont("s14 bold", THEME["fontMono"])

    btnW := (patW2 - 6) // 2
    CreateStyledButton(MainGui, patIn, profY + 130, btnW, 34, "Принять", (*) => MainSetPatient(), "primary",
        "Активировать сессию пациента").SetBackdrop(THEME["card"])
    CreateStyledButton(MainGui, patIn + btnW + 6, profY + 130, btnW, 34, "Сброс", (*) => MainClearPatient(), "default",
        "Очистить ID пациента").SetBackdrop(THEME["card"])

    g_PatientStatus := StatusDot(MainGui, patIn, profY + 184, "Ожидание пациента", THEME["textDim"], THEME["card"], 8, patW2 - 20, 8)
    MainGui.SetFont("s8 norm", THEME["fontFamily"])
    MainGui.AddText("x" patIn " y" (profY + 204) " w" patW2 " h16 c" THEME["textMuted"] " BackgroundTrans vPatientStatusHint",
        "Введите ID пациента для активации сессии")

    MainGui.SetFont("s8 norm", THEME["fontFamily"])
    MainGui.AddText("x" patIn " y" (profY + 226) " w100 h16 c" THEME["textMuted"] " BackgroundTrans", "В чате")
    MainGui.SetFont("s9 bold", THEME["fontMono"])
    MainGui.AddText("x" (patIn + 100) " y" (profY + 225) " w" (patW2 - 100) " h16 Right c" THEME["textDim"]
        " BackgroundTrans vMainPatientDisplay", GetPatientDisplay() = "" ? "—" : GetPatientDisplay())

    ; ───────────────────────── Быстрые действия (низ слева) ───────────────────
    actY := 558
    actH := 170
    CreateCard(MainGui, 20, actY, 596, actH)
    CreateCardHeader(MainGui, 20, actY, 596, "Быстрые действия", "", 20)

    quickRows := [
        [colA, actY + 56,  "Оверлей",            "→", (*) => ToggleOverlay(),      "Показать/скрыть внутриигровой оверлей"],
        [colA, actY + 100, "Обновить бинды",     "↻", (*) => RegisterAllHotkeys(), "Перерегистрировать горячие клавиши биндов"],
        [colB, actY + 56,  "Загрузить профиль",  "↓", (*) => LoadProfileDialog(),  "Импорт профиля из файла .ini или .aci"],
        [colB, actY + 100, "Сохранить профиль",  "↑", (*) => SaveProfileDialog(),  "Экспорт биндов в отдельный файл .ini"]
    ]
    for row in quickRows {
        qb := CreateStyledButton(MainGui, row[1], row[2], colW, 36, row[3], row[5], "default", row[6])
        qb.SetBackdrop(THEME["card"])
        qb.SetLayout("left", row[4])
        qb.ctrl.SetFont("s9 norm", THEME["fontFamily"])
    }

    ; ─────────────────────── Горячие клавиши (низ справа) ─────────────────────
    CreateCard(MainGui, patX, actY, patW, actH)
    CreateCardHeader(MainGui, patX, actY, patW, "Горячие клавиши", "", 20)

    AddHotkeyRow(rowY, label, value) {
        MainGui.SetFont("s8 norm", THEME["fontFamily"])
        MainGui.AddText("x" patIn " y" rowY " w160 h16 c" THEME["textDim"] " BackgroundTrans", label)
        MainGui.SetFont("s8 bold", THEME["fontMono"])
        MainGui.AddText("x" (patIn + patW2 - 108) " y" rowY " w108 h16 Right c" THEME["textMuted"] " BackgroundTrans",
            value = "" ? "—" : FormatHotkey(value))
    }

    AddHotkeyRow(actY + 58, "Меню биндера", CFG["hotkeyMainGui"])
    AddHotkeyRow(actY + 82, "Оверлей", CFG["hotkeyOverlay"])
    AddHotkeyRow(actY + 106, "Остановить отправку", CFG["hotkeyStopSending"])
    AddHotkeyRow(actY + 130, "Ответ на СМС", CFG["hotkeyReplySms"])

    ; ==============================================================================
    ; 2. БИНДЫ (MODERN MANAGER LAYOUT)
    ; ==============================================================================
    tabs.UseTab(2)
    
    yHead := 104
    
    ; --- ШАПКА (современная) ---
    AddModernHeader(yHead, "≡", THEME["accent"], "Бинды",
        "Управление и настройка", "Слотов: " Constants.MAX_SLOTS)
    
    
    ; --- ОСНОВНАЯ РАБОЧАЯ ОБЛАСТЬ ---
    yStart := 210
    
    ; ======================= ЛЕВАЯ КОЛОНКА: СПИСОК (ШИРОКАЯ) =======================
    wList := 660
    
    ; Карточка списка
    cardList := AddCardPanel(20, yStart, wList, 500, 14, THEME["accent"])
    
    ; --- ПАНЕЛЬ ИНСТРУМЕНТОВ (TOOLBAR) ---
    yTool := yStart + 15
    xTool := 40
    
    CreateFieldLabel(MainGui, xTool, yTool - 4, 150, "Поиск")

    ; Поле поиска (премиальный input, без белой рамки Windows)
    inpSearch := CreateInput(MainGui, xTool, yTool + 12, 300, THEME["inputH"], "vBindSearch", "", 10)
    inpSearch.ctrl.OnEvent("Change", OnSearchChange)

    ; Кнопка очистки
    CreateClearBtn(MainGui, xTool + 308, yTool + 12, THEME["inputH"], (*) => ClearSearch()).SetBackdrop(THEME["card"])

    ; Фильтр (справа)
    CreateFieldLabel(MainGui, xTool + 360, yTool - 4, 100, "Фильтр")

    global btnFilterDisplay
    btnFilterDisplay := CreateStyledButton(MainGui, xTool + 360, yTool + 12, 250, THEME["inputH"], "Все бинды",
        (*) => ShowModernFilterMenu(), "default", "Фильтрация списка")
    btnFilterDisplay.SetBackdrop(THEME["card"])
    btnFilterDisplay.SetLayout("left", "▾")

    ; Разделитель под тулбаром
    MainGui.AddText("x40 y" (yTool + 60) " w" (wList - 40) " h1 Background" THEME["border"], "")
    
    ; --- ЗАГОЛОВОК ТАБЛИЦЫ (Кастомный) ---
    yList := yTool + 72
    hList := 380
    
    ; Фон заголовка таблицы
    MainGui.AddText("x30 y" yList " w" (wList-20) " h26 Background" THEME["bgElevated"], "")
    MainGui.AddText("x30 y" (yList+26) " w" (wList-20) " h1 Background" THEME["border"], "")
    
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
    MainGui.SetFont("s8 bold", THEME["fontFamily"])
    MainGui.AddText("x" (x1+4) " y" (yList+5) " w" col1 " c" THEME["textMuted"] " BackgroundTrans", "№")
    MainGui.AddText("x" (x2+4) " y" (yList+5) " w" col2 " c" THEME["textMuted"] " BackgroundTrans", "Название")
    MainGui.AddText("x" (x3+4) " y" (yList+5) " w" col3 " c" THEME["textMuted"] " BackgroundTrans", "Категория")
    MainGui.AddText("x" (x4+4) " y" (yList+5) " w" col4 " c" THEME["textMuted"] " BackgroundTrans", "Клавиша")
    MainGui.AddText("x" (x5+2) " y" (yList+5) " w" col5 " c" THEME["textMuted"] " BackgroundTrans", "Стр")
    MainGui.AddText("x" (x6+2) " y" (yList+5) " w" col6 " c" THEME["textMuted"] " BackgroundTrans", "Статус")
    
    ; ListView
    lvTop := yList + 28
    lvH := hList - 28
    
    MainGui.SetFont("s9", THEME["fontFamily"])
    lv := MainGui.AddListView("x30 y" lvTop " w" (wList-20) " h" lvH 
        " Background" THEME["card"] " c" THEME["textBody"] 
        " vBindList -Hdr -Grid -Multi -HScroll +LV0x10000", 
        ["№", "Название", "Категория", "Клавиша", "Стр", "Статус"])
    
    SetDarkControl(lv)
    SetListViewRowHeight(lv, 28)
    
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
    MainGui.SetFont("s9", THEME["fontFamily"])
    MainGui.AddText("x40 y" (yList+hList+10) " w200 c" THEME["textMuted"] " vListStatusLabel BackgroundTrans", "Загрузка списка...")


    ; ======================= ПРАВАЯ КОЛОНКА: ДЕЙСТВИЯ =======================
    xRight := 700
    wRight := 240
    
    ; Карточка действий
    cardActions := AddCardPanel(xRight, yStart, wRight, 500, 14, THEME["accent"])
    
    CreateCardHeader(MainGui, xRight, yStart, wRight, "Действия", "04", 20)
    
    ySide := yStart + 60
    xSide := xRight + 20
    wSide := 200
    
    ; Primary action раздела
    btnCreate := CreateStyledButton(MainGui, xSide, ySide, wSide, 42, "Создать бинд", (*) => CreateNewBind(), "primary")
    btnCreate.SetBackdrop(THEME["card"])
    btnCreate.SetLayout("left", "+")

    ySide += 62
    CreateFieldLabel(MainGui, xSide, ySide, wSide, "Выбранный элемент")

    ySide += 22
    gap := 10
    btnH := 40

    ; Единый спокойный стиль: тёмная поверхность + тонкая рамка
    CreateStyledButton(MainGui, xSide, ySide, wSide, btnH, "Изменить", (*) => EditSelectedBind(), "default").SetBackdrop(THEME["card"])
    ySide += btnH + gap
    CreateStyledButton(MainGui, xSide, ySide, wSide, btnH, "Копировать", (*) => DuplicateBind(), "default").SetBackdrop(THEME["card"])
    ySide += btnH + gap
    CreateStyledButton(MainGui, xSide, ySide, wSide, btnH, "Задать клавишу", (*) => ChangeBindHotkey(), "default").SetBackdrop(THEME["card"])
    ySide += btnH + gap
    CreateStyledButton(MainGui, xSide, ySide, wSide, btnH, "Удалить", (*) => DeleteSelectedBind(), "default").SetBackdrop(THEME["card"])

    ySide += btnH + 30
    MainGui.AddText("x" xSide " y" (ySide-16) " w" wSide " h1 Background" THEME["border"], "")
    CreateStyledButton(MainGui, xSide, ySide, wSide, btnH, "Отменить действие", (*) => Undo(), "default").SetBackdrop(THEME["card"])

    ; ==============================================================================
    ; 3. НАСТРОЙКИ (FINAL POLISHED LAYOUT)
    ; ==============================================================================
    tabs.UseTab(3)
    
    yHead := 104
    
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

    
    ; Пункт бокового меню: спокойная строка, cyan только у активной
    CreateSideBtn(yPos, text, id) {
        w := wMenu - 24
        btn := CreateStyledButton(MainGui, xMenu+12, yPos+4, w, 40, text, (*) => SwitchSettingTab(id), "default")
        btn.id := id
        btn.SetBackdrop(THEME["card"])
        btn.SetLayout("left", "")
        btn.SetVisual(THEME["card"], THEME["textDim"], THEME["bgHover"], THEME["card"])
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
                ; Подраздел страницы: без cyan-рамки и свечения — этот приём
                ; закреплён за главной навигацией слева.
                btn.SetVisual(THEME["bgElevated"], THEME["accent"], THEME["bgElevated"], THEME["bgElevated"])
                btn.SetLayout("left", "›")
                btn.ctrl.SetFont("s9 bold", THEME["fontFamily"])
            } else {
                btn.SetVisual(THEME["card"], THEME["textDim"], THEME["bgHover"], THEME["card"])
                btn.SetLayout("left", "")
                btn.ctrl.SetFont("s9 norm", THEME["fontFamily"])
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
        btn := CreateStyledButton(MainGui, xPos, yPos, 100, 34, label, callback, "default")
        btn.ctrl.Name := name
        btn.SetBackdrop(THEME["card"])
        btn.SetVisual(THEME["bgElevated"], THEME["textDim"], THEME["bgHover"], THEME["border"])
        return btn
    }
    
    ; ======================= 1. ОСНОВНЫЕ =======================
    y := yStart + 20
    x := xContent + 30
    
    ; ЗАГОЛОВОК И ОПИСАНИЕ
    MainGui.SetFont("s12 bold", THEME["fontFamily"])
    AddToGroup("General", MainGui.AddText("x" x " y" y " w400 c" THEME["textTitle"] " BackgroundTrans", "Основные параметры"))
    MainGui.SetFont("s9", THEME["fontFamily"])
    AddToGroup("General", MainGui.AddText("x" x " y" (y+30) " w580 c" THEME["textDim"] " BackgroundTrans", "Настройте базовое поведение биндера, клавишу активации чата и формат отображения ID пациентов."))
    MainGui.SetFont("s10 norm", THEME["fontFamily"])
    
    y += 70
    AddToGroup("General", MainGui.AddText("x" x " y" (y+3) " w150 c" THEME["textDim"] " BackgroundTrans", "Клавиша чата (F6/T):"))
    val := CFG["chatKey"]
    disp := val = "" ? "—" : FormatHotkey(val)
    hkChatBtn := CreateStyledButton(MainGui, x+160, y, 140, THEME["btnHSm"], disp, (*) => StartHotkeyCapture("ChatKey"), "default")
    hkChatBtn.ctrl.Name := "Display_ChatKey"
    hkChatBtn.SetBackdrop(THEME["card"])
    hkChatBtn.SetVisual(THEME["field"], val="" ? THEME["textMuted"] : THEME["accent"], THEME["bgHover"], THEME["fieldBorder"])
    hkChatBtn.ctrl.SetFont("s9 bold", THEME["fontMono"])
    hkChat := hkChatBtn.ctrl
    AddToGroup("General", hkChatBtn)
    MainGui.AddEdit("x0 y0 w0 h0 Hidden vValue_ChatKey", val) 
    ; Делаем чуть меньше и квадратным (30x30)
    btnCl := CreateClearBtn(MainGui, x+310, y, THEME["btnHSm"], (*) => ClearHotkey("ChatKey"))
    btnCl.SetBackdrop(THEME["card"])
    AddToGroup("General", btnCl) 
    
    y += 50
    AddToGroup("General", MainGui.AddText("x" x " y" (y-5) " w400 c" THEME["textDim"] " BackgroundTrans", "Формат ID пациента (как вставлять в чат):"))
    btnW := 100
    btnH := 35
    MainGui.SetFont("s9 bold", THEME["fontFamily"])
    
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
    MainGui.SetFont("s10 norm", THEME["fontFamily"])
    c1 := MainGui.AddCheckbox("x" x " y" y " vSettingsOnlyGTA c" THEME["text"] " Background" THEME["card"] " Checked" (CFG["onlyGTA"] ? 1 : 0), " Работа только при активном окне GTA")
    AddToGroup("General", c1)
    StyleCheckbox(c1)
    c1.OnEvent("Click", (*) => CheckSettingsDirty())
    
    ; ======================= 2. УВЕДОМЛЕНИЯ =======================
    y := yStart + 20
    MainGui.SetFont("s12 bold", THEME["fontFamily"])
    AddToGroup("Notify", MainGui.AddText("x" x " y" y " w400 c" THEME["textTitle"] " BackgroundTrans", "Система уведомлений"))
    MainGui.SetFont("s9", THEME["fontFamily"])
    AddToGroup("Notify", MainGui.AddText("x" x " y" (y+30) " w580 c" THEME["textDim"] " BackgroundTrans", "Управляйте звуковыми и визуальными оповещениями. Полезно, если игра свернута."))
    MainGui.SetFont("s10 norm", THEME["fontFamily"])
    
    y += 70
    c2 := MainGui.AddCheckbox("x" x " y" y " vSettingsNotifySms c" THEME["text"] " Background" THEME["card"] " Checked" (CFG["notifySms"] ? 1 : 0), " Всплывающее SMS (если игра свернута)")
    AddToGroup("Notify", c2)
    StyleCheckbox(c2)
    c2.OnEvent("Click", (*) => CheckSettingsDirty())
    y += 40
    c3 := MainGui.AddCheckbox("x" x " y" y " vSettingsNotifyMention c" THEME["text"] " Background" THEME["card"] " Checked" (CFG["notifyMention"] ? 1 : 0), " Звук при упоминании вашего ника в чате")
    AddToGroup("Notify", c3)
    StyleCheckbox(c3)
    c3.OnEvent("Click", (*) => CheckSettingsDirty())
    y += 40
    c4 := MainGui.AddCheckbox("x" x " y" y " vSettingsNotifyKeywords c" THEME["text"] " Background" THEME["card"] " Checked" (CFG["notifyKeywords"] ? 1 : 0), " Реагировать на просьбы (врач, лечи, таблетку)")
    AddToGroup("Notify", c4)
    StyleCheckbox(c4)
    c4.OnEvent("Click", (*) => CheckSettingsDirty())
    y += 40
    c5 := MainGui.AddCheckbox("x" x " y" y " vSettingsConfirmDelete c" THEME["text"] " Background" THEME["card"] " Checked" (EditorConfirmDelete ? 1 : 0), " Спрашивать подтверждение при удалении строк")
    AddToGroup("Notify", c5)
    StyleCheckbox(c5)
    c5.OnEvent("Click", (*) => CheckSettingsDirty())
    
    ; ======================= 3. ТАЙМИНГИ =======================
    y := yStart + 20
    MainGui.SetFont("s12 bold", THEME["fontFamily"])
    AddToGroup("Timing", MainGui.AddText("x" x " y" y " w400 c" THEME["textTitle"] " BackgroundTrans", "Тайминги и интерфейс"))
    MainGui.SetFont("s9", THEME["fontFamily"])
    AddToGroup("Timing", MainGui.AddText("x" x " y" (y+30) " w580 c" THEME["textDim"] " BackgroundTrans", "Настройка задержек между строками для обхода анти-флуда и прозрачность оверлея."))
    MainGui.SetFont("s10 norm", THEME["fontFamily"])
    
    y += 70
    AddToGroup("Timing", MainGui.AddText("x" x " y" y " w150 c" THEME["textDim"] " BackgroundTrans", "Базовая (мс):"))
    AddToGroup("Timing", MainGui.AddText("x" (x+220) " y" y " w150 c" THEME["textDim"] " BackgroundTrans", "Разброс (Random):"))
    y += 25
    e1 := CreateInput(MainGui, x, y, 200, THEME["inputH"], "Center Number vSettingsBaseDelay", CFG["baseDelay"], 10)
    AddToGroup("Timing", e1)
    e1.ctrl.OnEvent("Change", (*) => CheckSettingsDirty())
    e2 := CreateInput(MainGui, x+220, y, 200, THEME["inputH"], "Center Number vSettingsJitter", CFG["jitter"], 10)
    AddToGroup("Timing", e2)
    e2.ctrl.OnEvent("Change", (*) => CheckSettingsDirty())
    
    y += 50
    AddToGroup("Timing", MainGui.AddText("x" x " y" y " w150 c" THEME["textDim"] " BackgroundTrans", "После чата (t):"))
    AddToGroup("Timing", MainGui.AddText("x" (x+220) " y" y " w150 c" THEME["textDim"] " BackgroundTrans", "После ввода (Enter):"))
    y += 25
    e3 := CreateInput(MainGui, x, y, 200, THEME["inputH"], "Center Number vSettingsAfterChat", CFG["afterChatDelay"], 10)
    AddToGroup("Timing", e3)
    e3.ctrl.OnEvent("Change", (*) => CheckSettingsDirty())
    e4 := CreateInput(MainGui, x+220, y, 200, THEME["inputH"], "Center Number vSettingsAfterEnter", CFG["afterEnterDelay"], 10)
    AddToGroup("Timing", e4)
    e4.ctrl.OnEvent("Change", (*) => CheckSettingsDirty())
    
    y += 50
    bFast := CreateStyledButton(MainGui, x, y, 130, 32, "Быстро", (*) => SetDelayPreset("fast"), "default")
    bFast.SetBackdrop(THEME["card"])
    AddToGroup("Timing", bFast)
    bNorm := CreateStyledButton(MainGui, x+140, y, 130, 32, "Норма", (*) => SetDelayPreset("norm"), "default")
    bNorm.SetBackdrop(THEME["card"])
    AddToGroup("Timing", bNorm)
    bSlow := CreateStyledButton(MainGui, x+280, y, 130, 32, "Full RP", (*) => SetDelayPreset("rp"), "default")
    bSlow.SetBackdrop(THEME["card"])
    AddToGroup("Timing", bSlow)
    
    y += 45
    cAutoSave := MainGui.AddCheckbox("x" x " y" y " vSettingsEditorAutoSave c" THEME["text"] " Background" THEME["card"] " Checked" (CFG["editorAutoSaveDelay"] ? 1 : 0), " Авто-сохранение задержки в редакторе (без галочки)")
    AddToGroup("Timing", cAutoSave)
    StyleCheckbox(cAutoSave)
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
    MainGui.SetFont("s12 bold", THEME["fontFamily"])
    AddToGroup("Hotkeys", MainGui.AddText("x" x " y" y " w400 c" THEME["textTitle"] " BackgroundTrans", "Глобальные клавиши"))
    
    y += 40 

    ; --- ВОТ ЭТОЙ ФУНКЦИИ НЕ ХВАТАЛО ---
    AddGroupHotkey(label, type, yPos) {
        MainGui.SetFont("s10 norm", THEME["fontFamily"])
        AddToGroup("Hotkeys", MainGui.AddText("x" x " y" (yPos+3) " w120 c" THEME["textDim"] " BackgroundTrans", label))
        
        val := CFG["hotkey" type]
        disp := val = "" ? "—" : FormatHotkey(val)
        
        ; Поле отображения клавиши
        hkBtn := CreateStyledButton(MainGui, x+130, yPos, 200, THEME["btnHSm"], disp, (*) => StartHotkeyCapture(type), "default")
        hkBtn.ctrl.Name := "Display_" type
        hkBtn.SetBackdrop(THEME["card"])
        hkBtn.SetVisual(THEME["field"], val="" ? THEME["textMuted"] : THEME["accent"], THEME["bgHover"], THEME["fieldBorder"])
        hkBtn.ctrl.SetFont("s9 bold", THEME["fontMono"])
        hk := hkBtn.ctrl
        AddToGroup("Hotkeys", hkBtn)
        
        ; Скрытое поле для хранения значения
        MainGui.AddEdit("x0 y0 w0 h0 Hidden vValue_" type, val)
        
        ; Кнопка очистки (Крестик)
        bn := CreateClearBtn(MainGui, x+340, yPos, THEME["btnHSm"], (*) => ClearHotkey(type))
        bn.SetBackdrop(THEME["card"])
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
    
    MainGui.SetFont("s10 bold", THEME["fontFamily"])
    AddToGroup("Hotkeys", MainGui.AddText("x" x " y" y " w400 c" THEME["accent"] " BackgroundTrans", "Настройка секторов меню:"))
    y += 30
    
    ; Функция ячейки радиального меню
    AddWheelCell(label, cfgKey, xPos, yPos) {
        MainGui.SetFont("s9", THEME["fontFamily"])
        AddToGroup("Hotkeys", MainGui.AddText("x" xPos " y" (yPos+4) " w60 c" THEME["textDim"] " BackgroundTrans", label))
        
        currentID := CFG[cfgKey]
        currentName := "— Пусто —"
        if (currentID > 0 && currentID <= Constants.MAX_SLOTS) {
            sName := SLOTS[currentID]["name"]
            currentName := "[" currentID "] " (StrLen(sName) > 10 ? SubStr(sName, 1, 8) ".." : sName)
        }
        
        btn := CreateStyledButton(MainGui, xPos+65, yPos-2, 145, THEME["btnHSm"], currentName, 
            ((k, b) => (*) => ShowBindSelector(k, b))(cfgKey, "btnWheel_" cfgKey), "default")

        btn.SetBackdrop(THEME["card"])
        btn.ctrl.SetFont("s8 norm", THEME["fontFamily"])
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
    MainGui.SetFont("s12 bold", THEME["fontFamily"])
    ; Заголовок
    AddToGroup("Screenshots", MainGui.AddText("x" x " y" y " w400 c" THEME["textTitle"] " BackgroundTrans", "Автоматические отчёты"))
    
    y += 30
    MainGui.SetFont("s9", THEME["fontFamily"])
    ; Описание
    AddToGroup("Screenshots", MainGui.AddText("x" x " y" y " w580 c" THEME["textDim"] " BackgroundTrans", "Биндер будет сам делать F8 при лечении и раскладывать скрины по папкам."))
    
    y += 40
    MainGui.SetFont("s11 bold", THEME["fontFamily"])
    ; Чекбокс
    cScr := MainGui.AddCheckbox("x" x " y" y " vSettingsAutoScreen c" THEME["success"] " Background" THEME["card"] " Checked" (CFG["autoScreen"] ? 1 : 0), " Включить авто-сортировку (Smart Sort)")
    AddToGroup("Screenshots", cScr)
    StyleCheckbox(cScr)
    cScr.OnEvent("Click", (*) => CheckSettingsDirty())
    
    
    y += 40
    MainGui.SetFont("s9", THEME["fontFamily"])
    AddToGroup("Screenshots", MainGui.AddText("x" x " y" y " w580 c" THEME["textDim"] " BackgroundTrans", "Создайте правила: какую фразу искать в чате и куда сохранять скриншот."))
    
    y += 25
    
    ; === 1. КРАСИВЫЙ ЗАГОЛОВОК ТАБЛИЦЫ (Как в Бинды) ===
    ; Фон заголовка
    AddToGroup("Screenshots", MainGui.AddText("x" x " y" y " w500 h26 Background" THEME["bgElevated"], ""))
    ; Линия подчеркивания
    AddToGroup("Screenshots", MainGui.AddText("x" x " y" (y+26) " w500 h1 Background" THEME["border"], ""))
    
    ; Текст колонок
    MainGui.SetFont("s8 bold", THEME["fontFamily"])
    AddToGroup("Screenshots", MainGui.AddText("x" (x+5)   " y" (y+5) " w135 c" THEME["textMuted"] " BackgroundTrans", "Название"))
    AddToGroup("Screenshots", MainGui.AddText("x" (x+145) " y" (y+5) " w175 c" THEME["textMuted"] " BackgroundTrans", "Фраза (триггер)"))
    AddToGroup("Screenshots", MainGui.AddText("x" (x+325) " y" (y+5) " w170 c" THEME["textMuted"] " BackgroundTrans", "Папка"))
    
    ; === 2. САМА ТАБЛИЦА (Без стандартного заголовка) ===
    y += 28
    MainGui.SetFont("s9", THEME["fontFamily"])
    ; Флаг -Hdr убирает стандартный заголовок, -Multi запрещает выбор нескольких, -Grid убирает сетку (для чистоты)
    lvRules := MainGui.AddListView("x" x " y" y " w500 h200 Background" THEME["card"] " c" THEME["textBody"] " vScreenRulesList -Hdr -Multi -Grid", ["Name", "Phrase", "Path"])
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
    
    bAdd := CreateStyledButton(MainGui, btnX, y, 100, 32, "Добавить", (*) => AddScreenRule(), "primary")
    bAdd.SetBackdrop(THEME["card"])
    AddToGroup("Screenshots", bAdd)

    bEdit := CreateStyledButton(MainGui, btnX, y+42, 100, 32, "Изменить", (*) => EditScreenRule(), "default")
    bEdit.SetBackdrop(THEME["card"])
    AddToGroup("Screenshots", bEdit)

    bDel := CreateStyledButton(MainGui, btnX, y+84, 100, 32, "Удалить", (*) => DeleteScreenRule(), "default")
    bDel.SetBackdrop(THEME["card"])
    AddToGroup("Screenshots", bDel)
    
    ; Заполнение данными
    RefreshScreenRulesList()    
    ; --- КНОПКИ ВНИЗУ (ВЫРОВНЕНЫ ПО ВЫСОТЕ) ---
    y := 675 ; <--- Подняли, чтобы точно влезали в h760
    MainGui.AddText("x20 y" y " w920 h1 Background" THEME["border"], "")
    y += 15
    
    CreateStyledButton(MainGui, 20, y, 150, 38, "Сброс настроек", (*) => ResetSettingsDefault(), "default").SetBackdrop(THEME["bg"])
    CreateStyledButton(MainGui, 180, y, 150, 38, "Сброс статистики", (*) => ResetStats(), "default").SetBackdrop(THEME["bg"])
    CreateStyledButton(MainGui, 340, y, 150, 38, "Удалить бинды", (*) => ClearAllBindsAction(), "danger").SetBackdrop(THEME["bg"])

    g_BtnSaveSettings := CreateStyledButton(MainGui, 700, y, 240, 38, "Сохранить изменения", (*) => ApplyAndSaveSettings(), "primary")
    g_BtnSaveSettings.SetBackdrop(THEME["bg"])
    g_BtnSaveSettings.ctrl.SetFont("s8 bold", THEME["fontFamily"])
    UpdateButtonState(g_BtnSaveSettings, false)
    
    SwitchSettingTab("General")


    ; ==============================================================================
    ; 4. СТАТИСТИКА (SIDEBAR STYLE)
    ; ==============================================================================
    tabs.UseTab(4)
    
    yHead := 104
    
    ; --- ШАПКА (современная) ---
    AddModernHeader(yHead, "▲", THEME["success"], "Статистика",
        "Анализ сессии")
    
    ; --- ЛЕВОЕ МЕНЮ ---
    yStart := 210
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
        btn := CreateStyledButton(MainGui, xMenu+12, yPos+4, w, 40, text, (*) => SwitchStatTab(id), "default")
        btn.id := id
        btn.SetBackdrop(THEME["card"])
        btn.SetLayout("left", "")
        btn.SetVisual(THEME["card"], THEME["textDim"], THEME["bgHover"], THEME["card"])
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
                ; Подраздел страницы: без cyan-рамки и свечения — этот приём
                ; закреплён за главной навигацией слева.
                btn.SetVisual(THEME["bgElevated"], THEME["accent"], THEME["bgElevated"], THEME["bgElevated"])
                btn.SetLayout("left", "›")
                btn.ctrl.SetFont("s9 bold", THEME["fontFamily"])
            } else {
                btn.SetVisual(THEME["card"], THEME["textDim"], THEME["bgHover"], THEME["card"])
                btn.SetLayout("left", "")
                btn.ctrl.SetFont("s9 norm", THEME["fontFamily"])
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
    
    ; Метрика: тонкая рамка, muted-label, крупное значение. Без цветных заливок.
    CreateDashCard(x, y, w, h, title, varName, value, color) {
        frame := MainGui.AddText("x" x " y" y " w" w " h" h " Background" THEME["border"], "")
        RoundCorners(frame, w, h, THEME["radius"])
        bg := MainGui.AddText("x" (x+1) " y" (y+1) " w" (w-2) " h" (h-2) " Background" THEME["bgElevated"], "")
        RoundCorners(bg, w-2, h-2, THEME["radius"])

        MainGui.SetFont("s" THEME["fontMeta"] " bold", THEME["fontFamily"])
        tit := MainGui.AddText("x" (x+16) " y" (y+14) " w" (w-24) " h14 c" THEME["textMuted"] " BackgroundTrans", StrUpper(title))

        MainGui.SetFont("s20 bold", THEME["fontFamily"])
        val := MainGui.AddText("x" (x+15) " y" (y+34) " w" (w-24) " h40 c" THEME["text"] " BackgroundTrans v" varName, value)

        AddToStatGroup("Dashboard", frame)
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
    MainGui.SetFont("s12 bold", THEME["fontFamily"])
    AddToStatGroup("Info", MainGui.AddText("x" x " y" y " w400 c" THEME["textTitle"] " BackgroundTrans", "Информация о сессии"))
    
    y += 60
    MainGui.SetFont("s9 norm", THEME["fontFamily"])
    AddToStatGroup("Info", MainGui.AddText("x" x " y" y " w200 c" THEME["textDim"] " BackgroundTrans", "Время запуска:"))
    MainGui.SetFont("s13 bold", THEME["fontMono"])
    AddToStatGroup("Info", MainGui.AddText("x" (x+200) " y" (y-5) " w300 c" THEME["text"] " BackgroundTrans", FormatTime(STATS["sessionStart"], "HH:mm:ss")))
    
    y += 50
    MainGui.SetFont("s9 norm", THEME["fontFamily"])
    AddToStatGroup("Info", MainGui.AddText("x" x " y" y " w200 c" THEME["textDim"] " BackgroundTrans", "Текущее время:"))
    MainGui.SetFont("s13 bold", THEME["fontMono"])
    ; Часы
    clk := MainGui.AddText("x" (x+200) " y" (y-5) " w300 c" THEME["success"] " vRealTimeClock BackgroundTrans", FormatTime(A_Now, "HH:mm:ss"))
    AddToStatGroup("Info", clk)
    
    y += 100
    MainGui.SetFont("s10 italic", THEME["fontFamily"])
    infoTxt := "Статистика автоматически сохраняется в файл конфигурации при каждом действии.`n`n" 
             . "При перезапуске скрипта, если не было сброса, статистика продолжается.`n`n"
             . "Используйте кнопку 'Сбросить всё' внизу для начала новой смены."
    AddToStatGroup("Info", MainGui.AddText("x" x " y" y " w560 h100 c" THEME["textDim"], infoTxt))
    
    
    ; --- КНОПКИ ВНИЗУ ---
    y := 675
    MainGui.AddText("x20 y" y " w920 h1 Background" THEME["border"], "")
    y += 15
    CreateStyledButton(MainGui, 760, y, 180, 38, "Сбросить всё", (*) => ResetStats(), "danger").SetBackdrop(THEME["bg"])
    CreateStyledButton(MainGui, 560, y, 180, 38, "Обновить", (*) => UpdateStatsDisplay(), "default").SetBackdrop(THEME["bg"])
    
    SwitchStatTab("Dashboard")

    ; ==============================================================================
    ; 5. СПРАВКА (FINAL LAYOUT WITH STATIC SIDEBAR)
    ; ==============================================================================
    tabs.UseTab(5)
    
    yHead := 104
    
    ; --- ШАПКА (современная) ---
    AddModernHeader(yHead, "?", THEME["accentLight"], "Справка",
        "База знаний и поддержка")
    
    yStart := 210
    
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
        btn := CreateStyledButton(MainGui, xMenu+12, yPos+4, w, 40, text, (*) => SwitchHelpTab(id), "default")
        btn.id := id
        btn.SetBackdrop(THEME["card"])
        btn.SetLayout("left", "")
        btn.SetVisual(THEME["card"], THEME["textDim"], THEME["bgHover"], THEME["card"])
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
                ; Подраздел страницы: без cyan-рамки и свечения — этот приём
                ; закреплён за главной навигацией слева.
                btn.SetVisual(THEME["bgElevated"], THEME["accent"], THEME["bgElevated"], THEME["bgElevated"])
                btn.SetLayout("left", "›")
                btn.ctrl.SetFont("s9 bold", THEME["fontFamily"])
            } else {
                btn.SetVisual(THEME["card"], THEME["textDim"], THEME["bgHover"], THEME["card"])
                btn.SetLayout("left", "")
                btn.ctrl.SetFont("s9 norm", THEME["fontFamily"])
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
    
    MainGui.SetFont("s12 bold", THEME["fontFamily"])
    AddToHelp("Overlay", MainGui.AddText("x" x " y" y " w350 c" THEME["textTitle"] " BackgroundTrans", "Управление оверлеем"))
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
    MainGui.SetFont("s12 bold", THEME["fontFamily"])
    AddToHelp("Syntax", MainGui.AddText("x" x " y" y " w350 c" THEME["textTitle"] " BackgroundTrans", "Переменные"))
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
    MainGui.SetFont("s9 italic", THEME["fontFamily"])
    AddToHelp("Syntax", MainGui.AddText("x" x " y" y " w350 c" THEME["textDim"] " BackgroundTrans", "Пример: Привет, я {MY}. Что болит, {P}?"))
    
    ; === 3. О ПРОГРАММЕ ===
    y := yStart + 20
    MainGui.SetFont("s12 bold", THEME["fontFamily"])
    AddToHelp("About", MainGui.AddText("x" x " y" y " w350 c" THEME["textTitle"] " BackgroundTrans", "О программе"))
    y += 40
    
    ; Лого-блок: плитка с крестом + крупное название биндера
    logo := MainGui.AddText("x" x " y" y " w52 h52 Center 0x200 Background" THEME["accentSoft"] " c" THEME["accent"], "✚")
    logo.SetFont("s20", "Segoe UI Symbol")
    RoundCorners(logo, 52, 52, THEME["radius"])
    AddToHelp("About", logo)
    
    MainGui.SetFont("s16 bold", THEME["fontFamily"])
    AddToHelp("About", MainGui.AddText("x" (x+66) " y" (y+6) " w280 c" THEME["textTitle"] " BackgroundTrans", "DOCTOR BINDER"))
    MainGui.SetFont("s8", THEME["fontFamily"])
    AddToHelp("About", MainGui.AddText("x" (x+67) " y" (y+34) " w280 c" THEME["textMuted"] " BackgroundTrans", "MEDICAL OPERATIONS CONSOLE  ·  v" VERSION "  ·  " AUTHOR))
    
    y += 78
    sepAbout := MainGui.AddText("x" x " y" y " w350 h1 Background" THEME["border"], "")
    AddToHelp("About", sepAbout)
    y += 20
    MainGui.SetFont("s10", THEME["fontFamily"])
    AddToHelp("About", MainGui.AddText("x" x " y" y " w350 c" THEME["textDim"] " BackgroundTrans", "Версия: " VERSION))
    y += 28
    AddToHelp("About", MainGui.AddText("x" x " y" y " w350 c" THEME["textDim"] " BackgroundTrans", "Автор: " AUTHOR))
    y += 28
    AddToHelp("About", MainGui.AddText("x" x " y" y " w350 c" THEME["textDim"] " BackgroundTrans", "Год: 2026"))
    y += 40
    MainGui.SetFont("s9 italic", THEME["fontFamily"])
    AddToHelp("About", MainGui.AddText("x" x " y" y " w350 h100 c" THEME["textDim"] " BackgroundTrans", "Разработано специально для медицинского сообщества SAMP ABS RP"))
    
    
    ; --- ПРАВАЯ ОБЛАСТЬ (КОНТАКТЫ - ВСЕГДА ВИДНЫ) ---
    xRight := xCenter + wCenter + 20
    wRight := 240
    y := yStart
    
    ; Фон правой панели
    rightPanel := AddCardPanel(xRight, y, wRight, hMenu, THEME["radiusLg"], THEME["accentLight"])
    
    y += 20
    xIn := xRight + 20
    
    MainGui.SetFont("s10 bold", THEME["fontFamily"])
    MainGui.AddText("x" xIn " y" y " w200 c" THEME["text"] " BackgroundTrans", "СВЯЗЬ")
    y += 40
    
    MainGui.SetFont("s10 norm", THEME["fontFamily"])
    MainGui.AddLink("x" xIn " y" (y+5) " w180 c" THEME["accent"] " Background" THEME["card"], '<a href="https://t.me/maxon3r">Telegram</a>')
    y += 50
    MainGui.AddLink("x" xIn " y" (y+5) " w180 c" THEME["accent"] " Background" THEME["card"], '<a href="https://vk.com/20max19">ВКонтакте</a>')
    
    y += 70
    MainGui.AddText("x" xIn " y" y " w200 h1 Background" THEME["border"], "")
    y += 20
    
    MainGui.SetFont("s10 bold", THEME["fontFamily"])
    MainGui.AddText("x" xIn " y" y " w200 c" THEME["text"] " BackgroundTrans", "ПОДДЕРЖКА")
    y += 40
    
    MainGui.SetFont("s9", THEME["fontFamily"])
    MainGui.AddText("x" xIn " y" y " w200 h40 c" THEME["textDim"] " BackgroundTrans", "Поддержите разработку копеечкой:")
    y += 50
    
    MainGui.SetFont("s10 bold", THEME["fontFamily"])
    MainGui.AddLink("x" xIn " y" (y+5) " w180 c" THEME["accent"] " Background" THEME["card"], '<a href="https://www.donationalerts.com/r/maxon3r">DonationAlerts</a>')
    
    
    ; --- ПОДВАЛ ---
    y := 675
    MainGui.AddText("x20 y" y " w920 h1 Background" THEME["border"], "")
    
    SwitchHelpTab("Overlay")

    ; ==============================================================================
    ; РАБОЧАЯ ОБЛАСТЬ: сдвигаем всё содержимое страниц вправо, под sidebar
    ; Страницы свёрстаны в локальной сетке 20..940; здесь они целиком переезжают
    ; в область справа от боковой навигации и поднимаются под верхнюю панель.
    ; ==============================================================================
    tabs.UseTab()   ; дальше контролы добавляются в окно, а не во вкладку

    for hwnd, pageCtrl in MainGui {
        if topBarHwnds.Has(hwnd)
            continue
        if hwnd = tabs.Hwnd
            continue
        try {
            pageCtrl.GetPos(&pcx, &pcy, &pcw, &pch)
            pageCtrl.Move(pcx + SIDEBAR_W, pcy + PAGE_DY)
        }
    }

    ; ==============================================================================
    ; БОКОВАЯ НАВИГАЦИЯ (SIDEBAR)
    ; Вертикальный список разделов слева: активный пункт — чуть светлее
    ; поверхность, тонкая cyan-рамка, мягкое свечение и cyan-текст.
    ; Внизу — состояние сохранения и глобальные действия.
    ; ==============================================================================
    MainGui.AddText("x0 y" TOPBAR_H " w" SIDEBAR_W " h" (WIN_H - TOPBAR_H) " Background" THEME["surface"], "")
    MainGui.AddText("x" (SIDEBAR_W - 1) " y" TOPBAR_H " w1 h" (WIN_H - TOPBAR_H) " Background" THEME["border"], "")

    MainGui.SetFont("s7 bold", THEME["fontFamily"])
    MainGui.AddText("x24 y76 w190 h14 c" THEME["textMuted"] " BackgroundTrans", "РАЗДЕЛЫ")

    global NavItems := []
    global NavActive := 1
    tabs.Choose(1)

    navLabels := [["Обзор", "▦"], ["Бинды", "▤"], ["Настройки", "⚙"], ["Статистика", "◔"], ["Помощь", "?"]]
    navX := 12
    navW := SIDEBAR_W - 24
    navItemH := 40
    navStep := 46
    navTop := 98
    indW := 3
    indH := 18

    ; Тонкий вертикальный индикатор активного раздела (плавно скользит)
    global NavInd := Map("y", navTop + (navItemH - indH) // 2, "h", indH)
    global NavIndicator := MainGui.AddText("x2 y" NavInd["y"] " w" indW " h" indH " Background" THEME["accent"], "")
    RoundCorners(NavIndicator, indW, indH, 1)
    global NavAnimTimer := ""
    global NavAnimData := ""

    for i, item in navLabels {
        act := (i = NavActive)
        iy := navTop + (i - 1) * navStep
        tab := NavigationTab(MainGui, navX, iy, navW, navItemH, item[1], i,
            ((idx) => (*) => NavSelect(idx))(i), act)
        tab.SetIcon(item[2])
        NavItems.Push(Map("btn", tab, "id", i))
    }

    ; --- Нижний блок: состояние и глобальные действия ---
    sysY := WIN_H - 190
    MainGui.AddText("x24 y" sysY " w" (SIDEBAR_W - 48) " h1 Background" THEME["border"], "")
    MainGui.SetFont("s7 bold", THEME["fontFamily"])
    MainGui.AddText("x24 y" (sysY + 18) " w190 h14 c" THEME["textMuted"] " BackgroundTrans", "СОХРАНЕНИЕ")

    g_SaveStatus := StatusDot(MainGui, 24, sysY + 46, "Все изменения сохранены", THEME["success"], THEME["surface"], 8, 190, 8)

    g_BtnGlobalSave := CreateStyledButton(MainGui, navX, sysY + 76, navW, 36, "Сохранить изменения",
        (*) => SaveEverything(), "primary", "Сохранить бинды и настройки")
    g_BtnGlobalSave.SetBackdrop(THEME["surface"])

    CreateStyledButton(MainGui, navX, sysY + 120, navW, 32, "Отменить действие", (*) => Undo(), "default",
        "Вернуть последнее изменение").SetBackdrop(THEME["surface"])

    if GlobalUnsavedChanges {
        UpdateButtonState(g_BtnGlobalSave, true, "primary")
        UpdateSaveBar(true)
    } else {
        UpdateButtonState(g_BtnGlobalSave, false)
        UpdateSaveBar(false)
    }

    AnimateNavIndicator(ind, targetY, aIndX, aIndW) {
        global NavIndicator, NavAnimTimer, NavAnimData
        if NavAnimTimer
            SetTimer(NavAnimTimer, 0)
        NavAnimData := Map(
            "ind", ind, "targetY", targetY, "aIndX", aIndX, "aIndW", aIndW,
            "fromY", ind["y"], "step", 0
        )
        NavAnimTimer := NavAnimTick
        SetTimer(NavAnimTimer, 0)
        SetTimer(NavAnimTimer, 12)
    }

    NavAnimTick() {
        global NavIndicator, NavAnimTimer, NavAnimData
        d := NavAnimData
        d["step"]++
        t := Min(1, d["step"] / 9)
        e := 1 - (1 - t) ** 3      ; ease-out cubic — плавное скольжение
        d["ind"]["y"] := Round(d["fromY"] + (d["targetY"] - d["fromY"]) * e)
        try NavIndicator.Move(d["aIndX"], d["ind"]["y"], d["aIndW"], d["ind"]["h"])
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
        ; Переключаем только страницу: окно не скрывается и не перерисовывается.
        tabs.Choose(idx)
        NavActive := idx
        for item in NavItems {
            act := (item["id"] = idx)
            item["btn"].SetActive(act)
        }
        for hb in HoverButtons {
            if IsObject(hb) && hb.HasOwnProp("isNav") && hb.isNav
                hb.isHovered := false
        }
        AnimateNavIndicator(NavInd, navTop + (idx - 1) * navStep + (navItemH - indH) // 2, 2, indW)
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
    global MainGui, STATE, CFG, STATS, THEME, GlobalUnsavedChanges
    
    if !MainGui
        return
    
    try {
        MainGui["MainPatientId"].Value := STATE["patientId"]
        UpdatePatientCard()
        
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
        UpdateDashboardCards()
        UpdateProfileStatus(false)
        UpdateSaveBar(GlobalUnsavedChanges)
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
    try MainGui["KpiSent"].Text := STATS["totalSent"]
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
                ; ВКЛЮЧЕНО: спокойная тёмная поверхность, красный — только у удаления
                style := "default"
                if InStr(text, "Удалить")
                    style := "danger"
                try btn.SetEnabledStyle(true, style)

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
        UpdatePatientCard("Введите ID пациента для активации сессии")
        return
    }
    
    if !RegExMatch(id, "^\d{1,5}$") {
        ShowNotify("ID должен быть числом 1-5 цифр!", "error")
        UpdatePatientCard("ID должен быть числом из 1–5 цифр")
        return
    }
    
    STATE["patientId"] := id
    MainGui["MainPatientDisplay"].Text := GetPatientDisplay()
    UpdatePatientCard()
    UpdateOverlayData()
    ShowNotify("ID установлен: " id, "success")
}

MainClearPatient(*) {
    global MainGui, STATE
    STATE["patientId"] := ""
    MainGui["MainPatientId"].Value := ""
    MainGui["MainPatientDisplay"].Text := "—"
    UpdatePatientCard()
    UpdateOverlayData()
    ShowNotify("ID очищен", "success")
}

; ══════════════════════════════════════════════════════════════════════════════
;  ДАННЫЕ РАБОЧЕГО СТОЛА
; ══════════════════════════════════════════════════════════════════════════════

; Приветствие по времени суток + имя врача (реальные данные профиля).
GetGreetingText() {
    global STATE
    hour := Integer(FormatTime(A_Now, "H"))
    if (hour < 5)
        part := "Доброй ночи"
    else if (hour < 12)
        part := "Доброе утро"
    else if (hour < 18)
        part := "Добрый день"
    else
        part := "Добрый вечер"
    name := Trim(STATE["myName"])
    return name = "" ? part : part ", " name
}

; Считает заполненные и активные бинды (только реальные данные).
CountBinds(&total, &active) {
    global SLOTS
    total := 0
    active := 0
    for slot in SLOTS {
        if slot["name"] != "" {
            total++
            if (slot["enabled"] && slot["hotkey"] != "")
                active++
        }
    }
}

GetPatientFormatLabel() {
    global CFG
    switch CFG["patientFormat"] {
        case "at": return "@ID"
        case "quote": return "`"ID"
        default: return "ID"
    }
}

; Верхний ряд показателей на «Обзоре».
UpdateDashboardCards() {
    global MainGui, STATE, STATS, CFG, THEME

    if !MainGui
        return

    try {
        CountBinds(&total, &active)
        hasPatient := STATE["patientId"] != ""

        MainGui["KpiPatient"].Text := hasPatient ? STATE["patientId"] : "—"
        MainGui["KpiPatient"].Opt("c" (hasPatient ? THEME["accent"] : THEME["textMuted"]))
        MainGui["KpiPatient"].Redraw()
        MainGui["KpiPatientSub"].Text := hasPatient ? "сессия активна" : "сессия не начата"

        MainGui["KpiBinds"].Text := total
        MainGui["KpiBindsSub"].Text := "активных: " active

        MainGui["KpiSent"].Text := STATS["totalSent"]

        MainGui["KpiSave"].Text := CFG["autoSave"] ? "Вкл" : "Выкл"
        MainGui["KpiSave"].Opt("c" (CFG["autoSave"] ? THEME["success"] : THEME["textMuted"]))
        MainGui["KpiSave"].Redraw()
        MainGui["KpiSaveSub"].Text := STATE["lastAutoSave"] != ""
            ? "последнее в " FormatTime(STATE["lastAutoSave"], "HH:mm")
            : "интервал " CFG["autoSaveInterval"] " сек"
    }

    try MainGui["DashGreeting"].Text := GetGreetingText()
}

; ── Состояния карточки «Текущий пациент» ──────────────────────────────────────
;    ○ Ожидание пациента · ● Сессия активна · ● Ошибка ввода

UpdatePatientCard(errorText := "") {
    global MainGui, STATE, THEME, g_PatientStatus, g_PatientGlow

    if !MainGui
        return

    hasPatient := STATE["patientId"] != ""

    try {
        display := GetPatientDisplay()
        MainGui["MainPatientDisplay"].Text := display = "" ? "—" : display
        MainGui["MainPatientDisplay"].Opt("c" (display = "" ? THEME["textMuted"] : THEME["accent"]))
        MainGui["MainPatientDisplay"].Redraw()
    }

    ; Активная сессия подсвечивается очень мягким cyan-свечением карточки
    try g_PatientGlow.Set(hasPatient && errorText = "")

    if IsObject(g_PatientStatus) {
        try {
            if errorText != "" {
                g_PatientStatus.Set("Ошибка ввода", THEME["error"])
                MainGui["PatientStatusHint"].Text := errorText
                MainGui["PatientStatusHint"].Opt("c" THEME["textDim"])
            } else if hasPatient {
                g_PatientStatus.Set("Сессия активна", THEME["success"])
                MainGui["PatientStatusHint"].Text := "ID готов к использованию в сообщениях"
                MainGui["PatientStatusHint"].Opt("c" THEME["textDim"])
            } else {
                g_PatientStatus.Set("Ожидание пациента", THEME["textDim"])
                MainGui["PatientStatusHint"].Text := "Введите ID пациента для активации сессии"
                MainGui["PatientStatusHint"].Opt("c" THEME["textMuted"])
            }
            MainGui["PatientStatusHint"].Redraw()
        }
    }

    UpdateDashboardCards()
}

; ── Статус карточки «Личное дело» ─────────────────────────────────────────────
UpdateProfileStatus(isDirty) {
    global g_ProfileStatus, THEME
    if !IsObject(g_ProfileStatus)
        return
    try {
        if isDirty
            g_ProfileStatus.Set("Есть несохранённые изменения", THEME["warning"])
        else
            g_ProfileStatus.Set("Профиль сохранён", THEME["success"])
    }
}

; ── Нижний action/status bar ──────────────────────────────────────────────────
UpdateSaveBar(isDirty) {
    global g_SaveStatus, THEME
    if !IsObject(g_SaveStatus)
        return
    try {
        if isDirty
            g_SaveStatus.Set("Есть изменения", THEME["warning"])
        else
            g_SaveStatus.Set("Все изменения сохранены", THEME["success"])
    }
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
    ShowNotify("Профиль сохранён: " STATE["myName"], "success")

    if g_BtnSaveProfile
        UpdateButtonState(g_BtnSaveProfile, false, "primary")
    UpdateProfileStatus(false)
}

ShowMainGui() {
    global MainGui
    
    if !MainGui
        BuildMainGui()
    
    RefreshMainGui()
    RefreshBindList()

    MainGui.Show("w1200 h736")
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
            MainGui["AutoSaveStatus"].Text := "АВТОСОХРАНЕНИЕ ВЫКЛ"
            MainGui["AutoSaveStatus"].Opt("c" THEME["textMuted"])
            MainGui["AutoSaveStatus"].Redraw()
            return
        }
        t := STATE["lastAutoSave"] != "" ? "  ·  " FormatTime(STATE["lastAutoSave"], "HH:mm") : ""
        MainGui["AutoSaveStatus"].Text := "АВТОСОХРАНЕНИЕ ВКЛ" t
        MainGui["AutoSaveStatus"].Opt("c" THEME["textMuted"])
        MainGui["AutoSaveStatus"].Redraw()
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
