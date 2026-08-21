; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: bindlist                      ║
; ║  Список биндов и захват клавиш                  ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
OnBindDoubleClick(lv, row) {
    if row = 0
        return
    
    slotIdx := Integer(lv.GetText(row, 1))
    OpenBindEditor(slotIdx)
}


RefreshBindList(filter := "") {
    global MainGui, SLOTS, CurrentFilter, FILTERS, CurrentSearch
    
    if !MainGui
        return
    
    ; Счётчики для дашборда статистики
    totalCount := 0
    Loop Constants.MAX_SLOTS {
        if SLOTS[A_Index]["name"] != ""
            totalCount++
    }

    if filter != ""
        CurrentFilter := filter
        
    try {
        lv := MainGui["BindList"]
        lv.Opt("-Redraw")
        lv.Delete()
        
        visibleCount := 0
        activeCount := 0
        
        Loop Constants.MAX_SLOTS {
            slot := SLOTS[A_Index]
            
            if slot["name"] = "" && slot["lines"].Length = 0
                continue
            
            shouldShow := true
            
            ; Поиск
            if (CurrentSearch != "") {
                searchStr := StrLower(CurrentSearch)
                nameLower := StrLower(slot["name"])
                keyLower := StrLower(slot["hotkey"])
                catLower := StrLower(slot.Has("category") ? slot["category"] : "")
                if (!InStr(nameLower, searchStr) && !InStr(keyLower, searchStr) && !InStr(catLower, searchStr))
                    shouldShow := false
            }
            
            ; Фильтры
            if shouldShow && CurrentFilter != "" && CurrentFilter != "Все" && FILTERS.Has(CurrentFilter) {
                condition := FILTERS[CurrentFilter]["condition"]
                if condition != "" {
                    if InStr(condition, "category=") {
                        cat := StrReplace(condition, "category=")
                        if !slot.Has("category") || slot["category"] != cat
                            shouldShow := false
                    }
                    else if condition = "enabled=true" {
                        if !slot["enabled"]
                            shouldShow := false
                    }
                }
            }
            
            if shouldShow {
                if slot["enabled"] {
                    status := "Вкл"
                    activeCount++
                } else {
                    status := "Выкл"
                }
                
                cat := slot.Has("category") ? slot["category"] : "—"
                hk := FormatHotkey(slot["hotkey"])
                lineCount := slot["lines"].Length
                
                lv.Add("", A_Index, slot["name"], cat, hk, lineCount, status)
                visibleCount++
            }
        }
        
        ; === ФИКС: Ширина должна совпадать с заголовком из Части 1 (320) ===
        lv.ModifyCol(2, 320) 
        
        lv.Opt("+Redraw")
        
        ; Скрываем горизонтальный скролл
        DllCall("ShowScrollBar", "Ptr", lv.Hwnd, "Int", 0, "Int", 0)
        
        MainGui["ListStatusLabel"].Text := "Показано: " visibleCount "  •  Активных: " activeCount
        try MainGui["StatTotalBinds"].Text := totalCount
        try MainGui["StatActiveBinds"].Text := activeCount
    }
}

BindPrevPage(*) {
    global CurrentPage
    if CurrentPage > 1 {
        CurrentPage--
        RefreshBindList()
    }
}

BindNextPage(*) {
    global CurrentPage, TotalPages
    if CurrentPage < TotalPages {
        CurrentPage++
        RefreshBindList()
    }
}

GetSelectedSlotIndex() {
    global MainGui
    row := MainGui["BindList"].GetNext()
    if row = 0
        return 0
    return Integer(MainGui["BindList"].GetText(row, 1))
}

CreateNewBind(*) {
    global SLOTS
    SaveUndoState("Создание бинда")
    targetSlot := 0
    Loop Constants.MAX_SLOTS {
        if SLOTS[A_Index]["name"] = "" || SLOTS[A_Index]["lines"].Length = 0 {
            targetSlot := A_Index
            break
        }
    }
    if targetSlot = 0 {
        ShowNotify("Все слоты заняты!", "error")
        return
    }
    SLOTS[targetSlot]["name"] := "Новый бинд"
    SLOTS[targetSlot]["enabled"] := true
    SLOTS[targetSlot]["hotkey"] := ""
    SLOTS[targetSlot]["category"] := "Основные"
    SLOTS[targetSlot]["statType"] := ""
    SLOTS[targetSlot]["lines"] := []
    
    RefreshBindList()
    OpenBindEditor(targetSlot)
}

EditSelectedBind(*) {
    idx := GetSelectedSlotIndex()
    if idx = 0 {
        ShowNotify("Выберите бинд!", "warning")
        return
    }
    OpenBindEditor(idx)
}

DeleteSelectedBind(*) {
    idx := GetSelectedSlotIndex()
    if idx = 0 {
        ShowNotify("Выберите бинд!", "warning")
        return
    }
    DeleteBindByIdx(idx)
}

DuplicateBind(*) {
    idx := GetSelectedSlotIndex()
    if idx = 0 {
        ShowNotify("Выберите бинд!", "warning")
        return
    }
    DuplicateBindByIdx(idx)
}

ChangeBindHotkey(*) {
    idx := GetSelectedSlotIndex()
    if idx = 0 {
        ShowNotify("Выберите бинд!", "warning")
        return
    }
    CaptureHotkeyVisual(idx)
}

ChangeBindHotkeyByIdx(idx) {
    CaptureHotkeyVisual(idx)
}

DuplicateBindByIdx(idx) {
    global SLOTS
    source := SLOTS[idx]
    if source["name"] = "" || source["lines"].Length = 0 {
        ShowNotify("Нельзя копировать пустой", "warning")
        return
    }
    SaveUndoState("Копирование бинда")
    targetSlot := 0
    Loop Constants.MAX_SLOTS {
        if A_Index != idx && (SLOTS[A_Index]["name"] = "" || SLOTS[A_Index]["lines"].Length = 0) {
            targetSlot := A_Index
            break
        }
    }
    if targetSlot = 0 {
        ShowNotify("Нет пустых слотов!", "error")
        return
    }
    SLOTS[targetSlot]["name"] := source["name"] " (копия)"
    SLOTS[targetSlot]["enabled"] := source["enabled"]
    SLOTS[targetSlot]["hotkey"] := ""
    SLOTS[targetSlot]["category"] := source.Has("category") ? source["category"] : ""
    SLOTS[targetSlot]["statType"] := source.Has("statType") ? source["statType"] : ""
    SLOTS[targetSlot]["lines"] := []
    for line in source["lines"]
        SLOTS[targetSlot]["lines"].Push(Map("text", line["text"], "delay", line["delay"]))
    RefreshBindList()
    ShowNotify("Скопировано в слот " targetSlot, "success")
}

DeleteBindByIdx(idx) {
    global SLOTS
    slot := SLOTS[idx]
    if slot["name"] = "" && slot["lines"].Length = 0 {
        ShowNotify("Слот пустой", "warning")
        return
    }
    result := MsgBox("Удалить '" slot["name"] "'?", "Подтверждение", "YesNo Icon!")
    if result = "Yes" {
        SaveUndoState("Удаление бинда")
        SLOTS[idx]["name"] := ""
        SLOTS[idx]["enabled"] := false
        SLOTS[idx]["hotkey"] := ""
        SLOTS[idx]["category"] := ""
        SLOTS[idx]["statType"] := ""
        SLOTS[idx]["lines"] := []
        MarkUnsaved()
        RefreshBindList()
        UpdateOverlayData()
        RegisterAllHotkeys()
        ShowNotify("Удалено!", "success")
    }
}

OnBindContextMenu(lv, row, isRightClick, x, y) {
    global SLOTS
    if row = 0
        return
    slotIdx := Integer(lv.GetText(row, 1))
    CoordMode "Mouse", "Screen"
    MouseGetPos &mx, &my
    ShowCustomBindMenu(slotIdx, mx, my)
}

CheckHotkeyConflict(hotkey, excludeSlot) {
    global SLOTS
    if (hotkey == "")
        return ""
    Loop Constants.MAX_SLOTS {
        if (A_Index == excludeSlot)
            continue
        slot := SLOTS[A_Index]
        if (slot["hotkey"] != "" && slot["hotkey"] = hotkey)
            return slot["name"]
    }
    return ""
}

CaptureHotkeyVisual(slotIdx) {
    global SLOTS, THEME, CapturedEditorKey, MainGui
    slot := SLOTS[slotIdx]
    if slot["name"] = "" {
        ShowNotify("Слот пустой!", "warning")
        return
    }
    CapturedEditorKey := ""
    captureGui := Gui("+AlwaysOnTop +Owner" MainGui.Hwnd, "Захват клавиши — " slot["name"])
    captureGui.BackColor := THEME["bg"]
    captureGui.SetFont("s11 c" THEME["text"], "Segoe UI")
    captureGui.AddText("x30 y20 w440 c" THEME["textTitle"] " BackgroundTrans", "Нажмите нужную клавишу")
    captureGui.SetFont("s9 c" THEME["textDim"], "Segoe UI")
    captureGui.AddText("x30 y50 w440 BackgroundTrans", "Примеры: F1, Ctrl+1, Alt+F5, Numpad3")
    captureGui.SetFont("s14 bold", THEME["fontMono"])
    frameCap := captureGui.AddText("x30 y90 w440 h50 Background" THEME["fieldBorder"], "")
    RoundCorners(frameCap, 440, 50, THEME["radiusSm"])
    display := captureGui.AddText("x31 y91 w438 h48 Center 0x200 Background" THEME["field"] " c" THEME["textDim"], "Ожидание…")
    RoundCorners(display, 438, 48, THEME["radiusSm"])
    statusText := captureGui.AddText("x30 y150 w440 Center c" THEME["textMuted"] " BackgroundTrans", "")
    ih := InputHook("L0 T30")
    ih.KeyOpt("{All}", "N")
    ih.OnKeyDown := SidebarKeyHandler.Bind(display, statusText, slotIdx)
    captureGui.SetFont("s10", "Segoe UI")
    CreateStyledButton(captureGui, 30, 180, 140, 40, "Отмена", (*) => (ih.Stop(), captureGui.Destroy()), "default")
    CreateStyledButton(captureGui, 180, 180, 140, 40, "Сброс", (*) => (display.Text := "", CapturedEditorKey := ""), "default")
    CreateStyledButton(captureGui, 330, 180, 140, 40, "OK", (*) => (ih.Stop(), ApplyCapturedKeyToSlot(CapturedEditorKey, slotIdx, captureGui)), "primary")
    captureGui.OnEvent("Close", (*) => (ih.Stop(), captureGui.Destroy()))
    captureGui.Show("w500 h240")
    ih.Start()
}

SidebarKeyHandler(displayCtrl, statusCtrl, slotIdx, hook, vk, sc) {
    global THEME, CapturedEditorKey
    try {
        if !displayCtrl.Hwnd
            return
    }
    keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    if (keyName = "Control" || keyName = "LControl" || keyName = "RControl"
     || keyName = "Alt"     || keyName = "LAlt"     || keyName = "RAlt"
     || keyName = "Shift"   || keyName = "LShift"   || keyName = "RShift"
     || keyName = "LWin"    || keyName = "RWin") 
        return
    mods := ""
    if GetKeyState("Ctrl", "P")
        mods .= "^"
    if GetKeyState("Alt", "P")
        mods .= "!"
    if GetKeyState("Shift", "P")
        mods .= "+"
    if GetKeyState("LWin", "P")
        mods .= "#"
    CapturedEditorKey := mods . keyName
    displayCtrl.Text := FormatHotkey(CapturedEditorKey)
    conflict := CheckHotkeyConflict(CapturedEditorKey, slotIdx)
    if conflict = "" {
        SetButtonVisualByControl(displayCtrl, THEME["success"])
        statusCtrl.Text := "Клавиша свободна"
        statusCtrl.Opt("c" THEME["success"])
    } else {
        SetButtonVisualByControl(displayCtrl, THEME["error"])
        statusCtrl.Text := "Занята: " SubStr(conflict, 1, 35)
        statusCtrl.Opt("c" THEME["error"])
    }
}

ApplyCapturedKeyToSlot(key, slotIdx, gui) {
    global SLOTS
    conflict := CheckHotkeyConflict(key, slotIdx)
    if conflict != "" {
        gui.Destroy()
        ShowConflictDialog(key, conflict, slotIdx, MainGui) 
    } else {
        SaveUndoState("Изменение клавиши")
        SLOTS[slotIdx]["hotkey"] := key
        gui.Destroy()
        RefreshBindList()
        RegisterAllHotkeys()
        ShowNotify("Клавиша установлена: " key, "success")
    }
}

GlobalBlinkTick() {
    global MainGui, CurrentCapturing, THEME
    static blinkState := false
    try {
        if (CurrentCapturing == "") {
            StopBlink()
            return
        }
        ctrl := MainGui["Display_" CurrentCapturing]
        blinkState := !blinkState
        if blinkState {
            SetButtonVisualByControl(ctrl, THEME["warning"], THEME["field"])
            ctrl.Text := ">>> ЖДУ <<<"
        } else {
            SetButtonVisualByControl(ctrl, THEME["error"], THEME["field"])
            ctrl.Text := " НАЖМИТЕ "
        }
        ctrl.Redraw()
    } catch {
        StopBlink()
    }
}

StartHotkeyCapture(keyType) {
    global MainGui, THEME, CurrentCapturing, CaptureHook, CurrentBlinkTimer
    if (CurrentCapturing != "")
        CancelCapture(CurrentCapturing)
    CurrentCapturing := keyType
    try MainGui["Status_" keyType].Text := ""
    StopBlink() 
    CurrentBlinkTimer := GlobalBlinkTick
    SetTimer(CurrentBlinkTimer, 500)
    GlobalBlinkTick() 
    if CaptureHook
        CaptureHook.Stop()
    CaptureHook := InputHook("L0 T30")
    CaptureHook.KeyOpt("{All}", "N")
    CaptureHook.KeyOpt("{LButton}{RButton}{MButton}", "S") 
    CaptureHook.OnKeyDown := CaptureKeyHandlerNew.Bind(keyType)
    CaptureHook.OnKeyUp := CaptureKeyUpHandler.Bind(keyType)
    CaptureHook.Start()
}

StopBlink() {
    global CurrentBlinkTimer
    if (CurrentBlinkTimer != "") {
        try SetTimer(CurrentBlinkTimer, 0)
        CurrentBlinkTimer := ""
    }
}

CaptureKeyHandlerNew(keyType, hook, vk, sc) {
    global MainGui, THEME
    
    try {
        displayCtrl := MainGui["Display_" keyType]
    } catch {
        CancelCapture(keyType)
        return
    }

    keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    
    ; РАЗРЕШАЕМ MButton (убрали из запрета), но запрещаем клики
    if (keyName = "LButton" || keyName = "RButton")
        return

    if (keyName = "Escape") {
        CancelCapture(keyType)
        return
    }
    
    if (keyName = "Control" || keyName = "LControl" || keyName = "RControl"
     || keyName = "Shift"   || keyName = "LShift"   || keyName = "RShift"
     || keyName = "Alt"     || keyName = "LAlt"     || keyName = "RAlt"
     || keyName = "LWin"    || keyName = "RWin") 
    {
        mods := GetCurrentModifiers()
        if (mods != "") {
            StopBlink()
            try {
                displayCtrl.Text := FormatHotkey(mods) " ..."
                SetButtonVisualByControl(displayCtrl, THEME["accent"])
                displayCtrl.Redraw()
            }
        }
        return
    }
    
    mods := GetCurrentModifiers()
    fullKey := mods . keyName
    
    conflictName := CheckHotkeyConflict(fullKey, 0)
    
    FinalizeCapture(keyType, fullKey, conflictName)
}

CaptureKeyUpHandler(keyType, hook, vk, sc) {
    global CurrentBlinkTimer
    if (hook.InProgress && GetCurrentModifiers() == "" && CurrentBlinkTimer == "") {
         global CurrentBlinkTimer := GlobalBlinkTick
         SetTimer(CurrentBlinkTimer, 500)
    }
}

FinalizeCapture(keyType, fullKey, conflictText := "") {
    global MainGui, CaptureHook, CurrentCapturing, THEME
    StopBlink()
    if CaptureHook
        CaptureHook.Stop()
    CurrentCapturing := ""
    CaptureHook := ""
    try {
        MainGui["Value_" keyType].Value := fullKey
        ctrl := MainGui["Display_" keyType]
        ctrl.Text := FormatHotkey(fullKey)
        SetButtonVisualByControl(ctrl, THEME["accent"], THEME["field"])
        ctrl.Redraw()
        if (conflictText != "") {
             try {
                 MainGui["Status_" keyType].Text := "Занято: " SubStr(conflictText, 1, 30)
                  SetButtonVisualByControl(ctrl, THEME["warning"])
                 ctrl.Redraw()
             }
        } else {
             try MainGui["Status_" keyType].Text := ""
        }
    }
    CheckSettingsDirty()
}

CancelCapture(keyType) {
    global MainGui, THEME, CaptureHook, CurrentCapturing
    StopBlink()
    if CaptureHook
        CaptureHook.Stop()
    CurrentCapturing := ""
    CaptureHook := ""
    try {
        oldVal := MainGui["Value_" keyType].Value
        try MainGui["Status_" keyType].Text := "" 
        ctrl := MainGui["Display_" keyType]
        ctrl.Text := oldVal = "" ? "—" : FormatHotkey(oldVal)
        color := oldVal = "" ? THEME["textMuted"] : THEME["accent"]
        SetButtonVisualByControl(ctrl, color, THEME["field"])
        ctrl.Redraw()
    }
}

ClearHotkey(keyType) {
    global MainGui, THEME, CurrentCapturing
    
    if (CurrentCapturing != "")
        CancelCapture(CurrentCapturing)
        
    try {
        ; 1. Очищаем значение
        MainGui["Value_" keyType].Value := ""
        
        ; 2. Очищаем статус (если есть)
        try MainGui["Status_" keyType].Text := ""
        
        ; 3. Обновляем визуальную кнопку
        ctrl := MainGui["Display_" keyType]
        ctrl.Text := "—"
        SetButtonVisualByControl(ctrl, THEME["textMuted"])
        ctrl.Redraw()
        
        ShowNotify("Клавиша очищена", "info", 1000)
    }
    
    CheckSettingsDirty()
}

ShowConflictDialog(key, conflictName, slotIdx, parentGui) {
    global SLOTS, THEME
    conflictGui := Gui("+AlwaysOnTop +Owner" parentGui.Hwnd, "Конфликт клавиш")
    conflictGui.BackColor := THEME["bg"]
    conflictGui.MarginX := 0
    conflictGui.MarginY := 0
    conflictGui.AddText("x0 y0 w500 h3 Background" THEME["error"], "")
    conflictGui.SetFont("s12 bold", "Segoe UI")
    conflictGui.AddText("x30 y25 w440 c" THEME["error"] " BackgroundTrans", "Конфликт клавиш")
    conflictGui.SetFont("s10 norm", "Segoe UI")
    conflictGui.AddText("x30 y60 w440 c" THEME["text"] " BackgroundTrans", "Клавиша уже используется:")
    conflictGui.AddText("x30 y90 w440 h90 Background" THEME["bgHighlight"], "")
    conflictGui.SetFont("s11 bold", "Consolas")
    conflictGui.AddText("x50 y100 w400 c" THEME["accentLight"], "Клавиша: " key)
    conflictGui.SetFont("s10 norm", "Segoe UI")
    conflictGui.AddText("x50 y130 w400 c" THEME["textDim"] " BackgroundTrans", "Занята биндом:")
    conflictGui.SetFont("s10 bold", "Segoe UI")
    conflictGui.AddText("x50 y152 w400 c" THEME["warning"], SubStr(conflictName, 1, 45))
    conflictGui.SetFont("s10 norm", "Segoe UI")
    conflictGui.AddText("x30 y200 w440 c" THEME["text"] " Center BackgroundTrans", "Заменить конфликтующую клавишу?")
    conflictGui.SetFont("s9", "Segoe UI")
    conflictGui.AddText("x30 y225 w440 c" THEME["textDim"] " Center BackgroundTrans", "(У старого бинда клавиша будет удалена)")
    conflictGui.AddText("x30 y255 w440 h1 Background" THEME["border"], "")
    conflictGui.SetFont("s10 bold", "Segoe UI")
    CreateStyledButton(conflictGui, 30, 270, 200, 45, "Да, заменить", (*) => ConfirmReplace(key, slotIdx, parentGui, conflictGui), "success")
    CreateStyledButton(conflictGui, 240, 270, 230, 45, "Нет, выбрать другую", (*) => conflictGui.Destroy(), "danger")
    conflictGui.Show("w500 h335")
    conflictGui.GetPos(&gx, &gy, &gw, &gh)
    conflictGui.Move((A_ScreenWidth - gw) / 2, (A_ScreenHeight - gh) / 2)
}

ConfirmReplace(key, slotIdx, parentGui, conflictGui) {
    global SLOTS
    Loop Constants.MAX_SLOTS {
        if A_Index != slotIdx && SLOTS[A_Index]["hotkey"] = key {
            SLOTS[A_Index]["hotkey"] := ""
            ShowNotify("Удалена из: " SLOTS[A_Index]["name"], "warning", 2500)
            break
        }
    }
    SaveUndoState("Изменение клавиши")
    SLOTS[slotIdx]["hotkey"] := key
    conflictGui.Destroy()
    parentGui.Destroy()
    RefreshBindList()
    RegisterAllHotkeys()
    ShowNotify("Клавиша установлена: " key, "success")
}

ShowEditorConflictDialog(key, conflictName) {
    global SLOTS, THEME, CurrentEditSlot, EditorGui
    conflictGui := Gui("+AlwaysOnTop +Owner" EditorGui.Hwnd, "Конфликт клавиш")
    conflictGui.BackColor := THEME["bg"]
    conflictGui.MarginX := 0
    conflictGui.MarginY := 0
    conflictGui.AddText("x0 y0 w500 h3 Background" THEME["error"], "")
    conflictGui.SetFont("s12 bold", "Segoe UI")
    conflictGui.AddText("x30 y25 w440 c" THEME["error"] " BackgroundTrans", "Конфликт клавиш")
    conflictGui.SetFont("s10 norm", "Segoe UI")
    conflictGui.AddText("x30 y60 w440 c" THEME["text"] " BackgroundTrans", "Клавиша уже используется:")
    conflictGui.AddText("x30 y90 w440 h1 Background" THEME["borderGlow"], "")
    conflictGui.AddText("x30 y90 w1 h90 Background" THEME["borderGlow"], "")
    conflictGui.AddText("x469 y90 w1 h90 Background" THEME["borderGlow"], "")
    conflictGui.AddText("x30 y179 w440 h1 Background" THEME["borderGlow"], "")
    conflictGui.SetFont("s14 bold", "Consolas")
    conflictGui.AddText("x50 y105 w400 c" THEME["accentLight"], key)
    conflictGui.SetFont("s9 norm", "Segoe UI")
    conflictGui.AddText("x50 y135 w400 c" THEME["textDim"] " BackgroundTrans", "Занята биндом:")
    conflictGui.SetFont("s11 bold", "Segoe UI")
    conflictGui.AddText("x50 y155 w400 c" THEME["warning"], SubStr(conflictName, 1, 40))
    conflictGui.SetFont("s10 norm", "Segoe UI")
    conflictGui.AddText("x30 y200 w440 c" THEME["text"] " Center BackgroundTrans", "Заменить конфликтующую клавишу?")
    conflictGui.SetFont("s8", "Segoe UI")
    conflictGui.AddText("x30 y225 w440 c" THEME["textDim"] " Center BackgroundTrans", "(У старого бинда клавиша будет удалена)")
    conflictGui.AddText("x30 y250 w440 h2 Background" THEME["borderGlow"], "")
    conflictGui.SetFont("s10 bold", "Segoe UI")
    CreateStyledButton(conflictGui, 30, 265, 200, 45, "Да, заменить", (*) => ConfirmEditorReplace(key, conflictGui), "success")
    CreateStyledButton(conflictGui, 240, 265, 230, 45, "Нет, выбрать другую", (*) => (conflictGui.Destroy(), EditorStartCapture()), "danger")    
    conflictGui.Show("w500 h330")
    conflictGui.GetPos(&gx, &gy, &gw, &gh)
    conflictGui.Move((A_ScreenWidth - gw) / 2, (A_ScreenHeight - gh) / 2)
}

ConfirmEditorReplace(key, conflictGui) {
    global SLOTS, CurrentEditSlot, EditorGui
    Loop Constants.MAX_SLOTS {
        if A_Index != CurrentEditSlot && SLOTS[A_Index]["hotkey"] = key {
            SLOTS[A_Index]["hotkey"] := ""
            break
        }
    }
    conflictGui.Destroy()
    ApplyEditorInlineKey(key)
    ShowNotify("Конфликт устранен. Клавиша установлена.", "success")
}

; ═══════════════════════════════════════════════════════════════════════════════
; РЕДАКТОР БИНДА v3.0 (MODERN UI / CARD STYLE)
; ═══════════════════════════════════════════════════════════════════════════════
