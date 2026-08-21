# Doctor Binder — Design System (v2.1 «Dark Premium / Medical Enterprise»)

Единый источник правды по интерфейсу. Все токены живут в `lib/02_Globals.ahk`
(`THEME`), все базовые компоненты — в `lib/03_UI.ahk`.

> Правило пропорций: **~90 %** тёмные поверхности, **~7 %** серо-синий,
> **~3 %** cyan. Cyan — это **сигнал состояния или действия**, а не украшение.
> Если убрать все свечения, интерфейс всё равно должен выглядеть хорошо.

---

## 1. Токены цвета

| Токен | HEX | Назначение |
|---|---|---|
| `bg` | `#080A0F` | фон приложения |
| `surface` / `card` / `bgLight` | `#0D1016` | шапка, навигация, карточки |
| `bgElevated` / `bgHighlight` | `#111722` | приподнятые блоки, плитки, шапки таблиц |
| `bgHover` / `surfaceHover` | `#151D28` | поверхность под курсором |
| `bgSelected` | `#0F1E29` | активный пункт навигации (cyan-tinted) |
| `field` / `fieldBg` | `#0D141D` | фон поля ввода |
| `fieldBorder` | `#202D3B` | рамка поля ввода |
| `border` | `#202833` | рамки карточек, разделители |
| `borderLight` | `#344252` | рамка при наведении |
| `text` | `#F2F4F7` | основной текст |
| `textDim` | `#9AA4B2` | вторичный текст |
| `textMuted` | `#626D7B` | подписи, LABEL, метаданные |
| `accent` | `#38BDF8` | акцент (фокус, активное, primary) |
| `accentSoft` | `#103746` | мягкая cyan-подложка / focus glow |
| `accentDark` | `#1C5F7D` | cyan-рамка активных элементов |
| `success` | `#35C98A` | READY / ACTIVE / SAVED |
| `warning` | `#D9A75C` | UNSAVED CHANGES |
| `error` | `#E66B83` | ERROR / удаление |

## 2. Геометрия и типографика

```
radiusSm 6   radius 10   radiusLg 12
inputH 34    btnH 38     btnHSm 30    cardPad 18    navH 30

App title      s14 bold     Page title   s13 bold
Card title     s10 bold     Label        s7 bold (UPPERCASE, muted)
Main value     s16–s20      Secondary    s8–s9
```

Шрифт: `Segoe UI Variable Text` с автоматическим откатом на `Segoe UI`
(`ResolveUIFont()` в `03_UI.ahk` проверяет наличие семейства через GDI).
Моноширинный (`Consolas`) — только для ID, хоткеев и технических значений.

## 3. Компоненты (`lib/03_UI.ahk`)

| Компонент | Функция | Комментарий |
|---|---|---|
| Кнопка | `CreateStyledButton(gui,x,y,w,h,text,cb,style,tip)` | owner-draw (WM_DRAWITEM), скругление, hover/pressed, опциональное свечение |
| Стили кнопок | `default` `primary` `danger` `warning` `info` `icon` `ghost` | по умолчанию — тёмная поверхность + тонкая рамка + светлый текст |
| Левое выравнивание + глиф | `btn.SetLayout("left", "→")` | action-панель «Быстрое управление» |
| Подложка под кнопкой | `btn.SetBackdrop(THEME["card"])` | чистые скруглённые углы поверх карточки |
| Свечение | `btn.SetGlow(THEME["accent"])` | 2 контурных кольца, очень мягко |
| Поле ввода | `CreateInput(gui,x,y,w,h,options,value,fontSize,backdrop,accentText)` | glow-ring → рамка → поверхность → Edit **без** `WS_EX_CLIENTEDGE` |
| Подпись поля | `CreateFieldLabel(gui,x,y,w,"NAME")` | 9–10px, uppercase, muted |
| Карточка | `CreateCard(gui,x,y,w,h,radius)` | рамка 1px + поверхность |
| Заголовок карточки | `CreateCardHeader(gui,x,y,w,"ЛИЧНОЕ ДЕЛО","01")` | название + системный номер + разделитель |
| Статус | `StatusDot(gui,x,y,text,color,backdrop)` + `.Set(text,color)` | маленькая точка с мягким гало |
| Чекбокс | `StyleCheckbox(ctrl)` | тёмная тема Windows для стандартного контрола |

### Состояния полей ввода

```
обычное : bg #0D141D   border #202D3B
hover   : border #344252
focus   : border #38BDF8 + очень мягкое cyan-кольцо (2px)
```

### Единая система состояний

```
● SYSTEM READY        success   шапка приложения
● ACTIVE              success   пациент принят
○ WAITING FOR PATIENT dim       пациент не задан
● ERROR               error     некорректный ID
● PROFILE SAVED       success   профиль актуален
● UNSAVED CHANGES     warning   есть несохранённые изменения
● ALL CHANGES SAVED   success   всё сохранено
```

## 4. Правила

* Cyan — только: активная вкладка, фокус поля, primary-кнопка, активный статус.
* Никаких больших залитых badge, градиентов, glassmorphism и «таблеток».
* Иконки — монохромные, muted; cyan только когда элемент активен.
* Переходы — мгновенные состояния (hover/focus/pressed ≈ 110 мс).
* Лучше whitespace, чем декоративный виджет.

## 5. Предпросмотр

`docs/index.html` — статический HTML-макет главного экрана в тех же токенах.
Он не участвует в работе скрипта, нужен только для визуальной сверки дизайна
(например, когда AutoHotkey под рукой нет).
