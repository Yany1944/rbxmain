-- LocalScript в StarterPlayer > StarterPlayerScripts
-- MM2 Auto Farm + Hard Farm - OPTIMIZED VERSION
-- Author: AI Assistant | Date: 29.12.2025

if game.PlaceId ~= 142823291 then return end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait(2)

if getgenv().MM2_AutoFarm_Script then
    return
end
getgenv().MM2_AutoFarm_Script = true

-- === КОНФИГУРАЦИЯ ===

local CONFIG = {
    Colors = {
        Background = Color3.fromRGB(25, 25, 30),
        Section = Color3.fromRGB(35, 35, 40),
        Text = Color3.fromRGB(230, 230, 230),
        TextDark = Color3.fromRGB(150, 150, 150),
        Accent = Color3.fromRGB(90, 140, 255),
        Red = Color3.fromRGB(255, 85, 85),
        Green = Color3.fromRGB(85, 255, 120),
        Orange = Color3.fromRGB(255, 170, 50),
    },
    UI_UPDATE_INTERVAL = 0.5, -- Обновление UI раз в 0.5 сек вместо каждого кадра
    COIN_CHECK_INTERVAL = 0.2, -- Проверка монет
    HEARTBEAT_INTERVAL = 2, -- Уменьшено использование Heartbeat
}

-- === СЕРВИСЫ (КЭШИРУЕМ ЛОКАЛЬНО) ===

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- === СОСТОЯНИЕ ===

local State = {
    -- Auto Farm (базовый)
    AutoFarmEnabled = false,
    CoinFarmFlySpeed = 35,
    CoinFarmDelay = 0.3,
    CoinFarmCollected = {},
    CoinFarmThread = nil,
    
    -- Hard Farm (надстройка)
    HardFarmEnabled = false,
    isRoundActive = false,
    isProcessingHardFarm = false,
    roundStartCoins = 0,
    coinsCollectedThisRound = 0,
    participationTimerStart = 0,
    participationTimeout = 7,
    participationTimeoutAfterDeath = 8,
    lastCoinCount = 0,
    farmStatus = "Ожидание",
    
    -- UI
    UIElements = {},
    
    -- Кэширование
    cachedCoinsCount = 0,
    lastCoinsCheckTime = 0,
    cachedMap = nil,
    lastMapCheckTime = 0,
}

-- === ОПТИМИЗИРОВАННЫЕ ФУНКЦИИ ===

-- Кэшированная функция получения монет
local coinLabelCache = nil
local lastCacheTime = 0

local function GetCollectedCoinsCount()
    -- Проверяем кэш (оптимизация)
    if coinLabelCache and coinLabelCache.Parent and (tick() - lastCacheTime) < 2 then
        local success, value = pcall(function()
            return tonumber(coinLabelCache.Text) or 0
        end)
        if success then
            return value
        end
    end
    
    -- Метод 1: Прямой путь (быстрый)
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
    
    -- Метод 2: Универсальный поиск (медленный фолбек)
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

-- Кэшированная функция получения карты
local function getMap()
    local currentTime = tick()
    
    -- Кэш карты на 2 секунды
    if State.cachedMap and State.cachedMap.Parent and currentTime - State.lastMapCheckTime < 2 then
        return State.cachedMap
    end
    
    for _, v in next, Workspace:GetChildren() do
        if v:FindFirstChild("CoinContainer") then
            State.cachedMap = v
            State.lastMapCheckTime = currentTime
            return v
        end
    end
    
    State.cachedMap = nil
    return nil
end

local function getNearestCoin()
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    
    local map = getMap()
    if not map then return nil end
    
    local coinContainer = map:FindFirstChild("CoinContainer")
    if not coinContainer then return nil end
    
    local target
    local closestDistance = math.huge
    local hrpPosition = humanoidRootPart.Position

    for _, coin in pairs(coinContainer:GetChildren()) do
        if coin.Name == "Coin_Server" and not State.CoinFarmCollected[coin] then
            local distance = (coin.Position - hrpPosition).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                target = coin
            end
        end
    end
    
    return target
end

-- ОПТИМИЗИРОВАННЫЙ полет (убрал Heartbeat)
local function SmoothFlyToCoin(coin, humanoidRootPart, speed)
    speed = speed or State.CoinFarmFlySpeed

    local startPos = humanoidRootPart.Position
    local targetPos = coin.Position + Vector3.new(0, 1, 0) -- Уменьшено с 2 до 1
    local distance = (targetPos - startPos).Magnitude
    local duration = distance / speed

    local startTime = tick()

    while tick() - startTime < duration do
        if not State.AutoFarmEnabled then break end

        local character = LocalPlayer.Character
        if not character or not humanoidRootPart.Parent then break end

        local elapsed = tick() - startTime
        local alpha = math.min(elapsed / duration, 1)

        local currentPos = startPos:Lerp(targetPos, alpha)
        humanoidRootPart.CFrame = CFrame.new(currentPos)
        
        -- СБРОС СКОРОСТИ (предотвращает тряску)
        if humanoidRootPart.AssemblyLinearVelocity then
            humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end

        task.wait(0.03) -- Фиксированная задержка
    end

    -- Финальная позиция
    if State.AutoFarmEnabled and humanoidRootPart.Parent then
        humanoidRootPart.CFrame = CFrame.new(targetPos)
        if humanoidRootPart.AssemblyLinearVelocity then
            humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end
end

local function EnableNoClip(character)
    if not character then return end
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function DisableNoClip(character)
    if not character then return end
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = true
        end
    end
end

-- === ЧИСТЫЙ АВТОФАРМ ===

local function StartAutoFarm()
    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end

    if not State.AutoFarmEnabled then return end

    State.CoinFarmThread = task.spawn(function()
        print("[Auto Farm] Запущен")
        
        while State.AutoFarmEnabled do
            task.wait(0.1)

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

            local coin = getNearestCoin()
            if not coin then
                task.wait(1)
                continue
            end

            if State.CoinFarmCollected[coin] then
                continue
            end

            pcall(function()
                local currentCoins = GetCollectedCoinsCount()
                local coinsBeforeCollection = currentCoins

                if currentCoins < 3 then
                    -- ПЕРВЫЕ 3 МОНЕТЫ: ТЕЛЕПОРТ
                    local targetCFrame = coin.CFrame + Vector3.new(0, 2, 0)

                    if targetCFrame.Position.Y > -500 and targetCFrame.Position.Y < 10000 then
                        humanoidRootPart.CFrame = targetCFrame
                        
                        -- ПРИНУДИТЕЛЬНЫЙ СБОР
                        if firetouchinterest then
                            firetouchinterest(humanoidRootPart, coin, 0)
                            task.wait(0.05)
                            firetouchinterest(humanoidRootPart, coin, 1)
                        end
                        
                        task.wait(State.CoinFarmDelay)
                        
                        -- ПРОВЕРКА СБОРА
                        local coinsAfter = GetCollectedCoinsCount()
                        if coinsAfter > coinsBeforeCollection then
                            print("[Auto Farm] ✅ Монета собрана (TP)")
                        else
                            print("[Auto Farm] ⚠️ Монета не собралась")
                        end
                        
                        State.CoinFarmCollected[coin] = true
                    end
                else
                    -- ОСТАЛЬНЫЕ: ПОЛЁТ
                    EnableNoClip(character)
                    SmoothFlyToCoin(coin, humanoidRootPart, State.CoinFarmFlySpeed)
                    
                    -- ПРИНУДИТЕЛЬНЫЙ СБОР НА МЕСТЕ
                    if firetouchinterest then
                        firetouchinterest(humanoidRootPart, coin, 0)
                        task.wait(0.05)
                        firetouchinterest(humanoidRootPart, coin, 1)
                    end
                    
                    task.wait(0.2)
                    
                    -- ПРОВЕРКА СБОРА
                    local coinsAfter = GetCollectedCoinsCount()
                    if coinsAfter > coinsBeforeCollection then
                        print("[Auto Farm] ✅ Монета собрана (Fly)")
                    else
                        print("[Auto Farm] ⚠️ Монета не собралась")
                    end
                    
                    State.CoinFarmCollected[coin] = true
                    DisableNoClip(character)
                end
            end)
        end

        local character = LocalPlayer.Character
        if character then
            DisableNoClip(character)
        end

        State.CoinFarmThread = nil
        print("[Auto Farm] Остановлен")
    end)
end

local function StopAutoFarmThread()
    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end
    
    local character = LocalPlayer.Character
    if character then
        DisableNoClip(character)
    end
    
    print("[Auto Farm] Поток остановлен")
end

local function StopAutoFarm()
    State.AutoFarmEnabled = false
    StopAutoFarmThread()
    print("[Auto Farm] Полностью выключен")
end

-- === ФУНКЦИИ HARD FARM ===

local function findMurderer()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Backpack:FindFirstChild("Knife") then
            return player
        end
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character and character:FindFirstChild("Knife") then
            return player
        end
    end
    
    return nil
end

local function isMurdererPresent()
    return findMurderer() ~= nil
end

local function amIMurderer()
    return LocalPlayer.Backpack:FindFirstChild("Knife") ~= nil or 
           (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Knife") ~= nil)
end

local function isMurdererInFlight(murderer)
    if not murderer or not murderer.Character then return false end
    
    local hrp = murderer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    return hrp.Velocity.Magnitude > 500
end

local function isMurdererAlive(murderer)
    if not murderer then return false end
    
    local character = murderer.Character
    if not character or not character.Parent then 
        return false 
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then 
        return false 
    end
    
    local hasKnife = character:FindFirstChild("Knife") or murderer.Backpack:FindFirstChild("Knife")
    return hasKnife ~= nil
end

local function miniFling(playerToFling)
    if not playerToFling or not playerToFling.Character then 
        print("[Fling] Игрок не найден")
        return false
    end
    
    local a=game.Players.LocalPlayer;local b=a:GetMouse()local c={playerToFling}local d=game:GetService("Players")local e=d.LocalPlayer;local f=false;local g=function(h)local i=e.Character;local j=i and i:FindFirstChildOfClass("Humanoid")local k=j and j.RootPart;local l=h.Character;local m;local n;local o;local p;local q;if l:FindFirstChildOfClass("Humanoid")then m=l:FindFirstChildOfClass("Humanoid")end;if m and m.RootPart then n=m.RootPart end;if l:FindFirstChild("Head")then o=l.Head end;if l:FindFirstChildOfClass("Accessory")then p=l:FindFirstChildOfClass("Accessory")end;if p and p:FindFirstChild("Handle")then q=p.Handle end;if i and j and k then if k.Velocity.Magnitude<50 then getgenv().OldPos=k.CFrame end;if m and m.Sit and not f then end;if o then if o.Velocity.Magnitude>500 then print("[Fling] Цель уже в полёте")return true end end;if not o and q then if q.Velocity.Magnitude>500 then print("[Fling] Цель уже в полёте")return true end end;if o then workspace.CurrentCamera.CameraSubject=o elseif not o and q then workspace.CurrentCamera.CameraSubject=q elseif m and n then workspace.CurrentCamera.CameraSubject=m end;if not l:FindFirstChildWhichIsA("BasePart")then return false end;local r=function(s,t,u)k.CFrame=CFrame.new(s.Position)*t*u;i:SetPrimaryPartCFrame(CFrame.new(s.Position)*t*u)k.Velocity=Vector3.new(9e7,9e7*10,9e7)k.RotVelocity=Vector3.new(9e8,9e8,9e8)end;local v=function(s)local w=2;local x=tick()local y=0;repeat if k and m then if s.Velocity.Magnitude<50 then y=y+100;r(s,CFrame.new(0,1.5,0)+m.MoveDirection*s.Velocity.Magnitude/1.25,CFrame.Angles(math.rad(y),0,0))task.wait()r(s,CFrame.new(0,-1.5,0)+m.MoveDirection*s.Velocity.Magnitude/1.25,CFrame.Angles(math.rad(y),0,0))task.wait()r(s,CFrame.new(2.25,1.5,-2.25)+m.MoveDirection*s.Velocity.Magnitude/1.25,CFrame.Angles(math.rad(y),0,0))task.wait()r(s,CFrame.new(-2.25,-1.5,2.25)+m.MoveDirection*s.Velocity.Magnitude/1.25,CFrame.Angles(math.rad(y),0,0))task.wait()r(s,CFrame.new(0,1.5,0)+m.MoveDirection,CFrame.Angles(math.rad(y),0,0))task.wait()r(s,CFrame.new(0,-1.5,0)+m.MoveDirection,CFrame.Angles(math.rad(y),0,0))task.wait()else r(s,CFrame.new(0,1.5,m.WalkSpeed),CFrame.Angles(math.rad(90),0,0))task.wait()r(s,CFrame.new(0,-1.5,-m.WalkSpeed),CFrame.Angles(0,0,0))task.wait()r(s,CFrame.new(0,1.5,m.WalkSpeed),CFrame.Angles(math.rad(90),0,0))task.wait()r(s,CFrame.new(0,1.5,n.Velocity.Magnitude/1.25),CFrame.Angles(math.rad(90),0,0))task.wait()r(s,CFrame.new(0,-1.5,-n.Velocity.Magnitude/1.25),CFrame.Angles(0,0,0))task.wait()r(s,CFrame.new(0,1.5,n.Velocity.Magnitude/1.25),CFrame.Angles(math.rad(90),0,0))task.wait()r(s,CFrame.new(0,-1.5,0),CFrame.Angles(math.rad(90),0,0))task.wait()r(s,CFrame.new(0,-1.5,0),CFrame.Angles(0,0,0))task.wait()r(s,CFrame.new(0,-1.5,0),CFrame.Angles(math.rad(-90),0,0))task.wait()r(s,CFrame.new(0,-1.5,0),CFrame.Angles(0,0,0))task.wait()end else break end until s.Velocity.Magnitude>500 or s.Parent~=h.Character or h.Parent~=d or h.Character~=l or m.Sit or j.Health<=0 or tick()>x+w end;workspace.FallenPartsDestroyHeight=0/0;local z=Instance.new("BodyVelocity")z.Name="EpixVel"z.Parent=k;z.Velocity=Vector3.new(9e8,9e8,9e8)z.MaxForce=Vector3.new(1/0,1/0,1/0)j:SetStateEnabled(Enum.HumanoidStateType.Seated,false)if n and o then if(n.CFrame.p-o.CFrame.p).Magnitude>5 then v(o)else v(n)end elseif n and not o then v(n)elseif not n and o then v(o)elseif not n and not o and p and q then v(q)else return false end;z:Destroy()j:SetStateEnabled(Enum.HumanoidStateType.Seated,true)workspace.CurrentCamera.CameraSubject=j;repeat k.CFrame=getgenv().OldPos*CFrame.new(0,.5,0)i:SetPrimaryPartCFrame(getgenv().OldPos*CFrame.new(0,.5,0))j:ChangeState("GettingUp")table.foreach(i:GetChildren(),function(A,B)if B:IsA("BasePart")then B.Velocity,B.RotVelocity=Vector3.new(),Vector3.new()end end)task.wait()until(k.Position-getgenv().OldPos.p).Magnitude<25;workspace.FallenPartsDestroyHeight=getgenv().FPDH else return false end end;g(c[1])return true
end

-- === УНИВЕРСАЛЬНЫЙ ЦИКЛ ФЛИНГА ===

local function FlingCycle()
    print("[Hard Farm] ЦИКЛ ФЛИНГА: Начало")
    
    while State.isRoundActive and State.HardFarmEnabled do
        local murderer = findMurderer()
        
        if not murderer or not isMurdererAlive(murderer) then
            print("[Hard Farm] Мурдер не найден/мёртв - выход")
            break
        end
        
        local murdererCharacter = murderer.Character
        if not murdererCharacter then
            print("[Hard Farm] У мурдерера нет персонажа - ждём 2 сек")
            task.wait(2)
            continue
        end
        
        local murdererHRP = murdererCharacter:FindFirstChild("HumanoidRootPart")
        if not murdererHRP then
            print("[Hard Farm] У мурдерера нет HRP - ждём 2 сек")
            task.wait(2)
            continue
        end
        
        if isMurdererInFlight(murderer) then
            State.farmStatus = string.format("Мурдер в полёте: %s", murderer.Name)
            print("[Hard Farm] Мурдер в полёте, ждём 3 сек...")
            task.wait(3)
            continue
        end
        
        State.farmStatus = string.format("Флинг: %s", murderer.Name)
        print("[Hard Farm] Флинг мурдерера...")
        
        local success, err = pcall(miniFling, murderer)
        
        if not success then
            print("[Hard Farm] Ошибка флинга:", err)
        end
        
        task.wait(5)
    end
    
    print("[Hard Farm] ЦИКЛ ФЛИНГА: Завершён")
end

-- === СБРОС СЧЁТЧИКОВ ===

local function ResetCounters()
    State.CoinFarmCollected = {}
    State.coinsCollectedThisRound = 0
    State.roundStartCoins = GetCollectedCoinsCount()
    State.lastCoinCount = State.roundStartCoins
    State.participationTimerStart = 0
    -- Сброс кэша
    State.cachedMap = nil
    State.lastMapCheckTime = 0
    print("[Hard Farm] Счётчики сброшены. Начальные монеты:", State.roundStartCoins)
end

local function ResetCharacter()
    print("[Hard Farm] Ресет персонажа")
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

-- === GUI ===

local lastUIUpdate = 0

local function CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MM2_Farm_GUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 360, 0, 280)
    MainFrame.Position = UDim2.new(0, 10, 0, 10)
    MainFrame.BackgroundColor3 = CONFIG.Colors.Background
    MainFrame.BorderSizePixel = 2
    MainFrame.BorderColor3 = CONFIG.Colors.Accent
    MainFrame.Parent = ScreenGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundColor3 = CONFIG.Colors.Section
    Title.Text = "MM2 Auto Farm + Hard Farm"
    Title.TextColor3 = CONFIG.Colors.Text
    Title.TextSize = 16
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = Title
    
    local RoundStatus = Instance.new("TextLabel")
    RoundStatus.Name = "RoundStatus"
    RoundStatus.Size = UDim2.new(1, -20, 0, 20)
    RoundStatus.Position = UDim2.new(0, 10, 0, 50)
    RoundStatus.BackgroundTransparency = 1
    RoundStatus.Text = "Раунд: ⏳ Ожидание"
    RoundStatus.TextColor3 = CONFIG.Colors.Orange
    RoundStatus.TextSize = 13
    RoundStatus.Font = Enum.Font.Gotham
    RoundStatus.TextXAlignment = Enum.TextXAlignment.Left
    RoundStatus.Parent = MainFrame
    
    local CoinStatus = Instance.new("TextLabel")
    CoinStatus.Name = "CoinStatus"
    CoinStatus.Size = UDim2.new(1, -20, 0, 20)
    CoinStatus.Position = UDim2.new(0, 10, 0, 75)
    CoinStatus.BackgroundTransparency = 1
    CoinStatus.Text = "Монеты: 0 / 50 (+0)"
    CoinStatus.TextColor3 = CONFIG.Colors.TextDark
    CoinStatus.TextSize = 13
    CoinStatus.Font = Enum.Font.Gotham
    CoinStatus.TextXAlignment = Enum.TextXAlignment.Left
    CoinStatus.Parent = MainFrame
    
    local FarmStatus = Instance.new("TextLabel")
    FarmStatus.Name = "FarmStatus"
    FarmStatus.Size = UDim2.new(1, -20, 0, 20)
    FarmStatus.Position = UDim2.new(0, 10, 0, 100)
    FarmStatus.BackgroundTransparency = 1
    FarmStatus.Text = "Статус: Ожидание"
    FarmStatus.TextColor3 = CONFIG.Colors.TextDark
    FarmStatus.TextSize = 13
    FarmStatus.Font = Enum.Font.Gotham
    FarmStatus.TextXAlignment = Enum.TextXAlignment.Left
    FarmStatus.Parent = MainFrame
    
    local AutoFarmButton = Instance.new("TextButton")
    AutoFarmButton.Name = "AutoFarmButton"
    AutoFarmButton.Size = UDim2.new(0, 160, 0, 32)
    AutoFarmButton.Position = UDim2.new(0, 10, 0, 130)
    AutoFarmButton.BackgroundColor3 = CONFIG.Colors.Section
    AutoFarmButton.Text = "Auto Farm: OFF"
    AutoFarmButton.TextColor3 = CONFIG.Colors.Text
    AutoFarmButton.TextSize = 13
    AutoFarmButton.Font = Enum.Font.GothamBold
    AutoFarmButton.Parent = MainFrame
    
    local AutoFarmCorner = Instance.new("UICorner")
    AutoFarmCorner.CornerRadius = UDim.new(0, 8)
    AutoFarmCorner.Parent = AutoFarmButton
    
    local HardFarmButton = Instance.new("TextButton")
    HardFarmButton.Name = "HardFarmButton"
    HardFarmButton.Size = UDim2.new(0, 160, 0, 32)
    HardFarmButton.Position = UDim2.new(1, -170, 0, 130)
    HardFarmButton.BackgroundColor3 = CONFIG.Colors.Section
    HardFarmButton.Text = "Hard Farm: OFF"
    HardFarmButton.TextColor3 = CONFIG.Colors.TextDark
    HardFarmButton.TextSize = 13
    HardFarmButton.Font = Enum.Font.GothamBold
    HardFarmButton.Parent = MainFrame
    
    local HardFarmCorner = Instance.new("UICorner")
    HardFarmCorner.CornerRadius = UDim.new(0, 8)
    HardFarmCorner.Parent = HardFarmButton
    
    local SettingsLabel = Instance.new("TextLabel")
    SettingsLabel.Size = UDim2.new(1, -20, 0, 18)
    SettingsLabel.Position = UDim2.new(0, 10, 0, 175)
    SettingsLabel.BackgroundTransparency = 1
    SettingsLabel.Text = "НАСТРОЙКИ"
    SettingsLabel.TextColor3 = CONFIG.Colors.Accent
    SettingsLabel.TextSize = 12
    SettingsLabel.Font = Enum.Font.GothamBold
    SettingsLabel.TextXAlignment = Enum.TextXAlignment.Left
    SettingsLabel.Parent = MainFrame
    
    local SpeedLabel = Instance.new("TextLabel")
    SpeedLabel.Size = UDim2.new(0, 100, 0, 20)
    SpeedLabel.Position = UDim2.new(0, 10, 0, 200)
    SpeedLabel.BackgroundTransparency = 1
    SpeedLabel.Text = "Скорость:"
    SpeedLabel.TextColor3 = CONFIG.Colors.Text
    SpeedLabel.TextSize = 11
    SpeedLabel.Font = Enum.Font.Gotham
    SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    SpeedLabel.Parent = MainFrame
    
    local SpeedInput = Instance.new("TextBox")
    SpeedInput.Name = "SpeedInput"
    SpeedInput.Size = UDim2.new(0, 60, 0, 24)
    SpeedInput.Position = UDim2.new(0, 110, 0, 198)
    SpeedInput.BackgroundColor3 = CONFIG.Colors.Section
    SpeedInput.Text = "35"
    SpeedInput.TextColor3 = CONFIG.Colors.Text
    SpeedInput.TextSize = 12
    SpeedInput.Font = Enum.Font.Gotham
    SpeedInput.PlaceholderText = "35"
    SpeedInput.Parent = MainFrame
    
    local SpeedCorner = Instance.new("UICorner")
    SpeedCorner.CornerRadius = UDim.new(0, 6)
    SpeedCorner.Parent = SpeedInput
    
    local DelayLabel = Instance.new("TextLabel")
    DelayLabel.Size = UDim2.new(0, 100, 0, 20)
    DelayLabel.Position = UDim2.new(0, 10, 0, 230)
    DelayLabel.BackgroundTransparency = 1
    DelayLabel.Text = "Задержка TP:"
    DelayLabel.TextColor3 = CONFIG.Colors.Text
    DelayLabel.TextSize = 11
    DelayLabel.Font = Enum.Font.Gotham
    DelayLabel.TextXAlignment = Enum.TextXAlignment.Left
    DelayLabel.Parent = MainFrame
    
    local DelayInput = Instance.new("TextBox")
    DelayInput.Name = "DelayInput"
    DelayInput.Size = UDim2.new(0, 60, 0, 24)
    DelayInput.Position = UDim2.new(0, 110, 0, 228)
    DelayInput.BackgroundColor3 = CONFIG.Colors.Section
    DelayInput.Text = "0.3"
    DelayInput.TextColor3 = CONFIG.Colors.Text
    DelayInput.TextSize = 12
    DelayInput.Font = Enum.Font.Gotham
    DelayInput.PlaceholderText = "0.3"
    DelayInput.Parent = MainFrame
    
    local DelayCorner = Instance.new("UICorner")
    DelayCorner.CornerRadius = UDim.new(0, 6)
    DelayCorner.Parent = DelayInput
    
    local InfoLabel = Instance.new("TextLabel")
    InfoLabel.Size = UDim2.new(0, 150, 0, 50)
    InfoLabel.Position = UDim2.new(1, -160, 0, 200)
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.Text = "Hard Farm требует\nвключенный Auto Farm"
    InfoLabel.TextColor3 = CONFIG.Colors.TextDark
    InfoLabel.TextSize = 9
    InfoLabel.Font = Enum.Font.Gotham
    InfoLabel.TextWrapped = true
    InfoLabel.TextXAlignment = Enum.TextXAlignment.Right
    InfoLabel.TextYAlignment = Enum.TextYAlignment.Top
    InfoLabel.Parent = MainFrame
    
    State.UIElements = {
        MainGui = ScreenGui,
        RoundStatus = RoundStatus,
        CoinStatus = CoinStatus,
        FarmStatus = FarmStatus,
        AutoFarmButton = AutoFarmButton,
        HardFarmButton = HardFarmButton,
        SpeedInput = SpeedInput,
        DelayInput = DelayInput,
    }
    
    return State.UIElements
end

-- ОПТИМИЗИРОВАННОЕ обновление UI с ограничением частоты
function UpdateUI()
    local currentTime = tick()
    
    -- Ограничение обновления UI до CONFIG.UI_UPDATE_INTERVAL
    if currentTime - lastUIUpdate < CONFIG.UI_UPDATE_INTERVAL then
        return
    end
    
    lastUIUpdate = currentTime
    
    local ui = State.UIElements
    if not ui or not ui.MainGui then return end
    
    -- Батчевое обновление всех элементов
    if State.isRoundActive then
        ui.RoundStatus.Text = "Раунд: ✅ Активен"
        ui.RoundStatus.TextColor3 = CONFIG.Colors.Green
    else
        ui.RoundStatus.Text = "Раунд: ⏳ Ожидание"
        ui.RoundStatus.TextColor3 = CONFIG.Colors.Orange
    end
    
    local currentCoins = GetCollectedCoinsCount()
    ui.CoinStatus.Text = string.format("Монеты: %d / 50 (+%d)", 
        currentCoins, State.coinsCollectedThisRound)
    
    ui.FarmStatus.Text = "Статус: " .. State.farmStatus
    
    -- Определение цвета статуса
    local statusText = State.farmStatus
    if statusText:find("Собираю") or statusText:find("Участвую") or statusText:find("мурдерер") then
        ui.FarmStatus.TextColor3 = CONFIG.Colors.Green
    elseif statusText:find("Флинг") or statusText:find("полёте") then
        ui.FarmStatus.TextColor3 = CONFIG.Colors.Red
    elseif statusText:find("Проверка") then
        ui.FarmStatus.TextColor3 = CONFIG.Colors.Orange
    else
        ui.FarmStatus.TextColor3 = CONFIG.Colors.TextDark
    end
    
    ui.AutoFarmButton.Text = State.AutoFarmEnabled and "Auto Farm: ON" or "Auto Farm: OFF"
    ui.AutoFarmButton.BackgroundColor3 = State.AutoFarmEnabled and CONFIG.Colors.Green or CONFIG.Colors.Section
    
    ui.HardFarmButton.Text = State.HardFarmEnabled and "Hard Farm: ON" or "Hard Farm: OFF"
    
    if not State.AutoFarmEnabled then
        ui.HardFarmButton.BackgroundColor3 = CONFIG.Colors.Section
        ui.HardFarmButton.TextColor3 = CONFIG.Colors.TextDark
    elseif State.HardFarmEnabled then
        ui.HardFarmButton.BackgroundColor3 = CONFIG.Colors.Accent
        ui.HardFarmButton.TextColor3 = CONFIG.Colors.Text
    else
        ui.HardFarmButton.BackgroundColor3 = CONFIG.Colors.Section
        ui.HardFarmButton.TextColor3 = CONFIG.Colors.Text
    end
end

-- === HARD FARM ЛОГИКА ===

local function HardFarmProcess()
    if not State.HardFarmEnabled or State.isProcessingHardFarm then return end
    if not State.isRoundActive or not State.AutoFarmEnabled then return end
    
    State.isProcessingHardFarm = true
    print("[Hard Farm] ========== НАЧАЛО ОБРАБОТКИ ==========")
    
    -- СЦЕНАРИЙ 1: Я мурдерер
    if amIMurderer() then
        State.farmStatus = "Я мурдерер - фармлю до 50"
        print("[Hard Farm] СЦЕНАРИЙ 1: Я мурдерер")
        
        while State.isRoundActive and State.HardFarmEnabled and State.AutoFarmEnabled do
            task.wait(1) -- Увеличена задержка
            
            local currentCoins = GetCollectedCoinsCount()
            State.coinsCollectedThisRound = currentCoins - State.roundStartCoins
            
            if State.coinsCollectedThisRound >= 50 then
                print("[Hard Farm] Собрали 50 как мурдерер")
                State.farmStatus = "50 монет - ресет"
                
                StopAutoFarmThread()
                task.wait(0.5)
                ResetCounters()
                task.wait(0.5)
                ResetCharacter()
                break
            end
        end
        
        State.isProcessingHardFarm = false
        return
    end
    
    -- СЦЕНАРИЙ 2 и 3: Проверка участия
    State.farmStatus = "Проверка участия..."
    print("[Hard Farm] СЦЕНАРИЙ 2/3: ПРОВЕРКА УЧАСТИЯ")
    
    State.participationTimerStart = tick()
    State.lastCoinCount = GetCollectedCoinsCount()
    
    local participates = false
    local checkPhase = true
    
    while State.isRoundActive and State.HardFarmEnabled and State.AutoFarmEnabled do
        task.wait(1) -- Увеличена задержка проверки
        
        local currentCoins = GetCollectedCoinsCount()
        
        -- Проверка на 50 монет
        if currentCoins - State.roundStartCoins >= 50 then
            print("[Hard Farm] 50 монет собрано!")
            State.farmStatus = "50 монет - флинг и ресет"
            State.coinsCollectedThisRound = 50
            
            StopAutoFarmThread()
            task.wait(0.5)
            ResetCounters()
            task.wait(0.5)
            
            FlingCycle()
            
            ResetCharacter()
            State.isProcessingHardFarm = false
            return
        end
        
        -- Если монеты увеличились
        if currentCoins > State.lastCoinCount then
            State.participationTimerStart = tick()
            State.lastCoinCount = currentCoins
            State.coinsCollectedThisRound = currentCoins - State.roundStartCoins
            participates = true
            print(string.format("[Hard Farm] Монета собрана! Таймер сброшен. Всего: %d", State.coinsCollectedThisRound))
            
            if checkPhase then
                checkPhase = false
                State.farmStatus = "УЧАСТВУЕМ - собираю до 50"
                print("[Hard Farm] СЦЕНАРИЙ 3: УЧАСТВУЕМ")
            end
        end
        
        -- Проверка таймера
        local elapsed = tick() - State.participationTimerStart
        local timeoutToUse = participates and State.participationTimeoutAfterDeath or State.participationTimeout
        
        if elapsed >= timeoutToUse then
            if not participates then
                print("[Hard Farm] 7 сек без прироста - НЕ УЧАСТВУЕМ")
                State.farmStatus = "Не участвую - флинг"
                
                StopAutoFarmThread()
                task.wait(0.5)
                ResetCounters()
                task.wait(0.5)
                
                print("[Hard Farm] СЦЕНАРИЙ 4: НЕ УЧАСТВУЕМ")
                FlingCycle()
                
                ResetCharacter()
                State.isProcessingHardFarm = false
                return
            else
                print("[Hard Farm] 8 сек без прироста - УБИТЫ")
                State.farmStatus = "Убиты - флинг"
                
                StopAutoFarmThread()
                task.wait(0.5)
                ResetCounters()
                task.wait(0.5)
                
                print("[Hard Farm] СЦЕНАРИЙ 4: УБИТЫ")
                FlingCycle()
                
                ResetCharacter()
                State.isProcessingHardFarm = false
                return
            end
        end
        
        -- Обновление статуса
        if checkPhase then
            State.farmStatus = string.format("Проверка участия... (%ds)", math.floor(State.participationTimeout - elapsed))
        else
            State.farmStatus = string.format("УЧАСТВУЕМ - собираю... (%ds)", math.floor(State.participationTimeoutAfterDeath - elapsed))
        end
    end
    
    State.isProcessingHardFarm = false
    print("[Hard Farm] ========== ОБРАБОТКА ЗАВЕРШЕНА ==========")
end

-- === МОНИТОРИНГ РАУНДА (ОПТИМИЗИРОВАН) ===

task.spawn(function()
    while task.wait(1) do -- Увеличена задержка до 1 сек
        local wasActive = State.isRoundActive
        State.isRoundActive = isMurdererPresent()
        
        if State.isRoundActive and not wasActive then
            print("[MM2] ========== РАУНД НАЧАЛСЯ ==========")
            ResetCounters()
            
            if State.AutoFarmEnabled and not State.CoinFarmThread then
                StartAutoFarm()
            end
            
            if State.HardFarmEnabled and State.AutoFarmEnabled then
                task.spawn(HardFarmProcess)
            end
        end
        
        if not State.isRoundActive and wasActive then
            print("[MM2] ========== РАУНД ЗАВЕРШИЛСЯ ==========")
            print("[Hard Farm] СЦЕНАРИЙ 5: РАУНД ЗАВЕРШЁН")
            
            State.isProcessingHardFarm = false
            State.farmStatus = "Ожидание раунда"
            
            if State.CoinFarmThread then
                task.cancel(State.CoinFarmThread)
                State.CoinFarmThread = nil
            end
            
            local character = LocalPlayer.Character
            if character then
                DisableNoClip(character)
            end
            
            ResetCounters()
            
            task.wait(0.5)
            ResetCharacter()
        end
        
        UpdateUI()
    end
end)

-- Отдельный поток для обновления счётчика монет
task.spawn(function()
    while task.wait(2) do -- Увеличена задержка до 2 сек
        if State.isRoundActive then
            local currentCoins = GetCollectedCoinsCount()
            State.coinsCollectedThisRound = currentCoins - State.roundStartCoins
            UpdateUI()
        end
    end
end)

CreateUI()

-- === ОБРАБОТЧИКИ КНОПОК ===

State.UIElements.AutoFarmButton.MouseButton1Click:Connect(function()
    State.AutoFarmEnabled = not State.AutoFarmEnabled
    print("[Auto Farm]", State.AutoFarmEnabled and "ON" or "OFF")
    
    if State.AutoFarmEnabled then
        ResetCounters()
        StartAutoFarm()
    else
        StopAutoFarm()
        State.HardFarmEnabled = false
        State.isProcessingHardFarm = false
        State.farmStatus = "Выключен"
        ResetCounters()
    end
    
    UpdateUI()
end)

State.UIElements.HardFarmButton.MouseButton1Click:Connect(function()
    if not State.AutoFarmEnabled then
        print("[Hard Farm] Сначала включите Auto Farm!")
        return
    end
    
    State.HardFarmEnabled = not State.HardFarmEnabled
    print("[Hard Farm]", State.HardFarmEnabled and "ON" or "OFF")
    
    if State.HardFarmEnabled then
        if State.isRoundActive and not State.isProcessingHardFarm then
            ResetCounters()
            task.spawn(HardFarmProcess)
        end
    else
        State.isProcessingHardFarm = false
        State.farmStatus = "Hard Farm выключен"
    end
    
    UpdateUI()
end)

State.UIElements.SpeedInput.FocusLost:Connect(function()
    local value = tonumber(State.UIElements.SpeedInput.Text)
    if value and value >= 10 and value <= 100 then
        State.CoinFarmFlySpeed = value
        print("[Settings] Скорость:", value)
    else
        State.UIElements.SpeedInput.Text = tostring(State.CoinFarmFlySpeed)
    end
end)

State.UIElements.DelayInput.FocusLost:Connect(function()
    local value = tonumber(State.UIElements.DelayInput.Text)
    if value and value >= 0.1 and value <= 5 then
        State.CoinFarmDelay = value
        print("[Settings] Задержка:", value)
    else
        State.UIElements.DelayInput.Text = tostring(State.CoinFarmDelay)
    end
end)

UpdateUI()
print("[MM2 Auto Farm + Hard Farm] Загружен успешно! (ОПТИМИЗИРОВАННАЯ ВЕРСИЯ)")
