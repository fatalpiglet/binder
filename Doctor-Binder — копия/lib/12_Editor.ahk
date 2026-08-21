; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: editor                        ║
; ║  Редактор бинда                                 ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
OpenBindEditor(slotNum) {
    global EditorGui, SLOTS, CurrentEditSlot, THEME, EditorHasChanges
    global CurrentSelectedRow, EditorEditBox, EditorDelayBox, EditorKeyDisplay
    global GlobalUnsavedChanges, WasDirtyBeforeEditor, HoverButtons, BtnConfirmDelay
    global MainGui, g_EditorLineList, g_EditorCategory, g_EditorStatVisible
    
    SaveUndoState("Редактирование бинда")
    
    WasDirtyBeforeEditor := GlobalUnsavedChanges 
    EditorHasChanges := false
    CurrentEditSlot := slotNum
    CurrentSelectedRow := 0
    slot := SLOTS[slotNum]
    
    try {
        if EditorGui {
            CleanupHoverButtons(EditorGui)
            EditorGui.Destroy()
        }
    }
    
    totalW := 1040
    totalH := 736
    
    EditorGui := Gui("-Resize -Caption +Border +Owner" MainGui.Hwnd, "Bind Editor")
    EditorGui.BackColor := THEME["bg"]
    EditorGui.SetFont("s10 c" THEME["text"], THEME["fontFamily"])
    EditorGui.OnEvent("Close", (*) => SafeCloseEditor())
    
    try {
        if VerCompare(A_OSVersion, "10.0.17763") >= 0 {
            IsDark := 1
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", EditorGui.Hwnd, "Int", 20, "Int*", IsDark, "Int", 4)
        }
    }
    
    TitleBar := EditorGui.AddText("x0 y0 w" totalW " h56 Background" THEME["surface"], "")
    EditorGui.AddText("x0 y55 w" totalW " h1 Background" THEME["border"], "")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, EditorGui.Hwnd))

    EditorGui.SetFont("s14 bold", THEME["fontFamily"])
    EditorGui.AddText("x22 y10 w420 h24 c" THEME["textTitle"] " BackgroundTrans", "Редактор бинда")
    EditorGui.SetFont("s8 norm", THEME["fontFamily"])
    EditorGui.AddText("x23 y34 w520 h16 c" THEME["textMuted"] " BackgroundTrans", "Горячая клавиша, строки и параметры бинда")

    bindTitle := slot["name"] != "" ? slot["name"] : "Новый бинд"
    EditorGui.SetFont("s9 bold", THEME["fontFamily"])
    EditorGui.AddText("x620 y20 w340 h18 Right c" THEME["textDim"] " BackgroundTrans", bindTitle)

    CloseBtn := CreateStyledButton(EditorGui, totalW - 46, 12, 32, 32, "×", (*) => SafeCloseEditor(), "icon", "Закрыть редактор")
    CloseBtn.SetBackdrop(THEME["surface"])
    CloseBtn.ctrl.SetFont("s12 norm", "Segoe UI")

    xCard := 16
    cardW := totalW - 32
    CreateCard(EditorGui, xCard, 68, cardW, 598)

    EditorChip(parent, x, y, w, h, text, cb, style := "default") {
        b := CreateStyledButton(parent, x, y, w, h, text, cb, style)
        b.SetBackdrop(THEME["card"])
        b.radius := 6
        try RoundCorners(b.ctrl, w, h, 6)
        if (style = "default") {
            b.SetVisual("0d1117", "e5e7eb", "121820", "232a36")
            b.SetHoverAccent("121820", "38bdf8")
        }
        b.ctrl.SetFont("s8 norm", THEME["fontFamily"])
        return b
    }

    yRow := 92
    xIn := xCard + 20
    CreateFieldLabel(EditorGui, xIn, yRow, 220, "Название бинда")
    CreateInput(EditorGui, xIn, yRow + 16, 250, 32, "vEditorName", slot["name"], 10, THEME["card"])
    xIn += 266

    CreateFieldLabel(EditorGui, xIn, yRow, 150, "Горячая клавиша")
    hkDisplay := slot["hotkey"] = "" ? "Нажмите..." : FormatHotkey(slot["hotkey"])
    hkColor := slot["hotkey"] = "" ? THEME["textMuted"] : THEME["accent"]
    EditorKeyButton := CreateStyledButton(EditorGui, xIn, yRow + 16, 150, 32, hkDisplay, (*) => EditorStartCapture(), "default")
    EditorKeyButton.ctrl.Name := "EditorKeyDisplay"
    EditorKeyButton.SetBackdrop(THEME["card"])
    EditorKeyButton.SetVisual("0d1117", hkColor, "121820", "232a36")
    EditorKeyButton.ctrl.SetFont("s9 bold", THEME["fontMono"])
    EditorKeyDisplay := EditorKeyButton.ctrl
    EditorGui.AddEdit("x0 y0 w0 h0 Hidden vEditorHotkey", slot["hotkey"])
    xIn += 166

    CreateFieldLabel(EditorGui, xIn, yRow, 150, "Категория")
    g_EditorCategory := DarkSelect(EditorGui, xIn, yRow + 16, 160, 32, "EditorCategory",
        ["Основные", "Лечение", "Медосмотр", "Вакцины", "Операции", "Быстрые", "Утилиты"], 1)
    xIn += 180

    tgEnabled := ToggleBox(EditorGui, xIn, yRow + 24, "EditorEnabled", slot["enabled"], "", THEME["card"], 17)
    lblEnabled := EditorGui.AddText("x" (xIn + 26) " y" (yRow + 24) " w80 h18 BackgroundTrans c" THEME["success"], "Активен")
    lblEnabled.SetFont("s10 norm", THEME["fontFamily"])
    tgEnabled.AttachLabel(lblEnabled)

    yStat := 154
    stLab := EditorGui.AddText("x" (xCard + 20) " y" yStat " w90 h16 BackgroundTrans c" THEME["textMuted"], "В статистику")
    stLab.SetFont("s8 norm", THEME["fontFamily"])
    g_EditorStatVisible := DarkSelect(EditorGui, xCard + 118, yStat - 6, 150, 28, "EditorStatTypeVisible",
        ["—", "Таблетки", "Уколы", "Операции", "Медкарты", "Вакцины"], 1, (*) => SyncStatTypeFromVisible())
    EditorGui.AddDropDownList("x0 y0 w0 Hidden vEditorStatType Choose1", ["", "pills", "inject", "operation", "medcheck", "vaccine"])
    SetEditorDropdowns(slot)
    SetEditorStatTypeVisible(slot)

    yMain := 188
    leftW := 430
    rightW := cardW - leftW - 40
    xRight := xCard + leftW + 28

    EditorGui.SetFont("s10 bold", THEME["fontFamily"])
    EditorGui.AddText("x" (xCard+20) " y" yMain " w220 h18 c" THEME["text"] " BackgroundTrans", "СТРОКИ БИНДА")
    EditorGui.SetFont("s8 norm", THEME["fontFamily"])
    EditorGui.AddText("x" (xCard+leftW-120) " y" (yMain+2) " w110 Right c" THEME["textMuted"] " BackgroundTrans vEditorLineCount",
        EditorLineCountText(slot["lines"].Length))

    yTool := yMain + 28
    CreateOutlineBtn(EditorGui, xCard+20, yTool, 118, 30, "+ Добавить", (*) => EditorAddRow(), "primary").SetBackdrop(THEME["card"])
    EditorChip(EditorGui, xCard+146, yTool, 30, 30, "↑", (*) => EditorMoveUp())
    EditorChip(EditorGui, xCard+180, yTool, 30, 30, "↓", (*) => EditorMoveDown())
    EditorChip(EditorGui, xCard+218, yTool, 96, 30, "Копировать", (*) => EditorDuplicateRow())
    delBtn := CreateOutlineBtn(EditorGui, xCard+320, yTool, 90, 30, "Удалить", (*) => EditorDeleteRow(), "danger")
    delBtn.SetBackdrop(THEME["card"])

    lvY := yTool + 40
    lvH := 380
    g_EditorLineList := EditorLineList(EditorGui, xCard+20, lvY, leftW - 16, lvH, EditorOnSelect)
    for idx, line in slot["lines"] {
        delayText := line["delay"] > 0 ? line["delay"] : "—"
        g_EditorLineList.Add("", idx, line["text"], delayText)
    }

    EditorGui.SetFont("s10 bold", THEME["fontFamily"])
    EditorGui.AddText("x" xRight " y" yMain " w200 h18 c" THEME["text"] " BackgroundTrans", "РЕДАКТИРОВАНИЕ")
    EditorGui.SetFont("s8 norm", THEME["fontFamily"])
    EditorGui.AddText("x" (xRight+rightW-150) " y" (yMain+2) " w150 Right c" THEME["textMuted"] " BackgroundTrans vEditorRowLabel", "Строка не выбрана")

    yTags := yMain + 28
    EditorGui.SetFont("s8 bold", THEME["fontFamily"])
    EditorGui.AddText("x" xRight " y" yTags " w200 h14 c" THEME["textMuted"] " BackgroundTrans", "БЫСТРЫЕ ВСТАВКИ")
    yTags += 18
    EditorChip(EditorGui, xRight, yTags, 52, 26, "{P}", (*) => EditorInsertTag("{P}"))
    EditorChip(EditorGui, xRight+58, yTags, 58, 26, "{MY}", (*) => EditorInsertTag("{MY}"))
    EditorChip(EditorGui, xRight+122, yTags, 68, 26, "{HOSP}", (*) => EditorInsertTag("{HOSPITAL}"))
    EditorChip(EditorGui, xRight+196, yTags, 68, 26, "{SPEC}", (*) => EditorInsertTag("{SPECIALTY}"))

    yCmds := yTags + 36
    EditorGui.SetFont("s8 bold", THEME["fontFamily"])
    EditorGui.AddText("x" xRight " y" yCmds " w200 h14 c" THEME["textMuted"] " BackgroundTrans", "КОМАНДЫ")
    yCmds += 18
    EditorChip(EditorGui, xRight, yCmds, 48, 26, "/я", (*) => EditorInsertTag("/я "))
    EditorChip(EditorGui, xRight+54, yCmds, 48, 26, "/фд", (*) => EditorInsertTag("/фд "))
    EditorChip(EditorGui, xRight+108, yCmds, 48, 26, "/де", (*) => EditorInsertTag("/де "))
    EditorChip(EditorGui, xRight+162, yCmds, 72, 26, "/шепот", (*) => EditorInsertTag("/шепот "))

    yEdit := yCmds + 40
    EditorGui.SetFont("s8 bold", THEME["fontFamily"])
    EditorGui.AddText("x" xRight " y" yEdit " w200 h14 c" THEME["textMuted"] " BackgroundTrans", "ТЕКСТ СТРОКИ")
    yEdit += 18
    hEdit := 70
    editField := CreateInput(EditorGui, xRight, yEdit, rightW, hEdit, "Multi vCurrentLineText Disabled", "", 10, THEME["card"])
    EditorEditBox := editField.ctrl
    SetDarkControl(EditorEditBox)
    EditorEditBox.OnEvent("Change", EditorSyncText)

    yDelay := yEdit + hEdit + 12
    EditorGui.SetFont("s8 bold", THEME["fontFamily"])
    EditorGui.AddText("x" xRight " y" yDelay " w220 h14 c" THEME["textMuted"] " BackgroundTrans", "ЗАДЕРЖКА ОТПРАВКИ")
    yDelay += 18
    delayField := CreateInput(EditorGui, xRight, yDelay, 88, 32, "Number Center vCurrentLineDelay Disabled", "", 10, THEME["card"])
    EditorDelayBox := delayField.ctrl
    EditorDelayBox.OnEvent("Change", EditorHandleDelayInput)
    msLab := EditorGui.AddText("x" (xRight+96) " y" (yDelay+8) " w36 h16 BackgroundTrans c" THEME["textDim"], "мс")
    msLab.SetFont("s9 norm", THEME["fontFamily"])

    BtnConfirmDelay := CreateOutlineBtn(EditorGui, xRight+134, yDelay, 32, 32, "✓", (*) => EditorConfirmDelay(), "primary")
    BtnConfirmDelay.SetBackdrop(THEME["card"])
    OutlineSetVisible(BtnConfirmDelay, false)
    EditorChip(EditorGui, xRight+174, yDelay, 56, 32, "1200", (*) => EditorSetDelay(1200))
    EditorChip(EditorGui, xRight+234, yDelay, 56, 32, "2300", (*) => EditorSetDelay(2300))
    EditorChip(EditorGui, xRight+294, yDelay, 56, 32, "3000", (*) => EditorSetDelay(3000))

    yApply := yDelay + 40
    EditorChip(EditorGui, xRight, yApply, 220, 30, "Применить ко всем строкам", (*) => EditorApplyDelayToAll())

    yPreview := yApply + 40
    EditorGui.SetFont("s8 bold", THEME["fontFamily"])
    EditorGui.AddText("x" xRight " y" yPreview " w200 h14 c" THEME["textMuted"] " BackgroundTrans", "ПРЕДПРОСМОТР")
    yPreview += 18
    preview := EditorGui.AddText("x" xRight " y" yPreview " w" rightW " h70 Background0d1117", "")
    RoundCorners(preview, rightW, 70, 8)
    SendPanelToBack(preview)
    EditorGui.SetFont("s9 norm", THEME["fontFamily"])
    EditorGui.AddText("x" (xRight+12) " y" (yPreview+12) " w" (rightW-24) " h46 c" THEME["text"] " BackgroundTrans vEditorPreview", "Выберите строку...")

    yFooter := 668
    EditorGui.SetFont("s8 norm", THEME["fontFamily"])
    EditorGui.AddText("x22 y" (yFooter+10) " w420 c" THEME["textMuted"] " BackgroundTrans", "Изменения применятся после сохранения")
    CreateOutlineBtn(EditorGui, totalW-360, yFooter, 150, 36, "Отмена", (*) => SafeCloseEditor(), "default").SetBackdrop(THEME["bg"])
    btnSaveBind := CreateOutlineBtn(EditorGui, totalW-194, yFooter, 174, 36, "Сохранить бинд", (*) => SaveModernEditor(), "primary")
    btnSaveBind.SetBackdrop(THEME["bg"])
    btnSaveBind.ctrl.SetFont("s9 bold", THEME["fontFamily"])

    if (g_EditorLineList.GetCount() > 0) {
        g_EditorLineList.Modify(1, "Select Focus")
    } else {
        EditorEditBox.Value := "Добавьте первую строку кнопкой слева..."
    }
    
    xPos := (A_ScreenWidth - totalW) // 2
    yPos := (A_ScreenHeight - totalH) // 2
    EditorGui.Show("x" xPos " y" yPos " w" totalW " h" totalH)
    try RoundCorners(EditorGui, totalW, totalH, THEME["radiusWin"])
}

; ══════════════════════════════════════════════════════════════════════════
; ЛОГИКА РЕДАКТОРА (НЕТ ДУБЛИКАТОВ)
; ══════════════════════════════════════════════════════════════════════════

; 1. Текст всегда сохраняется сразу
EditorSyncText(*) {
    global EditorGui, CurrentSelectedRow, SLOTS, CurrentEditSlot, EditorHasChanges, g_EditorLineList
    
    if (CurrentSelectedRow > 0) {
        text := EditorGui["CurrentLineText"].Value
        SLOTS[CurrentEditSlot]["lines"][CurrentSelectedRow]["text"] := text
        
        ; Обновляем ListView (Колонка 2)
        g_EditorLineList.Modify(CurrentSelectedRow, "Col2", text)
        EditorHasChanges := true
        UpdateEditorPreview()
    }
}

; 2. УМНЫЙ ОБРАБОТЧИК ВВОДА ЗАДЕРЖКИ
EditorHandleDelayInput(*) {
    global CFG, BtnConfirmDelay
    
    ; Если настройки еще не загружены или ключа нет - считаем false
    if (!CFG.Has("editorAutoSaveDelay"))
        CFG["editorAutoSaveDelay"] := false

    if (CFG["editorAutoSaveDelay"]) {
        ; Если авто-сохранение ВКЛ -> Сохраняем сразу (скрытый режим)
        EditorConfirmDelay(true) 
    } else {
        ; Если авто-сохранение ВЫКЛ -> Показываем галочку
        if BtnConfirmDelay
            OutlineSetVisible(BtnConfirmDelay, true)
    }
}

; 3. Функция подтверждения (нажатие на галочку или авто-вызов)
EditorConfirmDelay(silentMode := false) {
    global EditorGui, CurrentSelectedRow, SLOTS, CurrentEditSlot, EditorHasChanges, BtnConfirmDelay, g_EditorLineList
    
    if (CurrentSelectedRow > 0) {
        newDelay := EditorGui["CurrentLineDelay"].Value
        if (newDelay = "")
            newDelay := 0
            
        SLOTS[CurrentEditSlot]["lines"][CurrentSelectedRow]["delay"] := Integer(newDelay)
        
        ; Обновляем список (Колонка 3)
        delayText := Integer(newDelay) > 0 ? newDelay : "—"
        g_EditorLineList.Modify(CurrentSelectedRow, "Col3", delayText)
        
        EditorHasChanges := true
        
        ; Скрываем галочку, если это ручной режим
        if (!silentMode && BtnConfirmDelay)
            OutlineSetVisible(BtnConfirmDelay, false)
    }
}

; 4. Пресеты (всегда применяются сразу)
EditorSetDelay(value) {
    global EditorDelayBox, CurrentSelectedRow, BtnConfirmDelay
    
    if (CurrentSelectedRow = 0) {
        ShowNotify("Выберите строку", "warning")
        return
    }
    
    EditorDelayBox.Value := value
    EditorConfirmDelay(false) ; Применяем и скрываем галочку
}

; 5. При выборе строки обновляем поля и скрываем галочку
EditorOnSelect(lv, row, selected) {
    global EditorGui, SLOTS, CurrentEditSlot, CurrentSelectedRow, EditorEditBox, EditorDelayBox, BtnConfirmDelay, g_EditorLineList
    
    if !selected
        return

    CurrentSelectedRow := row
    slot := SLOTS[CurrentEditSlot]
    
    if (row <= slot["lines"].Length) {
        lineData := slot["lines"][row]
        
        EditorEditBox.Value := lineData["text"]
        EditorDelayBox.Value := lineData["delay"]
        
        EditorEditBox.Opt("-Disabled")
        EditorDelayBox.Opt("-Disabled")
        
        try EditorGui["EditorRowLabel"].Text := "Строка " row "/" slot["lines"].Length
        
        ; СКРЫВАЕМ ГАЛОЧКУ при смене строки
        if BtnConfirmDelay
            OutlineSetVisible(BtnConfirmDelay, false)
            
        UpdateEditorPreview()
    }
}

; 6. Применить ко всем (Исправленная версия)
EditorApplyDelayToAll(*) {
    global EditorGui, SLOTS, CurrentEditSlot, EditorHasChanges, EditorDelayBox, g_EditorLineList
    
    newDelay := EditorDelayBox.Value
    
    if (newDelay = "" || !IsNumber(newDelay)) {
        ShowNotify("Введите число!", "warning")
        return
    }
    
    lines := SLOTS[CurrentEditSlot]["lines"]
    count := lines.Length
    
    if (count = 0)
        return
    
    for line in lines {
        line["delay"] := Integer(newDelay)
    }
    
    ; Моментальное обновление списка
    lv := g_EditorLineList
    lv.Opt("-Redraw")
    Loop count {
        delayText := Integer(newDelay) > 0 ? newDelay : "—"
        lv.Modify(A_Index, "Col3", delayText)
    }
    lv.Opt("+Redraw")
    
    EditorHasChanges := true
    ShowNotify("Применено к " count " строкам", "success")
}

EditorAddRow(*) {
    global EditorGui, SLOTS, CurrentEditSlot, CurrentSelectedRow, EditorHasChanges, g_EditorLineList
    
    SLOTS[CurrentEditSlot]["lines"].Push(Map("text", "Новая строка", "delay", 2300))
    
    lv := g_EditorLineList
    newRow := lv.GetCount() + 1
    lv.Add("", newRow, "Новая строка", 2300)
    lv.Modify(newRow, "Select Focus")
    EditorHasChanges := true
    UpdateEditorLineCount()
}

EditorDeleteRow(*) {
    global EditorGui, SLOTS, CurrentEditSlot, CurrentSelectedRow, EditorHasChanges, EditorEditBox, EditorDelayBox, EditorConfirmDelete, g_EditorLineList
    
    if (CurrentSelectedRow == 0) {
        ShowNotify("Выберите строку", "warning")
        return
    }
    
    if EditorConfirmDelete {
        res := MsgBox("Удалить строку?", "Редактор", "YesNo Icon?")
        if res = "No"
            return
    }
        
    SLOTS[CurrentEditSlot]["lines"].RemoveAt(CurrentSelectedRow)
    g_EditorLineList.Delete(CurrentSelectedRow)
    
    Loop g_EditorLineList.GetCount() {
        g_EditorLineList.Modify(A_Index, , A_Index)
    }
    
    EditorHasChanges := true
    CurrentSelectedRow := 0
    EditorEditBox.Value := ""
    EditorDelayBox.Value := ""
    EditorEditBox.Opt("+Disabled")
    EditorDelayBox.Opt("+Disabled")
    UpdateEditorLineCount()
}

EditorMoveUp(*) {
    global EditorGui, SLOTS, CurrentEditSlot, CurrentSelectedRow, EditorHasChanges, g_EditorLineList
    
    if (CurrentSelectedRow <= 1)
        return
        
    lines := SLOTS[CurrentEditSlot]["lines"]
    
    temp := lines[CurrentSelectedRow]
    lines[CurrentSelectedRow] := lines[CurrentSelectedRow - 1]
    lines[CurrentSelectedRow - 1] := temp
    
    RefreshEditorList()
    
    g_EditorLineList.Modify(CurrentSelectedRow - 1, "Select Focus")
    EditorHasChanges := true
}

EditorMoveDown(*) {
    global EditorGui, SLOTS, CurrentEditSlot, CurrentSelectedRow, EditorHasChanges, g_EditorLineList
    
    lines := SLOTS[CurrentEditSlot]["lines"]
    if (CurrentSelectedRow >= lines.Length || CurrentSelectedRow == 0)
        return
        
    temp := lines[CurrentSelectedRow]
    lines[CurrentSelectedRow] := lines[CurrentSelectedRow + 1]
    lines[CurrentSelectedRow + 1] := temp
    
    RefreshEditorList()
    
    g_EditorLineList.Modify(CurrentSelectedRow + 1, "Select Focus")
    EditorHasChanges := true
}

RefreshEditorList() {
    global EditorGui, SLOTS, CurrentEditSlot, g_EditorLineList
    lv := g_EditorLineList
    lv.Opt("-Redraw")
    lv.Delete()
    
    for idx, line in SLOTS[CurrentEditSlot]["lines"] {
        delayText := line["delay"] > 0 ? line["delay"] : "—"
        lv.Add("", idx, line["text"], delayText)
    }
    lv.Opt("+Redraw")
    
    UpdateEditorLineCount()
}

; Вставляет текст в Edit-поле в текущую позицию курсора (через EM_REPLACESEL).
; Раньше этой функции не было — кнопки тегов ({P}, /я, /фд и т.д.) молча не работали.
EditPaste(text, ctrl) {
    if !IsObject(ctrl)
        return
    ; EM_REPLACESEL (0xC2): заменяет текущее (пустое) выделение на текст,
    ; т.е. вставляет текст в позицию курсора. wParam=true — разрешаем отмену (Ctrl+Z).
    SendMessage(0xC2, true, StrPtr(text), ctrl.Hwnd)
}

EditorInsertTag(tag) {
    global EditorEditBox
    
    if !EditorEditBox || !EditorEditBox.Enabled
        return

    ; Коррекция тегов
    if (tag = "{RANK}")    ; ← Убрали "else" — после return он не нужен
        tag := "{SPECIALTY}"

    ; 1. Получаем, где стоял курсор до потери фокуса
    StartBuf := Buffer(4, 0)
    EndBuf := Buffer(4, 0)
    SendMessage(0xB0, StartBuf.Ptr, EndBuf.Ptr, EditorEditBox.Hwnd) ; EM_GETSEL
    SavedStart := NumGet(StartBuf, 0, "UInt")
    SavedEnd   := NumGet(EndBuf, 0, "UInt")

    ; 2. Возвращаем фокус (Windows может выделить весь текст автоматом)
    try EditorEditBox.Focus()

    ; 3. Принудительно возвращаем курсор на старое место (снимаем выделение всего текста)
    SendMessage(0xB1, SavedStart, SavedEnd, EditorEditBox.Hwnd) ; EM_SETSEL

    ; 4. Вставляем текст в позицию курсора
    try EditPaste(tag, EditorEditBox)

    ; 5. Сохраняем
    EditorSyncText()
    MarkUnsaved()
}

; === СОХРАНЕНИЕ ===
SaveModernEditor() {
    global EditorGui, SLOTS, CurrentEditSlot
    
    try {
        slot := SLOTS[CurrentEditSlot]
        
        slot["name"] := Trim(EditorGui["EditorName"].Value)
        slot["hotkey"] := Trim(EditorGui["EditorHotkey"].Value)
        slot["enabled"] := EditorGui["EditorEnabled"].Value = 1
        
        categories := ["Основные", "Лечение", "Медосмотр", "Вакцины", "Операции", "Быстрые", "Утилиты"]
        slot["category"] := categories[EditorGui["EditorCategory"].Value]
        statTypes := ["", "pills", "inject", "operation", "medcheck", "vaccine"]
        try slot["statType"] := statTypes[EditorGui["EditorStatType"].Value]
        
        CleanupHoverButtons(EditorGui)
        EditorGui.Destroy()
        EditorGui := ""
        
        RefreshBindList()
        UpdateOverlayData()
        RegisterAllHotkeys()
        MarkUnsaved()
        
        ShowNotify("Бинд сохранён!", "success")
        
    } catch as err {
        ShowNotify("Ошибка: " err.Message, "error")
    }
}


OnSearchChange(*) {
    global CurrentSearch, MainGui
    
    if !MainGui
        return
    
    try {
        CurrentSearch := MainGui["BindSearch"].Value
        RefreshBindList()
    }
}


; === БЕЗОПАСНЫЙ ВЫХОД ===
SafeCloseEditor() {
    global EditorGui, EditorHasChanges, GlobalUnsavedChanges, WasDirtyBeforeEditor, g_BtnGlobalSave
    
    if !EditorHasChanges {
        CleanupHoverButtons(EditorGui)
        EditorGui.Destroy()
        EditorGui := ""
        return
    }
    
    result := MsgBox("Есть несохраненные изменения. Сохранить?", "Редактор", "YesNoCancel Icon?")
    
    if result = "Yes" {
        SaveModernEditor()
    }
    else if result = "No" {
        CleanupHoverButtons(EditorGui)
        EditorGui.Destroy()
        EditorGui := ""
        
        Undo() ; Откатываем изменения в массиве
        
        ; === ИСПРАВЛЕНИЕ ===
        ; Возвращаем статус сохранения, который был ДО открытия редактора
        GlobalUnsavedChanges := WasDirtyBeforeEditor
        
        ; Обновляем визуальное состояние большой кнопки "Сохранить все"
        if g_BtnGlobalSave {
            if GlobalUnsavedChanges {
                UpdateButtonState(g_BtnGlobalSave, true, "primary")
                g_BtnGlobalSave.ctrl.Text := "Сохранить изменения"
            } else {
                UpdateButtonState(g_BtnGlobalSave, false)
                g_BtnGlobalSave.ctrl.Text := "Сохранить изменения"
            }
            try UpdateSaveBar(GlobalUnsavedChanges)
        }
        ; ===================
    }
    ; Если Cancel - ничего не делаем, остаемся в редакторе
}

; ═══════════════════════════════════════════════════════════════════════════════
; ВСТРОЕННЫЙ ЗАХВАТ КЛАВИШ В РЕДАКТОРЕ
; ═══════════════════════════════════════════════════════════════════════════════

EditorStartCapture() {
    global EditorGui, EditorKeyDisplay, THEME, EditorInputHook, EditorBlinkState
    
    if !EditorGui
        return
        
    ; Визуальный старт
    EditorKeyDisplay.Text := "НАЖМИТЕ КЛАВИШУ…"
    SetButtonVisualByControl(EditorKeyDisplay, THEME["accent"], THEME["field"])
    EditorBlinkState := true
    SetTimer(EditorCaptureBlink, 500)
    
    ; Запуск хука
    if EditorInputHook
        try EditorInputHook.Stop()
        
    EditorInputHook := InputHook("L0 T30")
    EditorInputHook.KeyOpt("{All}", "N")
    EditorInputHook.OnKeyDown := EditorInlineHandler
    EditorInputHook.Start()
}

EditorCaptureBlink() {
    global EditorGui, EditorKeyDisplay, THEME, EditorBlinkState
    
    if !EditorGui || !EditorKeyDisplay
        return
        
    EditorBlinkState := !EditorBlinkState
    if EditorBlinkState
        SetButtonVisualByControl(EditorKeyDisplay, THEME["warning"])
    else
        SetButtonVisualByControl(EditorKeyDisplay, THEME["error"])
        
    EditorKeyDisplay.Redraw()
}

EditorInlineHandler(ih, vk, sc) {
    global EditorGui, EditorKeyDisplay, THEME, EditorInputHook, CurrentEditSlot
    
    keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    
    ; === ИСПРАВЛЕНИЕ ===
    ; Если нажата только клавиша-модификатор — ничего не делаем, 
    ; ждем, пока будет нажата основная клавиша (например, 6).
    if (keyName = "Control" || keyName = "LControl" || keyName = "RControl"
     || keyName = "Alt"     || keyName = "LAlt"     || keyName = "RAlt"
     || keyName = "Shift"   || keyName = "LShift"   || keyName = "RShift"
     || keyName = "LWin"    || keyName = "RWin") 
    {
        return 
    }
    ; ===================
    
    ; Останавливаем мигание и хук только теперь
    SetTimer(EditorCaptureBlink, 0)
    ih.Stop()
    
    ; Отмена по ESC
    if (keyName = "Escape") {
        oldVal := EditorGui["EditorHotkey"].Value
        EditorKeyDisplay.Text := oldVal = "" ? "Нажмите для выбора" : FormatHotkey(oldVal)
        SetButtonVisualByControl(EditorKeyDisplay, oldVal="" ? THEME["textMuted"] : THEME["accent"])
        EditorKeyDisplay.Redraw()
        return
    }
    
    ; Собираем модификаторы (какие кнопки сейчас зажаты)
    mods := ""
    if GetKeyState("Ctrl", "P")
        mods .= "^"
    if GetKeyState("Alt", "P")
        mods .= "!"
    if GetKeyState("Shift", "P")
        mods .= "+"
    if GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
        mods .= "#"
    
    fullKey := mods . keyName
    
    ; Проверка конфликтов
    conflictName := CheckHotkeyConflict(fullKey, CurrentEditSlot)
    
    if (conflictName != "") {
        ShowEditorConflictDialog(fullKey, conflictName)
    } else {
        ApplyEditorInlineKey(fullKey)
    }
}

ApplyEditorInlineKey(key) {
    global EditorGui, EditorKeyDisplay, THEME
    
    EditorGui["EditorHotkey"].Value := key
    EditorKeyDisplay.Text := FormatHotkey(key)
    SetButtonVisualByControl(EditorKeyDisplay, THEME["success"])
    EditorKeyDisplay.Redraw()
}


ApplyEditorHotkey(gui) {
    global EditorGui, CurrentEditSlot, CapturedEditorKey, THEME, EditorKeyDisplay
    
    if CapturedEditorKey = "" {
        ShowNotify("Не захвачена!", "warning")
        return
    }
    
    conflict := CheckHotkeyConflict(CapturedEditorKey, CurrentEditSlot)
    if conflict != "" {
        gui.Destroy()
        ShowEditorConflictDialog(CapturedEditorKey, conflict)
    } else {
        EditorGui["EditorHotkey"].Value := CapturedEditorKey
        EditorKeyDisplay.Text := FormatHotkey(CapturedEditorKey)
        SetButtonVisualByControl(EditorKeyDisplay, THEME["accent"])
        gui.Destroy()
        ShowNotify("Клавиша: " CapturedEditorKey, "success")
    }
}

; ═══════════════════════════════════════════════════════════════════════════
; КРАСИВОЕ КОНТЕКСТНОЕ МЕНЮ (Финальная рабочая версия 4.0)
; ═══════════════════════════════════════════════════════════════════════════

SetEditorDropdowns(slot) {
    global EditorGui, g_EditorCategory
    
    ; Категория
    categories := ["Основные", "Лечение", "Медосмотр", "Вакцины", "Операции", "Быстрые", "Утилиты"]
    catIndex := 1
    if slot.Has("category") && slot["category"] != "" {
        for idx, cat in categories {
            if cat = slot["category"] {
                catIndex := idx
                break
            }
        }
    }
    try {
        if IsObject(g_EditorCategory)
            g_EditorCategory.Value := catIndex
        else
            EditorGui["EditorCategory"].Value := catIndex
    }
    
    ; Статистика (скрытый список)
    statTypes := ["", "pills", "inject", "operation", "medcheck", "vaccine"]
    statIndex := 1
    if slot.Has("statType") && slot["statType"] != "" {
        for idx, stat in statTypes {
            if stat = slot["statType"] {
                statIndex := idx
                break
            }
        }
    }
    try EditorGui["EditorStatType"].Value := statIndex
}

SetEditorStatTypeVisible(slot) {
    global EditorGui, g_EditorStatVisible
    
    ; Маппинг кодов статистики на индексы видимого списка
    statMap := Map("", 1, "pills", 2, "inject", 3, "operation", 4, "medcheck", 5, "vaccine", 6)
    
    statType := slot.Has("statType") ? slot["statType"] : ""
    idx := statMap.Has(statType) ? statMap[statType] : 1
    
    try {
        if IsObject(g_EditorStatVisible)
            g_EditorStatVisible.Value := idx
        else
            EditorGui["EditorStatTypeVisible"].Value := idx
    }
}

SyncStatTypeFromVisible(*) {
    global EditorGui, EditorHasChanges
    
    ; Синхронизация: Видимый список -> Скрытый список (который хранит коды)
    idx := EditorGui["EditorStatTypeVisible"].Value
    try EditorGui["EditorStatType"].Value := idx
    EditorHasChanges := true
}

UpdateEditorLineCount() {
    global EditorGui, SLOTS, CurrentEditSlot
    
    if !EditorGui
        return
    
    count := SLOTS[CurrentEditSlot]["lines"].Length
    try EditorGui["EditorLineCount"].Text := EditorLineCountText(count)
}

EditorLineCountText(count) {
    n := Integer(count)
    if (n = 1)
        return "1 строка"
    if (n >= 2 && n <= 4)
        return n " строки"
    return n " строк"
}

UpdateEditorPreview() {
    global EditorGui, SLOTS, CurrentEditSlot, CurrentSelectedRow, STATE
    
    if !EditorGui
        return
    
    if (CurrentSelectedRow = 0) {
        try EditorGui["EditorPreview"].Text := "Выберите строку для предпросмотра..."
        return
    }
    
    slot := SLOTS[CurrentEditSlot]
    if (CurrentSelectedRow > slot["lines"].Length)
        return
    
    text := slot["lines"][CurrentSelectedRow]["text"]
    
    ; Подставляем переменные для превью
    text := StrReplace(text, "{P}", STATE["patientId"] != "" ? STATE["patientId"] : "[ID]")
    text := StrReplace(text, "{MY}", STATE["myName"] != "" ? STATE["myName"] : "[Имя]")
    text := StrReplace(text, "{HOSPITAL}", STATE["hospital"])
    text := StrReplace(text, "{SPECIALTY}", STATE["specialty"])
    text := StrReplace(text, "{RANK}", STATE["specialty"])
    
    try EditorGui["EditorPreview"].Text := "▶ " text
}

EditorDuplicateRow(*) {
    global EditorGui, SLOTS, CurrentEditSlot, CurrentSelectedRow, EditorHasChanges
    
    if (CurrentSelectedRow = 0) {
        ShowNotify("Выберите строку для копирования", "warning")
        return
    }
    
    slot := SLOTS[CurrentEditSlot]
    if (CurrentSelectedRow > slot["lines"].Length)
        return
    
    original := slot["lines"][CurrentSelectedRow]
    newLine := Map("text", original["text"], "delay", original["delay"])
    
    ; Вставляем после текущей строки
    slot["lines"].InsertAt(CurrentSelectedRow + 1, newLine)
    
    ; Обновляем ListView
    RefreshEditorList()
    
    ; Выбираем новую строку
    g_EditorLineList.Modify(CurrentSelectedRow + 1, "Select Focus")
    
    EditorHasChanges := true
    UpdateEditorLineCount()
    ShowNotify("Строка скопирована", "success")
}

; ══════════════════════════════════════════════════════════════════════════
; ФОРМАТИРОВАНИЕ ГОРЯЧИХ КЛАВИШ (ВСТАВИТЬ В КОНЕЦ ФАЙЛА)
; ══════════════════════════════════════════════════════════════════════════
