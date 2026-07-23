-- GUI.lua
-- Библиотека GUI для MM2 скрипта — редизайн «Violite v2»
-- Сайдбар вместо ленты табов, секции-контейнеры со строками, футер-статусбар.
-- Публичный API совместим со старой версией, все колбэки — через env.Handlers.

return function(env)
    local CONFIG = env.CONFIG
    local State = env.State
    local Players = env.Players
    local CoreGui = env.CoreGui
    local TweenService = env.TweenService
    local UserInputService = env.UserInputService
    local LocalPlayer = env.LocalPlayer
    local TrackConnection = env.TrackConnection
    local ShowNotification = env.ShowNotification
    local Handlers = env.Handlers

    local GUI = {}

    ----------------------------------------------------------------
    -- ТОКЕНЫ ДИЗАЙНА (поверх CONFIG.Colors)
    ----------------------------------------------------------------
    -- Нейтральная цинковая шкала — строгий монохром, акцент только на состояниях
    local T = {
        Canvas    = Color3.fromRGB(9, 9, 11),
        Surface1  = Color3.fromRGB(19, 19, 22),
        Surface2  = Color3.fromRGB(31, 31, 35),
        HairCol   = Color3.fromRGB(255, 255, 255),
        HairTrans = 0.90,
        Text      = Color3.fromRGB(237, 237, 240),
        TextDark  = Color3.fromRGB(140, 140, 148),
        Accent    = CONFIG.Colors.Accent,
        AccentInk = Color3.fromRGB(15, 15, 17),   -- тёмный текст на акцентной заливке
        Danger    = CONFIG.Colors.Red,
        TrackBg   = Color3.fromRGB(45, 45, 50),   -- фон трека слайдера / выкл. тогла
    }

    -- Шрифты — та же пара, что в Scripts/Notify.lua: на мелких кеглях
    -- GothamSemibold/GothamMedium растрируются заметно мягче, чем GothamBold,
    -- а Enum.Font.Code (пиксельный моноширинный) убран совсем — именно он
    -- давал «квадратный» вид значениям и статусбару.
    local FONT = {
        Bold = Enum.Font.GothamSemibold, -- названия фич, заголовки, кнопки
        Body = Enum.Font.GothamMedium,   -- описания, второстепенный текст
        Mono = Enum.Font.GothamMedium,   -- значения, чипы, статусбар
    }

    -- Единая шкала кеглей. Меняется только здесь — по месту цифры не пишем
    local TS = {
        Logo      = 18,   -- «Violite»
        LogoSub   = 12,   -- «mm2»
        TabTitle  = 16,   -- заголовок вкладки в хедере
        Nav       = 14,   -- пункты сайдбара
        Section   = 12,   -- заголовки секций (CAPS)
        Title     = 14,   -- название строки
        Desc      = 12,   -- описание строки
        Button    = 13,   -- кнопки, дропдауны, кейбинд-кнопки
        Value     = 13,   -- значения в полях ввода
        Chip      = 12,   -- узкие чипы бинда
        Status    = 12,   -- футер-статусбар
        Option    = 12,   -- пункты выпадающих списков
        Search    = 13,   -- поле поиска
    }

    -- Единый вертикальный ритм строк и правых контролов
    local ROW_H       = 46   -- строка без описания
    local ROW_H_DESC  = 60   -- строка с описанием
    local CTRL_H      = 28   -- высота дропдаунов/кнопок/полей ввода
    local EDGE        = 14   -- отступ контролов от правого края строки

    -- Единственное место с прозрачностью — корневой фрейм окна
    local ROOT_TRANSPARENCY = 0.06

    local SIDEBAR_W  = 188
    local HEADER_H   = 48
    local FOOTER_H   = 28

    ----------------------------------------------------------------
    -- ХЕЛПЕРЫ UI (БЛОК 19)
    ----------------------------------------------------------------

    local function Create(className, properties, children)
        local obj = Instance.new(className)
        for k, v in pairs(properties or {}) do
            obj[k] = v
        end
        for _, child in ipairs(children or {}) do
            child.Parent = obj
        end
        return obj
    end

    local function AddCorner(parent, radius)
        return Create("UICorner", {CornerRadius = UDim.new(0, radius), Parent = parent})
    end

    local function AddStroke(parent, thickness, color, transparency)
        return Create("UIStroke", {
            Thickness = thickness or 1,
            Color = color or T.HairCol,
            Transparency = transparency or T.HairTrans,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = parent
        })
    end

    -- Горизонтальный hairline-разделитель
    local function Hairline(props)
        props = props or {}
        props.BackgroundColor3 = T.HairCol
        props.BackgroundTransparency = T.HairTrans
        props.BorderSizePixel = 0
        return Create("Frame", props)
    end

    ----------------------------------------------------------------
    -- ГЛИФ-ФАБРИКИ: рисованные значки вместо текстовых символов.
    -- ✕, ▾, ↘ отсутствуют в Gotham/Code и рендерятся «тофу»-квадратами,
    -- поэтому все такие глифы собираются из Frame/UIStroke.
    ----------------------------------------------------------------

    -- Заполненная линия/точка (штрих глифа)
    local function glyphLine(parent, x, y, w, h, rot, corner)
        local f = Create("Frame", {
            BackgroundColor3 = T.TextDark,
            BorderSizePixel = 0,
            Position = UDim2.new(0, x, 0, y),
            Size = UDim2.new(0, w, 0, h),
            Rotation = rot or 0,
            ZIndex = parent.ZIndex or 1,
            Parent = parent
        })
        if corner then AddCorner(f, corner) end
        return f
    end

    -- Контур (кольцо/рамка) — возвращает фрейм и его UIStroke
    local function glyphRing(parent, x, y, w, h, corner, thickness)
        local f = Create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, x, 0, y),
            Size = UDim2.new(0, w, 0, h),
            ZIndex = parent.ZIndex or 1,
            Parent = parent
        })
        AddCorner(f, corner)
        local s = Create("UIStroke", {
            Thickness = thickness or 1.2,
            Color = T.TextDark,
            Transparency = 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = f
        })
        return f, s
    end

    -- Крест «✕» по центру родителя: два штриха 1.4x12 под ±45°.
    -- Возвращает список штрихов, чтобы их можно было перекрасить на hover.
    local function glyphCross(parent)
        local strokes = {}
        for _, rot in ipairs({45, -45}) do
            local f = Create("Frame", {
                BackgroundColor3 = T.TextDark,
                BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 1.4, 0, 12),
                Rotation = rot,
                ZIndex = (parent.ZIndex or 1) + 1,
                Parent = parent
            })
            table.insert(strokes, f)
        end
        return strokes
    end

    -- Шеврон-уголок вниз «▾» у правого края родителя: два штриха 1.4x6 под ±45°.
    -- padRight компенсирует UIPadding родителя: дети живут в уже сжатой
    -- области, поэтому холдер надо вернуть обратно к реальному краю кнопки.
    local function glyphChevron(parent, padRight)
        local z = (parent.ZIndex or 1) + 1
        local holder = Create("Frame", {
            Name = "Chevron",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, (padRight or 0) - 10, 0.5, 0),
            Size = UDim2.new(0, 10, 0, 10),
            ZIndex = z,
            Parent = parent
        })
        -- центры штрихов — (2.88, 5) и (7.12, 5), сходятся внизу по центру
        local a = glyphLine(holder, 2.18, 2, 1.4, 6, -45)
        local b = glyphLine(holder, 6.42, 2, 1.4, 6, 45)
        a.ZIndex, b.ZIndex = z, z
        return holder, a, b
    end

    -- Уголок ресайза «↘»: две параллельные диагонали в правом нижнем углу
    local function glyphResizeCorner(parent)
        local z = (parent.ZIndex or 1)
        local a = glyphLine(parent, 10.5, 6.5, 1, 9, 45)
        local b = glyphLine(parent, 13.5, 11.5, 1, 5, 45)
        a.ZIndex, b.ZIndex = z, z
        return a, b
    end

    ----------------------------------------------------------------
    -- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ИЗ MAIN (через Handlers)
    ----------------------------------------------------------------

    local function callHandler(name, ...)
        local fn = Handlers[name]
        if fn then
            fn(...)
        end
    end

    local function getAllPlayers()
        local list = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                table.insert(list, plr.Name)
            end
        end
        table.sort(list)
        return list
    end

    -- Пинг для статусбара (набор Stats отличается между executor'ами — всё в pcall)
    local function probePingMs()
        local ms
        local okItem, item = pcall(function()
            return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]
        end)
        if okItem and item then
            local okStr, s = pcall(function() return item:GetValueString() end)
            if okStr and s and tonumber(s) then
                ms = tonumber(s)
            else
                local okVal, v = pcall(function() return item:GetValue() end)
                if okVal and typeof(v) == "number" then ms = v end
            end
        end
        return ms
    end

    ----------------------------------------------------------------
    -- СОЗДАНИЕ UI (БЛОК 20 → CreateUI, TabFunctions и т.д.)
    ----------------------------------------------------------------

    local function CreateUI()
        for _, child in ipairs(CoreGui:GetChildren()) do
            if child.Name == "MM2_ESP_UI" then child:Destroy() end
        end

        local gui = Create("ScreenGui", {
            Name = "MM2_ESP_UI",
            Parent = CoreGui
        })
        State.UIElements.MainGui = gui

        local mainFrame = Create("Frame", {
            Name = "MainFrame",
            BackgroundColor3 = T.Canvas,
            BackgroundTransparency = ROOT_TRANSPARENCY,
            Position = UDim2.new(0.5, -460, 0.5, -320),
            Size = UDim2.new(0, 920, 0, 640),
            ClipsDescendants = false,
            Active = true,
            Parent = gui
        })
        AddCorner(mainFrame, 10)
        AddStroke(mainFrame, 1, T.HairCol, 0.88)

        ----------------------------------------------------------------
        -- САЙДБАР: логотип + вертикальная навигация вкладок
        ----------------------------------------------------------------

        local sidebar = Create("Frame", {
            Name = "Sidebar",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0, SIDEBAR_W, 1, 0),
            Parent = mainFrame
        })

        Hairline({
            Name = "SidebarSep",
            Position = UDim2.new(0, SIDEBAR_W, 0, 0),
            Size = UDim2.new(0, 1, 1, 0),
            Parent = mainFrame
        })

        Create("TextLabel", {
            Name = "LogoName",
            Text = "Violite",
            Font = FONT.Bold,
            TextSize = TS.Logo,
            TextColor3 = T.Accent,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 18, 0, 15),
            Size = UDim2.new(0, 150, 0, 22),
            Parent = sidebar
        })

        Create("TextLabel", {
            Name = "LogoSub",
            Text = "mm2",
            Font = FONT.Body,
            TextSize = TS.LogoSub,
            TextColor3 = T.TextDark,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 18, 0, 37),
            Size = UDim2.new(0, 150, 0, 16),
            Parent = sidebar
        })

        local navScroll = Create("ScrollingFrame", {
            Name = "NavScroll",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 62),
            Size = UDim2.new(0, SIDEBAR_W - 20, 1, -100),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 0,
            BorderSizePixel = 0,
            Parent = sidebar
        })

        local navLayout = Create("UIListLayout", {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = navScroll
        })
        navLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            navScroll.CanvasSize = UDim2.new(0, 0, 0, navLayout.AbsoluteContentSize.Y + 4)
        end)

        -- Личная подпись внизу сайдбара — переехала из заголовка старой версии
        Create("TextLabel", {
            Name = "Dedication",
            Text = "for my кошичка жена",
            Font = FONT.Body,
            TextSize = TS.LogoSub,
            TextColor3 = Color3.fromRGB(220, 145, 230),
            TextTransparency = 0.35,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 18, 1, -26),
            Size = UDim2.new(0, 160, 0, 16),
            Parent = sidebar
        })

        ----------------------------------------------------------------
        -- ХЕДЕР: название вкладки, поиск, закрытие. Драг окна — за хедер
        ----------------------------------------------------------------

        local header = Create("Frame", {
            Name = "Header",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, SIDEBAR_W + 1, 0, 0),
            Size = UDim2.new(1, -(SIDEBAR_W + 1), 0, HEADER_H),
            Active = true,
            Parent = mainFrame
        })

        local tabTitle = Create("TextLabel", {
            Name = "TabTitle",
            Text = "",
            Font = FONT.Bold,
            TextSize = TS.TabTitle,
            TextColor3 = T.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 18, 0, 0),
            Size = UDim2.new(0, 300, 1, 0),
            Parent = header
        })

        local searchBox = Create("TextBox", {
            Name = "SearchBox",
            PlaceholderText = "Search...",
            Text = "",
            Font = FONT.Body,
            TextSize = TS.Search,
            TextColor3 = T.Text,
            PlaceholderColor3 = T.TextDark,
            BackgroundColor3 = T.Surface2,
            Position = UDim2.new(1, -278, 0.5, -15),
            Size = UDim2.new(0, 220, 0, 30),
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            Parent = header,
        })
        AddCorner(searchBox, 6)
        AddStroke(searchBox, 1, T.HairCol, T.HairTrans)
        Create("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = searchBox})

        local closeButton = Create("TextButton", {
            Text = "",
            BackgroundColor3 = T.Danger,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -44, 0.5, -15),
            Size = UDim2.new(0, 30, 0, 30),
            AutoButtonColor = false,
            Parent = header
        })
        AddCorner(closeButton, 6)
        local closeStrokes = glyphCross(closeButton)

        Hairline({
            Name = "HeaderSep",
            Position = UDim2.new(0, SIDEBAR_W + 1, 0, HEADER_H),
            Size = UDim2.new(1, -(SIDEBAR_W + 1), 0, 1),
            Parent = mainFrame
        })

        ----------------------------------------------------------------
        -- КОНТЕНТ (страницы вкладок) + ФУТЕР-СТАТУСБАР
        ----------------------------------------------------------------

        local pagesContainer = Create("Frame", {
            Name = "PagesContainer",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, SIDEBAR_W + 15, 0, HEADER_H + 13),
            Size = UDim2.new(1, -(SIDEBAR_W + 29), 1, -(HEADER_H + 13 + FOOTER_H + 13)),
            Parent = mainFrame
        })

        Hairline({
            Name = "FooterSep",
            Position = UDim2.new(0, SIDEBAR_W + 1, 1, -(FOOTER_H + 1)),
            Size = UDim2.new(1, -(SIDEBAR_W + 1), 0, 1),
            Parent = mainFrame
        })

        local footer = Create("Frame", {
            Name = "Footer",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, SIDEBAR_W + 1, 1, -FOOTER_H),
            Size = UDim2.new(1, -(SIDEBAR_W + 1), 0, FOOTER_H),
            Parent = mainFrame
        })

        -- Чип роли: скрыт, пока MainScript не отдаст Handlers.GetRole
        local roleChip = Create("Frame", {
            Name = "RoleChip",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 14, 0, 0),
            Size = UDim2.new(0, 140, 1, 0),
            Visible = false,
            Parent = footer
        })
        local roleDot = Create("Frame", {
            BackgroundColor3 = T.TextDark,
            Position = UDim2.new(0, 0, 0.5, -3),
            Size = UDim2.new(0, 6, 0, 6),
            BorderSizePixel = 0,
            Parent = roleChip
        })
        AddCorner(roleDot, 3)
        local roleText = Create("TextLabel", {
            Text = "",
            Font = FONT.Mono,
            TextSize = TS.Status,
            TextColor3 = T.TextDark,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 0),
            Size = UDim2.new(0, 120, 1, 0),
            Parent = roleChip
        })

        local pingLabel = Create("TextLabel", {
            Text = "Ping: -- ms",
            Font = FONT.Mono,
            TextSize = TS.Status,
            TextColor3 = T.TextDark,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, -110, 0, 0),
            Size = UDim2.new(0, 220, 1, 0),
            Parent = footer
        })

        Create("TextLabel", {
            Text = "Toggle: " .. CONFIG.HideKey.Name,
            Font = FONT.Mono,
            TextSize = TS.Status,
            TextColor3 = T.TextDark,
            TextXAlignment = Enum.TextXAlignment.Right,
            BackgroundTransparency = 1,
            -- правая граница -36, чтобы не залезать под уголок ресайза
            Position = UDim2.new(1, -196, 0, 0),
            Size = UDim2.new(0, 160, 1, 0),
            Parent = footer
        })

        -- Раз в секунду обновляем пинг и роль; цикл умирает вместе с gui
        local roleColorMap = {
            Murderer = CONFIG.Colors.Murder,
            Murder   = CONFIG.Colors.Murder,
            Sheriff  = CONFIG.Colors.Sheriff,
            Innocent = CONFIG.Colors.Innocent,
        }
        task.spawn(function()
            while gui and gui.Parent do
                pcall(function()
                    local ms = probePingMs()
                    pingLabel.Text = ms and string.format("Ping: %d ms", ms) or "Ping: -- ms"

                    local getRole = Handlers.GetRole
                    if getRole then
                        local ok, role = pcall(getRole)
                        if ok and type(role) == "string" and role ~= "" then
                            local col = roleColorMap[role] or T.TextDark
                            roleChip.Visible = true
                            roleDot.BackgroundColor3 = col
                            roleText.Text = role:upper()
                            roleText.TextColor3 = col
                        else
                            roleChip.Visible = false
                        end
                    else
                        roleChip.Visible = false
                    end
                end)
                task.wait(1)
            end
        end)

        local Tabs = {}
        local currentTab = nil
        local sections = {}   -- {frame, layout, rows = {{row, sep, name, desc}, ...}}

        ----------------------------------------------------------------
        -- КАСТОМНЫЙ SCROLLBAR (thumb без родного track)
        ----------------------------------------------------------------
        local SCROLL_THUMB_COLOR = T.Accent
        local SCROLL_THUMB_TRANSPARENCY = 0.35
        local SCROLL_THUMB_WIDTH = 4

        local function AttachCustomScrollbar(scrollingFrame, container, anchorX)
            local thumb = Create("Frame", {
                Name = "CustomScrollbar",
                BackgroundColor3 = SCROLL_THUMB_COLOR,
                BackgroundTransparency = SCROLL_THUMB_TRANSPARENCY,
                BorderSizePixel = 0,
                Position = UDim2.new(anchorX.Scale, anchorX.Offset, 0, 0),
                Size = UDim2.new(0, SCROLL_THUMB_WIDTH, 0, 30),
                Visible = false,
                ZIndex = 10,
                Parent = container
            })
            AddCorner(thumb, 2)

            local function update()
                local canvasH = scrollingFrame.CanvasSize.Y.Offset
                local viewH = scrollingFrame.AbsoluteSize.Y
                if canvasH <= viewH or viewH <= 0 then
                    thumb.Visible = false
                    return
                end
                thumb.Visible = true
                local thumbH = math.max(20, viewH * (viewH / canvasH))
                local maxScroll = canvasH - viewH
                local scrollRatio = maxScroll > 0 and (scrollingFrame.CanvasPosition.Y / maxScroll) or 0
                local thumbY = scrollRatio * (viewH - thumbH)
                thumb.Size = UDim2.new(0, SCROLL_THUMB_WIDTH, 0, thumbH)
                thumb.Position = UDim2.new(anchorX.Scale, anchorX.Offset, 0, thumbY)
            end

            TrackConnection(scrollingFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(update))
            TrackConnection(scrollingFrame:GetPropertyChangedSignal("CanvasSize"):Connect(update))
            TrackConnection(scrollingFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))

            local dragging = false
            local dragStartMouseY = 0
            local dragStartCanvasY = 0

            thumb.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    dragStartMouseY = UserInputService:GetMouseLocation().Y
                    dragStartCanvasY = scrollingFrame.CanvasPosition.Y
                end
            end)

            TrackConnection(UserInputService.InputChanged:Connect(function(input)
                if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    local canvasH = scrollingFrame.CanvasSize.Y.Offset
                    local viewH = scrollingFrame.AbsoluteSize.Y
                    local maxScroll = canvasH - viewH
                    if maxScroll <= 0 then return end
                    local thumbH = math.max(20, viewH * (viewH / canvasH))
                    local trackH = viewH - thumbH
                    if trackH <= 0 then return end
                    local deltaY = UserInputService:GetMouseLocation().Y - dragStartMouseY
                    local newCanvasY = math.clamp(dragStartCanvasY + (deltaY / trackH) * maxScroll, 0, maxScroll)
                    scrollingFrame.CanvasPosition = Vector2.new(0, newCanvasY)
                end
            end))

            TrackConnection(UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end))

            task.defer(update)
            return thumb
        end

        ----------------------------------------------------------------
        -- ПОИСК: фильтрация строк, скрытие пустых секций
        ----------------------------------------------------------------

        local function applySearch(query)
            local q = query:lower()
            for _, sec in ipairs(sections) do
                local anyVisible = false
                local firstShown = true
                for _, entry in ipairs(sec.rows) do
                    local vis = q == ""
                        or entry.name:find(q, 1, true) ~= nil
                        or entry.desc:find(q, 1, true) ~= nil
                    entry.row.Visible = vis
                    if entry.sep then
                        entry.sep.Visible = vis and not firstShown
                    end
                    if vis then
                        anyVisible = true
                        firstShown = false
                    end
                end
                sec.frame.Visible = anyVisible
            end
        end

        ----------------------------------------------------------------
        -- ЛИНЕЙНЫЕ ИКОНКИ ВКЛАДОК (16x16, собраны из Frame/UIStroke —
        -- без внешних ассетов, 1px-контуры в стиле lucide)
        ----------------------------------------------------------------

        local function makeTabIcon(tabName, parent)
            local holder = Create("Frame", {
                Name = "Icon",
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0.5, -8),
                Size = UDim2.new(0, 16, 0, 16),
                Parent = parent
            })

            local fills, strokes, labels = {}, {}, {}

            -- Обёртки над общими глиф-фабриками: складывают созданное
            -- в списки, чтобы setColor мог перекрасить иконку целиком
            local function line(x, y, w, h, rot, corner)
                local f = glyphLine(holder, x, y, w, h, rot, corner)
                table.insert(fills, f)
                return f
            end

            local function ring(x, y, w, h, corner)
                local f, s = glyphRing(holder, x, y, w, h, corner)
                table.insert(strokes, s)
                return f
            end

            -- Текстовый глиф внутри иконки (например «$» на монете)
            local function label(text, size)
                local l = Create("TextLabel", {
                    Text = text,
                    Font = FONT.Bold,
                    TextSize = size or 10,
                    TextColor3 = T.TextDark,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Parent = holder
                })
                table.insert(labels, l)
                return l
            end

            local n = tabName:lower()
            if n == "main" then
                -- сетка 2x2 (dashboard)
                ring(1, 1, 6, 6, 2)
                ring(9, 1, 6, 6, 2)
                ring(1, 9, 6, 6, 2)
                ring(9, 9, 6, 6, 2)
            elseif n == "aim" then
                -- мишень: два кольца и точка
                ring(1, 1, 14, 14, 7)
                ring(5, 5, 6, 6, 3)
                line(7, 7, 2, 2, 0, 1)
            elseif n == "combat" then
                -- прицел: кольцо + 4 риски
                ring(2, 2, 12, 12, 6)
                line(7, 0, 1, 3)
                line(7, 13, 1, 3)
                line(0, 7, 3, 1)
                line(13, 7, 3, 1)
            elseif n == "visuals" then
                -- глаз: пилюля-контур + зрачок
                ring(0, 4, 16, 8, 4)
                line(6, 6, 3, 3, 0, 2)
            elseif n == "farming" or n == "farm" then
                -- монета: кольцо + «$» по центру (прежние две прорези
                -- читались как значок «пауза»)
                ring(2, 2, 12, 12, 6)
                label("$", 10)
            elseif n == "fun" then
                -- искра: 4 луча из центра
                line(7, 1, 1, 14)
                line(1, 7, 14, 1)
                line(7, 2, 1, 12, 45)
                line(7, 2, 1, 12, -45)
            elseif n == "troll" then
                -- смайл: кольцо + глаза + рот
                ring(2, 2, 12, 12, 6)
                line(5, 6, 2, 2, 0, 1)
                line(9, 6, 2, 2, 0, 1)
                line(5, 10, 6, 1, 0, 1)
            elseif n == "settings" then
                -- слайдеры: 3 линии с бегунками
                line(2, 3, 12, 1)
                line(4, 1, 3, 4, 0, 1)
                line(2, 7, 12, 1)
                line(9, 5, 3, 4, 0, 1)
                line(2, 12, 12, 1)
                line(6, 10, 3, 4, 0, 1)
            else
                -- дефолт: рамка
                ring(2, 2, 12, 12, 3)
            end

            local function setColor(col)
                for _, f in ipairs(fills) do f.BackgroundColor3 = col end
                for _, s in ipairs(strokes) do s.Color = col end
                for _, l in ipairs(labels) do l.TextColor3 = col end
            end

            return setColor
        end

        ----------------------------------------------------------------
        -- ВНУТРЕННИЙ КОНСТРУКТОР ТАБА + TabFunctions
        ----------------------------------------------------------------

        local function CreateTab(name)
            local tabBtn = Create("TextButton", {
                Text = "",
                BackgroundColor3 = T.Surface1,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 36),
                AutoButtonColor = false,
                Parent = navScroll
            })
            AddCorner(tabBtn, 6)

            local setIconColor = makeTabIcon(name, tabBtn)

            local tabLabel = Create("TextLabel", {
                Text = name,
                Font = FONT.Bold,
                TextSize = TS.Nav,
                TextColor3 = T.TextDark,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 34, 0, 0),
                Size = UDim2.new(1, -38, 1, 0),
                Parent = tabBtn
            })

            local accentBar = Create("Frame", {
                Name = "AccentBar",
                BackgroundColor3 = T.Accent,
                Position = UDim2.new(0, 0, 0.5, -9),
                Size = UDim2.new(0, 3, 0, 18),
                BorderSizePixel = 0,
                Visible = false,
                Parent = tabBtn
            })
            AddCorner(accentBar, 2)

            -- Контейнер двух колонок для этой вкладки
            local pageHolder = Create("Frame", {
                Name = name .. "PageHolder",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Visible = false,
                Parent = pagesContainer
            })

            local leftPage = Create("ScrollingFrame", {
                Name = name .. "PageLeft",
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(0.5, -6, 1, 0),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 0,
                BorderSizePixel = 0,
                Parent = pageHolder
            })
            local leftLayout = Create("UIListLayout", {
                Padding = UDim.new(0, 12),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = leftPage
            })
            leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                leftPage.CanvasSize = UDim2.new(0, 0, 0, leftLayout.AbsoluteContentSize.Y + 20)
            end)
            AttachCustomScrollbar(leftPage, pageHolder, UDim.new(0.5, -2))

            local rightPage = Create("ScrollingFrame", {
                Name = name .. "PageRight",
                BackgroundTransparency = 1,
                Position = UDim2.new(0.5, 6, 0, 0),
                Size = UDim2.new(0.5, -6, 1, 0),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 0,
                BorderSizePixel = 0,
                Parent = pageHolder
            })
            local rightLayout = Create("UIListLayout", {
                Padding = UDim.new(0, 12),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = rightPage
            })
            rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                rightPage.CanvasSize = UDim2.new(0, 0, 0, rightLayout.AbsoluteContentSize.Y + 20)
            end)
            AttachCustomScrollbar(rightPage, pageHolder, UDim.new(1, 4))

            local currentPage = leftPage
            local currentSectionData = nil

            local function isActive()
                return currentTab ~= nil and currentTab.Btn == tabBtn
            end

            local function Activate()
                if State.UIElements.OpenDropdowns then
                    for _, closeFunc in ipairs(State.UIElements.OpenDropdowns) do
                        pcall(closeFunc)
                    end
                end
                if currentTab then
                    TweenService:Create(
                        currentTab.Btn,
                        TweenInfo.new(0.12, Enum.EasingStyle.Quad),
                        {BackgroundTransparency = 1}
                    ):Play()
                    currentTab.Label.TextColor3 = T.TextDark
                    currentTab.SetIcon(T.TextDark)
                    currentTab.Bar.Visible = false
                    currentTab.Holder.Visible = false
                end
                currentTab = {
                    Btn = tabBtn, Holder = pageHolder, Bar = accentBar,
                    Label = tabLabel, SetIcon = setIconColor
                }
                tabBtn.BackgroundColor3 = T.Surface2
                TweenService:Create(
                    tabBtn,
                    TweenInfo.new(0.12, Enum.EasingStyle.Quad),
                    {BackgroundTransparency = 0}
                ):Play()
                tabLabel.TextColor3 = T.Text
                setIconColor(T.Text)
                accentBar.Visible = true
                pageHolder.Visible = true
                tabTitle.Text = name
            end

            tabBtn.MouseButton1Click:Connect(Activate)

            tabBtn.MouseEnter:Connect(function()
                if not isActive() then
                    tabBtn.BackgroundColor3 = T.Surface1
                    TweenService:Create(tabBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                        BackgroundTransparency = 0
                    }):Play()
                    tabLabel.TextColor3 = T.Text
                    setIconColor(T.Text)
                end
            end)
            tabBtn.MouseLeave:Connect(function()
                if not isActive() then
                    TweenService:Create(tabBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                        BackgroundTransparency = 1
                    }):Play()
                    tabLabel.TextColor3 = T.TextDark
                    setIconColor(T.TextDark)
                end
            end)

            if #Tabs == 0 then
                Activate()
            end
            table.insert(Tabs, {Btn = tabBtn, Holder = pageHolder})

            --------------------------------------------
            -- Секции-контейнеры и строки внутри них
            --------------------------------------------

            local function newSection(title)
                local sec = Create("Frame", {
                    Name = (title or "Section") .. "Card",
                    BackgroundColor3 = T.Surface1,
                    Size = UDim2.new(1, 0, 0, 0),
                    ClipsDescendants = true,
                    BorderSizePixel = 0,
                    Parent = currentPage
                })
                AddCorner(sec, 8)
                AddStroke(sec, 1, T.HairCol, 0.9)

                local layout = Create("UIListLayout", {
                    Padding = UDim.new(0, 0),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = sec
                })
                -- +8 снизу = PaddingTop заголовка: карточка дышит одинаково
                layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    sec.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y + 8)
                end)

                if title and title ~= "" then
                    local head = Create("TextLabel", {
                        Text = title:upper(),
                        Font = FONT.Bold,
                        TextSize = TS.Section,
                        TextColor3 = T.TextDark,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 36),
                        LayoutOrder = 1,
                        Parent = sec
                    })
                    Create("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingTop = UDim.new(0, 8), Parent = head})
                end

                local data = {frame = sec, layout = layout, rows = {}, order = 1}
                table.insert(sections, data)
                return data
            end

            local function ensureSection()
                if not currentSectionData then
                    currentSectionData = newSection(nil)
                end
                return currentSectionData
            end

            -- Строка контрола: hairline-разделитель перед ней (кроме первой),
            -- лёгкая подсветка при hover, регистрация в поиске
            local function addRow(height, searchName, searchDesc)
                local data = ensureSection()
                local sep = nil
                if #data.rows > 0 then
                    data.order = data.order + 1
                    sep = Hairline({
                        Size = UDim2.new(1, 0, 0, 1),
                        LayoutOrder = data.order,
                        Parent = data.frame
                    })
                end
                data.order = data.order + 1
                local row = Create("Frame", {
                    BackgroundColor3 = T.Surface2,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, height),
                    LayoutOrder = data.order,
                    Parent = data.frame
                })
                row.MouseEnter:Connect(function()
                    TweenService:Create(row, TweenInfo.new(0.12), {BackgroundTransparency = 0.5}):Play()
                end)
                row.MouseLeave:Connect(function()
                    TweenService:Create(row, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
                end)
                table.insert(data.rows, {
                    row = row,
                    sep = sep,
                    name = (searchName or ""):lower(),
                    desc = (searchDesc or ""):lower()
                })
                return row
            end

            -- Заголовок и описание внутри строки.
            -- reserved — ширина правого блока контролов вместе с отступами:
            -- текст обрезается ровно по его границе и не налезает на контрол
            local function addRowText(row, title, desc, reserved)
                reserved = reserved or 200
                if desc and desc ~= "" then
                    -- 11 + 20 + 18 + 11 = ROW_H_DESC: сверху и снизу поровну
                    Create("TextLabel", {
                        Text = title,
                        Font = FONT.Bold,
                        TextSize = TS.Title,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Center,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, EDGE, 0, 11),
                        Size = UDim2.new(1, -reserved, 0, 20),
                        Parent = row
                    })
                    Create("TextLabel", {
                        Text = desc,
                        Font = FONT.Body,
                        TextSize = TS.Desc,
                        TextColor3 = T.TextDark,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Center,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, EDGE, 0, 31),
                        Size = UDim2.new(1, -reserved, 0, 18),
                        Parent = row
                    })
                else
                    Create("TextLabel", {
                        Text = title,
                        Font = FONT.Bold,
                        TextSize = TS.Title,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Center,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, EDGE, 0, 0),
                        Size = UDim2.new(1, -reserved, 1, 0),
                        Parent = row
                    })
                end
            end

            -- Мини-кнопка бинда (чип) — общая для CreateToggle/CreateKeybindButton
            local function makeKeybindChip(parent, keybindKey, width, height, posX)
                local bound = State.Keybinds and State.Keybinds[keybindKey]
                local chip = Create("TextButton", {
                    Name = keybindKey .. "_Button",
                    Text = (bound and bound ~= Enum.KeyCode.Unknown) and bound.Name or "—",
                    Font = FONT.Bold,
                    TextSize = TS.Chip,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextColor3 = T.Text,
                    BackgroundColor3 = T.Surface2,
                    Position = posX,
                    Size = UDim2.new(0, width, 0, height),
                    AutoButtonColor = false,
                    Parent = parent
                })
                AddCorner(chip, 6)
                local chipStroke = AddStroke(chip, 1, T.HairCol, T.HairTrans)

                State.UIElements[keybindKey .. "_Button"] = chip

                chip.MouseButton1Click:Connect(function()
                    chip.Text = "..."
                    State.ListeningForKeybind = {key = keybindKey, button = chip}
                end)
                chip.MouseEnter:Connect(function()
                    TweenService:Create(chipStroke, TweenInfo.new(0.15), {Transparency = 0.5, Color = T.Accent}):Play()
                end)
                chip.MouseLeave:Connect(function()
                    TweenService:Create(chipStroke, TweenInfo.new(0.15), {Transparency = T.HairTrans, Color = T.HairCol}):Play()
                end)
                return chip
            end

            -- Выпадающий список поверх mainFrame + закрытие по клику мимо.
            -- Общая механика для CreateDropdown и CreatePlayerDropdown.
            local function makeOverlayList(anchorBtn, width)
                local overlay = Create("ScrollingFrame", {
                    BackgroundColor3 = T.Surface2,
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, width, 0, 0),
                    Visible = false,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness = 4,
                    ScrollBarImageColor3 = T.Accent,
                    ClipsDescendants = true,
                    BorderSizePixel = 0,
                    ZIndex = 1000,
                    Parent = mainFrame
                })
                AddCorner(overlay, 6)
                AddStroke(overlay, 1, T.HairCol, 0.8)

                Create("UIListLayout", {
                    Padding = UDim.new(0, 2),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = overlay
                })

                local function close()
                    if overlay.Visible then
                        TweenService:Create(
                            overlay,
                            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                            {Size = UDim2.new(0, width, 0, 0)}
                        ):Play()
                        task.wait(0.2)
                        overlay.Visible = false
                    end
                end

                local function openAt(targetHeight)
                    local absPos = anchorBtn.AbsolutePosition
                    local absSize = anchorBtn.AbsoluteSize
                    local mainPos = mainFrame.AbsolutePosition
                    overlay.Position = UDim2.new(
                        0, absPos.X - mainPos.X,
                        0, absPos.Y - mainPos.Y + absSize.Y + 5
                    )
                    overlay.Size = UDim2.new(0, width, 0, 0)
                    TweenService:Create(
                        overlay,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        {Size = UDim2.new(0, width, 0, targetHeight)}
                    ):Play()
                end

                -- Закрытие по клику вне списка и вне кнопки
                local clickOutsideConnection = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 and overlay.Visible then
                        local mousePos = UserInputService:GetMouseLocation()
                        local framePos = overlay.AbsolutePosition
                        local frameSize = overlay.AbsoluteSize
                        local btnPos = anchorBtn.AbsolutePosition
                        local btnSize = anchorBtn.AbsoluteSize

                        local outsideFrame =
                            mousePos.X < framePos.X or mousePos.X > framePos.X + frameSize.X or
                            mousePos.Y < framePos.Y or mousePos.Y > framePos.Y + frameSize.Y

                        local outsideButton =
                            mousePos.X < btnPos.X or mousePos.X > btnPos.X + btnSize.X or
                            mousePos.Y < btnPos.Y or mousePos.Y > btnPos.Y + btnSize.Y

                        if outsideFrame and outsideButton then
                            close()
                        end
                    end
                end)
                table.insert(State.Connections, clickOutsideConnection)

                if not State.UIElements.OpenDropdowns then
                    State.UIElements.OpenDropdowns = {}
                end
                table.insert(State.UIElements.OpenDropdowns, close)

                return overlay, openAt, close
            end

            --------------------------------------------
            -- TabFunctions (API 1:1, всё через Handlers)
            --------------------------------------------
            local TabFunctions = {}

            function TabFunctions:CreateSection(title, column)
                if column == "right" then
                    currentPage = rightPage
                elseif column == "left" then
                    currentPage = leftPage
                end
                currentSectionData = newSection(title)
            end

            function TabFunctions:CreateToggle(title, desc, handlerKey, default, keybindKey)
                default = default or false
                local hasDesc = desc ~= nil and desc ~= ""
                local row = addRow(hasDesc and ROW_H_DESC or ROW_H, title, desc or "")
                -- правый блок: 44(пилюля)+14 и, если есть чип, ещё 56+8 слева
                addRowText(row, title, desc, keybindKey and 148 or 84)

                -- Пилюля 44x24, позиция/цвет зависят от состояния
                local toggleBg = Create("TextButton", {
                    Text = "",
                    BackgroundColor3 = default and T.Accent or T.TrackBg,
                    Position = UDim2.new(1, -(44 + EDGE), 0.5, -12),
                    Size = UDim2.new(0, 44, 0, 24),
                    AutoButtonColor = false,
                    Parent = row
                })
                AddCorner(toggleBg, 12)
                -- В выключенном состоянии пилюля почти сливается со строкой —
                -- держим на ней hairline и прячем его при включении
                local toggleStroke = AddStroke(toggleBg, 1, T.HairCol, default and 1 or 0.88)

                local toggleCircle = Create("Frame", {
                    BackgroundColor3 = T.Text,
                    Position = default and UDim2.new(0, 23, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
                    Size = UDim2.new(0, 18, 0, 18),
                    BorderSizePixel = 0,
                    Parent = toggleBg
                })
                AddCorner(toggleCircle, 9)

                -- Опциональный чип бинда слева от тогла
                if keybindKey then
                    makeKeybindChip(row, keybindKey, 56, CTRL_H, UDim2.new(1, -122, 0.5, -CTRL_H / 2))
                end

                local state = default

                -- Сразу вызываем handler с начальным значением, чтобы State
                -- был синхронизирован с GUI
                if default then
                    task.spawn(function()
                        callHandler(handlerKey, default)
                    end)
                end

                TrackConnection(toggleBg.MouseButton1Click:Connect(function()
                    state = not state
                    local targetColor = state and T.Accent or T.TrackBg
                    local targetPos = state and UDim2.new(0, 23, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)

                    TweenService:Create(toggleBg, TweenInfo.new(0.15), {BackgroundColor3 = targetColor}):Play()
                    TweenService:Create(toggleStroke, TweenInfo.new(0.15), {Transparency = state and 1 or 0.88}):Play()
                    TweenService:Create(toggleCircle, TweenInfo.new(0.15), {Position = targetPos}):Play()

                    callHandler(handlerKey, state)
                end))

                return toggleBg
            end

            function TabFunctions:CreateDropdown(title, desc, options, default, handlerKey)
                local hasDesc = desc ~= nil and desc ~= ""
                local row = addRow(hasDesc and ROW_H_DESC or ROW_H, title, desc or "")
                addRowText(row, title, desc, 150)

                local DD_W = 110
                local dropdown = Create("TextButton", {
                    Text = default,
                    Font = FONT.Bold,
                    TextSize = TS.Button,
                    TextColor3 = T.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    BackgroundColor3 = T.Surface2,
                    Position = UDim2.new(1, -(DD_W + EDGE), 0.5, -CTRL_H / 2),
                    Size = UDim2.new(0, DD_W, 0, CTRL_H),
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = row
                })
                AddCorner(dropdown, 6)
                AddStroke(dropdown, 1, T.HairCol, T.HairTrans)
                -- правый паддинг 22 — место под рисованный шеврон
                Create("UIPadding", {
                    PaddingLeft = UDim.new(0, 10),
                    PaddingRight = UDim.new(0, 22),
                    Parent = dropdown
                })
                glyphChevron(dropdown, 22)

                local overlay, openAt, close = makeOverlayList(dropdown, DD_W)

                for _, option in ipairs(options) do
                    local optionBtn = Create("TextButton", {
                        Text = option,
                        Font = FONT.Body,
                        TextSize = TS.Option,
                        TextColor3 = T.Text,
                        BackgroundColor3 = T.Surface2,
                        Size = UDim2.new(1, 0, 0, 28),
                        AutoButtonColor = false,
                        ZIndex = 1001,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Parent = overlay
                    })
                    AddCorner(optionBtn, 4)
                    -- пункт выравнивается по тексту закрытой кнопки (те же 10px)
                    Create("UIPadding", {PaddingLeft = UDim.new(0, 10), Parent = optionBtn})

                    optionBtn.MouseButton1Click:Connect(function()
                        dropdown.Text = option
                        callHandler(handlerKey, option)
                        close()
                    end)

                    optionBtn.MouseEnter:Connect(function()
                        TweenService:Create(optionBtn, TweenInfo.new(0.15), {
                            BackgroundColor3 = T.Accent
                        }):Play()
                    end)

                    optionBtn.MouseLeave:Connect(function()
                        TweenService:Create(optionBtn, TweenInfo.new(0.15), {
                            BackgroundColor3 = T.Surface2
                        }):Play()
                    end)
                end

                dropdown.MouseButton1Click:Connect(function()
                    if overlay.Visible then
                        close()
                    else
                        overlay.Visible = true
                        overlay.CanvasSize = UDim2.new(0, 0, 0, #options * 30 + 4)
                        openAt(math.min(154, #options * 30 + 4))
                    end
                end)

                return dropdown
            end

            function TabFunctions:CreateInputField(title, desc, defaultValue, handlerKey)
                local hasDesc = desc ~= nil and desc ~= ""
                local row = addRow(hasDesc and ROW_H_DESC or ROW_H, title, desc or "")
                addRowText(row, title, desc, 104)

                local inputBox = Create("TextBox", {
                    Text = tostring(defaultValue),
                    Font = FONT.Mono,
                    TextSize = TS.Value,
                    TextColor3 = T.Text,
                    BackgroundColor3 = T.Surface2,
                    Position = UDim2.new(1, -(64 + EDGE), 0.5, -CTRL_H / 2),
                    Size = UDim2.new(0, 64, 0, CTRL_H),
                    PlaceholderText = "…",
                    PlaceholderColor3 = T.TextDark,
                    ClearTextOnFocus = false,
                    Parent = row
                })
                AddCorner(inputBox, 6)
                AddStroke(inputBox, 1, T.HairCol, T.HairTrans)

                inputBox.FocusLost:Connect(function()
                    local value = tonumber(inputBox.Text)
                    if value then
                        callHandler(handlerKey, value)
                    else
                        inputBox.Text = tostring(defaultValue)
                    end
                end)
            end

            function TabFunctions:CreateSlider(title, description, min, max, default, handlerKey, step)
                step = step or 1
                local hasDesc = description ~= nil and description ~= ""
                local row = addRow(hasDesc and ROW_H_DESC or ROW_H, title, description or "")
                addRowText(row, title, description, 206)

                local function fmt(v)
                    return step >= 1 and string.format("%d", v) or string.format("%.2f", v)
                end

                local currentValue = default

                -- Трек 110x4 (кончается за 10px до поля значения) и значение-TextBox
                local sliderBg = Create("Frame", {
                    BackgroundColor3 = T.TrackBg,
                    Position = UDim2.new(1, -180, 0.5, -2),
                    Size = UDim2.new(0, 110, 0, 4),
                    BorderSizePixel = 0,
                    Parent = row
                })
                AddCorner(sliderBg, 2)

                local sliderFill = Create("Frame", {
                    BackgroundColor3 = T.Accent,
                    Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
                    BorderSizePixel = 0,
                    Parent = sliderBg
                })
                AddCorner(sliderFill, 2)

                local sliderButton = Create("TextButton", {
                    Text = "",
                    BackgroundColor3 = T.Text,
                    Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7),
                    Size = UDim2.new(0, 14, 0, 14),
                    AutoButtonColor = false,
                    Parent = sliderBg
                })
                AddCorner(sliderButton, 7)

                local valueBox = Create("TextBox", {
                    Text = fmt(default),
                    Font = FONT.Mono,
                    TextSize = TS.Value,
                    TextColor3 = T.Accent,
                    BackgroundColor3 = T.Surface2,
                    Position = UDim2.new(1, -(46 + EDGE), 0.5, -CTRL_H / 2),
                    Size = UDim2.new(0, 46, 0, CTRL_H),
                    ClearTextOnFocus = true,
                    Parent = row
                })
                AddCorner(valueBox, 6)
                AddStroke(valueBox, 1, T.HairCol, T.HairTrans)

                local function applyValue(value, fire)
                    value = math.floor(value / step + 0.5) * step
                    value = math.clamp(value, min, max)
                    currentValue = value

                    local normalizedValue = (value - min) / (max - min)
                    sliderFill.Size = UDim2.new(normalizedValue, 0, 1, 0)
                    sliderButton.Position = UDim2.new(normalizedValue, -7, 0.5, -7)
                    valueBox.Text = fmt(value)

                    if fire then
                        callHandler(handlerKey, value)
                    end
                end

                local dragging = false
                local function updateSlider(input)
                    local pos = sliderBg.AbsolutePosition.X
                    local size = sliderBg.AbsoluteSize.X
                    local mouseX = input.Position.X
                    local alpha = math.clamp((mouseX - pos) / size, 0, 1)
                    applyValue(min + alpha * (max - min), true)
                end

                sliderButton.MouseButton1Down:Connect(function() dragging = true end)
                sliderBg.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        updateSlider(input)
                    end
                end)
                TrackConnection(UserInputService.InputChanged:Connect(function(input)
                    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        updateSlider(input)
                    end
                end))
                TrackConnection(UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
                end))

                -- Ручной ввод значения: clamp по min/max, округление до step
                valueBox.FocusLost:Connect(function()
                    local value = tonumber(valueBox.Text)
                    if value then
                        applyValue(value, true)
                    else
                        valueBox.Text = fmt(currentValue)
                    end
                end)
            end

            function TabFunctions:CreateKeybindButton(title, emoteId, keybindKey)
                local row = addRow(ROW_H, title, "")
                addRowText(row, title, nil, 140)

                local bound = State.Keybinds and State.Keybinds[keybindKey]
                local bindButton = Create("TextButton", {
                    Name = keybindKey .. "_Button",
                    Text = (bound and bound ~= Enum.KeyCode.Unknown) and bound.Name or "Not Bound",
                    Font = FONT.Bold,
                    TextSize = TS.Button,
                    TextColor3 = T.Text,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    BackgroundColor3 = T.Surface2,
                    Position = UDim2.new(1, -(100 + EDGE), 0.5, -CTRL_H / 2),
                    Size = UDim2.new(0, 100, 0, CTRL_H),
                    AutoButtonColor = false,
                    Parent = row
                })
                AddCorner(bindButton, 6)
                AddStroke(bindButton, 1, T.HairCol, T.HairTrans)

                State.UIElements[keybindKey .. "_Button"] = bindButton

                bindButton.MouseButton1Click:Connect(function()
                    bindButton.Text = "Press Key..."
                    State.ListeningForKeybind = {key = keybindKey, button = bindButton}
                end)

                return bindButton
            end

            -- stateKey - в какое поле State писать выбор. Разные вкладки передают
            -- разные ключи, иначе списки затирают друг друга.
            function TabFunctions:CreatePlayerDropdown(title, desc, stateKey)
                stateKey = stateKey or "SelectedPlayerForFling"
                local hasDesc = desc ~= nil and desc ~= ""
                local row = addRow(hasDesc and ROW_H_DESC or ROW_H, title, desc or "")
                addRowText(row, title, desc, 205)

                local DD_W = 165
                local dropdown = Create("TextButton", {
                    Text = "Select player",
                    Font = FONT.Bold,
                    TextSize = TS.Button,
                    TextColor3 = T.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    BackgroundColor3 = T.Surface2,
                    Position = UDim2.new(1, -(DD_W + EDGE), 0.5, -CTRL_H / 2),
                    Size = UDim2.new(0, DD_W, 0, CTRL_H),
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = row
                })
                AddCorner(dropdown, 6)
                AddStroke(dropdown, 1, T.HairCol, T.HairTrans)
                -- правый паддинг 22 — место под рисованный шеврон
                Create("UIPadding", {
                    PaddingLeft = UDim.new(0, 10),
                    PaddingRight = UDim.new(0, 22),
                    Parent = dropdown
                })
                glyphChevron(dropdown, 22)

                local overlay, openAt, close = makeOverlayList(dropdown, DD_W)

                local function updatePlayerList()
                    for _, child in ipairs(overlay:GetChildren()) do
                        if child:IsA("TextButton") or child:IsA("TextLabel") then
                            child:Destroy()
                        end
                    end

                    local players = getAllPlayers()
                    if #players == 0 then
                        local empty = Create("TextLabel", {
                            Text = "No players",
                            Font = FONT.Body,
                            TextSize = TS.Option,
                            TextColor3 = T.TextDark,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 28),
                            ZIndex = 1001,
                            Parent = overlay
                        })
                        Create("UIPadding", {PaddingLeft = UDim.new(0, 10), Parent = empty})
                        overlay.CanvasSize = UDim2.new(0, 0, 0, 32)
                        return
                    end

                    -- ширина строк — на всю ширину списка: UIListLayout всё равно
                    -- перебивает Position, а инсет давал «съеденный» правый край
                    local buttonHeight = 28
                    local buttonSpacing = 2
                    overlay.CanvasSize = UDim2.new(0, 0, 0, #players * (buttonHeight + buttonSpacing) + 4)

                    for _, playerName in ipairs(players) do
                        local pb = Create("TextButton", {
                            Text = playerName,
                            Font = FONT.Body,
                            TextSize = TS.Option,
                            TextColor3 = T.Text,
                            BackgroundColor3 = T.Surface2,
                            Size = UDim2.new(1, 0, 0, buttonHeight),
                            AutoButtonColor = false,
                            ZIndex = 1001,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextTruncate = Enum.TextTruncate.AtEnd,
                            Parent = overlay
                        })
                        AddCorner(pb, 4)
                        Create("UIPadding", {PaddingLeft = UDim.new(0, 10), Parent = pb})

                        pb.MouseButton1Click:Connect(function()
                            State[stateKey] = playerName
                            -- длинные ники режет TextTruncate, вручную не обрезаем
                            dropdown.Text = playerName
                            close()
                        end)

                        pb.MouseEnter:Connect(function()
                            TweenService:Create(pb, TweenInfo.new(0.15), {
                                BackgroundColor3 = T.Accent
                            }):Play()
                        end)

                        pb.MouseLeave:Connect(function()
                            TweenService:Create(pb, TweenInfo.new(0.15), {
                                BackgroundColor3 = T.Surface2
                            }):Play()
                        end)
                    end
                end

                dropdown.MouseButton1Click:Connect(function()
                    if overlay.Visible then
                        close()
                    else
                        overlay.Visible = true
                        updatePlayerList()
                        local playerCount = #getAllPlayers()
                        openAt(math.min(184, math.max(32, playerCount * 30 + 4)))
                    end
                end)

                TrackConnection(Players.PlayerAdded:Connect(function()
                    if overlay.Visible then
                        updatePlayerList()
                    end
                end))

                TrackConnection(Players.PlayerRemoving:Connect(function()
                    if overlay.Visible then
                        updatePlayerList()
                    end
                end))

                return dropdown
            end

            function TabFunctions:CreateButton(title, buttonText, color, handlerKey)
                local hasTitle = title ~= nil and title ~= ""
                local row = addRow(hasTitle and 78 or ROW_H + 4, title or "", buttonText)

                if hasTitle then
                    Create("TextLabel", {
                        Text = title,
                        Font = FONT.Bold,
                        TextSize = TS.Title,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, EDGE, 0, 10),
                        Size = UDim2.new(1, -EDGE * 2, 0, 20),
                        Parent = row
                    })
                end

                local useColor = color or T.Accent
                local isDanger = color == CONFIG.Colors.Red

                local button = Create("TextButton", {
                    Text = buttonText,
                    Font = FONT.Bold,
                    TextSize = TS.Button,
                    TextColor3 = isDanger and T.Danger or T.AccentInk,
                    BackgroundColor3 = useColor,
                    BackgroundTransparency = isDanger and 0.85 or 0,
                    -- 10 + 20 + 4 + 32 + 12 = 78 при заголовке; иначе строго по центру
                    Position = hasTitle and UDim2.new(0, EDGE, 0, 34) or UDim2.new(0, EDGE, 0.5, -16),
                    Size = UDim2.new(1, -EDGE * 2, 0, 32),
                    AutoButtonColor = false,
                    Parent = row
                })
                AddCorner(button, 6)
                if isDanger then
                    AddStroke(button, 1, T.Danger, 0.6)
                end

                button.MouseButton1Click:Connect(function()
                    callHandler(handlerKey)
                end)

                if isDanger then
                    button.MouseEnter:Connect(function()
                        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundTransparency = 0.7}):Play()
                    end)
                    button.MouseLeave:Connect(function()
                        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundTransparency = 0.85}):Play()
                    end)
                else
                    button.MouseEnter:Connect(function()
                        local hoverColor = Color3.fromRGB(
                            math.min(255, useColor.R * 255 + 20),
                            math.min(255, useColor.G * 255 + 20),
                            math.min(255, useColor.B * 255 + 20)
                        )
                        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
                    end)
                    button.MouseLeave:Connect(function()
                        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = useColor}):Play()
                    end)
                end

                return button
            end

            return TabFunctions
        end
        GUI.CreateTab = CreateTab

        ----------------------------------------------------------------
        -- Кнопка закрытия, поиск, драг за хедер, инпут
        ----------------------------------------------------------------

        closeButton.MouseButton1Click:Connect(function()
            callHandler("Shutdown")
        end)

        closeButton.MouseEnter:Connect(function()
            TweenService:Create(closeButton, TweenInfo.new(0.15), {
                BackgroundTransparency = 0.85
            }):Play()
            for _, s in ipairs(closeStrokes) do
                TweenService:Create(s, TweenInfo.new(0.15), {BackgroundColor3 = T.Danger}):Play()
            end
        end)
        closeButton.MouseLeave:Connect(function()
            TweenService:Create(closeButton, TweenInfo.new(0.15), {
                BackgroundTransparency = 1
            }):Play()
            for _, s in ipairs(closeStrokes) do
                TweenService:Create(s, TweenInfo.new(0.15), {BackgroundColor3 = T.TextDark}):Play()
            end
        end)

        -- Поиск: фильтрация строк и скрытие пустых секций
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            applySearch(searchBox.Text)
        end)

        -- Перетаскивание окна за хедер (кастомный драг вместо Draggable)
        local winDragging = false
        local winDragStart = nil
        local winStartPos = nil

        header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                winDragging = true
                winDragStart = UserInputService:GetMouseLocation()
                winStartPos = mainFrame.Position
            end
        end)
        TrackConnection(UserInputService.InputChanged:Connect(function(input)
            if winDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = UserInputService:GetMouseLocation() - winDragStart
                mainFrame.Position = UDim2.new(
                    winStartPos.X.Scale, winStartPos.X.Offset + delta.X,
                    winStartPos.Y.Scale, winStartPos.Y.Offset + delta.Y
                )
            end
        end))
        TrackConnection(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                winDragging = false
            end
        end))

        local inputBeganConnection = UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.KeyCode == CONFIG.HideKey then
                mainFrame.Visible = not mainFrame.Visible
            end

            if processed then return end

            -- Листенер на выбор кейбинда
            if State.ListeningForKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode
                local bindData = State.ListeningForKeybind

                if key == Enum.KeyCode.Delete or key == Enum.KeyCode.Backspace then
                    callHandler("ClearKeybind", bindData.key, bindData.button)
                    State.ListeningForKeybind = nil
                    return
                end

                callHandler("SetKeybind", bindData.key, key, bindData.button)
                State.ListeningForKeybind = nil
                return
            end

            -- Эмоты
            callHandler("OnInputEmotes", input)

            -- Actions (knifeThrow, shootMurderer, PickupGun, ClickTP, GodMode toggle, FlingPlayer, NoClip)
            callHandler("OnInputActions", input)
        end)
        table.insert(State.Connections, inputBeganConnection)

        local inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
            callHandler("OnInputEnded", input)
        end)
        table.insert(State.Connections, inputEndedConnection)

        local mouse = LocalPlayer:GetMouse()
        local mouseClickConnection = mouse.Button1Down:Connect(function()
            callHandler("OnMouseClick")
        end)
        table.insert(State.Connections, mouseClickConnection)

        -- ResizeGrip: изменение размера окна мышью
        local resizeGrip = Create("TextButton", {
            Name = "ResizeGrip",
            Text = "",
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -20, 1, -20),
            Size = UDim2.new(0, 18, 0, 18),
            AutoButtonColor = false,
            Active = true,
            ZIndex = 10,
            Parent = mainFrame,
        })
        glyphResizeCorner(resizeGrip)

        local resizing = false
        local resizeStart = nil
        local frameStartSize = nil

        resizeGrip.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                resizing = true
                resizeStart = UserInputService:GetMouseLocation()
                frameStartSize = mainFrame.AbsoluteSize
            end
        end)
        TrackConnection(UserInputService.InputChanged:Connect(function(input)
            if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mouseLoc = UserInputService:GetMouseLocation()
                local delta = mouseLoc - resizeStart
                local newW = math.clamp(frameStartSize.X + delta.X, 720, 1400)
                local newH = math.clamp(frameStartSize.Y + delta.Y, 480, 900)
                mainFrame.Size = UDim2.new(0, newW, 0, newH)
            end
        end))
        TrackConnection(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                resizing = false
            end
        end))
    end

    ----------------------------------------------------------------
    -- API
    ----------------------------------------------------------------

    function GUI.Init()
        CreateUI()
    end

    function GUI.Cleanup()
        if State.UIElements.MainGui then
            pcall(function()
                State.UIElements.MainGui:Destroy()
            end)
            State.UIElements.MainGui = nil
        end
    end

    return GUI
end
