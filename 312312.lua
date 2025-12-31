-- === ГИБРИДНЫЙ АВТОФАРМ С ПОЛНЫМ ФУНКЦИОНАЛОМ ===

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- === ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ===

local State = {
    -- Управление фармом
    AutoFarmEnabled = false,
    CoinFarmThread = nil,
    
    -- Настройки
    CoinFarmFlySpeed = 25,
    CoinFarmDelay = 2,
    
    -- Отслеживание монет
    CoinBlacklist = {},
    StartSessionCoins = 0,

    -- Reset‑логика
    AllowReset = false,
    FailedCollects = 0,
    MaxFailedCollects = 3,
    LastMapName = nil,
    LastMurdererName = nil,
    
    -- Noclip
    NoclipEnabled = false,
    NoclipMode = "Standard",
    NoclipConnection = nil,
    NoclipRespawnConnection = nil,
    NoClipConnection = nil,
    ClipEnabled = true,
    
    -- Anti-Fling
    AntiFlingEnabled = false,
    
    -- UI
    UIElements = {},
    Connections = {},
}

-- Anti-Fling переменные
local AntiFlingLastPos = Vector3.zero
local FlingDetectionConnection = nil
local FlingNeutralizerConnection = nil
local DetectedFlingers = {}

-- === ПОЛУЧЕНИЕ ТЕКУЩЕЙ КАРТЫ ===

local function GetCurrentMap()
    local success, mapName = pcall(function()
        -- Проверяем workspace на наличие карты
        local map = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("CurrentMap")
        if map then
            return map.Name
        end
        
        -- Альтернативный способ через ReplicatedStorage
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

-- === ПОЛУЧЕНИЕ НИКА УБИЙЦЫ (ДЛЯ ВСЕХ ИГРОКОВ) ===

local function GetMurdererName()
    local success, murdererName = pcall(function()
        -- Ищем убийцу среди ВСЕХ игроков
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then
                -- Проверяем наличие ножа в персонаже
                local knife = player.Character:FindFirstChild("Knife")
                if knife then
                    return player.Name
                end
                
                -- Проверяем в рюкзаке
                if player.Backpack then
                    local knifeInBackpack = player.Backpack:FindFirstChild("Knife")
                    if knifeInBackpack then
                        return player.Name
                    end
                end
                
                -- Дополнительная проверка через все инструменты
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


-- === ПРОВЕРКА СМЕНЫ РАУНДА ===

local function HasRoundChanged()
    local currentMap = GetCurrentMap()
    local currentMurderer = GetMurdererName()
    
    -- Если это первый запуск, сохраняем текущие значения
    if State.LastMapName == nil and State.LastMurdererName == nil then
        State.LastMapName = currentMap
        State.LastMurdererName = currentMurderer
        return false
    end
    
    -- Проверяем, изменилась ли карта или убийца
    local mapChanged = currentMap ~= State.LastMapName
    local murdererChanged = currentMurderer ~= State.LastMurdererName
    
    if mapChanged or murdererChanged then
        print("[Round Check] Раунд изменился!")
        if mapChanged then
            print("[Round Check] Карта: " .. tostring(State.LastMapName) .. " → " .. tostring(currentMap))
        end
        if murdererChanged then
            print("[Round Check] Убийца: " .. tostring(State.LastMurdererName) .. " → " .. tostring(currentMurderer))
        end
        
        State.LastMapName = currentMap
        State.LastMurdererName = currentMurderer
        return true
    end
    
    return false
end

-- === СЧЁТЧИК МОНЕТ С КЭШИРОВАНИЕМ ===

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

-- === ANTI-AFK (ВСЕГДА АКТИВЕН) ===

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
            if player.Character and player.Character:IsDescendantOf(workspace) and player ~= LocalPlayer then
                local primaryPart = player.Character.PrimaryPart
                if primaryPart then
                    if primaryPart.AssemblyAngularVelocity.Magnitude > 50 or primaryPart.AssemblyLinearVelocity.Magnitude > 100 then
                        if not DetectedFlingers[player.Name] then
                            DetectedFlingers[player.Name] = true
                            print("[Anti-Fling] 🛡️ Обнаружен флингер:", player.Name)
                        end

                        pcall(function()
                            if player.Character then
                                for _, part in ipairs(player.Character:GetDescendants()) do
                                    if part:IsA("BasePart") then
                                        pcall(function()
                                            part.CanCollide = false
                                            part.AssemblyAngularVelocity = Vector3.zero
                                            part.AssemblyLinearVelocity = Vector3.zero
                                            part.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0)
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

            if primaryPart.AssemblyLinearVelocity.Magnitude > 250 or primaryPart.AssemblyAngularVelocity.Magnitude > 250 then
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

-- === ПЛАВНЫЙ НЕПРЕРЫВНЫЙ ПОЛЁТ ===


local function SmoothFlyToCoin(coin, humanoidRootPart, speed)
    speed = speed or State.CoinFarmFlySpeed

    local startPos = humanoidRootPart.Position
    local targetPos = coin.Position + Vector3.new(0, 1, 0)
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
        humanoidRootPart.CFrame = CFrame.new(currentPos)
        
        -- Убираем любые остановки - непрерывное движение
        if humanoidRootPart.AssemblyLinearVelocity then
            humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
        if humanoidRootPart.AssemblyAngularVelocity then
            humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end

        -- Пытаемся собрать монету на полпути (не останавливаясь)
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

        task.wait()  -- Максимальная плавность
    end
end

-- === ОСНОВНОЙ ЦИКЛ ФАРМА (БЕЗ ЗАДЕРЖЕК И ПРОВЕРОК) ===

local function StartAutoFarm()
    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end

    if not State.AutoFarmEnabled then return end
    
    State.AllowReset = false
    State.FailedCollects = 0
    State.LastMapName = nil
    State.LastMurdererName = nil

    State.CoinFarmThread = task.spawn(function()
        print("[Auto Farm] 🚀 Запущен")
        
        local noCoinsAttempts = 0
        local maxNoCoinsAttempts = 5
        
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

            -- ═══════════════════════════════════════════════════
            -- ПРОВЕРКА НАЛИЧИЯ УБИЙЦЫ
            -- ═══════════════════════════════════════════════════
            local murdererExists = GetMurdererName() ~= nil
            
            if not murdererExists then
                print("[Auto Farm] ⏳ Ожидаю появления убийцы...")
                noCoinsAttempts = 0
                task.wait(2)
                continue
            end

            local coin = FindNearestCoin()
            if not coin then
                noCoinsAttempts = noCoinsAttempts + 1
                print("[Auto Farm] 🔍 Монет не найдено (попытка " .. noCoinsAttempts .. "/" .. maxNoCoinsAttempts .. ")")
                
                if noCoinsAttempts >= maxNoCoinsAttempts then
                    print("[Auto Farm] 🎯 Все монеты собраны! Делаю ресет...")
                    ResetCharacter()
                    noCoinsAttempts = 0
                    
                    task.wait(3)
                    
                    print("[Auto Farm] ⏳ Ожидаю смены раунда...")
                    local waitingForRound = true
                    while State.AutoFarmEnabled and waitingForRound do
                        if HasRoundChanged() then
                            print("[Auto Farm] ✅ Новый раунд начался, возобновляем фарм!")
                            State.CoinBlacklist = {}
                            waitingForRound = false
                            break
                        end
                        task.wait(2)
                    end
                else
                    task.wait(1)
                end
                continue
            end

            -- Нашли монету — сбрасываем счётчик попыток
            noCoinsAttempts = 0

            pcall(function()
                local currentCoins = GetCollectedCoinsCount()

                if currentCoins < 3 then
                    ----------------------------------------------------------------
                    -- ПЕРВЫЕ 3 МОНЕТЫ: ТП
                    ----------------------------------------------------------------
                    print("[Auto Farm] 📍 ТП к монете #" .. (currentCoins + 1))
                    
                    local targetCFrame = coin.CFrame + Vector3.new(0, 2, 0)

                    if targetCFrame.Position.Y > -500 and targetCFrame.Position.Y < 10000 then
                        humanoidRootPart.CFrame = targetCFrame
                        
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
                        
                        -- Всегда добавляем в чёрный список
                        State.CoinBlacklist[coin] = true
                    end
                else
                    ----------------------------------------------------------------
                    -- ОСТАЛЬНЫЕ МОНЕТЫ: НЕПРЕРЫВНЫЙ ПОЛЁТ БЕЗ ОСТАНОВОК
                    ----------------------------------------------------------------
                    print("[Auto Farm] ✈️ Непрерывный полёт к монете (скорость: " .. State.CoinFarmFlySpeed .. ")")
                    
                    EnableNoClip()
                    SmoothFlyToCoin(coin, humanoidRootPart, State.CoinFarmFlySpeed)
                    DisableNoClip()
                    
                    -- Проверяем результат БЕЗ ЗАДЕРЖКИ
                    local coinsAfter = GetCollectedCoinsCount()
                    if coinsAfter > currentCoins then
                        print("[Auto Farm] ✅ Монета собрана (Fly) | Всего: " .. coinsAfter)
                    end
                    
                    -- Всегда добавляем в чёрный список
                    State.CoinBlacklist[coin] = true
                end
            end)
            
            -- НЕТ task.wait здесь - сразу ищем следующую монету!
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

-- === GUI ===

local function CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MM2_Farm_GUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 360, 0, 450)
    MainFrame.Position = UDim2.new(0, 10, 0, 10)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    MainFrame.BorderSizePixel = 2
    MainFrame.BorderColor3 = Color3.fromRGB(90, 140, 255)
    MainFrame.Parent = ScreenGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    Title.Text = "MM2 Hybrid Auto Farm"
    Title.TextColor3 = Color3.fromRGB(230, 230, 230)
    Title.TextSize = 16
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = Title
    
    local CoinStatus = Instance.new("TextLabel")
    CoinStatus.Name = "CoinStatus"
    CoinStatus.Size = UDim2.new(1, -20, 0, 20)
    CoinStatus.Position = UDim2.new(0, 10, 0, 50)
    CoinStatus.BackgroundTransparency = 1
    CoinStatus.Text = "Монеты: 0 (+0 за сессию)"
    CoinStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
    CoinStatus.TextSize = 13
    CoinStatus.Font = Enum.Font.Gotham
    CoinStatus.TextXAlignment = Enum.TextXAlignment.Left
    CoinStatus.Parent = MainFrame
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Size = UDim2.new(1, -20, 0, 20)
    StatusLabel.Position = UDim2.new(0, 10, 0, 75)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "Статус: Выключен"
    StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    StatusLabel.TextSize = 13
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = MainFrame
    
    -- === КНОПКИ ===
    
    local AutoFarmButton = Instance.new("TextButton")
    AutoFarmButton.Name = "AutoFarmButton"
    AutoFarmButton.Size = UDim2.new(1, -20, 0, 32)
    AutoFarmButton.Position = UDim2.new(0, 10, 0, 110)
    AutoFarmButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    AutoFarmButton.Text = "Auto Farm: OFF"
    AutoFarmButton.TextColor3 = Color3.fromRGB(230, 230, 230)
    AutoFarmButton.TextSize = 13
    AutoFarmButton.Font = Enum.Font.GothamBold
    AutoFarmButton.Parent = MainFrame
    
    Instance.new("UICorner", AutoFarmButton).CornerRadius = UDim.new(0, 8)
    
    local NoclipButton = Instance.new("TextButton")
    NoclipButton.Name = "NoclipButton"
    NoclipButton.Size = UDim2.new(0, 165, 0, 32)
    NoclipButton.Position = UDim2.new(0, 10, 0, 150)
    NoclipButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    NoclipButton.Text = "Noclip: OFF"
    NoclipButton.TextColor3 = Color3.fromRGB(230, 230, 230)
    NoclipButton.TextSize = 13
    NoclipButton.Font = Enum.Font.GothamBold
    NoclipButton.Parent = MainFrame
    
    Instance.new("UICorner", NoclipButton).CornerRadius = UDim.new(0, 8)
    
    local AntiFlingButton = Instance.new("TextButton")
    AntiFlingButton.Name = "AntiFlingButton"
    AntiFlingButton.Size = UDim2.new(0, 165, 0, 32)
    AntiFlingButton.Position = UDim2.new(1, -175, 0, 150)
    AntiFlingButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    AntiFlingButton.Text = "Anti-Fling: OFF"
    AntiFlingButton.TextColor3 = Color3.fromRGB(230, 230, 230)
    AntiFlingButton.TextSize = 13
    AntiFlingButton.Font = Enum.Font.GothamBold
    AntiFlingButton.Parent = MainFrame
    
    Instance.new("UICorner", AntiFlingButton).CornerRadius = UDim.new(0, 8)
    
    local RejoinButton = Instance.new("TextButton")
    RejoinButton.Name = "RejoinButton"
    RejoinButton.Size = UDim2.new(0, 165, 0, 32)
    RejoinButton.Position = UDim2.new(0, 10, 0, 190)
    RejoinButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
    RejoinButton.Text = "Rejoin"
    RejoinButton.TextColor3 = Color3.fromRGB(230, 230, 230)
    RejoinButton.TextSize = 13
    RejoinButton.Font = Enum.Font.GothamBold
    RejoinButton.Parent = MainFrame
    
    Instance.new("UICorner", RejoinButton).CornerRadius = UDim.new(0, 8)
    
    local ServerHopButton = Instance.new("TextButton")
    ServerHopButton.Name = "ServerHopButton"
    ServerHopButton.Size = UDim2.new(0, 165, 0, 32)
    ServerHopButton.Position = UDim2.new(1, -175, 0, 190)
    ServerHopButton.BackgroundColor3 = Color3.fromRGB(255, 170, 50)
    ServerHopButton.Text = "Server Hop"
    ServerHopButton.TextColor3 = Color3.fromRGB(230, 230, 230)
    ServerHopButton.TextSize = 13
    ServerHopButton.Font = Enum.Font.GothamBold
    ServerHopButton.Parent = MainFrame
    
    Instance.new("UICorner", ServerHopButton).CornerRadius = UDim.new(0, 8)
    
    -- === НАСТРОЙКИ ===
    
    local SettingsLabel = Instance.new("TextLabel")
    SettingsLabel.Size = UDim2.new(1, -20, 0, 18)
    SettingsLabel.Position = UDim2.new(0, 10, 0, 235)
    SettingsLabel.BackgroundTransparency = 1
    SettingsLabel.Text = "НАСТРОЙКИ"
    SettingsLabel.TextColor3 = Color3.fromRGB(90, 140, 255)
    SettingsLabel.TextSize = 12
    SettingsLabel.Font = Enum.Font.GothamBold
    SettingsLabel.TextXAlignment = Enum.TextXAlignment.Left
    SettingsLabel.Parent = MainFrame
    
    local SpeedLabel = Instance.new("TextLabel")
    SpeedLabel.Size = UDim2.new(0, 100, 0, 20)
    SpeedLabel.Position = UDim2.new(0, 10, 0, 260)
    SpeedLabel.BackgroundTransparency = 1
    SpeedLabel.Text = "Скорость полёта:"
    SpeedLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    SpeedLabel.TextSize = 11
    SpeedLabel.Font = Enum.Font.Gotham
    SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    SpeedLabel.Parent = MainFrame
    
    local SpeedInput = Instance.new("TextBox")
    SpeedInput.Name = "SpeedInput"
    SpeedInput.Size = UDim2.new(0, 60, 0, 24)
    SpeedInput.Position = UDim2.new(0, 140, 0, 258)
    SpeedInput.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    SpeedInput.Text = "25"
    SpeedInput.TextColor3 = Color3.fromRGB(230, 230, 230)
    SpeedInput.TextSize = 12
    SpeedInput.Font = Enum.Font.Gotham
    SpeedInput.PlaceholderText = "25"
    SpeedInput.Parent = MainFrame
    
    Instance.new("UICorner", SpeedInput).CornerRadius = UDim.new(0, 6)
    
    local DelayLabel = Instance.new("TextLabel")
    DelayLabel.Size = UDim2.new(0, 100, 0, 20)
    DelayLabel.Position = UDim2.new(0, 10, 0, 290)
    DelayLabel.BackgroundTransparency = 1
    DelayLabel.Text = "Задержка TP:"
    DelayLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    DelayLabel.TextSize = 11
    DelayLabel.Font = Enum.Font.Gotham
    DelayLabel.TextXAlignment = Enum.TextXAlignment.Left
    DelayLabel.Parent = MainFrame
    
    local DelayInput = Instance.new("TextBox")
    DelayInput.Name = "DelayInput"
    DelayInput.Size = UDim2.new(0, 60, 0, 24)
    DelayInput.Position = UDim2.new(0, 140, 0, 288)
    DelayInput.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    DelayInput.Text = "2"
    DelayInput.TextColor3 = Color3.fromRGB(230, 230, 230)
    DelayInput.TextSize = 12
    DelayInput.Font = Enum.Font.Gotham
    DelayInput.PlaceholderText = "2"
    DelayInput.Parent = MainFrame
    
    Instance.new("UICorner", DelayInput).CornerRadius = UDim.new(0, 6)
    
    local InfoLabel = Instance.new("TextLabel")
    InfoLabel.Size = UDim2.new(1, -20, 0, 130)
    InfoLabel.Position = UDim2.new(0, 10, 0, 320)
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.Text = [[Первые 3 монеты: ТП
Остальные: Полёт (настраиваемая скорость)

Умный ресет: По карте/убийце
3 неудачи → ждёт смены раунда
Anti-AFK: Всегда активен
Noclip: Отключает столкновения
Anti-Fling: Защита от флингеров]]
    InfoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    InfoLabel.TextSize = 9
    InfoLabel.Font = Enum.Font.Gotham
    InfoLabel.TextWrapped = true
    InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    InfoLabel.TextYAlignment = Enum.TextYAlignment.Top
    InfoLabel.Parent = MainFrame
    
    State.UIElements = {
        MainGui = ScreenGui,
        CoinStatus = CoinStatus,
        StatusLabel = StatusLabel,
        AutoFarmButton = AutoFarmButton,
        NoclipButton = NoclipButton,
        AntiFlingButton = AntiFlingButton,
        RejoinButton = RejoinButton,
        ServerHopButton = ServerHopButton,
        SpeedInput = SpeedInput,
        DelayInput = DelayInput,
    }
    
    return State.UIElements
end

-- === ОБНОВЛЕНИЕ UI ===

local lastUIUpdate = 0

local function UpdateUI()
    local currentTime = tick()
    
    if currentTime - lastUIUpdate < 0.5 then
        return
    end
    
    lastUIUpdate = currentTime
    
    local ui = State.UIElements
    if not ui or not ui.MainGui then return end
    
    local currentCoins = GetCollectedCoinsCount()
    local sessionCoins = currentCoins - State.StartSessionCoins
    
    ui.CoinStatus.Text = string.format("Монеты: %d (+%d за сессию)", 
        currentCoins, sessionCoins)
    
    if State.AutoFarmEnabled then
        if State.FailedCollects >= State.MaxFailedCollects then
            ui.StatusLabel.Text = "Статус: Жду смены раунда..."
            ui.StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 85)
        else
            ui.StatusLabel.Text = "Статус: Фармлю монеты..."
            ui.StatusLabel.TextColor3 = Color3.fromRGB(85, 255, 120)
        end
        ui.AutoFarmButton.Text = "Auto Farm: ON"
        ui.AutoFarmButton.BackgroundColor3 = Color3.fromRGB(85, 255, 120)
    else
        ui.StatusLabel.Text = "Статус: Выключен"
        ui.StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        ui.AutoFarmButton.Text = "Auto Farm: OFF"
        ui.AutoFarmButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    end
    
    -- Noclip Button
    if State.NoclipEnabled then
        ui.NoclipButton.Text = "Noclip: ON"
        ui.NoclipButton.BackgroundColor3 = Color3.fromRGB(85, 255, 120)
    else
        ui.NoclipButton.Text = "Noclip: OFF"
        ui.NoclipButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    end
    
    -- Anti-Fling Button
    if State.AntiFlingEnabled then
        ui.AntiFlingButton.Text = "Anti-Fling: ON"
        ui.AntiFlingButton.BackgroundColor3 = Color3.fromRGB(85, 255, 120)
    else
        ui.AntiFlingButton.Text = "Anti-Fling: OFF"
        ui.AntiFlingButton.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    end
end

-- === ОБРАБОТЧИКИ КНОПОК ===

CreateUI()

State.UIElements.AutoFarmButton.MouseButton1Click:Connect(function()
    State.AutoFarmEnabled = not State.AutoFarmEnabled
    print("[Auto Farm]", State.AutoFarmEnabled and "ON" or "OFF")
    
    if State.AutoFarmEnabled then
        State.CoinBlacklist = {}
        State.StartSessionCoins = GetCollectedCoinsCount()
        print("[Auto Farm] Стартовые монеты: " .. State.StartSessionCoins)
        StartAutoFarm()
    else
        StopAutoFarm()
    end
    
    UpdateUI()
end)

State.UIElements.NoclipButton.MouseButton1Click:Connect(function()
    if State.NoclipEnabled then
        DisableNoclip()
    else
        EnableNoclip()
    end
    UpdateUI()
end)

State.UIElements.AntiFlingButton.MouseButton1Click:Connect(function()
    if State.AntiFlingEnabled then
        DisableAntiFling()
    else
        EnableAntiFling()
    end
    UpdateUI()
end)

State.UIElements.RejoinButton.MouseButton1Click:Connect(function()
    Rejoin()
end)

State.UIElements.ServerHopButton.MouseButton1Click:Connect(function()
    ServerHop()
end)

State.UIElements.SpeedInput.FocusLost:Connect(function()
    local value = tonumber(State.UIElements.SpeedInput.Text)
    if value and value >= 10 and value <= 100 then
        State.CoinFarmFlySpeed = value
        print("[Settings] Скорость полёта:", value)
    else
        State.UIElements.SpeedInput.Text = tostring(State.CoinFarmFlySpeed)
    end
end)

State.UIElements.DelayInput.FocusLost:Connect(function()
    local value = tonumber(State.UIElements.DelayInput.Text)
    if value and value >= 0.1 and value <= 5 then
        State.CoinFarmDelay = value
        print("[Settings] Задержка TP:", value)
    else
        State.UIElements.DelayInput.Text = tostring(State.CoinFarmDelay)
    end
end)

-- === ИНИЦИАЛИЗАЦИЯ ===

SetupAntiAFK()

task.spawn(function()
    while task.wait(0.5) do
        UpdateUI()
    end
end)

UpdateUI()
print("[MM2 Hybrid Auto Farm] ✅ Загружен успешно!")
print("[Anti-AFK] ✅ Всегда активен")
