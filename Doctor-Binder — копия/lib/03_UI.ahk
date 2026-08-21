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
        ; --- премиальный рендер ---
        this.align := "center"      ; center | left
        this.glyph := ""            ; правый монохромный глиф (→ ↻ ↑ ↓ ?)
        this.leftGlyph := ""        ; левая иконка пункта навигации
        this.backdrop := ""         ; цвет поверхности ПОД кнопкой (чистые углы)
        this.glow := ""             ; мягкое свечение (только primary/active)

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
        global THEME
        ; Единый радиус кнопок: 8–10px (без «таблеток» и случайных значений).
        this.radius := Max(8, Min(THEME["radius"], this.h // 3))
        ; Region отвечает только за прозрачные углы. Видимый контур рисуется
        ; внутри него с отступом, поэтому ступенчатый край маски не подсвечен.
        try RoundCorners(this.ctrl, this.w, this.h, this.radius + 2)
    }

    ; Левое выравнивание + правый глиф — для action-панелей (быстрые действия).
    SetLayout(align := "center", glyph := "") {
        this.align := align
        this.glyph := glyph
        this.Refresh()
    }

    ; Левая монохромная иконка (пункты бокового меню).
    SetIcon(glyph) {
        this.leftGlyph := glyph
        this.Refresh()
    }

    ; Цвет поверхности под кнопкой: убирает мусор в скруглённых углах.
    SetBackdrop(color) {
        this.backdrop := color
        this.Refresh()
    }

    ; Очень мягкий cyan-акцент при наведении (для action-строк).
    ; Без свечения: меняется только оттенок поверхности и цвет рамки.
    SetHoverAccent(bgColor := "", borderColor := "") {
        global THEME
        if !IsObject(this.colors)
            return
        this.colors.hover := bgColor = "" ? BlendHex(this.colors.bg, THEME["accent"], 0.10) : bgColor
        this.colors.borderHover := borderColor = "" ? THEME["accentDark"] : borderColor
        this.Refresh()
    }

    ; Мягкое свечение (enhancement, не основа дизайна).
    SetGlow(color) {
        this.glow := color
        this.Refresh()
    }

    Refresh() {
        try DllCall("user32\InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", true)
    }

    OnClick() {
        if !this.isClickable
            return
        this.SetPressed(true)
        SetTimer(() => this.SetPressed(false), -110)
        try this.callback.Call()
    }

    SetPressed(state) {
        if !this.isClickable
            return
        bg := state ? this.colors.pressed : (this.isHovered ? this.colors.hover : this.colors.bg)
        this.ApplyVisual(bg, this.colors.text)
    }

    ; ── Палитра кнопок ────────────────────────────────────────────────────────
    ; Базовый вид = тёмная поверхность + тонкая рамка + светлый текст.
    ; Cyan появляется только у primary и у активных состояний.
    GetColors(style) {
        style := StrLower(style)
        switch style {
            case "icon", "close":
                return {bg: "0d1016", hover: "1c1419", pressed: "141018", border: "1a212c", borderHover: "5c2f3c", text: "8d97a5", glow: ""}
            case "ghost", "flat":
                return {bg: "0d1016", hover: "151d28", pressed: "0d1016", border: "0d1016", borderHover: "202833", text: "9aa4b2", glow: ""}
            case "primary", "cyan", "accent":
                return {bg: "0e2a37", hover: "123646", pressed: "0c2431", border: "1e5f7d", borderHover: "38bdf8", text: "cfeeff", glow: "38bdf8"}
            case "success", "green", "ok", "save":
                return {bg: "0f2a20", hover: "143528", pressed: "0d2119", border: "1f5c44", borderHover: "35c98a", text: "9fe6c4", glow: ""}
            case "danger", "red", "delete", "error":
                ; Тёмная кнопка; красный акцент появляется только при наведении.
                return {bg: "111722", hover: "1b1620", pressed: "0e141d", border: "202833", borderHover: "6e3543"
                    , text: "dfe4ec", textHover: "eda9b6", glow: ""}
            case "info", "blue":
                ; Нейтральная «прохладная» кнопка: без заливки cyan.
                return {bg: "111722", hover: "16202c", pressed: "0e141d", border: "22303f", borderHover: "3c5670", text: "dde3ea", glow: ""}
            case "warning", "yellow":
                return {bg: "241d12", hover: "2e2517", pressed: "1d170e", border: "50401f", borderHover: "d9a75c", text: "e6c78e", glow: ""}
            default:
                return {bg: "111722", hover: "151d28", pressed: "0e141d", border: "202833", borderHover: "344252", text: "e6eaf0", glow: ""}
        }
    }

    ApplyVisual(bg, textColor) {
        this.currentBg := bg
        this.currentText := textColor
        try DllCall("user32\InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", true)
    }

    SetVisual(bg, textColor := "ffffff", hoverBg := "", border := "", glow := "") {
        global THEME
        if hoverBg = ""
            hoverBg := bg
        if border = ""
            border := THEME["border"]
        this.colors := {
            bg: bg,
            hover: hoverBg,
            pressed: bg,
            border: border,
            borderHover: THEME["borderLight"],
            text: textColor,
            glow: glow
        }
        this.glow := glow
        this.ApplyVisual(bg, textColor)
    }

    SetEnabledStyle(isActive, style := "primary") {
        global THEME
        this.isClickable := isActive
        this.isHovered := false
        if isActive {
            this.colors := this.GetColors(style)
            this.glow := this.colors.HasOwnProp("glow") ? this.colors.glow : ""
            this.ApplyVisual(this.colors.bg, this.colors.text)
        } else {
            ; Disabled: та же геометрия, без акцента и свечения, но текст
            ; остаётся читаемым (textDim вместо muted).
            this.glow := ""
            this.colors := {bg: THEME["bgElevated"], hover: THEME["bgElevated"], pressed: THEME["bgElevated"]
                , border: THEME["border"], borderHover: THEME["border"], text: THEME["textDim"], glow: ""}
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
        textColor := this.colors.text
        if (state && IsObject(this.colors) && this.colors.HasOwnProp("textHover") && this.colors.textHover != "")
            textColor := this.colors.textHover
        this.ApplyVisual(target, textColor)
        try DllCall("user32\SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", state ? 32649 : 32512, "Ptr"))
    }
}

; Верхняя навигация использует тот же owner-draw renderer, но имеет отдельную
; семантику состояний и не выглядит как action-кнопка.
class NavigationTab extends StyledBtn {
    __New(parent, x, y, w, h, text, id, callback, active := false) {
        global THEME
        this.id := id
        this.active := active
        super.__New(parent, x, y, w, h, text, callback, "default")
        this.isNav := true
        this.radius := THEME["radiusSm"] + 2
        this.backdrop := THEME["surface"]
        this.align := "left"        ; пункт бокового меню, а не кнопка-таблетка
        RoundCorners(this.ctrl, this.w, this.h, this.radius + 2)
        this.SetActive(active)
    }

    SetActive(active) {
        global THEME
        this.active := active
        if active {
            ; Активная вкладка: чуть светлее поверхность, cyan-рамка, мягкое свечение.
            this.colors := {
                bg: THEME["bgSelected"], hover: THEME["bgSelected"], pressed: THEME["bgSelected"],
                border: THEME["accentDark"], borderHover: THEME["accent"], text: THEME["accent"],
                glow: THEME["accent"]
            }
            this.glow := THEME["accent"]
            this.ctrl.SetFont("s10 bold", THEME["fontFamily"])
        } else {
            ; Неактивная: приглушённый текст, без рамки и без свечения.
            this.colors := {
                bg: THEME["surface"], hover: THEME["bgElevated"], pressed: THEME["surface"],
                border: THEME["surface"], borderHover: THEME["border"], text: THEME["textDim"],
                glow: ""
            }
            this.glow := ""
            this.ctrl.SetFont("s10 norm", THEME["fontFamily"])
        }
        this.isHovered := false
        this.ApplyVisual(this.colors.bg, this.colors.text)
    }
}

; HWND -> объект кнопки. Это единственный реестр состояний.
global ButtonByHwnd := Map()

OnMessage(0x002B, DrawStyledButton) ; WM_DRAWITEM

DrawStyledButton(wParam, lParam, msg, hwnd) {
    global ButtonByHwnd, THEME
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

    backdrop := (btn.HasOwnProp("backdrop") && btn.backdrop != "") ? btn.backdrop : THEME["card"]
    border := btn.isHovered && btn.isClickable ? btn.colors.borderHover : btn.colors.border
    diameter := btn.radius * 2

    ; 1. Подложка: гарантирует чистые скруглённые углы без «мусора» от region.
    full := Buffer(16)
    NumPut("Int", left, full, 0), NumPut("Int", top, full, 4)
    NumPut("Int", right, full, 8), NumPut("Int", bottom, full, 12)
    backBrush := DllCall("gdi32\CreateSolidBrush", "UInt", HexToColorRef(backdrop), "Ptr")
    DllCall("user32\FillRect", "Ptr", hdc, "Ptr", full, "Ptr", backBrush)
    DllCall("gdi32\DeleteObject", "Ptr", backBrush)

    ; 2. Очень мягкое свечение — два кольца, только у primary/active элементов.
    glowColor := ""
    if btn.HasOwnProp("glow") && btn.glow != ""
        glowColor := btn.glow
    else if IsObject(btn.colors) && btn.colors.HasOwnProp("glow")
        glowColor := btn.colors.glow
    if (glowColor != "" && btn.isClickable) {
        hollow := DllCall("gdi32\GetStockObject", "Int", 5, "Ptr") ; NULL_BRUSH
        prevBrush := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hollow, "Ptr")
        DrawGlowRing(hdc, left, top, right, bottom, diameter + 4, BlendHex(backdrop, glowColor, 0.09))
        DrawGlowRing(hdc, left + 1, top + 1, right - 1, bottom - 1, diameter + 2, BlendHex(backdrop, glowColor, 0.19))
        DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", prevBrush)
    }

    ; 3. Тело кнопки.
    brush := DllCall("gdi32\CreateSolidBrush", "UInt", HexToColorRef(btn.currentBg), "Ptr")
    pen := DllCall("gdi32\CreatePen", "Int", 0, "Int", 1, "UInt", HexToColorRef(border), "Ptr")
    oldBrush := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", brush, "Ptr")
    oldPen := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")
    DllCall("gdi32\RoundRect", "Ptr", hdc, "Int", left + 2, "Int", top + 2, "Int", right - 2, "Int", bottom - 2
        , "Int", diameter, "Int", diameter)
    DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldBrush)
    DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldPen)
    DllCall("gdi32\DeleteObject", "Ptr", brush)
    DllCall("gdi32\DeleteObject", "Ptr", pen)

    ; 4. Текст (+ опциональный правый глиф).
    DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1)
    font := SendMessage(0x31, 0, 0, ctrlHwnd)
    oldFont := font ? DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", font, "Ptr") : 0

    alignLeft := btn.HasOwnProp("align") && btn.align = "left"
    glyph := btn.HasOwnProp("glyph") ? btn.glyph : ""
    leftGlyph := btn.HasOwnProp("leftGlyph") ? btn.leftGlyph : ""
    padL := alignLeft ? 16 : 8
    if leftGlyph != ""
        padL += 26
    padR := (glyph != "") ? 34 : 8

    ; Левая иконка — отдельным символьным шрифтом, чтобы кириллица в подписи
    ; рисовалась основным UI-шрифтом, а глиф гарантированно был из Segoe UI Symbol.
    if leftGlyph != "" {
        iconColor := btn.isClickable ? btn.currentText : BlendHex(btn.currentBg, btn.currentText, 0.6)
        DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", HexToColorRef(iconColor))
        symFont := GetSymbolFont(14)
        prevF := symFont ? DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", symFont, "Ptr") : 0
        iRect := Buffer(16)
        NumPut("Int", left + 16, iRect, 0), NumPut("Int", top, iRect, 4)
        NumPut("Int", left + 40, iRect, 8), NumPut("Int", bottom, iRect, 12)
        DllCall("user32\DrawText", "Ptr", hdc, "Str", leftGlyph, "Int", -1, "Ptr", iRect, "UInt", 0x25)
        if prevF
            DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", prevF)
    }

    DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", HexToColorRef(btn.currentText))
    rect := Buffer(16)
    NumPut("Int", left + padL, rect, 0), NumPut("Int", top, rect, 4)
    NumPut("Int", right - padR, rect, 8), NumPut("Int", bottom, rect, 12)
    ; DT_VCENTER | DT_SINGLELINE (+ DT_CENTER для центрированных кнопок)
    flags := alignLeft ? 0x24 : 0x25
    DllCall("user32\DrawText", "Ptr", hdc, "Str", btn.ctrl.Text, "Int", -1, "Ptr", rect, "UInt", flags)

    if glyph != "" {
        glyphColor := (btn.isHovered && btn.isClickable) ? btn.currentText : BlendHex(btn.currentBg, btn.currentText, 0.55)
        DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", HexToColorRef(glyphColor))
        symFont := GetSymbolFont(13)
        prevF := symFont ? DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", symFont, "Ptr") : 0
        gRect := Buffer(16)
        NumPut("Int", left + 8, gRect, 0), NumPut("Int", top, gRect, 4)
        NumPut("Int", right - 16, gRect, 8), NumPut("Int", bottom, gRect, 12)
        ; DT_RIGHT | DT_VCENTER | DT_SINGLELINE
        DllCall("user32\DrawText", "Ptr", hdc, "Str", glyph, "Int", -1, "Ptr", gRect, "UInt", 0x26)
        if prevF
            DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", prevF)
    }

    if oldFont
        DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont)
    return true
}

; Кэш символьного шрифта для глифов кнопок (иконки и стрелки).
GetSymbolFont(size := 14) {
    static cache := Map()
    if cache.Has(size)
        return cache[size]
    hFont := DllCall("gdi32\CreateFont", "Int", -size, "Int", 0, "Int", 0, "Int", 0, "Int", 400
        , "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 4, "UInt", 0
        , "Str", "Segoe UI Symbol", "Ptr")
    cache[size] := hFont
    return hFont
}

; Контурное кольцо свечения (без заливки — брошен NULL_BRUSH до вызова).
DrawGlowRing(hdc, left, top, right, bottom, diameter, color) {
    pen := DllCall("gdi32\CreatePen", "Int", 0, "Int", 1, "UInt", HexToColorRef(color), "Ptr")
    oldPen := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")
    DllCall("gdi32\RoundRect", "Ptr", hdc, "Int", left, "Int", top, "Int", right, "Int", bottom
        , "Int", diameter, "Int", diameter)
    DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldPen)
    DllCall("gdi32\DeleteObject", "Ptr", pen)
}

; Смешивание двух HEX-цветов (t = 0..1). Используется для мягких свечений,
; halo у статус-точек и приглушённых глифов.
BlendHex(colorA, colorB, t) {
    a := Integer("0x" StrReplace(String(colorA), "#"))
    b := Integer("0x" StrReplace(String(colorB), "#"))
    t := Max(0, Min(1, t))
    r := Round(((a >> 16) & 0xFF) * (1 - t) + ((b >> 16) & 0xFF) * t)
    g := Round(((a >> 8) & 0xFF) * (1 - t) + ((b >> 8) & 0xFF) * t)
    bl := Round((a & 0xFF) * (1 - t) + (b & 0xFF) * t)
    return Format("{:06x}", (r << 16) | (g << 8) | bl)
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

; ═══════════════════════════════════════════════════════════════════════════════
;  ПРЕМИАЛЬНЫЕ БАЗОВЫЕ КОНТРОЛЫ
;  Стандартные Windows Edit/Static заменяются составными компонентами:
;  подложка свечения → рамка → поверхность поля → сам Edit без клиентского
;  «белого» края (WS_EX_CLIENTEDGE снят). Логика контролов не меняется:
;  наружу отдаётся тот же Gui.Edit с тем же v-именем и событиями.
; ═══════════════════════════════════════════════════════════════════════════════
class InputField {
    static Registry := []

    __New(parent, x, y, w, h, options := "", value := "", fontSize := 10, backdrop := "", accentText := "") {
        global THEME
        this.parent := parent
        this.x := x, this.y := y, this.w := w, this.h := h
        this.focused := false
        this.hovered := false
        this.visible := true
        this.backdrop := backdrop = "" ? THEME["card"] : backdrop

        r := THEME["radiusSm"]

        ; Кольцо мягкого cyan-свечения. В покое оно окрашено в цвет подложки
        ; (то есть невидимо) — так надёжнее, чем прятать контрол: переключение
        ; вкладок в AHK может заново показать скрытые контролы страницы.
        this.glowOff := this.backdrop
        this.glowOn := BlendHex(this.backdrop, THEME["accent"], 0.13)
        this.glowRing := parent.AddText("x" (x - 2) " y" (y - 2) " w" (w + 4) " h" (h + 4)
            " Background" this.glowOff, "")
        RoundCorners(this.glowRing, w + 4, h + 4, r + 2)

        ; Рамка (1px) — цвет меняется на hover/focus.
        this.frame := parent.AddText("x" x " y" y " w" w " h" h " Background" THEME["fieldBorder"], "")
        RoundCorners(this.frame, w, h, r)

        ; Поверхность поля.
        this.inner := parent.AddText("x" (x + 1) " y" (y + 1) " w" (w - 2) " h" (h - 2) " Background" THEME["fieldBg"], "")
        RoundCorners(this.inner, w - 2, h - 2, r)

        isMulti := InStr(options, "Multi") ? true : false
        if isMulti {
            edH := h - 12
            edY := y + 6
        } else {
            edH := Max(18, Min(h - 8, Round(fontSize * 2.0)))
            ; Обычное поле — текст по центру; высокое однострочное поле
            ; (например, строка бинда в редакторе) — текст сверху.
            edY := (h > 56) ? (y + 10) : (y + (h - edH) // 2)
        }
        textColor := accentText = "" ? THEME["text"] : accentText

        parent.SetFont("s" fontSize " norm", THEME["fontFamily"])
        this.ctrl := parent.AddEdit("x" (x + 11) " y" edY " w" (w - 22) " h" edH
            " -E0x200 -Border Background" THEME["fieldBg"] " c" textColor " " options, value)
        this.ctrl.SetFont("s" fontSize " norm", THEME["fontFamily"])

        try this.ctrl.OnEvent("Focus", (*) => this.SetFocused(true))
        try this.ctrl.OnEvent("LoseFocus", (*) => this.SetFocused(false))

        InputField.Registry.Push(this)
    }

    ; Собственный шрифт поля (моно/крупный ID пациента и т.п.)
    SetFont(opts, family := "") {
        global THEME
        try this.ctrl.SetFont(opts, family = "" ? THEME["fontFamily"] : family)
    }

    SetFocused(state) {
        if this.focused = state
            return
        this.focused := state
        this.Apply()
    }

    SetHover(state) {
        if this.hovered = state
            return
        this.hovered := state
        this.Apply()
    }

    Apply() {
        global THEME
        color := this.focused ? THEME["accent"] : (this.hovered ? THEME["borderLight"] : THEME["fieldBorder"])
        try {
            this.frame.Opt("Background" color)
            this.frame.Redraw()
        }
        try {
            this.glowRing.Opt("Background" (this.focused ? this.glowOn : this.glowOff))
            this.glowRing.Redraw()
        }
    }

    SetVisible(state) {
        this.visible := state
        try this.frame.Visible := state
        try this.inner.Visible := state
        try this.ctrl.Visible := state
        try this.glowRing.Visible := state
    }

    SetEnabled(state) {
        try this.ctrl.Enabled := state
    }

    Value {
        get => this.ctrl.Value
        set => this.ctrl.Value := value
    }
}

; Удобный фасад: возвращает объект InputField (ctrl — сам Edit).
CreateInput(parent, x, y, w, h, options := "", value := "", fontSize := 10, backdrop := "", accentText := "") {
    return InputField(parent, x, y, w, h, options, value, fontSize, backdrop, accentText)
}

; Маленький muted-label над полем (LABEL в верхнем регистре).
CreateFieldLabel(parent, x, y, w, text, color := "") {
    global THEME
    lbl := parent.AddText("x" x " y" y " w" w " h17 BackgroundTrans c" (color = "" ? THEME["textDim"] : color), text)
    lbl.SetFont("s" THEME["fontMeta"] " bold", THEME["fontFamily"])
    return lbl
}

; Спокойная карточка: очень тонкая рамка + тёмная поверхность + мягкая
; «глубина» (светлая линия по верхней кромке). Рамка не должна быть главным
; элементом — иерархию задают уровни поверхностей и типографика.
; Возвращает {frame, surface} — обе панели уходят под содержимое.
CreateCard(parent, x, y, w, h, radius := 0, surfaceColor := "") {
    global THEME
    if !radius
        radius := THEME["radiusLg"]
    if surfaceColor = ""
        surfaceColor := THEME["card"]

    frame := parent.AddText("x" x " y" y " w" w " h" h " Background" THEME["cardBorder"], "")
    RoundCorners(frame, w, h, radius)
    surface := parent.AddText("x" (x + 1) " y" (y + 1) " w" (w - 2) " h" (h - 2) " Background" surfaceColor, "")
    RoundCorners(surface, w - 2, h - 2, radius)
    SendPanelToBack(surface)
    SendPanelToBack(frame)
    return {frame: frame, surface: surface, top: ""}
}

; ─── Строка-карточка настройки с hover ────────────────────────────────────────
; Тексты внутри создаются НЕпрозрачными в цвет поверхности, поэтому при
; наведении строка подсвечивается целиком и без «чёрных прямоугольников».
class HoverCard {
    static Registry := []

    __New(parent, x, y, w, h, radius := 0, surfaceColor := "", hoverColor := "") {
        global THEME
        this.parent := parent
        this.surfaceColor := surfaceColor = "" ? THEME["bgElevated"] : surfaceColor
        this.hoverColor := hoverColor = "" ? THEME["bgHover"] : hoverColor
        card := CreateCard(parent, x, y, w, h, radius ? radius : THEME["radiusLg"], this.surfaceColor)
        this.frame := card.frame
        this.surface := card.surface
        this.topLine := ""
        this.children := []
        this.hovered := false
        this.visible := true
        HoverCard.Registry.Push(this)
    }

    ; Регистрирует контрол внутри строки, чтобы он подсвечивался вместе с ней
    Add(ctrl) {
        this.children.Push(ctrl)
        return ctrl
    }

    SetHover(state) {
        if this.hovered = state
            return
        this.hovered := state
        color := state ? this.hoverColor : this.surfaceColor
        try {
            this.surface.Opt("Background" color)
            this.surface.Redraw()
        }
        for c in this.children {
            try {
                c.Opt("Background" color)
                c.Redraw()
            }
        }
    }

    SetVisible(state) {
        this.visible := state
        try this.frame.Visible := state
        try this.surface.Visible := state
        if IsObject(this.topLine)
            try this.topLine.Visible := state
        for c in this.children {
            try c.Visible := state
        }
    }
}

; ─── Кастомный переключатель Doctor Binder ────────────────────────────────────
; Внешне — аккуратный квадрат с зелёной галочкой и очень мягким свечением.
; Внутри — обычный скрытый Checkbox с тем же v-именем, поэтому вся существующая
; логика (чтение .Value, RefreshMainGui, CheckSettingsDirty) работает без правок.
class ToggleBox {
    static Registry := []

    __New(parent, x, y, name, checked := false, onToggle := "", backdrop := "", size := 17) {
        global THEME
        this.parent := parent
        this.name := name
        this.size := size
        this.enabled := true
        this.onToggle := onToggle
        this.backdrop := backdrop = "" ? THEME["card"] : backdrop

        ; Скрытый настоящий чекбокс — источник истины для логики приложения
        this.hidden := parent.AddCheckbox("x0 y0 w0 h0 Hidden v" name " Checked" (checked ? 1 : 0), "")

        this.glowOff := this.backdrop
        this.glowOn := BlendHex(this.backdrop, THEME["success"], 0.14)
        this.glow := parent.AddText("x" (x - 2) " y" (y - 2) " w" (size + 4) " h" (size + 4)
            " Background" this.glowOff, "")
        RoundCorners(this.glow, size + 4, size + 4, 6)

        this.frame := parent.AddText("x" x " y" y " w" size " h" size " Background" THEME["fieldBorder"], "")
        RoundCorners(this.frame, size, size, 4)

        this.box := parent.AddText("x" (x + 1) " y" (y + 1) " w" (size - 2) " h" (size - 2)
            " Center 0x200 Background" THEME["field"] " c" THEME["field"], "✓")
        this.box.SetFont("s8 bold", "Segoe UI Symbol")
        RoundCorners(this.box, size - 2, size - 2, 4)
        this.box.OnEvent("Click", (*) => this.Toggle())

        ToggleBox.Registry.Push(this)
        this.Apply()
    }

    ; Клик по подписи тоже переключает настройку
    AttachLabel(ctrl) {
        try ctrl.OnEvent("Click", (*) => this.Toggle())
        return ctrl
    }

    Value {
        get {
            try return this.hidden.Value
            return 0
        }
        set {
            try this.hidden.Value := value ? 1 : 0
            this.Apply()
        }
    }

    Toggle() {
        if !this.enabled
            return
        this.Value := this.Value ? 0 : 1
        if this.onToggle
            try this.onToggle.Call(this)
    }

    SetEnabled(state) {
        this.enabled := state
        this.Apply()
    }

    Apply() {
        global THEME
        on := false
        try on := this.hidden.Value ? true : false
        if !this.enabled {
            markColor := on ? THEME["textDisabled"] : THEME["field"]
            borderColor := THEME["border"]
        } else {
            markColor := on ? THEME["success"] : THEME["field"]
            borderColor := on ? THEME["successDark"] : THEME["fieldBorder"]
        }
        try {
            this.box.Opt("c" markColor)
            this.box.Redraw()
        }
        try {
            this.frame.Opt("Background" borderColor)
            this.frame.Redraw()
        }
        try {
            this.glow.Opt("Background" ((on && this.enabled) ? this.glowOn : this.glowOff))
            this.glow.Redraw()
        }
    }

    SetVisible(state) {
        try this.glow.Visible := state
        try this.frame.Visible := state
        try this.box.Visible := state
    }

    ; Обновить все переключатели после программного изменения значений
    static SyncAll() {
        for t in ToggleBox.Registry {
            try t.Apply()
        }
    }
}

; Тёмный select без системного Windows-списка: кнопка + popup.
class DarkSelect {
    static OpenGui := ""

    __New(parent, x, y, w, h, name, items, selectedIndex := 1, onChange := "") {
        global THEME
        this.parent := parent
        this.items := items
        this.onChange := onChange
        this.enabled := true
        this.visible := true
        this.w := w, this.h := h
        if (selectedIndex < 1 || selectedIndex > items.Length)
            selectedIndex := 1
        this.hidden := parent.AddEdit("x0 y0 w0 h0 Hidden Number v" name, selectedIndex)
        label := items[selectedIndex]
        this.btn := CreateStyledButton(parent, x, y, w, h, label, (*) => this.Open(), "default")
        this.btn.SetBackdrop(THEME["card"])
        this.ApplyIdle()
        this.btn.SetLayout("left", "▾")
        this.btn.ctrl.SetFont("s10 norm", THEME["fontFamily"])
    }

    Value {
        get {
            try return Integer(this.hidden.Value)
            return 1
        }
        set {
            idx := Integer(value)
            if (idx < 1)
                idx := 1
            if (idx > this.items.Length)
                idx := this.items.Length
            try this.hidden.Value := idx
            try this.btn.ctrl.Text := this.items[idx]
            this.ApplyIdle()
        }
    }

    Enabled {
        get => this.enabled
        set {
            this.enabled := value ? true : false
            this.btn.isClickable := this.enabled
            this.ApplyIdle()
        }
    }

    ApplyIdle() {
        global THEME
        if this.enabled
            this.btn.SetVisual("0d1117", "e5e7eb", "121820", "232a36")
        else
            this.btn.SetVisual("0d1117", THEME["textDisabled"], "0d1117", "232a36")
        this.btn.SetLayout("left", "▾")
    }

    Open() {
        global THEME, MainGui
        if !this.enabled
            return
        try {
            if DarkSelect.OpenGui
                DarkSelect.OpenGui.Destroy()
        }
        this.btn.SetVisual("0b0f14", "e5e7eb", "0b0f14", "38bdf8")
        this.btn.SetLayout("left", "▾")

        itemH := 32
        pad := 6
        h := pad * 2 + this.items.Length * itemH
        w := this.w
        pop := Gui("-Caption +Border +Owner" this.parent.Hwnd, "DarkSelect")
        pop.BackColor := "0b0f14"
        pop.SetFont("s10 c" THEME["text"], THEME["fontFamily"])
        pop.AddText("x0 y0 w" w " h" h " Background0b0f14", "")
        y := pad
        for i, label in this.items {
            active := (i = this.Value)
            b := CreateStyledButton(pop, 4, y, w - 8, itemH - 2, label,
                ((idx) => (*) => this.Choose(idx))(i), "default")
            b.SetBackdrop("0b0f14")
            if active
                b.SetVisual(THEME["bgSelected"], THEME["accent"], THEME["bgSelected"], THEME["accentDark"])
            else
                b.SetVisual("0b0f14", "e5e7eb", "121820", "0b0f14")
            b.SetLayout("left", "")
            b.ctrl.SetFont("s10 norm", THEME["fontFamily"])
            y += itemH
        }
        DarkSelect.OpenGui := pop
        this.btn.ctrl.GetPos(&bx, &by, &bw, &bh)
        pt := Buffer(8, 0)
        NumPut("Int", bx, pt, 0)
        NumPut("Int", by + bh, pt, 4)
        DllCall("user32\ClientToScreen", "Ptr", this.parent.Hwnd, "Ptr", pt)
        sx := NumGet(pt, 0, "Int")
        sy := NumGet(pt, 4, "Int")
        pop.Show("x" sx " y" sy " w" w " h" h)
        try RoundCorners(pop, w, h, 8)
        pop.OnEvent("Close", (*) => this.Close())
        pop.OnEvent("Escape", (*) => this.Close())
        SetTimer(() => this.WatchOutside(), 80)
    }

    WatchOutside() {
        if !DarkSelect.OpenGui
            return
        if !GetKeyState("LButton", "P")
            return
        try {
            MouseGetPos(, , &win)
            if (win != DarkSelect.OpenGui.Hwnd)
                this.Close()
        }
    }

    Choose(idx) {
        this.Value := idx
        this.Close()
        if this.onChange
            try this.onChange.Call()
    }

    Close() {
        SetTimer(() => this.WatchOutside(), 0)
        try {
            if DarkSelect.OpenGui
                DarkSelect.OpenGui.Destroy()
        }
        DarkSelect.OpenGui := ""
        this.ApplyIdle()
    }

    SetVisible(state) {
        this.visible := state
        try this.btn.SetVisible(state)
        if !state
            this.Close()
    }

    Opt(*) {
    }

    Redraw() {
        try this.btn.Refresh()
    }
}

; Компактный список строк бинда (замена Windows ListView в редакторе).
; API совместим с вызовами Add / Modify / Delete / GetCount / Opt / OnEvent.
class EditorLineList {
    __New(parent, x, y, w, h, onSelect := "") {
        global THEME
        this.parent := parent
        this.x := x, this.y := y, this.w := w, this.h := h
        this.onSelect := onSelect
        this.items := []
        this.selected := 0
        this.offset := 0
        this.redrawLock := false
        this.rowH := 38
        this.gap := 6
        this.capacity := Max(1, Integer((h + this.gap) / (this.rowH + this.gap)))
        this.slots := []
        Loop this.capacity {
            iy := y + (A_Index - 1) * (this.rowH + this.gap)
            btn := CreateStyledButton(parent, x, iy, w, this.rowH, "",
                ((idx) => (*) => this.ClickSlot(idx))(A_Index), "default")
            btn.SetBackdrop(THEME["card"])
            btn.SetLayout("left", "")
            btn.ctrl.SetFont("s9 norm", THEME["fontFamily"])
            btn.radius := 8
            try RoundCorners(btn.ctrl, w, this.rowH, 8)
            this.slots.Push(btn)
        }
        this.Paint()
    }

    GetCount() {
        return this.items.Length
    }

    Opt(opt := "") {
        if InStr(opt, "-Redraw")
            this.redrawLock := true
        else if InStr(opt, "+Redraw") {
            this.redrawLock := false
            this.Paint()
        }
    }

    OnEvent(ev, cb) {
        if (ev = "ItemSelect")
            this.onSelect := cb
    }

    Add(opts := "", col1 := "", col2 := "", col3 := "") {
        this.items.Push({num: col1, text: col2, delay: col3})
        if !this.redrawLock
            this.Paint()
    }

    Delete(row := 0) {
        if (row = 0)
            this.items := []
        else if (row >= 1 && row <= this.items.Length)
            this.items.RemoveAt(row)
        if (this.selected > this.items.Length)
            this.selected := this.items.Length
        if !this.redrawLock
            this.Paint()
    }

    Modify(row, colSpec := "", value := "") {
        if (row < 1 || row > this.items.Length)
            return
        spec := String(colSpec)
        if (InStr(spec, "Select") || InStr(spec, "Focus")) {
            this.Select(row)
            return
        }
        if (spec = "Col2")
            this.items[row].text := value
        else if (spec = "Col3")
            this.items[row].delay := value
        else if (spec = "")
            this.items[row].num := value
        if !this.redrawLock
            this.Paint()
    }

    ClickSlot(slotIdx) {
        row := this.offset + slotIdx
        if (row < 1 || row > this.items.Length)
            return
        this.Select(row)
    }

    Select(row) {
        this.selected := row
        if (row > this.offset + this.capacity)
            this.offset := row - this.capacity
        if (row <= this.offset)
            this.offset := row - 1
        if (this.offset < 0)
            this.offset := 0
        this.Paint()
        if this.onSelect
            try this.onSelect.Call(this, row, true)
    }

    FormatDelay(raw) {
        if (raw = "" || raw = "—")
            return "—"
        if !IsNumber(raw)
            return raw
        n := Integer(raw)
        if (n <= 0)
            return "—"
        sec := n / 1000
        if (Mod(n, 1000) = 0)
            return Integer(sec) " с"
        return Format("{:.1f} с", sec)
    }

    ClipText(text, maxLen := 28) {
        t := Trim(String(text))
        if (StrLen(t) <= maxLen)
            return t
        return SubStr(t, 1, maxLen - 1) "…"
    }

    Paint() {
        global THEME
        maxOff := Max(0, this.items.Length - this.capacity)
        if (this.offset > maxOff)
            this.offset := maxOff
        Loop this.capacity {
            btn := this.slots[A_Index]
            row := this.offset + A_Index
            if (row > this.items.Length) {
                btn.ctrl.Text := ""
                btn.SetVisual(THEME["card"], THEME["card"], THEME["card"], THEME["card"])
                btn.SetLayout("left", "")
                btn.isClickable := false
                continue
            }
            item := this.items[row]
            num := Format("{:02}", Integer(item.num != "" ? item.num : row))
            btn.ctrl.Text := num "   " this.ClipText(item.text)
            btn.isClickable := true
            active := (row = this.selected)
            if active {
                btn.SetVisual(THEME["bgSelected"], THEME["text"], THEME["bgSelected"], THEME["accent"], THEME["accent"])
                btn.ctrl.SetFont("s9 bold", THEME["fontFamily"])
            } else {
                btn.SetVisual("0d1117", THEME["text"], "121820", "232a36")
                btn.ctrl.SetFont("s9 norm", THEME["fontFamily"])
            }
            btn.SetLayout("left", this.FormatDelay(item.delay))
        }
    }
}

; Очень мягкое свечение вокруг карточки (активное состояние).
; Кольца всегда существуют, но в покое окрашены в цвет подложки.
class CardGlow {
    __New(parent, x, y, w, h, color, backdrop := "", radius := 0) {
        global THEME
        if !radius
            radius := THEME["radiusLg"]
        this.backdrop := backdrop = "" ? THEME["bg"] : backdrop
        this.rings := []
        this.active := false
        ; Внутреннее кольцо создаём первым: после SendPanelToBack оно окажется
        ; выше внешнего, и оба — под карточкой.
        for spec in [[2, 0.16], [5, 0.07]] {
            pad := spec[1], k := spec[2]
            ring := parent.AddText("x" (x - pad) " y" (y - pad) " w" (w + pad * 2) " h" (h + pad * 2)
                " Background" this.backdrop, "")
            RoundCorners(ring, w + pad * 2, h + pad * 2, radius + pad)
            SendPanelToBack(ring)
            this.rings.Push({ctrl: ring, on: BlendHex(this.backdrop, color, k)})
        }
    }

    Set(state) {
        if this.active = state
            return
        this.active := state
        for r in this.rings {
            try {
                r.ctrl.Opt("Background" (state ? r.on : this.backdrop))
                r.ctrl.Redraw()
            }
        }
    }
}

; Заголовок карточки. Без разделительной линии: иерархию держат размер,
; вес и отступы. Справа — необязательная приглушённая подпись.
CreateCardHeader(parent, x, y, w, title, note := "", pad := 0) {
    global THEME
    if !pad
        pad := THEME["cardPad"]
    t := parent.AddText("x" (x + pad) " y" (y + 18) " w" (w - pad * 2 - 110) " h20 BackgroundTrans c" THEME["text"], title)
    t.SetFont("s" THEME["fontSection"] " bold", THEME["fontFamily"])
    if note != "" {
        n := parent.AddText("x" (x + w - pad - 110) " y" (y + 21) " w110 h16 Right BackgroundTrans c" THEME["textMuted"], note)
        n.SetFont("s" THEME["fontMeta"] " norm", THEME["fontFamily"])
    }
    return t
}

; ─── Единая система состояний: ● READY / ACTIVE / SAVED / WAITING / ERROR ─────
class StatusDot {
    __New(parent, x, y, text := "", color := "", backdrop := "", size := 8, labelW := 220, fontSize := 8) {
        global THEME
        this.parent := parent
        this.size := size
        this.backdrop := backdrop = "" ? THEME["card"] : backdrop
        color := color = "" ? THEME["textMuted"] : color
        this.color := color

        ; Очень слабое гало: ровно одно кольцо в 2px, без пятен и ярких плашек.
        this.halo := parent.AddText("x" (x - 2) " y" (y - 2) " w" (size + 4) " h" (size + 4)
            " Background" BlendHex(this.backdrop, color, 0.22), "")
        RoundCorners(this.halo, size + 4, size + 4, (size + 4) // 2)

        this.dot := parent.AddText("x" x " y" y " w" size " h" size " Background" color, "")
        RoundCorners(this.dot, size, size, size // 2)

        this.label := parent.AddText("x" (x + size + 10) " y" (y - 5) " w" labelW " h" (size + 10)
            " 0x200 BackgroundTrans c" color, text)
        this.label.SetFont("s" fontSize " bold", THEME["fontFamily"])
    }

    Set(text, color := "") {
        if color = ""
            color := this.color
        this.color := color
        try {
            this.halo.Opt("Background" BlendHex(this.backdrop, color, 0.22))
            this.halo.Redraw()
        }
        try {
            this.dot.Opt("Background" color)
            this.dot.Redraw()
        }
        try {
            this.label.Text := text
            this.label.Opt("c" color)
            this.label.Redraw()
        }
    }

    SetVisible(state) {
        try this.halo.Visible := state
        try this.dot.Visible := state
        try this.label.Visible := state
    }
}

CreateStatusDot(parent, x, y, text := "", color := "", backdrop := "", size := 8, labelW := 220, fontSize := 8) {
    return StatusDot(parent, x, y, text, color, backdrop, size, labelW, fontSize)
}

; Проверка наличия шрифта: если Segoe UI Variable недоступен (Windows 10),
; вся типографика аккуратно откатывается на Segoe UI.
FontInstalled(name) {
    hdc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    if !hdc
        return false
    hFont := DllCall("gdi32\CreateFont", "Int", 16, "Int", 0, "Int", 0, "Int", 0, "Int", 400
        , "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 0
        , "Str", name, "Ptr")
    result := false
    if hFont {
        oldFont := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
        buf := Buffer(64 * 2, 0)
        DllCall("gdi32\GetTextFaceW", "Ptr", hdc, "Int", 64, "Ptr", buf)
        actual := StrGet(buf, "UTF-16")
        result := (StrLower(actual) = StrLower(name))
        DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont)
        DllCall("gdi32\DeleteObject", "Ptr", hFont)
    }
    DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return result
}

ResolveUIFont() {
    global THEME
    try {
        if !FontInstalled(THEME["fontFamily"])
            THEME["fontFamily"] := THEME["fontFallback"]
    } catch {
        THEME["fontFamily"] := THEME["fontFallback"]
    }
    return THEME["fontFamily"]
}

ResolveUIFont()

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
    static lastInput := 0

    point := Buffer(8, 0)
    if !DllCall("user32\GetCursorPos", "Ptr", point)
        return
    mouseX := NumGet(point, 0, "Int")
    mouseY := NumGet(point, 4, "Int")
    hwndAtPoint := DllCall("user32\WindowFromPoint", "Int64", (mouseY << 32) | (mouseX & 0xFFFFFFFF), "Ptr")
    winId := hwndAtPoint ? DllCall("user32\GetAncestor", "Ptr", hwndAtPoint, "UInt", 2, "Ptr") : 0

    hitButton := 0
    hitInput := 0
    if winId {
        for btn in HoverButtons {
            if IsButtonUnderMouse(btn, mouseX, mouseY, winId) {
                hitButton := btn
                break
            }
        }
        if !hitButton {
            for fld in InputField.Registry {
                if IsInputUnderMouse(fld, mouseX, mouseY, winId) {
                    hitInput := fld
                    break
                }
            }
        }
        ; hover строк-карточек (настройки)
        for hc in HoverCard.Registry {
            state := IsPanelUnderMouse(hc, mouseX, mouseY, winId)
            if (hc.hovered != state)
                try hc.SetHover(state)
        }
    } else {
        for hc in HoverCard.Registry {
            if hc.hovered
                try hc.SetHover(false)
        }
    }

    ; hover полей ввода (border: #202D3B → #344252)
    if hitInput != lastInput {
        if IsObject(lastInput)
            try lastInput.SetHover(false)
        if IsObject(hitInput)
            try hitInput.SetHover(true)
        lastInput := hitInput
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

; Наведение на строку-карточку (страница настроек)
IsPanelUnderMouse(panel, mouseX, mouseY, winId) {
    if !IsObject(panel)
        return false
    try {
        if panel.parent.Hwnd != winId
            return false
        if !panel.visible
            return false
        if !DllCall("user32\IsWindowVisible", "Ptr", panel.surface.Hwnd)
            return false
        panel.surface.GetPos(&x, &y, &w, &h)
        point := Buffer(8, 0)
        NumPut("Int", x, point, 0)
        NumPut("Int", y, point, 4)
        DllCall("user32\ClientToScreen", "Ptr", panel.parent.Hwnd, "Ptr", point)
        screenX := NumGet(point, 0, "Int")
        screenY := NumGet(point, 4, "Int")
        return mouseX >= screenX && mouseX < screenX + w
            && mouseY >= screenY && mouseY < screenY + h
    } catch {
        return false
    }
}

IsInputUnderMouse(fld, mouseX, mouseY, winId) {
    if !IsObject(fld)
        return false
    try {
        if fld.parent.Hwnd != winId
            return false
        if !fld.visible
            return false
        if !DllCall("user32\IsWindowVisible", "Ptr", fld.frame.Hwnd)
            return false
        fld.frame.GetPos(&x, &y, &w, &h)
        point := Buffer(8, 0)
        NumPut("Int", x, point, 0)
        NumPut("Int", y, point, 4)
        DllCall("user32\ClientToScreen", "Ptr", fld.parent.Hwnd, "Ptr", point)
        screenX := NumGet(point, 0, "Int")
        screenY := NumGet(point, 4, "Int")
        return mouseX >= screenX && mouseX < screenX + w
            && mouseY >= screenY && mouseY < screenY + h
    } catch {
        return false
    }
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
    ; Поля ввода уничтоженного окна тоже убираем из реестра hover-опроса.
    try {
        aliveInputs := []
        for fld in InputField.Registry {
            try {
                if !IsObject(fld) || !IsObject(fld.parent)
                    continue
                if fld.parent = gui
                    continue
                if fld.frame.Hwnd && WinExist("ahk_id " fld.frame.Hwnd)
                    aliveInputs.Push(fld)
            }
        }
        InputField.Registry := aliveInputs

        aliveCards := []
        for hc in HoverCard.Registry {
            try {
                if !IsObject(hc) || !IsObject(hc.parent) || hc.parent = gui
                    continue
                if hc.surface.Hwnd && WinExist("ahk_id " hc.surface.Hwnd)
                    aliveCards.Push(hc)
            }
        }
        HoverCard.Registry := aliveCards

        aliveToggles := []
        for tg in ToggleBox.Registry {
            try {
                if !IsObject(tg) || !IsObject(tg.parent) || tg.parent = gui
                    continue
                if tg.frame.Hwnd && WinExist("ahk_id " tg.frame.Hwnd)
                    aliveToggles.Push(tg)
            }
        }
        ToggleBox.Registry := aliveToggles
    }
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
    ; Нейтральная icon-кнопка: красный акцент появляется только на hover.
    btn := CreateStyledButton(parent, x, y, size, size, "×", callback, "icon", "Очистить")
    try btn.ctrl.SetFont("s12 norm", "Segoe UI")
    return btn
}

; Тёмная тема для стандартных чекбоксов/кнопок Windows: без этого рамка
; чекбокса рисуется светлой и выбивается из интерфейса.
StyleCheckbox(ctrl) {
    global THEME
    if !IsObject(ctrl)
        return ctrl
    try {
        if VerCompare(A_OSVersion, "10.0.17763") >= 0
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
    }
    try ctrl.SetFont("s9 norm", THEME["fontFamily"])
    return ctrl
}

; ══════════════════════════════════════════════════════════════════════════
; СИСТЕМА РАДИАЛЬНОГО МЕНЮ (WHEEL MENU) - ИСПРАВЛЕННАЯ
; ══════════════════════════════════════════════════════════════════════════
