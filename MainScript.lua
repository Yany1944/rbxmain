    if game.PlaceId ~= 142823291 then return end

    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    if getgenv().MM2_ESP_Script then
        return
    end
    getgenv().MM2_ESP_Script = true

-- ✅ ПОЛНОЕ ПОДАВЛЕНИЕ CorePackages ОШИБОК
pcall(function()
    local StarterGui = game:GetService("StarterGui")
    
    -- Отключаем все CoreGui по отдельности (не используем Enum.CoreGuiType.All)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
    
    task.wait(0.5)
    
    -- Включаем обратно
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
end)


-- ДОБАВЛЕНО: Переопределяем warn и error
local oldWarn = warn
local oldError = error

warn = function(...)
    local msg = tostring(...)
    if msg:match("useSliderMotionStates") or 
       msg:match("CorePackages") or
       msg:match("Slider") then
        return
    end
    return oldWarn(...)
end

error = function(msg, level)
    if type(msg) == "string" then
        if msg:match("useSliderMotionStates") or 
           msg:match("CorePackages") or
           msg:match("Slider") then
            return
        end
    end
    return oldError(msg, level)
end


    local CONFIG = {
        HideKey = Enum.KeyCode.Q,
        CheckInterval = 0.5,
        Colors = {
            Background = Color3.fromRGB(25, 25, 30),
            Section = Color3.fromRGB(35, 35, 40),
            Text = Color3.fromRGB(220, 220, 220),
            TextDark = Color3.fromRGB(150, 150, 150),
        --  Accent = Color3.fromRGB(90, 140, 255),
            Accent = Color3.fromRGB(220, 145, 230),
            Red = Color3.fromRGB(255, 85, 85),
            Green = Color3.fromRGB(85, 255, 120),
            Orange = Color3.fromRGB(255, 170, 50),
            Stroke = Color3.fromRGB(50, 50, 55),
            Murder = Color3.fromRGB(255, 50, 50),
            Sheriff = Color3.fromRGB(50, 150, 255),
            Gun = Color3.fromRGB(255, 200, 50),
            Innocent = Color3.fromRGB(85, 255, 120)
        },
        Notification = {
            Duration = 3,
            FadeTime = 0.4
        }
    }

    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")
    local TweenService = game:GetService("TweenService")
    local LocalPlayer = Players.LocalPlayer


local State = {
    -- ESP настройки
    GunESP = false,
    MurderESP = false,
    SheriffESP = false,
    InnocentESP = false,
    
    -- Уведомления
    NotificationsEnabled = false,
    
    -- Character settings
    WalkSpeed = 18,
    JumpPower = 50,
    MaxCameraZoom = 100,
    CameraFOV = 90,
    
    -- Camera 
    ViewClipEnabled = false,
    
    -- Combat
    ShootPrediction = 0.15,
    ShootDirection = "Front",
    ExtendedHitboxSize = 15,
    ExtendedHitboxEnabled = false,
    KillAuraDistance = 2.5,
    
    -- Auto Farm
    AutoFarmEnabled = false,
    CoinFarmThread = nil,
    CoinFarmFlySpeed = 23,
    CoinFarmDelay = 2,
    UndergroundMode = false,
    UndergroundOffset = 2.5,
    CoinBlacklist = {},
    StartSessionCoins = 0,
    CoinLabelCache = nil,
    LastCacheTime = 0,
    
    -- Anti-Fling
    AntiFlingEnabled = false,
    IsFlingInProgress = false,
    SelectedPlayerForFling = nil,
    OldPos = nil,
    
    -- NoClip
    NoClipEnabled = false,
    NoClipConnection = nil,
    NoClipRespawnConnection = nil,
    NoClipObjects = nil,
    
    -- NoClip (старая система для auto farm)
    ClipEnabled = true,
    NoClipConnection = nil,
    
    -- GodMode
    GodModeEnabled = false,
    
    -- Role detection
    prevMurd = nil,
    prevSher = nil,
    heroSent = false,
    roundStart = true,
    roundActive = false,
    
    -- ESP internals
    PlayerHighlights = {},
    GunCache = {},
    
    -- System
    Connections = {},
    UIElements = {},
    RoleCheckLoop = nil,
    FPDH = workspace.FallenPartsDestroyHeight,
    
    -- UI State
    ClickTPActive = false,
    ListeningForKeybind = nil,
    
    -- Notifications
    NotificationQueue = {},
    CurrentNotification = nil,
    
    -- Keybinds
    Keybinds = {
        Sit = Enum.KeyCode.Unknown,
        Dab = Enum.KeyCode.Unknown,
        Zen = Enum.KeyCode.Unknown,
        Ninja = Enum.KeyCode.Unknown,
        Floss = Enum.KeyCode.Unknown,
        ClickTP = Enum.KeyCode.Unknown,
        GodMode = Enum.KeyCode.Unknown,
        FlingPlayer = Enum.KeyCode.Unknown,
        ThrowKnife = Enum.KeyCode.Unknown,
        NoClip = Enum.KeyCode.Unknown,
        ShootMurderer = Enum.KeyCode.Unknown,
        PickupGun = Enum.KeyCode.Unknown,
        InstantKillAll = Enum.KeyCode.Unknown
    }
}

local currentMapConnection = nil
local currentMap = nil

local function CleanupMemory()
    -- Очистка highlights
    if State.PlayerHighlights then
        for _, highlight in pairs(State.PlayerHighlights) do
            if highlight and highlight.Parent then
                pcall(function() highlight:Destroy() end)
            end
        end
        State.PlayerHighlights = {}
    end

    -- Очистка gun ESP
    if State.GunCache then
        for _, espData in pairs(State.GunCache) do
            if espData then
                pcall(function()
                    if espData.highlight then espData.highlight:Destroy() end
                    if espData.billboard then espData.billboard:Destroy() end
                end)
            end
        end
        State.GunCache = {}
    end

    -- ✅ ДОБАВЛЕНО: Сброс Gun tracking
    if currentMapConnection then
        currentMapConnection:Disconnect()
        currentMapConnection = nil
    end
    currentMap = nil

    -- Очистка очереди уведомлений
    State.NotificationQueue = {}
    State.CurrentNotification = nil

    -- Очистка coin blacklist
    State.CoinBlacklist = {}
end



local function FindRole(player)
    if not player or not player.Character then return nil end

    local character = player.Character
    local backpack = player:WaitForChild("Backpack", 2)  -- ✅ Ждем загрузки

    -- Проверка на убийцу
    if character:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife")) then
        return "Murder"
    end

    -- Проверка на шерифа
    if character:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun")) then
        return "Sheriff"
    end

    return "Innocent"
end

-- Универсальная функция поиска убийцы (возвращает Player или имя)
local function FindMurderer(returnName)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            local knife = player.Character:FindFirstChild("Knife")
            if knife then
                return returnName and player.Name or player
            end

            if player.Backpack then
                local knifeInBackpack = player.Backpack:FindFirstChild("Knife")
                if knifeInBackpack then
                    return returnName and player.Name or player
                end
            end
        end
    end
    return nil
end

-- Алиасы для совместимости
local function findMurderer()
    return FindMurderer(false) -- возвращает Player
end

local function GetMurdererName()
    return FindMurderer(true) -- возвращает Name
end


local function findNearestPlayer()
    local nearestPlayer = nil
    local shortestDistance = math.huge
    local localChar = LocalPlayer.Character
    
    if not localChar or not localChar:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local localHRP = localChar.HumanoidRootPart
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local otherHRP = player.Character:FindFirstChild("HumanoidRootPart")
            if otherHRP then
                local distance = (localHRP.Position - otherHRP.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    nearestPlayer = player
                end
            end
        end
    end
    
    return nearestPlayer
end

local function ApplyWalkSpeed(speed)
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = speed
        State.WalkSpeed = speed
    end
end

local function ApplyJumpPower(power)
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.JumpPower = power
        State.JumpPower = power
    end
end

local function ApplyMaxCameraZoom(distance)
    LocalPlayer.CameraMaxZoomDistance = distance
    State.MaxCameraZoom = distance
end

local function ApplyCharacterSettings()
    ApplyWalkSpeed(State.WalkSpeed)
    ApplyJumpPower(State.JumpPower)
    ApplyMaxCameraZoom(State.MaxCameraZoom)
end

local function CreateNotificationUI()
    local notifGui = Instance.new("ScreenGui")
    notifGui.Name = "MM2_Notifications"
    notifGui.ResetOnSpawn = false
    notifGui.DisplayOrder = 100
    notifGui.Parent = CoreGui

    local container = Instance.new("Frame")
    container.Name = "NotificationContainer"
    container.BackgroundTransparency = 1
    container.AnchorPoint = Vector2.new(0.5, 0)
    container.Position = UDim2.new(0.5, 0, 0, 80) -- правый верх
    container.Size = UDim2.new(0, 340, 1, -100)
    container.Parent = notifGui

    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 6)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.VerticalAlignment = Enum.VerticalAlignment.Top
    list.Parent = container

    State.UIElements.NotificationGui = notifGui
    State.UIElements.NotificationContainer = container
end


local function ShowNotification(richText, defaultColor)
    if not State.NotificationsEnabled then return end

    task.spawn(function()
        if not State.UIElements.NotificationGui then
            CreateNotificationUI()
        end

        local container = State.UIElements.NotificationContainer
        if not container then return end

        local notifFrame = Instance.new("Frame")
        notifFrame.Name = "NotificationItem"
        notifFrame.BackgroundColor3 = CONFIG.Colors.Section
        notifFrame.BackgroundTransparency = 0.1
        notifFrame.Size = UDim2.new(1, 0, 0, 40)
        notifFrame.Parent = container

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = notifFrame

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1
        stroke.Color = CONFIG.Colors.Stroke
        stroke.Transparency = 0.4
        stroke.Parent = notifFrame

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.RichText = true
        label.Text = richText or ""
        label.Font = Enum.Font.GothamBold
        label.TextSize = 16
        label.TextColor3 = defaultColor or Color3.fromRGB(255, 255, 255)
        label.TextTransparency = 1
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.Size = UDim2.new(1, -20, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.Parent = notifFrame

        -- ✅ НОВАЯ анимация: появление сверху вниз с fade-in
        notifFrame.AnchorPoint = Vector2.new(0.5, 0)  -- Центрируем по X
        notifFrame.Position = UDim2.new(0.5, 0, 0, -50)  -- Начинаем выше контейнера
        notifFrame.BackgroundTransparency = 1

        TweenService:Create(
            notifFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Position = UDim2.new(0.5, 0, 0, 0),  -- Опускаем на место
              BackgroundTransparency = 0.1 }
        ):Play()

        TweenService:Create(
            label,
            TweenInfo.new(CONFIG.Notification.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { TextTransparency = 0 }
        ):Play()

        task.wait(CONFIG.Notification.Duration)

        local fadeOut = TweenService:Create(
            notifFrame,
            TweenInfo.new(CONFIG.Notification.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, -50) }  -- ✅ Уходит вверх
        )
        fadeOut:Play()
        
        TweenService:Create(
            label,
            TweenInfo.new(CONFIG.Notification.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { TextTransparency = 1 }
        ):Play()
        
        fadeOut.Completed:Wait()
        notifFrame:Destroy()
    end)
end

local function ApplyFOV(fov)
    local camera = Workspace.CurrentCamera
    if camera then
        TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
            FieldOfView = fov
        }):Play()
        State.CameraFOV = fov
    end
end


local AntiFlingEnabled = false
local AntiFlingLastPos = Vector3.zero
local FlingDetectionConnection = nil
local FlingNeutralizerConnection = nil
local DetectedFlingers = {}
local FlingBlockedNotified = false


local function EnableAntiFling()
    if AntiFlingEnabled then return end
    AntiFlingEnabled = true
    
    -- Детектор флинга других игроков (без изменений)
    FlingDetectionConnection = RunService.Heartbeat:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character and player.Character:IsDescendantOf(Workspace) and player ~= LocalPlayer then
                local primaryPart = player.Character.PrimaryPart
                if primaryPart then
                    if primaryPart.AssemblyAngularVelocity.Magnitude > 50 or primaryPart.AssemblyLinearVelocity.Magnitude > 100 then
                        if not DetectedFlingers[player.Name] then
                            DetectedFlingers[player.Name] = true
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
    
    -- ✅ ИСПРАВЛЕННАЯ защита с совместимостью FlingPlayer
    FlingNeutralizerConnection = RunService.Heartbeat:Connect(function()
        local character = LocalPlayer.Character
        if character and character.PrimaryPart then
            local primaryPart = character.PrimaryPart
            
            -- ✅ ВАЖНО: Пропускаем если идёт FlingPlayer
            if State.IsFlingInProgress then
                AntiFlingLastPos = primaryPart.Position
                return
            end
            
            -- ✅ ПОНИЖЕН ПОРОГ: 250 вместо 350 (как в рабочем коде)
            if primaryPart.AssemblyLinearVelocity.Magnitude > 250 or 
               primaryPart.AssemblyAngularVelocity.Magnitude > 250 then
                
                if State.NotificationsEnabled and not FlingBlockedNotified then
                    ShowNotification(
                        "<font color=\"rgb(220, 220, 220)\">Anti-Fling: Velocity neutralized</font>",
                        CONFIG.Colors.Text
                    )
                    
                    FlingBlockedNotified = true
                    task.delay(3, function()
                        FlingBlockedNotified = false
                    end)
                end
                
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
end



local function DisableAntiFling()
    AntiFlingEnabled = false
    DetectedFlingers = {}
    
    if FlingDetectionConnection then
        FlingDetectionConnection:Disconnect()
        FlingDetectionConnection = nil
    end
    
    if FlingNeutralizerConnection then
        FlingNeutralizerConnection:Disconnect()
        FlingNeutralizerConnection = nil
    end
end

local function getAllPlayers()
    local playerList = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerList, player.Name)
        end
    end
    return playerList
end

local function getPlayerByName(playerName)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == playerName or player.DisplayName == playerName then
            return player
        end
    end
    return nil
end

local function FlingPlayer(playerToFling)
    if not playerToFling or not playerToFling.Character then 
        if State.NotificationsEnabled then
            ShowNotification(
            "<font color=\"rgb(255, 85, 85)\">Fling error: </font><font color=\"rgb(220,220,220)\">Body parts missing</font>",
            CONFIG.Colors.Text
        )
        end
        return 
    end

    local Character = LocalPlayer.Character
    if not Character then return end
    
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart
    if not RootPart then return end
    -- Временно отключаем anti-fling
    local antiFlingWasEnabled = State.AntiFlingEnabled
    if antiFlingWasEnabled then
        DisableAntiFling()
    end
    State.IsFlingInProgress = true


    local TCharacter = playerToFling.Character
    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")

    if not TRootPart and not THead and not Handle then
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Body parts missing</font>",CONFIG.Colors.Text)
        end
        return
    end

    if RootPart.Velocity.Magnitude < 50 then
        State.OldPos = RootPart.CFrame
    end

    local targetPart = TRootPart or THead or Handle
    
    if targetPart.Velocity.Magnitude > 500 then
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(220,220,220)\">Fling: Already flung</font>",CONFIG.Colors.Text)
        end
        return
    end

    workspace.CurrentCamera.CameraSubject = targetPart
    workspace.FallenPartsDestroyHeight = 0/0

    local BV = Instance.new("BodyVelocity")
    BV.Name = "EpixVel"
    BV.Parent = RootPart
    BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
    BV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)

    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    local function FPos(BasePart, Pos, Ang)
        RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
        Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
        RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
        RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    local function SFBasePart(BasePart)
        local TimeToWait = 2
        local Time = tick()
        local Angle = 0
        
        repeat
            if RootPart and THumanoid then
                if BasePart.Velocity.Magnitude < 50 then
                    Angle = Angle + 100

                    FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()

                    FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()

                    FPos(BasePart, CFrame.new(2.25, 1.5, -2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()

                    FPos(BasePart, CFrame.new(-2.25, -1.5, 2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()

                    FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()

                    FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                else
                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                        task.wait()
                    end
            else
                break
            end
        until BasePart.Velocity.Magnitude > 500 or 
              BasePart.Parent ~= playerToFling.Character or 
              playerToFling.Parent ~= Players or 
              playerToFling.Character ~= TCharacter or 
              THumanoid.Sit or 
              Humanoid.Health <= 0 or 
              tick() > Time + TimeToWait
    end

    if TRootPart and THead then
        if (TRootPart.CFrame.p - THead.CFrame.p).Magnitude > 5 then
            SFBasePart(THead)
        else
            SFBasePart(TRootPart)
        end
    elseif TRootPart and not THead then
        SFBasePart(TRootPart)
    elseif not TRootPart and THead then
        SFBasePart(THead)
    elseif not TRootPart and not THead and Accessory and Handle then
        SFBasePart(Handle)
    end

    BV:Destroy()
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    workspace.CurrentCamera.CameraSubject = Humanoid

    if State.OldPos then
        repeat
            RootPart.CFrame = State.OldPos * CFrame.new(0, 0.5, 0)
            Character:SetPrimaryPartCFrame(State.OldPos * CFrame.new(0, 0.5, 0))
            Humanoid:ChangeState("GettingUp")

            for _, part in pairs(Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Velocity = Vector3.new()
                    part.RotVelocity = Vector3.new()
                end
            end

            task.wait()
        until (RootPart.Position - State.OldPos.p).Magnitude < 25
    end

    workspace.FallenPartsDestroyHeight = State.FPDH
    -- Включаем anti-fling обратно
    State.IsFlingInProgress = false
    if antiFlingWasEnabled then
        task.delay(1, function()
            EnableAntiFling()
        end)
    end


    if State.NotificationsEnabled then
        ShowNotification("<font color=\"rgb(220,220,220)\">Player flung: " .. playerToFling.Name .. "</font>",CONFIG.Colors.Text)
    end
end

-- ╔═══════════════════════════════════════════════════════════════╗
-- ║                    🚫 NoClip ФУНКЦИИ                          ║
-- ╚═══════════════════════════════════════════════════════════════╝

-- === NoClip (УНИВЕРСАЛЬНЫЙ) ===

local function EnableNoClip()
    if State.NoClipEnabled then return end
    State.NoClipEnabled = true
    
    local character = LocalPlayer.Character
    if not character then return end
    
    -- ✅ КАК В ИСХОДНИКЕ: Собираем BasePart в таблицу один раз
    local NoClipObjects = {}
    
    for _, obj in ipairs(character:GetChildren()) do
        if obj:IsA("BasePart") then
            table.insert(NoClipObjects, obj)
        end
    end
    
    -- Сохраняем в State для доступа
    State.NoClipObjects = NoClipObjects
    
    -- ✅ КАК В ИСХОДНИКЕ: Обновляем таблицу при респавне
    State.NoClipRespawnConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(0.15)
        
        table.clear(NoClipObjects)
        
        for _, obj in ipairs(newChar:GetChildren()) do
            if obj:IsA("BasePart") then
                table.insert(NoClipObjects, obj)
            end
        end
    end)
    
    -- ✅ КАК В ИСХОДНИКЕ: Просто отключаем коллизии в Stepped
    State.NoClipConnection = RunService.Stepped:Connect(function()
        for i = 1, #NoClipObjects do
            NoClipObjects[i].CanCollide = false
        end
    end)
    
    if State.NotificationsEnabled then
        ShowNotification("<font color=\"rgb(220,220,220)\">Noclip: </font><font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Text)
    end
end


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


local function DisableNoClip()
    if not State.NoClipEnabled then return end
    State.NoClipEnabled = false
    
    -- ✅ СНАЧАЛА отключаем соединения
    if State.NoClipConnection then
        State.NoClipConnection:Disconnect()
        State.NoClipConnection = nil
    end
    
    if State.NoClipRespawnConnection then
        State.NoClipRespawnConnection:Disconnect()
        State.NoClipRespawnConnection = nil
    end
    
    -- ✅ НОВОЕ: Принудительно восстанавливаем коллизии
    if State.NoClipObjects then
        local character = LocalPlayer.Character
        if character then
            for i = 1, #State.NoClipObjects do
                local part = State.NoClipObjects[i]
                if part and part.Parent then
                    -- Восстанавливаем CanCollide для всех частей кроме HumanoidRootPart
                    if part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
        
        table.clear(State.NoClipObjects)
        State.NoClipObjects = nil
    end
    
    if State.NotificationsEnabled then
        ShowNotification("<font color=\"rgb(220,220,220)\">Noclip:</font> <font color=\"rgb(255, 85, 85)\">OFF</font>", CONFIG.Colors.Red)
    end
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

-- ╔═══════════════════════════════════════════════════════════════╗
-- ║                    ⏰ ANTI-AFK (РАБОЧИЙ)                      ║
-- ╚═══════════════════════════════════════════════════════════════╝

local function SetupAntiAFK()
    local VirtualUser = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    
    task.spawn(function()
        while getgenv().MM2_ESP_Script do
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
end


-- ╔═══════════════════════════════════════════════════════════════╗
-- ║                    🔄 REJOIN / SERVER HOP                     ║
-- ╚═══════════════════════════════════════════════════════════════╝

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

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

-- ╔═══════════════════════════════════════════════════════════════╗
-- ║    GODMODE (УДАЛЕНИЕ ТРУПА + АГРЕССИВНАЯ ЗАЩИТА)               ║
-- ╚═══════════════════════════════════════════════════════════════╝

local healthConnection = nil
local damageBlockerConnection = nil
local stateConnection = nil

local function ApplyGodMode()
    if not State.GodModeEnabled then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    pcall(function()
        humanoid.MaxHealth = math.huge
        humanoid.Health = math.huge
        
        if not character:FindFirstChild("ForceField") then
            local ff = Instance.new("ForceField")
            ff.Visible = false
            ff.Parent = character
        end
        
        if State.WalkSpeed ~= 18 then
            humanoid.WalkSpeed = State.WalkSpeed
        end
        if State.JumpPower ~= 50 then
            humanoid.JumpPower = State.JumpPower
        end
    end)
end

local function SetupHealthProtection()
    if healthConnection then
        healthConnection:Disconnect()
    end
    
    if stateConnection then
        stateConnection:Disconnect()
    end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- МГНОВЕННАЯ БЛОКИРОВКА СОСТОЯНИЯ DEAD
    stateConnection = humanoid.StateChanged:Connect(function(oldState, newState)
        if State.GodModeEnabled then
            if newState == Enum.HumanoidStateType.Dead then
                
                -- МОМЕНТАЛЬНО возвращаем состояние
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
                humanoid.Health = math.huge
            end
        end
    end)
    table.insert(State.Connections, stateConnection)
    
    -- МОНИТОРИМ HP
    healthConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        if State.GodModeEnabled and humanoid.Health < math.huge then
            humanoid.Health = math.huge
        end
    end)
    
    table.insert(State.Connections, healthConnection)
end

local function SetupDamageBlocker()
    if damageBlockerConnection then
        damageBlockerConnection:Disconnect()
    end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    damageBlockerConnection = character.ChildAdded:Connect(function(child)
        if State.GodModeEnabled then
            if child.Name == "Ragdoll" or child.Name == "CreatorTag" or 
               (child:IsA("ObjectValue") and child.Name == "creator") then
                task.spawn(function()
                    child:Destroy()
                end)
            end
        end
    end)
    
    table.insert(State.Connections, damageBlockerConnection)
end

local function ToggleGodMode()
    State.GodModeEnabled = not State.GodModeEnabled
    
    if State.GodModeEnabled then
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(220,220,220)\">GodMode:</font> <font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Green)
        end
        
        ApplyGodMode()
        SetupHealthProtection()
        SetupDamageBlocker()
        -- АГРЕССИВНЫЙ МОНИТОРИНГ HP
        local godModeConnection = RunService.Heartbeat:Connect(function()
            if State.GodModeEnabled and LocalPlayer.Character then
                local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    -- Принудительно держим HP на максимуме
                    if humanoid.Health < math.huge then
                        humanoid.Health = math.huge
                    end
                    
                    -- Блокируем состояние Dead КАЖДЫЙ КАДР
                    local state = humanoid:GetState()
                    if state == Enum.HumanoidStateType.Dead then
                        humanoid:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
            end
        end)
        table.insert(State.Connections, godModeConnection)
        
        local respawnConnection = LocalPlayer.CharacterAdded:Connect(function(character)
            if State.GodModeEnabled then
                task.wait(0.5)
                ApplyGodMode()
                SetupHealthProtection()
                SetupDamageBlocker()
                print("[GodMode] 🔄 Переподключён")
            end
        end)
        table.insert(State.Connections, respawnConnection)
    else
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(220,220,220)\">GodMode:</font> <font color=\"rgb(255, 85, 85)\">OFF</font>",CONFIG.Colors.Text)
        end
        
        if healthConnection then
            healthConnection:Disconnect()
            healthConnection = nil
        end
        
        if stateConnection then
            stateConnection:Disconnect()
            stateConnection = nil
        end
        
        if damageBlockerConnection then
            damageBlockerConnection:Disconnect()
            damageBlockerConnection = nil
        end
        
        
        for _, connection in ipairs(State.Connections) do
            if connection and connection.Connected then
                connection:Disconnect()
            end
        end
        State.Connections = {}
        
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.MaxHealth = 100
                humanoid.Health = 100
            end
            
            local ff = character:FindFirstChild("ForceField")
            if ff then
                ff:Destroy()
            end
        end
    end
end


local function CreateHighlight(adornee, color)
    if not adornee or not adornee.Parent then return nil end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = adornee
    highlight.FillColor = color
    highlight.FillTransparency = 0.8
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0.3
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = true
    highlight.Parent = adornee
    return highlight
end

local function UpdatePlayerHighlight(player, role)
    if player == LocalPlayer then return end

    local character = player.Character
    if not character or not character.Parent then 
        if State.PlayerHighlights[player] then
            pcall(function() State.PlayerHighlights[player]:Destroy() end)
            State.PlayerHighlights[player] = nil
        end
        return 
    end

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

    if State.PlayerHighlights[player] then
        pcall(function() State.PlayerHighlights[player]:Destroy() end)
        State.PlayerHighlights[player] = nil
    end

    local highlight = CreateHighlight(character, color)
    if highlight then
        highlight.Enabled = shouldShow
        State.PlayerHighlights[player] = highlight
    end
end

local function UpdateAllHighlightsVisibility()
    for player, highlight in pairs(State.PlayerHighlights) do
        if highlight and highlight.Parent then
            local items = player.Backpack
            local character = player.Character

            local role = "Innocent"
            if (items and items:FindFirstChild("Knife")) or (character and character:FindFirstChild("Knife")) then
                role = "Murder"
            elseif (items and items:FindFirstChild("Gun")) or (character and character:FindFirstChild("Gun")) then
                role = "Sheriff"
            end

            local shouldShow = false
            if role == "Murder" and State.MurderESP then
                shouldShow = true
            elseif role == "Sheriff" and State.SheriffESP then
                shouldShow = true
            elseif role == "Innocent" and State.InnocentESP then
                shouldShow = true
            end

            highlight.Enabled = shouldShow
        end
    end
end

-- Добавь функцию поиска карты
local function GetMap()
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:FindFirstChild("CoinContainer") then
            return v
        end
    end
    return nil
end

local function CreateGunESP(gunPart)
    if not gunPart or not gunPart:IsA("BasePart") then return end


        if not gunPart.Parent then
        if State.GunCache[gunPart] then
            RemoveGunESP(gunPart)
        end
        return
    end
    
    -- ✅ Если уже есть ESP, обновляем его видимость
    if State.GunCache[gunPart] then
        local espData = State.GunCache[gunPart]
        if espData.highlight then espData.highlight.Enabled = State.GunESP end
        if espData.billboard then espData.billboard.Enabled = State.GunESP end
        return
    end

    local highlight = CreateHighlight(gunPart, CONFIG.Colors.Gun)
    highlight.Enabled = State.GunESP

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = gunPart
    billboard.Size = UDim2.new(0, 150, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = State.GunESP
    billboard.Parent = gunPart

    local textLabel = Instance.new("TextLabel")
    textLabel.Text = "GUN"
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 14
    textLabel.TextColor3 = CONFIG.Colors.Gun
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.Parent = billboard

    State.GunCache[gunPart] = {
        highlight = highlight,
        billboard = billboard,
        textLabel = textLabel
    }
end

local function RemoveGunESP(gunPart)
    local espData = State.GunCache[gunPart]
    if not espData then return end

    if espData.highlight then espData.highlight:Destroy() end
    if espData.billboard then espData.billboard:Destroy() end
    State.GunCache[gunPart] = nil
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

local function SetupGunTracking()
    local mapCheckLoop = RunService.Heartbeat:Connect(function()
        local map = GetMap()
        
        if not map then
            currentMap = nil
            if currentMapConnection then
                currentMapConnection:Disconnect()
                currentMapConnection = nil
            end
            -- ✅ Очищаем кеш при пропаже карты
            for gunPart, _ in pairs(State.GunCache) do
                RemoveGunESP(gunPart)
            end
            return
        end
        
        if map ~= currentMap then
            if currentMapConnection then
                currentMapConnection:Disconnect()
                currentMapConnection = nil
            end
            
            -- ✅ Добавляем отслеживание ChildRemoved
            local removeConnection
            removeConnection = map.ChildRemoved:Connect(function(child)
                if child.Name == "GunDrop" then
                    local gunPart = child
                    if child:IsA("Model") then
                        gunPart = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
                    end
                    
                    if gunPart then
                        RemoveGunESP(gunPart)
                    end
                end
            end)
            
            currentMapConnection = map.ChildAdded:Connect(function(child)
                if child.Name == "GunDrop" then
                    task.wait(0.1)
                    
                    local gunPart = child
                    if child:IsA("Model") then
                        gunPart = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
                    end
                    
                    if gunPart and gunPart:IsA("BasePart") then
                        -- ✅ Сначала удаляем старый ESP (если был)
                        RemoveGunESP(gunPart)
                        -- Теперь создаём новый
                        CreateGunESP(gunPart)
                        
                        if State.NotificationsEnabled then
                            ShowNotification(
                                "<font color=\"rgb(255, 200, 50)\">Gun Dropped</font>",
                                CONFIG.Colors.Gun
                            )
                        end
                    end
                end
            end)
            
            -- ✅ Сохраняем оба соединения
            table.insert(State.Connections, removeConnection)
            
            currentMap = map
        end
    end)
    
    table.insert(State.Connections, mapCheckLoop)
end

local function InitialGunScan()
    if not State.GunESP then return end
    
    local map = GetMap()
    if not map then return end
    
    local gunDrop = map:FindFirstChild("GunDrop")
    if gunDrop then
        local gunPart = gunDrop
        if gunDrop:IsA("Model") then
            gunPart = gunDrop.PrimaryPart or gunDrop:FindFirstChildWhichIsA("BasePart")
        end
        
        if gunPart and gunPart:IsA("BasePart") then
            CreateGunESP(gunPart)
        end
    end
end


local function StartRoleChecking()
    if State.RoleCheckLoop then
        State.RoleCheckLoop:Disconnect()
    end

    State.RoleCheckLoop = task.spawn(function()
        while getgenv().MM2_ESP_Script do
            pcall(function()
                local murder, sheriff = nil, nil

                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        local items = p.Backpack
                        local character = p.Character

                        if (items and items:FindFirstChild("Knife")) or (character and character:FindFirstChild("Knife")) then
                            murder = p
                            UpdatePlayerHighlight(p, "Murder")
                        elseif (items and items:FindFirstChild("Gun")) or (character and character:FindFirstChild("Gun")) then
                            sheriff = p
                            UpdatePlayerHighlight(p, "Sheriff")
                        else
                            UpdatePlayerHighlight(p, "Innocent")
                        end
                    end
                end

                if not murder and State.roundActive then
                    State.roundActive = false
                    State.roundStart = true

                        if State.ExtendedHitboxEnabled then
                            DisableExtendedHitbox()
                        end

                    State.prevMurd = nil
                    State.prevSher = nil
                    State.heroSent = false

                    if State.NotificationsEnabled then
                        task.spawn(function()
                            ShowNotification("<font color=\"rgb(220, 220, 220)\">Round ended</font>",CONFIG.Colors.Text)
                        end)
                    end
                end


                if murder and sheriff and State.roundStart then
                    State.roundActive = true

                    if State.NotificationsEnabled then
                        task.spawn(function()
                            ShowNotification(
                                "<font color=\"rgb(255, 50, 50)\">Murderer: </font>" .. murder.Name .. "",
                                CONFIG.Colors.Text
                            )

                            ShowNotification(
                                "<font color=\"rgb(50, 150, 255)\">Sheriff: </font>" .. sheriff.Name .. "",
                                CONFIG.Colors.Text
                            )
                        end)
                    end
                    State.roundStart = false
                    State.prevMurd = murder
                    State.prevSher = sheriff
                    State.heroSent = false                
                    end

                if sheriff and sheriff ~= State.prevSher and murder == State.prevMurd then
                    if State.NotificationsEnabled then
                        task.spawn(function()
                            ShowNotification(
                                "<font color=\"rgb(50, 150, 255)\">Sheriff: </font>" .. sheriff.Name .. "",
                                CONFIG.Colors.Text
                            )
                        end)
                    end
                    State.heroSent = true
                    State.prevSher = sheriff
                end


                if murder and murder ~= State.prevMurd then
                    State.prevMurd = murder
                    State.roundStart = true
                end

                if sheriff and sheriff ~= State.prevSher and not State.heroSent and not State.roundStart then
                    State.prevSher = sheriff
                end
            end)

            task.wait(CONFIG.CheckInterval)
        end
    end)
end




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

local function TeleportToMouse()
    local character = LocalPlayer.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local mouse = LocalPlayer:GetMouse()
    local targetPos = mouse.Hit.Position

    if targetPos then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
    end
end

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
local originalColor = button.BackgroundColor3
    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 40, 40)}):Play()
    task.wait(0.15)
    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = originalColor}):Play()
end

local function SetKeybind(key, keyCode, button, callbacks)
    -- Проверяем, используется ли уже эта клавиша для другого действия
    for actionName, boundKey in pairs(State.Keybinds) do
        if boundKey == keyCode and actionName ~= key then
            -- Нашли дубликат! Очищаем старую привязку
            State.Keybinds[actionName] = Enum.KeyCode.Unknown
            
            -- Находим кнопку старого действия и обновляем её текст
            for _, element in pairs(State.UIElements) do
                if element.Name == actionName .. "_Button" then
                    element.Text = "Not Bound"
                    break
                end
            end
        end
    end
    
    -- Устанавливаем новую привязку
    State.Keybinds[key] = keyCode
    button.Text = keyCode.Name
    
    -- ✅ ВАЖНО: Сбрасываем состояние прослушивания
    State.ListeningForKeybind = nil
    
    -- ✅ Визуальная обратная связь (мигание кнопки)
    local originalColor = button.BackgroundColor3
    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = CONFIG.Colors.Accent}):Play()
    task.wait(0.15)
    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = originalColor}):Play()
end

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

local function knifeThrow(silent)
    -- Проверка: игрок убийца?
    local murderer = findMurderer()
    if murderer ~= LocalPlayer then 
        if not silent then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">You're not murderer.</font>",CONFIG.Colors.Text)
        end
        return 
    end

    -- Проверка: нож экипирован?
    if not LocalPlayer.Character:FindFirstChild("Knife") then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if LocalPlayer.Backpack:FindFirstChild("Knife") then
            hum:EquipTool(LocalPlayer.Backpack:FindFirstChild("Knife"))
            task.wait(0.3)
        else
            if not silent then
                ShowNotification("<font color=\"rgb(220, 220, 220)\">You don't have the knife..?</font>",CONFIG.Colors.Text)
            end
            return
        end
    end
    local knife = LocalPlayer.Character:FindFirstChild("Knife")
    if not knife then
        if not silent then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220, 220, 220)\">Knife not equipped</font>",CONFIG.Colors.Text)
        end
        return
    end

    -- Проверка что у персонажа есть RightHand
    if not LocalPlayer.Character:FindFirstChild("RightHand") then
        if not silent then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220, 220, 220)\">No RightHand</font>", nil)
        end
        return
    end

    -- ✅ ПОЛУЧАЕМ ПОЗИЦИЮ КУРСОРА (НЕ БЛИЖАЙШЕГО ИГРОКА!)
    local mouse = LocalPlayer:GetMouse()
    local targetPosition = mouse.Hit.Position
    
    if not targetPosition then
        if not silent then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220, 220, 220)\">No mouse position</font>", nil)
        end
        return
    end

    -- ✅ ПРАВИЛЬНЫЕ АРГУМЕНТЫ ДЛЯ БРОСКА
    -- Arg 1: CFrame позиции правой руки
    -- Arg 2: CFrame позиции КУРСОРА (не игрока!)
    local argsThrowRemote = {
        [1] = CFrame.new(LocalPlayer.Character.RightHand.Position),
        [2] = CFrame.new(targetPosition)  -- Позиция мыши!
    }

    -- Бросаем нож через Events.KnifeThrown
    local success, err = pcall(function()
        LocalPlayer.Character.Knife.Events.KnifeThrown:FireServer(unpack(argsThrowRemote))
    end)
end

local CanShootMurderer = true

local function shootMurderer()
    if not CanShootMurderer then
        return
    end
    CanShootMurderer = false

    -- Проверка: ты шериф/герой?
    local sheriff = nil
    for _, p in pairs(Players:GetPlayers()) do
        local items = p.Backpack
        local character = p.Character
        if (items and items:FindFirstChild("Gun")) or (character and character:FindFirstChild("Gun")) then
            sheriff = p
            break
        end
    end

    if sheriff ~= LocalPlayer then
        ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">Not sheriff/hero</font>", nil)
        task.delay(1, function()
            CanShootMurderer = true
        end)
        return
    end

    -- Найти убийцу
    local murderer = findMurderer()
    if not murderer then
        ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">No murderer found</font>", nil)
        task.delay(1, function()
            CanShootMurderer = true
        end)
        return
    end

    -- Экипировать пистолет
    if not LocalPlayer.Character:FindFirstChild("Gun") then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if LocalPlayer.Backpack:FindFirstChild("Gun") then
            hum:EquipTool(LocalPlayer.Backpack:FindFirstChild("Gun"))
            task.wait(0.3)
        else
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">No gun found</font>", nil)
            task.delay(1, function()
                CanShootMurderer = true
            end)
            return
        end
    end

    local murdererHRP = murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart")
    if not murdererHRP then
        ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">No murderer HRP</font>", nil)
        task.delay(1, function()
            CanShootMurderer = true
        end)
        return
    end

    -- ПРЕДСКАЗАНИЕ ПОЗИЦИИ
    local velocity = murdererHRP.AssemblyLinearVelocity
    local currentPos = murdererHRP.Position

    local predictionTime = State.ShootPrediction
    local predictedPos = currentPos + (velocity * predictionTime)

    local chestOffset = Vector3.new(0, 0.5, 0)
    local targetPos = predictedPos + chestOffset

    local shootDistance = 3
    local shootFromPos

    if State.ShootDirection == "Behind" then
        shootFromPos = predictedPos - (murdererHRP.CFrame.LookVector * shootDistance) + chestOffset
    else
        shootFromPos = predictedPos + (murdererHRP.CFrame.LookVector * shootDistance) + chestOffset
    end

    local args = {
        [1] = CFrame.new(shootFromPos),
        [2] = CFrame.new(targetPos)
    }

    local success, err = pcall(function()
        LocalPlayer.Character:WaitForChild("Gun"):WaitForChild("Shoot"):FireServer(unpack(args))
    end)

    if success then
        ShowNotification(
            "<font color=\"rgb(255, 85, 85)\">Shot fired: </font>" .. murderer.Name .. " [" .. State.ShootDirection .. "]",CONFIG.Colors.Text)
    else
        ShowNotification(
            "<font color=\"rgb(255, 85, 85)\">Shoot failed: </font>" .. tostring(err) .. "",
            CONFIG.Colors.Text
        )
    end

    task.delay(1, function()
        CanShootMurderer = true
    end)
end

local function pickupGun()
    -- Проверяем что пистолет существует на карте
    local gun = Workspace:FindFirstChild("GunDrop", true) -- true = recursive search
    
    if not gun then
        ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">No gun on map</font>",CONFIG.Colors.Text)
        return
    end
    
    -- Сохраняем текущую позицию
    local character = LocalPlayer.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local previousPosition = hrp.CFrame
    
    -- Телепортируемся к пистолету
    hrp.CFrame = gun.CFrame + Vector3.new(0, 2, 0)
    
    -- Ждём пока подберём
    task.wait(0.08)
    
    -- Возвращаемся назад
    hrp.CFrame = previousPosition Vector3.new(0, 2, 0)
    ShowNotification("<font color=\"rgb(220, 220, 220)\">Gun: Picked up</font>",CONFIG.Colors.Text)
end

local OriginalSizes = {}
local HitboxConnection = nil

local function EnableExtendedHitbox()
    if State.ExtendedHitboxEnabled then return end
    State.ExtendedHitboxEnabled = true
    
    -- ✅ RenderStepped вместо Heartbeat - меньше лагов
    HitboxConnection = RunService.RenderStepped:Connect(function()
        local size = Vector3.new(
            State.ExtendedHitboxSize, 
            State.ExtendedHitboxSize, 
            State.ExtendedHitboxSize
        )
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local character = player.Character
                if character then
                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if hrp and hrp:IsA("BasePart") then
                        if not OriginalSizes[player] then
                            OriginalSizes[player] = {
                                Size = hrp.Size,
                                Transparency = hrp.Transparency,
                                CanCollide = hrp.CanCollide
                            }
                        end
                        
                        hrp.Size = size
                        hrp.Transparency = 0.9
                        hrp.CanCollide = true  -- ✅ Оставляем true для коллизий
                    end
                end
            end
        end
    end)
end


local function DisableExtendedHitbox()
    if not State.ExtendedHitboxEnabled then return end
    State.ExtendedHitboxEnabled = false
    
    if HitboxConnection then
        HitboxConnection:Disconnect()
        HitboxConnection = nil
    end
    
    -- Восстанавливаем всё
    for player, original in pairs(OriginalSizes) do
        if player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Size = original.Size
                hrp.Transparency = original.Transparency
                hrp.CanCollide = original.CanCollide
            end
        end
    end
    
    OriginalSizes = {}
    
end

local function UpdateHitboxSize(newSize)
    State.ExtendedHitboxSize = newSize
end

local function EnableViewClip()
    if State.ViewClipEnabled then return end
    State.ViewClipEnabled = true
    
    -- ✅ Изменяем режим камеры (из сурса)
    LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam

end

local function DisableViewClip()
    if not State.ViewClipEnabled then return end
    State.ViewClipEnabled = false
    
    -- ✅ Возвращаем обычный режим камеры
    LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom

end

local killAuraCon = nil
local anchoredPlayers = {}

local function ToggleKillAura(state)
    if state then
        anchoredPlayers = {}
        
        if killAuraCon then
            killAuraCon:Disconnect()
        end
        
        killAuraCon = RunService.Heartbeat:Connect(function()
            local localHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not localHRP then return end
            
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player ~= LocalPlayer then
                    local hrp = player.Character.HumanoidRootPart
                    local distance = (hrp.Position - localHRP.Position).Magnitude
                    
                    -- ✅ Проверяем дистанцию 7 studs для активации
                    if distance <= 7 then
                        pcall(function()
                            hrp.Anchored = true
                            -- ✅ Телепортируем на безопасную дистанцию из State (2.5 studs)
                            hrp.CFrame = localHRP.CFrame + (localHRP.CFrame.LookVector * State.KillAuraDistance)
                        end)
                        
                        if not anchoredPlayers[player] then
                            anchoredPlayers[player] = true
                        end
                    end
                end
            end
        end)
        
    else
        if killAuraCon then
            killAuraCon:Disconnect()
            killAuraCon = nil
        end
        
        -- Освобождаем заанкоренных игроков
        for player, _ in pairs(anchoredPlayers) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                pcall(function()
                    player.Character.HumanoidRootPart.Anchored = false
                end)
            end
        end
        anchoredPlayers = {}
    end
end




local function InstantKillAll()
    -- Проверка роли
    if findMurderer() ~= LocalPlayer then
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">You're not murderer.</font>",CONFIG.Colors.Text)
        end
        return
    end
    
    -- Проверка наличия ножа
    if not LocalPlayer.Character:FindFirstChild("Knife") then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if LocalPlayer.Backpack:FindFirstChild("Knife") then
            hum:EquipTool(LocalPlayer.Backpack:FindFirstChild("Knife"))
            task.wait(0.2)
        else
            if State.NotificationsEnabled then
                ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">No knife in inventory</font>",CONFIG.Colors.Text)
            end
            return
        end
    end
    
    local localHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localHRP then return end
    
    -- ✅ ТОЛЬКО ТЕЛЕПОРТ всех игроков к себе
    local teleportedCount = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player ~= LocalPlayer then
            local hrp = player.Character.HumanoidRootPart
            pcall(function()
                hrp.Anchored = true
                hrp.CFrame = localHRP.CFrame + (localHRP.CFrame.LookVector * 2.5)
                teleportedCount = teleportedCount + 1
            end)
        end
    end
    
    -- ✅ Уведомление о том, что нужно бить самому
    if State.NotificationsEnabled then
        ShowNotification("<font color=\"rgb(220, 220, 220)\">Players Teleported: " .. teleportedCount .. "</font> <font color=\"rgb(220, 220, 220)\">Now swing your knife!</font>",CONFIG.Colors.Text)
    end
    
    -- Освобождаем через 3 секунды
    task.spawn(function()
        task.wait(3)
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player ~= LocalPlayer then
                pcall(function()
                    player.Character.HumanoidRootPart.Anchored = false
                end)
            end
        end
    end)
end

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
        Text = "MM2 <font color=\"rgb(128, 0, 128)\">for my lubimka</font>",
        --Text = "MM2 ESP <font color=\"rgb(90,140,255)\">v6.0 Tabs</font>",
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
       
        local textWidth = game:GetService("TextService"):GetTextSize(name, 13, Enum.Font.GothamBold, Vector2.new(999, 35)).X
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
                TweenService:Create(currentTab.Btn, TweenInfo.new(0.2), {BackgroundColor3 = CONFIG.Colors.Section, TextColor3 = CONFIG.Colors.TextDark}):Play()
                currentTab.Page.Visible = false
            end
            currentTab = {Btn = tabBtn, Page = page}
            TweenService:Create(tabBtn, TweenInfo.new(0.2), {BackgroundColor3 = CONFIG.Colors.Accent, TextColor3 = CONFIG.Colors.Text}):Play()
            page.Visible = true
        end


        tabBtn.MouseButton1Click:Connect(Activate)


        if #Tabs == 0 then
            Activate()
        end
        table.insert(Tabs, {Btn = tabBtn, Page = page})


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

        function TabFunctions:CreateDropdown(title, desc, options, default, callback)
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
            callback(option)
            TweenService:Create(dropdownFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 95, 0, 0)
            }):Play()
            task.wait(0.2)
            dropdownFrame.Visible = false
        end)
        
        optionBtn.MouseEnter:Connect(function()
            TweenService:Create(optionBtn, TweenInfo.new(0.15), {BackgroundColor3 = CONFIG.Colors.Accent}):Play()
        end)
        
        optionBtn.MouseLeave:Connect(function()
            TweenService:Create(optionBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(50, 50, 55)}):Play()
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
            TweenService:Create(dropdownFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 95, 0, calculatedHeight)
            }):Play()
        else
            TweenService:Create(dropdownFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 95, 0, 0)
            }):Play()
            task.wait(0.2)
            dropdownFrame.Visible = false
        end
    end)
    
    return dropdown
end



        function TabFunctions:CreateToggle(title, desc, callback)
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


        function TabFunctions:CreateInputField(title, desc, defaultValue, callback)
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
   
            inputBox.FocusLost:Connect(function(enterPressed)
                local value = tonumber(inputBox.Text)
                if value then
                    callback(value)
                else
                    inputBox.Text = tostring(defaultValue)
                end
            end)
        end


        function TabFunctions:CreateSlider(title, description, min, max, default, callback, step)
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
               
                callback(value)
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
                Name = keybindKey .. "_Button",  -- ✅ ДОБАВЬТЕ ЭТО
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

    -- ✅ ФУНКЦИЯ ЗАКРЫТИЯ ДРОПДАУНА
    local function closeDropdown()
        if dropdownFrame.Visible then
            TweenService:Create(dropdownFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 165, 0, 0)
            }):Play()
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
        
        for i, playerName in ipairs(players) do
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
            TweenService:Create(dropdownFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 165, 0, calculatedHeight)
            }):Play()
        else
            closeDropdown()
        end
    end)

    -- ✅ НОВОЕ: Закрытие при клике мимо
    local clickOutsideConnection = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dropdownFrame.Visible then
            local mousePos = UserInputService:GetMouseLocation()
            local framePos = dropdownFrame.AbsolutePosition
            local frameSize = dropdownFrame.AbsoluteSize
            local dropdownPos = dropdown.AbsolutePosition
            local dropdownSize = dropdown.AbsoluteSize
            
            -- Проверяем, клик вне дропдауна и вне кнопки
            local outsideFrame = mousePos.X < framePos.X or mousePos.X > framePos.X + frameSize.X or
                                 mousePos.Y < framePos.Y or mousePos.Y > framePos.Y + frameSize.Y
            
            local outsideButton = mousePos.X < dropdownPos.X or mousePos.X > dropdownPos.X + dropdownSize.X or
                                  mousePos.Y < dropdownPos.Y or mousePos.Y > dropdownPos.Y + dropdownSize.Y
            
            if outsideFrame and outsideButton then
                closeDropdown()
            end
        end
    end)
    
    table.insert(State.Connections, clickOutsideConnection)
    
    -- ✅ НОВОЕ: Сохраняем ссылку на функцию закрытия для других событий
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


        function TabFunctions:CreateButton(title, buttonText, color, callback)
            local card = Create("Frame", {
                BackgroundColor3 = CONFIG.Colors.Section,
                Size = UDim2.new(1, 0, 0, 50),
                Parent = page
            })
            AddCorner(card, 8)
            AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)
   
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
   
            button.MouseButton1Click:Connect(callback)
           
            button.MouseEnter:Connect(function()
                local hoverColor = Color3.fromRGB(
                    math.min(255, color.R * 255 + 20),
                    math.min(255, color.G * 255 + 20),
                    math.min(255, color.B * 255 + 20)
                )
                TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
            end)
           
            button.MouseLeave:Connect(function()
                TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
            end)
           
            return button
        end


        return TabFunctions
    end


    -- ═══════════════════════════════════════════════════════════════
    --              СОЗДАНИЕ ВКЛАДОК И РАСПРЕДЕЛЕНИЕ ФУНКЦИЙ
    -- ═══════════════════════════════════════════════════════════════


    local MainTab = CreateTab("Main")
   
    MainTab:CreateSection("CHARACTER SETTINGS")
    MainTab:CreateInputField("WalkSpeed", "Set custom walk speed", State.WalkSpeed, ApplyWalkSpeed)
    MainTab:CreateInputField("JumpPower", "Set custom jump power", State.JumpPower, ApplyJumpPower)
    MainTab:CreateInputField("Max Camera Zoom", "Set maximum camera distance", State.MaxCameraZoom, ApplyMaxCameraZoom)
   
    MainTab:CreateSection("CAMERA")
    MainTab:CreateInputField("Field of View", "Set custom camera FOV", State.CameraFOV, function(v) pcall(function() ApplyFOV(v) end) end)
    MainTab:CreateToggle("ViewClip", "Camera clips through walls", function(s) if s then EnableViewClip() else DisableViewClip() end end)
   
    MainTab:CreateSection("TELEPORT & MOVEMENT")
    MainTab:CreateKeybindButton("Click TP (Hold Key)", "clicktp", "ClickTP")
    MainTab:CreateKeybindButton("Toggle NoClip", "NoClip", "NoClip")
   
    MainTab:CreateSection("GODMODE")
    MainTab:CreateKeybindButton("Toggle GodMode", "godmode", "GodMode")


    local VisualsTab = CreateTab("Visuals")
   
    VisualsTab:CreateSection("NOTIFICATIONS")
    VisualsTab:CreateToggle("Enable Notifications", "Show role and gun notifications", function(s) State.NotificationsEnabled = s end)
   
    VisualsTab:CreateSection("ESP OPTIONS (Highlight)")
    VisualsTab:CreateToggle("Gun ESP", "Highlight dropped guns", function(s) State.GunESP = s; if s then InitialGunScan() else UpdateGunESPVisibility() end end)
    VisualsTab:CreateToggle("Murder ESP", "Highlight murderer", function(s) State.MurderESP = s; UpdateAllHighlightsVisibility() end)
    VisualsTab:CreateToggle("Sheriff ESP", "Highlight sheriff", function(s) State.SheriffESP = s; UpdateAllHighlightsVisibility() end)
    VisualsTab:CreateToggle("Innocent ESP", "Highlight innocent players", function(s) State.InnocentESP = s; UpdateAllHighlightsVisibility() end)


    local CombatTab = CreateTab("Combat")
   
    CombatTab:CreateSection("EXTENDED HITBOX")
    CombatTab:CreateToggle("Enable Extended Hitbox", "Makes all players easier to hit", function(s) if s then EnableExtendedHitbox() else DisableExtendedHitbox() end end)
    CombatTab:CreateSlider("Hitbox Size", "Larger = easier to hit (10-30)", 10, 30, 15, function(v) State.ExtendedHitboxSize = v; if State.ExtendedHitboxEnabled then UpdateHitboxSize(v) end end, 1)
   
    CombatTab:CreateSection("MURDERER TOOLS")
    CombatTab:CreateKeybindButton("Throw Knife to Nearest", "throwknife", "ThrowKnife")
    CombatTab:CreateToggle("Murderer Kill Aura", "Auto kill nearby players", function(s) ToggleKillAura(s) end)
    CombatTab:CreateKeybindButton("Instant Kill All (Murderer)", "instantkillall", "InstantKillAll")
   
    CombatTab:CreateSection("SHERIFF TOOLS")
    CombatTab:CreateKeybindButton("Shoot Murderer (Instakill)", "shootmurderer", "ShootMurderer")
    CombatTab:CreateDropdown(
    "Shoot Direction",
    "Choose shooting angle",
    {"Behind", "Front"},
    "Front",
    function(value)
        State.ShootDirection = value
    end)
    CombatTab:CreateSlider("Prediction Time", "Adjust for moving targets (0.05-0.30)", 0.05, 0.30, 0.15, function(v) State.ShootPrediction = v end, 0.05)
    CombatTab:CreateKeybindButton("Pickup Dropped Gun (TP)", "pickupgun", "PickupGun")


    local FarmTab = CreateTab("Farming")
   
    FarmTab:CreateSection("AUTO FARM")
    FarmTab:CreateToggle("Auto Farm Coins", "Automatic coin collection", function(s)
        State.AutoFarmEnabled = s
        if s then
            State.CoinBlacklist = {}
            State.StartSessionCoins = GetCollectedCoinsCount()
            ShowNotification(
                "Auto Farm: <font color=\"rgb(85, 255, 120)\">ON</font>",
                CONFIG.Colors.Text
            )
            StartAutoFarm()
        else
            StopAutoFarm()
            ShowNotification(
            "Auto Farm: <font color=\"rgb(255, 85, 85)\">OFF</font>",
            CONFIG.Colors.Text
        )
        end
    end)
   
    FarmTab:CreateToggle("Underground Mode", "Fly under the map (safer)", function(s) State.UndergroundMode = s end)
    FarmTab:CreateSlider("Fly Speed", "Flying speed (10-30)", 10, 30, 23, function(v) State.CoinFarmFlySpeed = v end, 1)
    FarmTab:CreateSlider("TP Delay", "Delay between TPs (0.5-5.0)", 0.5, 5.0, 2.0, function(v) State.CoinFarmDelay = v end, 0.5)


    local FunTab = CreateTab("Fun")
   
    FunTab:CreateSection("ANIMATION KEYBINDS")
    FunTab:CreateKeybindButton("Sit Animation", "sit", "Sit")
    FunTab:CreateKeybindButton("Dab Animation", "dab", "Dab")
    FunTab:CreateKeybindButton("Zen Animation", "zen", "Zen")
    FunTab:CreateKeybindButton("Ninja Animation", "ninja", "Ninja")
    FunTab:CreateKeybindButton("Floss Animation", "floss", "Floss")
   
    FunTab:CreateSection("ANTI-FLING")
    FunTab:CreateToggle("Enable Anti-Fling", "Protect yourself from flingers", function(s) if s then EnableAntiFling() else DisableAntiFling() end end)
   
    FunTab:CreateSection("FLING PLAYER")
    FunTab:CreatePlayerDropdown("Select Target", "Choose player to fling")
    FunTab:CreateKeybindButton("Fling Selected Player", "fling", "FlingPlayer")


    local UtilityTab = CreateTab("Utility")
   
    UtilityTab:CreateSection("SERVER MANAGEMENT")
    UtilityTab:CreateButton("", "🔄 Rejoin Server", CONFIG.Colors.Accent, function() Rejoin() end)
    UtilityTab:CreateButton("", "🌐 Server Hop", Color3.fromRGB(100, 200, 100), function() ServerHop() end)


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
    -- Закрыть все открытые дропдауны
    if State.UIElements.OpenDropdowns then
        for _, closeFunc in ipairs(State.UIElements.OpenDropdowns) do
            pcall(closeFunc)
        end
        State.UIElements.OpenDropdowns = {}
    end

    -- Очистка ESP / gun / coin
    CleanupMemory()

    -- Выключаем все активные режимы
    if State.AutoFarmEnabled then
        StopAutoFarm()
    end
    if State.NoClipEnabled then
        DisableNoClip()
    end
    if State.AntiFlingEnabled then
        DisableAntiFling()
    end
    if State.ExtendedHitboxEnabled then
        DisableExtendedHitbox()
    end
    if State.GodModeEnabled then
        ToggleGodMode()  -- сам отключит свои коннекты и сбросит HP
    end

    -- Отключение всех общих соединений
    for _, connection in ipairs(State.Connections) do
        pcall(function()
            if connection and connection.Disconnect then
                connection:Disconnect()
            end
        end)
    end
    State.Connections = {}

    -- Очистка UI
    if gui then pcall(function() gui:Destroy() end) end
    if State.UIElements.NotificationGui then
        pcall(function() State.UIElements.NotificationGui:Destroy() end)
        State.UIElements.NotificationGui = nil
        State.UIElements.NotificationContainer = nil
    end

    -- Финальный флаг
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
       
        if processed then return end
       
        if State.ListeningForKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
    local key = input.KeyCode
    local bindData = State.ListeningForKeybind
    
    if key == Enum.KeyCode.Delete or key == Enum.KeyCode.Backspace then
        ClearKeybind(bindData.key, bindData.button)
        State.ListeningForKeybind = nil  -- ✅ Сброс состояния
        return
    end
    
    SetKeybind(bindData.key, key, bindData.button, {})
    -- State.ListeningForKeybind = nil теперь внутри SetKeybind
    return
end
       
        if input.KeyCode == State.Keybinds.Sit and State.Keybinds.Sit ~= Enum.KeyCode.Unknown then PlayEmote("sit")
        elseif input.KeyCode == State.Keybinds.Dab and State.Keybinds.Dab ~= Enum.KeyCode.Unknown then PlayEmote("dab")
        elseif input.KeyCode == State.Keybinds.Zen and State.Keybinds.Zen ~= Enum.KeyCode.Unknown then PlayEmote("zen")
        elseif input.KeyCode == State.Keybinds.Ninja and State.Keybinds.Ninja ~= Enum.KeyCode.Unknown then PlayEmote("ninja")
        elseif input.KeyCode == State.Keybinds.Floss and State.Keybinds.Floss ~= Enum.KeyCode.Unknown then PlayEmote("floss")
        end
       
        if input.KeyCode == State.Keybinds.ThrowKnife and State.Keybinds.ThrowKnife ~= Enum.KeyCode.Unknown then
            pcall(function() knifeThrow(true) end)
        end
        if input.KeyCode == State.Keybinds.InstantKillAll and State.Keybinds.InstantKillAll ~= Enum.KeyCode.Unknown then
            pcall(function() InstantKillAll() end)
        end
       
        if input.KeyCode == State.Keybinds.ShootMurderer and State.Keybinds.ShootMurderer ~= Enum.KeyCode.Unknown then
            pcall(function() shootMurderer() end)
        end
       
        if input.KeyCode == State.Keybinds.PickupGun and State.Keybinds.PickupGun ~= Enum.KeyCode.Unknown then
            pcall(function() pickupGun() end)
        end
       
        if input.KeyCode == State.Keybinds.ClickTP and State.Keybinds.ClickTP ~= Enum.KeyCode.Unknown then
            State.ClickTPActive = true
        end
       
        if input.KeyCode == State.Keybinds.GodMode and State.Keybinds.GodMode ~= Enum.KeyCode.Unknown then
            ToggleGodMode()
        end
       
        if input.KeyCode == State.Keybinds.FlingPlayer and State.Keybinds.FlingPlayer ~= Enum.KeyCode.Unknown then
            if State.SelectedPlayerForFling then
                local targetPlayer = getPlayerByName(State.SelectedPlayerForFling)
                if targetPlayer and targetPlayer.Character then
                    pcall(function() FlingPlayer(targetPlayer) end)
                end
            end
        end
       
        if input.KeyCode == State.Keybinds.NoClip and State.Keybinds.NoClip ~= Enum.KeyCode.Unknown then
            if State.NoClipEnabled then DisableNoClip() else EnableNoClip() end
        end
    end)
   
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == State.Keybinds.ClickTP then
            State.ClickTPActive = false
        end
    end)
   
    local mouse = LocalPlayer:GetMouse()
    mouse.Button1Down:Connect(function()
        if State.ClickTPActive then TeleportToMouse() end
    end)
end


LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    ApplyCharacterSettings()


    State.prevMurd = nil
    State.prevSher = nil
    State.heroSent = false
    State.roundStart = true
    State.roundActive = false
    CleanupMemory()
    end)

-- ═══════════════════════════════════════════════════════════════
--                      ЗАПУСК СКРИПТА
-- ═══════════════════════════════════════════════════════════════

CreateUI()
CreateNotificationUI()
ApplyCharacterSettings()

-- ✅ Применяем FOV
pcall(function()
    ApplyFOV(State.CameraFOV)
end)

SetupGunTracking()
InitialGunScan()
StartRoleChecking()
SetupAntiAFK()

-- выводим в консоль
print("╔════════════════════════════════════════════╗")
print("║   MM2 ESP v6.0 - Successfully Loaded!     ║")
print("║   Press [" .. CONFIG.HideKey.Name .. "] to toggle GUI               ║")
print("╚════════════════════════════════════════════╝")
