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
    local T = {
        Canvas    = Color3.fromRGB(16, 16, 23),
        Surface1  = Color3.fromRGB(22, 22, 30),
        Surface2  = Color3.fromRGB(29, 29, 39),
        HairCol   = Color3.fromRGB(255, 255, 255),
        HairTrans = 0.92,
        Text      = Color3.fromRGB(232, 230, 238),
        TextDark  = Color3.fromRGB(141, 136, 152),
        Accent    = CONFIG.Colors.Accent,
        AccentInk = Color3.fromRGB(20, 20, 27),   -- тёмный текст на акцентной заливке
        Danger    = CONFIG.Colors.Red,
        TrackBg   = Color3.fromRGB(51, 51, 63),   -- фон трека слайдера / выкл. тогла
    }

    -- Единственное место с прозрачностью — корневой фрейм окна
    local ROOT_TRANSPARENCY = 0.06

    local SIDEBAR_W  = 188
    local HEADER_H   = 48
    local FOOTER_H   = 28
    local MONO_FONT  = Enum.Font.Code

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
        AddCorner(mainFrame, 14)
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
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            TextColor3 = T.Accent,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 18, 0, 16),
            Size = UDim2.new(0, 150, 0, 20),
            Parent = sidebar
        })

        Create("TextLabel", {
            Name = "LogoSub",
            Text = "mm2",
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = T.TextDark,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 18, 0, 36),
            Size = UDim2.new(0, 150, 0, 14),
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
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = Color3.fromRGB(240, 150, 200),
            TextTransparency = 0.25,
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
            Font = Enum.Font.GothamBold,
            TextSize = 15,
            TextColor3 = T.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 18, 0, 0),
            Size = UDim2.new(0, 300, 1, 0),
            Parent = header
        })

        local searchBox = Create("TextBox", {
            Name = "SearchBox",
            PlaceholderText = "Поиск...",
            Text = "",
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = T.Text,
            PlaceholderColor3 = T.TextDark,
            BackgroundColor3 = T.Surface2,
            Position = UDim2.new(1, -286, 0.5, -14),
            Size = UDim2.new(0, 220, 0, 28),
            ClearTextOnFocus = false,
            Parent = header,
        })
        AddCorner(searchBox, 7)
        AddStroke(searchBox, 1, T.HairCol, T.HairTrans)

        local closeButton = Create("TextButton", {
            Text = "✕",
            Font = Enum.Font.GothamMedium,
            TextSize = 15,
            TextColor3 = T.TextDark,
            BackgroundColor3 = T.Danger,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -42, 0.5, -14),
            Size = UDim2.new(0, 28, 0, 28),
            AutoButtonColor = false,
            Parent = header
        })
        AddCorner(closeButton, 7)

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
            Font = MONO_FONT,
            TextSize = 11,
            TextColor3 = T.TextDark,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 0),
            Size = UDim2.new(0, 120, 1, 0),
            Parent = roleChip
        })

        local pingLabel = Create("TextLabel", {
            Text = "Ping: -- ms",
            Font = MONO_FONT,
            TextSize = 11,
            TextColor3 = T.TextDark,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, -110, 0, 0),
            Size = UDim2.new(0, 220, 1, 0),
            Parent = footer
        })

        Create("TextLabel", {
            Text = "Toggle: " .. CONFIG.HideKey.Name,
            Font = MONO_FONT,
            TextSize = 11,
            TextColor3 = T.TextDark,
            TextXAlignment = Enum.TextXAlignment.Right,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -174, 0, 0),
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
        -- ВНУТРЕННИЙ КОНСТРУКТОР ТАБА + TabFunctions
        ----------------------------------------------------------------

        local function CreateTab(name)
            local tabBtn = Create("TextButton", {
                Text = name,
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextColor3 = T.TextDark,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundColor3 = T.Surface1,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 34),
                AutoButtonColor = false,
                Parent = navScroll
            })
            AddCorner(tabBtn, 8)
            Create("UIPadding", {PaddingLeft = UDim.new(0, 12), Parent = tabBtn})

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
                        TweenInfo.new(0.15, Enum.EasingStyle.Quad),
                        {BackgroundTransparency = 1, TextColor3 = T.TextDark}
                    ):Play()
                    currentTab.Bar.Visible = false
                    currentTab.Holder.Visible = false
                end
                currentTab = {Btn = tabBtn, Holder = pageHolder, Bar = accentBar}
                tabBtn.BackgroundColor3 = T.Surface2
                TweenService:Create(
                    tabBtn,
                    TweenInfo.new(0.15, Enum.EasingStyle.Quad),
                    {BackgroundTransparency = 0, TextColor3 = T.Text}
                ):Play()
                accentBar.Visible = true
                pageHolder.Visible = true
                tabTitle.Text = name
            end

            tabBtn.MouseButton1Click:Connect(Activate)

            tabBtn.MouseEnter:Connect(function()
                if not isActive() then
                    tabBtn.BackgroundColor3 = T.Surface1
                    TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                        BackgroundTransparency = 0, TextColor3 = T.Text
                    }):Play()
                end
            end)
            tabBtn.MouseLeave:Connect(function()
                if not isActive() then
                    TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                        BackgroundTransparency = 1, TextColor3 = T.TextDark
                    }):Play()
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
                AddCorner(sec, 10)
                AddStroke(sec, 1, T.HairCol, 0.9)

                local layout = Create("UIListLayout", {
                    Padding = UDim.new(0, 0),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = sec
                })
                layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    sec.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y + 6)
                end)

                if title and title ~= "" then
                    local head = Create("TextLabel", {
                        Text = title:upper(),
                        Font = Enum.Font.GothamBold,
                        TextSize = 11,
                        TextColor3 = T.TextDark,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 30),
                        LayoutOrder = 1,
                        Parent = sec
                    })
                    Create("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingTop = UDim.new(0, 4), Parent = head})
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

            -- Заголовок и описание внутри строки
            local function addRowText(row, title, desc)
                if desc and desc ~= "" then
                    Create("TextLabel", {
                        Text = title,
                        Font = Enum.Font.GothamMedium,
                        TextSize = 13,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 14, 0, 9),
                        Size = UDim2.new(1, -200, 0, 20),
                        Parent = row
                    })
                    Create("TextLabel", {
                        Text = desc,
                        Font = Enum.Font.Gotham,
                        TextSize = 11,
                        TextColor3 = T.TextDark,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 14, 0, 30),
                        Size = UDim2.new(1, -200, 0, 16),
                        Parent = row
                    })
                else
                    Create("TextLabel", {
                        Text = title,
                        Font = Enum.Font.GothamMedium,
                        TextSize = 13,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 14, 0, 0),
                        Size = UDim2.new(1, -200, 1, 0),
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
                    Font = Enum.Font.GothamMedium,
                    TextSize = 11,
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
                AddCorner(overlay, 7)
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
                local row = addRow(hasDesc and 56 or 44, title, desc or "")
                addRowText(row, title, desc)

                -- Пилюля 40x22, позиция/цвет зависят от состояния
                local toggleBg = Create("TextButton", {
                    Text = "",
                    BackgroundColor3 = default and T.Accent or T.TrackBg,
                    Position = UDim2.new(1, -54, 0.5, -11),
                    Size = UDim2.new(0, 40, 0, 22),
                    AutoButtonColor = false,
                    Parent = row
                })
                AddCorner(toggleBg, 11)

                local toggleCircle = Create("Frame", {
                    BackgroundColor3 = T.Text,
                    Position = default and UDim2.new(0, 21, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
                    Size = UDim2.new(0, 16, 0, 16),
                    BorderSizePixel = 0,
                    Parent = toggleBg
                })
                AddCorner(toggleCircle, 8)

                -- Опциональный чип бинда слева от тогла
                if keybindKey then
                    makeKeybindChip(row, keybindKey, 56, 24, UDim2.new(1, -118, 0.5, -12))
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
                    local targetPos = state and UDim2.new(0, 21, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)

                    TweenService:Create(toggleBg, TweenInfo.new(0.15), {BackgroundColor3 = targetColor}):Play()
                    TweenService:Create(toggleCircle, TweenInfo.new(0.15), {Position = targetPos}):Play()

                    callHandler(handlerKey, state)
                end))

                return toggleBg
            end

            function TabFunctions:CreateDropdown(title, desc, options, default, handlerKey)
                local hasDesc = desc ~= nil and desc ~= ""
                local row = addRow(hasDesc and 56 or 44, title, desc or "")
                addRowText(row, title, desc)

                local DD_W = 110
                local dropdown = Create("TextButton", {
                    Text = default .. "  ▾",
                    Font = Enum.Font.GothamMedium,
                    TextSize = 12,
                    TextColor3 = T.Text,
                    BackgroundColor3 = T.Surface2,
                    Position = UDim2.new(1, -(DD_W + 14), 0.5, -14),
                    Size = UDim2.new(0, DD_W, 0, 28),
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = row
                })
                AddCorner(dropdown, 7)
                AddStroke(dropdown, 1, T.HairCol, T.HairTrans)

                local overlay, openAt, close = makeOverlayList(dropdown, DD_W)

                for _, option in ipairs(options) do
                    local optionBtn = Create("TextButton", {
                        Text = option,
                        Font = Enum.Font.Gotham,
                        TextSize = 11,
                        TextColor3 = T.Text,
                        BackgroundColor3 = T.Surface2,
                        Size = UDim2.new(1, 0, 0, 25),
                        AutoButtonColor = false,
                        ZIndex = 1001,
                        Parent = overlay
                    })
                    AddCorner(optionBtn, 4)

                    optionBtn.MouseButton1Click:Connect(function()
                        dropdown.Text = option .. "  ▾"
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
                        overlay.CanvasSize = UDim2.new(0, 0, 0, #options * 27)
                        openAt(math.min(120, #options * 27))
                    end
                end)

                return dropdown
            end

            function TabFunctions:CreateInputField(title, desc, defaultValue, handlerKey)
                local hasDesc = desc ~= nil and desc ~= ""
                local row = addRow(hasDesc and 56 or 44, title, desc or "")
                addRowText(row, title, desc)

                local inputBox = Create("TextBox", {
                    Text = tostring(defaultValue),
                    Font = MONO_FONT,
                    TextSize = 12,
                    TextColor3 = T.Text,
                    BackgroundColor3 = T.Surface2,
                    Position = UDim2.new(1, -78, 0.5, -12),
                    Size = UDim2.new(0, 64, 0, 24),
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
                local row = addRow(hasDesc and 56 or 44, title, description or "")
                addRowText(row, title, description)

                local function fmt(v)
                    return step >= 1 and string.format("%d", v) or string.format("%.2f", v)
                end

                local currentValue = default

                -- Трек 110x4 и значение-TextBox в одной строке с заголовком
                local sliderBg = Create("Frame", {
                    BackgroundColor3 = T.TrackBg,
                    Position = UDim2.new(1, -178, 0.5, -2),
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
                    Position = UDim2.new((default - min) / (max - min), -6, 0.5, -6),
                    Size = UDim2.new(0, 12, 0, 12),
                    AutoButtonColor = false,
                    Parent = sliderBg
                })
                AddCorner(sliderButton, 6)

                local valueBox = Create("TextBox", {
                    Text = fmt(default),
                    Font = MONO_FONT,
                    TextSize = 11,
                    TextColor3 = T.Accent,
                    BackgroundColor3 = T.Surface2,
                    Position = UDim2.new(1, -58, 0.5, -11),
                    Size = UDim2.new(0, 44, 0, 22),
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
                    sliderButton.Position = UDim2.new(normalizedValue, -6, 0.5, -6)
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
                local row = addRow(44, title, "")
                addRowText(row, title, nil)

                local bound = State.Keybinds and State.Keybinds[keybindKey]
                local bindButton = Create("TextButton", {
                    Name = keybindKey .. "_Button",
                    Text = (bound and bound ~= Enum.KeyCode.Unknown) and bound.Name or "Not Bound",
                    Font = Enum.Font.GothamMedium,
                    TextSize = 12,
                    TextColor3 = T.Text,
                    BackgroundColor3 = T.Surface2,
                    Position = UDim2.new(1, -109, 0.5, -13),
                    Size = UDim2.new(0, 95, 0, 26),
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
                local row = addRow(hasDesc and 56 or 44, title, desc or "")
                addRowText(row, title, desc)

                local DD_W = 165
                local dropdown = Create("TextButton", {
                    Text = "Select player  ▾",
                    Font = Enum.Font.GothamMedium,
                    TextSize = 12,
                    TextColor3 = T.Text,
                    BackgroundColor3 = T.Surface2,
                    Position = UDim2.new(1, -(DD_W + 14), 0.5, -14),
                    Size = UDim2.new(0, DD_W, 0, 28),
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = row
                })
                AddCorner(dropdown, 7)
                AddStroke(dropdown, 1, T.HairCol, T.HairTrans)

                local overlay, openAt, close = makeOverlayList(dropdown, DD_W)

                local function updatePlayerList()
                    for _, child in ipairs(overlay:GetChildren()) do
                        if child:IsA("TextButton") or child:IsA("TextLabel") then
                            child:Destroy()
                        end
                    end

                    local players = getAllPlayers()
                    if #players == 0 then
                        Create("TextLabel", {
                            Text = "No players",
                            Font = Enum.Font.Gotham,
                            TextSize = 11,
                            TextColor3 = T.TextDark,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, -10, 0, 25),
                            ZIndex = 1001,
                            Parent = overlay
                        })
                        overlay.CanvasSize = UDim2.new(0, 0, 0, 30)
                        return
                    end

                    local buttonHeight = 28
                    local buttonSpacing = 2
                    overlay.CanvasSize = UDim2.new(0, 0, 0, #players * (buttonHeight + buttonSpacing) + 5)

                    for _, playerName in ipairs(players) do
                        local pb = Create("TextButton", {
                            Text = playerName,
                            Font = Enum.Font.Gotham,
                            TextSize = 11,
                            TextColor3 = T.Text,
                            BackgroundColor3 = T.Surface2,
                            Size = UDim2.new(1, -10, 0, buttonHeight),
                            Position = UDim2.new(0, 5, 0, 0),
                            AutoButtonColor = false,
                            ZIndex = 1001,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextTruncate = Enum.TextTruncate.AtEnd,
                            Parent = overlay
                        })
                        AddCorner(pb, 4)
                        Create("UIPadding", {PaddingLeft = UDim.new(0, 8), Parent = pb})

                        pb.MouseButton1Click:Connect(function()
                            State[stateKey] = playerName
                            dropdown.Text = (#playerName > 14 and playerName:sub(1, 14) .. "…" or playerName) .. "  ▾"
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
                        openAt(math.min(150, math.max(30, playerCount * 30)))
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
                local row = addRow(hasTitle and 70 or 44, title or "", buttonText)

                if hasTitle then
                    Create("TextLabel", {
                        Text = title,
                        Font = Enum.Font.GothamMedium,
                        TextSize = 13,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 14, 0, 8),
                        Size = UDim2.new(1, -28, 0, 18),
                        Parent = row
                    })
                end

                local useColor = color or T.Accent
                local isDanger = color == CONFIG.Colors.Red

                local button = Create("TextButton", {
                    Text = buttonText,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 12,
                    TextColor3 = isDanger and T.Danger or T.AccentInk,
                    BackgroundColor3 = useColor,
                    BackgroundTransparency = isDanger and 0.85 or 0,
                    Position = hasTitle and UDim2.new(0, 14, 0, 32) or UDim2.new(0, 14, 0.5, -15),
                    Size = UDim2.new(1, -28, 0, 30),
                    AutoButtonColor = false,
                    Parent = row
                })
                AddCorner(button, 7)
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
                TextColor3 = T.Danger, BackgroundTransparency = 0.85
            }):Play()
        end)
        closeButton.MouseLeave:Connect(function()
            TweenService:Create(closeButton, TweenInfo.new(0.15), {
                TextColor3 = T.TextDark, BackgroundTransparency = 1
            }):Play()
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
            Text = "↘",
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = T.TextDark,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -20, 1, -20),
            Size = UDim2.new(0, 18, 0, 18),
            AutoButtonColor = false,
            Active = true,
            ZIndex = 10,
            Parent = mainFrame,
        })

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
