; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: globals                       ║
; ║  Глобальные переменные (состояние приложения)   ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
global VERSION := Constants.VERSION
global CONFIG_FILE := Constants.CONFIG_FILE
global FILTERS_FILE := Constants.FILTERS_FILE
global APP_NAME := Constants.APP_NAME  ; <--- Этой строки не хватало!
global AUTHOR := Constants.AUTHOR      ; <--- И этой тоже

; ══════════════════════════════════════════════════════════════════════════════
;  DESIGN SYSTEM — Dark Premium / Medical Enterprise / Subtle Neon
;  Правило пропорций: ~90% тёмные поверхности, ~7% серо-синий, ~3% cyan.
;  Cyan (accent) = сигнал состояния/действия, а не декоративный цвет.
;  Все имена токенов сохранены для обратной совместимости со старым кодом.
; ══════════════════════════════════════════════════════════════════════════════
global THEME := Map(
    ; ── Поверхности ───────────────────────────────────────────────────────────
    "bg",           "080a0f",   ; фон приложения (почти чёрный)
    "surface",      "0d1016",   ; основная поверхность: шапка, навигация, карточки
    "card",         "0d1016",   ; поверхность карточки
    "bgLight",      "0d1016",   ; legacy-алиас основной поверхности
    "bgElevated",   "111722",   ; приподнятая поверхность (плитки, вложенные блоки)
    "bgHighlight",  "111722",   ; legacy-алиас приподнятой поверхности
    "bgHover",      "151d28",   ; поверхность под курсором
    "surfaceHover", "151d28",
    "bgSelected",   "0f1e29",   ; активный элемент навигации (cyan-tinted)
    "field",        "0d141d",   ; фон поля ввода
    "fieldBg",      "0d141d",
    "fieldBorder",  "202d3b",   ; рамка поля ввода
    "backdrop",     "080a0f",

    ; ── Границы ───────────────────────────────────────────────────────────────
    "border",       "202833",
    "cardBorder",   "191f29",   ; рамка карточки — тише основной границы
    "borderLight",  "344252",   ; hover-рамка
    "borderGlow",   "263646",   ; тонкие разделители под шапками таблиц

    ; ── Текст ─────────────────────────────────────────────────────────────────
    "text",         "f2f4f7",
    "textTitle",    "f7f9fc",
    "textBody",     "dde3ea",
    "textDim",      "9aa4b2",
    "textMuted",    "626d7b",

    ; ── Акцент (использовать экономно) ────────────────────────────────────────
    "accent",       "38bdf8",
    "accentLight",  "7dd3fc",
    "accentDark",   "1c5f7d",
    "accentSoft",   "103746",   ; мягкая cyan-подложка (glow, focus ring)
    "accentGlow",   "1a5872",
    "btnPrimary",   "0e2a37",   ; фон primary-кнопки

    ; ── Статусы ───────────────────────────────────────────────────────────────
    "success",      "35c98a",
    "successDark",  "174a35",
    "successSoft",  "0f2a20",
    "warning",      "d9a75c",
    "warningDark",  "534020",
    "warningSoft",  "241d12",
    "error",        "e66b83",
    "errorDark",    "6d2f3c",
    "errorSoft",    "24141a",

    ; ── Типографика ───────────────────────────────────────────────────────────
    "fontTitle",    14,         ; заголовок страницы
    "fontSection",  10,         ; заголовок карточки
    "fontBody",     9,
    "fontMeta",     7,          ; label / caption
    "fontFamily",   "Segoe UI Variable Text",
    "fontFallback", "Segoe UI",
    "fontMono",     "Consolas",

    ; ── Геометрия ─────────────────────────────────────────────────────────────
    ; Единая система скруглений: поля 8, кнопки 8–10, карточки 10–12, окна 12–16
    "radiusSm",     8,          ; inputs / малые элементы
    "radius",       10,         ; buttons / компактные карточки
    "radiusLg",     12,         ; карточки
    "radiusWin",    14,         ; окна и popup
    "spacing",      16,
    "spacingSm",    8,
    "spacingLg",    24,
    "btnH",         38,        ; стандартная высота кнопки
    "btnHSm",       30,        ; малая кнопка
    "inputH",       34,        ; высота поля ввода
    "cardPad",      18,        ; внутренний отступ карточки
    "navH",         30,        ; высота пункта навигации

    ; ── Legacy-алиасы кнопок ──────────────────────────────────────────────────
    "btnBg",        "111722",
    "btnBgHover",   "151d28",
)

global CFG := Map(
    "chatKey", "t",
    "onlyGTA", true,
    "baseDelay", Constants.DEFAULT_BASE_DELAY,
    "afterChatDelay", Constants.DEFAULT_AFTER_CHAT_DELAY,
    "afterEnterDelay", Constants.DEFAULT_AFTER_ENTER_DELAY,
    "jitter", Constants.DEFAULT_JITTER,
    "patientFormat", "quote",
    "overlayOpacity", Constants.DEFAULT_OPACITY,
    "notifySms", true,
    "notifyMention", true,
    "notifyKeywords", false,
    "editorAutoSaveDelay", false,
    "autoSave", true,
    "autoSaveInterval", 60,
    
    "autoScreen", false,
    "ScreenRules", [],
    
    "enableWheel", true,
    "hotkeyWheel", "MButton",
    "wheelTop", 0,
    "wheelRight", 0,
    "wheelBottom", 0,
    "wheelLeft", 0,

    "hotkeyReplySms", "F4",
    "hotkeyOverlay", "F10",
    "hotkeyMiniOverlay", "!F10",
    "hotkeyStopSending", "F8",
    "hotkeyMainGui", "F9",
)

global STATE := Map(
    "patientId", "",
    "myName", "Max Life",
    "hospital", "MCLV",
    "rank", "",
    "specialty", "Интерн",
    "isSending", false,
    "stopSending", false,
    "overlayInputMode", false,
    "tempId", "",
    "overlayMode", "full",
    "lastSmsNum", "",
    "lastAutoSave", ""
)

global STATS := Map("totalSent", 0, "patientsHealed", 0, "pillsGiven", 0, "injectionsGiven", 0, "operationsDone", 0, "medChecks", 0, "vaccinesGiven", 0, "sessionStart", A_Now)

global HoverButtons := [], SLOTS := [], UndoHistory := [], FILTERS := Map()
global MainGui := "", OverlayGui := "", EditorGui := "", FilterMenuGui := "", FilterEditorGui := "", ContextMenuGui := ""
global g_BtnSaveProfile := "", g_BtnSaveSettings := "", g_BtnGlobalSave := ""
; Индикаторы единой системы состояний (● READY / ACTIVE / SAVED / WAITING / ERROR)
global g_SystemStatus := "", g_ProfileStatus := "", g_PatientStatus := "", g_SaveStatus := ""
global g_PatientGlow := "", g_KpiPatientDot := "", g_KpiSaveDot := ""
global CurrentSearch := "", CurrentFilter := "", CurrentIdFormat := ""
global OverlayVisible := false, ChatIsOpen := false
global CapturedEditorKey := "", OverlayInputHook := ""
global EditorHasChanges := false, EditorConfirmDelete := true, GlobalUnsavedChanges := false, WasDirtyBeforeEditor := false
global OverlaySelectedIndex := 0, OverlayBindsList := [], CurrentPage := 1, TotalPages := 4
global CurrentEditSlot := 0, EditorLineCount := 12, EditorScrollPos := 1, EditorLines := []
global MaxUndoSteps := Constants.MAX_UNDO_STEPS, EDITOR_VISIBLE_LINES := Constants.EDITOR_VISIBLE_LINES

global BtnConfirmDelay := "", EditorInputHook := "", EditorBlinkState := false
global WheelGui := "", BindSelectorGui := "", FilterPopupGui := "", btnFilterDisplay := "", RuleEditorGui := ""
global MentionNotifyGui := "", SmsNotifyGui := "", LastSmsNotification := ""
global ChatLogPath := A_MyDocuments "\GTA San Andreas User Files\SAMP\chatlog.txt", LastLogPos := 0

Loop Constants.MAX_SLOTS {
    SLOTS.Push(Map("name", "", "hotkey", "", "lines", [], "enabled", false, "category", "", "statType", ""))
}

global CurrentBlinkTimer := "" 
global CurrentCapturing := "" 
global CaptureHook := ""
