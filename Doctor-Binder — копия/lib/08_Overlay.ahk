; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: overlay                       ║
; ║  Внутриигровой оверлей                          ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
BuildOverlay(mode := "full") {
    global OverlayGui, STATE
    
    if (OverlayGui && STATE.Has("lastMode") && STATE["lastMode"] = mode) {
        UpdateOverlayData()
        return (mode = "mini") ? 115 : 360
    }

    STATE["lastMode"] := mode
    try OverlayGui.Destroy()
    
    CreateOverlayGuiBase(mode)
    UpdateOverlayData()
    
    ; Теперь мини-оверлей тоже широкий (360px), но координаты X считаются в ShowOverlay
    return (mode = "mini") ? 115 : 360
}

CreateOverlayGuiBase(mode := "full") {
    global OverlayGui, THEME, CFG, STATE
    
    OverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000", "DoctorOverlay")
    OverlayGui.BackColor := THEME["bg"]
    OverlayGui.MarginX := 0
    OverlayGui.MarginY := 0
    
    ; === ФИКС: ЕДИНАЯ ШИРИНА 360 ДЛЯ ВСЕХ РЕЖИМОВ ===
    w := 360 
    ; ================================================
    
    ; --- МИНИ РЕЖИМ ---
    if (mode = "mini") {
        OverlayGui.AddText("x0 y0 w" w " h35 Background" THEME["bgLight"], "")
        OverlayGui.SetFont("s10 bold", "Segoe UI")
        OverlayGui.AddText("x15 y8 w" (w-30) " c" THEME["accent"] " BackgroundTrans", "Doctor Binder")
        OverlayGui.AddText("x0 y35 w" w " h3 Background" THEME["success"] " vMiniStatusLine", "")
        
        y := 45
        OverlayGui.SetFont("s9", "Segoe UI")
        OverlayGui.AddText("x15 y" (y+3) " w60 c" THEME["textDim"] " BackgroundTrans", "Пациент:")
        
        OverlayGui.SetFont("s10 bold", "Consolas")
        OverlayGui.AddEdit("x80 y" y " w80 h24 Background" THEME["bgHighlight"] " c" THEME["accent"] " vMiniInputId Center Hidden", "")
        OverlayGui.AddText("x80 y" (y+3) " w80 c" THEME["textMuted"] " vMiniPatient BackgroundTrans", "—")
        
        OverlayGui.SetFont("s9 bold", "Segoe UI")
        OverlayGui.AddText("x180 y" (y+3) " w165 Right c" THEME["success"] " vMiniStatus BackgroundTrans", "ГОТОВ")
        
        y += 30
        OverlayGui.SetFont("s8", "Segoe UI")
        OverlayGui.AddText("x15 y" y " w" (w-30) " c" THEME["textDim"] " vMiniStats BackgroundTrans", "...")
        
        y += 20
        OverlayGui.SetFont("s7", "Segoe UI")
        hkMini := FormatHotkey(CFG["hotkeyMiniOverlay"])
        OverlayGui.AddText("x0 y" y " w" w " Center c" THEME["textMuted"] " BackgroundTrans", hkMini ": Скрыть")
        
        WinSetTransparent(CFG["overlayOpacity"], OverlayGui)
        return
    }
    
    ; --- ПОЛНЫЙ РЕЖИМ (Теперь тоже широкий, 360px) ---
    OverlayGui.AddText("x0 y0 w" w " h55 Background" THEME["bgLight"], "")
    OverlayGui.AddText("x0 y0 w" w " h4 vOvStatusLine Background" THEME["success"], "")
    
    OverlayGui.SetFont("s9", "Segoe UI")
    OverlayGui.AddText("x15 y12 w60 c" THEME["textDim"] " BackgroundTrans", "Пациент:")
    
    OverlayGui.SetFont("s11 bold", "Consolas")
    OverlayGui.AddText("x80 y10 w80 c" THEME["textMuted"] " BackgroundTrans vOvPatient", "—")
    
    OverlayGui.SetFont("s10 bold", "Consolas")
    OverlayGui.AddEdit("x80 y8 w80 h24 Background" THEME["bgHighlight"] " c" THEME["accent"] " vOvInputId Center Hidden", "")
    
    ; Статус (Подвинули правее под ширину 360)
    OverlayGui.SetFont("s9 bold", "Segoe UI")
    OverlayGui.AddText("x210 y12 w135 Right c" THEME["success"] " BackgroundTrans vOvStatus", "ГОТОВ")
    
    OverlayGui.SetFont("s8", "Segoe UI")
    OverlayGui.AddText("x15 y35 w" (w-30) " c" THEME["textDim"] " BackgroundTrans vOvStats", "...")
    
    OverlayGui.AddText("x0 y55 w" w " h2 Background" THEME["borderGlow"], "")
    
    y := 63
    rowH := 24
    Loop 10 {
        OverlayGui.AddText("x0 y" y " w" w " h" rowH " Background" THEME["bg"] " vOvRowBg" A_Index, "")
        OverlayGui.AddText("x0 y" y " w4 h" rowH " Background" THEME["bg"] " vOvRowMark" A_Index, "")
        
        OverlayGui.SetFont("s8 bold", "Consolas")
        OverlayGui.AddText("x12 y" (y+4) " w70 c" THEME["textMuted"] " BackgroundTrans vOvHk" A_Index, "")
        OverlayGui.SetFont("s9", "Segoe UI")
        ; Увеличили ширину названия
        OverlayGui.AddText("x90 y" (y+2) " w" (w-130) " c" THEME["textDim"] " BackgroundTrans vOvName" A_Index, "")
        OverlayGui.SetFont("s7", "Segoe UI")
        ; Сдвинули счетчик строк вправо
        OverlayGui.AddText("x" (w-40) " y" (y+5) " w30 Right c" THEME["textMuted"] " BackgroundTrans vOvLines" A_Index, "")
        y += rowH
    }
    
    OverlayGui.AddText("x0 y" y " w" w " h1 Background" THEME["border"], "")
    y += 5
    
    OverlayGui.SetFont("s8", "Segoe UI")
    OverlayGui.AddText("x15 y" y " w100 c" THEME["accent"] " BackgroundTrans vOvPage", "Стр 1/1")
    y += 18
    
    hkFull := FormatHotkey(CFG["hotkeyOverlay"])
    OverlayGui.AddText("x15 y" y " w" (w-30) " Center c" THEME["textMuted"] " BackgroundTrans vOvFooter", "P: ID • " hkFull ": Скрыть")
    
    WinSetTransparent(CFG["overlayOpacity"], OverlayGui)
}

BuildMiniOverlay() {
    global OverlayGui, THEME, STATE, STATS, CFG
    
    w := 280
    y := 0
    
    ; Заголовок со свечением
    OverlayGui.AddText("x0 y0 w" w " h40 Background" THEME["bgLight"], "")
    OverlayGui.SetFont("s11 bold", "Segoe UI")
    OverlayGui.AddText("x16 y12 w" (w-32) " c" THEME["accent"] " BackgroundTrans", "Doctor Binder")
    y += 40
    
    ; Полоска статуса (теперь с ID для обновления)
    statusColor := STATE["isSending"] ? THEME["warning"] : THEME["success"]
    OverlayGui.AddText("x0 y" y " w" w " h3 Background" statusColor " vMiniStatusLine", "")
    y += 10
    
    ; Пациент с возможностью ввода
    OverlayGui.SetFont("s9 norm", "Segoe UI")
    OverlayGui.AddText("x16 y" (y+3) " w80 c" THEME["textDim"] " BackgroundTrans", "Пациент:")
    
    if (STATE["overlayInputMode"]) {
        OverlayGui.SetFont("s10 bold", "Consolas")
        OverlayGui.AddEdit("x100 y" y " w150 h26 Background" THEME["bgHighlight"] " c" THEME["accent"] " vMiniInputId ReadOnly Center", STATE["tempId"])
        OverlayGui.SetFont("s8", "Segoe UI")
        OverlayGui.AddText("x16 y" (y+32) " w" (w-32) " c" THEME["warning"] " Center BackgroundTrans", "Введите ID и нажмите Enter")
        y += 62
    } else {
        patientDisplay := STATE["patientId"] = "" ? "не задан" : GetPatientDisplay()
        patientColor := STATE["patientId"] = "" ? THEME["textMuted"] : THEME["success"]
        
        OverlayGui.SetFont("s10 bold", "Consolas")
        OverlayGui.AddText("x100 y" (y+3) " w" (w-116) " c" patientColor " vMiniPatient BackgroundTrans", patientDisplay)
        y += 30
        
        ; Статистика
        OverlayGui.SetFont("s8", "Segoe UI")
        OverlayGui.AddText("x16 y" (y+3) " w" (w-32) " c" THEME["textDim"] " vMiniStats BackgroundTrans", 
            "Вылечено: " STATS["patientsHealed"] " | Операций: " STATS["operationsDone"])
        y += 26
        
        ; Статус текстом
        statusText := STATE["isSending"] ? "Отправка..." : "Готов"
        statusColor := STATE["isSending"] ? THEME["warning"] : THEME["success"]
        OverlayGui.AddText("x16 y" (y+3) " w" (w-32) " c" statusColor " vMiniStatus BackgroundTrans", statusText)
        y += 26
    }
    
    ; Подсказка с РЕАЛЬНЫМИ клавишами
    hkFull := FormatHotkey(CFG["hotkeyOverlay"]) ; Получаем клавишу полного оверлея
    
    OverlayGui.SetFont("s7", "Segoe UI")
    OverlayGui.AddText("x16 y" (y+3) " w" (w-32) " c" THEME["textMuted"] " Center BackgroundTrans", 
        hkFull " — полный | P — ID | Esc — закрыть")
    y += 24
    
    return y
}

; ═══════════════════════════════════════════════════════════════════════════════
; ОВЕРЛЕЙ v3.0 (ИНФОРМАТИВНЫЙ И УМНЫЙ)
; ═══════════════════════════════════════════════════════════════════════════════
BuildFullOverlay() {
    global OverlayGui, THEME, SLOTS, OverlaySelectedIndex, OverlayBindsList, STATE, STATS, CurrentPage, CFG
    
    ; == НАСТРОЙКИ РАЗМЕРОВ ==
    w := 320
    rowH := 24
    y := 0
    
    ; === 1. ВЕРХНЯЯ ПАНЕЛЬ ===
    OverlayGui.AddText("x0 y0 w" w " h55 Background" THEME["bgLight"], "")
    
    ; Полоска статуса
    statusColor := STATE["isSending"] ? THEME["warning"] : THEME["success"]
    OverlayGui.AddText("x0 y0 w" w " h4 vOvStatusLine Background" statusColor, "")
    
    ; Пациент
    OverlayGui.SetFont("s9", "Segoe UI")
    OverlayGui.AddText("x15 y12 w60 c" THEME["textDim"] " BackgroundTrans", "Пациент:")
    
    if (STATE["overlayInputMode"]) {
        OverlayGui.SetFont("s10 bold", "Consolas")
        OverlayGui.AddEdit("x80 y8 w80 h24 Background" THEME["bgHighlight"] " c" THEME["accent"] " vOvInputId ReadOnly Center", STATE["tempId"])
    } else {
        OverlayGui.SetFont("s11 bold", "Consolas")
        patColor := STATE["patientId"]="" ? THEME["textMuted"] : THEME["success"]
        patText := STATE["patientId"]="" ? "—" : STATE["patientId"]
        OverlayGui.AddText("x80 y10 w80 c" patColor " BackgroundTrans vOvPatient", patText)
    }
    
    ; Статус (Текст)
    stText := STATE["isSending"] ? "ОТПРАВКА..." : "ГОТОВ"
    stColor := STATE["isSending"] ? THEME["warning"] : THEME["success"]
    OverlayGui.SetFont("s9 bold", "Segoe UI")
    OverlayGui.AddText("x170 y12 w" (w-185) " Right c" stColor " BackgroundTrans vOvStatus", stText)

    ; Статистика
    y += 35
    OverlayGui.SetFont("s8", "Segoe UI")
    statsInfo := "Лечение: " STATS["patientsHealed"] "   Уколы: " STATS["injectionsGiven"] "   Операции: " STATS["operationsDone"] "   Медосмотры: " STATS["medChecks"]
    OverlayGui.AddText("x15 y" y " w" (w-30) " c" THEME["textDim"] " BackgroundTrans vOvStats", statsInfo)
    
    y += 20
    OverlayGui.AddText("x0 y" y " w" w " h2 Background" THEME["borderGlow"], "")
    y += 6
    
    ; === 2. СПИСОК БИНДОВ ===
    ; Сразу собираем список, чтобы корректно отобразить
    OverlayBindsList := []
    Loop Constants.MAX_SLOTS {
        slot := SLOTS[A_Index]
        if slot["enabled"] && slot["name"] != "" && slot["lines"].Length > 0 {
            OverlayBindsList.Push(Map("index", A_Index, "hotkey", slot["hotkey"], "name", slot["name"], "lines", slot["lines"].Length))
        }
    }
    
    totalItems := OverlayBindsList.Length
    TotalPages := Max(1, Ceil(totalItems / 10))
    CurrentPage := Min(CurrentPage, TotalPages)
    startIdx := (CurrentPage - 1) * 10 + 1
    
    Loop 10 {
        isSelected := (A_Index = OverlaySelectedIndex)
        bgColor := isSelected ? THEME["bgSelected"] : THEME["bg"]
        
        ; Фон строки
        OverlayGui.AddText("x0 y" y " w" w " h" rowH " Background" bgColor " vOvRow" A_Index, "")
        
        ; Маркер выбора
        if isSelected {
            OverlayGui.AddText("x0 y" y " w4 h" rowH " Background" THEME["accent"], "")
        }
        
        bindIdx := startIdx + A_Index - 1
        hkText := ""
        nameText := ""
        linesText := ""
        
        if (bindIdx <= OverlayBindsList.Length) {
            bind := OverlayBindsList[bindIdx]
            hkText := bind["hotkey"]
            nameText := SubStr(bind["name"], 1, 25)
            linesText := "(" bind["lines"] ")"
        }
        
        ; Хоткей
        OverlayGui.SetFont("s8 bold", "Consolas")
        hkColor := isSelected ? THEME["accent"] : THEME["textMuted"]
        OverlayGui.AddText("x12 y" (y+4) " w70 c" hkColor " BackgroundTrans vOvHk" A_Index, hkText)
        
        ; Название
        OverlayGui.SetFont("s9", "Segoe UI")
        nmColor := isSelected ? THEME["text"] : THEME["textDim"]
        OverlayGui.AddText("x90 y" (y+2) " w" (w-130) " c" nmColor " BackgroundTrans vOvName" A_Index, nameText)
        
        ; Строки
        OverlayGui.SetFont("s7", "Segoe UI")
        OverlayGui.AddText("x" (w-40) " y" (y+5) " w30 Right c" THEME["textMuted"] " BackgroundTrans vOvLines" A_Index, linesText)
        
        y += rowH
    }
    
    y += 5
    OverlayGui.AddText("x0 y" y " w" w " h1 Background" THEME["border"], "")
    y += 5
    
    ; === 3. ПОДВАЛ ===
    hkToggle := FormatHotkey(CFG["hotkeyOverlay"])
    hkMini := FormatHotkey(CFG["hotkeyMiniOverlay"])
    
    OverlayGui.SetFont("s8", "Segoe UI")
    
    ; СТРАНИЦЫ (Исправлено отображение переменной)
    pageStr := "Стр " CurrentPage "/" TotalPages
    OverlayGui.AddText("x15 y" y " w100 c" THEME["accent"] " BackgroundTrans vOvPage", pageStr)
    OverlayGui.AddText("x120 y" y " w" (w-135) " Right c" THEME["textDim"] " BackgroundTrans", "PgUp / PgDn : Листать")
    
    y += 18
    
    if (STATE["overlayInputMode"]) {
         OverlayGui.AddText("x0 y" y " w" w " Center c" THEME["warning"] " BackgroundTrans", "ENTER: Принять  |  ESC: Отмена")
    } else {
         OverlayGui.AddText("x15 y" y " w" (w-30) " Center c" THEME["textMuted"] " BackgroundTrans", 
            "P: ID  •  " hkToggle ": Скрыть  •  " hkMini ": Мини")
    }
    y += 20
    
    return y
}

UpdateOverlayData() {
    global OverlayGui, SLOTS, STATE, STATS, OverlaySelectedIndex, OverlayBindsList, THEME, CurrentPage, CFG
    
    if !OverlayGui
        return

    ; Определяем цвета статуса
    statusColor := STATE["isSending"] ? THEME["warning"] : THEME["success"]
    statusText := STATE["isSending"] ? "ОТПРАВКА..." : "ГОТОВ"

    ; ==============================================================================
    ; ЛОГИКА ДЛЯ МИНИ-РЕЖИМА
    ; ==============================================================================
    if (STATE["overlayMode"] = "mini") {
        try OverlayGui["MiniStatusLine"].Opt("Background" statusColor)
        
        if (STATE["overlayInputMode"]) {
            try OverlayGui["MiniPatient"].Visible := false
            try OverlayGui["MiniInputId"].Visible := true
            try OverlayGui["MiniInputId"].Value := STATE["tempId"]
            try OverlayGui["MiniStatus"].Text := "Enter: Принять"
            try OverlayGui["MiniStatus"].Opt("c" THEME["warning"])
        } else {
            try OverlayGui["MiniInputId"].Visible := false
            try OverlayGui["MiniPatient"].Visible := true
            
            patText := STATE["patientId"] = "" ? "не задан" : STATE["patientId"]
            try OverlayGui["MiniPatient"].Text := patText
            try OverlayGui["MiniPatient"].Opt("c" (STATE["patientId"]="" ? THEME["textMuted"] : THEME["success"]))
            
            try OverlayGui["MiniStatus"].Text := statusText
            try OverlayGui["MiniStatus"].Opt("c" statusColor)
            
            try OverlayGui["MiniStats"].Text := "Лечение: " STATS["patientsHealed"] " | Операции: " STATS["operationsDone"]
        }
        return
    }

    ; ==============================================================================
    ; ЛОГИКА ДЛЯ ПОЛНОГО РЕЖИМА
    ; ==============================================================================
    
    try OverlayGui["OvStatusLine"].Opt("Background" statusColor)
    try OverlayGui["OvStatusLine"].Redraw()
    
    try OverlayGui["OvStatus"].Text := statusText
    try OverlayGui["OvStatus"].Opt("c" statusColor)
    
    if (STATE["overlayInputMode"]) {
        try OverlayGui["OvPatient"].Visible := false
        try OverlayGui["OvInputId"].Visible := true
        try OverlayGui["OvInputId"].Value := STATE["tempId"]
        try OverlayGui["OvFooter"].Text := "ENTER: Принять | ESC: Отмена"
        try OverlayGui["OvFooter"].Opt("c" THEME["warning"])
    } else {
        try OverlayGui["OvInputId"].Visible := false
        try OverlayGui["OvPatient"].Visible := true
        patText := STATE["patientId"] = "" ? "—" : STATE["patientId"]
        try OverlayGui["OvPatient"].Text := patText
        try OverlayGui["OvPatient"].Opt("c" (STATE["patientId"]="" ? THEME["textMuted"] : THEME["success"]))
        
        hk1 := FormatHotkey(CFG["hotkeyOverlay"])
        try OverlayGui["OvFooter"].Text := "P: ID  •  " hk1 ": Скрыть"
        try OverlayGui["OvFooter"].Opt("c" THEME["textMuted"])
    }
    
    try OverlayGui["OvStats"].Text := "Лечение: " STATS["patientsHealed"] "   Уколы: " STATS["injectionsGiven"] "   Операции: " STATS["operationsDone"]

    ; --- Обновление Списка Биндов ---
    
    OverlayBindsList := []
    Loop Constants.MAX_SLOTS {
        slot := SLOTS[A_Index]
        if slot["enabled"] && slot["name"] != "" && slot["lines"].Length > 0 {
            OverlayBindsList.Push(Map("index", A_Index, "hotkey", slot["hotkey"], "name", slot["name"], "lines", slot["lines"].Length))
        }
    }
    
    totalItems := OverlayBindsList.Length
    totalPages := Max(1, Ceil(totalItems / 10))
    if (CurrentPage > totalPages) 
        CurrentPage := totalPages
    if (CurrentPage < 1) 
        CurrentPage := 1
    
    try OverlayGui["OvPage"].Text := "Стр " CurrentPage "/" totalPages
    
    startIdx := (CurrentPage - 1) * 10 + 1
    
    Loop 10 {
        bindIdx := startIdx + A_Index - 1
        isSelected := (A_Index = OverlaySelectedIndex)
        
        bgColor := isSelected ? THEME["bgSelected"] : THEME["bg"]
        markColor := isSelected ? THEME["accent"] : THEME["bg"]
        
        try OverlayGui["OvRowBg" A_Index].Opt("Background" bgColor)
        try OverlayGui["OvRowBg" A_Index].Redraw()
        try OverlayGui["OvRowMark" A_Index].Opt("Background" markColor)
        try OverlayGui["OvRowMark" A_Index].Redraw()
        
        if (bindIdx <= totalItems) {
            bind := OverlayBindsList[bindIdx]
            
            ; === ВОТ ЗДЕСЬ БЫЛО ИЗМЕНЕНИЕ ===
            ; Было: bind["hotkey"]
            ; Стало: FormatHotkey(bind["hotkey"])
            try OverlayGui["OvHk" A_Index].Text := FormatHotkey(bind["hotkey"])
            ; ================================
            
            try OverlayGui["OvName" A_Index].Text := SubStr(bind["name"], 1, 25)
            try OverlayGui["OvLines" A_Index].Text := "(" bind["lines"] ")"
            
            try OverlayGui["OvHk" A_Index].Opt("c" (isSelected ? THEME["accent"] : THEME["textMuted"]))
            try OverlayGui["OvName" A_Index].Opt("c" (isSelected ? THEME["text"] : THEME["textDim"]))
        } else {
            try OverlayGui["OvHk" A_Index].Text := ""
            try OverlayGui["OvName" A_Index].Text := ""
            try OverlayGui["OvLines" A_Index].Text := ""
        }
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; УПРАВЛЕНИЕ ОВЕРЛЕЕМ (БЕЗ ПЕРЕСОЗДАНИЯ ОКОН)
; ═══════════════════════════════════════════════════════════════════════════════

ShowOverlay(mode := "full") {
    global OverlayGui, OverlayVisible, STATE, CFG
    
    ; === ИСПРАВЛЕНИЕ ===
    ; Если режим изменился (например, был Full, стал Mini) — УНИЧТОЖАЕМ старое окно.
    ; Это уберет "призрачные" бинды из мини-версии.
    if (STATE.Has("lastMode") && STATE["lastMode"] != mode) {
        try OverlayGui.Destroy()
        OverlayGui := ""
    }
    STATE["lastMode"] := mode
    STATE["overlayMode"] := mode
    ; ===================
    
    ; Если окна нет (или мы его только что уничтожили) — создаем заново под нужный режим
    if !OverlayGui {
        CreateOverlayGuiBase(mode)
    }
    
    ; Размеры
    w := 360
    h := (mode = "mini") ? 115 : 360
    
    ; Позиция
    x := A_ScreenWidth - w - 20
    y := (mode = "mini") ? 20 : A_ScreenHeight - h - 80
    
    ; Обновляем текст
    UpdateOverlayData()
    
    ; Показываем
    OverlayGui.Show("x" x " y" y " w" w " h" h " NA")
    
    try WinSetAlwaysOnTop(1, OverlayGui)
    try WinSetRegion("0-0 w" w " h" h " R15-15", OverlayGui.Hwnd)
    try WinSetTransparent(CFG["overlayOpacity"], OverlayGui)
    
    OverlayVisible := true
    
    if mode = "full"
        EnableOverlayKeys()
    else
        EnableMiniOverlayKeys()
}

HideOverlay() {
    global OverlayGui, OverlayVisible
    
    DisableOverlayKeys()
    
    if OverlayGui
        OverlayGui.Hide()
        
    OverlayVisible := false
}

ToggleOverlay() {
    global OverlayVisible, ChatIsOpen
    
    ; Аварийный сброс чата при нажатии F10
    ChatIsOpen := false 
    
    if OverlayVisible
        HideOverlay()
    else
        ShowOverlay("full")
}

ToggleMiniOverlay() {
    global OverlayVisible, ChatIsOpen
    
    ChatIsOpen := false
    
    if OverlayVisible
        HideOverlay()
    else
        ShowOverlay("mini")
}

; ═══════════════════════════════════════════════════════════════════════════════
; КЛАВИАТУРНОЕ УПРАВЛЕНИЕ
; ═══════════════════════════════════════════════════════════════════════════════

DisableOverlayKeys() {
    ; Пустышка для совместимости
}

EnableOverlayKeys() {
    ; Пустышка
}

EnableMiniOverlayKeys() {
    ; Пустышка
}

OverlayUp(*) {
    global OverlaySelectedIndex
    if OverlaySelectedIndex <= 1 {
        OverlaySelectedIndex := 10
    } else {
        OverlaySelectedIndex--
    }
    UpdateOverlayData()
}

OverlayDown(*) {
    global OverlaySelectedIndex, OverlayBindsList, CurrentPage
    maxOnPage := Min(10, OverlayBindsList.Length - (CurrentPage - 1) * 10)
    if OverlaySelectedIndex >= maxOnPage {
        OverlaySelectedIndex := 1
    } else {
        OverlaySelectedIndex++
    }
    UpdateOverlayData()
}

OverlayActivate(*) {
    global OverlaySelectedIndex, OverlayBindsList, CurrentPage
    
    if OverlaySelectedIndex = 0
        return
    
    itemIdx := (CurrentPage - 1) * 10 + OverlaySelectedIndex
    if itemIdx <= OverlayBindsList.Length {
        bind := OverlayBindsList[itemIdx]
        slotIdx := bind["index"]
        HideOverlay()
        RunSlotByNum(slotIdx)
    }
}

OverlayClose(*) {
    HideOverlay()
}

OverlayPageUp(*) {
    global CurrentPage
    if CurrentPage > 1 {
        CurrentPage--
        UpdateOverlayData()
    }
}

OverlayPageDown(*) {
    global CurrentPage, OverlayBindsList
    totalPages := Max(1, Ceil(OverlayBindsList.Length / 10))
    if CurrentPage < totalPages {
        CurrentPage++
        UpdateOverlayData()
    }
}

OverlaySelectNum(num) {
    global OverlaySelectedIndex, OverlayBindsList, CurrentPage
    maxOnPage := Min(10, OverlayBindsList.Length - (CurrentPage - 1) * 10)
    if num <= maxOnPage {
        OverlaySelectedIndex := num
        UpdateOverlayData()
        OverlayActivate()
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; ВВОД ID ПАЦИЕНТА (БЕЗ ПЕРЕСОЗДАНИЯ ОКНА)
; ═══════════════════════════════════════════════════════════════════════════════

OverlaySetId(*) {
    global STATE, OverlayInputHook, OverlayGui
    
    STATE["overlayInputMode"] := true
    STATE["tempId"] := ""
    
    ; Просто обновляем данные, окно само покажет поле ввода
    UpdateOverlayData()
    
    ; Запускаем перехватчик ввода
    if OverlayInputHook
        try OverlayInputHook.Stop()
        
    OverlayInputHook := InputHook("V L0")
    OverlayInputHook.KeyOpt("0123456789", "NS")
    OverlayInputHook.KeyOpt("{Numpad0}{Numpad1}{Numpad2}{Numpad3}{Numpad4}{Numpad5}{Numpad6}{Numpad7}{Numpad8}{Numpad9}", "NS")
    OverlayInputHook.KeyOpt("{BackSpace}{Enter}{Escape}{NumpadEnter}", "NS")
    
    OverlayInputHook.OnKeyDown := OverlayHandleKey
    OverlayInputHook.Start()
}

OverlayHandleKey(ih, vk, sc) {
    global STATE
    
    keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    
    ; Цифры
    if RegExMatch(keyName, "^\d$") || RegExMatch(keyName, "^Numpad\d$") {
        digit := StrReplace(keyName, "Numpad")
        
        if StrLen(STATE["tempId"]) < Constants.MAX_PATIENT_ID_LENGTH {
            STATE["tempId"] .= digit
        }
    }
    ; Backspace
    else if (keyName = "Backspace") {
        if StrLen(STATE["tempId"]) > 0 {
            STATE["tempId"] := SubStr(STATE["tempId"], 1, -1)
        }
    }
    ; Enter - Сохранить
    else if (keyName = "Enter" || keyName = "NumpadEnter") {
        OverlaySaveAndClose()
        return ; Выходим, чтобы не вызвать UpdateOverlayData дважды
    }
    ; Escape - Отмена
    else if (keyName = "Escape") {
        OverlayCancelAndClose()
        return
    }
    
    ; Обновляем отображение введенных цифр
    UpdateOverlayData()
}

OverlaySaveAndClose() {
    global STATE, OverlayInputHook
    
    if OverlayInputHook
        OverlayInputHook.Stop()
    
    if (STATE["tempId"] != "") {
        STATE["patientId"] := STATE["tempId"]
        ShowNotify("ID сохранен: " STATE["tempId"], "success")
    }
    
    STATE["overlayInputMode"] := false
    UpdateOverlayData()
}

OverlayCancelAndClose() {
    global STATE, OverlayInputHook
    
    if OverlayInputHook
        OverlayInputHook.Stop()
    
    STATE["overlayInputMode"] := false
    UpdateOverlayData()
}

OverlayClearId(*) {
    global STATE
    STATE["patientId"] := ""
    UpdateOverlayData()
    ShowNotify("ID очищен", "success")
}


; ═══════════════════════════════════════════════════════════════════════════════
; ПРОВЕРКА ЧАТА
; ═══════════════════════════════════════════════════════════════════════════════
