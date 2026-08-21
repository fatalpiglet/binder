; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: telegram                      ║
; ║  Отправка статистики запуска в Telegram         ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
SendLaunchStats() {
    global STATE, VERSION

    ; Токен и chat_id теперь берём из отдельного файла telegram.ini (лежит рядом со скриптом).
    ; Файла может не быть — тогда просто ничего не отправляем и не мешаем запуску.
    iniPath := A_ScriptDir "\telegram.ini"
    if !FileExist(iniPath)
        return

    my_token  := IniRead(iniPath, "Telegram", "token", "")
    my_chat_id := IniRead(iniPath, "Telegram", "chat_id", "")

    ; Пустой/заполнитель = отключаем отправку
    if (my_token = "" || my_chat_id = "" || InStr(my_token, "ВСТАВЬ") || InStr(my_token, "ВАШ_ТОКЕН"))
        return

    user := (IsSet(STATE) && STATE.Has("myName") && STATE["myName"] != "") ? STATE["myName"] : "Неизвестный"
    hosp := (IsSet(STATE) && STATE.Has("hospital")) ? STATE["hospital"] : "?"
    ver  := (IsSet(VERSION)) ? VERSION : "7.3"
    
    text := "🚀 *Запуск Binder v" ver "*`n👤 Ник: " user "`n🏥 Больница: " hosp
    
    encodedText := EncodeUri(text)
    url := "https://api.telegram.org/bot" my_token "/sendMessage?chat_id=" my_chat_id "&text=" encodedText "&parse_mode=Markdown"
    
    try {
        WebRequest := ComObject("WinHttp.WinHttpRequest.5.1")
        WebRequest.Open("GET", url, true)
        ; Не зависаем дольше 5 секунд (иначе Telegram, который недоступен, стопорит запуск)
        WebRequest.SetTimeouts(5000, 5000, 5000, 5000)
        WebRequest.Send()
        WebRequest.WaitForResponse(5)
        ; Ответ игнорируем — это просто «запись в журнал», она не обязательна
    } catch {
        ; Тихо игнорируем любую ошибку (нет сети, Telegram заблокирован, токен отозван и т.д.)
        OutputDebug("Telegram launch stats skipped (no network / token invalid).")
    }
}

; Функция кодирования текста в URL-формат (UTF-8)
EncodeUri(str) {
    ; Конвертируем строку в UTF-8 буфер
    utf8Buf := Buffer(StrPut(str, "UTF-8"))
    StrPut(str, utf8Buf, "UTF-8")
    
    out := ""
    Loop utf8Buf.Size - 1 { ; -1 чтобы не брать null-терминатор
        byte := NumGet(utf8Buf, A_Index - 1, "UChar")
        char := Chr(byte)
        
        ; Если символ безопасный (a-z, 0-9, и т.д.), оставляем как есть (но только если это ASCII)
        if (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A) || byte == 0x2D || byte == 0x2E || byte == 0x5F || byte == 0x7E {
            out .= char
        } else {
            ; Иначе кодируем в %XX
            out .= Format("%{:02X}", byte)
        }
    }
    return out
}
