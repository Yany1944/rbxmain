    if game.PlaceId ~= 142823291 then return end

    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    if getgenv().MM2_ESP_Script then
        return
    end
    getgenv().MM2_ESP_Script = true

   pcall(function()
    local StarterGui = game:GetService("StarterGui")
    
    -- Отключаем встроенные уведомления
    StarterGui:SetCore("TopbarEnabled", true)
    
    -- Блокируем конфликтующие функции
    local function safeEmpty() return false end
    local function safeNothing() end
    
    _G.useSliderMotionStates = safeEmpty
    getgenv().useSliderMotionStates = safeEmpty
    _G.SendNotification = safeNothing
    getgenv().SendNotification = safeNothing
    
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
            Text = Color3.fromRGB(230, 230, 230),
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
            Duration = 2.5,
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
    CoinFarmFlySpeed = 24,
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
    
    -- Noclip
    NoclipEnabled = false,
    NoclipConnection = nil,
    NoclipRespawnConnection = nil,
    NoclipObjects = nil,
    
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
        Noclip = Enum.KeyCode.Unknown,
        ShootMurderer = Enum.KeyCode.Unknown,
        PickupGun = Enum.KeyCode.Unknown,
        InstantKillAll = Enum.KeyCode.Unknown
    }
}


local function CleanupMemory()
    -- Очистка highlights
    if State.PlayerHighlights then
        for player, highlight in pairs(State.PlayerHighlights) do
            if highlight and highlight.Parent then
                pcall(function() highlight:Destroy() end)
            end
        end
        State.PlayerHighlights = {}
    end

    -- Очистка gun ESP
    if State.GunCache then
        for gunPart, espData in pairs(State.GunCache) do
            if espData then
                pcall(function()
                    if espData.highlight then espData.highlight:Destroy() end
                    if espData.billboard then espData.billboard:Destroy() end
                end)
            end
        end
        State.GunCache = {}
    end

    -- Очистка coin blacklist
    State.CoinBlacklist = {}
    
    -- Roblox автоматически очищает память, вызов не нужен
end

local function FindRole(player)
    if not player or not player.Character then return nil end

    local character = player.Character
    local backpack = player.Backpack

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

-- Использование:
local function findMurderer()
    for _, player in ipairs(Players:GetPlayers()) do
        if FindRole(player) == "Murder" then
            return player
        end
    end
    return nil
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
    State.UIElements.NotificationGui = notifGui
end

local function ShowNotification(text1, color1, text2, color2)
    if not State.NotificationsEnabled then return end

    if State.CurrentNotification then
        table.insert(State.NotificationQueue, {text1 = text1, color1 = color1, text2 = text2, color2 = color2})
        return
    end

    State.CurrentNotification = true

    local notifGui = State.UIElements.NotificationGui
    if not notifGui then
        CreateNotificationUI()
        notifGui = State.UIElements.NotificationGui
    end

    local notifFrame = Instance.new("Frame")
    notifFrame.Name = "NotificationFrame"
    notifFrame.BackgroundTransparency = 1
    notifFrame.AnchorPoint = Vector2.new(0.5, 0)
    notifFrame.Position = UDim2.new(0.5, 0, 0.25, 0)
    notifFrame.Size = text2 and UDim2.new(0, 320, 0, 70) or UDim2.new(0, 320, 0, 40)
    notifFrame.Parent = notifGui

    local textLabel1 = Instance.new("TextLabel")
    textLabel1.Text = text1
    textLabel1.Font = Enum.Font.GothamBold
    textLabel1.TextSize = 18
    textLabel1.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel1.BackgroundTransparency = 1
    textLabel1.TextTransparency = 1
    textLabel1.Size = UDim2.new(1, 0, 0, 35)
    textLabel1.Position = text2 and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 0, 0.5, -17)
    textLabel1.TextXAlignment = Enum.TextXAlignment.Center
    textLabel1.Parent = notifFrame

    local textLabel2
    if text2 then
        textLabel2 = Instance.new("TextLabel")
        textLabel2.Text = text2
        textLabel2.Font = Enum.Font.GothamBold
        textLabel2.TextSize = 18
        textLabel2.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel2.BackgroundTransparency = 1
        textLabel2.TextTransparency = 1
        textLabel2.Size = UDim2.new(1, 0, 0, 35)
        textLabel2.Position = UDim2.new(0, 0, 0, 35)
        textLabel2.TextXAlignment = Enum.TextXAlignment.Center
        textLabel2.Parent = notifFrame
    end

    local textFadeIn1 = TweenService:Create(textLabel1, TweenInfo.new(CONFIG.Notification.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
    textFadeIn1:Play()

    if textLabel2 then
        local textFadeIn2 = TweenService:Create(textLabel2, TweenInfo.new(CONFIG.Notification.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
        textFadeIn2:Play()
    end

    task.wait(CONFIG.Notification.Duration)

    local textFadeOut1 = TweenService:Create(textLabel1, TweenInfo.new(CONFIG.Notification.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1})
    textFadeOut1:Play()

    if textLabel2 then
        local textFadeOut2 = TweenService:Create(textLabel2, TweenInfo.new(CONFIG.Notification.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1})
        textFadeOut2:Play()
    end

    textFadeOut1.Completed:Wait()
    notifFrame:Destroy()

    State.CurrentNotification = nil

    if #State.NotificationQueue > 0 then
        local next = table.remove(State.NotificationQueue, 1)
        ShowNotification(next.text1, next.color1, next.text2, next.color2)
    end
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
                            if State.NotificationsEnabled then
                                ShowNotification("Flinger Detected", CONFIG.Colors.Orange, player.Name, CONFIG.Colors.Red)
                            end
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
    
    -- ✅ ИСПРАВЛЕННАЯ защита себя от флинга
    FlingNeutralizerConnection = RunService.Heartbeat:Connect(function()
        local character = LocalPlayer.Character
        if character and character.PrimaryPart then
            local primaryPart = character.PrimaryPart
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            
            -- ✅ Игнорируем если персонаж в воздухе
            if humanoid then
                local state = humanoid:GetState()
                if state == Enum.HumanoidStateType.Jumping or 
                   state == Enum.HumanoidStateType.Freefall or
                   state == Enum.HumanoidStateType.Flying then
                    AntiFlingLastPos = primaryPart.Position
                    return  -- НЕ ТРОГАЕМ скорость!
                end
            end
            
            if State.IsFlingInProgress then
                AntiFlingLastPos = primaryPart.Position
            -- ✅ Увеличен порог: 250 → 500 (безопаснее для высокого JumpPower)
            elseif primaryPart.AssemblyLinearVelocity.Magnitude > 500 or 
                   primaryPart.AssemblyAngularVelocity.Magnitude > 500 then
                
                if State.NotificationsEnabled and not FlingBlockedNotified then
                    ShowNotification("Fling Blocked", CONFIG.Colors.Green, "Velocity neutralized", CONFIG.Colors.Accent)
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
            ShowNotification("Fling Failed", CONFIG.Colors.Red, "Invalid target", CONFIG.Colors.TextDark)
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
            ShowNotification("Fling Failed", CONFIG.Colors.Red, "Target has no valid parts", CONFIG.Colors.TextDark)
        end
        return
    end

    if RootPart.Velocity.Magnitude < 50 then
        State.OldPos = RootPart.CFrame
    end

    local targetPart = TRootPart or THead or Handle
    
    if targetPart.Velocity.Magnitude > 500 then
        if State.NotificationsEnabled then
            ShowNotification("Already Flung", CONFIG.Colors.Orange, playerToFling.Name .. " is already flung", CONFIG.Colors.TextDark)
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
        ShowNotification("Player Flung!", CONFIG.Colors.Green, playerToFling.Name, CONFIG.Colors.Accent)
    end
end

-- ╔═══════════════════════════════════════════════════════════════╗
-- ║                    🚫 NOCLIP ФУНКЦИИ                          ║
-- ╚═══════════════════════════════════════════════════════════════╝

-- === NOCLIP (УНИВЕРСАЛЬНЫЙ) ===

local function EnableNoclip()
    if State.NoclipEnabled then return end
    State.NoclipEnabled = true
    
    local character = LocalPlayer.Character
    if not character then return end
    
    -- ✅ КАК В ИСХОДНИКЕ: Собираем BasePart в таблицу один раз
    local NoclipObjects = {}
    
    for _, obj in ipairs(character:GetChildren()) do
        if obj:IsA("BasePart") then
            table.insert(NoclipObjects, obj)
        end
    end
    
    -- Сохраняем в State для доступа
    State.NoclipObjects = NoclipObjects
    
    -- ✅ КАК В ИСХОДНИКЕ: Обновляем таблицу при респавне
    State.NoclipRespawnConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(0.15)
        
        table.clear(NoclipObjects)
        
        for _, obj in ipairs(newChar:GetChildren()) do
            if obj:IsA("BasePart") then
                table.insert(NoclipObjects, obj)
            end
        end
    end)
    
    -- ✅ КАК В ИСХОДНИКЕ: Просто отключаем коллизии в Stepped
    State.NoclipConnection = RunService.Stepped:Connect(function()
        for i = 1, #NoclipObjects do
            NoclipObjects[i].CanCollide = false
        end
    end)
    
    if State.NotificationsEnabled then
        ShowNotification("Noclip Enabled", CONFIG.Colors.Green)
    end
end


local function DisableNoclip()
    if not State.NoclipEnabled then return end
    State.NoclipEnabled = false
    
    -- ✅ КАК В ИСХОДНИКЕ: Просто отключаем соединения, НЕ ТРОГАЯ CanCollide
    if State.NoclipConnection then
        State.NoclipConnection:Disconnect()
        State.NoclipConnection = nil
    end
    
    if State.NoclipRespawnConnection then
        State.NoclipRespawnConnection:Disconnect()
        State.NoclipRespawnConnection = nil
    end
    
    -- Очищаем таблицу
    if State.NoclipObjects then
        table.clear(State.NoclipObjects)
        State.NoclipObjects = nil
    end
    
    if State.NotificationsEnabled then
        ShowNotification("Noclip Disabled", CONFIG.Colors.Red)
    end
end

local coinLabelCache = nil
local lastCacheTime = 0

local function GetCollectedCoinsCount()
    -- Проверяем кэш (5 секунд)
    if State.CoinLabelCache and State.CoinLabelCache.Parent and 
       (tick() - State.LastCacheTime) < 5 then
        local success, value = pcall(function()
            return tonumber(State.CoinLabelCache.Text) or 0
        end)
        if success then
            return value
        end
    end
    
    -- ИСПРАВЛЕНО: Добавлен timeout
    local success, coins = pcall(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
        if not playerGui then return 0 end
        
        local mainGui = playerGui:FindFirstChild("MainGUI")
        if not mainGui then return 0 end
        
        -- Безопасный путь к coins
        local game = mainGui:FindFirstChild("Game")
        if not game then return 0 end
        
        local coinBags = game:FindFirstChild("CoinBags")
        if not coinBags then return 0 end
        
        local container = coinBags:FindFirstChild("Container")
        if not container then return 0 end
        
        local snowToken = container:FindFirstChild("SnowToken")
        if not snowToken then return 0 end
        
        local currencyFrame = snowToken:FindFirstChild("CurrencyFrame")
        if not currencyFrame then return 0 end
        
        local icon = currencyFrame:FindFirstChild("Icon")
        if not icon then return 0 end
        
        local coinsLabel = icon:FindFirstChild("Coins")
        if not coinsLabel then return 0 end
        
        State.CoinLabelCache = coinsLabel
        State.LastCacheTime = tick()
        return tonumber(coinsLabel.Text) or 0
    end)
    
    if success and coins >= 0 then
        return coins
    end
    
    -- Fallback через FindFirstChild
    local maxValue = 0
    pcall(function()
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") and gui.Name == "Coins" then
                local path = gui:GetFullName()
                if path:match("CurrencyFrame%.Icon%.Coins$") then
                    local value = tonumber(gui.Text) or 0
                    if value > maxValue then
                        maxValue = value
                        State.CoinLabelCache = gui
                        State.LastCacheTime = tick()
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

local function DisableNoclip()
    if not State.NoclipEnabled then return end
    State.NoclipEnabled = false
    
    -- ✅ СНАЧАЛА отключаем соединения
    if State.NoclipConnection then
        State.NoclipConnection:Disconnect()
        State.NoclipConnection = nil
    end
    
    if State.NoclipRespawnConnection then
        State.NoclipRespawnConnection:Disconnect()
        State.NoclipRespawnConnection = nil
    end
    
    -- ✅ НОВОЕ: Принудительно восстанавливаем коллизии
    if State.NoclipObjects then
        local character = LocalPlayer.Character
        if character then
            for i = 1, #State.NoclipObjects do
                local part = State.NoclipObjects[i]
                if part and part.Parent then
                    -- Восстанавливаем CanCollide для всех частей кроме HumanoidRootPart
                    if part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
        
        table.clear(State.NoclipObjects)
        State.NoclipObjects = nil
    end
    
    if State.NotificationsEnabled then
        ShowNotification("Noclip Disabled", CONFIG.Colors.Red)
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



local lastGodModeApply = 0

local function ApplyGodMode()
    if not State.GodModeEnabled then return end

    local now = tick()
    if now - lastGodModeApply < 0.5 then return end
    lastGodModeApply = now

    local character = LocalPlayer.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    pcall(function()
        humanoid.Name = "OldHumanoid"

        local newHumanoid = humanoid:Clone()
        newHumanoid.Parent = character
        newHumanoid.Name = "Humanoid"

        humanoid:Destroy()

        if Workspace.Camera then
            Workspace.Camera.CameraSubject = newHumanoid
        end

        local animate = character:FindFirstChild("Animate")
        if animate then
            animate.Disabled = true
            task.wait(0.05)
            animate.Disabled = false
        end

        if State.WalkSpeed ~= 18 then
            newHumanoid.WalkSpeed = State.WalkSpeed
        end
        if State.JumpPower ~= 50 then
            newHumanoid.JumpPower = State.JumpPower
        end
    end)
end

local function ToggleGodMode()
    State.GodModeEnabled = not State.GodModeEnabled

    if State.GodModeEnabled then
        local godModeConnection = RunService.Heartbeat:Connect(function()
            if State.GodModeEnabled and LocalPlayer.Character then
                ApplyGodMode()
            end
        end)
        table.insert(State.Connections, godModeConnection)
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

local function CreateGunESP(gunPart)
    if not gunPart or not gunPart:IsA("BasePart") then return end
    if State.GunCache[gunPart] then return end

    local highlight = CreateHighlight(gunPart, CONFIG.Colors.Gun)
    highlight.Enabled = State.GunESP  -- ИСПРАВЛЕНО: Учитываем текущее состояние

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = gunPart
    billboard.Size = UDim2.new(0, 150, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = State.GunESP  -- ИСПРАВЛЕНО: Учитываем текущее состояние
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
    local gunAddedConnection = Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") and obj.Name == "GunDrop" then
            task.wait(0.1)
            CreateGunESP(obj)
            if State.NotificationsEnabled then
                task.spawn(function()
                    ShowNotification("Gun Dropped", CONFIG.Colors.Gun)
                end)
            end
        end
    end)

    local gunRemovedConnection = Workspace.DescendantRemoving:Connect(function(obj)
        if obj:IsA("BasePart") and obj.Name == "GunDrop" then
            RemoveGunESP(obj)
        end
    end)

    table.insert(State.Connections, gunAddedConnection)
    table.insert(State.Connections, gunRemovedConnection)
end

local function InitialGunScan()
    if State.GunESP then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == "GunDrop" then
                CreateGunESP(obj)
            end
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
                            ShowNotification("Round Ended", CONFIG.Colors.TextDark)
                        end)
                    end
                end


                if murder and sheriff and State.roundStart then
                    State.roundActive = true

                    if State.NotificationsEnabled then
                        task.spawn(function()
                            ShowNotification(
                                "Murder: " .. murder.Name,
                                CONFIG.Colors.Murder,
                                "Sheriff: " .. sheriff.Name,
                                CONFIG.Colors.Sheriff
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
                            ShowNotification("Sheriff: " .. sheriff.Name, CONFIG.Colors.Sheriff)
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
            ShowNotification("You're not murderer.", CONFIG.Colors.Red)
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
                ShowNotification("You don't have the knife..?", CONFIG.Colors.Red)
            end
            return
        end
    end
    local knife = LocalPlayer.Character:FindFirstChild("Knife")
    if not knife then
        if not silent then
            ShowNotification("Knife not equipped!", CONFIG.Colors.Red)
        end
        return
    end

    -- Проверка что у персонажа есть RightHand
    if not LocalPlayer.Character:FindFirstChild("RightHand") then
        if not silent then
            ShowNotification("Can't find RightHand!", CONFIG.Colors.Red)
        end
        return
    end

    -- ✅ ПОЛУЧАЕМ ПОЗИЦИЮ КУРСОРА (НЕ БЛИЖАЙШЕГО ИГРОКА!)
    local mouse = LocalPlayer:GetMouse()
    local targetPosition = mouse.Hit.Position
    
    if not targetPosition then
        if not silent then
            ShowNotification("Can't get mouse position!", CONFIG.Colors.Red)
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
    
    if success then
        if not silent then
            ShowNotification("Knife thrown!", CONFIG.Colors.Green)
        end
    else
        if not silent then
            ShowNotification("Failed to throw: " .. tostring(err), CONFIG.Colors.Red)
        end
    end
end

local function shootMurderer()
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
        ShowNotification("Not Sheriff/Hero", CONFIG.Colors.Red)
        return
    end

    -- Найти убийцу
    local murderer = findMurderer()
    if not murderer then
        ShowNotification("No murderer found", CONFIG.Colors.Red)
        return
    end

    -- Экипировать пистолет
    if not LocalPlayer.Character:FindFirstChild("Gun") then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if LocalPlayer.Backpack:FindFirstChild("Gun") then
            hum:EquipTool(LocalPlayer.Backpack:FindFirstChild("Gun"))
            task.wait(0.3)
        else
            ShowNotification("No gun found", CONFIG.Colors.Red)
            return
        end
    end

    local murdererHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
    if not murdererHRP then
        ShowNotification("Can't find murderer HRP", CONFIG.Colors.Red)
        return
    end

    -- ✅ ПРЕДСКАЗАНИЕ ПОЗИЦИИ
    local velocity = murdererHRP.AssemblyLinearVelocity
    local currentPos = murdererHRP.Position
    
    local predictionTime = State.ShootPrediction
    local predictedPos = currentPos + (velocity * predictionTime)
    
    -- Смещение на уровень груди/торса (центр масс)
    local chestOffset = Vector3.new(0, 0.5, 0)
    local targetPos = predictedPos + chestOffset
    
    -- ✅ ВЫБОР НАПРАВЛЕНИЯ ВЫСТРЕЛА (спина или спереди)
    local shootDistance = 3 -- Расстояние в studs
    local shootFromPos
    
    if State.ShootDirection == "Behind" then
        -- Выстрел СО СПИНЫ
        shootFromPos = predictedPos - (murdererHRP.CFrame.LookVector * shootDistance) + chestOffset
    else
        -- Выстрел СПЕРЕДИ
        shootFromPos = predictedPos + (murdererHRP.CFrame.LookVector * shootDistance) + chestOffset
    end
    
    local args = {
        [1] = CFrame.new(shootFromPos),  -- Откуда
        [2] = CFrame.new(targetPos)       -- Куда
    }

    local success, err = pcall(function()
        LocalPlayer.Character:WaitForChild("Gun"):WaitForChild("Shoot"):FireServer(unpack(args))
    end)

    if success then
        ShowNotification("Shot fired!", CONFIG.Colors.Green, murderer.Name .. " [" .. State.ShootDirection .. "]", CONFIG.Colors.Murder)
    else
        ShowNotification("Shoot failed: " .. tostring(err), CONFIG.Colors.Red)
    end
end



local function pickupGun()
    -- Проверяем что пистолет существует на карте
    local gun = Workspace:FindFirstChild("GunDrop", true) -- true = recursive search
    
    if not gun then
        ShowNotification("No gun on map", CONFIG.Colors.Red)
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
    
    ShowNotification("Gun picked up!", CONFIG.Colors.Green)
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
        if killAuraCon then killAuraCon:Disconnect() end
        killAuraCon = RunService.Heartbeat:Connect(function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player ~= LocalPlayer then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    local localHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if localHRP and (hrp.Position - localHRP.Position).Magnitude < 7 then
                        hrp.Anchored = true
                        -- Используем значение из State
                        hrp.CFrame = localHRP.CFrame + localHRP.CFrame.LookVector * State.KillAuraDistance
                        
                        if not anchoredPlayers[player] then
                            anchoredPlayers[player] = true
                        end

                        task.wait(0.1)
                        local args = { [1] = "Slash" }
                        LocalPlayer.Character.Knife.Stab:FireServer(unpack(args))
                        return
                    end
                end
            end
        end)
    else
        if killAuraCon then 
            killAuraCon:Disconnect()
            killAuraCon = nil
        end
        
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
    if findMurderer() ~= LocalPlayer then 
        if State.NotificationsEnabled then
            ShowNotification("You're not murderer.", CONFIG.Colors.Red)
        end
        return 
    end

    if not LocalPlayer.Character:FindFirstChild("Knife") then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if LocalPlayer.Backpack:FindFirstChild("Knife") then
            hum:EquipTool(LocalPlayer.Backpack:FindFirstChild("Knife"))
        else
            if State.NotificationsEnabled then
                ShowNotification("You don't have the knife..?", CONFIG.Colors.Red)
            end
            return
        end
    end

    local localHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localHRP then return end

    -- Телепортируем ВСЕХ игроков перед собой (без проверки расстояния)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player ~= LocalPlayer then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            pcall(function()
                hrp.Anchored = true
                hrp.CFrame = localHRP.CFrame + localHRP.CFrame.LookVector * 3
            end)
        end
    end

    local args = { [1] = "Slash" }
    LocalPlayer.Character.Knife.Stab:FireServer(unpack(args))
    
    task.spawn(function()
        task.wait(0.1)
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player ~= LocalPlayer then
                pcall(function()
                    player.Character.HumanoidRootPart.Anchored = false
                end)
            end
        end
    end)
    
    if State.NotificationsEnabled then
        ShowNotification("Kill All Complete!", CONFIG.Colors.Green)
    end
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
        Text = "MM2 ESP <font color=\"rgb(128, 0, 128)\">v6.0 Tabs</font>",
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
    MainTab:CreateKeybindButton("Toggle Noclip", "noclip", "Noclip")
   
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
            ShowNotification("Auto Farm Started", CONFIG.Colors.Green)
            StartAutoFarm()
        else
            StopAutoFarm()
            ShowNotification("Auto Farm Stopped", CONFIG.Colors.Red)
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
    if State.UIElements.OpenDropdowns then
        for _, closeFunc in ipairs(State.UIElements.OpenDropdowns) do
            pcall(closeFunc)
        end
    end
    -- Очистка highlights
    CleanupMemory()
    if State.NoclipEnabled then 
        DisableNoclip() 
    end

    -- Отключение всех соединений
    for _, connection in ipairs(State.Connections) do
        pcall(function()
            if connection and connection.Disconnect then
                connection:Disconnect()
            end
        end)
    end

    -- Очистка UI
    if gui then gui:Destroy() end
    if State.UIElements.NotificationGui then 
        State.UIElements.NotificationGui:Destroy() 
    end

    -- Отключение Auto Farm
    if State.AutoFarmEnabled then
        StopAutoFarm()
    end

    -- Отключение всех активных функций
    if State.NoclipEnabled then DisableNoclip() end
    if State.AntiFlingEnabled then DisableAntiFling() end
    if State.ExtendedHitboxEnabled then DisableExtendedHitbox() end

    -- Финальная очистка
    getgenv().MM2_ESP_Script = false
    collectgarbage("collect")
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
       
        if input.KeyCode == State.Keybinds.Noclip and State.Keybinds.Noclip ~= Enum.KeyCode.Unknown then
            if State.NoclipEnabled then DisableNoclip() else EnableNoclip() end
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

-- ✅ Приветственное уведомление
if State.NotificationsEnabled then
    task.wait(1)
    ShowNotification("MM2 ESP v6.0 Loaded", CONFIG.Colors.Green, "All systems ready!", CONFIG.Colors.Accent)
end

-- выводим в консоль
print("╔════════════════════════════════════════════╗")
print("║   MM2 ESP v6.0 - Successfully Loaded!     ║")
print("║   Press [" .. CONFIG.HideKey.Name .. "] to toggle GUI               ║")
print("╚════════════════════════════════════════════╝")
