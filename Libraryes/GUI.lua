-- GUI.lua
-- Библиотека GUI для MM2 скрипта

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
            Color = color or CONFIG.Colors.Stroke,
            Transparency = transparency or 0.5,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = parent
        })
    end

    ----------------------------------------------------------------
    -- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ИЗ MAIN, КОТОРЫЕ НУЖНЫ GUI
    -- (ЭТИ ФУНКЦИИ ДОЛЖНЫ БЫТЬ ПЕРЕДАНЫ ЧЕРЕЗ Handlers)
    ----------------------------------------------------------------
    -- Весь прямой вызов игровых функций заменяем на Handlers.*

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
            BackgroundColor3 = CONFIG.Colors.Background,
            Position = UDim2.new(0.5, -225, 0.5, -325),
            Size = UDim2.new(0, 450, 0, 650),
            ClipsDescendants = false,
            Active = true,
            Draggable = true,
            Parent = gui
        })
        AddCorner(mainFrame, 12)
        AddStroke(mainFrame, 2, CONFIG.Colors.Accent, 0.8)

        local header = Create("Frame", {
            Name = "Header",
            BackgroundColor3 = CONFIG.Colors.Section,
            Size = UDim2.new(1, 0, 0, 40),
            Parent = mainFrame
        })
        AddCorner(header, 12)

        local titleLabel = Create("TextLabel", {
            Text = "MM2 <font color=\"rgb(128, 0, 128)\">for my кошичка жена!</font>",
            RichText = true,
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            TextColor3 = CONFIG.Colors.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 15, 0, 0),
            Size = UDim2.new(0.8, 0, 1, 0),
            Parent = header
        })

        local closeButton = Create("TextButton", {
            Text = "X",
            Font = Enum.Font.GothamMedium,
            TextSize = 24,
            TextColor3 = CONFIG.Colors.TextDark,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -35, 0, 0),
            Size = UDim2.new(0, 35, 0, 40),
            Parent = header
        })

        local tabContainer = Create("ScrollingFrame", {
            Name = "TabContainer",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 45),
            Size = UDim2.new(1, -20, 0, 35),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 0,
            Parent = mainFrame
        })

        local tabLayout = Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = tabContainer
        })

        tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tabContainer.CanvasSize = UDim2.new(0, tabLayout.AbsoluteContentSize.X + 10, 0, 0)
        end)

        local pagesContainer = Create("Frame", {
            Name = "PagesContainer",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 15, 0, 90),
            Size = UDim2.new(1, -30, 1, -115),
            Parent = mainFrame
        })

        local Tabs = {}
        local currentTab = nil

        ----------------------------------------------------------------
        -- ВНУТРЕННИЙ КОНСТРУКТОР ТАБА + TabFunctions
        ----------------------------------------------------------------

        local function CreateTab(name)
            local tabBtn = Create("TextButton", {
                Text = name,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextColor3 = CONFIG.Colors.TextDark,
                BackgroundColor3 = CONFIG.Colors.Section,
                Size = UDim2.new(0, 0, 1, 0),
                AutoButtonColor = false,
                Parent = tabContainer
            })
            AddCorner(tabBtn, 6)

            local textWidth = game:GetService("TextService"):GetTextSize(
                name, 13, Enum.Font.GothamBold, Vector2.new(999, 35)
            ).X
            tabBtn.Size = UDim2.new(0, textWidth + 20, 1, 0)

            local page = Create("ScrollingFrame", {
                Name = name .. "Page",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 6,
                ScrollBarImageColor3 = CONFIG.Colors.Accent,
                Visible = false,
                Parent = pagesContainer
            })

            local pageLayout = Create("UIListLayout", {
                Padding = UDim.new(0, 12),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = page
            })

            pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                page.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 20)
            end)

            local function Activate()
                if State.UIElements.OpenDropdowns then
                    for _, closeFunc in ipairs(State.UIElements.OpenDropdowns) do
                        pcall(closeFunc)
                    end
                end
                if currentTab then
                    TweenService:Create(
                        currentTab.Btn,
                        TweenInfo.new(0.2),
                        {BackgroundColor3 = CONFIG.Colors.Section, TextColor3 = CONFIG.Colors.TextDark}
                    ):Play()
                    currentTab.Page.Visible = false
                end
                currentTab = {Btn = tabBtn, Page = page}
                TweenService:Create(
                    tabBtn,
                    TweenInfo.new(0.2),
                    {BackgroundColor3 = CONFIG.Colors.Accent, TextColor3 = CONFIG.Colors.Text}
                ):Play()
                page.Visible = true
            end

            tabBtn.MouseButton1Click:Connect(Activate)

            if #Tabs == 0 then
                Activate()
            end
            table.insert(Tabs, {Btn = tabBtn, Page = page})

            --------------------------------------------
            -- TabFunctions (1:1, но через Handlers)
            --------------------------------------------
            local TabFunctions = {}

            function TabFunctions:CreateSection(title)
                Create("TextLabel", {
                    Text = title,
                    Font = Enum.Font.GothamBold,
                    TextSize = 13,
                    TextColor3 = CONFIG.Colors.TextDark,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 22),
                    Parent = page
                })
            end

            function TabFunctions:CreateDropdown(title, desc, options, default, handlerKey)
                local card = Create("Frame", {
                    BackgroundColor3 = CONFIG.Colors.Section,
                    Size = UDim2.new(1, 0, 0, 60),
                    Parent = page
                })
                AddCorner(card, 8)
                AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

                Create("TextLabel", {
                    Text = title,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 14,
                    TextColor3 = CONFIG.Colors.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 15, 0, 10),
                    Size = UDim2.new(0, 250, 0, 20),
                    Parent = card
                })

                Create("TextLabel", {
                    Text = desc,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextColor3 = CONFIG.Colors.TextDark,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 15, 0, 30),
                    Size = UDim2.new(0, 250, 0, 20),
                    Parent = card
                })

                local dropdown = Create("TextButton", {
                    Text = default .. " ▼",
                    Font = Enum.Font.GothamMedium,
                    TextSize = 11,
                    TextColor3 = CONFIG.Colors.Text,
                    BackgroundColor3 = Color3.fromRGB(45, 45, 50),
                    Position = UDim2.new(1, -110, 0.5, -12),
                    Size = UDim2.new(0, 95, 0, 24),
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = card
                })
                AddCorner(dropdown, 6)
                AddStroke(dropdown, 1, CONFIG.Colors.Accent, 0.6)

                local dropdownFrame = Create("ScrollingFrame", {
                    BackgroundColor3 = CONFIG.Colors.Section,
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, 95, 0, 0),
                    Visible = false,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness = 4,
                    ScrollBarImageColor3 = CONFIG.Colors.Accent,
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ClipsDescendants = false,
                    ZIndex = 1000,
                    Parent = mainFrame
                })
                AddCorner(dropdownFrame, 6)
                AddStroke(dropdownFrame, 1, CONFIG.Colors.Accent, 0.6)

                local listLayout = Create("UIListLayout", {
                    Padding = UDim.new(0, 2),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = dropdownFrame
                })

                local function fire(option)
                    callHandler(handlerKey, option)
                end

                for _, option in ipairs(options) do
                    local optionBtn = Create("TextButton", {
                        Text = option,
                        Font = Enum.Font.Gotham,
                        TextSize = 10,
                        TextColor3 = CONFIG.Colors.Text,
                        BackgroundColor3 = Color3.fromRGB(50, 50, 55),
                        Size = UDim2.new(1, 0, 0, 25),
                        AutoButtonColor = false,
                        ZIndex = 1001,
                        Parent = dropdownFrame
                    })
                    AddCorner(optionBtn, 4)

                    optionBtn.MouseButton1Click:Connect(function()
                        dropdown.Text = option .. " ▼"
                        fire(option)
                        TweenService:Create(
                            dropdownFrame,
                            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                            {Size = UDim2.new(0, 95, 0, 0)}
                        ):Play()
                        task.wait(0.2)
                        dropdownFrame.Visible = false
                    end)

                    optionBtn.MouseEnter:Connect(function()
                        TweenService:Create(optionBtn, TweenInfo.new(0.15), {
                            BackgroundColor3 = CONFIG.Colors.Accent
                        }):Play()
                    end)

                    optionBtn.MouseLeave:Connect(function()
                        TweenService:Create(optionBtn, TweenInfo.new(0.15), {
                            BackgroundColor3 = Color3.fromRGB(50, 50, 55)
                        }):Play()
                    end)
                end

                dropdown.MouseButton1Click:Connect(function()
                    dropdownFrame.Visible = not dropdownFrame.Visible

                    if dropdownFrame.Visible then
                        local dropdownAbsPos = dropdown.AbsolutePosition
                        local dropdownAbsSize = dropdown.AbsoluteSize
                        local mainFramePos = mainFrame.AbsolutePosition

                        local calculatedHeight = math.min(100, #options * 27)

                        dropdownFrame.Position = UDim2.new(
                            0, dropdownAbsPos.X - mainFramePos.X,
                            0, dropdownAbsPos.Y - mainFramePos.Y + dropdownAbsSize.Y + 5
                        )

                        dropdownFrame.Size = UDim2.new(0, 95, 0, 0)
                        TweenService:Create(
                            dropdownFrame,
                            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            {Size = UDim2.new(0, 95, 0, calculatedHeight)}
                        ):Play()
                    else
                        TweenService:Create(
                            dropdownFrame,
                            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                            {Size = UDim2.new(0, 95, 0, 0)}
                        ):Play()
                        task.wait(0.2)
                        dropdownFrame.Visible = false
                    end
                end)

                return dropdown
            end

            function TabFunctions:CreateToggle(title, desc, handlerKey)
                local card = Create("Frame", {
                    BackgroundColor3 = CONFIG.Colors.Section,
                    Size = UDim2.new(1, 0, 0, 60),
                    Parent = page
                })
                AddCorner(card, 8)
                AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

                Create("TextLabel", {
                    Text = title,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 14,
                    TextColor3 = CONFIG.Colors.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 15, 0, 10),
                    Size = UDim2.new(0, 250, 0, 20),
                    Parent = card
                })

                Create("TextLabel", {
                    Text = desc,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextColor3 = CONFIG.Colors.TextDark,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 15, 0, 30),
                    Size = UDim2.new(0, 250, 0, 20),
                    Parent = card
                })

                local toggleBg = Create("TextButton", {
                    Text = "",
                    BackgroundColor3 = Color3.fromRGB(50, 50, 55),
                    Position = UDim2.new(1, -60, 0.5, -12),
                    Size = UDim2.new(0, 44, 0, 24),
                    AutoButtonColor = false,
                    Parent = card
                })
                AddCorner(toggleBg, 24)

                local toggleCircle = Create("Frame", {
                    BackgroundColor3 = CONFIG.Colors.Text,
                    Position = UDim2.new(0, 2, 0.5, -10),
                    Size = UDim2.new(0, 20, 0, 20),
                    Parent = toggleBg
                })
                AddCorner(toggleCircle, 20)

                local state = false
                TrackConnection(toggleBg.MouseButton1Click:Connect(function()
                    state = not state
                    local targetColor = state and CONFIG.Colors.Accent or Color3.fromRGB(50, 50, 55)
                    local targetPos = state and UDim2.new(0, 22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)

                    TweenService:Create(toggleBg, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
                    TweenService:Create(toggleCircle, TweenInfo.new(0.2), {Position = targetPos}):Play()

                    callHandler(handlerKey, state)
                end))
                return toggleBg
            end

            function TabFunctions:CreateInputField(title, desc, defaultValue, handlerKey)
                local card = Create("Frame", {
                    BackgroundColor3 = CONFIG.Colors.Section,
                    Size = UDim2.new(1, 0, 0, 60),
                    Parent = page
                })
                AddCorner(card, 8)
                AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

                Create("TextLabel", {
                    Text = title,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 14,
                    TextColor3 = CONFIG.Colors.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 15, 0, 10),
                    Size = UDim2.new(0, 250, 0, 20),
                    Parent = card
                })

                Create("TextLabel", {
                    Text = desc,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextColor3 = CONFIG.Colors.TextDark,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 15, 0, 30),
                    Size = UDim2.new(0, 250, 0, 20),
                    Parent = card
                })

                local inputBox = Create("TextBox", {
                    Text = tostring(defaultValue),
                    Font = Enum.Font.GothamMedium,
                    TextSize = 13,
                    TextColor3 = CONFIG.Colors.Text,
                    BackgroundColor3 = Color3.fromRGB(45, 45, 50),
                    Position = UDim2.new(1, -80, 0.5, -12),
                    Size = UDim2.new(0, 65, 0, 24),
                    PlaceholderText = "Value",
                    ClearTextOnFocus = false,
                    Parent = card
                })
                AddCorner(inputBox, 6)
                AddStroke(inputBox, 1, CONFIG.Colors.Accent, 0.6)

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
                local card = Create("Frame", {
                    BackgroundColor3 = CONFIG.Colors.Section,
                    Size = UDim2.new(1, 0, 0, 70),
                    Parent = page
                })
                AddCorner(card, 8)
                AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

                Create("TextLabel", {
                    Text = title,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 14,
                    TextColor3 = CONFIG.Colors.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 15, 0, 10),
                    Size = UDim2.new(0, 250, 0, 20),
                    Parent = card
                })

                Create("TextLabel", {
                    Text = description,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextColor3 = CONFIG.Colors.TextDark,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 15, 0, 30),
                    Size = UDim2.new(0, 250, 0, 20),
                    Parent = card
                })

                local sliderBg = Create("Frame", {
                    BackgroundColor3 = Color3.fromRGB(40, 40, 45),
                    Position = UDim2.new(0, 15, 0, 50),
                    Size = UDim2.new(1, -95, 0, 6),
                    Parent = card
                })
                AddCorner(sliderBg, 3)

                local sliderFill = Create("Frame", {
                    BackgroundColor3 = CONFIG.Colors.Accent,
                    Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
                    Parent = sliderBg
                })
                AddCorner(sliderFill, 3)

                local sliderButton = Create("TextButton", {
                    Text = "",
                    BackgroundColor3 = CONFIG.Colors.Text,
                    Position = UDim2.new((default - min) / (max - min), -8, 0.5, -8),
                    Size = UDim2.new(0, 16, 0, 16),
                    AutoButtonColor = false,
                    Parent = sliderBg
                })
                AddCorner(sliderButton, 16)

                local valueLabel = Create("TextLabel", {
                    Text = step >= 1 and string.format("%d", default) or string.format("%.2f", default),
                    Font = Enum.Font.GothamBold,
                    TextSize = 12,
                    TextColor3 = CONFIG.Colors.Accent,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -65, 0, 8),
                    Size = UDim2.new(0, 50, 0, 20),
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = card
                })

                local dragging = false
                local function updateSlider(input)
                    local pos = sliderBg.AbsolutePosition.X
                    local size = sliderBg.AbsoluteSize.X
                    local mouseX = input.Position.X

                    local alpha = math.clamp((mouseX - pos) / size, 0, 1)
                    local value = min + (alpha * (max - min))

                    value = math.floor(value / step + 0.5) * step
                    value = math.clamp(value, min, max)

                    local normalizedValue = (value - min) / (max - min)
                    sliderFill.Size = UDim2.new(normalizedValue, 0, 1, 0)
                    sliderButton.Position = UDim2.new(normalizedValue, -8, 0.5, -8)

                    if step >= 1 then
                        valueLabel.Text = string.format("%d", value)
                    else
                        valueLabel.Text = string.format("%.2f", value)
                    end

                    callHandler(handlerKey, value)
                end

                sliderButton.MouseButton1Down:Connect(function() dragging = true end)
                sliderBg.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        updateSlider(input)
                    end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        updateSlider(input)
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
                end)
            end

            function TabFunctions:CreateKeybindButton(title, emoteId, keybindKey)
                local card = Create("Frame", {
                    BackgroundColor3 = CONFIG.Colors.Section,
                    Size = UDim2.new(1, 0, 0, 50),
                    Parent = page
                })
                AddCorner(card, 8)
                AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

                Create("TextLabel", {
                    Text = title,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 14,
                    TextColor3 = CONFIG.Colors.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 15, 0, 0),
                    Size = UDim2.new(0, 200, 1, 0),
                    Parent = card
                })

                local bindButton = Create("TextButton", {
                    Name = keybindKey .. "_Button",
                    Text = State.Keybinds[keybindKey] ~= Enum.KeyCode.Unknown
                        and State.Keybinds[keybindKey].Name or "Not Bound",
                    Font = Enum.Font.GothamMedium,
                    TextSize = 12,
                    TextColor3 = CONFIG.Colors.Text,
                    BackgroundColor3 = Color3.fromRGB(45, 45, 50),
                    Position = UDim2.new(1, -110, 0.5, -15),
                    Size = UDim2.new(0, 95, 0, 30),
                    AutoButtonColor = false,
                    Parent = card
                })
                AddCorner(bindButton, 6)
                AddStroke(bindButton, 1, CONFIG.Colors.Accent, 0.6)

                State.UIElements[keybindKey .. "_Button"] = bindButton

                bindButton.MouseButton1Click:Connect(function()
                    bindButton.Text = "Press Key..."
                    State.ListeningForKeybind = {key = keybindKey, button = bindButton}
                end)

                return bindButton
            end

            function TabFunctions:CreatePlayerDropdown(title, desc)
                local card = Create("Frame", {
                    BackgroundColor3 = CONFIG.Colors.Section,
                    Size = UDim2.new(1, 0, 0, 60),
                    Parent = page
                })
                AddCorner(card, 8)
                AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

                Create("TextLabel", {
                    Text = title,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 14,
                    TextColor3 = CONFIG.Colors.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 15, 0, 10),
                    Size = UDim2.new(0, 250, 0, 20),
                    Parent = card
                })

                Create("TextLabel", {
                    Text = desc,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextColor3 = CONFIG.Colors.TextDark,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 15, 0, 30),
                    Size = UDim2.new(0, 250, 0, 20),
                    Parent = card
                })

                local dropdown = Create("TextButton", {
                    Text = "Select Player ▼",
                    Font = Enum.Font.GothamMedium,
                    TextSize = 11,
                    TextColor3 = CONFIG.Colors.Text,
                    BackgroundColor3 = Color3.fromRGB(45, 45, 50),
                    Position = UDim2.new(1, -180, 0.5, -12),
                    Size = UDim2.new(0, 165, 0, 24),
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = card
                })
                AddCorner(dropdown, 6)
                AddStroke(dropdown, 1, CONFIG.Colors.Accent, 0.6)

                local dropdownFrame = Create("ScrollingFrame", {
                    BackgroundColor3 = CONFIG.Colors.Section,
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, 165, 0, 0),
                    Visible = false,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness = 4,
                    ScrollBarImageColor3 = CONFIG.Colors.Accent,
                    ClipsDescendants = true,
                    BorderSizePixel = 0,
                    ZIndex = 1000,
                    Parent = mainFrame
                })
                AddCorner(dropdownFrame, 6)
                AddStroke(dropdownFrame, 1, CONFIG.Colors.Accent, 0.6)

                local listLayout = Create("UIListLayout", {
                    Padding = UDim.new(0, 2),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = dropdownFrame
                })

                local function closeDropdown()
                    if dropdownFrame.Visible then
                        TweenService:Create(
                            dropdownFrame,
                            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                            {Size = UDim2.new(0, 165, 0, 0)}
                        ):Play()
                        task.wait(0.2)
                        dropdownFrame.Visible = false
                    end
                end

                local function updatePlayerList()
                    for _, child in ipairs(dropdownFrame:GetChildren()) do
                        if child:IsA("TextButton") then
                            child:Destroy()
                        end
                    end

                    local players = getAllPlayers()
                    if #players == 0 then
                        Create("TextLabel", {
                            Text = "No players",
                            Font = Enum.Font.Gotham,
                            TextSize = 11,
                            TextColor3 = CONFIG.Colors.TextDark,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, -10, 0, 25),
                            ZIndex = 1001,
                            Parent = dropdownFrame
                        })
                        dropdownFrame.CanvasSize = UDim2.new(0, 0, 0, 30)
                        return
                    end

                    local buttonHeight = 28
                    local buttonSpacing = 2
                    local totalHeight = #players * (buttonHeight + buttonSpacing) + 5

                    dropdownFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)

                    for _, playerName in ipairs(players) do
                        local pb = Create("TextButton", {
                            Text = playerName,
                            Font = Enum.Font.Gotham,
                            TextSize = 11,
                            TextColor3 = CONFIG.Colors.Text,
                            BackgroundColor3 = Color3.fromRGB(50, 50, 55),
                            Size = UDim2.new(1, -10, 0, buttonHeight),
                            Position = UDim2.new(0, 5, 0, 0),
                            AutoButtonColor = false,
                            ZIndex = 1001,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextTruncate = Enum.TextTruncate.AtEnd,
                            Parent = dropdownFrame
                        })
                        AddCorner(pb, 4)

                        local padding = Instance.new("UIPadding")
                        padding.PaddingLeft = UDim.new(0, 8)
                        padding.Parent = pb

                        pb.MouseButton1Click:Connect(function()
                            State.SelectedPlayerForFling = playerName
                            dropdown.Text = (#playerName > 12 and playerName:sub(1, 12) .. "..." or playerName)
                            closeDropdown()
                        end)

                        pb.MouseEnter:Connect(function()
                            TweenService:Create(pb, TweenInfo.new(0.15), {
                                BackgroundColor3 = CONFIG.Colors.Accent
                            }):Play()
                        end)

                        pb.MouseLeave:Connect(function()
                            TweenService:Create(pb, TweenInfo.new(0.15), {
                                BackgroundColor3 = Color3.fromRGB(50, 50, 55)
                            }):Play()
                        end)
                    end
                end

                dropdown.MouseButton1Click:Connect(function()
                    dropdownFrame.Visible = not dropdownFrame.Visible

                    if dropdownFrame.Visible then
                        updatePlayerList()

                        local dropdownAbsPos = dropdown.AbsolutePosition
                        local dropdownAbsSize = dropdown.AbsoluteSize
                        local mainFramePos = mainFrame.AbsolutePosition

                        local playerCount = #getAllPlayers()
                        local maxHeight = 150
                        local calculatedHeight = math.min(maxHeight, math.max(30, playerCount * 30))

                        dropdownFrame.Position = UDim2.new(
                            0, dropdownAbsPos.X - mainFramePos.X,
                            0, dropdownAbsPos.Y - mainFramePos.Y + dropdownAbsSize.Y + 5
                        )

                        dropdownFrame.Size = UDim2.new(0, 165, 0, 0)
                        TweenService:Create(
                            dropdownFrame,
                            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            {Size = UDim2.new(0, 165, 0, calculatedHeight)}
                        ):Play()
                    else
                        closeDropdown()
                    end
                end)

                local clickOutsideConnection = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 and dropdownFrame.Visible then
                        local mousePos = UserInputService:GetMouseLocation()
                        local framePos = dropdownFrame.AbsolutePosition
                        local frameSize = dropdownFrame.AbsoluteSize
                        local dropdownPos = dropdown.AbsolutePosition
                        local dropdownSize = dropdown.AbsoluteSize

                        local outsideFrame =
                            mousePos.X < framePos.X or mousePos.X > framePos.X + frameSize.X or
                            mousePos.Y < framePos.Y or mousePos.Y > framePos.Y + frameSize.Y

                        local outsideButton =
                            mousePos.X < dropdownPos.X or mousePos.X > dropdownPos.X + dropdownSize.X or
                            mousePos.Y < dropdownPos.Y or mousePos.Y > dropdownPos.Y + dropdownSize.Y

                        if outsideFrame and outsideButton then
                            closeDropdown()
                        end
                    end
                end)
                table.insert(State.Connections, clickOutsideConnection)

                if not State.UIElements.OpenDropdowns then
                    State.UIElements.OpenDropdowns = {}
                end
                table.insert(State.UIElements.OpenDropdowns, closeDropdown)

                Players.PlayerAdded:Connect(function()
                    if dropdownFrame.Visible then
                        updatePlayerList()
                    end
                end)

                Players.PlayerRemoving:Connect(function()
                    if dropdownFrame.Visible then
                        updatePlayerList()
                    end
                end)

                return dropdown
            end

            function TabFunctions:CreateButton(title, buttonText, color, handlerKey)
                local card = Create("Frame", {
                    BackgroundColor3 = CONFIG.Colors.Section,
                    Size = UDim2.new(1, 0, 0, 50),
                    Parent = page
                })
                AddCorner(card, 8)
                AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

                if title ~= "" and title ~= nil then
                    Create("TextLabel", {
                        Text = title,
                        Font = Enum.Font.GothamMedium,
                        TextSize = 13,
                        TextColor3 = CONFIG.Colors.Text,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 15, 0, 5),
                        Size = UDim2.new(1, -30, 0, 20),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = card
                    })
                end

                local button = Create("TextButton", {
                    Text = buttonText,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 13,
                    TextColor3 = CONFIG.Colors.Text,
                    BackgroundColor3 = color or CONFIG.Colors.Accent,
                    Position = UDim2.new(0, 15, 0.5, -15),
                    Size = UDim2.new(1, -30, 0, 30),
                    AutoButtonColor = false,
                    Parent = card
                })
                AddCorner(button, 6)

                button.MouseButton1Click:Connect(function()
                    callHandler(handlerKey)
                end)

                local useColor = color or CONFIG.Colors.Accent
                button.MouseEnter:Connect(function()
                    local hoverColor = Color3.fromRGB(
                        math.min(255, useColor.R * 255 + 20),
                        math.min(255, useColor.G * 255 + 20),
                        math.min(255, useColor.B * 255 + 20)
                    )
                    TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
                end)

                button.MouseLeave:Connect(function()
                    TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = useColor}):Play()
                end)

                return button
            end

            return TabFunctions
        end

        ----------------------------------------------------------------
        -- СОЗДАНИЕ ВКЛАДОК И ПРИВЯЗКА К Handlers
        ----------------------------------------------------------------

        local MainTab = CreateTab("Main")

        MainTab:CreateSection("CHARACTER SETTINGS")
        MainTab:CreateInputField("WalkSpeed", "Set custom walk speed", State.WalkSpeed, "ApplyWalkSpeed")
        MainTab:CreateInputField("JumpPower", "Set custom jump power", State.JumpPower, "ApplyJumpPower")
        MainTab:CreateInputField("Max Camera Zoom", "Set maximum camera distance", State.MaxCameraZoom, "ApplyMaxCameraZoom")

        MainTab:CreateSection("CAMERA")
        MainTab:CreateInputField("Field of View", "Set custom camera FOV", State.CameraFOV, "ApplyFOV")
        MainTab:CreateToggle("ViewClip", "Camera clips through walls", "ViewClip")

        MainTab:CreateSection("TELEPORT & MOVEMENT")
        MainTab:CreateKeybindButton("Click TP (Hold Key)", "clicktp", "ClickTP")
        MainTab:CreateKeybindButton("Toggle NoClip", "NoClip", "NoClip")

        MainTab:CreateSection("GODMODE")
        MainTab:CreateKeybindButton("Toggle GodMode", "godmode", "GodMode")

        local VisualsTab = CreateTab("Visuals")

        VisualsTab:CreateSection("NOTIFICATIONS")
        VisualsTab:CreateToggle("Enable Notifications", "Show role and gun notifications", "NotificationsEnabled")

        VisualsTab:CreateSection("ESP OPTIONS (Highlight)")
        VisualsTab:CreateToggle("Gun ESP", "Highlight dropped guns", "GunESP")
        VisualsTab:CreateToggle("Murder ESP", "Highlight murderer", "MurderESP")
        VisualsTab:CreateToggle("Sheriff ESP", "Highlight sheriff", "SheriffESP")
        VisualsTab:CreateToggle("Innocent ESP", "Highlight innocent players", "InnocentESP")

        VisualsTab:CreateSection("Misc")
        VisualsTab:CreateToggle("UI Only", "Hide all UI except script GUI", "UIOnly")
        VisualsTab:CreateToggle("Ping Chams", "Show server-side position", "PingChams")
        VisualsTab:CreateToggle("Bullet Tracers", "Show bullet/knife trajectory", "BulletTracers")

        local CombatTab = CreateTab("Combat")
        CombatTab:CreateSection("EXTENDED HITBOX")
        CombatTab:CreateToggle("Enable Extended Hitbox", "Makes all players easier to hit", "ExtendedHitbox")
        CombatTab:CreateSlider("Hitbox Size", "Larger = easier to hit (10-30)", 10, 30, State.ExtendedHitboxSize, "ExtendedHitboxSize", 1)

        CombatTab:CreateSection("MURDERER TOOLS")
        CombatTab:CreateKeybindButton("Fast throw", "knifeThrow", "knifeThrow")
        CombatTab:CreateToggle("Spawn Knife Near Player", "Spawns knife next to target instead of from your hand", "SpawnAtPlayer")
        CombatTab:CreateToggle("Murderer Kill Aura", "Auto kill nearby players", "KillAura")
        CombatTab:CreateKeybindButton("Instant Kill All (Murderer)", "instantkillall", "InstantKillAll")

        CombatTab:CreateSection("SHERIFF TOOLS")
        CombatTab:CreateKeybindButton("Shoot Murderer (Instakill)", "shootmurderer", "ShootMurderer")
        CombatTab:CreateToggle("Instant Pickup Gun", "Auto pickup gun when dropped", "InstantPickup")
        CombatTab:CreateKeybindButton("Pickup Dropped Gun (TP)", "pickupgun", "PickupGun")

        local FarmTab = CreateTab("Farming")
        FarmTab:CreateSection("AUTO FARM")
        FarmTab:CreateToggle("Auto Farm Coins", "Automatic coin collection", "AutoFarm")
        FarmTab:CreateToggle("XP Farm", "Auto win rounds: Kill as Murderer, Shoot as Sheriff, Fling as Innocent", "XPFarm")

        FarmTab:CreateToggle("Underground Mode", "Fly under the map (safer)", "UndergroundMode")
        FarmTab:CreateSlider("Fly Speed", "Flying speed (10-30)", 10, 30, State.CoinFarmFlySpeed, "CoinFarmFlySpeed", 1)
        FarmTab:CreateSlider("TP Delay", "Delay between TPs (0.5-5.0)", 0.5, 5.0, State.CoinFarmDelay, "CoinFarmDelay", 0.5)
        FarmTab:CreateToggle("AFK Mode", "Disable rendering to reduce GPU usage", "AFKMode")
        FarmTab:CreateToggle("Auto reconnect (farm)","Переподключаться каждые 25 минут после завершения раунда",false,"FarmAutoReconnect")
        FarmTab:CreateInputField("Reconnect interval","Интервал в минутах (по умолчанию 25)",25,"FarmReconnectMinutes")
        FarmTab:CreateButton("", "FPS Boost", CONFIG.Colors.Accent, "FPSBoost")

        local FunTab = CreateTab("Fun")
        FunTab:CreateSection("ANIMATION KEYBINDS")
        FunTab:CreateKeybindButton("Sit Animation", "sit", "Sit")
        FunTab:CreateKeybindButton("Dab Animation", "dab", "Dab")
        FunTab:CreateKeybindButton("Zen Animation", "zen", "Zen")
        FunTab:CreateKeybindButton("Ninja Animation", "ninja", "Ninja")
        FunTab:CreateKeybindButton("Floss Animation", "floss", "Floss")

        FunTab:CreateSection("ANTI-FLING")
        FunTab:CreateToggle("Enable Anti-Fling", "Protect yourself from flingers", "AntiFling")
        FunTab:CreateToggle("Walk Fling", "Fling players by walking into them", "WalkFling")
        
        FunTab:CreateSection("FLING PLAYER")
        FunTab:CreatePlayerDropdown("Select Target", "Choose player to fling")
        FunTab:CreateKeybindButton("Fling Selected Player", "fling", "FlingPlayer")
        FunTab:CreateSection("FLING ROLE")
        FunTab:CreateButton("", "Fling Murderer", Color3.fromRGB(255, 85, 85), "FlingMurderer")
        FunTab:CreateButton("", "Fling Sheriff", Color3.fromRGB(90, 140, 255), "FlingSheriff")

        local TrollingTab = CreateTab("Troll")
        TrollingTab:CreateSection("SELECT TARGET")
        TrollingTab:CreatePlayerDropdown("Target Player", "Choose victim for trolling")

        TrollingTab:CreateSection("TROLLING MODES")
        TrollingTab:CreateToggle("Orbit Mode", "Rotate around player (rigid)", "Orbit")
        TrollingTab:CreateToggle("Loop Fling", "Fling player every 3s", "LoopFling")
        TrollingTab:CreateToggle("Block Path", "Block path with pendulum motion", "BlockPath")

        TrollingTab:CreateSection("ORBIT SETTINGS")
        TrollingTab:CreateSlider("Radius", "Distance from target (2-20)", 2, 20, State.OrbitRadius, "OrbitRadius", 0.5)
        TrollingTab:CreateSlider("Speed", "Rotation speed (0.5-15)", 0.5, 15, State.OrbitSpeed, "OrbitSpeed", 0.5)
        TrollingTab:CreateSlider("Height", "Base height (-10 to 20)", -10, 20, State.OrbitHeight, "OrbitHeight", 1)
        TrollingTab:CreateSlider("Tilt", "Orbital angle (-90 to 90)", -90, 90, State.OrbitTilt, "OrbitTilt", 5)

        TrollingTab:CreateSection("BLOCK PATH SETTINGS")
        TrollingTab:CreateSlider("Pendulum Speed", "Movement speed (0.05-0.3)", 0.05, 0.3, State.BlockPathSpeed, "BlockPathSpeed", 0.05)

        TrollingTab:CreateSection("ORBIT PRESETS")
        TrollingTab:CreateButton("", "⚡ Fast Spin", Color3.fromRGB(255, 170, 50), "OrbitPresetFastSpin")
        TrollingTab:CreateButton("", "🎢 Vertical Loop", Color3.fromRGB(255, 85, 85), "OrbitPresetVerticalLoop")
        TrollingTab:CreateButton("", "💫 Chaotic Spin", Color3.fromRGB(200, 100, 200), "OrbitPresetChaoticSpin")

        local UtilityTab = CreateTab("Server")
        UtilityTab:CreateSection("SERVER MANAGEMENT")
        UtilityTab:CreateButton("", "🔄 Rejoin Server", CONFIG.Colors.Accent, "Rejoin")
        UtilityTab:CreateButton("", "🌐 Server Hop", Color3.fromRGB(100, 200, 100), "ServerHop")
        UtilityTab:CreateToggle("Auto Rejoin on kick","Автоматический rejoin при вылете",true,"ServerAutoRejoin")

        local footer = Create("TextLabel", {
            Text = "Toggle Menu: " .. CONFIG.HideKey.Name .. " | Delete = Clear Bind",
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = CONFIG.Colors.TextDark,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, -110, 1, -25),
            Size = UDim2.new(0, 220, 0, 20),
            Parent = mainFrame
        })

        ----------------------------------------------------------------
        -- Кнопка закрытия и обработка инпута (клавиши / клик по GUI)
        ----------------------------------------------------------------

        closeButton.MouseButton1Click:Connect(function()
            callHandler("Shutdown")
        end)

        closeButton.MouseEnter:Connect(function()
            TweenService:Create(closeButton, TweenInfo.new(0.2), {TextColor3 = CONFIG.Colors.Red}):Play()
        end)
        closeButton.MouseLeave:Connect(function()
            TweenService:Create(closeButton, TweenInfo.new(0.2), {TextColor3 = CONFIG.Colors.TextDark}):Play()
        end)

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
    end

    ----------------------------------------------------------------
    -- ПУБЛИЧНЫЙ API
    ----------------------------------------------------------------

    function GUI.Init()
        CreateUI()
    end

    function GUI.Cleanup()
        if State.UIElements.MainGui then
            pcall(function() State.UIElements.MainGui:Destroy() end)
            State.UIElements.MainGui = nil
        end
    end

    return GUI
end
