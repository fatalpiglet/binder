; ╔══════════════════════════════════════════════════════════════╗
; ║  Doctor Binder v2.1 — модуль: filters                       ║
; ║  Фильтры биндов                                 ║
; ╚══════════════════════════════════════════════════════════════╝
; ВНИМАНИЕ: этот файл — МОДУЛЬ. Не запускайте его отдельно,
; он подключается через #Include из google.ahk
;
InitDefaultFilters() {
    global FILTERS
    FILTERS := Map(
        "Все", Map("name", "Все", "builtin", true, "condition", ""),
        "Основные", Map("name", "Основные", "builtin", true, "condition", "category=Основные"),
        "Лечение", Map("name", "Лечение", "builtin", true, "condition", "category=Лечение"),
        "Медосмотр", Map("name", "Медосмотр", "builtin", true, "condition", "category=Медосмотр"),
        "Вакцины", Map("name", "Вакцины", "builtin", true, "condition", "category=Вакцины"),
        "Операции", Map("name", "Операции", "builtin", true, "condition", "category=Операции"),
        "Быстрые", Map("name", "Быстрые", "builtin", true, "condition", "category=Быстрые"),
        "Утилиты", Map("name", "Утилиты", "builtin", true, "condition", "category=Утилиты"),
        "Активные", Map("name", "Активные", "builtin", true, "condition", "enabled=true"),
        "Пустые", Map("name", "Пустые", "builtin", true, "condition", "empty=true")
    )
    LoadCustomFilters()
}

LoadCustomFilters() {
    global FILTERS, FILTERS_FILE
    if !FileExist(FILTERS_FILE)
        return
    try {
        count := Integer(IniRead(FILTERS_FILE, "Filters", "count", 0))
        Loop count {
            name := IniRead(FILTERS_FILE, "Filter" A_Index, "name", "")
            condition := IniRead(FILTERS_FILE, "Filter" A_Index, "condition", "")
            if name != ""
                FILTERS[name] := Map("name", name, "builtin", false, "condition", condition)
        }
    }
}

SaveCustomFilters() {
    global FILTERS, FILTERS_FILE
    customCount := 0
    for name, filter in FILTERS {
        if !filter["builtin"] {
            customCount++
            IniWrite(filter["name"], FILTERS_FILE, "Filter" customCount, "name")
            IniWrite(filter["condition"], FILTERS_FILE, "Filter" customCount, "condition")
        }
    }
    IniWrite(customCount, FILTERS_FILE, "Filters", "count")
}


ShowFilterMenu(*) {
    global FilterMenuGui, CurrentFilter, FILTERS, THEME, MainGui
    
    try {
        if FilterMenuGui {
            CleanupHoverButtons(FilterMenuGui)
            FilterMenuGui.Destroy()
        }
    }
    
    FilterMenuGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" MainGui.Hwnd, "Filters")
    FilterMenuGui.BackColor := THEME["bg"]
    FilterMenuGui.MarginX := 0
    FilterMenuGui.MarginY := 0
  
    y := 12
    w := 240
    
    FilterMenuGui.SetFont("s10 bold", "Segoe UI")
    FilterMenuGui.AddText("x16 y" y " w" (w-32) " c" THEME["accent"] " BackgroundTrans", "Фильтры")
    y += 32
    
    FilterMenuGui.AddText("x12 y" y " w" (w-24) " h2 Background" THEME["borderGlow"], "")
    y += 10
    
    FilterMenuGui.SetFont("s9 norm", "Segoe UI")
    
    filterItems := []
    
    for name, filter in FILTERS {
        isSelected := (name = CurrentFilter || (CurrentFilter = "" && name = "Все"))
        bgColor := isSelected ? THEME["bgSelected"] : THEME["bg"]
        textColor := filter["builtin"] ? THEME["text"] : THEME["success"]
        
        (filterName := name)
        
        rowBtn := CreateStyledButton(FilterMenuGui, 8, y+2, w-16, 28,
            (filter["builtin"] ? "" : "* ") name,
            ((fn) => (*) => ApplyFilterFromMenu(fn))(filterName), "default")
        rowBtn.SetVisual(isSelected ? THEME["bgSelected"] : THEME["bgLight"],
            isSelected ? THEME["accent"] : textColor, THEME["bgHover"])
        row := rowBtn.ctrl
        txt := rowBtn.ctrl
        
        filterItems.Push(Map(
            "row", row,
            "txt", txt,
            "isSelected", isSelected,
            "normalBg", bgColor,
            "hoverBg", THEME["bgHover"],
            "textColor", textColor,
            "button", rowBtn
        ))
        
        y += 32
    }
    
    y += 10
    FilterMenuGui.AddText("x12 y" y " w" (w-24) " h2 Background" THEME["borderGlow"], "")
    y += 14
    
    ; ✅ Используем класс StyledBtn вместо несуществующей функции
    StyledBtn(FilterMenuGui, 16, y, 100, 36, "Создать", (*) => (FilterMenuGui.Destroy(), CreateNewFilter()), "success")
    StyledBtn(FilterMenuGui, 124, y, 100, 36, "Изменить", (*) => (FilterMenuGui.Destroy(), EditFilters()), "default")
    y += 48
    
    FilterMenuGui.OnEvent("Close", (*) => (CleanupHoverButtons(FilterMenuGui), FilterMenuGui.Destroy()))
    
    try {
        MainGui.GetPos(&gx, &gy)
        FilterMenuGui.Show("x" (gx + 30) " y" (gy + 570) " w" w " h" y)
    } catch {
        FilterMenuGui.Show("w" w " h" y)
    }
}

ApplyFilterFromMenu(filterName) {
    global FilterMenuGui, CurrentFilter, CurrentPage  ; ✅ ВСЕ НУЖНЫЕ ПЕРЕМЕННЫЕ
    
    try FilterMenuGui.Destroy()
    
    CurrentFilter := (filterName = "Все") ? "" : filterName
    CurrentPage := 1
    RefreshBindList()
}

CreateNewFilter() {
    global FILTERS, THEME, MainGui
    
    filterGui := Gui("+AlwaysOnTop +Owner" MainGui.Hwnd, "Создать фильтр")
    filterGui.BackColor := THEME["bg"]
    filterGui.SetFont("s10 c" THEME["text"], THEME["fontFamily"])
    
    CreateFieldLabel(filterGui, 20, 20, 100, "НАЗВАНИЕ")
    CreateInput(filterGui, 20, 38, 320, THEME["inputH"], "vNewFilterName", "", 10, THEME["bg"])

    CreateFieldLabel(filterGui, 20, 84, 100, "УСЛОВИЕ")
    CreateInput(filterGui, 20, 102, 320, THEME["inputH"], "vNewFilterCondition", "category=", 10, THEME["bg"])
    
    filterGui.SetFont("s8", THEME["fontFamily"])
    filterGui.AddText("x20 y144 w320 c" THEME["textMuted"] " BackgroundTrans", "Примеры: category=Лечение, enabled=true")

    filterGui.SetFont("s9", THEME["fontFamily"])
    CreateStyledButton(filterGui, 20, 174, 150, 38, "Создать", (*) => SaveNewFilter(filterGui), "primary").SetBackdrop(THEME["bg"])
    CreateStyledButton(filterGui, 190, 174, 150, 38, "Отмена", (*) => filterGui.Destroy(), "default").SetBackdrop(THEME["bg"])

    filterGui.Show("w360 h230")
}

SaveNewFilter(gui) {
    global FILTERS
    
    name := gui["NewFilterName"].Value
    condition := gui["NewFilterCondition"].Value
    
    if name = "" {
        ShowNotify("Введите название", "error")
        return
    }
    
    FILTERS[name] := Map("name", name, "builtin", false, "condition", condition)
    SaveCustomFilters()
    gui.Destroy()
    ShowNotify("Фильтр создан!", "success")
}

EditFilters() {
    global FILTERS, THEME, FilterEditorGui, MainGui
    
    try FilterEditorGui.Destroy()
    
    FilterEditorGui := Gui("-Resize +Owner" MainGui.Hwnd, "Редактор фильтров")
    FilterEditorGui.BackColor := THEME["bg"]
    FilterEditorGui.SetFont("s10 c" THEME["text"], "Segoe UI")
    
    FilterEditorGui.AddText("x20 y15 w300 c" THEME["accent"] " BackgroundTrans", "★ — пользовательские фильтры")
    
    lv := FilterEditorGui.AddListView("x20 y45 w460 h310 Background" THEME["bgLight"] " c" THEME["text"] " vFilterList Grid", 
        ["Название", "Условие", "Тип"])
    lv.ModifyCol(1, 130)
    lv.ModifyCol(2, 220)
    lv.ModifyCol(3, 100)
    
    for name, filter in FILTERS {
        typeText := filter["builtin"] ? "Встроенный" : "★ Свой"
        lv.Add("", filter["name"], filter["condition"], typeText)
    }
    
    CreateStyledButton(FilterEditorGui, 20, 370, 110, 36, "Создать", (*) => CreateNewFilter(), "success")
    CreateStyledButton(FilterEditorGui, 140, 370, 110, 36, "Удалить", (*) => DeleteSelectedFilter(), "danger")
    CreateStyledButton(FilterEditorGui, 260, 370, 110, 36, "Закрыть", (*) => FilterEditorGui.Destroy(), "default")
    
    FilterEditorGui.Show("w500 h425")
}

DeleteSelectedFilter() {
    global FilterEditorGui, FILTERS
    
    row := FilterEditorGui["FilterList"].GetNext()
    if row = 0 {
        ShowNotify("Выберите фильтр", "warning")
        return
    }
    
    name := FilterEditorGui["FilterList"].GetText(row, 1)
    
    if FILTERS.Has(name) && FILTERS[name]["builtin"] {
        ShowNotify("Нельзя удалить встроенный фильтр", "error")
        return
    }
    
    FILTERS.Delete(name)
    SaveCustomFilters()
    FilterEditorGui["FilterList"].Delete(row)
    ShowNotify("Фильтр удалён", "success")
}

; ═══════════════════════════════════════════════════════════════════════════════
; ЗАГРУЗКА ПРОФИЛЕЙ
; ═══════════════════════════════════════════════════════════════════════════════
ShowModernFilterMenu(*) {
    global MainGui, FilterPopupGui, THEME, btnFilterDisplay, CurrentFilter
    
    if FilterPopupGui {
        CleanupHoverButtons(FilterPopupGui)
        FilterPopupGui.Destroy()
        FilterPopupGui := ""
        return
    }
    
    try {
        ; Получаем абсолютные координаты окна на экране
        WinGetPos(&winX, &winY, , , MainGui.Hwnd)
        
        ; Получаем позицию кнопки внутри окна
        ControlGetPos(&btnX, &btnY, &btnW, &btnH, btnFilterDisplay.ctrl.Hwnd)
        
        ; Клиентская область (без заголовка) начинается ниже
        ; Стандартный заголовок ~30-40px + рамка ~8px
        ; Но у нас кастомный заголовок, так что просто подбираем:
        
        menuX := winX + btnX + 1  ; Отступ слева (рамка окна)
        menuY := winY + btnY + btnH + 2  ; Прямо под кнопкой
        
    } catch {
        return
    }
    
    FilterPopupGui := Gui("-Caption +AlwaysOnTop +ToolWindow +Owner" MainGui.Hwnd, "FilterMenu")
    FilterPopupGui.BackColor := THEME["surface"]
    FilterPopupGui.SetFont("s9", THEME["fontFamily"])

    filters := ["Все", "Основные", "Лечение", "Медосмотр", "Вакцины", "Операции", "Быстрые", "Утилиты", "Активные"]
    current := CurrentFilter = "" ? "Все" : CurrentFilter

    w := 250
    hItem := 32
    y := 4

    for filterName in filters {
        isActive := (filterName = current)
        btn := CreateStyledButton(FilterPopupGui, 4, y, w-8, hItem-4,
            filterName = "Все" ? "Все бинды" : filterName,
            ((fn) => (*) => ApplyModernFilter(fn))(filterName), "default")
        btn.SetBackdrop(THEME["surface"])
        ; Активная строка: cyan-текст + мягкая подсветка, без ярких заливок
        if isActive
            btn.SetVisual(THEME["bgSelected"], THEME["accent"], THEME["bgSelected"], THEME["accentDark"], THEME["accent"])
        else
            btn.SetVisual(THEME["surface"], THEME["textDim"], THEME["bgHover"], THEME["surface"])
        btn.SetLayout("left", isActive ? "•" : "")
        btn.ctrl.SetFont("s9" (isActive ? " bold" : " norm"), THEME["fontFamily"])
        y += hItem
    }

    FilterPopupGui.Show("x" menuX " y" menuY " w" w " h" (y + 4) " NA")
}

ApplyModernFilter(name) {
    global FilterPopupGui, btnFilterDisplay
    
    if FilterPopupGui {
        CleanupHoverButtons(FilterPopupGui)
        FilterPopupGui.Destroy()
        FilterPopupGui := ""
    }
    
    btnFilterDisplay.ctrl.Text := name = "Все" ? "Все бинды" : name
    RefreshBindList(name)
}

CheckFilterMenuFocus() {
    global FilterPopupGui
    
    if !FilterPopupGui {
        SetTimer(CheckFilterMenuFocus, 0)
        return
    }
    
    ; Если мышь кликнула не в меню
    if !WinActive("ahk_id " FilterPopupGui.Hwnd) && !WinActive("ahk_id " MainGui.Hwnd) {
        ; Но даем время на клик
        MouseGetPos(,, &winId)
        if (winId != FilterPopupGui.Hwnd) {
             ; Можно закрывать, но лучше просто по клику на элемент
        }
    }
}

; Обработчик клика для закрытия меню фильтров
