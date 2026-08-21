; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: notify                        ║
; ║  Система всплывающих уведомлений                ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
; Уведомления на обычных функциях (не классах): статические методы
; класса нельзя передавать в SetTimer как callback в AHK v2 —
; это даёт «Invalid callback function».
;
global NotifyGui := ""
global NotifyPhase := ""       ; "in" | "hold" | "out"
global NotifyStep := 0
global NotifyBaseX := 0
global NotifyBaseY := 0

ShowNotify(text, type := "info", duration := 2000) {
    global NotifyGui, NotifyPhase, NotifyStep, NotifyBaseX, NotifyBaseY, THEME
    HideNotify()

    ; Убираем эмодзи из текста: в GDI-рендере они превращаются в чёрные
    ; силуэты/квадраты — текст уведомления должен оставаться чистым
    try text := RegExReplace(text, "[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}]", "")

    color := THEME["accent"]
    switch type {
        case "success": color := THEME["success"]
        case "error": color := THEME["error"]
        case "warning": color := THEME["warning"]
    }

    NotifyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "Notify")
    NotifyGui.BackColor := THEME["border"]
    NotifyGui.MarginX := 0
    NotifyGui.MarginY := 0
    ; Тонкая рамка (фон окна) + основная поверхность внутри
    NotifyGui.AddText("x1 y1 w318 h48 Background" THEME["surface"], "")
    ; Маленькая статус-точка вместо широкой цветной полосы
    dot := NotifyGui.AddText("x16 y22 w7 h7 Background" color, "")
    RoundCorners(dot, 7, 7, 4)
    NotifyGui.SetFont("s9 norm", THEME["fontFamily"])
    NotifyGui.AddText("x34 y16 w270 h20 c" THEME["textBody"] " BackgroundTrans", text)

    NotifyBaseX := A_ScreenWidth - 340
    NotifyBaseY := A_ScreenHeight - 110
    NotifyGui.Show("x" NotifyBaseX " y" (NotifyBaseY + 16) " w320 h50 NA")
    ; Скруглённые углы окна уведомления
    try {
        hrgn := DllCall("gdi32\CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", 321, "Int", 51, "Int", 12, "Int", 12, "Ptr")
        DllCall("user32\SetWindowRgn", "Ptr", NotifyGui.Hwnd, "Ptr", hrgn, "Int", 1)
    }
    WinSetTransparent(0, NotifyGui)

    ; Плавное появление (fade-in + подъём)
    NotifyPhase := "in"
    NotifyStep := 0
    SetTimer(NotifyTick, 12)

    ; Авто-скрытие после паузы (однократный таймер)
    SetTimer(NotifyAutoHide, -duration)
}

HideNotify() {
    global NotifyGui, NotifyPhase
    SetTimer(NotifyTick, 0)
    SetTimer(NotifyAutoHide, 0)
    try {
        if NotifyGui
            NotifyGui.Destroy()
        NotifyGui := ""
    }
    NotifyPhase := ""
}

NotifyAutoHide() {
    global NotifyGui, NotifyPhase, NotifyStep
    if NotifyGui && NotifyPhase != "out" {
        NotifyPhase := "out"
        NotifyStep := 0
    }
}

NotifyTick() {
    global NotifyGui, NotifyPhase, NotifyStep, NotifyBaseX, NotifyBaseY
    if !NotifyGui {
        SetTimer(NotifyTick, 0)
        return
    }
    NotifyStep++
    t := Min(1, NotifyStep / 8)
    e := 1 - (1 - t) ** 3     ; ease-out — плавно и без рывков

    if NotifyPhase = "in" {
        alpha := Round(240 * e)
        y := Round(NotifyBaseY + 16 * (1 - e))
        try WinSetTransparent(alpha, NotifyGui)
        try NotifyGui.Move(NotifyBaseX, y)
        if t >= 1 {
            NotifyPhase := "hold"
            NotifyStep := 0
        }
    } else if NotifyPhase = "out" {
        alpha := Round(240 * (1 - e))
        y := Round(NotifyBaseY + 10 * e)
        try WinSetTransparent(alpha, NotifyGui)
        try NotifyGui.Move(NotifyBaseX, y)
        if t >= 1 {
            SetTimer(NotifyTick, 0)
            try NotifyGui.Destroy()
            NotifyGui := ""
            NotifyPhase := ""
        }
    }
}


; ═══════════════════════════════════════════════════════════════════════════════
; ГЛОБАЛЬНЫЕ ГОРЯЧИЕ КЛАВИШИ
; ═══════════════════════════════════════════════════════════════════════════════


; 2. Хоткеи Оверлея
; Работают ТОЛЬКО если:
; 1. Оверлей видим
; 2. Мы НЕ вводим ID в оверлее (overlayInputMode = false)
; 3. Чат ЗАКРЫТ (IsChatActive = false)
