; ╔══════════════════════════════════════════════════════════════════╗
; ║            DOCTOR BINDER v2.1  —  ГЛАВНЫЙ ФАЙЛ                   ║
; ║            Точка входа: хоткеи, инициализация, запуск            ║
; ╚══════════════════════════════════════════════════════════════════╝

#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetTitleMatchMode 2
SetWorkingDir A_ScriptDir  ; все относительные пути — от папки скрипта

try {
    DllCall("uxtheme\SetPreferredAppMode", "Int", 2) 
} catch {
    try DllCall("uxtheme\AllowDarkModeForApp", "Int", 1)
}

if not A_IsAdmin
{
    try Run "*RunAs " A_ScriptFullPath
    catch
        MsgBox "Скрипту нужны права администратора для работы в игре!"
    ExitApp
} 


; ╔══════════════════════════════════════════════════════════════════╗
; ║                    ПОДКЛЮЧЕНИЕ МОДУЛЕЙ                          ║
; ╚══════════════════════════════════════════════════════════════════╝
#Include lib\01_Constants.ahk
#Include lib\02_Globals.ahk
#Include lib\03_UI.ahk
#Include lib\04_Utils.ahk
#Include lib\05_Notify.ahk
#Include lib\06_Filters.ahk
#Include lib\07_Profiles.ahk
#Include lib\08_Overlay.ahk
#Include lib\09_Chat.ahk
#Include lib\10_MainGui.ahk
#Include lib\11_BindList.ahk
#Include lib\12_Editor.ahk
#Include lib\13_Sending.ahk
#Include lib\14_Settings.ahk
#Include lib\15_Menus.ahk
#Include lib\16_Telegram.ahk

#HotIf (CurrentCapturing != "")
*MButton:: {
    global CurrentCapturing
    FinalizeCapture(CurrentCapturing, "MButton", "")
}
#HotIf

#HotIf OverlayVisible && !STATE["overlayInputMode"] && !IsChatActive()

$Up:: OverlayUp()
$Down:: OverlayDown()
$Enter:: OverlayActivate()
$NumpadEnter:: OverlayActivate()
$Escape:: OverlayClose()
$PgUp:: OverlayPageUp()
$PgDn:: OverlayPageDown()

; Буквы (P, C)
$p:: OverlaySetId()
$c:: OverlayClearId()

; Цифры
$1:: OverlaySelectNum(1)
$2:: OverlaySelectNum(2)
$3:: OverlaySelectNum(3)
$4:: OverlaySelectNum(4)
$5:: OverlaySelectNum(5)
$6:: OverlaySelectNum(6)
$7:: OverlaySelectNum(7)
$8:: OverlaySelectNum(8)
$9:: OverlaySelectNum(9)
$0:: OverlaySelectNum(10)

#HotIf

; ═══════════════════════════════════════════════════════════════════════════════
; СЛЕЖКА ЗА СОСТОЯНИЕМ ЧАТА (ФИНАЛ)
; ═══════════════════════════════════════════════════════════════════════════════

#HotIf WinActive("ahk_exe gta_sa.exe")

; Клавиша 't' (английская) - открывает чат
~*t:: {
    global ChatIsOpen := true
}

; ✅ ИСПРАВЛЕНИЕ: Клавиша 'Ё' (тильда) через Скан-код (SC029)
; Теперь работает на любой раскладке и не выдает ошибок
~*SC029:: {
    global ChatIsOpen := true
}

; Клавиша F6 - работает как ПЕРЕКЛЮЧАТЕЛЬ
~*F6:: {
    global ChatIsOpen := !ChatIsOpen
}

; Клавиши закрытия чата
~*Enter::
~*NumpadEnter::
~*Escape:: {
    SetTimer(CloseChatTimer, -150)
}

; Клик мышкой (часто закрывает диалоги)
~*LButton:: {
    SetTimer(CloseChatTimer, -100)
}

#HotIf

; Hover кнопок обслуживается таймером PollButtonHover из lib/03_UI.ahk.

; ═══════════════════════════════════════════════════════════════════════════════
; СИСТЕМА УВЕДОМЛЕНИЙ ОБ УПОМИНАНИИ (ОБНОВЛЕННАЯ)
; ═══════════════════════════════════════════════════════════════════════════════

#HotIf (CurrentCapturing != "")
~LButton:: {
    global MainGui, CurrentCapturing
    
    try {
        MouseGetPos(,, &winId, &ctrlHwnd)
        
        ; Если кликнули не по нашему окну вообще -> отмена
        if (winId != MainGui.Hwnd) {
             CancelCapture(CurrentCapturing)
             return
        }
        
        ; Проверяем, кликнули ли мы по ТОЙ ЖЕ кнопке, которую настраиваем
        targetCtrl := MainGui["Display_" CurrentCapturing].Hwnd
        
        if (ctrlHwnd != targetCtrl) {
            ; Кликнули мимо кнопки (в другое поле или в пустоту) -> Отмена
            CancelCapture(CurrentCapturing)
        }
        ; Если кликнули по той же кнопке - ничего не делаем (игнорим), пусть дальше ждет
    } catch {
        CancelCapture(CurrentCapturing)
    }
}
#HotIf



Log("══════════ Doctor Binder v" VERSION " запущен ══════════", "INFO")

LoadConfig()
BuildMainGui()
InitDefaultFilters()
RegisterAllHotkeys()
RegisterSystemHotkeys()
InitChatWatcher()

; === ПРАВИЛЬНАЯ ПРЕДЗАГРУЗКА ===
CreateOverlayGuiBase("full") ; Просто создаем структуру в памяти
UpdateOverlayData()          ; Заполняем данными

SetTimer(UpdateAppClock, 1000) ; Обновлять часы каждую секунду

; Автосохранение: проверяем изменения и сохраняем (интервал из настроек, по умолчанию 60 сек)
SetTimer(AutoSaveTick, CFG["autoSaveInterval"] * 1000)

; 6. Показываем главное меню и приветствие
ShowMainGui()
; Приветствие с задержкой — чтобы не было эффекта «запустилось два окна»
SetTimer((*) => ShowNotify("Doctor Binder v" VERSION " готов к работе!", "success", 3000), -800)

; Статистика запуска отправляется в фоне, чтобы не блокировать старт скрипта
SetTimer(SendLaunchStats, -500)
; Обработчик выхода (сохранение при закрытии)
OnExit(ExitHandler)


; Закрытие меню фильтра кликом мимо — ТОЛЬКО когда меню открыто,
; чтобы глобальный ~LButton не перехватывал клики в остальное время
#HotIf (FilterPopupGui != "")
~LButton:: {
    global FilterPopupGui
    try {
        if FilterPopupGui {
            MouseGetPos(,, &winId)
            ; Если клик НЕ по окну фильтра -> Закрываем его
            if (winId != FilterPopupGui.Hwnd) {
                CleanupHoverButtons(FilterPopupGui)
                FilterPopupGui.Destroy()
                FilterPopupGui := ""
            }
        }
    }
}
#HotIf


; Стильный крестик (Иконка + Неон + Анимация клика)

