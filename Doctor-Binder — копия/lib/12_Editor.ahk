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
    global MainGui
    
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
    
    totalW := 1000
    totalH := 760
    
    EditorGui := Gui("-Resize -Caption +Border +Owner" MainGui.Hwnd, "Bind Editor")
    EditorGui.BackColor := THEME["bg"]
    EditorGui.SetFont("s10 c" THEME["text"], "Segoe UI")
    EditorGui.OnEvent("Close", (*) => SafeCloseEditor())
    
    try {
        if VerCompare(A_OSVersion, "10.0.17763") >= 0 {
            IsDark := 1
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", EditorGui.Hwnd, "Int", 20, "Int*", IsDark, "Int", 4)
        }
    }
    
    ; --- СОВРЕМЕННАЯ ШАПКА ---
    EditorGui.SetFont("s12 bold", "Segoe UI")
    EditorGui.AddText("x22 y14 w520 h28 c" THEME["text"] " BackgroundTrans", "Редактор бинда")
    EditorGui.SetFont("s9", "Segoe UI")
    EditorGui.AddText("x22 y40 w560 h20 c" THEME["textDim"] " BackgroundTrans", "Настройте горячую клавишу, текст и задержки")

    bindTitle := slot["name"] != "" ? slot["name"] : "Новый бинд"
    EditorGui.SetFont("s9 bold", "Segoe UI")
    EditorGui.AddText("x640 y18 w240 h24 Right c" THEME["accent"] " BackgroundTrans", bindTitle)

    CloseBtn := CreateStyledButton(EditorGui, totalW - 48, 8, 36, 36, "x", (*) => SafeCloseEditor(), "danger")
    CloseBtn.ctrl.SetFont("s11 bold", "Segoe UI")

    ; --- КАРТОЧКА ОСНОВНЫХ ПАРАМЕТРОВ ---
    yInfo := 72
    cardW := totalW - 40
    cardH := 82
    xCard := 20
    infoCard := EditorGui.AddText("x" xCard " y" yInfo " w" cardW " h" cardH " Background" THEME["bgLight"], "")
    RoundCorners(infoCard, cardW, cardH, 14)
    SendPanelToBack(infoCard)

    yRow := yInfo + 28
    xIn := xCard + 20
    EditorGui.SetFont("s8 bold", "Segoe UI")
    EditorGui.AddText("x" xIn " y" (yRow-18) " w200 c" THEME["textDim"] " BackgroundTrans", "НАЗВАНИЕ БИНДА")
    EditorGui.SetFont("s10", "Segoe UI")
    nameBox := EditorGui.AddEdit("x" xIn " y" yRow " w250 h32 Background" THEME["bgHighlight"] " c" THEME["text"] " vEditorName", slot["name"])
    RoundCorners(nameBox, 250, 32, 8)
    xIn += 270

    EditorGui.SetFont("s8 bold", "Segoe UI")
    EditorGui.AddText("x" xIn " y" (yRow-18) " w130 c" THEME["textDim"] " BackgroundTrans", "ГОРЯЧАЯ КЛАВИША")
    hkDisplay := slot["hotkey"] = "" ? "Нажмите..." : FormatHotkey(slot["hotkey"])
    hkColor := slot["hotkey"] = "" ? THEME["textMuted"] : THEME["accent"]
    EditorGui.SetFont("s10 bold", "Segoe UI")
    EditorKeyButton := CreateStyledButton(EditorGui, xIn, yRow, 130, 32, hkDisplay, (*) => EditorStartCapture(), "default")
    EditorKeyButton.ctrl.Name := "EditorKeyDisplay"
    EditorKeyButton.SetVisual(THEME["bgHighlight"], hkColor, THEME["bgHover"])
    EditorKeyDisplay := EditorKeyButton.ctrl
    EditorGui.AddEdit("x0 y0 w0 h0 Hidden vEditorHotkey", slot["hotkey"])
    xIn += 150

    EditorGui.SetFont("s8 bold", "Segoe UI")
    EditorGui.AddText("x" xIn " y" (yRow-18) " w130 c" THEME["textDim"] " BackgroundTrans", "КАТЕГОРИЯ")
    EditorGui.SetFont("s9", "Segoe UI")
    categoryBox := EditorGui.AddDropDownList("x" xIn " y" yRow " w130 h32 vEditorCategory Choose1 Background" THEME["bgHighlight"] " c" THEME["text"], ["Основные", "Лечение", "Медосмотр", "Вакцины", "Операции", "Быстрые", "Утилиты"])
    xIn += 150

    EditorGui.SetFont("s8 bold", "Segoe UI")
    EditorGui.AddText("x" xIn " y" (yRow-18) " w120 c" THEME["textDim"] " BackgroundTrans", "В СТАТИСТИКУ")
    EditorGui.SetFont("s9", "Segoe UI")
    statBox := EditorGui.AddDropDownList("x" xIn " y" yRow " w120 h32 vEditorStatTypeVisible Choose1 Background" THEME["bgHighlight"] " c" THEME["text"], ["—", "Таблетки", "Уколы", "Операции", "Медкарты", "Вакцины"])
    EditorGui.AddDropDownList("x0 y0 w0 Hidden vEditorStatType Choose1", ["", "pills", "inject", "operation", "medcheck", "vaccine"])
    SetEditorDropdowns(slot)
    SetEditorStatTypeVisible(slot)
    EditorGui["EditorStatTypeVisible"].OnEvent("Change", (*) => SyncStatTypeFromVisible())
    xIn += 140

    EditorGui.SetFont("s9 bold", "Segoe UI")
    EditorGui.AddCheckbox("x" xIn " y" (yRow+5) " w100 vEditorEnabled c" THEME["success"] " Checked" (slot["enabled"] ? 1 : 0) " Background" THEME["bgLight"], " Активен")

    ; --- ОСНОВНАЯ ОБЛАСТЬ ---
    yMain := yInfo + cardH + 16
    leftW := 420
    mainH := 505

    leftCard := EditorGui.AddText("x" xCard " y" yMain " w" leftW " h" mainH " Background" THEME["bgLight"], "")
    RoundCorners(leftCard, leftW, mainH, 14)
    SendPanelToBack(leftCard)
    xRight := xCard + leftW + 20
    rightW := totalW - 40 - leftW - 20
    rightCard := EditorGui.AddText("x" xRight " y" yMain " w" rightW " h" mainH " Background" THEME["bgLight"], "")
    RoundCorners(rightCard, rightW, mainH, 14)
    SendPanelToBack(rightCard)

    ; --- ЛЕВАЯ: СТРОКИ ---
    EditorGui.SetFont("s11 bold", "Segoe UI")
    EditorGui.AddText("x" (xCard+18) " y" (yMain+16) " w200 c" THEME["text"] " BackgroundTrans", "Строки бинда")
    EditorGui.SetFont("s9", "Segoe UI")
    EditorGui.AddText("x" (xCard+leftW-125) " y" (yMain+19) " w105 Right c" THEME["textDim"] " BackgroundTrans vEditorLineCount", slot["lines"].Length " строк")

    yTool := yMain + 50
    CreateOutlineBtn(EditorGui, xCard+18, yTool, 108, 34, "+ Добавить", (*) => EditorAddRow(), "success")
    CreateOutlineBtn(EditorGui, xCard+134, yTool, 42, 34, "▲", (*) => EditorMoveUp(), "default")
    CreateOutlineBtn(EditorGui, xCard+182, yTool, 42, 34, "▼", (*) => EditorMoveDown(), "default")
    CreateOutlineBtn(EditorGui, xCard+230, yTool, 52, 34, "Копия", (*) => EditorDuplicateRow(), "info")
    CreateOutlineBtn(EditorGui, xCard+290, yTool, 62, 34, "Удалить", (*) => EditorDeleteRow(), "danger")

    EditorGui.AddText("x" (xCard+18) " y" (yTool+42) " w" (leftW-36) " h1 Background" THEME["borderLight"], "")

    lvY := yTool + 55
    lvH := mainH - (lvY - yMain) - 16
    EditorGui.SetFont("s9", "Segoe UI")
    lv := EditorGui.AddListView("x" (xCard+18) " y" lvY " w" (leftW-36) " h" lvH
        " Background" THEME["bg"] " c" THEME["text"]
        " vEditorLV -Hdr -Multi +LV0x4000", ["№", "Текст", "⏱"])
    SetDarkControl(lv)
    lv.ModifyCol(1, 35)
    lv.ModifyCol(2, leftW-130)
    lv.ModifyCol(3, 45)
    lv.OnEvent("ItemSelect", EditorOnSelect)

    for idx, line in slot["lines"] {
        delayText := line["delay"] > 0 ? line["delay"] : "—"
        lv.Add("", idx, line["text"], delayText)
    }

    ; --- ПРАВАЯ: РЕДАКТИРОВАНИЕ ---
    EditorGui.SetFont("s11 bold", "Segoe UI")
    EditorGui.AddText("x" (xRight+18) " y" (yMain+16) " w220 c" THEME["text"] " BackgroundTrans", "Редактирование")
    EditorGui.SetFont("s9", "Segoe UI")
    EditorGui.AddText("x" (xRight+rightW-150) " y" (yMain+19) " w130 Right c" THEME["textDim"] " BackgroundTrans vEditorRowLabel", "Строка не выбрана")

    yTags := yMain + 52
    EditorGui.SetFont("s8 bold", "Segoe UI")
    EditorGui.AddText("x" (xRight+18) " y" (yTags+8) " w40 c" THEME["textDim"] " BackgroundTrans", "ТЕГИ")
    CreateOutlineBtn(EditorGui, xRight+62, yTags, 48, 28, "{P}", (*) => EditorInsertTag("{P}"), "info")
    CreateOutlineBtn(EditorGui, xRight+116, yTags, 58, 28, "{MY}", (*) => EditorInsertTag("{MY}"), "info")
    CreateOutlineBtn(EditorGui, xRight+180, yTags, 72, 28, "{HOSP}", (*) => EditorInsertTag("{HOSPITAL}"), "info")
    CreateOutlineBtn(EditorGui, xRight+258, yTags, 72, 28, "{SPEC}", (*) => EditorInsertTag("{SPECIALTY}"), "info")

    yCmds := yTags + 36
    EditorGui.SetFont("s8 bold", "Segoe UI")
    EditorGui.AddText("x" (xRight+18) " y" (yCmds+8) " w100 c" THEME["textDim"] " BackgroundTrans", "КОМАНДЫ")
    CreateOutlineBtn(EditorGui, xRight+118, yCmds, 48, 28, "/я", (*) => EditorInsertTag("/я "), "default")
    CreateOutlineBtn(EditorGui, xRight+172, yCmds, 48, 28, "/фд", (*) => EditorInsertTag("/фд "), "default")
    CreateOutlineBtn(EditorGui, xRight+226, yCmds, 48, 28, "/де", (*) => EditorInsertTag("/де "), "default")
    CreateOutlineBtn(EditorGui, xRight+280, yCmds, 72, 28, "/шепот", (*) => EditorInsertTag("/шепот "), "default")

    yEdit := yCmds + 38
    hEdit := 178
    EditorGui.SetFont("s10", "Segoe UI")
    EditorEditBox := EditorGui.AddEdit("x" (xRight+18) " y" yEdit " w" (rightW-36) " h" hEdit " vCurrentLineText Background" THEME["bgHighlight"] " c" THEME["text"] " Disabled", "")
    SetDarkControl(EditorEditBox)
    EditorEditBox.OnEvent("Change", EditorSyncText)
    RoundCorners(EditorEditBox, rightW-36, hEdit, 9)

    ; --- ЗАДЕРЖКА ---
    yDelay := yEdit + hEdit + 12
    EditorGui.SetFont("s8 bold", "Segoe UI")
    EditorGui.AddText("x" (xRight+18) " y" (yDelay+8) " w90 c" THEME["textDim"] " BackgroundTrans", "ЗАДЕРЖКА")
    EditorGui.SetFont("s9", "Segoe UI")
    EditorDelayBox := EditorGui.AddEdit("x" (xRight+108) " y" yDelay " w80 h30 Number Center vCurrentLineDelay Background" THEME["bgHighlight"] " c" THEME["text"] " Disabled", "")
    RoundCorners(EditorDelayBox, 80, 30, 8)
    EditorDelayBox.OnEvent("Change", EditorHandleDelayInput)

    BtnConfirmDelay := CreateOutlineBtn(EditorGui, xRight+198, yDelay, 38, 30, "✓", (*) => EditorConfirmDelay(), "success")
    OutlineSetVisible(BtnConfirmDelay, false)
    CreateOutlineBtn(EditorGui, xRight+244, yDelay, 50, 30, "1200", (*) => EditorSetDelay(1200), "default")
    CreateOutlineBtn(EditorGui, xRight+300, yDelay, 50, 30, "2300", (*) => EditorSetDelay(2300), "default")
    CreateOutlineBtn(EditorGui, xRight+356, yDelay, 108, 30, "Применить всем", (*) => EditorApplyDelayToAll(), "warning")

    ; --- ПРЕДПРОСМОТР ---
    yPreview := yDelay + 42
    hPreview := mainH - (yPreview - yMain) - 16
    preview := EditorGui.AddText("x" (xRight+18) " y" yPreview " w" (rightW-36) " h" hPreview " Background" THEME["bg"], "")
    RoundCorners(preview, rightW-36, hPreview, 9)
    SendPanelToBack(preview)
    EditorGui.SetFont("s8 bold", "Segoe UI")
    EditorGui.AddText("x" (xRight+30) " y" (yPreview+8) " w220 c" THEME["accent"] " BackgroundTrans", "ПРЕДПРОСМОТР")
    EditorGui.SetFont("s9", "Segoe UI")
    EditorGui.AddText("x" (xRight+30) " y" (yPreview+30) " w" (rightW-60) " h" (hPreview-38) " c" THEME["text"] " BackgroundTrans vEditorPreview", "Выберите строку...")

    ; --- ПОДВАЛ ---
    yFooter := yMain + mainH + 16
    EditorGui.AddText("x20 y" (yFooter-8) " w" (totalW-40) " h1 Background" THEME["borderLight"], "")
    CreateOutlineBtn(EditorGui, 20, yFooter, 210, 44, "Сохранить изменения", (*) => SaveModernEditor(), "success")
    EditorGui.SetFont("s8 italic", "Segoe UI")
    EditorGui.AddText("x250 y" (yFooter+13) " w480 Center c" THEME["textMuted"] " BackgroundTrans", "Изменения применяются после сохранения")
    CreateOutlineBtn(EditorGui, totalW-190, yFooter, 170, 44, "Отмена", (*) => SafeCloseEditor(), "default")

    if (lv.GetCount() > 0) {
        lv.Modify(1, "Select Focus")
        EditorOnSelect(lv, 1, true)
    } else {
        EditorEditBox.Value := "Добавьте первую строку кнопкой слева..."
    }
    
    xPos := (A_ScreenWidth - totalW) // 2
    yPos := (A_ScreenHeight - totalH) // 2
    EditorGui.Show("x" xPos " y" yPos " w" totalW " h" totalH)
}

; ══════════════════════════════════════════════════════════════════════════
; ЛОГИКА РЕДАКТОРА (НЕТ ДУБЛИКАТОВ)
; ══════════════════════════════════════════════════════════════════════════

; 1. Текст всегда сохраняется сразу
EditorSyncText(*) {
    global EditorGui, CurrentSelectedRow, SLOTS, CurrentEditSlot, EditorHasChanges
    
    if (CurrentSelectedRow > 0) {
        text := EditorGui["CurrentLineText"].Value
        SLOTS[CurrentEditSlot]["lines"][CurrentSelectedRow]["text"] := text
        
        ; Обновляем ListView (Колонка 2)
        EditorGui["EditorLV"].Modify(CurrentSelectedRow, "Col2", text)
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
    global EditorGui, CurrentSelectedRow, SLOTS, CurrentEditSlot, EditorHasChanges, BtnConfirmDelay
    
    if (CurrentSelectedRow > 0) {
        newDelay := EditorGui["CurrentLineDelay"].Value
        if (newDelay = "")
            newDelay := 0
            
        SLOTS[CurrentEditSlot]["lines"][CurrentSelectedRow]["delay"] := Integer(newDelay)
        
        ; Обновляем список (Колонка 3)
        delayText := Integer(newDelay) > 0 ? newDelay : "—"
        EditorGui["EditorLV"].Modify(CurrentSelectedRow, "Col3", delayText)
        
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
    global EditorGui, SLOTS, CurrentEditSlot, CurrentSelectedRow, EditorEditBox, EditorDelayBox, BtnConfirmDelay
    
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
    global EditorGui, SLOTS, CurrentEditSlot, EditorHasChanges, EditorDelayBox
    
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
    lv := EditorGui["EditorLV"]
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
    global EditorGui, SLOTS, CurrentEditSlot, CurrentSelectedRow, EditorHasChanges
    
    SLOTS[CurrentEditSlot]["lines"].Push(Map("text", "Новая строка", "delay", 2300))
    
    lv := EditorGui["EditorLV"]
    newRow := lv.GetCount() + 1
    lv.Add("", newRow, "Новая строка")
    
    lv.Modify(newRow, "Select Focus")
    EditorHasChanges := true
}

EditorDeleteRow(*) {
    global EditorGui, SLOTS, CurrentEditSlot, CurrentSelectedRow, EditorHasChanges, EditorEditBox, EditorDelayBox, EditorConfirmDelete
    
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
    EditorGui["EditorLV"].Delete(CurrentSelectedRow)
    
    Loop EditorGui["EditorLV"].GetCount() {
        EditorGui["EditorLV"].Modify(A_Index, , A_Index)
    }
    
    EditorHasChanges := true
    CurrentSelectedRow := 0
    EditorEditBox.Value := ""
    EditorDelayBox.Value := ""
    EditorEditBox.Opt("+Disabled")
    EditorDelayBox.Opt("+Disabled")
}

EditorMoveUp(*) {
    global EditorGui, SLOTS, CurrentEditSlot, CurrentSelectedRow, EditorHasChanges
    
    if (CurrentSelectedRow <= 1)
        return
        
    lines := SLOTS[CurrentEditSlot]["lines"]
    
    temp := lines[CurrentSelectedRow]
    lines[CurrentSelectedRow] := lines[CurrentSelectedRow - 1]
    lines[CurrentSelectedRow - 1] := temp
    
    RefreshEditorList()
    
    EditorGui["EditorLV"].Modify(CurrentSelectedRow - 1, "Select Focus")
    EditorHasChanges := true
}

EditorMoveDown(*) {
    global EditorGui, SLOTS, CurrentEditSlot, CurrentSelectedRow, EditorHasChanges
    
    lines := SLOTS[CurrentEditSlot]["lines"]
    if (CurrentSelectedRow >= lines.Length || CurrentSelectedRow == 0)
        return
        
    temp := lines[CurrentSelectedRow]
    lines[CurrentSelectedRow] := lines[CurrentSelectedRow + 1]
    lines[CurrentSelectedRow + 1] := temp
    
    RefreshEditorList()
    
    EditorGui["EditorLV"].Modify(CurrentSelectedRow + 1, "Select Focus")
    EditorHasChanges := true
}

RefreshEditorList() {
    global EditorGui, SLOTS, CurrentEditSlot
    lv := EditorGui["EditorLV"]
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
        
        ; СтатТип не меняем в этом интерфейсе, чтобы не перегружать, но сохраняем старый
        ; Строки уже обновлены в массиве
        
        CleanupHoverButtons(EditorGui)
        EditorGui.Destroy()
        EditorGui := ""
        
        RefreshBindList()
        UpdateOverlayData()
        RegisterAllHotkeys()
        MarkUnsaved()
        
        ShowNotify("✅ Бинд сохранён!", "success")
        
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
                UpdateButtonState(g_BtnGlobalSave, true, "warning")
                g_BtnGlobalSave.ctrl.Text := "Сохранить изменения (!)"
            } else {
                UpdateButtonState(g_BtnGlobalSave, false)
                g_BtnGlobalSave.ctrl.Text := "Сохранить изменения"
            }
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
    EditorKeyDisplay.Text := ">>> НАЖМИТЕ КЛАВИШУ <<<"
    SetButtonVisualByControl(EditorKeyDisplay, THEME["warning"], THEME["bgHighlight"])
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
    global EditorGui
    
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
    try EditorGui["EditorCategory"].Value := catIndex
    
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
    global EditorGui
    
    ; Маппинг кодов статистики на индексы видимого списка
    statMap := Map("", 1, "pills", 2, "inject", 3, "operation", 4, "medcheck", 5, "vaccine", 6)
    
    statType := slot.Has("statType") ? slot["statType"] : ""
    idx := statMap.Has(statType) ? statMap[statType] : 1
    
    try EditorGui["EditorStatTypeVisible"].Value := idx
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
    try EditorGui["EditorLineCount"].Text := count " строк"
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
    EditorGui["EditorLV"].Modify(CurrentSelectedRow + 1, "Select Focus")
    
    EditorHasChanges := true
    UpdateEditorLineCount()
    ShowNotify("Строка скопирована", "success")
}

; ══════════════════════════════════════════════════════════════════════════
; ФОРМАТИРОВАНИЕ ГОРЯЧИХ КЛАВИШ (ВСТАВИТЬ В КОНЕЦ ФАЙЛА)
; ══════════════════════════════════════════════════════════════════════════
