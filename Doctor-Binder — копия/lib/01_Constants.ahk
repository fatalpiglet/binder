; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: constants                     ║
; ║  Константы и настройки по умолчанию             ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
class Constants {
    static VERSION := "2.1"
    static APP_NAME := "Doctor Binder"
    static AUTHOR := "by maxon3r"
    static CONFIG_FILE := A_ScriptDir "\doctor_config.ini"
    static FILTERS_FILE := A_ScriptDir "\doctor_filters.ini"
    static MAX_SLOTS := 100
    static MAX_PATIENT_ID_LENGTH := 5
    static MAX_UNDO_STEPS := 20
    
    ; -- Лимиты отображения --
    static BINDS_PER_PAGE := 12
    static OVERLAY_BINDS_PER_PAGE := 10
    static EDITOR_VISIBLE_LINES := 8  ; <--- ДОБАВИТЬ ВОТ ЭТУ СТРОКУ
    
    static DEFAULT_BASE_DELAY := 2300
    static DEFAULT_AFTER_CHAT_DELAY := 300
    static DEFAULT_AFTER_ENTER_DELAY := 400
    static DEFAULT_JITTER := 200
    static DEFAULT_OPACITY := 245
    static TYPE_DELAY := 80
    static PATH_SAMP_SCREENS := A_MyDocuments "\GTA San Andreas User Files\SAMP\screens"
    static PATH_BINDER_REPORTS := A_MyDocuments "\Doctor Binder Reports"
}
; === ВСТАВИТЬ/ИСПРАВИТЬ ЭТОТ БЛОК ===
