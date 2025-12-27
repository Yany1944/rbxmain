if game.PlaceId ~= 142823291 then return end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait(2)

-- ==============================================
-- ЗАЩИТА ОТ ДУБЛИКАТОВ
-- ==============================================
if getgenv().MM2_ESP_Script then
    warn("[MM2] Скрипт уже запущен!")
    return
end
getgenv().MM2_ESP_Script = true

-- ==============================================
-- КОНФИГУРАЦИЯ
-- ==============================================
local CONFIG = {
    HideKey = Enum.KeyCode.Q,
    DebugMode = true,

    Colors = {
        Background = Color3.fromRGB(25, 25, 30),
        Section = Color3.fromRGB(35, 35, 40),
        Text = Color3.fromRGB(230, 230, 230),
        TextDark = Color3.fromRGB(150, 150, 150),
        Accent = Color3.fromRGB(90, 140, 255),
        Red = Color3.fromRGB(255, 85, 85),
        Green = Color3.fromRGB(85, 255, 120),
        Orange = Color3.fromRGB(255, 170, 50),
        Stroke = Color3.fromRGB(50, 50, 55),
        Murder = Color3.fromRGB(255, 50, 50),
        Sheriff = Color3.fromRGB(50, 150, 255),
        Gun = Color3.fromRGB(255, 200, 50),
        Innocent = Color3.fromRGB(85, 255, 120)
    }
}

-- ==============================================
-- СЕРВИСЫ
-- ==============================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- ==============================================
-- LOGGER
-- ==============================================
local function Log(category, message)
    if CONFIG.DebugMode then
        print(string.format("[MM2][%s] %s", category, message))
    end
end

-- ==============================================
-- СОСТОЯНИЕ
-- ==============================================
local State = {
    GunESP = false,
    MurderESP = false,
    SheriffESP = false,
    InnocentESP = false,

    -- Character settings
    WalkSpeed = 18,
    JumpPower = 50,
    MaxCameraZoom = 100,

    Keybinds = {
        Sit = Enum.KeyCode.Unknown,
        Dab = Enum.KeyCode.Unknown,
        Zen = Enum.KeyCode.Unknown,
        Ninja = Enum.KeyCode.Unknown,
        Floss = Enum.KeyCode.Unknown,
        ClickTP = Enum.KeyCode.Unknown
    },

    -- Кэш игроков и их ролей
    PlayerCache = {}, -- [userId] = {role = "Murder"/"Sheriff"/"Innocent", espData = {...}}
    GunCache = {}, -- [gunInstance] = espData

    Connections = {},
    PlayerConnections = {}, -- Отдельное хранение для подключений каждого игрока
    UIElements = {},

    ClickTPActive = false,
    ListeningForKeybind = nil,

    UpdateLoop = nil -- Для хранения постоянного цикла обновления
}

-- ==============================================
-- CHARACTER MODIFIERS
-- ==============================================

local function ApplyWalkSpeed(speed)
    local character = LocalPlayer.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = speed
        State.WalkSpeed = speed
        Log("Character", "WalkSpeed установлен: " .. speed)
    end
end

local function ApplyJumpPower(power)
    local character = LocalPlayer.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.JumpPower = power
        State.JumpPower = power
        Log("Character", "JumpPower установлен: " .. power)
    end
end

local function ApplyMaxCameraZoom(distance)
    LocalPlayer.CameraMaxZoomDistance = distance
    State.MaxCameraZoom = distance
    Log("Character", "MaxCameraZoom установлен: " .. distance)
end

-- Применение настроек при респавне
local function ApplyCharacterSettings()
    ApplyWalkSpeed(State.WalkSpeed)
    ApplyJumpPower(State.JumpPower)
    ApplyMaxCameraZoom(State.MaxCameraZoom)
end

-- ==============================================
-- ESP UTILITIES
-- ==============================================

-- Определение роли игрока
local function GetPlayerRole(player)
    if player == LocalPlayer then return "LocalPlayer" end

    local character = player.Character
    if not character then return "Unknown" end

    local backpack = player.Backpack

    -- Проверка на убийцу (нож)
    if character:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife")) then
        return "Murder"
    end

    -- Проверка на шерифа (пистолет)
    if character:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun")) then
        return "Sheriff"
    end

    return "Innocent"
end

-- Создание Highlight
local function CreateHighlight(adornee, color)
    local highlight = Instance.new("Highlight")
    highlight.Adornee = adornee
    highlight.FillColor = color
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0.2
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = true
    highlight.Parent = adornee
    return highlight
end

-- ==============================================
-- ESP ДЛЯ ОРУЖИЯ
-- ==============================================

local function CreateGunESP(gunPart)
    if not gunPart or not gunPart:IsA("BasePart") then return end
    if State.GunCache[gunPart] then return end

    local highlight = CreateHighlight(gunPart, CONFIG.Colors.Gun)

    -- Создаём Billboard для оружия
    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = gunPart
    billboard.Size = UDim2.new(0, 150, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = gunPart

    local textLabel = Instance.new("TextLabel")
    textLabel.Text = "GUN"
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 18
    textLabel.TextColor3 = CONFIG.Colors.Gun
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.Parent = billboard

    State.GunCache[gunPart] = {
        highlight = highlight,
        billboard = billboard,
        textLabel = textLabel
    }

    Log("GunESP", "Создан ESP для оружия")
end

local function RemoveGunESP(gunPart)
    local espData = State.GunCache[gunPart]
    if not espData then return end

    if espData.highlight then espData.highlight:Destroy() end
    if espData.billboard then espData.billboard:Destroy() end
    State.GunCache[gunPart] = nil

    Log("GunESP", "Удалён ESP для оружия")
end

local function UpdateGunESPVisibility()
    for gunPart, espData in pairs(State.GunCache) do
        if espData.highlight then
            espData.highlight.Enabled = State.GunESP
        end
        if espData.billboard then
            espData.billboard.Enabled = State.GunESP
        end
    end
end

-- ==============================================
-- ESP ДЛЯ ИГРОКОВ
-- ==============================================

local function RemovePlayerESP(player)
    local userId = player.UserId
    local cache = State.PlayerCache[userId]

    if not cache then return end

    if cache.espData then
        if cache.espData.highlight then 
            pcall(function() cache.espData.highlight:Destroy() end)
        end
    end

    State.PlayerCache[userId] = nil
    Log("PlayerESP", string.format("Удалён ESP для %s", player.Name))
end

local function CreatePlayerESP(player, role)
    if player == LocalPlayer then return end
    if not player:IsDescendantOf(Players) then return end

    local character = player.Character
    if not character or not character.Parent then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local userId = player.UserId

    -- Определяем цвет на основе роли
    local color, shouldShow
    if role == "Murder" then
        color = CONFIG.Colors.Murder
        shouldShow = State.MurderESP
    elseif role == "Sheriff" then
        color = CONFIG.Colors.Sheriff
        shouldShow = State.SheriffESP
    elseif role == "Innocent" then
        color = CONFIG.Colors.Innocent
        shouldShow = State.InnocentESP
    else
        shouldShow = false
    end

    -- Удаляем старый ESP если он существует
    local cache = State.PlayerCache[userId]
    if cache and cache.espData and cache.espData.highlight then
        pcall(function() cache.espData.highlight:Destroy() end)
    end

    -- Создаём новый ESP
    local success, highlight = pcall(function()
        return CreateHighlight(character, color)
    end)

    if not success or not highlight then
        Log("PlayerESP", string.format("Ошибка создания Highlight для %s", player.Name))
        return
    end

    highlight.Enabled = shouldShow

    State.PlayerCache[userId] = {
        player = player,
        role = role,
        espData = {
            highlight = highlight
        }
    }

    Log("PlayerESP", string.format("Создан ESP для %s (%s)", player.Name, role))
end

local function UpdatePlayerRole(player)
    if not player or player == LocalPlayer then return end
    if not player:IsDescendantOf(Players) then return end
    if not player.Character or not player.Character.Parent then return end

    local role = GetPlayerRole(player)
    CreatePlayerESP(player, role)
end

local function UpdateAllPlayerESPVisibility()
    for userId, cache in pairs(State.PlayerCache) do
        if cache.espData and cache.role and cache.espData.highlight then
            local shouldShow = false

            if cache.role == "Murder" and State.MurderESP then
                shouldShow = true
            elseif cache.role == "Sheriff" and State.SheriffESP then
                shouldShow = true
            elseif cache.role == "Innocent" and State.InnocentESP then
                shouldShow = true
            end

            pcall(function()
                if cache.espData.highlight then
                    cache.espData.highlight.Enabled = shouldShow
                end
            end)
        end
    end
end

-- ==============================================
-- EVENT HANDLERS
-- ==============================================

local function DisconnectPlayerConnections(userId)
    if State.PlayerConnections[userId] then
        for _, connection in ipairs(State.PlayerConnections[userId]) do
            pcall(function() connection:Disconnect() end)
        end
        State.PlayerConnections[userId] = nil
        Log("Connections", "Отключены подключения для userId: " .. userId)
    end
end

local function SetupPlayerTracking(player)
    if player == LocalPlayer then return end

    local userId = player.UserId

    -- Отключаем старые подключения для этого игрока
    DisconnectPlayerConnections(userId)

    -- ВАЖНО: Всегда инициализируем таблицу ПЕРЕД использованием
    State.PlayerConnections[userId] = {}

    -- Отслеживание персонажа
    local function onCharacterAdded(character)
        Log("PlayerTracking", string.format("%s получил персонажа", player.Name))

        -- Удаляем старый ESP
        RemovePlayerESP(player)

        -- Ждём загрузки HumanoidRootPart
        local hrp = character:WaitForChild("HumanoidRootPart", 10)
        if not hrp then 
            Log("PlayerTracking", string.format("HumanoidRootPart не найден для %s", player.Name))
            return 
        end

        task.wait(0.5)

        -- Создаём новый ESP
        UpdatePlayerRole(player)

        -- Проверяем что таблица всё ещё существует
        if not State.PlayerConnections[userId] then
            State.PlayerConnections[userId] = {}
        end

        -- Отслеживание добавления предметов в персонажа
        local charConnection = character.ChildAdded:Connect(function(child)
            if child.Name == "Knife" or child.Name == "Gun" then
                task.wait(0.1)
                UpdatePlayerRole(player)
            end
        end)

        -- Отслеживание удаления предметов из персонажа
        local charRemovedConnection = character.ChildRemoved:Connect(function(child)
            if child.Name == "Knife" or child.Name == "Gun" then
                task.wait(0.1)
                UpdatePlayerRole(player)
            end
        end)

        if State.PlayerConnections[userId] then
            table.insert(State.PlayerConnections[userId], charConnection)
            table.insert(State.PlayerConnections[userId], charRemovedConnection)
        end
    end

    -- Проверяем что таблица существует перед добавлением
    if not State.PlayerConnections[userId] then
        State.PlayerConnections[userId] = {}
    end

    -- Отслеживание CharacterAdded
    local charAddedConnection = player.CharacterAdded:Connect(onCharacterAdded)
    if State.PlayerConnections[userId] then
        table.insert(State.PlayerConnections[userId], charAddedConnection)
    end

    -- Отслеживание CharacterRemoving
    local charRemovingConnection = player.CharacterRemoving:Connect(function(character)
        Log("PlayerTracking", string.format("%s теряет персонажа", player.Name))
        RemovePlayerESP(player)
    end)
    if State.PlayerConnections[userId] then
        table.insert(State.PlayerConnections[userId], charRemovingConnection)
    end

    -- Если персонаж уже существует
    if player.Character then
        task.spawn(function()
            onCharacterAdded(player.Character)
        end)
    end

    -- Отслеживание рюкзака
    local function setupBackpackTracking()
        local backpack = player:WaitForChild("Backpack", 10)
        if not backpack then return end

        -- Проверяем что таблица существует
        if not State.PlayerConnections[userId] then
            State.PlayerConnections[userId] = {}
        end

        local backpackConnection = backpack.ChildAdded:Connect(function(child)
            if child.Name == "Knife" or child.Name == "Gun" then
                task.wait(0.1)
                UpdatePlayerRole(player)
            end
        end)

        local backpackRemovedConnection = backpack.ChildRemoved:Connect(function(child)
            if child.Name == "Knife" or child.Name == "Gun" then
                task.wait(0.1)
                UpdatePlayerRole(player)
            end
        end)

        if State.PlayerConnections[userId] then
            table.insert(State.PlayerConnections[userId], backpackConnection)
            table.insert(State.PlayerConnections[userId], backpackRemovedConnection)
        end
    end

    task.spawn(setupBackpackTracking)
end

local function SetupGunTracking()
    -- Отслеживание появления оружия в Workspace
    local gunAddedConnection = Workspace.DescendantAdded:Connect(function(obj)
        if not State.GunESP then return end

        if obj:IsA("BasePart") and obj.Name == "GunDrop" then
            task.wait(0.1)
            CreateGunESP(obj)
        end
    end)

    -- Отслеживание удаления оружия
    local gunRemovedConnection = Workspace.DescendantRemoving:Connect(function(obj)
        if obj:IsA("BasePart") and obj.Name == "GunDrop" then
            RemoveGunESP(obj)
        end
    end)

    table.insert(State.Connections, gunAddedConnection)
    table.insert(State.Connections, gunRemovedConnection)
end

-- Начальное сканирование
local function InitialScan()
    Log("Scan", "Начальное сканирование...")

    -- Сканирование оружия
    if State.GunESP then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == "GunDrop" then
                CreateGunESP(obj)
            end
        end
    end

    -- Сканирование игроков
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character.Parent then
            UpdatePlayerRole(player)
        end
    end

    Log("Scan", "Сканирование завершено")
end

-- Очистка всего ESP
local function ClearAllESP()
    -- Очистка игроков
    for userId, cache in pairs(State.PlayerCache) do
        if cache.espData then
            if cache.espData.highlight then 
                pcall(function() cache.espData.highlight:Destroy() end)
            end
        end
    end
    State.PlayerCache = {}

    -- Очистка оружия
    for gunPart, espData in pairs(State.GunCache) do
        if espData.highlight then pcall(function() espData.highlight:Destroy() end) end
        if espData.billboard then pcall(function() espData.billboard:Destroy() end) end
    end
    State.GunCache = {}

    Log("ESP", "Весь ESP очищен")
end

-- ПОСТОЯННЫЙ ЦИКЛ ОБНОВЛЕНИЯ
local function StartUpdateLoop()
    if State.UpdateLoop then
        State.UpdateLoop:Disconnect()
    end

    State.UpdateLoop = RunService.Heartbeat:Connect(function()
        -- Проверяем всех игроков каждый кадр
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player:IsDescendantOf(Players) then
                local userId = player.UserId
                local character = player.Character
                
                if character and character.Parent then
                    local cache = State.PlayerCache[userId]
                    
                    -- Проверяем, существует ли ESP и привязан ли он к текущему персонажу
                    local needsUpdate = false
                    
                    if not cache or not cache.espData or not cache.espData.highlight then
                        needsUpdate = true
                    else
                        -- Проверяем валидность Highlight
                        local validHighlight = pcall(function()
                            return cache.espData.highlight.Parent == character
                        end)
                        
                        if not validHighlight then
                            needsUpdate = true
                        else
                            -- Проверяем изменение роли
                            local currentRole = GetPlayerRole(player)
                            if cache.role ~= currentRole then
                                needsUpdate = true
                            end
                        end
                    end
                    
                    if needsUpdate then
                        UpdatePlayerRole(player)
                    end
                else
                    -- У игрока нет персонажа - удаляем ESP
                    if cache then
                        RemovePlayerESP(player)
                    end
                end
            end
        end
    end)

    table.insert(State.Connections, State.UpdateLoop)
    Log("UpdateLoop", "Запущен постоянный цикл обновления ESP")
end

-- ==============================================
-- АНИМАЦИИ
-- ==============================================
local function PlayEmote(emoteName)
    task.spawn(function()
        pcall(function()
            local character = LocalPlayer.Character
            if not character then return end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end

            if emoteName == "sit" then
                humanoid.Sit = true
                return
            end

            local animate = character:FindFirstChild("Animate")
            if animate then
                local playEmoteBindable = animate:FindFirstChild("PlayEmote", true)
                if playEmoteBindable and playEmoteBindable:IsA("BindableFunction") then
                    playEmoteBindable:Invoke(emoteName)
                    return
                end
            end

            humanoid:PlayEmote(emoteName)
        end)
    end)
end

-- ==============================================
-- CLICK TP
-- ==============================================
local function TeleportToMouse()
    local character = LocalPlayer.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local mouse = LocalPlayer:GetMouse()
    local targetPos = mouse.Hit.Position

    if targetPos then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        Log("ClickTP", "Телепорт на: " .. tostring(targetPos))
    end
end

-- ==============================================
-- KEYBIND UTILITIES
-- ==============================================

local function FindKeybindButton(keyCode)
    for bindName, boundKey in pairs(State.Keybinds) do
        if boundKey == keyCode then
            return bindName
        end
    end
    return nil
end

local function ClearKeybind(bindName, button)
    State.Keybinds[bindName] = Enum.KeyCode.Unknown
    button.Text = "Not Bound"
    Log("Keybind", string.format("%s cleared", bindName))
end

local function SetKeybind(bindName, keyCode, button, allButtons)
    local existingBind = FindKeybindButton(keyCode)
    if existingBind and existingBind ~= bindName then
        State.Keybinds[existingBind] = Enum.KeyCode.Unknown
        if allButtons[existingBind] then
            allButtons[existingBind].Text = "Not Bound"
        end
        Log("Keybind", string.format("%s unbound (replaced by %s)", existingBind, bindName))
    end

    State.Keybinds[bindName] = keyCode
    button.Text = keyCode.Name
    Log("Keybind", string.format("%s bound to %s", bindName, keyCode.Name))
end

-- ==============================================
-- UI UTILITIES
-- ==============================================
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

-- ==============================================
-- UI CREATION
-- ==============================================
local function CreateUI()
    Log("UI", "Создание интерфейса...")

    for _, child in ipairs(CoreGui:GetChildren()) do
        if child.Name == "MM2_ESP_UI" then child:Destroy() end
    end

    local gui = Create("ScreenGui", {
        Name = "MM2_ESP_UI",
        ResetOnSpawn = false,
        Parent = CoreGui
    })
    State.UIElements.MainGui = gui

    local mainFrame = Create("Frame", {
        Name = "MainFrame",
        BackgroundColor3 = CONFIG.Colors.Background,
        Position = UDim2.new(0.5, -225, 0.5, -325),
        Size = UDim2.new(0, 450, 0, 650),
        ClipsDescendants = true,
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

    local titleLabel = Create("TextLabel", {
        Text = "MM2 ESP + ANIMATIONS <font color=\"rgb(90,140,255)\">v4.2</font>",
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
        Text = "×",
        Font = Enum.Font.GothamMedium,
        TextSize = 24,
        TextColor3 = CONFIG.Colors.TextDark,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -35, 0, 0),
        Size = UDim2.new(0, 35, 0, 40),
        Parent = header
    })

    local content = Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 15, 0, 55),
        Size = UDim2.new(1, -30, 1, -70),
        CanvasSize = UDim2.new(0, 0, 0, 1000),
        ScrollBarThickness = 6,
        ScrollBarImageColor3 = CONFIG.Colors.Accent,
        BorderSizePixel = 0,
        Parent = mainFrame
    })

    local layout = Create("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = content
    })

    local function CreateSection(title)
        local label = Create("TextLabel", {
            Text = title,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = CONFIG.Colors.TextDark,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 22),
            Parent = content
        })
    end

    local function CreateToggle(title, desc, callback)
        local card = Create("Frame", {
            BackgroundColor3 = CONFIG.Colors.Section,
            Size = UDim2.new(1, 0, 0, 60),
            Parent = content
        })
        AddCorner(card, 8)
        AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

        local cardTitle = Create("TextLabel", {
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

        local cardDesc = Create("TextLabel", {
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
        toggleBg.MouseButton1Click:Connect(function()
            state = not state
            local targetColor = state and CONFIG.Colors.Accent or Color3.fromRGB(50, 50, 55)
            local targetPos = state and UDim2.new(0, 22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)

            TweenService:Create(toggleBg, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
            TweenService:Create(toggleCircle, TweenInfo.new(0.2), {Position = targetPos}):Play()

            callback(state)
        end)
    end

    local function CreateInputField(title, desc, defaultValue, callback)
        local card = Create("Frame", {
            BackgroundColor3 = CONFIG.Colors.Section,
            Size = UDim2.new(1, 0, 0, 60),
            Parent = content
        })
        AddCorner(card, 8)
        AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

        local cardTitle = Create("TextLabel", {
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

        local cardDesc = Create("TextLabel", {
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

        inputBox.FocusLost:Connect(function(enterPressed)
            local value = tonumber(inputBox.Text)
            if value then
                callback(value)
            else
                inputBox.Text = tostring(defaultValue)
            end
        end)
    end

    local keybindButtons = {}

    local function CreateKeybindButton(title, emoteId, keybindKey)
        local card = Create("Frame", {
            BackgroundColor3 = CONFIG.Colors.Section,
            Size = UDim2.new(1, 0, 0, 50),
            Parent = content
        })
        AddCorner(card, 8)
        AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

        local cardTitle = Create("TextLabel", {
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
            Text = State.Keybinds[keybindKey] ~= Enum.KeyCode.Unknown and State.Keybinds[keybindKey].Name or "Not Bound",
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

        keybindButtons[keybindKey] = bindButton

        bindButton.MouseButton1Click:Connect(function()
            bindButton.Text = "Press Key..."
            State.ListeningForKeybind = {key = keybindKey, button = bindButton}
        end)

        return bindButton
    end

    CreateSection("CHARACTER SETTINGS")

    CreateInputField("WalkSpeed", "Set custom walk speed", State.WalkSpeed, function(value)
        ApplyWalkSpeed(value)
    end)

    CreateInputField("JumpPower", "Set custom jump power", State.JumpPower, function(value)
        ApplyJumpPower(value)
    end)

    CreateInputField("Max Camera Zoom", "Set maximum camera distance", State.MaxCameraZoom, function(value)
        ApplyMaxCameraZoom(value)
    end)

    CreateSection("ESP OPTIONS")

    CreateToggle("Gun ESP", "Highlight dropped guns", function(state)
        State.GunESP = state
        Log("ESP", "Gun ESP: " .. tostring(state))
        if state then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name == "GunDrop" then
                    CreateGunESP(obj)
                end
            end
        else
            UpdateGunESPVisibility()
        end
    end)

    CreateToggle("Murder ESP", "Highlight murderer", function(state)
        State.MurderESP = state
        Log("ESP", "Murder ESP: " .. tostring(state))
        UpdateAllPlayerESPVisibility()
    end)

    CreateToggle("Sheriff ESP", "Highlight sheriff", function(state)
        State.SheriffESP = state
        Log("ESP", "Sheriff ESP: " .. tostring(state))
        UpdateAllPlayerESPVisibility()
    end)

    CreateToggle("Innocent ESP", "Highlight innocent players", function(state)
        State.InnocentESP = state
        Log("ESP", "Innocent ESP: " .. tostring(state))
        UpdateAllPlayerESPVisibility()
    end)

    CreateSection("ANIMATION KEYBINDS")

    CreateKeybindButton("Sit Animation", "sit", "Sit")
    CreateKeybindButton("Dab Animation", "dab", "Dab")
    CreateKeybindButton("Zen Animation", "zen", "Zen")
    CreateKeybindButton("Ninja Animation", "ninja", "Ninja")
    CreateKeybindButton("Floss Animation", "floss", "Floss")

    CreateSection("TELEPORT")

    CreateKeybindButton("Click TP (Hold Key)", "clicktp", "ClickTP")

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

    closeButton.MouseButton1Click:Connect(function()
        ClearAllESP()
        for _, connection in ipairs(State.Connections) do
            pcall(function() connection:Disconnect() end)
        end
        for userId, connections in pairs(State.PlayerConnections) do
            DisconnectPlayerConnections(userId)
        end
        gui:Destroy()
        getgenv().MM2_ESP_Script = false
    end)

    closeButton.MouseEnter:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.2), {TextColor3 = CONFIG.Colors.Red}):Play()
    end)
    closeButton.MouseLeave:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.2), {TextColor3 = CONFIG.Colors.TextDark}):Play()
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == CONFIG.HideKey then
            mainFrame.Visible = not mainFrame.Visible
        end
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end

        if State.ListeningForKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
            local key = input.KeyCode
            local bindData = State.ListeningForKeybind

            if key == Enum.KeyCode.Delete or key == Enum.KeyCode.Backspace then
                ClearKeybind(bindData.key, bindData.button)
                State.ListeningForKeybind = nil
                return
            end

            SetKeybind(bindData.key, key, bindData.button, keybindButtons)
            State.ListeningForKeybind = nil
            return
        end

        if input.KeyCode == State.Keybinds.Sit and State.Keybinds.Sit ~= Enum.KeyCode.Unknown then
            PlayEmote("sit")
        elseif input.KeyCode == State.Keybinds.Dab and State.Keybinds.Dab ~= Enum.KeyCode.Unknown then
            PlayEmote("dab")
        elseif input.KeyCode == State.Keybinds.Zen and State.Keybinds.Zen ~= Enum.KeyCode.Unknown then
            PlayEmote("zen")
        elseif input.KeyCode == State.Keybinds.Ninja and State.Keybinds.Ninja ~= Enum.KeyCode.Unknown then
            PlayEmote("ninja")
        elseif input.KeyCode == State.Keybinds.Floss and State.Keybinds.Floss ~= Enum.KeyCode.Unknown then
            PlayEmote("floss")
        end

        if input.KeyCode == State.Keybinds.ClickTP and State.Keybinds.ClickTP ~= Enum.KeyCode.Unknown then
            State.ClickTPActive = true
        end
    end)

    Log("UI", "✅ UI создан!")
end

-- ==============================================
-- INPUT HANDLING
-- ==============================================

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == State.Keybinds.ClickTP then
        State.ClickTPActive = false
    end
end)

local mouse = LocalPlayer:GetMouse()
mouse.Button1Down:Connect(function()
    if State.ClickTPActive then
        TeleportToMouse()
    end
end)

-- ==============================================
-- PLAYER EVENTS
-- ==============================================
Players.PlayerAdded:Connect(function(player)
    Log("PlayerEvents", string.format("Игрок присоединился: %s", player.Name))
    SetupPlayerTracking(player)
end)

Players.PlayerRemoving:Connect(function(player)
    Log("PlayerEvents", string.format("Игрок вышел: %s", player.Name))
    RemovePlayerESP(player)
    DisconnectPlayerConnections(player.UserId)
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    Log("Main", "Респавн локального игрока")
    ApplyCharacterSettings()
    -- Обновляем ESP всех игроков после нашего респавна
    task.wait(1)
    InitialScan()
end)

-- ==============================================
-- ИНИЦИАЛИЗАЦИЯ
-- ==============================================
Log("Main", "🚀 Инициализация MM2 ESP + Animations v4.2...")
CreateUI()

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        SetupPlayerTracking(player)
    end
end

SetupGunTracking()
ApplyCharacterSettings()
InitialScan()

-- ЗАПУСК ПОСТОЯННОГО ЦИКЛА ОБНОВЛЕНИЯ
StartUpdateLoop()

Log("Main", "✅ Скрипт готов к использованию!")
Log("Main", "✅ Постоянный мониторинг ESP активирован!")
