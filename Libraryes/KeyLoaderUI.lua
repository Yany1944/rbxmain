-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 1: МЕНЮ VIOLITE — ОКНО АВТОРИЗАЦИИ
-- ══════════════════════════════════════════════════════════════════════════════

return function(env)
    local CONFIG, State = env.CONFIG, env.State
    local Style, Services = env.Style, env.Services
    local Create, corner, hairline = Style.Create, Style.Corner, Style.Hairline
    local FONT, C = Style.Theme.FONT, CONFIG.Colors
    local UI = {}
    local textBindings = {}
    function UI.SetText(object, property, source)
        textBindings[object] = textBindings[object] or {}
        textBindings[object][property] = source
        object[property] = env.Text(source)
    end
    local function refreshLanguage()
        for object, properties in pairs(textBindings) do
            for property, source in pairs(properties) do object[property] = env.Text(source) end
        end
    end

    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        State.Connections[#State.Connections + 1] = connection
        return connection
    end

    -- Каждая поверхность имеет один tween: частые нажатия не накапливают эффекты.
    local function animate(object, duration, properties)
        if State.Done then return end
        local old = State.Tweens[object]
        if old then old:Cancel() end
        local tween = Services.TweenService:Create(object,
            TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
        State.Tweens[object] = tween
        tween:Play()
    end

    local function pressFeedback(control, color)
        local pulse = Create("Frame", {Name = "PressPulse", BackgroundColor3 = color,
            BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
            Size = UDim2.fromScale(1, 1), ZIndex = control.ZIndex + 2, Parent = control})
        corner(pulse, Style.Theme.R_CTRL)
        return function()
            if State.Done then return end
            local old = State.Tweens[pulse]
            if old then old:Cancel() end
            pulse.BackgroundTransparency = 0.76
            animate(pulse, CONFIG.Motion.Pulse, {BackgroundTransparency = 1})
        end
    end

    local function label(parent, name, text, x, y, w, h, size, color, font)
        local object = Create("TextLabel", {
            Name = name, Text = text, Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1,
            TextColor3 = color or C.Text, Font = font or FONT.Body,
            TextSize = size, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center, Parent = parent,
        })
        UI.SetText(object, "Text", text)
        return object
    end

    local function button(parent, name, text, x, y, w, h, background, ink, ghost)
        local control = Create("TextButton", {
            Name = name, Text = text, Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(w, h), BackgroundColor3 = background,
            TextColor3 = ink, TextSize = 15, Font = FONT.Bold,
            AutoButtonColor = false, BorderSizePixel = 0, Parent = parent,
        })
        if ghost then control.BackgroundTransparency = 1 end
        UI.SetText(control, "Text", text)
        corner(control, Style.Theme.R_CTRL)
        connect(control.MouseEnter, function()
            if not State.Done then
                animate(control, CONFIG.Motion.Hover, ghost
                    and {BackgroundTransparency = 0.92, TextColor3 = C.Text}
                    or {BackgroundColor3 = background:Lerp(C.Text, 0.07)})
            end
        end)
        connect(control.MouseLeave, function()
            if not State.Done then
                animate(control, CONFIG.Motion.Hover, ghost
                    and {BackgroundTransparency = 1, TextColor3 = ink}
                    or {BackgroundColor3 = background})
            end
        end)
        local pulse = pressFeedback(control, name == "Submit" and C.AccentInk or C.Accent)
        connect(control.Activated, pulse)
        return control
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 2: ОКНО И КОНТРОЛЫ
    -- ══════════════════════════════════════════════════════════════════════════

    function UI.Build(parent)
        local screen = Create("ScreenGui", {
            Name = CONFIG.GuiName, ResetOnSpawn = false, IgnoreGuiInset = true,
            DisplayOrder = CONFIG.DisplayOrder, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        })
        -- Регистрируем сразу: ошибка при сборке тоже должна удалить всё окно.
        State.Screen = screen
        screen.Parent = parent
        local panel = Style.WindowShell(screen, UDim2.fromOffset(CONFIG.Width, CONFIG.Height),
            UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
        panel.Name = "Panel"
        State.Panel = panel
        local scale = Create("UIScale", {Name = "Fit", Scale = 1, Parent = panel})
        local attached, acrylic = pcall(Style.AttachAcrylic, panel)
        if attached then State.Acrylic = acrylic end
        if not State.Acrylic then
            -- Тот же резервный эффект, что в основном меню, если стекло недоступно.
            pcall(function()
                State.Blur = Create("BlurEffect", {Name = CONFIG.GuiName .. "_Blur",
                    Size = Style.BlurSize, Parent = Services.Lighting})
            end)
        end

        local sidebarWidth, edge = 180, 24
        local contentX, contentWidth = sidebarWidth + edge, CONFIG.Width - sidebarWidth - edge * 2
        local sidebar = Create("Frame", {Name = "Sidebar", BackgroundTransparency = 1,
            Size = UDim2.new(0, sidebarWidth, 1, -32), Parent = panel})
        Style.BrandMark(sidebar, UDim2.fromOffset(14, 17))
        label(sidebar, "Brand", "Violite", 48, 15, 126, 20, 20, C.Text, FONT.Head)
        label(sidebar, "Game", "Murder Mystery 2", 48, 35, 128, 16, 13, C.Muted)
        hairline({Position = UDim2.fromOffset(sidebarWidth, 0), Size = UDim2.new(0, 1, 1, -32),
            BackgroundColor3 = C.Border, Parent = panel})
        hairline({Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = C.Border, Parent = panel})
        local active = Create("Frame", {Name = "ActiveSection", Position = UDim2.fromOffset(10, 72),
            Size = UDim2.fromOffset(160, 36), BackgroundColor3 = C.Accent,
            BackgroundTransparency = 0.88, BorderSizePixel = 0, Parent = sidebar})
        corner(active, Style.Theme.R_CTRL)
        label(active, "Label", "Доступ к скрипту", 12, 0, 136, 36, 16, C.Accent, FONT.Bold)
        local hint = label(sidebar, "Hint", "Нажми на кнопку, чтобы получить ключ.", 22, 322, 142, 48, 14, C.Muted)
        hint.TextWrapped = true
        hint.TextYAlignment = Enum.TextYAlignment.Bottom
        if CONFIG.KeyUrl ~= "" then
            local getKey = button(sidebar, "GetKey", "Получить ключ", 14, 378, 152, 34, C.Surface, C.Accent)
            Style.Stroke(getKey, 1, C.Border)
            connect(getKey.Activated, env.OnGetKey)
            function UI.ShowLinkCopied()
                if State.CopyResetThread then pcall(task.cancel, State.CopyResetThread) end
                UI.SetText(getKey, "Text", "Ссылка скопирована")
                getKey.TextSize = 13
                UI.SetText(hint, "Text", "Вставь ссылку в браузер.")
                State.CopyResetThread = task.delay(CONFIG.CopyNoticeSeconds, function()
                    State.CopyResetThread = nil
                    if State.Done then return end
                    UI.SetText(getKey, "Text", "Получить ключ")
                    getKey.TextSize = 15
                    UI.SetText(hint, "Text", "Нажми на кнопку, чтобы получить ключ.")
                end)
            end
        end
        -- Зона перетаскивания совпадает с шапкой меню и не перекрывает крестик.
        local header = Create("Frame", {Name = "Header", BackgroundTransparency = 1, Active = true,
            Position = UDim2.fromOffset(sidebarWidth, 0), Size = UDim2.fromOffset(CONFIG.Width - sidebarWidth - 50, 56), Parent = panel})
        label(header, "Title", "Авторизация", edge, 0, 300, 56, 22, C.Text, FONT.Head)
        local close = button(panel, "Close", "", CONFIG.Width - 40, 16, 24, 24, C.Canvas, C.Muted)
        close.BackgroundTransparency = 1
        for _, rotation in ipairs({45, -45}) do
            Create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(12, 1), Rotation = rotation,
                BorderSizePixel = 0, BackgroundColor3 = C.Muted, Parent = close})
        end
        label(panel, "Welcome", "Добро пожаловать в Violite", contentX, 80, contentWidth, 30, 22, C.Text, FONT.Head)
        label(panel, "Description", "Введите ключ доступа, чтобы продолжить.", contentX, 116, contentWidth, 24, 14, C.Muted)
        local card = Create("Frame", {Name = "AccessCard", Position = UDim2.fromOffset(contentX, 160),
            Size = UDim2.fromOffset(contentWidth, 164), BackgroundColor3 = C.Surface,
            BackgroundTransparency = Style.CardTransparency, BorderSizePixel = 0, Parent = panel})
        corner(card, 12)
        Style.Stroke(card, 1, C.Border)
        label(card, "KeyLabel", "Ключ доступа", 16, 12, contentWidth - 32, 24, 16, C.Text, FONT.Bold)
        local keyBox = Create("TextBox", {
            Name = "KeyInput", Position = UDim2.fromOffset(16, 46), Size = UDim2.fromOffset(contentWidth - 32, 42),
            BackgroundColor3 = C.Input, BorderSizePixel = 0, Text = State.InitialKey or "",
            PlaceholderText = "Вставьте ваш ключ", PlaceholderColor3 = C.Muted,
            TextColor3 = C.Text, TextSize = 15, Font = FONT.Mono,
            TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
            MultiLine = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
        })
        UI.SetText(keyBox, "PlaceholderText", "Вставьте ваш ключ")
        corner(keyBox, Style.Theme.R_CTRL)
        local keyStroke = Style.Stroke(keyBox, 1, C.Border)
        Create("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = keyBox})
        State.KeyBox = keyBox
        hairline({Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 1), Parent = card})
        local remember = button(card, "Remember", "", 16, 116, contentWidth - 32, 30, C.Surface, C.Muted)
        remember.BackgroundTransparency = 1
        local check = Create("Frame", {Name = "Check", Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(18, 18),
            BackgroundColor3 = C.Input, BorderSizePixel = 0, Parent = remember})
        corner(check, 4)
        local checkStroke = Style.Stroke(check, 1, C.Border)
        -- Векторная галочка: ровные линии вместо зависимого от шрифта символа.
        local tick = Create("Frame", {Name = "Selected", BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1), Parent = check})
        for _, segment in ipairs({{6, 10, 5, 45}, {10, 8, 9, -45}}) do
            local line = Create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(segment[1], segment[2]),
                Size = UDim2.fromOffset(segment[3], 2), Rotation = segment[4],
                BackgroundColor3 = C.AccentInk, BorderSizePixel = 0, Parent = tick})
            corner(line, 1)
        end
        label(remember, "Label", "Запомнить ключ на устройстве", 28, 0, contentWidth - 60, 30, 14, C.Text)
        local launch = button(panel, "Submit", "Запустить Violite", contentX, 344, contentWidth, 42, C.Accent, C.AccentInk)
        local status = label(panel, "Status", "", contentX, 394, contentWidth, 30, 12, C.Muted)
        status.TextWrapped = true
        status.TextYAlignment = Enum.TextYAlignment.Top
        State.StatusLabel = status
        hairline({Position = UDim2.new(0, 0, 1, -32), Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = C.Border, Parent = panel})
        label(panel, "Footer", "VIOLITE  /  MM2", 14, CONFIG.Height - 32, 180, 32, 13, C.Muted)
        local mode = label(panel, "Mode", CONFIG.Preview and "Предпросмотр" or "Авторизация через Jnkie",
            214, CONFIG.Height - 32, 276, 32, 13, C.Muted)
        mode.TextXAlignment = Enum.TextXAlignment.Right
        local language = button(panel, "Language", "Language: Auto",
            CONFIG.Width - 140, CONFIG.Height - 29, 126, 26, C.Text, C.Muted, true)
        language.TextSize = 13
        connect(language.Activated, function()
            local nextMode = {Auto = "Ru", Ru = "En", En = "Auto"}
            State.LanguageMode = nextMode[State.LanguageMode] or "Auto"
            UI.SetText(language, "Text", "Language: " .. State.LanguageMode)
            refreshLanguage()
        end)
        local pulseCheck = pressFeedback(check, C.AccentInk)

        local function refreshRemember(animated)
            local fill = State.Remember and C.Accent or C.Input
            local border = State.Remember and C.Accent or C.Muted
            if animated then
                animate(check, CONFIG.Motion.Toggle, {BackgroundColor3 = fill})
                animate(checkStroke, CONFIG.Motion.Toggle, {Color = border})
            else
                check.BackgroundColor3 = fill
                checkStroke.Color = border
            end
            tick.Visible = State.Remember
            remember.Selectable = State.CanPersist
            remember.Active = State.CanPersist
        end
        refreshRemember()
        connect(remember.Activated, function()
            if not State.CanPersist then
                UI.SetStatus("Этот executor не поддерживает сохранение ключа.", true)
                return
            end
            State.Remember = not State.Remember
            refreshRemember(true)
            pulseCheck()
        end)
        local function submitAfterPress()
            if State.Done or State.Busy or State.SubmitThread then return end
            local value = keyBox.Text
            State.SubmitThread = task.delay(CONFIG.Motion.PressDelay, function()
                State.SubmitThread = nil
                if not State.Done then env.OnSubmit(value) end
            end)
        end
        connect(keyBox.Focused, function() animate(keyStroke, CONFIG.Motion.Hover, {Color = C.Accent}) end)
        connect(keyBox.FocusLost, function(enterPressed)
            animate(keyStroke, CONFIG.Motion.Hover, {Color = C.Border})
            if enterPressed then submitAfterPress() end
        end)
        connect(keyBox:GetPropertyChangedSignal("Text"), function()
            if #keyBox.Text > CONFIG.MaxKeyLength then keyBox.Text = keyBox.Text:sub(1, CONFIG.MaxKeyLength) end
        end)
        connect(launch.Activated, submitAfterPress)
        connect(close.Activated, env.OnClose)
        connect(screen.Destroying, env.OnClose)

        -- ══════════════════════════════════════════════════════════════════════
        -- БЛОК 3: МЫШЬ, СЕНСОРНЫЙ ВВОД И РАЗМЕР ЭКРАНА
        -- ══════════════════════════════════════════════════════════════════════
        local function fit()
            if State.Done then return end
            local camera = Services.Workspace.CurrentCamera
            if not camera then return end
            local size = camera.ViewportSize
            scale.Scale = math.min(1, math.max(0.1, math.min((size.X - 32) / CONFIG.Width, (size.Y - 32) / CONFIG.Height)))
            local half = Vector2.new(CONFIG.Width, CONFIG.Height) * scale.Scale * 0.5
            local position = panel.Position
            local x = math.clamp(size.X * position.X.Scale + position.X.Offset, half.X + 8, math.max(half.X + 8, size.X - half.X - 8))
            local y = math.clamp(size.Y * position.Y.Scale + position.Y.Offset, half.Y + 8, math.max(half.Y + 8, size.Y - half.Y - 8))
            panel.Position = UDim2.fromOffset(x, y)
        end
        local function watchCamera()
            if State.CameraConnection then State.CameraConnection:Disconnect() end
            local camera = Services.Workspace.CurrentCamera
            if camera then State.CameraConnection = connect(camera:GetPropertyChangedSignal("ViewportSize"), fit) end
            fit()
        end
        connect(Services.Workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)
        watchCamera()
        connect(header.InputBegan, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            State.DragInput, State.DragOrigin, State.DragPosition = input, input.Position, panel.Position
        end)
        connect(Services.UserInputService.InputChanged, function(input)
            if not State.DragInput or State.Done then return end
            if input ~= State.DragInput and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local delta = input.Position - State.DragOrigin
            panel.Position = State.DragPosition + UDim2.fromOffset(delta.X, delta.Y)
            fit()
        end)
        connect(Services.UserInputService.InputEnded, function(input)
            if input == State.DragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then State.DragInput = nil end
        end)
        connect(Services.LocalizationService:GetPropertyChangedSignal("RobloxLocaleId"), refreshLanguage)
        UI.SetStatus("")
        return UI
    end

    function UI.SetStatus(text, isError)
        if State.Done or not State.StatusLabel then return end
        UI.SetText(State.StatusLabel, "Text", text)
        State.StatusLabel.TextColor3 = isError and C.Danger or C.Muted
    end

    function UI.ClearKey()
        if State.KeyBox then State.KeyBox.Text = "" end
    end

    return UI
end
