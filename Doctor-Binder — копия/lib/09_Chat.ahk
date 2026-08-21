; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: chat                          ║
; ║  Слежение за чатом, СМС и упоминания            ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
IsChatActive() {
    global ChatIsOpen
    ; Если окно не активно — считаем чат закрытым
    ; (чтобы оверлей работал на рабочем столе, но бинды — нет)
    if !WinActive("ahk_exe gta_sa.exe")
        return false
    return ChatIsOpen
}

QuickIdInput() {
    global CFG, STATE
    
    if !WinActive("ahk_exe gta_sa.exe") {
        QuickIdInputGUI()
        return
    }
    
    Send("{" CFG["chatKey"] "}")
    Sleep(CFG["afterChatDelay"])
    SendText("/id ")
    
    ih := InputHook("V", "{Enter}{Esc}")
    ih.KeyOpt("{Enter}", "S")
    ih.Start()
    ih.Wait()
    
    if (ih.EndKey = "Enter") {
        newId := Trim(ih.Input)
        
        if (newId != "") && RegExMatch(newId, "^\d+$") {
            STATE["patientId"] := newId
            ShowNotify("ID установлен: " newId, "success")
            UpdateOverlayData()
            RefreshMainGui()
        }
        
        Send("{Esc}")
    }
}

QuickIdInputGUI() {
    global STATE
    currentId := STATE["patientId"]
    ib := InputBox("Введите ID пациента:", "Быстрый ввод", "w200 h100", currentId)
    if ib.Result = "OK" {
        STATE["patientId"] := ib.Value
        UpdateOverlayData()
        RefreshMainGui()
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; ГЛАВНОЕ ОКНО
; ═══════════════════════════════════════════════════════════════════════════════
CloseChatTimer() {
    global ChatIsOpen := false
}

; ═══════════════════════════════════════════════════════════════════════════════
; РЕГИСТРАЦИЯ ГЛОБАЛЬНЫХ СОБЫТИЙ
; ═══════════════════════════════════════════════════════════════════════════════
InitChatWatcher() {
    global ChatLogPath, LastLogPos
    
    try {
        if FileExist(ChatLogPath) {
            f := FileOpen(ChatLogPath, "r", "CP1251")
            LastLogPos := f.Length
            f.Close()
        }
        SetTimer(CheckChatLog, 1000)
    }
}

CheckChatLog() {
    global ChatLogPath, LastLogPos, CFG, STATE
    
    if !FileExist(ChatLogPath)
        return

    try {
        f := FileOpen(ChatLogPath, "r", "CP1251")
        currentSize := f.Length
        
        if (currentSize < LastLogPos)
            LastLogPos := 0
            
        if (currentSize > LastLogPos) {
            f.Pos := LastLogPos
            newLines := f.Read()
            LastLogPos := currentSize
            f.Close()
            
            ; ВОТ ЗДЕСЬ БЫЛО ПРОПУЩЕНО:
            CheckForNickName(newLines)
            CheckForSms(newLines)
            CheckForKeywords(newLines)
            CheckForReportEvents(newLines)            
        } else {
            f.Close()
        }
    }
}

CheckForReportEvents(text) {
    global CFG
    
    ; Если правил нет или функция выключена - выходим
    if !CFG["autoScreen"] || CFG["ScreenRules"].Length = 0
        return

    Loop Parse, text, "`n", "`r" {
        line := A_LoopField
        if (line = "") 
            continue
            
        ; Пробегаем по ВСЕМ правилам пользователя
        for rule in CFG["ScreenRules"] {
            ; Если фраза из правила найдена в строке чата
            if InStr(line, rule["phrase"]) {
                ; Делаем скриншот и указываем путь из правила
                TakeSmartScreenshotPath(rule["path"])
                
                ; Прерываем проверку для этой строки (чтобы не делать 2 скрина, если фразы похожи)
                break 
            }
        }
    }
}

CheckForKeywords(text) {
    global CFG
    
    ; Если функция выключена в настройках или мы в игре — выходим
    if (!CFG.Has("notifyKeywords") || !CFG["notifyKeywords"] || WinActive("ahk_exe gta_sa.exe"))
        return

    keywords := ["врач", "лечи", "таблетк", "доктор", "болит", "помоги", "ранен"]
    
    Loop Parse, text, "`n", "`r" {
        line := A_LoopField
        for word in keywords {
            if InStr(line, word) {
                ; Проигрываем системный звук (или свой файл)
                SoundBeep(900, 150) 
                SoundBeep(750, 300)
                
                ShowNotify("Вас зовут: " word, "warning", 4000)
                return ; Чтобы не пищало много раз подряд
            }
        }
    }
}


CheckForNickName(text) {
    global STATE, CFG
    
    ; 1. Проверяем настройки и статус окна
    ; Уведомляем ТОЛЬКО если игра свернута (не активна)
    if (!CFG["notifyMention"] || WinActive("ahk_exe gta_sa.exe"))
        return
    
    if (STATE["myName"] == "")
        return
        
    nick1 := STATE["myName"]
    nick2 := StrReplace(STATE["myName"], " ", "_")
    
    ; Разбираем текст построчно, чтобы найти конкретную строку с упоминанием
    Loop Parse, text, "`n", "`r" {
        line := A_LoopField
        if (line = "")
            continue

        if (InStr(line, nick1) || InStr(line, nick2)) {
            ; Защита: не реагируем на свои же сообщения (формат: Nick_Name[ID]: текст)
            if InStr(line, nick2 "[") 
                 continue 
            
            ; Показываем красивое уведомление
            ShowMentionNotification(line)
            
            ; Прерываем, чтобы не пищать 10 раз, если флудят
            return 
        }
    }
}

; === ОТМЕНА ПРИ КЛИКЕ МЫШКОЙ ===

ShowMentionNotification(chatLine) {
    global MentionNotifyGui, THEME
    
    ; === 1. ЗВУК ===
    try {
        SoundPlay "*48" 
    } catch {
        SoundPlay "*64"
    }

    ; === 2. ОЧИСТКА СТАРОГО ОКНА ===
    try {
        if MentionNotifyGui
            MentionNotifyGui.Destroy()
    }
    
    ; === 3. ОЧИСТКА ТЕКСТА (НОВОЕ) ===
    cleanLine := chatLine
    
    ; 1. Удаляем время в начале строки [00:00:00]
    cleanLine := RegExReplace(cleanLine, "^\[\d{2}:\d{2}:\d{2}\]\s*", "")
    
    ; 2. Удаляем ВСЕ цветовые коды вида {FFFFFF}, {AFEEEE} и т.д.
    cleanLine := RegExReplace(cleanLine, "\{[A-Fa-f0-9]{6}\}", "")
    
    ; 3. Удаляем скобки OOC чата (( и ))
    cleanLine := StrReplace(cleanLine, "((", "")
    cleanLine := StrReplace(cleanLine, "))", "")
    
    ; 4. Убираем лишние пробелы (если после удаления осталось два пробела подряд)
    cleanLine := RegExReplace(cleanLine, "\s{2,}", " ")
    cleanLine := Trim(cleanLine)
    
    ; 5. Если текст все еще слишком длинный — обрезаем
    if StrLen(cleanLine) > 65
        cleanLine := SubStr(cleanLine, 1, 62) "..."

    ; === 4. СОЗДАНИЕ ОКНА ===
    MentionNotifyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "NewMention")
    MentionNotifyGui.BackColor := THEME["bg"]
    
    w := 340
    h := 100
    
    MentionNotifyGui.AddText("x0 y0 w6 h" h " Background" THEME["warning"], "")
    
    MentionNotifyGui.SetFont("s9 bold", "Segoe UI")
    MentionNotifyGui.AddText("x25 y12 w200 c" THEME["warning"] " BackgroundTrans", "Вас упомянули")
    
    ; Сам текст сообщения
    MentionNotifyGui.SetFont("s10", "Segoe UI")
    MentionNotifyGui.AddText("x25 y40 w300 h50 c" THEME["text"], cleanLine)
    
    x := A_ScreenWidth - w - 20
    y := A_ScreenHeight - h - 60
    
    MentionNotifyGui.Show("x" x " y" y " w" w " h" h " NA")
    
    SetTimer(CloseMentionNotify, -6000)
}

CloseMentionNotify() {
    global MentionNotifyGui
    try {
        if MentionNotifyGui
            MentionNotifyGui.Destroy()
        MentionNotifyGui := ""
    }
}


CheckForSms(text) {
    global STATE, CFG
    
    Loop Parse, text, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line = "")
            continue
            
        ; Паттерн СМС
        if RegExMatch(line, "i)СМС.*?от.*?\[(\d+)\]", &match) {
            smsNum := match[1]
            STATE["lastSmsNum"] := smsNum
            
            ; Проверяем: 1. Игра свернута? 2. Включена ли настройка?
            if !WinActive("ahk_exe gta_sa.exe") && CFG["notifySms"] {
                ShowSmsNotification(smsNum)
            }
            continue
        }
        
        ; Резервный паттерн
        if RegExMatch(line, "Отправитель:.*\[т\.(\d+)\]", &match) {
            STATE["lastSmsNum"] := match[1]
            if !WinActive("ahk_exe gta_sa.exe") && CFG["notifySms"] {
                ShowSmsNotification(match[1])
            }
            continue
        }
    }
}

ShowSmsNotification(smsNumber) {
    global SmsNotifyGui, LastSmsNotification, THEME
    
    if (LastSmsNotification = smsNumber)
        return
        
    LastSmsNotification := smsNumber
    
    try {
        if FileExist("C:\Windows\Media\Windows Notify Messaging.wav")
            SoundPlay "C:\Windows\Media\Windows Notify Messaging.wav"
        else
            SoundPlay "*64"
    }
    
    try {
        if SmsNotifyGui
            SmsNotifyGui.Destroy()
    }
    
    SmsNotifyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "NewSMS")
    SmsNotifyGui.BackColor := THEME["bg"]
    
    w := 320
    h := 95
    
    SmsNotifyGui.AddText("x0 y0 w6 h" h " Background" THEME["accent"], "")
    
    SmsNotifyGui.SetFont("s9 bold", "Segoe UI")
    SmsNotifyGui.AddText("x25 y12 w200 c" THEME["textDim"] " BackgroundTrans", "Входящее СМС")
    
    SmsNotifyGui.SetFont("s18 bold", "Consolas")
    SmsNotifyGui.AddText("x25 y35 w280 c" THEME["text"], smsNumber)
    
    SmsNotifyGui.SetFont("s9", "Segoe UI")
    ; ✅ ИЗМЕНЕННЫЙ ТЕКСТ
    SmsNotifyGui.AddText("x25 y70 w280 c" THEME["success"] " BackgroundTrans", "В игре: нажми [F4] для ответа")
    
    x := A_ScreenWidth - w - 20
    y := A_ScreenHeight - h - 60
    
    SmsNotifyGui.Show("x" x " y" y " w" w " h" h " NA")
    SetTimer(CloseSmsNotify, -6000)
}

CloseSmsNotify() {
    global SmsNotifyGui, LastSmsNotification
    try {
        if SmsNotifyGui
            SmsNotifyGui.Destroy()
        SmsNotifyGui := ""
        ; Сбрасываем LastSmsNotification через время, чтобы снова показать, если напишут через минуту
        LastSmsNotification := "" 
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; ЗАПУСК И ИНИЦИАЛИЗАЦИЯ
; ═══════════════════════════════════════════════════════════════════════════════

