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

global THEME := Map(
    "bg",           "181825",
    "bgLight",      "1e1e2e",
    "bgHighlight",  "313244",
    "bgSelected",   "45475a",
    "accent",       "89b4fa",
    "accentDark",   "585b70",
    "accentLight",  "b4befe",
    "accentGlow",   "89b4fa",
    "success",      "a6e3a1",
    "successDark",  "588c5e",
    "warning",      "f9e2af",
    "warningDark",  "df8e1d",
    "error",        "f38ba8",
    "errorDark",    "e64553",
    "text",         "cdd6f4",
    "textDim",      "a6adc8",
    "textMuted",    "6c7086",
    "border",       "313244",
    "borderLight",  "45475a",
    "borderGlow",   "89b4fa",
    "bgHover",      "3b3d4f",
    "btnBg",        "313244",
    "btnBgHover",   "45475a",
    ; === Дизайн-система (единые токены) ===
    "radiusSm",     6,
    "radius",       10,
    "radiusLg",     14,
    "spacing",      16,
    "spacingSm",    8,
    "spacingLg",    24,
    "btnH",         36,        ; стандартная высота кнопки
    "btnHSm",       30,        ; малая кнопка
    "inputH",       30,        ; высота поля ввода
    "cardPad",      16,        ; внутренний отступ карточки
    "navH",         28,        ; высота пункта навигации
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

