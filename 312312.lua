-- === СЕРВИСЫ ===
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")  -- ✅ ДОБАВЛЕНО
local HttpService = game:GetService("HttpService")  -- ✅ ДОБАВЛЕНО
local LocalPlayer = Players.LocalPlayer

-- === КОНФИГ ===
local CONFIG = {
    HideKey = Enum.KeyCode.Q,
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
    }
}

-- === ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ===
local State = {
    -- Управление фармом
    AutoFarmEnabled = false,
    CoinFarmThread = nil,
    
    -- Настройки
    CoinFarmFlySpeed = 23,
    CoinFarmDelay = 2,
    UndergroundMode = true,
    UndergroundOffset = 3,
    NoclipMode = "Standard",
    
    -- Отслеживание монет
    CoinBlacklist = {},
    StartSessionCoins = 0,

    -- Reset-логика
    AllowReset = false,
    FailedCollects = 0,
    MaxFailedCollects = 3,
    
    -- Noclip
    NoclipEnabled = false,
    NoclipConnection = nil,
    NoclipRespawnConnection = nil,
    NoClipConnection = nil,  -- ✅ ДОБАВЛЕНО
    ClipEnabled = true,  -- ✅ ДОБАВЛЕНО
    
    -- Anti-Fling
    AntiFlingEnabled = false,
    AntiFlingLastPos = Vector3.zero,
    FlingDetectionConnection = nil,
    FlingNeutralizerConnection = nil,
    DetectedFlingers = {},
    IsFlingInProgress = false,
    
    -- UI
    UIElements = {},
    Connections = {},
}

-- ✅ ДОБАВЛЕНО: Глобальные переменные для Anti-Fling
local AntiFlingLastPos = Vector3.zero
local FlingDetectionConnection = nil
local FlingNeutralizerConnection = nil
local DetectedFlingers = {}

-- === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ UI ===

local function Create(className, properties)
    local obj = Instance.new(className)
    for k, v in pairs(properties or {}) do
        obj[k] = v
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

-- === ПОЛУЧЕНИЕ ТЕКУЩЕЙ КАРТЫ ===

local function GetCurrentMap()
    local success, mapName = pcall(function()
        local map = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("CurrentMap")
        if map then
            return map.Name
        end
        
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local mapFolder = replicatedStorage:FindFirstChild("Maps") or replicatedStorage:FindFirstChild("Map")
        if mapFolder then
            for _, child in ipairs(mapFolder:GetChildren()) do
                if child:IsA("Folder") or child:IsA("Model") then
                    return child.Name
                end
            end
        end
        
        return nil
    end)
    
    return success and mapName or nil
end

-- === ПОЛУЧЕНИЕ НИКА УБИЙЦЫ ===

local function GetMurdererName()
    local success, murdererName = pcall(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                local knife = player.Character:FindFirstChild("Knife")
                if knife then
                    return player.Name
                end
                
                if player.Backpack then
                    local knifeInBackpack = player.Backpack:FindFirstChild("Knife")
                    if knifeInBackpack then
                        return player.Name
                    end
                end
                
                for _, tool in ipairs(player.Character:GetChildren()) do
                    if tool:IsA("Tool") and (tool.Name:lower():match("knife") or tool.Name:lower():match("murder")) then
                        return player.Name
                    end
                end
                
                if player.Backpack then
                    for _, tool in ipairs(player.Backpack:GetChildren()) do
                        if tool:IsA("Tool") and (tool.Name:lower():match("knife") or tool.Name:lower():match("murder")) then
                            return player.Name
                        end
                    end
                end
            end
        end
        
        return nil
    end)
    
    return success and murdererName or nil
end


-- === СЧЁТЧИК МОНЕТ ===

local coinLabelCache = nil
local lastCacheTime = 0

local function GetCollectedCoinsCount()
    if coinLabelCache and coinLabelCache.Parent and (tick() - lastCacheTime) < 2 then
        local success, value = pcall(function()
            return tonumber(coinLabelCache.Text) or 0
        end)
        if success then
            return value
        end
    end
    
    local success, coins = pcall(function()
        local label = LocalPlayer.PlayerGui
            :FindFirstChild("MainGUI")
            :FindFirstChild("Game")
            :FindFirstChild("CoinBags")
            :FindFirstChild("Container")
            :FindFirstChild("SnowToken")
            :FindFirstChild("CurrencyFrame")
            :FindFirstChild("Icon")
            :FindFirstChild("Coins")
        
        if label then
            coinLabelCache = label
            lastCacheTime = tick()
            return tonumber(label.Text) or 0
        end
        return 0
    end)
    
    if success and coins >= 0 then
        return coins
    end
    
    local maxValue = 0
    pcall(function()
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") and gui.Name == "Coins" then
                local path = gui:GetFullName()
                if path:match("CurrencyFrame%.Icon%.Coins$") then
                    local value = tonumber(gui.Text) or 0
                    if value > maxValue then
                        maxValue = value
                        coinLabelCache = gui
                        lastCacheTime = tick()
                    end
                end
            end
        end
    end)
    
    return maxValue
end

local function ResetCharacter()
    print("[Auto Farm] 💀 Ресет персонажа")
    pcall(function()
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.Health = 0
            end
        end
    end)
end

-- === ANTI-AFK ===

local function SetupAntiAFK()
    local VirtualUser = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    task.spawn(function()
        while true do
            pcall(function()
                if getconnections then
                    for _, connection in next, getconnections(LocalPlayer.Idled) do
                        if connection.Disable then
                            connection:Disable()
                        end
                    end
                end
            end)
            task.wait(60)
        end
    end)
    
    print("[Anti-AFK] ✅ Активирован")
end

-- === REJOIN / SERVER HOP ===

local function Rejoin()
    print("[Rejoin] Переподключение...")
    task.wait(0.5)

    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)

    task.wait(2)
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local function ServerHop()
    print("[Server Hop] Поиск нового сервера...")
    
    local success, result = pcall(function()
        local serverlist = {}
        local cursor = ""
        local foundServers = 0

        for i = 1, 3 do
            local url = string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
                game.PlaceId,
                cursor
            )

            local success2, response = pcall(function()
                return game:HttpGet(url)
            end)

            if not success2 then
                warn("[Server Hop] Ошибка получения списка серверов:", response)
                break
            end

            local data = HttpService:JSONDecode(response)

            for _, server in ipairs(data.data) do
                if server.id ~= game.JobId and 
                   server.playing < server.maxPlayers and
                   server.playing > 0 then
                    table.insert(serverlist, server)
                    foundServers = foundServers + 1
                end
            end

            cursor = data.nextPageCursor
            if not cursor or cursor == "" then
                break
            end

            if foundServers >= 10 then
                break
            end
        end

        if #serverlist == 0 then
            print("[Server Hop] Нет доступных серверов, используем Rejoin")
            task.wait(1)
            return Rejoin()
        end

        table.sort(serverlist, function(a, b)
            return a.playing < b.playing
        end)

        local targetIndex = math.random(1, math.min(5, #serverlist))
        local targetServer = serverlist[targetIndex]

        print("[Server Hop] Телепорт на сервер с " .. targetServer.playing .. " игроками")
        task.wait(1)

        TeleportService:TeleportToPlaceInstance(
            game.PlaceId, 
            targetServer.id, 
            LocalPlayer
        )
    end)

    if not success then
        warn("[Server Hop] Ошибка:", result)
        task.wait(1)
        Rejoin()
    end
end

-- === ANTI-FLING ===

local function EnableAntiFling()
    if State.AntiFlingEnabled then return end
    State.AntiFlingEnabled = true

    FlingDetectionConnection = RunService.Heartbeat:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character and player.Character:IsDescendantOf(Workspace) and player ~= LocalPlayer then
                local primaryPart = player.Character.PrimaryPart
                if primaryPart then
                    -- ✅ ИСПРАВЛЕНО: Увеличен порог для детекции флинга
                    if primaryPart.AssemblyAngularVelocity.Magnitude > 100 or primaryPart.AssemblyLinearVelocity.Magnitude > 200 then
                        if not DetectedFlingers[player.Name] then
                            DetectedFlingers[player.Name] = true
                            print("[Anti-Fling] 🛡️ Обнаружен флингер:", player.Name)
                        end

                        -- ✅ ИСПРАВЛЕНО: Только отключаем коллизию, не меняем физику
                        pcall(function()
                            if player.Character then
                                for _, part in ipairs(player.Character:GetDescendants()) do
                                    if part:IsA("BasePart") then
                                        pcall(function()
                                            part.CanCollide = false
                                        end)
                                    end
                                end
                            end
                        end)
                    end
                end
            end
        end
    end)

    FlingNeutralizerConnection = RunService.Heartbeat:Connect(function()
        local character = LocalPlayer.Character
        if character and character.PrimaryPart then
            local primaryPart = character.PrimaryPart

            -- ✅ ИСПРАВЛЕНО: Увеличен порог
            if primaryPart.AssemblyLinearVelocity.Magnitude > 300 or primaryPart.AssemblyAngularVelocity.Magnitude > 300 then
                primaryPart.AssemblyLinearVelocity = Vector3.zero
                primaryPart.AssemblyAngularVelocity = Vector3.zero

                if AntiFlingLastPos ~= Vector3.zero then
                    primaryPart.CFrame = CFrame.new(AntiFlingLastPos)
                end
            else
                AntiFlingLastPos = primaryPart.Position
            end
        end
    end)

    table.insert(State.Connections, FlingDetectionConnection)
    table.insert(State.Connections, FlingNeutralizerConnection)
    
    print("[Anti-Fling] ✅ Включен")
end

local function DisableAntiFling()
    if not State.AntiFlingEnabled then return end
    State.AntiFlingEnabled = false
    DetectedFlingers = {}

    if FlingDetectionConnection then
        FlingDetectionConnection:Disconnect()
        FlingDetectionConnection = nil
    end

    if FlingNeutralizerConnection then
        FlingNeutralizerConnection:Disconnect()
        FlingNeutralizerConnection = nil
    end
    
    print("[Anti-Fling] ❌ Выключен")
end

local function DisableAntiFling()
    if not State.AntiFlingEnabled then return end
    State.AntiFlingEnabled = false
    DetectedFlingers = {}

    if FlingDetectionConnection then
        FlingDetectionConnection:Disconnect()
        FlingDetectionConnection = nil
    end

    if FlingNeutralizerConnection then
        FlingNeutralizerConnection:Disconnect()
        FlingNeutralizerConnection = nil
    end
    
    print("[Anti-Fling] ❌ Выключен")
end

-- === NOCLIP (ОТДЕЛЬНАЯ КНОПКА) ===

local function EnableNoclip()
    if State.NoclipEnabled then return end
    State.NoclipEnabled = true

    local mode = State.NoclipMode

    if mode == "Standard" then
        local NoclipObjects = {}
        local char = LocalPlayer.Character
        if not char then return end

        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("BasePart") then
                table.insert(NoclipObjects, obj)
            end
        end

        State.NoclipRespawnConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
            task.wait(0.15)
            table.clear(NoclipObjects)
            for _, obj in ipairs(newChar:GetChildren()) do
                if obj:IsA("BasePart") then
                    table.insert(NoclipObjects, obj)
                end
            end
        end)

        State.NoclipConnection = RunService.Stepped:Connect(function()
            for _, part in ipairs(NoclipObjects) do
                pcall(function()
                    part.CanCollide = false
                end)
            end
        end)
    end
    
    print("[Noclip] ✅ Включен")
end

local function DisableNoclip()
    if not State.NoclipEnabled then return end
    State.NoclipEnabled = false

    if State.NoclipConnection then
        State.NoclipConnection:Disconnect()
        State.NoclipConnection = nil
    end

    if State.NoclipRespawnConnection then
        State.NoclipRespawnConnection:Disconnect()
        State.NoclipRespawnConnection = nil
    end
    
    print("[Noclip] ❌ Выключен")
end

-- === NOCLIP ДЛЯ АВТОФАРМА ===

local function EnableNoClip()
    if State.NoClipConnection then return end

    State.ClipEnabled = false
    State.NoClipConnection = RunService.Stepped:Connect(function()
        if not State.ClipEnabled then
            local character = LocalPlayer.Character
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide == true then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end

local function DisableNoClip()
    if State.NoClipConnection then
        State.NoClipConnection:Disconnect()
        State.NoClipConnection = nil
    end

    State.ClipEnabled = true

    local character = LocalPlayer.Character
    if character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

-- === ПОИСК БЛИЖАЙШЕЙ МОНЕТЫ ===

local function FindNearestCoin()
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    
    local closestCoin = nil
    local closestDistance = math.huge
    local hrpPosition = humanoidRootPart.Position
    
    for _, coin in ipairs(Workspace:GetDescendants()) do
        if coin:IsA("BasePart") 
           and coin.Name == "Coin_Server" 
           and coin:FindFirstChildWhichIsA("TouchTransmitter") 
           and not State.CoinBlacklist[coin] then
            
            local coinVisual = coin:FindFirstChild("CoinVisual")
            if coinVisual and coinVisual.Transparency == 0 then
                local distance = (coin.Position - hrpPosition).Magnitude
                
                if distance < closestDistance then
                    closestDistance = distance
                    closestCoin = coin
                end
            end
        end
    end
    
    return closestCoin
end

-- === ПЛАВНЫЙ ПОЛЁТ ===

local function SmoothFlyToCoin(coin, humanoidRootPart, speed)
    speed = speed or State.CoinFarmFlySpeed

    local startPos = humanoidRootPart.Position
    
    local targetPos
    if State.UndergroundMode then
        targetPos = coin.Position - Vector3.new(0, State.UndergroundOffset, 0)
    else
        targetPos = coin.Position + Vector3.new(0, 1, 0)
    end
    
    local distance = (targetPos - startPos).Magnitude
    local duration = distance / speed

    local startTime = tick()
    local collectionAttempted = false

    while tick() - startTime < duration do
        if not State.AutoFarmEnabled then break end

        local character = LocalPlayer.Character
        if not character or not humanoidRootPart.Parent then break end

        local elapsed = tick() - startTime
        local alpha = math.min(elapsed / duration, 1)

        local currentPos = startPos:Lerp(targetPos, alpha)
        
        local cframe
        if State.UndergroundMode then
            cframe = CFrame.new(currentPos) * CFrame.Angles(math.rad(90), 0, 0)
        else
            cframe = CFrame.new(currentPos)
        end
        
        humanoidRootPart.CFrame = cframe
        
        if humanoidRootPart.AssemblyLinearVelocity then
            humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
        if humanoidRootPart.AssemblyAngularVelocity then
            humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end

        if alpha >= 0.5 and not collectionAttempted then
            collectionAttempted = true
            if firetouchinterest then
                task.spawn(function()
                    firetouchinterest(humanoidRootPart, coin, 0)
                    task.wait(0.05)
                    firetouchinterest(humanoidRootPart, coin, 1)
                end)
            end
        end

        task.wait()
    end
end

local function StartAutoFarm()
    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end

    if not State.AutoFarmEnabled then return end
    
    State.CoinBlacklist = {}

    State.CoinFarmThread = task.spawn(function()
        print("[Auto Farm] 🚀 Запущен")
        if State.UndergroundMode then
            print("[Auto Farm] 🕳️ Режим под землёй: ВКЛ")
        end
        
        local noCoinsAttempts = 0
        local maxNoCoinsAttempts = 4
        local lastTeleportTime = 0
        
        while State.AutoFarmEnabled do
            local character = LocalPlayer.Character
            if not character then 
                task.wait(0.5)
                continue 
            end

            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then 
                task.wait(0.5)
                continue 
            end

            local murdererExists = GetMurdererName() ~= nil
            
            if not murdererExists then
                print("[Auto Farm] ⏳ Жду начала раунда...")
                State.CoinBlacklist = {}
                noCoinsAttempts = 0
                task.wait(2)
                continue
            end

            local coin = FindNearestCoin()
            if not coin then
                noCoinsAttempts = noCoinsAttempts + 1
                print("[Auto Farm] 🔍 Монет не найдено (попытка " .. noCoinsAttempts .. "/" .. maxNoCoinsAttempts .. ")")
                
                if noCoinsAttempts >= maxNoCoinsAttempts then
                    print("[Auto Farm] ✅ Все монеты собраны! Делаю ресет и жду нового раунда...")
                    ResetCharacter()
                    State.CoinBlacklist = {}
                    noCoinsAttempts = 0
                    
                    -- ✅ ИСПРАВЛЕНО: Ждём респавна
                    task.wait(3)
                    
                    -- ✅ ИСПРАВЛЕНО: Ждём пока убийца исчезнет (конец раунда)
                    print("[Auto Farm] ⏳ Жду окончания раунда...")
                    repeat
                        task.wait(1)
                    until GetMurdererName() == nil or not State.AutoFarmEnabled
                    
                    -- ✅ ИСПРАВЛЕНО: Теперь ждём НАЧАЛА нового раунда
                    print("[Auto Farm] ⏳ Жду начала нового раунда...")
                    repeat
                        task.wait(1)
                    until GetMurdererName() ~= nil or not State.AutoFarmEnabled
                    
                    print("[Auto Farm] ✅ Новый раунд начался! Продолжаю фарм...")
                else
                    task.wait(1)
                end
                continue
            end

            noCoinsAttempts = 0

            pcall(function()
                local currentCoins = GetCollectedCoinsCount()

                if currentCoins < 1 then
                    local currentTime = tick()
                    local timeSinceLastTP = currentTime - lastTeleportTime
                    
                    if timeSinceLastTP < 0.5 and lastTeleportTime > 0 then
                        local waitTime = 0.5 - timeSinceLastTP
                        task.wait(waitTime)
                    end
                    
                    print("[Auto Farm] 📍 ТП к монете #" .. (currentCoins + 1))
                    
                    local targetCFrame = coin.CFrame + Vector3.new(0, 2, 0)

                    if targetCFrame.Position.Y > -500 and targetCFrame.Position.Y < 10000 then
                        humanoidRootPart.CFrame = targetCFrame
                        lastTeleportTime = tick()
                        
                        if firetouchinterest then
                            firetouchinterest(humanoidRootPart, coin, 0)
                            task.wait(0.05)
                            firetouchinterest(humanoidRootPart, coin, 1)
                        end
                        
                        task.wait(State.CoinFarmDelay)
                        
                        local coinsAfter = GetCollectedCoinsCount()
                        if coinsAfter > currentCoins then
                            print("[Auto Farm] ✅ Монета собрана (TP) | Всего: " .. coinsAfter)
                        end
                        
                        State.CoinBlacklist[coin] = true
                    end
                else
                    if State.UndergroundMode then
                        print("[Auto Farm] 🕳️ Полёт под землёй к монете (скорость: " .. State.CoinFarmFlySpeed .. ")")
                    else
                        print("[Auto Farm] ✈️ Полёт к монете (скорость: " .. State.CoinFarmFlySpeed .. ")")
                    end
                    
                    EnableNoClip()
                    SmoothFlyToCoin(coin, humanoidRootPart, State.CoinFarmFlySpeed)
                    DisableNoClip()
                    
                    local coinsAfter = GetCollectedCoinsCount()
                    if coinsAfter > currentCoins then
                        print("[Auto Farm] ✅ Монета собрана (Fly) | Всего: " .. coinsAfter)
                    end
                    
                    State.CoinBlacklist[coin] = true
                end
            end)
        end

        DisableNoClip()
        State.CoinFarmThread = nil
        print("[Auto Farm] 🛑 Остановлен")
    end)
end
local function StopAutoFarm()
    State.AutoFarmEnabled = false
    
    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end
    
    DisableNoClip()
    print("[Auto Farm] Полностью выключен")
end

local function CreateUI()
    for _, child in ipairs(CoreGui:GetChildren()) do
        if child.Name == "MM2_Farm_UI" then child:Destroy() end
    end

    local gui = Create("ScreenGui", {
        Name = "MM2_Farm_UI",
        Parent = CoreGui,
        ResetOnSpawn = false
    })
    State.UIElements.MainGui = gui

    local mainFrame = Create("Frame", {
        Name = "MainFrame",
        BackgroundColor3 = CONFIG.Colors.Background,
        Position = UDim2.new(0.5, -225, 0.5, -275),
        Size = UDim2.new(0, 450, 0, 550),
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
        Text = "MM2 Hybrid Auto Farm <font color=\"rgb(90,140,255)\">v2.0</font>",
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

    local content = Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 15, 0, 55),
        Size = UDim2.new(1, -30, 1, -70),
        CanvasSize = UDim2.new(0, 0, 0, 0),
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

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

    -- === ФУНКЦИИ СОЗДАНИЯ ЭЛЕМЕНТОВ ===

    local function CreateSection(title)
        Create("TextLabel", {
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

    local function CreateToggle(title, desc, defaultState, callback)
        local card = Create("Frame", {
            BackgroundColor3 = CONFIG.Colors.Section,
            Size = UDim2.new(1, 0, 0, 60),
            Parent = content
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
            BackgroundColor3 = defaultState and CONFIG.Colors.Accent or Color3.fromRGB(50, 50, 55),
            Position = UDim2.new(1, -60, 0.5, -12),
            Size = UDim2.new(0, 44, 0, 24),
            AutoButtonColor = false,
            Parent = card
        })
        AddCorner(toggleBg, 24)

        local toggleCircle = Create("Frame", {
            BackgroundColor3 = CONFIG.Colors.Text,
            Position = defaultState and UDim2.new(0, 22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10),
            Size = UDim2.new(0, 20, 0, 20),
            Parent = toggleBg
        })
        AddCorner(toggleCircle, 20)

        local state = defaultState or false
        toggleBg.MouseButton1Click:Connect(function()
            state = not state
            local targetColor = state and CONFIG.Colors.Accent or Color3.fromRGB(50, 50, 55)
            local targetPos = state and UDim2.new(0, 22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)

            TweenService:Create(toggleBg, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
            TweenService:Create(toggleCircle, TweenInfo.new(0.2), {Position = targetPos}):Play()

            callback(state)
        end)

        return toggleBg
    end

    local function CreateInputField(title, desc, defaultValue, callback)
        local card = Create("Frame", {
            BackgroundColor3 = CONFIG.Colors.Section,
            Size = UDim2.new(1, 0, 0, 60),
            Parent = content
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
                callback(value)
            else
                inputBox.Text = tostring(defaultValue)
            end
        end)
    end

    local function CreateButton(title, color, callback)
        local card = Create("Frame", {
            BackgroundColor3 = CONFIG.Colors.Section,
            Size = UDim2.new(1, 0, 0, 50),
            Parent = content
        })
        AddCorner(card, 8)
        AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

        local button = Create("TextButton", {
            Text = title,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextColor3 = CONFIG.Colors.Text,
            BackgroundColor3 = color,
            Position = UDim2.new(0, 15, 0.5, -15),
            Size = UDim2.new(1, -30, 0, 30),
            AutoButtonColor = false,
            Parent = card
        })
        AddCorner(button, 6)

        button.MouseButton1Click:Connect(callback)

        button.MouseEnter:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.new(
                    math.min(color.R + 0.1, 1),
                    math.min(color.G + 0.1, 1),
                    math.min(color.B + 0.1, 1)
                )
            }):Play()
        end)

        button.MouseLeave:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
        end)
    end

    -- === СОЗДАНИЕ ЭЛЕМЕНТОВ ИНТЕРФЕЙСА ===

    CreateSection("AUTO FARM")

    CreateToggle("Auto Farm", "Автоматический сбор монет", false, function(state)
        State.AutoFarmEnabled = state
        if state then
            State.CoinBlacklist = {}
            State.StartSessionCoins = GetCollectedCoinsCount()
            print("[Auto Farm] Стартовые монеты: " .. State.StartSessionCoins)
            StartAutoFarm()
        else
            StopAutoFarm()
        end
    end)

    CreateToggle("Underground Mode", "Полёт под картой (только для флая)", State.UndergroundMode, function(state)
        State.UndergroundMode = state
        print("[Underground Mode]", state and "ON" or "OFF")
    end)

    CreateSection("MOVEMENT")

    CreateToggle("Noclip", "Отключить столкновения", false, function(state)
        if state then
            EnableNoclip()
        else
            DisableNoclip()
        end
    end)

    CreateToggle("Anti-Fling", "Защита от флингеров", false, function(state)
        if state then
            EnableAntiFling()
        else
            DisableAntiFling()
        end
    end)

    CreateSection("SETTINGS")

    CreateInputField("Скорость полёта", "Скорость для полёта (10-100)", State.CoinFarmFlySpeed, function(value)
        if value >= 10 and value <= 100 then
            State.CoinFarmFlySpeed = value
            print("[Settings] Скорость полёта:", value)
        end
    end)

    CreateInputField("Задержка TP", "Задержка между ТП (0.1-5)", State.CoinFarmDelay, function(value)
        if value >= 0.1 and value <= 5 then
            State.CoinFarmDelay = value
            print("[Settings] Задержка TP:", value)
        end
    end)

    CreateSection("UTILITY")

    CreateButton("🔄 Rejoin Server", CONFIG.Colors.Accent, function()
        Rejoin()
    end)

    CreateButton("🌐 Server Hop", CONFIG.Colors.Green, function()
        ServerHop()
    end)

    -- === FOOTER ===

    local footer = Create("TextLabel", {
        Text = "Toggle Menu: " .. CONFIG.HideKey.Name,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = CONFIG.Colors.TextDark,
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, -100, 1, -25),
        Size = UDim2.new(0, 200, 0, 20),
        Parent = mainFrame
    })

    -- === ОБРАБОТЧИКИ ===

    closeButton.MouseButton1Click:Connect(function()
        gui:Destroy()
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

    task.wait(0.1)
    content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
end

-- === ИНИЦИАЛИЗАЦИЯ ===

CreateUI()
SetupAntiAFK() 
print("[Auto Farm] UI загружен! Нажми", CONFIG.HideKey.Name, "для открытия")
