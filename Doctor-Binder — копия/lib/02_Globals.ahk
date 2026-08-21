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
    "bg",           "0b1018",
    "bgLight",      "121a26",
    "bgElevated",   "182231",
    "bgHighlight",  "1b2737",
    "surface",      "121a26",
    "card",         "151f2d",
    "field",        "0f1823",
    "bgSelected",   "20334a",
    "accent",       "55b9e8",
    "accentDark",   "176b96",
    "accentLight",  "8acde8",
    "accentGlow",   "3ba7e3",
    "success",      "69c7a4",
    "successDark",  "216b52",
    "warning",      "dcb16b",
    "warningDark",  "8c6223",
    "error",        "df788b",
    "errorDark",    "8e3549",
    "text",         "e7eef7",
    "textDim",      "9aabc0",
    "textMuted",    "63758b",
    "border",       "263548",
    "borderLight",  "354a62",
    "borderGlow",   "356f8a",
    "bgHover",      "223247",
    "btnBg",        "1b2737",
    "btnBgHover",   "26384f",
    "textTitle",    "f1f5fa",
    "textBody",     "d3dce8",
    "fontTitle",    20,
    "fontSection",  13,
    "fontBody",     10,
    "fontMeta",     8,
    "fontFamily",   "Segoe UI Variable Text",
    ; === Дизайн-система (единые токены) ===
    "radiusSm",     8,
    "radius",       12,
    "radiusLg",      16,
    "spacing",      16,
    "spacingSm",    8,
    "spacingLg",    24,
    "btnH",         38,        ; стандартная высота кнопки
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
