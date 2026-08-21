; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: profiles                      ║
; ║  Загрузка и сохранение профилей                 ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
LoadProfileDialog(*) {
    selectedFile := FileSelect(1, A_ScriptDir, "Выберите профиль", "Профили (*.ini; *.aci)")
    
    if selectedFile = ""
        return
    
    ext := ""
    SplitPath(selectedFile, , , &ext)
    
    SaveUndoState("Загрузка профиля")
    
    switch StrLower(ext) {
        case "ini":
            LoadINIProfile(selectedFile)
        case "aci":
            LoadACIProfile(selectedFile)
        default:
            ShowNotify("Неизвестный формат", "error")
            return
    }

    RefreshMainGui()
    
    RefreshBindList()
    UpdateOverlayData()
    RegisterAllHotkeys()
    ShowNotify("Профиль загружен!", "success")
}

LoadINIProfile(filePath) {
    global SLOTS, STATE
    
    try {
        ; Определяем кодировку файла
        rawContent := FileRead(filePath, "RAW")
        
        ; Проверяем BOM
        if (NumGet(rawContent, 0, "UChar") = 0xEF && 
            NumGet(rawContent, 1, "UChar") = 0xBB && 
            NumGet(rawContent, 2, "UChar") = 0xBF) {
            content := FileRead(filePath, "UTF-8")
        } else {
            ; Пробуем UTF-8 без BOM
            try {
                content := FileRead(filePath, "UTF-8")
                ; Проверка на кракозябры
                if InStr(content, "�") || InStr(content, "Ð") {
                    throw Error("Bad UTF-8")
                }
            } catch {
                ; Используем CP1251 (Windows Cyrillic)
                content := FileRead(filePath, "CP1251")
            }
        }
        
        ; Читаем профиль напрямую построчно
        lines := StrSplit(content, "`n")
        currentSection := ""
        currentSlot := 0
        
        for lineNum, line in lines {
            line := Trim(line, " `t`r`n")
            
            ; Пропускаем пустые строки
            if line = ""
                continue
            
            ; Определяем секцию
            if RegExMatch(line, "^\[([^\]]+)\]$", &match) {
                currentSection := match[1]
                
                ; Если это слот, определяем номер
                if RegExMatch(currentSection, "^Slot(\d+)$", &slotMatch) {
                    currentSlot := Integer(slotMatch[1])
                    
                    ; Инициализируем слот
                    if currentSlot >= 1 && currentSlot <= Constants.MAX_SLOTS { 
                        SLOTS[currentSlot] := Map(
                            "name", "",
                            "hotkey", "",
                            "enabled", false,
                            "category", "",
                            "statType", "",
                            "lines", []
                        )
                    }
                }
                continue
            }
            
            ; Парсим пары ключ=значение
            if InStr(line, "=") {
                parts := StrSplit(line, "=", , 2)
                key := Trim(parts[1])
                value := parts.Length >= 2 ? Trim(parts[2]) : ""
                
                ; Обработка Settings
                if currentSection = "Settings" {
                    switch key {
                        case "chatKey": CFG["chatKey"] := value
                        case "baseDelay": CFG["baseDelay"] := Integer(value)
                        case "myName": STATE["myName"] := value
                    }
                }
                
                ; Обработка Profile
                if currentSection = "Profile" {
                    switch key {
                        case "hospital": STATE["hospital"] := value
                        case "rank": STATE["rank"] := value
                        case "specialty": STATE["specialty"] := value
                    }
                }
                
                ; Обработка слотов
                if currentSlot >= 1 && currentSlot <= Constants.MAX_SLOTS { 
                    switch key {
                        case "name": SLOTS[currentSlot]["name"] := value
                        case "hotkey": SLOTS[currentSlot]["hotkey"] := value
                        case "enabled": SLOTS[currentSlot]["enabled"] := (value = "1")
                        case "category": SLOTS[currentSlot]["category"] := value
                        case "statType": SLOTS[currentSlot]["statType"] := value
                        case "lineCount": ; Игнорируем, считаем автоматически
                        default:
                            ; Обработка строк line1_text, line1_delay и т.д.
                            if RegExMatch(key, "^line(\d+)_text$", &lineMatch) {
                                lineIdx := Integer(lineMatch[1])
                                
                                ; Убеждаемся что массив достаточно большой
                                while SLOTS[currentSlot]["lines"].Length < lineIdx {
                                    SLOTS[currentSlot]["lines"].Push(Map("text", "", "delay", 0))
                                }
                                
                                SLOTS[currentSlot]["lines"][lineIdx]["text"] := value
                            }
                            else if RegExMatch(key, "^line(\d+)_delay$", &lineMatch) {
                                lineIdx := Integer(lineMatch[1])
                                
                                while SLOTS[currentSlot]["lines"].Length < lineIdx {
                                    SLOTS[currentSlot]["lines"].Push(Map("text", "", "delay", 0))
                                }
                                
                                SLOTS[currentSlot]["lines"][lineIdx]["delay"] := Integer(value)
                            }
                    }
                }
            }
        }
        
        ShowNotify("✅ Профиль загружен!", "success")
        MarkUnsaved()
        
    } catch as err {
        LogError(err, "LoadINIProfile")
        ShowNotify("Ошибка загрузки: " err.Message, "error")
    }
}

LoadACIProfile(filePath) {
    global SLOTS
    
    try {
        content := FileRead(filePath, "UTF-8")
        if InStr(content, "�")
            content := FileRead(filePath, "CP1251")
        
        if InStr(content, "[Bind") || InStr(content, "[Slot") {
            LoadINIProfile(filePath)
        } else if InStr(content, "{") && InStr(content, "}") && InStr(content, "name") {
            ParseACIAsJSON(content)
        } else {
            ParseACIAsText(content)
        }
    } catch as err {
        LogError(err, "LoadACIProfile")
        ShowNotify("Ошибка чтения .aci: " err.Message, "error")
    }
}

ParseACIAsJSON(content) {
    global SLOTS
    slotIdx := 1
    pos := 1
    
    while pos := RegExMatch(content, '"name"\s*:\s*"([^"]*)"', &match, pos) {
        if slotIdx > Constants.MAX_SLOTS
         break
        
        name := match[1]
        textPos := InStr(content, '"text"', , pos)
        if textPos && textPos < pos + 500 {
            if RegExMatch(content, '"text"\s*:\s*"([^"]*)"', &textMatch, textPos) {
                text := textMatch[1]
                SLOTS[slotIdx]["name"] := name
                SLOTS[slotIdx]["enabled"] := true
                SLOTS[slotIdx]["category"] := "Импорт ACI"
                SLOTS[slotIdx]["lines"] := [Map("text", text, "delay", 2300)]
                slotIdx++
            }
        }
        pos := match.Pos + match.Len
    }
}

ParseACIAsText(content) {
    global SLOTS
    lines := StrSplit(content, "`n")
    slotIdx := 1
    
    for line in lines {
        if slotIdx > Constants.MAX_SLOTS
         break
        
        line := Trim(line, "`r`n `t")
        if line = "" || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#"
            continue
        
        SLOTS[slotIdx]["name"] := "Импорт " slotIdx
        SLOTS[slotIdx]["enabled"] := true
        SLOTS[slotIdx]["category"] := "Импорт ACI"
        SLOTS[slotIdx]["lines"] := [Map("text", line, "delay", 2300)]
        slotIdx++
    }
}

SaveProfileDialog(*) {
    selectedFile := FileSelect("S16", A_ScriptDir "\profile.ini", "Сохранить профиль", "Профили (*.ini)")
    if selectedFile = ""
        return
    
    if !InStr(selectedFile, ".ini")
        selectedFile .= ".ini"
    
    SaveProfileToFile(selectedFile)
    ShowNotify("Профиль сохранён!", "success")
}

SaveProfileToFile(filePath) {
    global SLOTS, CFG, STATE
    
    try {
        if FileExist(filePath)
            FileDelete(filePath)
        
        IniWrite(CFG["chatKey"], filePath, "Settings", "chatKey")
        IniWrite(CFG["baseDelay"], filePath, "Settings", "baseDelay")
        IniWrite(STATE["myName"], filePath, "Settings", "myName")
        
        Loop Constants.MAX_SLOTS { 
            section := "Slot" A_Index
        
            ; 1. УДАЛЯЕМ СТАРУЮ СЕКЦИЮ В ФАЙЛЕ
            try IniDelete(filePath, section)
        
            slot := SLOTS[A_Index]
            if slot["name"] = "" && slot["lines"].Length = 0
            continue ; Если слот пустой, просто удалили секцию и идем дальше   
            
            section := "Slot" A_Index
            IniWrite(slot["name"], filePath, section, "name")
            IniWrite(slot["hotkey"], filePath, section, "hotkey")
            IniWrite(slot["enabled"] ? 1 : 0, filePath, section, "enabled")
            IniWrite(slot.Has("category") ? slot["category"] : "", filePath, section, "category")
            IniWrite(slot.Has("statType") ? slot["statType"] : "", filePath, section, "statType")
            IniWrite(slot["lines"].Length, filePath, section, "lineCount")
            
            for idx, line in slot["lines"] {
                IniWrite(line["text"], filePath, section, "line" idx "_text")
                IniWrite(line["delay"], filePath, section, "line" idx "_delay")
            }
        }
    } catch as err {
        LogError(err, "SaveProfileToFile")
        ShowNotify("Ошибка сохранения: " err.Message, "error")
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; ОВЕРЛЕЙ (ПОЛНЫЙ И МИНИ)
; ═══════════════════════════════════════════════════════════════════════════════
