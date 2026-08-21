; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: utils                         ║
; ║  Вспомогательные функции общего назначения      ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
; ───────────────────────────────────────────────────────────────────
; ЛОГИРОВАНИЕ В ФАЙЛ (doctor_log.txt рядом со скриптом)
; ───────────────────────────────────────────────────────────────────
Log(msg, level := "INFO") {
    try {
        logFile := A_ScriptDir "\doctor_log.txt"
        stamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        FileAppend("[" stamp "] [" level "] " msg "`r`n", logFile, "UTF-8")
    }
}

LogError(err, context := "") {
    msg := (IsObject(err) && err.HasOwnProp("Message")) ? err.Message : String(err)
    if (context != "")
        msg := context " — " msg
    OutputDebug(msg)
    Log(msg, "ERROR")
}

; ╔══════════════════════════════════════════════════════════════════════════════╗
; ║                            DOCTOR BINDER v2.1                                ║
; ║                              by maxon3r                                      ║
; ╚══════════════════════════════════════════════════════════════════════════════╝

SaveUndoState(action := "action") {
    global UndoHistory, MaxUndoSteps, SLOTS
    slotsCopy := []
    Loop Constants.MAX_SLOTS {
        slot := SLOTS[A_Index]
        slotCopy := Map("name", slot["name"], "hotkey", slot["hotkey"], "enabled", slot["enabled"], "category", slot.Has("category") ? slot["category"] : "", "statType", slot.Has("statType") ? slot["statType"] : "", "lines", [])
        for line in slot["lines"]
            slotCopy["lines"].Push(Map("text", line["text"], "delay", line["delay"]))
        slotsCopy.Push(slotCopy)
    }
    UndoHistory.Push(Map("action", action, "slots", slotsCopy, "time", A_Now))
    while UndoHistory.Length > MaxUndoSteps
        UndoHistory.RemoveAt(1)
}

Undo(*) {
    global UndoHistory, SLOTS
    if UndoHistory.Length = 0 {
        ShowNotify("Нет действий для отмены", "warning")
        return
    }
    state := UndoHistory.Pop()
    Loop Constants.MAX_SLOTS
        SLOTS[A_Index] := state["slots"][A_Index]
    RefreshBindList()
    UpdateOverlayData()
    RegisterAllHotkeys()
    ShowNotify("↩ Отменено: " state["action"], "success")
}

GetCurrentModifiers() {
    mods := ""
    if GetKeyState("Ctrl", "P")
        mods .= "^"
    if GetKeyState("Alt", "P")
        mods .= "!"
    if GetKeyState("Shift", "P")
        mods .= "+"
    if GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
        mods .= "#"
    return mods
}

GetPatientDisplay() {
    global STATE, CFG
    
    id := STATE["patientId"]
    if id = ""
        return ""
    
    switch CFG["patientFormat"] {
        case "at":
            return "@" id
        case "quote":
            return "`"" id   ; Только открывающая кавычка
        default:
            return id
    }
}

MarkUnsaved() {
    global GlobalUnsavedChanges, g_BtnGlobalSave
    
    ; Запоминаем, что есть изменения
    GlobalUnsavedChanges := true
    
    ; Проверяем, существует ли кнопка физически
    if IsObject(g_BtnGlobalSave) && g_BtnGlobalSave.HasOwnProp("ctrl") {
        try {
            ; SAVE становится primary action (cyan)
            UpdateButtonState(g_BtnGlobalSave, true, "primary")
            g_BtnGlobalSave.ctrl.Text := "СОХРАНИТЬ ИЗМЕНЕНИЯ"
        }
    }
    ; Нижний status bar: ● UNSAVED CHANGES
    try UpdateSaveBar(true)
}

UpdateButtonState(btnObj, isActive, style := "primary") {
    global THEME
    if !IsObject(btnObj)
        return
    
    ; === ЗАЩИТА ОТ МИГАНИЯ ===
    ; Если состояние кнопки не изменилось, ничего не делаем
    if (btnObj.HasOwnProp("lastState") && btnObj.lastState = isActive)
        return
        
    btnObj.lastState := isActive
    ; =========================
    
    btnObj.isClickable := isActive
    
    try {
        try {
            btnObj.SetEnabledStyle(isActive, style)
            return
        } catch {
            ; старые Map-кнопки используют fallback ниже
        }
        if isActive {
            colors := btnObj.GetColors(style)
            btnObj.colors := colors
            btnObj.ApplyVisual(colors.bg, colors.text)
        } else {
            btnObj.colors := {bg: THEME["bgLight"], hover: THEME["bgLight"], pressed: THEME["bgLight"], border: THEME["border"], borderHover: THEME["border"], text: THEME["textMuted"]}
            btnObj.ApplyVisual(btnObj.colors.bg, btnObj.colors.text)
        }
    }
}


; ═══════════════════════════════════════════════════════════════════════════
; ПРОВЕРКА ИЗМЕНЕНИЙ (DIRTY CHECK)
; ═══════════════════════════════════════════════════════════════════════════

CheckProfileDirty(*) {
    global MainGui, STATE, g_BtnSaveProfile
    
    if !MainGui
        return
    if !g_BtnSaveProfile
        return
    
    try {
        isDirty := false
        
        if (MainGui["ProfileName"].Value != STATE["myName"])
            isDirty := true
        if (MainGui["ProfileHospital"].Value != STATE["hospital"])
            isDirty := true
        if (MainGui["ProfileSpecialty"].Value != STATE["specialty"])
            isDirty := true
        
        UpdateButtonState(g_BtnSaveProfile, isDirty, "primary")
        UpdateProfileStatus(isDirty)
    }
}

CheckSettingsDirty(*) {
    global MainGui, CFG, g_BtnSaveSettings, EditorConfirmDelete, CurrentIdFormat
    
    if !MainGui || !g_BtnSaveSettings
        return

    try {
        isDirty := false
        
        ; Сравнение значений GUI с сохраненными в CFG
        
        if (MainGui["Value_ChatKey"].Value != CFG["chatKey"])
            isDirty := true
        
        if (CurrentIdFormat != CFG["patientFormat"])
            isDirty := true
        
         if (MainGui["Value_Wheel"].Value != CFG["hotkeyWheel"]) isDirty := true

        if (MainGui["SettingsOnlyGTA"].Value != (CFG["onlyGTA"] ? 1 : 0))
            isDirty := true

        if (Integer(MainGui["SettingsBaseDelay"].Value) != CFG["baseDelay"])
            isDirty := true
        if (Integer(MainGui["SettingsAfterChat"].Value) != CFG["afterChatDelay"])
            isDirty := true
        if (Integer(MainGui["SettingsAfterEnter"].Value) != CFG["afterEnterDelay"])
            isDirty := true
        if (Integer(MainGui["SettingsJitter"].Value) != CFG["jitter"])
            isDirty := true
        
        if (Integer(MainGui["SettingsOverlayOpacity"].Value) != CFG["overlayOpacity"])
            isDirty := true
            
        if (MainGui["SettingsConfirmDelete"].Value != (EditorConfirmDelete ? 1 : 0))
            isDirty := true
        if (MainGui["SettingsNotifyKeywords"].Value != (CFG["notifyKeywords"] ? 1 : 0))
            isDirty := true

        if (MainGui["Value_Overlay"].Value != CFG["hotkeyOverlay"])
            isDirty := true
        if (MainGui["Value_MiniOverlay"].Value != CFG["hotkeyMiniOverlay"])
            isDirty := true
        if (MainGui["Value_StopSending"].Value != CFG["hotkeyStopSending"])
            isDirty := true
        if (MainGui["Value_ReplySms"].Value != CFG["hotkeyReplySms"])
            isDirty := true

        if (MainGui["SettingsNotifySms"].Value != (CFG["notifySms"] ? 1 : 0))
            isDirty := true
        if (MainGui["SettingsNotifyMention"].Value != (CFG["notifyMention"] ? 1 : 0))
            isDirty := true

        if (MainGui["SettingsEditorAutoSave"].Value != (CFG["editorAutoSaveDelay"] ? 1 : 0))
            isDirty := true
            
        ; === [ИСПРАВЛЕНИЕ] Добавлена проверка авто-скриншотов ===
        if (MainGui["SettingsAutoScreen"].Value != (CFG["autoScreen"] ? 1 : 0))
            isDirty := true
        
        UpdateButtonState(g_BtnSaveSettings, isDirty, "primary")
    }
}


; ═══════════════════════════════════════════════════════════════════════════════
; УВЕДОМЛЕНИЯ
; ═══════════════════════════════════════════════════════════════════════════════

ExitHandler(ExitReason, Code) {
    global GlobalUnsavedChanges
    
    ; Вариант 1: Спрашивать, если забыл сохранить (Безопасно)
    if (GlobalUnsavedChanges) {
        res := MsgBox("У вас есть несохраненные изменения.`nСохранить их перед выходом?", "Doctor Binder", "YesNo Icon!")
        
        if (res = "Yes") {
            try {
                SaveConfig()
                SaveCustomFilters()
            }
        }
        ; Если "No" — просто вылетаем моментально, ничего не сохраняя
    }
    
    return 0
}





; ═══════════════════════════════════════════════════════════════════════════════
; ФУНКЦИЯ ТЕМНОЙ ТЕМЫ (ВСТАВИТЬ В САМЫЙ КОНЕЦ СКРИПТА)
; ═══════════════════════════════════════════════════════════════════════════════
FormatHotkey(hk) {
    if (hk = "")
        return "—"
    
    ; Собираем красивую строку
    result := ""
    
    ; Проверяем модификаторы
    if InStr(hk, "^") {
        result .= "Ctrl + "
        hk := StrReplace(hk, "^", "")
    }
    if InStr(hk, "!") {
        result .= "Alt + "
        hk := StrReplace(hk, "!", "")
    }
    if InStr(hk, "+") {
        result .= "Shift + "
        hk := StrReplace(hk, "+", "")
    }
    if InStr(hk, "#") {
        result .= "Win + "
        hk := StrReplace(hk, "#", "")
    }
    
    ; Делаем первую букву заглавной
    try {
        if StrLen(hk) > 1
            hk := StrTitle(hk)
        else
            hk := StrUpper(hk)
    }
    
    return result . hk
}


; ══════════════════════════════════════════════════════════════════════════
; ЛОГИКА УМНЫХ СКРИНШОТОВ (SMART SCREENSHOTS)
; ══════════════════════════════════════════════════════════════════════════

; 1. Открытие диалога выбора папки
