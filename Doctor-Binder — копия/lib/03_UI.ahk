; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: ui                            ║
; ║  UI-компоненты: кнопки, ховер, тёмная тема      ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
class StyledBtn {
    __New(parent, x, y, w, h, text, callback, style := "default", tip := "") {
        global HoverButtons, ButtonByHwnd, THEME
        this.parent := parent
        this.x := x, this.y := y, this.w := w, this.h := h
        this.callback := callback
        this.style := style
        this.tip := tip
        this.text := text
        this.colors := this.GetColors(style)
        this.currentBg := this.colors.bg
        this.currentText := this.colors.text
        this.isHovered := false
        this.isClickable := true
        this.lastState := true

        ; Один Static HWND: никаких frame/ctrl-слоёв. Region применяется к тому
        ; же контролу, который рисует фон и текст.
        this.ctrl := parent.AddText("x" x " y" y " w" w " h" h
            " Center 0x200 Background" this.colors.bg " c" this.colors.text " -Wrap", text)
        this.ctrl.SetFont("s9 norm", THEME["fontFamily"])
        styleBits := DllCall("user32\GetWindowLong", "Ptr", this.ctrl.Hwnd, "Int", -16, "UInt")
        DllCall("user32\SetWindowLong", "Ptr", this.ctrl.Hwnd, "Int", -16
            , "UInt", (styleBits & ~0xF) | 0xD, "UInt") ; SS_OWNERDRAW

        this.ApplyShape()
        this.ctrl.OnEvent("Click", (*) => this.OnClick())
        HoverButtons.Push(this)
        ButtonByHwnd[this.ctrl.Hwnd] := this
    }

    BuildTextOptions(textColor) {
        return "x" this.x " y" this.y " w" this.w " h" this.h " Center 0x200 BackgroundTrans c" textColor " -Wrap"
    }

    ApplyShape() {
        this.radius := Max(10, Min(12, this.h // 2))
        ; Region отвечает только за прозрачные углы. Видимый контур рисуется
        ; внутри него с отступом, поэтому ступенчатый край маски не подсвечен.
        try RoundCorners(this.ctrl, this.w, this.h, this.radius + 2)
    }

    OnClick() {
        if !this.isClickable
            return
        this.SetPressed(true)
        SetTimer(() => this.SetPressed(false), -80)
        try this.callback.Call()
    }

    SetPressed(state) {
        if !this.isClickable
            return
        bg := state ? this.colors.pressed : (this.isHovered ? this.colors.hover : this.colors.bg)
        this.ApplyVisual(bg, this.colors.text)
    }

    GetColors(style) {
        style := StrLower(style)
        switch style {
            case "icon", "close": return {bg: "121a26", hover: "26303d", pressed: "0f1823", border: "121a26", borderHover: "df788b", text: "9aabc0"}
            case "success", "green", "ok", "save": return {bg: "18382f", hover: "205043", pressed: "142f28", border: "28664f", borderHover: "4ab187", text: "baf3da"}
            case "danger", "red", "delete", "error": return {bg: "39222c", hover: "512d3a", pressed: "301c25", border: "703747", borderHover: "bd6079", text: "ffc3cf"}
            case "info", "blue", "primary": return {bg: "173247", hover: "1c4865", pressed: "122a3c", border: "286381", borderHover: "52b7e9", text: "bde8ff"}
            case "warning", "yellow": return {bg: "3a3020", hover: "514326", pressed: "30281a", border: "73592e", borderHover: "c89a4a", text: "f8d99b"}
            default: return {bg: "1b2737", hover: "26384f", pressed: "152131", border: "354a62", borderHover: "54708f", text: "e7eef7"}
        }
    }

    ApplyVisual(bg, textColor) {
        this.currentBg := bg
        this.currentText := textColor
        try DllCall("user32\InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", true)
    }

    SetVisual(bg, textColor := "ffffff", hoverBg := "") {
        global THEME
        if hoverBg = ""
            hoverBg := bg
        this.colors := {
            bg: bg,
            hover: hoverBg,
            pressed: bg,
            border: THEME["borderLight"],
            borderHover: hoverBg,
            text: textColor
        }
        this.ApplyVisual(bg, textColor)
    }

    SetEnabledStyle(isActive, style := "success") {
        global THEME
        this.isClickable := isActive
        this.isHovered := false
        if isActive {
            this.colors := this.GetColors(style)
            this.ApplyVisual(this.colors.bg, this.colors.text)
        } else {
            this.colors := {bg: THEME["bgLight"], hover: THEME["bgLight"], pressed: THEME["bgLight"], border: THEME["border"], borderHover: THEME["border"], text: THEME["textMuted"]}
            this.ApplyVisual(this.colors.bg, this.colors.text)
        }
    }

    SetVisible(visible) {
        if !visible && this.isHovered
            this.SetHover(false)
        try this.ctrl.Visible := visible
    }

    SetHover(state) {
        if this.isHovered = state
            return
        this.isHovered := state
        if state {
            if this.tip != ""
                ToolTip(this.tip, , , 1)
        } else {
            ToolTip(, , , 1)
        }
        target := state ? this.colors.hover : this.colors.bg
        this.ApplyVisual(target, this.colors.text)
        try DllCall("user32\SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", state ? 32649 : 32512, "Ptr"))
    }
}

; Верхняя навигация использует тот же owner-draw renderer, но имеет отдельную
; семантику состояний и не выглядит как action-кнопка.
class NavigationTab extends StyledBtn {
    __New(parent, x, y, w, h, text, id, callback, active := false) {
        this.id := id
        this.active := active
        super.__New(parent, x, y, w, h, text, callback, "default")
        this.isNav := true
        this.radius := 10
        RoundCorners(this.ctrl, this.w, this.h, this.radius + 2)
        this.SetActive(active)
    }

    SetActive(active) {
        global THEME
        this.active := active
        if active {
            this.colors := {
                bg: THEME["bgSelected"], hover: THEME["bgSelected"], pressed: THEME["bgSelected"],
                border: THEME["borderLight"], borderHover: THEME["accent"], text: THEME["accent"]
            }
            this.ctrl.SetFont("s9 bold", THEME["fontFamily"])
        } else {
            this.colors := {
                bg: THEME["bgLight"], hover: THEME["bgHover"], pressed: THEME["bgHighlight"],
                border: THEME["bgLight"], borderHover: THEME["borderLight"], text: THEME["textDim"]
            }
            this.ctrl.SetFont("s9 norm", THEME["fontFamily"])
        }
        this.isHovered := false
        this.ApplyVisual(this.colors.bg, this.colors.text)
    }
}

; HWND -> объект кнопки. Это единственный реестр состояний.
global ButtonByHwnd := Map()

OnMessage(0x002B, DrawStyledButton) ; WM_DRAWITEM

DrawStyledButton(wParam, lParam, msg, hwnd) {
    global ButtonByHwnd
    hwndOffset := 20 + (A_PtrSize - 4)
    hdcOffset := hwndOffset + A_PtrSize
    rectOffset := hdcOffset + A_PtrSize
    try ctrlHwnd := NumGet(lParam, hwndOffset, "Ptr")
    catch
        return 0
    if !ctrlHwnd || !ButtonByHwnd.Has(ctrlHwnd)
        return 0

    btn := ButtonByHwnd[ctrlHwnd]
    hdc := NumGet(lParam, hdcOffset, "Ptr")
    left := NumGet(lParam, rectOffset, "Int")
    top := NumGet(lParam, rectOffset + 4, "Int")
    right := NumGet(lParam, rectOffset + 8, "Int")
    bottom := NumGet(lParam, rectOffset + 12, "Int")
    border := btn.isHovered && btn.isClickable ? btn.colors.borderHover : btn.colors.border

    brush := DllCall("gdi32\CreateSolidBrush", "UInt", HexToColorRef(btn.currentBg), "Ptr")
    pen := DllCall("gdi32\CreatePen", "Int", 0, "Int", 1, "UInt", HexToColorRef(border), "Ptr")
    oldBrush := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", brush, "Ptr")
    oldPen := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")
    diameter := btn.radius * 2
    DllCall("gdi32\RoundRect", "Ptr", hdc, "Int", left + 2, "Int", top + 2, "Int", right - 2, "Int", bottom - 2
        , "Int", diameter, "Int", diameter)
    DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldBrush)
    DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldPen)
    DllCall("gdi32\DeleteObject", "Ptr", brush)
    DllCall("gdi32\DeleteObject", "Ptr", pen)

    DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1)
    DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", HexToColorRef(btn.currentText))
    font := SendMessage(0x31, 0, 0, ctrlHwnd)
    oldFont := font ? DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", font, "Ptr") : 0
    rect := Buffer(16)
    NumPut("Int", left + 6, rect, 0), NumPut("Int", top, rect, 4)
    NumPut("Int", right - 6, rect, 8), NumPut("Int", bottom, rect, 12)
    DllCall("user32\DrawText", "Ptr", hdc, "Str", btn.ctrl.Text, "Int", -1, "Ptr", rect
        , "UInt", 0x25) ; DT_CENTER | DT_VCENTER | DT_SINGLELINE
    if oldFont
        DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont)
    return true
}

HexToColorRef(hex) {
    value := Integer("0x" StrReplace(String(hex), "#"))
    return ((value & 0xFF) << 16) | (value & 0xFF00) | ((value >> 16) & 0xFF)
}

SetButtonVisualByControl(ctrl, textColor, bg := "") {
    global ButtonByHwnd
    if IsObject(ctrl) && ButtonByHwnd.Has(ctrl.Hwnd) {
        btn := ButtonByHwnd[ctrl.Hwnd]
        btn.colors.text := textColor
        if bg != "" {
            btn.colors.bg := bg
            btn.currentBg := bg
        }
        btn.ApplyVisual(btn.currentBg, textColor)
        return
    }
    try ctrl.Opt("c" textColor (bg != "" ? " Background" bg : ""))
    try ctrl.Redraw()
}

; Принудительно поднимает кнопку над карточкой/разделителем. Это важно для
; AHK GUI: фон карточки создаётся раньше, а некоторые Win32 region-контролы
; могут оказаться выше по Z-order после SetWindowRgn.
BringButtonToFront(ctrl) {
    try {
        ; HWND_TOP (0) + SHOWWINDOW: кнопка гарантированно остаётся видимой
        ; и выше фоновых STATIC-панелей. Координаты и размер не меняются.
        DllCall("user32\SetWindowPos", "Ptr", ctrl.Hwnd, "Ptr", 0
            , "Int", 0, "Int", 0, "Int", 0, "Int", 0
            , "UInt", 0x0053) ; SHOWWINDOW | NOACTIVATE | NOMOVE | NOSIZE
        return true
    } catch {
        return false
    }
}

SendPanelToBack(ctrl) {
    try {
        if !IsObject(ctrl) || !ctrl.Hwnd
            return false
        ; HWND_BOTTOM (1): фон панели уходит под остальные дочерние контролы.
        ; Это не меняет координаты/размер и не активирует окно.
        DllCall("user32\SetWindowPos", "Ptr", ctrl.Hwnd, "Ptr", 1
            , "Int", 0, "Int", 0, "Int", 0, "Int", 0
            , "UInt", 0x0017) ; NOACTIVATE | NOMOVE | NOSIZE
        return true
    } catch {
        return false
    }
}

CreateStyledButton(parent, x, y, w, h, text, callback, style := "default", tip := "") {
    return StyledBtn(parent, x, y, w, h, text, callback, style, tip)
}

; Скругляет Win32/AHK-контрол без внешних декоративных пикселей.
; SetWindowRgn передаёт владение созданным HRGN окну при успешном вызове,
; поэтому удаляем region только если SetWindowRgn завершился неудачно.
RoundCorners(ctrl, w, h, radius := 8) {
    if !IsObject(ctrl)
        return false
    try hwnd := ctrl.Hwnd
    catch
        return false
    if !hwnd || !WinExist("ahk_id " hwnd)
        return false

    w := Max(1, Integer(w))
    h := Max(1, Integer(h))
    radius := Max(1, Min(Integer(radius), Integer(Min(w, h) / 2)))

    ; GDI CreateRoundRectRgn использует правую/нижнюю границу как exclusive.
    hRgn := DllCall("gdi32\CreateRoundRectRgn"
        , "Int", 0, "Int", 0, "Int", w + 1, "Int", h + 1
        , "Int", radius * 2, "Int", radius * 2, "Ptr")
    if !hRgn
        return false

    if DllCall("user32\SetWindowRgn", "Ptr", hwnd, "Ptr", hRgn, "Int", true) {
        ; Окно теперь владеет HRGN. Не вызываем DeleteObject.
        return true
    }

    DllCall("gdi32\DeleteObject", "Ptr", hRgn)
    return false
}

; ───────────────────────────────────────────────────────────────────────────────
; СОВРЕМЕННЫЕ СКРУГЛЁННЫЕ КНОПКИ (rounded + заливка)
; Залитая цветная подложка со скруглёнными углами (RoundCorners) + текст на
; прозрачном фоне. При наведении кнопка подсвечивается более ярким цветом и
; курсор становится «пальцем» (IDC_HAND), при нажатии — вдавливается.
; ───────────────────────────────────────────────────────────────────────────────
CreateOutlineBtn(parent, x, y, w, h, text, callback, style := "default", tip := "") {
    ; Единый компонент для обычных кнопок и редактора.
    return CreateStyledButton(parent, x, y, w, h, text, callback, style, tip)
}

OutlineSetHover(obj, state) {
    try obj.SetHover(state)
}

OutlinePress(obj) {
    try obj.OnClick()
}

OutlineSetVisible(obj, visible) {
    if !IsObject(obj)
        return
    try obj.SetVisible(visible)
    catch {
        try obj.ctrl.Visible := visible
    }
}

; ───────────────────────────────────────────────────────────────────
; Плавное появление окна (fade-in)
; ───────────────────────────────────────────────────────────────────
FadeInGui(gui, steps := 14, interval := 14) {
    try {
        WinSetTransparent(0, gui)
        step := 255 // steps
        Loop steps {
            try WinSetTransparent(A_Index * step, gui)
            Sleep interval
        }
        ; Не сбрасываем прозрачность в "Off": сброс вызывает полную перерисовку
        ; окна и выглядит как «дёргание» при запуске. 255 = полностью непрозрачно.
        WinSetTransparent(255, gui)
    } catch {
        ; Если анимация не удалась — просто оставляем окно как есть
        try WinSetTransparent("Off", gui)
    }
}

WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    ; Оставляем обработчик совместимым, но фактический hover обслуживается
    ; таймером PollButtonHover. Это надёжнее для дочерних STATIC-контролов AHK.
    PollButtonHover()
}

PollButtonHover() {
    global HoverButtons
    static lastWinId := 0
    static lastButton := 0

    point := Buffer(8, 0)
    if !DllCall("user32\GetCursorPos", "Ptr", point)
        return
    mouseX := NumGet(point, 0, "Int")
    mouseY := NumGet(point, 4, "Int")
    hwndAtPoint := DllCall("user32\WindowFromPoint", "Int64", (mouseY << 32) | (mouseX & 0xFFFFFFFF), "Ptr")
    winId := hwndAtPoint ? DllCall("user32\GetAncestor", "Ptr", hwndAtPoint, "UInt", 2, "Ptr") : 0

    hitButton := 0
    if winId {
        for btn in HoverButtons {
            if IsButtonUnderMouse(btn, mouseX, mouseY, winId) {
                hitButton := btn
                break
            }
        }
    }

    if hitButton = lastButton && winId = lastWinId
        return

    if IsObject(lastButton)
        lastButton.SetHover(false)
    if IsObject(hitButton)
        hitButton.SetHover(true)

    lastButton := hitButton
    lastWinId := winId
}

IsButtonUnderMouse(btn, mouseX, mouseY, winId) {
    if !IsObject(btn) || !btn.HasOwnProp("ctrl") || !IsObject(btn.ctrl)
        return false
    try {
        if btn.parent.Hwnd != winId
            return false
        if !btn.ctrl.Visible || !DllCall("user32\IsWindowVisible", "Ptr", btn.ctrl.Hwnd)
            return false
        btn.ctrl.GetPos(&x, &y, &w, &h)
        point := Buffer(8, 0)
        NumPut("Int", x, point, 0)
        NumPut("Int", y, point, 4)
        DllCall("user32\ClientToScreen", "Ptr", btn.parent.Hwnd, "Ptr", point)
        screenX := NumGet(point, 0, "Int")
        screenY := NumGet(point, 4, "Int")
        return mouseX >= screenX && mouseX < screenX + w
            && mouseY >= screenY && mouseY < screenY + h
    } catch {
        return false
    }
}


CleanupHoverButtons(gui) {
    global HoverButtons, ButtonByHwnd
    if !IsObject(HoverButtons) {
        HoverButtons := []
        return
    }
    if HoverButtons.Length = 0
        return
    newButtons := []
    Loop HoverButtons.Length {
        try {
            btn := HoverButtons[A_Index]
            if !IsObject(btn) || !btn.HasOwnProp("parent") || !btn.HasOwnProp("ctrl")
                continue
            if btn.parent = gui
            {
                try ButtonByHwnd.Delete(btn.ctrl.Hwnd)
                continue
            }
            if !IsObject(btn.ctrl)
                continue
            try {
                if btn.ctrl.Hwnd && WinExist("ahk_id " btn.ctrl.Hwnd)
                    newButtons.Push(btn)
            }
        }
    }
    HoverButtons := newButtons
}

; WM_MOUSEMOVE у STATIC-контролов не всегда проходит через OnMessage стабильно.
; Периодический опрос делает hover надёжным на всех кнопках и окнах.
SetTimer(PollButtonHover, 40)

SetDarkControl(ctrl) {
    if !IsObject(ctrl)
        return
        
    try {
        if VerCompare(A_OSVersion, "10.0.17763") >= 0 {
            ; Попытка 1: Стандартная темная тема проводника
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
            
            ; Попытка 2: Если первая не сработала, иногда просто "Explorer" подхватывает темный режим приложения
            ; (Можно раскомментировать, если первая не работает)
            ; DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "Explorer", "Ptr", 0)
        }
    }
}


SetListViewRowHeight(lv, height := 28) {
    ; Создаём невидимый ImageList нужной высоты
    ; Это единственный способ увеличить высоту строк в ListView
    hIL := DllCall("comctl32\ImageList_Create", "Int", 1, "Int", height, "UInt", 0x00000020, "Int", 1, "Int", 1, "Ptr")
    SendMessage(0x1003, 0, hIL, lv.Hwnd)  ; LVM_SETIMAGELIST, LVSIL_SMALL
}


; ══════════════════════════════════════════════════════════════════════════
; ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ РЕДАКТОРА (ВСТАВИТЬ В КОНЕЦ, УДАЛИВ СТАРЫЕ)
; ══════════════════════════════════════════════════════════════════════════

CreateClearBtn(parent, x, y, size, callback) {
    return CreateStyledButton(parent, x, y, size, size, "x", callback, "danger")
}

; ══════════════════════════════════════════════════════════════════════════
; СИСТЕМА РАДИАЛЬНОГО МЕНЮ (WHEEL MENU) - ИСПРАВЛЕННАЯ
; ══════════════════════════════════════════════════════════════════════════
