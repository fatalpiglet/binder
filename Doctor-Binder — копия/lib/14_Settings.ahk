; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: settings                      ║
; ║  Сохранение/загрузка конфигурации и настроек    ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
ApplyAndSaveSettings(*) {
    global MainGui, CFG, g_BtnSaveSettings, EditorConfirmDelete, CurrentIdFormat, GlobalUnsavedChanges, g_BtnGlobalSave, THEME, OverlayGui, OverlayVisible
    
    ; === 1. ВИЗУАЛЬНЫЙ ЭФФЕКТ (МГНОВЕННЫЙ ОТКЛИК) ===
    if g_BtnSaveSettings {
        g_BtnSaveSettings.ctrl.Text := "Сохранение…"
        try g_BtnSaveSettings.SetVisual(THEME["bgElevated"], THEME["textDim"], THEME["bgElevated"], THEME["border"])
        g_BtnSaveSettings.ctrl.Redraw()
        Sleep(50) ; Даем Windows время перерисовать кнопку перед нагрузкой
    }
    ; Чтение настроек колеса (извлекаем ID из строки "[ID] Название")
    GetIdFromDDL(ctrlName) {
        text := MainGui[ctrlName].Text
        if RegExMatch(text, "^\[(\d+)\]", &match)
            return Integer(match[1])
        return 0
    }
    
    ; === 2. СЧИТЫВАНИЕ ДАННЫХ ===
    CFG["chatKey"] := MainGui["Value_ChatKey"].Value
    CFG["onlyGTA"] := MainGui["SettingsOnlyGTA"].Value = 1
    CFG["notifyMention"] := MainGui["SettingsNotifyMention"].Value = 1
    CFG["baseDelay"] := Integer(MainGui["SettingsBaseDelay"].Value)
    CFG["afterChatDelay"] := Integer(MainGui["SettingsAfterChat"].Value)
    CFG["afterEnterDelay"] := Integer(MainGui["SettingsAfterEnter"].Value)
    CFG["jitter"] := Integer(MainGui["SettingsJitter"].Value)
    CFG["overlayOpacity"] := Integer(MainGui["SettingsOverlayOpacity"].Value) 
    CFG["notifySms"] := MainGui["SettingsNotifySms"].Value = 1
    CFG["notifyKeywords"] := MainGui["SettingsNotifyKeywords"].Value = 1
    CFG["patientFormat"] := CurrentIdFormat
    CFG["editorAutoSaveDelay"] := MainGui["SettingsEditorAutoSave"].Value = 1
    CFG["autoScreen"] := MainGui["SettingsAutoScreen"].Value = 1
    CFG["hotkeyWheel"] := MainGui["Value_Wheel"].Value

    ; --- Автосохранение: переключатель + выбранный интервал ---
    CFG["autoSave"] := MainGui["SettingsAutoSaveEnabled"].Value = 1
    try {
        intervals := AutoSaveIntervals()
        idx := Integer(MainGui["SettingsAutoSaveInterval"].Value)
        if (idx >= 1 && idx <= intervals.Length)
            CFG["autoSaveInterval"] := intervals[idx]
    }
    
    EditorConfirmDelete := MainGui["SettingsConfirmDelete"].Value = 1
    
    CFG["hotkeyOverlay"] := MainGui["Value_Overlay"].Value
    CFG["hotkeyMiniOverlay"] := MainGui["Value_MiniOverlay"].Value
    CFG["hotkeyStopSending"] := MainGui["Value_StopSending"].Value
    CFG["hotkeyReplySms"] := MainGui["Value_ReplySms"].Value

    ; === 3. ПРИМЕНЕНИЕ ===
    RegisterSystemHotkeys()
    ; Новый интервал вступает в силу сразу, без перезапуска приложения
    ApplyAutoSaveTimer()
    
    if OverlayGui && OverlayVisible
        WinSetTransparent(CFG["overlayOpacity"], OverlayGui)
    
    ; === 4. БЫСТРОЕ СОХРАНЕНИЕ (Только настройки, без биндов) ===
    SaveGeneralSettings() 
    
    ; === 5. СБРОС КНОПКИ (УСПЕХ) ===
    if g_BtnSaveSettings {
        UpdateButtonState(g_BtnSaveSettings, false)
        g_BtnSaveSettings.ctrl.Text := "Сохранено"
        g_BtnSaveSettings.ctrl.Redraw()
        
        ; Через 1.5 сек возвращаем обычный текст
        SetTimer(() => RestoreSettingsBtnText(), -1500)
    }

    ; Если не было изменений в биндах, гасим и главную кнопку
    ; (Если были изменения в биндах, главная кнопка останется гореть, и это правильно)
    
    ShowNotify("Настройки применены", "success")
    ShowMainGui()
}

RestoreSettingsBtnText() {
    global g_BtnSaveSettings, THEME
    if g_BtnSaveSettings {
        g_BtnSaveSettings.ctrl.Text := "Сохранить изменения"
        ; Нет изменений — кнопка приглушена (disabled-состояние дизайн-системы)
        try g_BtnSaveSettings.SetEnabledStyle(false)
        g_BtnSaveSettings.ctrl.Redraw()
    }
}

ResetSettingsDefault(*) {
    global MainGui, CFG
    
    CFG["baseDelay"] := Constants.DEFAULT_BASE_DELAY
    CFG["afterChatDelay"] := Constants.DEFAULT_AFTER_CHAT_DELAY
    CFG["afterEnterDelay"] := Constants.DEFAULT_AFTER_ENTER_DELAY
    CFG["jitter"] := Constants.DEFAULT_JITTER
    CFG["overlayOpacity"] := Constants.DEFAULT_OPACITY
    
    MainGui["SettingsBaseDelay"].Value := Constants.DEFAULT_BASE_DELAY
    MainGui["SettingsAfterChat"].Value := Constants.DEFAULT_AFTER_CHAT_DELAY
    MainGui["SettingsAfterEnter"].Value := Constants.DEFAULT_AFTER_ENTER_DELAY
    MainGui["SettingsJitter"].Value := Constants.DEFAULT_JITTER
    MainGui["SettingsOverlayOpacity"].Value := Constants.DEFAULT_OPACITY
    
    ShowNotify("Сброшено!", "success")
}

ResetAllBinds(*) {
    result := MsgBox("Сбросить ВСЕ бинды к стандартным?", "Внимание!", "YesNo Icon!")
    if result = "Yes" {
        SaveUndoState("Сброс всех биндов")
        ImportDefaultBinds()
        RefreshBindList()
        UpdateOverlayData()
        RegisterAllHotkeys()
        ShowNotify("Бинды сброшены!", "success")
    }
}

SaveEverything() {
    global GlobalUnsavedChanges, g_BtnGlobalSave
    
    ; 1. ВИЗУАЛЬНЫЙ ЭФФЕКТ
    if g_BtnGlobalSave {
        UpdateButtonState(g_BtnGlobalSave, true, "primary")
        g_BtnGlobalSave.ctrl.Text := "Сохранение…"
        g_BtnGlobalSave.ctrl.Redraw()
        Sleep(50) ; <-- ВАЖНО: Дать время на отрисовку
    }
    
    ; 2. ТЯЖЕЛАЯ РАБОТА (СОХРАНЕНИЕ)
    try {
        SaveConfig()        ; Сохраняем настройки
        SaveCustomFilters() ; Сохраняем фильтры
        
        ; (Опционально) Еще небольшая пауза, чтобы пользователь точно заметил процесс, 
        ; если компьютер слишком быстрый :)
        Sleep(300) 
        
    } catch as err {
        LogError(err, "SaveEverything")
        ShowNotify("Ошибка сохранения: " err.Message, "error")
        return
    }
    
    ; 3. ФИНАЛ: СБРОС СОСТОЯНИЯ
    GlobalUnsavedChanges := false
    try UpdateSaveBar(false)
    try RegisterSaveEvent(false)
    
    if g_BtnGlobalSave {
        ; Выключаем кнопку (делаем серой)
        UpdateButtonState(g_BtnGlobalSave, false)
        g_BtnGlobalSave.ctrl.Text := "Сохранено"
        
        ; Через 2 секунды возвращаем обычный текст
        SetTimer(() => TryRestoreButtonText(), -2000)
    }
    
    ShowNotify("Все изменения сохранены", "success")
}

; Вспомогательная функция для таймера (чтобы не было ошибок, если кнопку удалят)
TryRestoreButtonText() {
    global g_BtnGlobalSave, GlobalUnsavedChanges
    if IsObject(g_BtnGlobalSave) && !GlobalUnsavedChanges
        g_BtnGlobalSave.ctrl.Text := "Сохранить изменения"
}



; ═══════════════════════════════════════════════════════════════════════════════
; СОХРАНЕНИЕ / ЗАГРУЗКА
; ═══════════════════════════════════════════════════════════════════════════════
; Главная функция (сохраняет ВСЁ - долго)
SaveConfig() {
    BackupConfig()        ; Сначала делаем резервную копию текущего конфига
    SaveGeneralSettings() ; Быстро
    SaveBinds()           ; Медленно (но нужно при выходе или глобальном сейве)
}

; ───────────────────────────────────────────────────────────────────
; БЭКАП КОНФИГА ПЕРЕД СОХРАНЕНИЕМ
; Копирует doctor_config.ini в папку backups\ с меткой времени,
; оставляя только последние N копий.
; ───────────────────────────────────────────────────────────────────
BackupConfig() {
    global CONFIG_FILE
    static lastBackup := 0

    ; Не чаще раза в 2 секунды (SaveConfig делает несколько записей подряд)
    if (A_TickCount - lastBackup < 2000)
        return
    lastBackup := A_TickCount

    try {
        if !FileExist(CONFIG_FILE)
            return
        backupDir := A_ScriptDir "\backups"
        if !DirExist(backupDir)
            DirCreate(backupDir)
        stamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
        FileCopy(CONFIG_FILE, backupDir "\doctor_config_" stamp ".bak", 1)
        TrimBackups(backupDir)
    } catch as err {
        OutputDebug("Backup failed: " err.Message)
    }
}

; Оставляем только последние N бэкапов (самые старые удаляются)
TrimBackups(dir) {
    maxKeep := 10
    names := []
    Loop Files, dir "\*.bak"
        names.Push(A_LoopFileName)

    while names.Length > maxKeep {
        oldest := names[1]
        oldestIdx := 1
        Loop names.Length {
            if names[A_Index] < oldest {
                oldest := names[A_Index]
                oldestIdx := A_Index
            }
        }
        try FileDelete(dir "\" oldest)
        names.RemoveAt(oldestIdx)
    }
}

; ───────────────────────────────────────────────────────────────────
; АВТОСОХРАНЕНИЕ (вызывается по таймеру)
; Сохраняет изменения тихо, если они есть и скрипт не занят отправкой.
; ───────────────────────────────────────────────────────────────────
AutoSaveTick() {
    global GlobalUnsavedChanges, STATE, CFG, MainGui

    ; Планируем следующее срабатывание (для строки «следующее через N сек»)
    STATE["nextAutoSave"] := A_TickCount + Max(5, Integer(CFG["autoSaveInterval"])) * 1000
    try UpdateAutoSaveInfoLine()

    ; Выключено — таймер останавливаем совсем
    if !CFG["autoSave"] {
        try SetTimer(AutoSaveTick, 0)
        return
    }
    if !GlobalUnsavedChanges
        return
    if STATE["isSending"]
        return
    if !MainGui
        return

    try {
        SaveConfig()
        SaveCustomFilters()
        GlobalUnsavedChanges := false
        try UpdateSaveBar(false)
        try RegisterSaveEvent(true)
        TryRestoreButtonText()
        UpdateAutoSaveStatus()
        Log("Автосохранение выполнено", "INFO")
        ShowNotify("Автосохранение выполнено", "success", 1500)
    } catch as err {
        LogError(err, "AutoSaveTick")
    }
}

; Функция сохранения ТОЛЬКО настроек (Мгновенно)
SaveGeneralSettings() {
    global CFG, STATE, STATS, CONFIG_FILE
    
    try {
        ; --- ОСНОВНЫЕ ---
        IniWrite(CFG["chatKey"], CONFIG_FILE, "Settings", "chatKey")
        IniWrite(CFG["onlyGTA"] ? 1 : 0, CONFIG_FILE, "Settings", "onlyGTA")
        IniWrite(CFG["notifyMention"] ? 1 : 0, CONFIG_FILE, "Settings", "notifyMention")
        IniWrite(CFG["baseDelay"], CONFIG_FILE, "Settings", "baseDelay")
        IniWrite(CFG["afterChatDelay"], CONFIG_FILE, "Settings", "afterChatDelay")
        IniWrite(CFG["afterEnterDelay"], CONFIG_FILE, "Settings", "afterEnterDelay")
        IniWrite(CFG["jitter"], CONFIG_FILE, "Settings", "jitter")
        IniWrite(CFG["patientFormat"], CONFIG_FILE, "Settings", "patientFormat")
        IniWrite(CFG["overlayOpacity"], CONFIG_FILE, "Settings", "overlayOpacity")
        IniWrite(CFG["notifySms"] ? 1 : 0, CONFIG_FILE, "Settings", "notifySms")
        IniWrite(CFG["notifyKeywords"] ? 1 : 0, CONFIG_FILE, "Settings", "notifyKeywords")
        IniWrite(CFG["editorAutoSaveDelay"] ? 1 : 0, CONFIG_FILE, "Settings", "editorAutoSaveDelay")
        IniWrite(STATS.Has("saveCount") ? STATS["saveCount"] : 0, CONFIG_FILE, "Stats", "saveCount")
        IniWrite(CFG["autoSave"] ? 1 : 0, CONFIG_FILE, "Settings", "autoSave")
        IniWrite(CFG["autoSaveInterval"], CONFIG_FILE, "Settings", "autoSaveInterval")
        
        ; Радиальное меню
        IniWrite(CFG["enableWheel"] ? 1 : 0, CONFIG_FILE, "Settings", "enableWheel")
        IniWrite(CFG["hotkeyWheel"], CONFIG_FILE, "Hotkeys", "wheel")
        
        IniWrite(CFG["wheelTop"], CONFIG_FILE, "Hotkeys", "wheelTop")
        IniWrite(CFG["wheelRight"], CONFIG_FILE, "Hotkeys", "wheelRight")
        IniWrite(CFG["wheelBottom"], CONFIG_FILE, "Hotkeys", "wheelBottom")
        IniWrite(CFG["wheelLeft"], CONFIG_FILE, "Hotkeys", "wheelLeft")

        ; --- ХОТКЕИ ---
        IniWrite(CFG["hotkeyOverlay"], CONFIG_FILE, "Hotkeys", "overlay")
        IniWrite(CFG["hotkeyMiniOverlay"], CONFIG_FILE, "Hotkeys", "miniOverlay")
        IniWrite(CFG["hotkeyStopSending"], CONFIG_FILE, "Hotkeys", "stopSending")
        IniWrite(CFG["hotkeyMainGui"], CONFIG_FILE, "Hotkeys", "mainGui")
        IniWrite(CFG["hotkeyReplySms"], CONFIG_FILE, "Hotkeys", "replySms")
        
        ; --- ПРОФИЛЬ ---
        IniWrite(STATE["myName"], CONFIG_FILE, "Settings", "myName")
        IniWrite(STATE["hospital"], CONFIG_FILE, "Profile", "hospital")
        IniWrite(STATE["rank"], CONFIG_FILE, "Profile", "rank")
        IniWrite(STATE["specialty"], CONFIG_FILE, "Profile", "specialty")

        ; --- СТАТИСТИКА ---
        IniWrite(STATS["patientsHealed"], CONFIG_FILE, "Stats", "patientsHealed")
        IniWrite(STATS["pillsGiven"], CONFIG_FILE, "Stats", "pillsGiven")
        IniWrite(STATS["injectionsGiven"], CONFIG_FILE, "Stats", "injectionsGiven")
        IniWrite(STATS["operationsDone"], CONFIG_FILE, "Stats", "operationsDone")
        IniWrite(STATS["medChecks"], CONFIG_FILE, "Stats", "medChecks")
        IniWrite(STATS["vaccinesGiven"], CONFIG_FILE, "Stats", "vaccinesGiven")
        IniWrite(STATS["totalSent"], CONFIG_FILE, "Stats", "totalSent")

        ; --- ПРАВИЛА СКРИНШОТОВ ---
        IniWrite(CFG["autoScreen"] ? 1 : 0, CONFIG_FILE, "Screenshots", "enabled")
        try IniDelete(CONFIG_FILE, "ScreenRules")
        IniWrite(CFG["ScreenRules"].Length, CONFIG_FILE, "ScreenRules", "count")
        
        for i, rule in CFG["ScreenRules"] {
            IniWrite(rule["name"], CONFIG_FILE, "ScreenRules", "rule" i "_name")
            IniWrite(rule["phrase"], CONFIG_FILE, "ScreenRules", "rule" i "_phrase")
            IniWrite(rule["path"], CONFIG_FILE, "ScreenRules", "rule" i "_path")
        }
    }
}

; Функция сохранения ТОЛЬКО биндов (Тяжелая операция)
SaveBinds() {
    global SLOTS, CONFIG_FILE, Constants
    
    Loop Constants.MAX_SLOTS {
        sec := "Slot" A_Index
        slot := SLOTS[A_Index]
        
        if slot["name"] = "" && slot["lines"].Length = 0 {
            try IniDelete(CONFIG_FILE, sec)
            continue
        }
        
        IniWrite(slot["name"], CONFIG_FILE, sec, "name")
        IniWrite(slot["hotkey"], CONFIG_FILE, sec, "hotkey")
        IniWrite(slot["enabled"] ? 1 : 0, CONFIG_FILE, sec, "enabled")
        IniWrite(slot["category"], CONFIG_FILE, sec, "category")
        IniWrite(slot["statType"], CONFIG_FILE, sec, "statType")
        IniWrite(slot["lines"].Length, CONFIG_FILE, sec, "lineCount")
        
        for idx, line in slot["lines"] {
            IniWrite(line["text"], CONFIG_FILE, sec, "line" idx "_text")
            IniWrite(line["delay"], CONFIG_FILE, sec, "line" idx "_delay")
        }
    }
}

LoadConfig() {
    global CFG, SLOTS, STATE, STATS, CONFIG_FILE
    
    if !FileExist(CONFIG_FILE) {
        ImportDefaultBinds()
        return
    }
    
    try {
        ; --- НАСТРОЙКИ ---
        CFG["chatKey"] := IniRead(CONFIG_FILE, "Settings", "chatKey", CFG["chatKey"])
        CFG["onlyGTA"] := IniRead(CONFIG_FILE, "Settings", "onlyGTA", 1) = 1
        CFG["notifyMention"] := IniRead(CONFIG_FILE, "Settings", "notifyMention", 1) = 1
        CFG["baseDelay"] := Integer(IniRead(CONFIG_FILE, "Settings", "baseDelay", CFG["baseDelay"]))
        CFG["afterChatDelay"] := Integer(IniRead(CONFIG_FILE, "Settings", "afterChatDelay", CFG["afterChatDelay"]))
        CFG["afterEnterDelay"] := Integer(IniRead(CONFIG_FILE, "Settings", "afterEnterDelay", CFG["afterEnterDelay"]))
        CFG["jitter"] := Integer(IniRead(CONFIG_FILE, "Settings", "jitter", CFG["jitter"]))
        CFG["patientFormat"] := IniRead(CONFIG_FILE, "Settings", "patientFormat", CFG["patientFormat"])
        CFG["overlayOpacity"] := Integer(IniRead(CONFIG_FILE, "Settings", "overlayOpacity", CFG["overlayOpacity"]))
        CFG["notifySms"] := IniRead(CONFIG_FILE, "Settings", "notifySms", 1) = 1
        CFG["notifyKeywords"] := IniRead(CONFIG_FILE, "Settings", "notifyKeywords", 0) = 1
        CFG["editorAutoSaveDelay"] := IniRead(CONFIG_FILE, "Settings", "editorAutoSaveDelay", 0) = 1
        STATS["saveCount"] := Integer(IniRead(CONFIG_FILE, "Stats", "saveCount", 0))
        CFG["autoSave"] := IniRead(CONFIG_FILE, "Settings", "autoSave", 1) = 1
        CFG["autoSaveInterval"] := Integer(IniRead(CONFIG_FILE, "Settings", "autoSaveInterval", 60))
        
        ; Радиальное меню
        CFG["enableWheel"] := IniRead(CONFIG_FILE, "Settings", "enableWheel", 1) = 1
        CFG["hotkeyWheel"] := IniRead(CONFIG_FILE, "Hotkeys", "wheel", "MButton")
        
        CFG["wheelTop"] := Integer(IniRead(CONFIG_FILE, "Hotkeys", "wheelTop", 0))
        CFG["wheelRight"] := Integer(IniRead(CONFIG_FILE, "Hotkeys", "wheelRight", 0))
        CFG["wheelBottom"] := Integer(IniRead(CONFIG_FILE, "Hotkeys", "wheelBottom", 0))
        CFG["wheelLeft"] := Integer(IniRead(CONFIG_FILE, "Hotkeys", "wheelLeft", 0))

        ; --- ХОТКЕИ ---
        CFG["hotkeyOverlay"] := IniRead(CONFIG_FILE, "Hotkeys", "overlay", "F10")
        CFG["hotkeyMiniOverlay"] := IniRead(CONFIG_FILE, "Hotkeys", "miniOverlay", "!F10")
        CFG["hotkeyStopSending"] := IniRead(CONFIG_FILE, "Hotkeys", "stopSending", "F8")
        CFG["hotkeyMainGui"] := IniRead(CONFIG_FILE, "Hotkeys", "mainGui", "F9")
        CFG["hotkeyReplySms"] := IniRead(CONFIG_FILE, "Hotkeys", "replySms", "F4")
        
        ; --- ПРОФИЛЬ ---
        STATE["myName"] := IniRead(CONFIG_FILE, "Settings", "myName", STATE["myName"])
        STATE["hospital"] := IniRead(CONFIG_FILE, "Profile", "hospital", "MCLV")
        STATE["rank"] := IniRead(CONFIG_FILE, "Profile", "rank", "Врач")
        STATE["specialty"] := IniRead(CONFIG_FILE, "Profile", "specialty", "Терапевт")
        
        ; --- СТАТИСТИКА ---
        STATS["patientsHealed"] := Integer(IniRead(CONFIG_FILE, "Stats", "patientsHealed", 0))
        STATS["pillsGiven"] := Integer(IniRead(CONFIG_FILE, "Stats", "pillsGiven", 0))
        STATS["injectionsGiven"] := Integer(IniRead(CONFIG_FILE, "Stats", "injectionsGiven", 0))
        STATS["operationsDone"] := Integer(IniRead(CONFIG_FILE, "Stats", "operationsDone", 0))
        STATS["medChecks"] := Integer(IniRead(CONFIG_FILE, "Stats", "medChecks", 0))
        STATS["vaccinesGiven"] := Integer(IniRead(CONFIG_FILE, "Stats", "vaccinesGiven", 0))
        STATS["totalSent"] := Integer(IniRead(CONFIG_FILE, "Stats", "totalSent", 0))
        
        ; === ЗАГРУЗКА ПРАВИЛ СКРИНШОТОВ ===
        CFG["autoScreen"] := IniRead(CONFIG_FILE, "Screenshots", "enabled", 0) = 1
        CFG["ScreenRules"] := []
        
        ruleCount := Integer(IniRead(CONFIG_FILE, "ScreenRules", "count", 0))
        Loop ruleCount {
            rName := IniRead(CONFIG_FILE, "ScreenRules", "rule" A_Index "_name", "")
            rPhrase := IniRead(CONFIG_FILE, "ScreenRules", "rule" A_Index "_phrase", "")
            rPath := IniRead(CONFIG_FILE, "ScreenRules", "rule" A_Index "_path", "")
            
            if (rName != "" && rPhrase != "" && rPath != "") {
                CFG["ScreenRules"].Push(Map("name", rName, "phrase", rPhrase, "path", rPath))
            }
        }

        ; --- СЛОТЫ ---
        Loop Constants.MAX_SLOTS {
            SlotIndex := A_Index
            section := "Slot" SlotIndex
            SLOTS[SlotIndex] := Map("name", "", "hotkey", "", "enabled", false, "category", "", "statType", "", "lines", [])
            
            try {
                name := IniRead(CONFIG_FILE, section, "name", "")
                if (name != "") {
                    SLOTS[SlotIndex]["name"] := name
                    SLOTS[SlotIndex]["hotkey"] := IniRead(CONFIG_FILE, section, "hotkey", "")
                    SLOTS[SlotIndex]["enabled"] := (IniRead(CONFIG_FILE, section, "enabled", 0) = 1)
                    SLOTS[SlotIndex]["category"] := IniRead(CONFIG_FILE, section, "category", "Основные")
                    SLOTS[SlotIndex]["statType"] := IniRead(CONFIG_FILE, section, "statType", "")
                    lineCount := Integer(IniRead(CONFIG_FILE, section, "lineCount", 0))
                    if lineCount > 0 {
                        Loop lineCount {
                            txt := IniRead(CONFIG_FILE, section, "line" A_Index "_text", "")
                            del := Integer(IniRead(CONFIG_FILE, section, "line" A_Index "_delay", 0))
                            SLOTS[SlotIndex]["lines"].Push(Map("text", txt, "delay", del))
                        }
                    }
                }
            }
        }
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; ИМПОРТ СТАНДАРТНЫХ БИНДОВ
; ═══════════════════════════════════════════════════════════════════════════════
ImportDefaultBinds() {
    global SLOTS
    
    ; [1] Клятва Гиппократа
    SLOTS[1] := Map(
        "name", "Клятва Гиппократа",
        "hotkey", "!0",
        "enabled", true,
        "category", "Основные",
        "statType", "",
        "lines", [
            Map("text", "/де На столе лежит папка с текстом клятвы.", "delay", 2300),
            Map("text", "/я взявшись за папку, начинает зачитывать текст клятвы.", "delay", 2300),
            Map("text", "Клянусь всеми богами и богинями, в свидетели сих слов их зазывая,", "delay", 2300),
            Map("text", "Не навредить больному и молящему, врачебное искусство постигая.", "delay", 2300),
            Map("text", "Не нарушать законы Штата и морали, не говорить обидных бранных слов.", "delay", 2300),
            Map("text", "Не отказать в приеме пациенту, любому жителю из всех трех городов.", "delay", 2300),
            Map("text", "Клянусь я подбирать режим больному с моими силами и разумением сообразно.", "delay", 2300),
            Map("text", "И величайшее уважение к жизни человека проявлять, никогда не прибегать к осуществлению эвтаназии;", "delay", 2300),
            Map("text", "А ежели не сведущ буду в хирургии я, ни в коем случае не сделаю сечения.", "delay", 2300),
            Map("text", "Клянусь, что я увидел и услышал, считать врачебной тайной при лечении.", "delay", 2300),
            Map("text", "Мне, нерушимо выполняющему клятву, да будет счастье в жизни на земле.", "delay", 2300),
            Map("text", "/фд Да будет так*положив папку с текстом клятвы на своё место.", "delay", 2300)
        ]
    )
    
    ; [2] Приветствие
    SLOTS[2] := Map(
        "name", "Приветствие",
        "hotkey", "!1",
        "enabled", true,
        "category", "Основные",
        "statType", "",
        "lines", [
            Map("text", "Здравствуйте. Я ваш лечащий врач — {MY}. Что вас беспокоит?", "delay", 2300)
        ]
    )
    
    ; [3] Лечение таблетками
    SLOTS[3] := Map(
        "name", "Таблетки",
        "hotkey", "!2",
        "enabled", true,
        "category", "Лечение",
        "statType", "pills",
        "lines", [
            Map("text", "/фд Сейчас я окажу Вам медицинскую помощь*осматривая пациента", "delay", 2300),
            Map("text", "/я записывает данные о симптомах в медкарту пациента и достает медикамент из сумки", "delay", 2300),
            Map("text", "/фд Вам поможет " Chr(34) "Полиспектрин" Chr(34) "*передавая препарат и бутылку воды пациенту", "delay", 2300),
            Map("text", "/фд Стоимость медикаментов составила 60$*выписывая счёт за лечение", "delay", 2300),
            Map("text", "/фд Всего вам доброго, не болейте*передавая счёт за лечение пациенту", "delay", 2300)
        ]
    )
    
    ; Остальные слоты инициализируем пустыми (ТОЛЬКО если они не существуют)
    Loop Constants.MAX_SLOTS {
        if A_Index > 3 {
            if !SLOTS.Has(A_Index) {
                SLOTS[A_Index] := Map(
                    "name", "",
                    "hotkey", "",
                    "lines", [],
                    "enabled", false,
                    "category", "",
                    "statType", ""
                )
            }
        }
    }
}

; Функция для переключения состояния кнопок (Активная / Неактивная)
SetDelayPreset(mode) {
    global MainGui, CFG
    
    vals := []
    switch mode {
        case "fast":
            vals := [1200, 150, 200, 50]
        case "norm":
            vals := [2300, 300, 400, 200]
        case "rp":
            vals := [4500, 600, 800, 500]
    }
    
    CFG["baseDelay"] := vals[1]
    CFG["afterChatDelay"] := vals[2]
    CFG["afterEnterDelay"] := vals[3]
    CFG["jitter"] := vals[4]

    if MainGui {
        MainGui["SettingsBaseDelay"].Value := vals[1]
        MainGui["SettingsAfterChat"].Value := vals[2]
        MainGui["SettingsAfterEnter"].Value := vals[3]
        MainGui["SettingsJitter"].Value := vals[4]
    }
    
    CheckSettingsDirty()
    ShowNotify("Установлен пресет: " mode, "info")
}

; ═══════════════════════════════════════════════════════════════════════════════
; ЛОГИКА СЕГМЕНТИРОВАННЫХ КНОПОК (ВЫБОР ФОРМАТА ID)
; ═══════════════════════════════════════════════════════════════════════════════
SetIdFormatGUI(fmt) {
    global MainGui, THEME, CurrentIdFormat, IdFormatButtons
    
    CurrentIdFormat := fmt
    
    for id, btn in IdFormatButtons {
        active := (id = fmt)
        if active
            btn.SetVisual(THEME["bgSelected"], THEME["accent"], THEME["bgSelected"], THEME["accentDark"], THEME["accent"])
        else
            btn.SetVisual(THEME["bgElevated"], THEME["textDim"], THEME["bgHover"], THEME["border"])
    }

    ; Карточка «Текущий пациент» показывает актуальный формат вставки
    try UpdatePatientCard()

    CheckSettingsDirty()
}


; ═══════════════════════════════════════════════════════════════════════════════
; СИСТЕМА СМС: КРАСИВЫЕ УВЕДОМЛЕНИЯ (BOTTOM-RIGHT)
; ═══════════════════════════════════════════════════════════════════════════════

BrowseFolder(cfgKey) {
    global MainGui, CFG
    
    ; Открываем диалог Windows
    selected := DirSelect("*" CFG[cfgKey], 3, "Выберите папку для отчетов")
    
    if (selected != "") {
        CFG[cfgKey] := selected
        try MainGui["Path_" cfgKey].Value := selected
        CheckSettingsDirty() ; Включаем кнопку "Сохранить"
    }
}

; 2. Функция создания и перемещения скриншота
TakeSmartScreenshotPath(targetPath) {
    global CFG
    
    Send "{F8}"
    ; Передаем путь прямо в функцию перемещения
    SetTimer(() => MoveScreenshotToFolder(targetPath), -1200)
}

; 3. Перемещение файла
MoveScreenshotToFolder(targetPath) {
    try {
        ; Путь к скринам GTA (стандартный)
        sourceDir := A_MyDocuments "\GTA San Andreas User Files\SAMP\screens"
        
        ; Создаем папку назначения (с датой), если нет
        dateFolder := FormatTime(A_Now, "yyyy-MM-dd")
        finalDir := targetPath "\" dateFolder
        
        if !DirExist(finalDir)
            DirCreate(finalDir)
            
        ; Ищем самый свежий файл в папке GTA
        latestFile := ""
        latestTime := 0
        Loop Files, sourceDir "\*.png" {
            if (A_LoopFileTimeModified > latestTime) {
                latestTime := A_LoopFileTimeModified
                latestFile := A_LoopFileFullPath
            }
        }
        
        if (latestFile = "")
            return
            
        ; Проверка на свежесть (если файл создан более 5 секунд назад - это старый скрин)
        ; ВАЖНО: используем latestTime — время САМОГО СВЕЖЕГО файла,
        ; а не A_LoopFileTimeModified (это время последнего файла в цикле)
        if (DateDiff(A_Now, latestTime, "Seconds") < 5) {
            ; Переименовываем и перемещаем
            SplitPath latestFile, &name, &dir, &ext
            newName := FormatTime(A_Now, "HH-mm-ss") "_" A_TickCount "." ext
            FileMove latestFile, finalDir "\" newName
            
            ; Тихое уведомление
            ShowNotify("Скриншот сохранён!", "success", 1500)
        }
    }
}


; === УПРАВЛЕНИЕ ПРАВИЛАМИ СКРИНШОТОВ ===

; === УПРАВЛЕНИЕ ПРАВИЛАМИ СКРИНШОТОВ ===

RefreshScreenRulesList() {
    global MainGui, CFG
    if !MainGui
        return
    
    lv := MainGui["ScreenRulesList"]
    lv.Opt("-Redraw")
    lv.Delete()
    
    for rule in CFG["ScreenRules"] {
        lv.Add("", rule["name"], rule["phrase"], rule["path"])
    }
    lv.Opt("+Redraw")
}

AddScreenRule() {
    ShowRuleEditor() 
}

EditScreenRule() {
    global MainGui
    row := MainGui["ScreenRulesList"].GetNext()
    if row == 0 {
        ShowNotify("Выберите правило", "warning")
        return
    }
    ShowRuleEditor(row) 
}

DeleteScreenRule() {
    global MainGui, CFG, g_BtnSaveSettings, THEME
    row := MainGui["ScreenRulesList"].GetNext()
    if row == 0 {
        ShowNotify("Выберите правило", "warning")
        return
    }
    
    CFG["ScreenRules"].RemoveAt(row)
    RefreshScreenRulesList()
    
    ; Активируем кнопку сохранения
    MarkUnsaved()
    try {
        if g_BtnSaveSettings {
            g_BtnSaveSettings.isClickable := true
            g_BtnSaveSettings.ctrl.Text := "Сохранить изменения"
            try g_BtnSaveSettings.SetEnabledStyle(true, "primary")
            g_BtnSaveSettings.ctrl.Redraw()
        }
    }
    
    ShowNotify("Правило удалено", "success")
}

; === ОКНО РЕДАКТОРА ПРАВИЛА (ФУНКЦИЯ СОХРАНЕНИЯ) ===
SaveRuleFromGui(gui, editIndex) {
    global CFG, g_BtnSaveSettings, THEME
    
    name := gui["RuleName"].Value
    phrase := gui["RulePhrase"].Value
    path := gui["RulePath"].Value
    
    if (name = "" || phrase = "" || path = "") {
        ShowNotify("Заполните все поля!", "warning")
        return
    }
    
    newRule := Map("name", name, "phrase", phrase, "path", path)
    
    if (editIndex > 0) {
        CFG["ScreenRules"][editIndex] := newRule
    } else {
        CFG["ScreenRules"].Push(newRule)
    }
    
    gui.Destroy()
    RefreshScreenRulesList()
    
    ; Активируем кнопку сохранения
    MarkUnsaved()
    try {
        if g_BtnSaveSettings {
            g_BtnSaveSettings.isClickable := true
            g_BtnSaveSettings.ctrl.Text := "Сохранить изменения"
            try g_BtnSaveSettings.SetEnabledStyle(true, "primary")
            g_BtnSaveSettings.ctrl.Redraw()
        }
    }
    
    ShowNotify("Правило сохранено!", "success")
}

; === ОКНО РЕДАКТОРА ПРАВИЛА ===
ShowRuleEditor(editIndex := 0) {
    global CFG, THEME, RuleEditorGui, MainGui
    
    ; Подготовка данных
    data := Map("name", "", "phrase", "", "path", "")
    titleText := "Новое правило"
    
    if (editIndex > 0) {
        data := CFG["ScreenRules"][editIndex]
        titleText := "Редактирование"
    }
    
    ; Удаляем старое окно если есть
    try {
        if RuleEditorGui {
            CleanupHoverButtons(RuleEditorGui)
            RuleEditorGui.Destroy()
        }
    }
    
    ; Создаем окно (Без заголовка винды, с рамкой)
    RuleEditorGui := Gui("-Caption +Border +AlwaysOnTop +Owner" MainGui.Hwnd, "RuleEditor")
    RuleEditorGui.BackColor := THEME["bg"]
    RuleEditorGui.SetFont("s10 c" THEME["text"], THEME["fontFamily"])

    w := 440
    h := 372

    ; --- ШАПКА ---
    RuleEditorGui.AddText("x0 y0 w" w " h48 Background" THEME["surface"], "")
    RuleEditorGui.AddText("x0 y47 w" w " h1 Background" THEME["border"], "")
    RuleEditorGui.SetFont("s11 bold", THEME["fontFamily"])
    RuleEditorGui.AddText("x20 y14 w300 c" THEME["textTitle"] " BackgroundTrans", titleText)

    ; Кнопка закрытия
    CloseBtn := CreateStyledButton(RuleEditorGui, w-44, 8, 32, 32, "×", (*) => RuleEditorGui.Destroy(), "icon")
    CloseBtn.SetBackdrop(THEME["surface"])
    CloseBtn.ctrl.SetFont("s12 norm", "Segoe UI")

    y := 68
    x := 25
    inputW := 390

    ; --- ПОЛЯ ВВОДА ---
    CreateFieldLabel(RuleEditorGui, x, y, 300, "Название папки")
    CreateInput(RuleEditorGui, x, y+18, inputW, THEME["inputH"], "vRuleName", data["name"], 10, THEME["bg"])

    y += 76
    CreateFieldLabel(RuleEditorGui, x, y, 300, "Фраза в чате (триггер)")
    CreateInput(RuleEditorGui, x, y+18, inputW, THEME["inputH"], "vRulePhrase", data["phrase"], 10, THEME["bg"])

    y += 76
    CreateFieldLabel(RuleEditorGui, x, y, 300, "Путь сохранения")
    CreateInput(RuleEditorGui, x, y+18, inputW-46, THEME["inputH"], "ReadOnly vRulePath", data["path"], 9, THEME["bg"])
    CreateStyledButton(RuleEditorGui, x+inputW-40, y+18, 40, THEME["inputH"], "…", (*) => BrowseRuleFolder(RuleEditorGui), "default").SetBackdrop(THEME["bg"])

    ; --- ПОДВАЛ ---
    y += 84
    RuleEditorGui.AddText("x20 y" (y-16) " w" (w-40) " h1 Background" THEME["border"], "")

    CreateStyledButton(RuleEditorGui, 20, y, 190, 40, "Отмена", (*) => RuleEditorGui.Destroy(), "default").SetBackdrop(THEME["bg"])
    CreateStyledButton(RuleEditorGui, 230, y, 190, 40, "Сохранить", (*) => SaveRuleFromGui(RuleEditorGui, editIndex), "primary").SetBackdrop(THEME["bg"])
    
    ; Центрирование
    RuleEditorGui.Show("w" w " h" h)
    try RoundCorners(RuleEditorGui, w, h, THEME["radiusWin"])
    WinGetPos(,, &ww, &wh, RuleEditorGui.Hwnd)
    RuleEditorGui.Move((A_ScreenWidth - ww) // 2, (A_ScreenHeight - wh) // 2)
}

; === ИСПРАВЛЕННАЯ ФУНКЦИЯ ВЫБОРА ПАПКИ ===
BrowseRuleFolder(gui) {
    ; 1. Временно убираем AlwaysOnTop, чтобы диалог был виден
    gui.Opt("-AlwaysOnTop")
    
    ; 2. Показываем диалог
    selected := DirSelect("*" A_MyDocuments, 3, "Выберите папку для сохранения скринов")
    
    ; 3. Возвращаем AlwaysOnTop обратно (и фокус на окно)
    gui.Opt("+AlwaysOnTop")
    gui.Show() 
    
    if selected != ""
        gui["RulePath"].Value := selected
}


; ══════════════════════════════════════════════════════════════════════════
; СОВРЕМЕННОЕ МЕНЮ ФИЛЬТРОВ (КОМПАКТНОЕ)
; ══════════════════════════════════════════════════════════════════════════
