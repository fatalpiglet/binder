; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: sending                       ║
; ║  Отправка сообщений и регистрация хоткеев       ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
ShowCustomBindMenu(slotIdx, mouseX, mouseY) {
    global ContextMenuGui, THEME, SLOTS, HoverButtons
    
    if slotIdx < 1 || slotIdx > Constants.MAX_SLOTS
        return
    
    slot := SLOTS[slotIdx]
    
    ; Удаляем старое меню (безопасно)
    try {
        if ContextMenuGui {
            CleanupHoverButtons(ContextMenuGui)
            ContextMenuGui.Destroy()
        }
    }
    
    ContextMenuGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner", "CustomContextMenu")
    ContextMenuGui.BackColor := THEME["bg"]
    ContextMenuGui.MarginX := 0
    ContextMenuGui.MarginY := 0
   
    w := 240
    y := 12
    
    ; Заголовок
    ContextMenuGui.SetFont("s9 bold", "Segoe UI")
    name := slot["name"] = "" ? "(Пустой слот)" : SubStr(slot["name"], 1, 28)
    ContextMenuGui.AddText("x16 y" y " w" (w-32) " c" THEME["accent"], name)
    y += 28
    
    ContextMenuGui.AddText("x12 y" y " w" (w-24) " h2 Background" THEME["borderGlow"], "")
    y += 10
    
    ContextMenuGui.SetFont("s9 norm", "Segoe UI")
    
    menuItems := []
    
    if (slot["name"] != "" && slot["lines"].Length > 0) {
        menuItems.Push(Map("text", "Запустить", "action", "run", "color", THEME["success"]))
        menuItems.Push(Map("text", "Редактировать", "action", "edit", "color", THEME["text"]))
        menuItems.Push(Map("text", "Копировать", "action", "copy", "color", THEME["text"]))
        menuItems.Push(Map("text", "Изменить клавишу", "action", "hotkey", "color", THEME["text"]))
        
        statusText := slot["enabled"] ? "Отключить" : "Включить"
        statusColor := slot["enabled"] ? THEME["warning"] : THEME["success"]
        menuItems.Push(Map("text", statusText, "action", "toggle", "color", statusColor))
        
        menuItems.Push(Map("text", "Удалить", "action", "delete", "color", THEME["error"]))
    } else {
        menuItems.Push(Map("text", "Создать здесь", "action", "edit", "color", THEME["success"]))
    }
    
    for item in menuItems {
        (itemAction := item["action"])
        (idx := slotIdx)
        
        callback := ((act, i) => (*) => ExecuteCustomAction(act, i))(itemAction, idx)
        
        rowBtn := CreateStyledButton(ContextMenuGui, 8, y+2, w-16, 28, item["text"], callback, "default")
        rowBtn.SetVisual(THEME["bg"], item["color"], THEME["bgHover"])
        row := rowBtn.ctrl
        txt := rowBtn.ctrl
        
        y += 32
    }
    
    y += 10
    
    ContextMenuGui.Show("x" mouseX " y" mouseY " w" w " h" y)
    
    ; Запускаем таймер для проверки фокуса (вместо OnMessage/LoseFocus)
    SetTimer(CheckMenuFocus, 100)
}

; Таймер закрытия меню, если кликнули мимо
CheckMenuFocus() {
    global ContextMenuGui
    try {
        if !ContextMenuGui {
            SetTimer(CheckMenuFocus, 0) ; Выключаем таймер
            return
        }
        
        ; Если окно меню существует, но НЕ активно -> Закрываем
        if WinExist("ahk_id " ContextMenuGui.Hwnd) && !WinActive("ahk_id " ContextMenuGui.Hwnd) {
            SetTimer(CheckMenuFocus, 0)
            CleanupHoverButtons(ContextMenuGui)
            ContextMenuGui.Destroy()
        }
    } catch {
        SetTimer(CheckMenuFocus, 0)
    }
}

ExecuteCustomAction(action, slotIdx) {
    global ContextMenuGui, SLOTS
    
    SetTimer(CheckMenuFocus, 0) ; Останавливаем таймер
    
    try {
        if (ContextMenuGui) {
            CleanupHoverButtons(ContextMenuGui)
            ContextMenuGui.Destroy()
        }
    }
    
    switch action {
        case "edit":
            OpenBindEditor(slotIdx)
        case "run":
            RunSlotByNum(slotIdx)
        case "copy":
            DuplicateBindByIdx(slotIdx)
        case "hotkey":
            ChangeBindHotkeyByIdx(slotIdx)
        case "toggle":
            ToggleBindState(slotIdx)
        case "delete":
            DeleteBindByIdx(slotIdx)
    }
}

ToggleBindState(idx) {
    global SLOTS
    
    SaveUndoState("Переключение бинда")
    SLOTS[idx]["enabled"] := !SLOTS[idx]["enabled"]
    
    RefreshBindList()
    RegisterAllHotkeys()
    
    stateText := SLOTS[idx]["enabled"] ? "Включен" : "Отключен"
    type := SLOTS[idx]["enabled"] ? "success" : "warning"
    ShowNotify(SLOTS[idx]["name"] ": " stateText, type, 1000)
}


; ═══════════════════════════════════════════════════════════════════════════════
; ФУНКЦИЯ ЖИВЫХ ЧАСОВ
; ═══════════════════════════════════════════════════════════════════════════════
RunSlotByNum(num) {
    global SLOTS, STATE, CFG
    
    if STATE["isSending"] {
        ShowNotify("Идёт отправка!", "warning")
        return
    }
    
    if CFG["onlyGTA"] && !WinActive("ahk_exe gta_sa.exe")
        return
    
    if IsChatActive()
        return
    
    if num < 1 || num > Constants.MAX_SLOTS
        return
    
    slot := SLOTS[num]
    
    if !slot["enabled"] || slot["lines"].Length = 0
        return
    
    ; Проверка ID пациента
    needPatient := false
    for line in slot["lines"] {
        if InStr(line["text"], "{P}") {
            needPatient := true
            break
        }
    }
    
    if needPatient && STATE["patientId"] = "" {
        ShowNotify("Задайте ID пациента!", "warning")
        return
    }
    
    SendSlot(slot)
}

; ═══════════════════════════════════════════════════════════════════════════════
; ФУНКЦИЯ ОТПРАВКИ (ИСПРАВЛЕННАЯ И НАДЕЖНАЯ)
; ═══════════════════════════════════════════════════════════════════════════════
SendSlot(slot) {
    global STATE, CFG, STATS, Constants

    if STATE["isSending"] {
        ShowNotify("Идёт отправка!", "warning")
        return
    }
    
    if CFG["onlyGTA"] && !WinActive("ahk_exe gta_sa.exe") {
        ShowNotify("Открыто не окно GTA!", "warning")
        return
    }
    
    STATE["isSending"] := true
    STATE["stopSending"] := false
    UpdateOverlayData()
    ShowNotify("► " slot["name"], "info")
    
    try {
        for idx, line in slot["lines"] {
            if STATE["stopSending"]
                break
            
            if CFG["onlyGTA"] && !WinActive("ahk_exe gta_sa.exe") {
                break
            }
            
            text := line["text"]
            text := StrReplace(text, "{P}", GetPatientDisplay())
            text := StrReplace(text, "{MY}", STATE["myName"])
            text := StrReplace(text, "{HOSPITAL}", STATE["hospital"])
            text := StrReplace(text, "{RANK}", STATE["rank"])
            text := StrReplace(text, "{SPECIALTY}", STATE["specialty"])        

            if RegExMatch(text, "^\{[a-zA-Z0-9_]+\}$") {
                Sleep(50)
                SendInput(text)
            } 
            else {
                ; === ВАЖНО: Ждем отпускания модификаторов, чтобы не свернулась игра ===
                KeyWait "Alt"
                KeyWait "Ctrl"
                KeyWait "Shift"
                
                BlockInput true
                oldClip := A_Clipboard
                try {
                    A_Clipboard := "" ; Чистим буфер
                    A_Clipboard := text
                    if !ClipWait(0.5) { ; Ждем пока текст попадет в буфер
                        continue
                    }
                    
                    if !IsChatActive() {
                        SendEvent "{" CFG["chatKey"] "}"
                        Sleep(CFG["afterChatDelay"]) ; Пауза, чтобы чат успел открыться
                    }
                    
                    ; Вставка (Event надежнее Input в GTA)
                    SendEvent "^v"
                    Sleep(Constants.TYPE_DELAY) ; Небольшая пауза перед Enter
                    SendEvent "{Enter}"
                    Sleep(CFG["afterEnterDelay"])
                    
                } finally {
                    ; ВАЖНО: возвращаем буфер пользователя В ЛЮБОМ СЛУЧАЕ,
                    ; даже если отправка упала с ошибкой (иначе буфер оставался бы затертым)
                    A_Clipboard := oldClip
                    BlockInput false
                }
            }

            IncrementAndSave("totalSent")
            
            if idx < slot["lines"].Length {
                totalSleepTime := (line["delay"] > 0 ? line["delay"] : CFG["baseDelay"]) + Random(0, CFG["jitter"])
                loopCount := totalSleepTime // 50
                Loop loopCount {
                    if STATE["stopSending"]
                        break
                    Sleep(50)
                }
            }
        }
    } catch as err {
        BlockInput false
        LogError(err, "SendSlot")
        ShowNotify("Ошибка: " err.Message, "error")
    }

    if slot.Has("statType") && slot["statType"] != "" {
        switch slot["statType"] {
            case "pills": IncrementAndSave("pillsGiven"), IncrementAndSave("patientsHealed")
            case "inject": IncrementAndSave("injectionsGiven")
            case "operation": IncrementAndSave("operationsDone"), IncrementAndSave("patientsHealed")
            case "medcheck": IncrementAndSave("medChecks")
            case "vaccine": IncrementAndSave("vaccinesGiven")
        }
    }
    
    STATE["isSending"] := false
    UpdateOverlayData()
    
    if !STATE["stopSending"]
        ShowNotify("✓ Готово!", "success")
    else
        ShowNotify("⏹ Остановлено", "warning")
}
ClearAllBindsAction(*) {
    global SLOTS
    
    result := MsgBox("Вы уверены, что хотите УДАЛИТЬ ВСЕ бинды?`n`nЭто действие нельзя отменить (А может и можно:) ).", "Внимание!", "YesNo Icon! Default2")
    
    if result = "No"
        return

    SaveUndoState("Удаление всех биндов")
    
    ; Полная очистка массива SLOTS
    Loop Constants.MAX_SLOTS {
        SLOTS[A_Index] := Map(
            "name", "",
            "hotkey", "",
            "enabled", false,
            "category", "",
            "statType", "",
            "lines", []
        )
    }
    
    ; Обновляем интерфейс
    RefreshBindList()
    UpdateOverlayData()
    RegisterAllHotkeys()
    
    ; Помечаем, что есть изменения
    MarkUnsaved()
    
    ShowNotify("🗑️ Все бинды удалены!", "success")
}


; ═══════════════════════════════════════════════════════════════════════════════
; РЕГИСТРАЦИЯ ГОРЯЧИХ КЛАВИШ
; ═══════════════════════════════════════════════════════════════════════════════
RegisterAllHotkeys(*) {
    global SLOTS
    
    ; Отключаем предыдущие
    Loop Constants.MAX_SLOTS {
        slot := SLOTS[A_Index]
        if slot["hotkey"] != "" {
            try Hotkey(slot["hotkey"], "Off")
        }
    }
    
    ; Регистрируем новые
    registered := 0
    Loop Constants.MAX_SLOTS {
        slot := SLOTS[A_Index]
        
        if slot["enabled"] && slot["hotkey"] != "" && slot["lines"].Length > 0 {
            hk := slot["hotkey"]
            num := A_Index
            
            try {
                Hotkey(hk, MakeSlotHandler(num), "On")
                registered++
            } catch {
                ShowNotify("Ошибка: " hk, "error")
            }
        }
    }
    
    ShowNotify("Биндов: " registered, "success")
    UpdateOverlayData()
}

MakeSlotHandler(num) {
    ; Возвращаем лямбда-функцию, которая просто вызывает SafeRunSlot с номером слота.
    ; Мы НЕ пытаемся здесь использовать KeyInfo.Hotkey, чтобы избежать ошибок.
    return (KeyInfo) => SafeRunSlot(num)
}


SafeRunSlot(num) {
    ; --- Проверка чата всегда должна быть первой ---
    if IsChatActive()
        return

    ; --- Автоматически определяем горячую клавишу, которая вызвала этот бинд ---
    ; A_ThisHotkey - это встроенная переменная AHK, которая содержит строку горячей клавиши,
    ; вызвавшей текущий поток (функцию).
    local triggeredHotkey := A_ThisHotkey

    local ignoreAlt := false
    local ignoreCtrl := false
    local ignoreShift := false
    local ignoreWin := false

    ; Если A_ThisHotkey содержит информацию (то есть, это было вызвано хоткеем)
    if (triggeredHotkey != "") {
        ignoreAlt := InStr(triggeredHotkey, "!")
        ignoreCtrl := InStr(triggeredHotkey, "^")
        ignoreShift := InStr(triggeredHotkey, "+")
        ignoreWin := InStr(triggeredHotkey, "#")
    }
    ; else {
    ;   ЕслиtriggeredHotkey пуст (вызов не от Hotkey, а напрямую из GUI, например),
    ;   то все ignoreXxx останутся false, что означает "не игнорировать никакие модификаторы",
    ;   что и является желаемым поведением.
    ; }

    ; --- Быстрая проверка на ЛЮБЫЕ ДРУГИЕ зажатые модификаторы ---
    ; GetKeyState("...","P") проверяет ФИЗИЧЕСКОЕ состояние клавиши.
    if (GetKeyState("Alt", "P") && !ignoreAlt)
        || (GetKeyState("Ctrl", "P") && !ignoreCtrl)
        || (GetKeyState("Shift", "P") && !ignoreShift)
        || (GetKeyState("LWin", "P") && !ignoreWin)
        || (GetKeyState("RWin", "P") && !ignoreWin)
    {
        ShowNotify("🚫 Зажат лишний модификатор, активация отменена", "warning")
        return
    }
    
    Sleep(10) ; Микро-пауза для стабильности
    
    RunSlotByNum(num)
}

; ══════════════════════════════════════════════════════════════════════════
; РЕГИСТРАЦИЯ СИСТЕМНЫХ ГОРЯЧИХ КЛАВИШ (ИСПРАВЛЕННАЯ)
; ══════════════════════════════════════════════════════════════════════════
RegisterSystemHotkeys() {
    global CFG
    
    ; Статические переменные для хранения ТЕКУЩИХ активных клавиш
    static currentOverlay   := ""
    static currentMini      := ""
    static currentStop      := ""
    static currentReplySms  := ""
    static currentWheel     := ""
    
    ; 1. Отключаем старые (каждая команда на своей строке для надежности)
    if (currentOverlay != "") {
        try Hotkey(currentOverlay, "Off")
        currentOverlay := ""
    }
    if (currentMini != "") {
        try Hotkey(currentMini, "Off")
        currentMini := ""
    }
    if (currentStop != "") {
        try Hotkey(currentStop, "Off")
        currentStop := ""
    }
    if (currentReplySms != "") {
        try Hotkey(currentReplySms, "Off")
        currentReplySms := ""
    }
    if (currentWheel != "") {
        try Hotkey("*" currentWheel, "Off")
        currentWheel := ""
    }
    
    ; 2. Включаем новые
    if (CFG["hotkeyOverlay"] != "") {
        try {
            Hotkey(CFG["hotkeyOverlay"], (*) => SafeToggleOverlay(), "On")
            currentOverlay := CFG["hotkeyOverlay"]
        }
    }
    
    if (CFG["hotkeyMiniOverlay"] != "") {
        try {
            Hotkey(CFG["hotkeyMiniOverlay"], (*) => SafeToggleMiniOverlay(), "On")
            currentMini := CFG["hotkeyMiniOverlay"]
        }
    }
    
    if (CFG["hotkeyStopSending"] != "") {
        try {
            Hotkey(CFG["hotkeyStopSending"], (*) => StopSending(), "On")
            currentStop := CFG["hotkeyStopSending"]
        }
    }
    
    if (CFG["hotkeyReplySms"] != "") {
        try {
            Hotkey(CFG["hotkeyReplySms"], (*) => ReplyToLastSms(), "On")
            currentReplySms := CFG["hotkeyReplySms"]
        }
    }
    
    ; РАДИАЛЬНОЕ МЕНЮ (Только в GTA)
    if (CFG["hotkeyWheel"] != "") {
        try {
            hk := "*" CFG["hotkeyWheel"]
            
            ; Создаем контекст HotIf
            HotIfWinActive "ahk_exe gta_sa.exe"
            Hotkey(hk, (*) => ShowRadialMenu(), "On")
            HotIfWinActive ; Закрываем контекст (дальше глобально)
            
            currentWheel := CFG["hotkeyWheel"] 
        }
    }
}

SafeToggleOverlay() {  ; ✅ Без параметра
    if IsChatActive()
        return
    
    ; A_ThisHotkey содержит нажатую клавишу
    local triggeredHotkey := A_ThisHotkey
    
    local ignoreAlt := InStr(triggeredHotkey, "!")
    local ignoreCtrl := InStr(triggeredHotkey, "^")
    local ignoreShift := InStr(triggeredHotkey, "+")
    local ignoreWin := InStr(triggeredHotkey, "#")

    if (GetKeyState("Alt", "P") && !ignoreAlt)
        || (GetKeyState("Ctrl", "P") && !ignoreCtrl)
        || (GetKeyState("Shift", "P") && !ignoreShift)
        || (GetKeyState("LWin", "P") && !ignoreWin)
        || (GetKeyState("RWin", "P") && !ignoreWin)
    {
        ShowNotify("🚫 Лишний модификатор при ToggleOverlay", "warning")
        return
    }
    
    Sleep(10)
    ToggleOverlay()
}

SafeToggleMiniOverlay() {  ; ✅ Без параметра
    if IsChatActive()
        return

    local triggeredHotkey := A_ThisHotkey
    
    local ignoreAlt := InStr(triggeredHotkey, "!")
    local ignoreCtrl := InStr(triggeredHotkey, "^")
    local ignoreShift := InStr(triggeredHotkey, "+")
    local ignoreWin := InStr(triggeredHotkey, "#")

    if (GetKeyState("Alt", "P") && !ignoreAlt)
        || (GetKeyState("Ctrl", "P") && !ignoreCtrl)
        || (GetKeyState("Shift", "P") && !ignoreShift)
        || (GetKeyState("LWin", "P") && !ignoreWin)
        || (GetKeyState("RWin", "P") && !ignoreWin)
    {
        ShowNotify("🚫 Лишний модификатор при ToggleMiniOverlay", "warning")
        return
    }

    Sleep(10)
    ToggleMiniOverlay()
}



StopSending() { ; <--- Больше не принимает параметр triggeredHotkey
    global STATE
    
    ; УДАЛИТЕ ВЕСЬ ЭТОТ БЛОК ПРОВЕРКИ МОДИФИКАТОРОВ ИЗ StopSending():
    ; local triggeredHotkey := A_ThisHotkey
    ; local ignoreAlt := InStr(triggeredHotkey, "!")
    ; local ignoreCtrl := InStr(triggeredHotkey, "^")
    ; local ignoreShift := InStr(triggeredHotkey, "+")
    ; local ignoreWin := InStr(triggeredHotkey, "#")
    ; if (GetKeyState("Alt", "P") && !ignoreAlt)
    ;     || (GetKeyState("Ctrl", "P") && !ignoreCtrl)
    ;     || (GetKeyState("Shift", "P") && !ignoreShift)
    ;     || (GetKeyState("LWin", "P") && !ignoreWin)
    ;     || (GetKeyState("RWin", "P") && !ignoreWin)
    ; {
    ;     ShowNotify("🚫 Лишний модификатор при StopSending", "warning")
    ;     return
    ; }

    ; Оставляем только следующую логику:
    Sleep(10) ; Малая задержка, чтобы AHK успел обработать Hotkey
    STATE["stopSending"] := true
    STATE["isSending"] := false
    UpdateOverlayData()
    ShowNotify("⏹ Остановлено", "warning")
    BlockInput false ; Снимаем блокировку ввода на всякий случай
    ReleaseStuckKeys() ; Очищаем залипшие клавиши
}


; ═══════════════════════════════════════════════════════════════════════════════
; ФУНКЦИЯ ДЛЯ ОТПУСКАНИЯ "ЗАЛИПШИХ" КЛАВИШ (например, после BlockInput)
; ═══════════════════════════════════════════════════════════════════════════════
ReleaseStuckKeys() {
    ; Отпускаем все модификаторы
    Send("{LControl up}{RControl up}{LAlt up}{RAlt up}{LShift up}{RShift up}{LWin up}{RWin up}")
    
    ; Отпускаем часто используемые в играх клавиши, которые могли "залипнуть"
    ; после BlockInput, если пользователь физически отпустил их, а AHK - нет.
    KeysToForceRelease := ["w", "a", "s", "d", "f", "Space", "Tab"] ; Добавил Tab, он часто используется
    for key in KeysToForceRelease {
        ; GetKeyState(key, "P") проверяет физическое состояние клавиши
        if GetKeyState(key, "P")
            Send("{" key " up}")
    }
}

ReplyToLastSms() { ; <--- Больше не принимает параметр triggeredHotkey
    global STATE, CFG
    
    ; УДАЛИТЕ ВЕСЬ ЭТОТ БЛОК ПРОВЕРКИ МОДИФИКАТОРОВ ИЗ ReplyToLastSms():
    ; local triggeredHotkey := A_ThisHotkey
    ; local ignoreAlt := InStr(triggeredHotkey, "!")
    ; local ignoreCtrl := InStr(triggeredHotkey, "^")
    ; local ignoreShift := InStr(triggeredHotkey, "+")
    ; local ignoreWin := InStr(triggeredHotkey, "#")
    ; if (GetKeyState("Alt", "P") && !ignoreAlt)
    ;     || (GetKeyState("Ctrl", "P") && !ignoreCtrl)
    ;     || (GetKeyState("Shift", "P") && !ignoreShift)
    ;     || (GetKeyState("LWin", "P") && !ignoreWin)
    ;     || (GetKeyState("RWin", "P") && !ignoreWin)
    ; {
    ;     ShowNotify("🚫 Лишний модификатор при ReplyToLastSms", "warning")
    ;     return
    ; }

    ; Оставляем только следующую логику:
    Sleep(10)
    if (STATE["lastSmsNum"] == "") {
        ShowNotify("Нет входящих SMS", "warning")
        return
    }
    if !WinActive("ahk_exe gta_sa.exe")
        return
        
    if !IsChatActive()
        Send("{" CFG["chatKey"] "}")
        
    Sleep(CFG["afterChatDelay"])
    SendText("/sms " STATE["lastSmsNum"] " ")
}

; === ЛОГИКА ГЛОБАЛЬНОГО СОХРАНЕНИЯ ===
