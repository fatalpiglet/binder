; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: menus                         ║
; ║  Радиальное меню и выбор бинда                  ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
ShowRadialMenu() {
    global CFG, WheelGui, THEME, SLOTS
    
    if !CFG["enableWheel"] || IsChatActive()
        return
        
    ; 1. Получаем ID слотов из настроек
    sectorBinds := [CFG["wheelTop"], CFG["wheelRight"], CFG["wheelBottom"], CFG["wheelLeft"]]
    
    ; 2. Создаем GUI
    try {
        if WheelGui 
            WheelGui.Destroy()
    }
    
    WheelGui := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20 +Owner", "RadialMenu")
    WheelGui.BackColor := "000000"
    WinSetTransColor("000000", WheelGui)
    
    centerX := A_ScreenWidth // 2
    centerY := A_ScreenHeight // 2
    radius := 130
    
    ; --- ОТРИСОВКА СЕКТОРОВ ---
    
    ; 1: TOP
    WheelGui.SetFont("s26 bold", "Segoe UI Symbol") ; Шрифт для иконок
    icTop := WheelGui.AddText("x" (centerX - 30) " y" (centerY - radius - 30) " w60 h60 Center cWhite BackgroundTrans vIcon1", GetWheelIcon(sectorBinds[1]))
    
    WheelGui.SetFont("s10 norm", "Segoe UI") ; Шрифт для текста
    lbTop := WheelGui.AddText("x" (centerX - 100) " y" (centerY - radius + 25) " w200 h20 Center cWhite BackgroundTrans vLabel1", GetBindName(sectorBinds[1]))
    
    ; 2: RIGHT
    WheelGui.SetFont("s26 bold", "Segoe UI Symbol")
    icRight := WheelGui.AddText("x" (centerX + radius - 30) " y" (centerY - 30) " w60 h60 Center cWhite BackgroundTrans vIcon2", GetWheelIcon(sectorBinds[2]))
    
    WheelGui.SetFont("s10 norm", "Segoe UI")
    lbRight := WheelGui.AddText("x" (centerX + radius - 70) " y" (centerY + 30) " w140 h20 Center cWhite BackgroundTrans vLabel2", GetBindName(sectorBinds[2]))
    
    ; 3: BOTTOM
    WheelGui.SetFont("s26 bold", "Segoe UI Symbol")
    icBot := WheelGui.AddText("x" (centerX - 30) " y" (centerY + radius - 30) " w60 h60 Center cWhite BackgroundTrans vIcon3", GetWheelIcon(sectorBinds[3]))
    
    WheelGui.SetFont("s10 norm", "Segoe UI")
    lbBot := WheelGui.AddText("x" (centerX - 100) " y" (centerY + radius + 30) " w200 h20 Center cWhite BackgroundTrans vLabel3", GetBindName(sectorBinds[3]))
    
    ; 4: LEFT
    WheelGui.SetFont("s26 bold", "Segoe UI Symbol")
    icLeft := WheelGui.AddText("x" (centerX - radius - 30) " y" (centerY - 30) " w60 h60 Center cWhite BackgroundTrans vIcon4", GetWheelIcon(sectorBinds[4]))
    
    WheelGui.SetFont("s10 norm", "Segoe UI")
    lbLeft := WheelGui.AddText("x" (centerX - radius - 70) " y" (centerY + 30) " w140 h20 Center cWhite BackgroundTrans vLabel4", GetBindName(sectorBinds[4]))
    
    ; Крестик в центре
    WheelGui.SetFont("s16")
    WheelGui.AddText("x" (centerX - 10) " y" (centerY - 10) " w20 h20 Center cGray BackgroundTrans", "✚")
    
    WheelGui.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight " NA")
    
    ; 3. Запуск слежения
    TrackRadialMouse(sectorBinds)
}

; Функция получения иконки (ВЫНЕСЕНА НАРУЖУ)
GetWheelIcon(slotIdx) {
    global SLOTS
    
    if (slotIdx == 0) {
        return "○"
    }
    
    cat := SLOTS[slotIdx]["category"]
    
    if (cat = "Лечение") {
        return "◉"
    }
    if (cat = "Вакцины" || cat = "Уколы") {
        return "▲"
    }
    if (cat = "Операции") {
        return "✂"
    }
    if (cat = "Медосмотр") {
        return "▤"
    }
    
    return "▶"
}

GetBindName(idx) {
    global SLOTS
    if (idx > 0 && idx <= Constants.MAX_SLOTS) {
        name := SLOTS[idx]["name"]
        return StrLen(name) > 15 ? SubStr(name, 1, 13) "..." : name
    }
    return ""
}

TrackRadialMouse(binds) {
    global WheelGui, THEME, CFG
    
    CoordMode "Mouse", "Screen"
    centerX := A_ScreenWidth // 2
    centerY := A_ScreenHeight // 2
    
    ; Сброс физической мыши
    DllCall("SetCursorPos", "Int", centerX, "Int", centerY)
    
    ; === ВИРТУАЛЬНЫЕ КООРДИНАТЫ ===
    vX := 0
    vY := 0
    maxRadius := 100 ; Максимальное отдаление точки от центра
    deadZone := 40   ; Зона в центре, где выбор сбрасывается
    
    activeSector := 0
    
    ; Очистка клавиши
    rawKey := CFG["hotkeyWheel"]
    cleanKey := StrReplace(rawKey, "*", "")
    cleanKey := StrReplace(cleanKey, "^", "")
    cleanKey := StrReplace(cleanKey, "!", "")
    cleanKey := StrReplace(cleanKey, "+", "")
    cleanKey := StrReplace(cleanKey, "#", "")
    cleanKey := Trim(cleanKey)
    
    colNormal := "cWhite"
    colActive := "c" THEME["accent"] 
    
    Loop {
        if !GetKeyState(cleanKey, "P") {
            break 
        }
        
        MouseGetPos(&mx, &my)
        
        ; Считаем, куда дернулась мышь (Delta)
        dx := mx - centerX
        dy := my - centerY
        
        ; Если есть движение - сбрасываем физическую мышь в центр
        if (dx != 0 || dy != 0) {
            DllCall("SetCursorPos", "Int", centerX, "Int", centerY)
        }
        
        ; Применяем движение к ВИРТУАЛЬНОЙ точке
        vX += dx
        vY += dy
        
        ; Считаем расстояние виртуальной точки от центра
        vDist := Sqrt(vX*vX + vY*vY)
        
        ; Ограничиваем круг (Clamp), чтобы точка не улетала бесконечно далеко
        ; Это создает ощущение "джойстика"
        if (vDist > maxRadius) {
            ratio := maxRadius / vDist
            vX *= ratio
            vY *= ratio
            vDist := maxRadius
        }
        
        ; Двигаем визуальную точку на экране
        try WheelGui["PointerDot"].Move(centerX + vX - 5, centerY + vY - 5)
        
        newSector := 0
        
        ; === ЛОГИКА ВЫБОРА ===
        ; Если мы вышли за пределы мертвой зоны - выбираем сектор
        if (vDist > deadZone) {
            angle := DllCall("msvcrt\atan2", "Double", vY, "Double", vX, "Cdecl Double") * 57.2957795
            
            if (angle > -135 && angle <= -45)
                newSector := 1
            else if (angle > -45 && angle <= 45)
                newSector := 2
            else if (angle > 45 && angle <= 135)
                newSector := 3
            else 
                newSector := 4
        }
        ; Если vDist < deadZone, newSector остается 0 (Сброс)
        
        if (newSector != activeSector) {
            if (activeSector > 0) {
                try {
                    WheelGui["Icon" activeSector].Opt(colNormal)
                    WheelGui["Label" activeSector].Opt(colNormal)
                    WheelGui["Label" activeSector].SetFont("s10 norm")
                }
            }
            if (newSector > 0) {
                try {
                    WheelGui["Icon" newSector].Opt(colActive)
                    try WheelGui["Label" newSector].Opt(colActive)
                    WheelGui["Label" newSector].SetFont("s11 bold")
                }
            }
            activeSector := newSector
        }
        Sleep 5
    }
    
    WheelGui.Destroy()
    WheelGui := ""
    
    if (activeSector > 0 && binds[activeSector] > 0) {
        RunSlotByNum(binds[activeSector])
    }
}


; ══════════════════════════════════════════════════════════════════════════
; МЕНЮ ВЫБОРА БИНДА (ФИНАЛ)
; ══════════════════════════════════════════════════════════════════════════

ShowBindSelector(cfgKey, btnName) {
    global MainGui, BindSelectorGui, THEME, SLOTS
    
    try { 
        if BindSelectorGui 
            BindSelectorGui.Destroy() 
    }
    
    MouseGetPos(&mx, &my)
    
    BindSelectorGui := Gui("-Caption +AlwaysOnTop +ToolWindow +Owner" MainGui.Hwnd, "SelectBind")
    BindSelectorGui.BackColor := THEME["bg"]
    
    BindSelectorGui.SetFont("s9 bold", "Segoe UI")
    BindSelectorGui.AddText("x10 y5 w200 c" THEME["accent"] " BackgroundTrans", "Выберите бинд:")
    
    ; Таблица
    lvSel := BindSelectorGui.AddListView("x5 y25 w240 h250 -Hdr -Multi Background" THEME["bgLight"] " c" THEME["text"], ["Name", "ID"])
    SetDarkControl(lvSel)
    
    ; Колонка 215px (чтобы влез скролл)
    lvSel.ModifyCol(1, 215) 
    
    lvSel.Add("", "— Очистить слот —", 0)
    
    Loop Constants.MAX_SLOTS {
        slot := SLOTS[A_Index]
        if (slot["name"] != "") {
            lvSel.Add("", "[" A_Index "] " slot["name"], A_Index)
        }
    }
    
    lvSel.OnEvent("DoubleClick", (*) => ApplySelectorSelection(lvSel, cfgKey, btnName))
    
    CreateStyledButton(BindSelectorGui, 5, 280, 240, 30, "Отмена", (*) => BindSelectorGui.Destroy(), "danger")
    
    BindSelectorGui.Show("x" mx " y" my " w250 h315 NA")
    
    ; Убираем гориз. скролл
    try DllCall("ShowScrollBar", "Ptr", lvSel.Hwnd, "Int", 0, "Int", 0)
}

ApplySelectorSelection(lv, cfgKey, btnName) {
    global CFG, MainGui, BindSelectorGui, SLOTS
    
    row := lv.GetNext()
    if (row == 0) 
        return
        
    slotID := Integer(lv.GetText(row, 2))
    
    displayName := "— Пусто —"
    if (slotID > 0) {
        sName := SLOTS[slotID]["name"]
        displayName := "[" slotID "] " (StrLen(sName) > 12 ? SubStr(sName, 1, 10) "..." : sName)
    }
    
    CFG[cfgKey] := slotID
    try MainGui[btnName].Text := displayName
    
    BindSelectorGui.Destroy()
    BindSelectorGui := ""
    
    CheckSettingsDirty()
}

ApplyBindToWheel(cfgKey, btnName, slotID, displayName) {
    global CFG, MainGui, BindSelectorGui
    
    CFG[cfgKey] := slotID
    MainGui[btnName].Text := displayName
    
    if BindSelectorGui {
        BindSelectorGui.Destroy()
        BindSelectorGui := ""
    }
    SetTimer(CheckSelectorFocus, 0)
    
    CheckSettingsDirty()
}

CheckSelectorFocus() {
    global BindSelectorGui
    if !BindSelectorGui {
        SetTimer(CheckSelectorFocus, 0)
        return
    }
    if !WinActive("ahk_id " BindSelectorGui.Hwnd) {
        MouseGetPos(,, &winId)
        if (winId != BindSelectorGui.Hwnd) {
            BindSelectorGui.Destroy()
            BindSelectorGui := ""
        }
    }
}


; СТАТИСТИКА


