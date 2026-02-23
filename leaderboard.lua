-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 1: INITIALIZATION & PROTECTION (СТРОКИ 1-70)
-- ══════════════════════════════════════════════════════════════════════════════

-- PlaceId проверка (если нужна)
--if game.PlaceId ~= 142823291 then return end

if not game:IsLoaded() then game.Loaded:Wait() end

if getgenv().MM2_Script then 
    warn("Already running!")
    return 
end
getgenv().MM2_Script = true

local AUTOFARM_ENABLED = true
--SK2ND = 982594515
--slonsagg2 = 6163487250
--0Jl9lra = 2058109987
--serejenkaluv = 10341870648
local WHITELIST_IDS = {10341870648,6163487250,982594515,2058109987,10340849538}

_G.AUTOEXEC_ENABLED = AUTOFARM_ENABLED --and table.find(WHITELIST_IDS, game:GetService("Players").LocalPlayer.UserId) ~= nil

--pcall(function()
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/Yany1944/rbxmain/refs/heads/main/Scripts/Emotes.lua"))()
--end)

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 2: CONFIG & SERVICES (СТРОКИ 65-115)
-- ══════════════════════════════════════════════════════════════════════════════

local CONFIG = {
        HideKey = Enum.KeyCode.Q,
        Tracers = {
        CountPerShot = 4,
        MaxDistance = 500,
        Duration = 0.8,
        Coin = {
            Color = Color3.fromRGB(255, 105, 180),
            Width = 0.3,
            Texture = "rbxasset://textures/particles/smoke_main.dds",
            TextureSpeed = 2,
        }
        },
        Defaults = {
        Humanoid = {
            WalkSpeed = 16,
            JumpPower = 50,
        },
        Camera = {
            FieldOfView = 70,
            MaxZoomDistance = 128,
        }
        },
        CoreGuiTypes = {
        Enum.CoreGuiType.PlayerList,
        Enum.CoreGuiType.Health,
        Enum.CoreGuiType.Backpack,
        Enum.CoreGuiType.Chat,
        Enum.CoreGuiType.EmotesMenu,
        Enum.CoreGuiType.SelfView
        },
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 3: STATE MANAGEMENT (СТРОКИ 116-252)
-- ══════════════════════════════════════════════════════════════════════════════

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
    KillAuraDistance = 2.5,
    CanShootMurderer = true,
    ShootCooldown = 3,
    ShootMurdererMode = "Magic",
    
    -- Auto Farm
    AutoFarmEnabled = false,
    CoinFarmThread = nil,
    CoinFarmFlySpeed = 22,
    CoinFarmDelay = 2,
    UndergroundMode = false,
    UndergroundOffset = 2.5,
    CoinBlacklist = {},
    LastCacheTime = 0,
    GodModeWithAutoFarm = true,

    -- Auto-load script on teleport
    AutoLoadOnTeleport = true,

    currentMapConnection = nil,
    currentMap = nil,
    previousGun = nil,

    -- Auto Rejoin & Reconnect
    AutoRejoinEnabled = false,
    AutoReconnectEnabled = false,
    ReconnectInterval = 60 * 60, -- 25 минут в секундах
    ReconnectThread = nil,

    -- Vote Spammer
    VoteSpammerEnabled = false,
    VoteSpammerActive = false,
    VoteSpammerThread = nil,
    VoteGoal = 8,
    VoteSpammerSession = 0,
    IsWaitingForVoting = false,
    IsGoalReached = false,
    TeleportedThisSession = false,
    CurrentTargetPad = nil,

    -- XP Farm
    XPFarmEnabled = false,
    AFKModeEnabled = false,

    -- Instant Pickup
    InstantPickupEnabled = false,
    InstantPickupThread = nil,
    
    -- Anti-Fling
    AntiFlingEnabled = false,
    IsFlingInProgress = false,
    SelectedPlayerForFling = nil,
    OldPos = nil,
    TrapTrackingConnection = nil,

    -- Walk Fling
    WalkFlingActive = false,
    WalkFlingConnection = nil,
    WalkFlingEnabledByUser = false,
    
    -- NoClip
    NoClipEnabled = false,
    NoClipConnection = nil,
    NoClipRespawnConnection = nil,
    NoClipObjects = nil,
    
    -- GodMode
    GodModeEnabled = false,
    GodModeConnections = {},
    healthConnection = nil,
    damageBlockerConnection = nil,
    stateConnection = nil,
    
    -- Role detection
    prevMurd = nil,
    prevSher = nil,
    heroSent = false,
    roundStart = true,
    roundActive = false,
    
    PLACEHOLDER_IMAGE = "",
    currentMurdererUserId = nil,
    currentSheriffUserId = nil,

    -- ESP internals
    PlayerHighlights = {},
    GunCache = {},
    TrapCache = {},
    CurrentGunDrop = nil,
    PlayerData = {},

    -- Player Nicknames ESP
    PlayerNicknamesESP = false,
    PlayerNicknamesCache = {},

    IsInvisible = false,

    -- Tracers
    BulletTracersEnabled = false,
    TracersList = {},
    LastTracerTime = 0,
    -- System
    Connections = {},
    UIElements = {},
    RoleCheckLoop = nil,
    FPDH = Workspace.FallenPartsDestroyHeight,
    
    -- UI State
    ClickTPActive = false,
    ListeningForKeybind = nil,
    
    -- Notifications
    NotificationQueue = {},
    CurrentNotification = nil,
---------------------
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
        knifeThrow = Enum.KeyCode.Unknown,
        NoClip = Enum.KeyCode.Unknown,
        ShootMurderer = Enum.KeyCode.Unknown,
        PickupGun = Enum.KeyCode.Unknown,
        InstantKillAll = Enum.KeyCode.Unknown,
        Fly = Enum.KeyCode.Unknown,
        Invisibility = Enum.KeyCode.Unknown,
    }
}

-- Замените существующий блок TeleportCheck на этот:
local TeleportCheck = false

-- Используйте более надежную проверку
if queue_on_teleport then
    local teleportScript = [[
        -- Ждем полной загрузки
        repeat task.wait() until game:IsLoaded()
        task.wait(2)
        
        -- Проверяем PlaceId
        if game.PlaceId == 142823291 or game.PlaceId == 335132309 then
            local success, err = pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Yany1944/rbxmain/refs/heads/main/leaderboard.lua", true))()
            end)
            if not success then
                warn("Ошибка автозагрузки:", err)
            end
        end
    ]]
    --
    -- Попытка 1: OnTeleport event
    game.Players.LocalPlayer.OnTeleport:Connect(function(State)
        if State == Enum.TeleportState.Started and not TeleportCheck then
            TeleportCheck = true
            queue_on_teleport(teleportScript)
        end
    end)
    
    -- Попытка 2: Сразу добавляем в очередь (для ручной смены серверов)
    queue_on_teleport(teleportScript)
end
--]]

local function TrackConnection(conn)
    if conn then
        table.insert(State.Connections, conn)
    end
    return conn
end

-- ============= COIN TRACER SYSTEM (С АНИМАЦИЕЙ) =============
local CurrentCoinTracer = nil

local function CreateCoinTracer(character, targetCoin)
    if not character or not targetCoin then return end
    -- ✅ УБРАНА проверка State.BulletTracersEnabled
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Удаляем старый трасер
    if CurrentCoinTracer then
        pcall(function()
            CurrentCoinTracer.beam:Destroy()
            CurrentCoinTracer.att0:Destroy()
            CurrentCoinTracer.att1:Destroy()
        end)
        CurrentCoinTracer = nil
    end
    
    -- Создаем новые Attachment
    local attachment0 = Instance.new("Attachment")
    attachment0.Name = "CoinTracerStart"
    attachment0.Parent = hrp
    
    local attachment1 = Instance.new("Attachment")
    attachment1.Name = "CoinTracerEnd"
    attachment1.Parent = targetCoin
    
    -- Создаем Beam
    local beam = Instance.new("Beam")
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(CONFIG.Tracers.Coin.Color)
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Brightness = 5
    beam.Texture = CONFIG.Tracers.Coin.Texture
    beam.TextureMode = Enum.TextureMode.Stretch
    beam.TextureSpeed = CONFIG.Tracers.Coin.TextureSpeed
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0)
    })
    beam.Width0 = CONFIG.Tracers.Coin.Width
    beam.Width1 = CONFIG.Tracers.Coin.Width
    beam.ZOffset = 0.1
    beam.Parent = attachment0
    
    CurrentCoinTracer = {
        beam = beam,
        att0 = attachment0,
        att1 = attachment1,
        coin = targetCoin
    }
    
    return CurrentCoinTracer
end

local function RemoveCoinTracer()
    if CurrentCoinTracer then
        pcall(function()
            CurrentCoinTracer.beam:Destroy()
            CurrentCoinTracer.att0:Destroy()
            CurrentCoinTracer.att1:Destroy()
        end)
        CurrentCoinTracer = nil
    end
end

-- Обновление трасера каждый кадр
RunService.RenderStepped:Connect(function()
    if CurrentCoinTracer then
        -- Проверка валидности монеты
        if not CurrentCoinTracer.coin or not CurrentCoinTracer.coin.Parent then
            RemoveCoinTracer()
            return
        end
        
        -- ✅ Проверяем ТОЛЬКО автофарм (без BulletTracersEnabled)
        if not State.AutoFarmEnabled then
            RemoveCoinTracer()
            return
        end
    end
end)

local function GetShootOrigin(tool)
    if not tool then return nil end
    local handle = tool:FindFirstChild("Handle")
    if handle then
        return handle.Position
    end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        return hrp.Position + Vector3.new(0, 1.5, 0)
    end
    return nil
end

local function PerformRaycast(origin, direction, maxDistance)
    RayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local raycastResult = Workspace:Raycast(origin, direction * maxDistance, RayParams)
    if raycastResult then
        return raycastResult.Position
    else
        return origin + (direction * maxDistance)
    end
end

local function CreateTracer(origin, targetPosition, duration)
    if not origin or not targetPosition then return nil end

    local char = LocalPlayer.Character
    if not char then return nil end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local attachment0 = Instance.new("Attachment")
    attachment0.Name = "BulletTracerStart"
    attachment0.WorldPosition = origin
    attachment0.Parent = hrp

    local endPart = Instance.new("Part")
    endPart.Name = "BulletTracerEnd"
    endPart.Anchored = true
    endPart.CanCollide = false
    endPart.CanQuery = false
    endPart.CanTouch = false
    endPart.Transparency = 1
    endPart.Size = Vector3.new(0.1, 0.1, 0.1)
    endPart.CFrame = CFrame.new(targetPosition)
    endPart.Parent = Workspace

    local attachment1 = Instance.new("Attachment")
    attachment1.Name = "BulletTracerEnd"
    attachment1.Parent = endPart

    local beam = Instance.new("Beam")
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(CONFIG.Colors.Accent)
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.FaceCamera = true
    beam.Brightness = 5
    beam.Width0 = 0.12
    beam.Width1 = 0.06
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(1, 0.7)
    })
    beam.Parent = attachment0

    local tracerData = {
        beam = beam,
        att0 = attachment0,
        att1 = attachment1,
        endPart = endPart,
    }
    table.insert(State.TracersList, tracerData)

    task.delay(duration or 0.8, function()
        pcall(function()
            beam:Destroy()
            attachment0:Destroy()
            attachment1:Destroy()
            endPart:Destroy()
        end)

        for i = #State.TracersList, 1, -1 do
            if State.TracersList[i] == tracerData then
                table.remove(State.TracersList, i)
                break
            end
        end
    end)

    return tracerData
end

local function CreateTracerFromTool(tool)
    if not State.BulletTracersEnabled then return end
    if not tool or not tool:IsA("Tool") then return end
    
    -- Проверка cooldown
    local currentTime = tick()
    if currentTime - State.LastTracerTime < State.ShootCooldown then
        return
    end
    State.LastTracerTime = currentTime
    
    local origin = GetShootOrigin(tool)
    if not origin then return end
    
    local mouse = LocalPlayer:GetMouse()
    if not mouse then return end
    
    local targetPos = mouse.Hit.Position
    local offset = targetPos - origin
    if offset.Magnitude <= 0.001 then return end
    local direction = offset.Unit
    
    local hitPos = PerformRaycast(origin, direction, CONFIG.Tracers.MaxDistance)
    for i = 1, CONFIG.Tracers.CountPerShot do
        CreateTracer(origin, hitPos, CONFIG.Tracers.Duration)
    end
end

local toolConnections = {}
local inputConnection = nil

-- Проверка, является ли инструмент ножом
local function IsKnifeTool(tool)
    if not tool then return false end
    local name = tool.Name:lower()
    return name:find("knife") or name:find("blade") or tool:FindFirstChild("Stab")
end

-- Для пистолета (Sheriff) - ЛКМ через Tool.Activated
local function SetupGunTracers(tool)
    if IsKnifeTool(tool) then return end
    
    local conn = tool.Activated:Connect(function()
        CreateTracerFromTool(tool)
    end)
    toolConnections[tool] = conn
end

-- Для ножа - клавиши E и кастомная
local function SetupKnifeTracers()
    if inputConnection then
        inputConnection:Disconnect()
    end
    
    inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not State.BulletTracersEnabled then return end
        
        local char = LocalPlayer.Character
        if not char then return end
        
        local equippedTool = char:FindFirstChildOfClass("Tool")
        if not equippedTool or not IsKnifeTool(equippedTool) then return end
        
        -- E или кастомная клавиша из настроек
        local knifeThrowKey = State.Keybinds.knifeThrow or Enum.KeyCode.E
        
        if input.KeyCode == Enum.KeyCode.E or input.KeyCode == knifeThrowKey then
            CreateTracerFromTool(equippedTool)
        end
    end)
end

local function SetupToolTracers(character)
    if not character then return end
    
    for _, conn in pairs(toolConnections) do
        pcall(function() conn:Disconnect() end)
    end
    toolConnections = {}
    
    local function connectTool(tool)
        if not tool:IsA("Tool") then return end
        if toolConnections[tool] then return end
        
        -- Только для пистолета
        if not IsKnifeTool(tool) then
            SetupGunTracers(tool)
        end
    end
    
    for _, tool in ipairs(character:GetChildren()) do
        connectTool(tool)
    end
    
    local charConn = character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            task.wait(0.1)
            connectTool(child)
        end
    end)
    TrackConnection(charConn)
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            connectTool(tool)
        end
        
        local backpackConn = backpack.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                task.wait(0.1)
                connectTool(child)
            end
        end)
        TrackConnection(backpackConn)
    end
    
    -- Настройка отслеживания клавиш для ножа
    SetupKnifeTracers()
end

local function InitializeToolTracers()
    TrackConnection(LocalPlayer.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        if State.BulletTracersEnabled then
            SetupToolTracers(character)
        end
    end))

    if LocalPlayer.Character then
        SetupToolTracers(LocalPlayer.Character)
    end
end

InitializeToolTracers()

local function CleanupTracers()
    for _, conn in pairs(toolConnections) do
        pcall(function() conn:Disconnect() end)
    end
    toolConnections = {}
    
    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end
    
    for _, tracer in ipairs(State.TracersList) do
        pcall(function()
            tracer.beam:Destroy()
            tracer.att0:Destroy()
            tracer.att1:Destroy()
            if tracer.endPart then
                tracer.endPart:Destroy()
            end
        end)
    end
    State.TracersList = {}
end

local function ToggleBulletTracers(enabled)
    State.BulletTracersEnabled = enabled
    
    if enabled then
        if LocalPlayer.Character then
            SetupToolTracers(LocalPlayer.Character)
        end
    else
        CleanupTracers()
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 4: SYSTEM FUNCTIONS (СТРОКИ 253-410)
-- ══════════════════════════════════════════════════════════════════════════════

-- CleanupMemory() - Очистка при респавне
local function CleanupMemory()
    -- Очистка очереди уведомлений (безопасно)
    State.NotificationQueue = {}
    State.CurrentNotification = nil

    -- Очистка coin blacklist (безопасно - относится к Auto Farm)
    State.CoinBlacklist = {}

end

local function FullShutdown()
    --print("[FullShutdown] Starting complete cleanup...")

    pcall(function()
        if State.AutoFarmEnabled then StopAutoFarm() end
        if State.XPFarmEnabled then StopXPFarm() end
        if State.NoClipEnabled then DisableNoClip() end
        if State.AntiFlingEnabled then DisableAntiFling() end
        if State.GodModeEnabled then ToggleGodMode() end
        if State.ToggleInvisibility then ToggleInvisibility() end
        if State.InstantPickupEnabled then DisableInstantPickup() end
        if State.VoteSpammerEnabled then StopVoteSpammer() end
    end)

    pcall(function()
        -- гасим Role ESP
        if State.RoleCheckLoop then
            State.RoleCheckLoop:Disconnect()
            State.RoleCheckLoop = nil
        end

        -- уничтожаем хайлайты игроков
        for player, highlight in pairs(State.PlayerHighlights) do
            pcall(function()
                if highlight and highlight.Parent then
                    highlight:Destroy()
                end
            end)
            State.PlayerHighlights[player] = nil
        end

        -- очищаем Gun ESP
        for _, espData in pairs(State.GunCache) do
            pcall(function()
                if espData.highlight then espData.highlight:Destroy() end
                if espData.billboard then espData.billboard:Destroy() end
            end)
        end
        State.GunCache = {}
        State.CurrentGunDrop = nil
                -- Player Nicknames ESP
        for player, espData in pairs(State.PlayerNicknamesCache) do
            pcall(function()
                if espData.billboard then
                    espData.billboard:Destroy()
                end
            end)
        end
        State.PlayerNicknamesCache = {}
    end)

    pcall(function() GUI.Cleanup() end)

    pcall(function()
        if State.AutoRejoinEnabled then HandleAutoRejoin(false) end
        if State.AutoReconnectEnabled then HandleAutoReconnect(false) end
    end)

    -- ✅ Очистка всех general connections
    pcall(function()
        for _, connection in ipairs(State.Connections) do
            if connection and connection.Connected then
                connection:Disconnect()
            end
        end
        State.Connections = {}
    end)
    
    -- ✅ Очистка GodMode connections (отдельное хранилище)
    pcall(function()
        for _, connection in ipairs(State.GodModeConnections) do
            if connection and connection.Connected then
                connection:Disconnect()
            end
        end
        State.GodModeConnections = {}
    end)
    
    -- ✅ Восстановление character settings
    pcall(function()
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = CONFIG.Defaults.Humanoid.WalkSpeed
                humanoid.JumpPower = CONFIG.Defaults.Humanoid.JumpPower
            end
            
            local ff = character:FindFirstChild("ForceField")
            if ff then ff:Destroy() end
        end
        
        LocalPlayer.CameraMaxZoomDistance = CONFIG.Defaults.Camera.MaxZoomDistance
        
        local camera = Workspace.CurrentCamera
        if camera then
            camera.FieldOfView = CONFIG.Defaults.Camera.FieldOfView
        end
    end)
    
    -- ✅ Восстановление FallenPartsDestroyHeight
    pcall(function()
        Workspace.FallenPartsDestroyHeight = State.FPDH
    end)
    
    -- ✅ Очистка Keybinds
    pcall(function()
        for key, _ in pairs(State.Keybinds) do
            State.Keybinds[key] = Enum.KeyCode.Unknown
        end
    end)
    
    -- ✅ Очистка UI State
    State.ClickTPActive = false
    State.ListeningForKeybind = nil
    
    -- ✅ Очистка Notifications
    State.NotificationQueue = {}
    State.CurrentNotification = nil
    
    -- ✅ Очистка Blacklist
    State.CoinBlacklist = {}
    
    -- ✅ Очистка Role detection
    State.prevMurd = nil
    State.prevSher = nil
    State.heroSent = false
    State.roundStart = true
    State.roundActive = false
    pcall(function()
        if State.UIElements.NotificationGui then
            State.UIElements.NotificationGui:Destroy()
            State.UIElements.NotificationGui = nil
            State.UIElements.NotificationContainer = nil
        end

        for name, ui in pairs(State.UIElements) do
            if typeof(ui) == "Instance" and ui.Parent then
                ui:Destroy()
            end
            State.UIElements[name] = nil
        end
    end)
    
    ScriptAlive = false
    --print("[FullShutdown] ✅ Complete!")
end


-- findNearestPlayer() - Поиск ближайшего игрока
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

-- getAllPlayers() - Список игроков (без LocalPlayer)
local function getAllPlayers()
    local playerList = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerList, player.Name)
        end
    end
    table.sort(playerList)
    return playerList
end

-- getPlayerByName() - Поиск игрока по имени
local function getPlayerByName(playerName)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == playerName or player.DisplayName == playerName then
            return player
        end
    end
    return nil
end

-- ==============================
-- OPTIMIZATION MODULE
-- ==============================

local OptimizationState = {
    afkModeActive = false,
    fpsBoostActive = false,
    uiOnlyActive = false,
    savedUIState = {},
    savedUIOnlyState = {},
    savedSettings = {
        Lighting = {},
        Camera = {}
    },
    fpsBoostDescendantConn = nil
}

-- ==============================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ==============================

-- Функция применения UI оптимизации
local function ApplyUIOptimization()
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

        for _, guiType in ipairs(CONFIG.CoreGuiTypes) do
            StarterGui:SetCoreGuiEnabled(guiType, false)
        end
    end)
    
    pcall(function()
        StarterGui:SetCore("TopbarEnabled", false)
    end)
    
    pcall(function()
        local targetTable = OptimizationState.afkModeActive and OptimizationState.savedUIState or OptimizationState.savedUIOnlyState
        for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui ~= MainGui then
                if not targetTable[gui] then
                    targetTable[gui] = gui.Enabled
                end
                gui.Enabled = false
            end
        end
    end)
end

-- ОБРАБОТЧИК РЕСПАВНА
LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    
    if OptimizationState.afkModeActive then
        ApplyUIOptimization()
        pcall(function()
            RunService:Set3dRenderingEnabled(false)
        end)
    elseif OptimizationState.uiOnlyActive then
        ApplyUIOptimization()
    end
end)

-- ==============================
-- AFK MODE FUNCTIONS
-- ==============================

EnableMaxOptimization = function()
    if OptimizationState.afkModeActive then 
        return 
    end
    
    OptimizationState.afkModeActive = true
    
    -- 1. ОТКЛЮЧЕНИЕ 3D РЕНДЕРИНГА
    pcall(function()
        RunService:Set3dRenderingEnabled(false)
    end)
    
    -- 2. ПОЛНОЕ ОТКЛЮЧЕНИЕ ВСЕХ GUI
    ApplyUIOptimization()
    
    -- 3. ОТКЛЮЧЕНИЕ ОСВЕЩЕНИЯ
    pcall(function()
        OptimizationState.savedSettings.Lighting = {
            GlobalShadows = Lighting.GlobalShadows,
            Brightness = Lighting.Brightness,
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            FogEnd = Lighting.FogEnd,
            Technology = Lighting.Technology
        }
        
        Lighting.GlobalShadows = false
        Lighting.Brightness = 0
        Lighting.Ambient = Color3.new(0, 0, 0)
        Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
        Lighting.FogEnd = 100
        Lighting.Technology = Enum.Technology.Legacy
        
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") or effect:IsA("Atmosphere") or effect:IsA("Sky") then
                OptimizationState.savedSettings.Lighting[effect.Name] = effect
                effect.Parent = nil
            end
        end
    end)
    
    -- 4. CAMERA OPTIMIZATION
    pcall(function()
        local camera = Workspace.CurrentCamera
        if camera then
            OptimizationState.savedSettings.Camera.FieldOfView = camera.FieldOfView
            camera.FieldOfView = 50
        end
    end)
    
    -- 5. RENDER DISTANCE
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(Workspace, "StreamingMinRadius", 32)
            sethiddenproperty(Workspace, "StreamingTargetRadius", 64)
        end
    end)
end

DisableMaxOptimization = function()
    if not OptimizationState.afkModeActive then 
        return 
    end
    
    OptimizationState.afkModeActive = false
    
    -- 1. ВКЛЮЧЕНИЕ 3D РЕНДЕРИНГА
    pcall(function()
        RunService:Set3dRenderingEnabled(true)
    end)
    
    -- 2. ВОССТАНОВЛЕНИЕ GUI
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
        
        task.wait(0.1)

        for _, guiType in ipairs(CONFIG.CoreGuiTypes) do
            StarterGui:SetCoreGuiEnabled(guiType, true)
        end
    end)
    
    pcall(function()
        StarterGui:SetCore("TopbarEnabled", true)
    end)
    
    pcall(function()
        for gui, wasEnabled in pairs(OptimizationState.savedUIState) do
            if gui and gui.Parent then
                gui.Enabled = wasEnabled
            end
        end
        OptimizationState.savedUIState = {}
    end)
    
    -- 3. ВОССТАНОВЛЕНИЕ ОСВЕЩЕНИЯ
    pcall(function()
        if OptimizationState.savedSettings.Lighting.GlobalShadows ~= nil then
            Lighting.GlobalShadows = OptimizationState.savedSettings.Lighting.GlobalShadows
            Lighting.Brightness = OptimizationState.savedSettings.Lighting.Brightness
            Lighting.Ambient = OptimizationState.savedSettings.Lighting.Ambient
            Lighting.OutdoorAmbient = OptimizationState.savedSettings.Lighting.OutdoorAmbient
            Lighting.FogEnd = OptimizationState.savedSettings.Lighting.FogEnd
            Lighting.Technology = OptimizationState.savedSettings.Lighting.Technology
            
            for _, effect in pairs(OptimizationState.savedSettings.Lighting) do
                if typeof(effect) == "Instance" then
                    effect.Parent = Lighting
                end
            end
            
            OptimizationState.savedSettings.Lighting = {}
        end
    end)
    
    -- 4. ВОССТАНОВЛЕНИЕ КАМЕРЫ
    pcall(function()
        local camera = Workspace.CurrentCamera
        if camera and OptimizationState.savedSettings.Camera.FieldOfView then
            camera.FieldOfView = OptimizationState.savedSettings.Camera.FieldOfView
        end
    end)
end

EnableUIOnly = function()
    if OptimizationState.uiOnlyActive then return end
    OptimizationState.uiOnlyActive = true
    OptimizationState.savedUIOnlyState = {}
    ApplyUIOptimization()
end

DisableUIOnly = function()
    if not OptimizationState.uiOnlyActive then return end
    OptimizationState.uiOnlyActive = false
    
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
        
        task.wait(0.1)

        for _, guiType in ipairs(CONFIG.CoreGuiTypes) do
            StarterGui:SetCoreGuiEnabled(guiType, true)
        end
    end)
    
    pcall(function()
        StarterGui:SetCore("TopbarEnabled", true)
    end)
    
    pcall(function()
        if OptimizationState.savedUIOnlyState and next(OptimizationState.savedUIOnlyState) ~= nil then
            for gui, wasEnabled in pairs(OptimizationState.savedUIOnlyState) do
                if gui and gui.Parent then
                    gui.Enabled = wasEnabled
                end
            end
        end
        OptimizationState.savedUIOnlyState = {}
    end)
end

-- ==============================
-- FPS BOOST FUNCTION
-- ==============================

EnableFPSBoost = function()
    if OptimizationState.fpsBoostActive then
        return
    end
    
    OptimizationState.fpsBoostActive = true
    
    -- 1. TERRAIN OPTIMIZATION
    pcall(function()
        local Terrain = Workspace:FindFirstChildOfClass('Terrain')
        if Terrain then
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 0
        end
    end)
    
    -- 2. LIGHTING OPTIMIZATION
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("BlurEffect") 
                or effect:IsA("SunRaysEffect") 
                or effect:IsA("ColorCorrectionEffect") 
                or effect:IsA("BloomEffect") 
                or effect:IsA("DepthOfFieldEffect") 
            then
                effect.Enabled = false
            end
        end
    end)
    
    -- 3. RENDER QUALITY
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    
    -- 4. MATERIALS & EFFECTS CLEANUP
    pcall(function()
        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation") then
                v.Material = Enum.Material.SmoothPlastic
                v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Enabled = false
            elseif v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                v.Enabled = false
            end
        end
    end)
    
    -- 5. AUTO-CLEANUP NEW EFFECTS
    OptimizationState.fpsBoostDescendantConn = Workspace.DescendantAdded:Connect(function(child)
        if not OptimizationState.fpsBoostActive then return end
        
        task.spawn(function()
            pcall(function()
                if child:IsA('ForceField') 
                    or child:IsA('Sparkles') 
                    or child:IsA('Smoke') 
                    or child:IsA('Fire') 
                then
                    task.wait()
                    child:Destroy()
                elseif child:IsA('ParticleEmitter') or child:IsA('Trail') then
                    child.Enabled = false
                end
            end)
        end)
    end)
    
    TrackConnection(OptimizationState.fpsBoostDescendantConn)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 5: CHARACTER FUNCTIONS (СТРОКИ 411-470)
-- ══════════════════════════════════════════════════════════════════════════════

-- ApplyWalkSpeed() - Установка скорости
local function ApplyWalkSpeed(speed)
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = speed
        State.WalkSpeed = speed
    end
end

-- ApplyJumpPower() - Установка прыжка
local function ApplyJumpPower(power)
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.JumpPower = power
        State.JumpPower = power
    end
end

-- ApplyMaxCameraZoom() - Установка зума
local function ApplyMaxCameraZoom(distance)
    LocalPlayer.CameraMaxZoomDistance = distance
    State.MaxCameraZoom = distance
end

-- ApplyCharacterSettings() - Применение всех настроек
local function ApplyCharacterSettings()
    ApplyWalkSpeed(State.WalkSpeed)
    ApplyJumpPower(State.JumpPower)
    ApplyMaxCameraZoom(State.MaxCameraZoom)
end

-- ApplyFOV() - Плавное изменение FOV
local function ApplyFOV(fov)
    local camera = Workspace.CurrentCamera
    if camera then
        TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
            FieldOfView = fov
        }):Play()
        State.CameraFOV = fov
    end
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 6: NOTIFICATION SYSTEM (СТРОКИ 471-610)
-- ══════════════════════════════════════════════════════════════════════════════

-- CreateNotificationUI() - Создание UI уведомлений
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
    container.Position = UDim2.new(0.5, 0, 0, 80)
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

-- ShowNotification() - Показ уведомления
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

        notifFrame.AnchorPoint = Vector2.new(0.5, 0)
        notifFrame.Position = UDim2.new(0.5, 0, 0, -50)
        notifFrame.BackgroundTransparency = 1

        TweenService:Create(
            notifFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Position = UDim2.new(0.5, 0, 0, 0),
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
            { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, -50) }
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

----------------------------------------------------------------
-- ESP: роли + GunESP
----------------------------------------------------------------

local function SetupPlayerDataListener()
    local success, remotes = pcall(function()
        return game.ReplicatedStorage:WaitForChild("Remotes", 5)
    end)
    
    if not success or not remotes then return end
    
    local gameplay = remotes:FindFirstChild("Gameplay")
    if not gameplay then return end
    
    local dataChanged = gameplay:FindFirstChild("PlayerDataChanged")
    if not dataChanged then return end
    
    dataChanged.OnClientEvent:Connect(function(data)
        State.PlayerData = data or {}
    end)
end

-- CreateHighlight() - создание Highlight для персонажа
local function CreateHighlight(adornee, color)
    if not adornee or not adornee.Parent then return nil end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = adornee
    highlight.FillColor = color
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0.25
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = true
    highlight.Parent = adornee

    return highlight
end

-- UpdatePlayerHighlight() - обновление ESP игрока
local function UpdatePlayerHighlight(player, role)
    if not player or player == LocalPlayer then return end

    local character = player.Character
    if not character then
        if State.PlayerHighlights[player] then
            pcall(function()
                State.PlayerHighlights[player]:Destroy()
            end)
            State.PlayerHighlights[player] = nil
        end
        return
    end

    local color, shouldShow

    if role == "Murder" then
        color      = CONFIG.Colors.Murder
        shouldShow = State.MurderESP
    elseif role == "Sheriff" then
        color      = CONFIG.Colors.Sheriff
        shouldShow = State.SheriffESP
    elseif role == "Innocent" then
        color      = CONFIG.Colors.Innocent
        shouldShow = State.InnocentESP
    else
        shouldShow = false
    end

    if not shouldShow then
        if State.PlayerHighlights[player] then
            pcall(function()
                State.PlayerHighlights[player].Enabled = false
            end)
        end
        return
    end

    local existingHighlight = State.PlayerHighlights[player]

    if existingHighlight then
        if existingHighlight.Parent and existingHighlight.Adornee == character then
            existingHighlight.FillColor    = color
            existingHighlight.OutlineColor = color
            existingHighlight.Enabled      = true
        else
            pcall(function()
                existingHighlight:Destroy()
            end)
            State.PlayerHighlights[player] = nil

            local newHighlight = CreateHighlight(character, color)
            if newHighlight then
                State.PlayerHighlights[player] = newHighlight
            end
        end
    else
        local newHighlight = CreateHighlight(character, color)
        if newHighlight then
            State.PlayerHighlights[player] = newHighlight
        end
    end
end

local function getMurder()
    -- Приоритет 1: Реальная проверка предметов
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and plr.Character:FindFirstChild("Knife") then
            return plr
        end
    end
    
    for _, plr in ipairs(Players:GetPlayers()) do
        local backpack = plr:FindFirstChild("Backpack")
        if backpack and backpack:FindFirstChild("Knife") then
            return plr
        end
    end
    
    -- Приоритет 2: Серверные данные (для ESP)
    if State.PlayerData then
        for playerName, data in pairs(State.PlayerData) do
            if data.Role == "Murderer" then
                local player = Players:FindFirstChild(playerName)
                if player then
                    return player
                end
            end
        end
    end
    
    return nil
end

local function getSheriff()
    -- Приоритет 1: Реальная проверка предметов
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and plr.Character:FindFirstChild("Gun") then
            return plr
        end
    end
    
    for _, plr in ipairs(Players:GetPlayers()) do
        local backpack = plr:FindFirstChild("Backpack")
        if backpack and backpack:FindFirstChild("Gun") then
            return plr
        end
    end
    
    -- Приоритет 2: Серверные данные (для ESP)
    if State.PlayerData then
        for playerName, data in pairs(State.PlayerData) do
            if data.Role == "Sheriff" then
                local player = Players:FindFirstChild(playerName)
                if player then
                    return player
                end
            end
        end
    end
    
    return nil
end

-- ✅ НОВЫЕ функции ТОЛЬКО для автофарма (БЕЗ серверных данных)
local function getMurderForAutoFarm()
    for _, plr in ipairs(Players:GetPlayers()) do
        local character = plr.Character
        local backpack = plr:FindFirstChild("Backpack")

        if (character and character:FindFirstChild("Knife"))
            or (backpack and backpack:FindFirstChild("Knife")) then
            return plr
        end
    end
    return nil
end

local function getSheriffForAutoFarm()
    for _, plr in ipairs(Players:GetPlayers()) do
        local character = plr.Character
        local backpack = plr:FindFirstChild("Backpack")

        if (character and character:FindFirstChild("Gun"))
            or (backpack and backpack:FindFirstChild("Gun")) then
            return plr
        end
    end
    return nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AVATAR DISPLAY SYSTEM
-- ══════════════════════════════════════════════════════════════════════════════

-- Функция получения URL полного аватара (не headshot)
local function getAvatarUrl(userId)
    -- Используем встроенный Roblox API (не требует HttpService)
    local success, thumbnailUrl = pcall(function()
        return Players:GetUserThumbnailAsync(
            userId,
            Enum.ThumbnailType.AvatarBust,
            Enum.ThumbnailSize.Size420x420
        )
    end)
    
    if success and thumbnailUrl then
        return thumbnailUrl
    else
        warn("Failed to load avatar for UserId:", userId)
        return nil
    end
end

local function setAvatar(imageLabel, player)
    if not imageLabel then return end
    
    if not player then
        imageLabel.Image = ""
        return
    end
    
    local avatarUrl = getAvatarUrl(player.UserId)
    
    if avatarUrl then
        imageLabel.Image = avatarUrl
    else
        imageLabel.Image = ""
    end
end

-- Функция обновления аватаров (вызывается из Role ESP)
local function updateRoleAvatars()
    
    if not State.UIElements.MurdererAvatar or not State.UIElements.SheriffAvatar then
        warn("❌ Avatar UI elements not found!")
        return
    end
    
    local murderer = getMurder()
    local sheriff = getSheriff()
    
    
    -- Обновляем Murderer
    if murderer then
        if State.currentMurdererUserId ~= murderer.UserId then
            State.currentMurdererUserId = murderer.UserId
            setAvatar(State.UIElements.MurdererAvatar, murderer)
        end
    else
        if State.currentMurdererUserId ~= nil then
            State.currentMurdererUserId = nil
            State.UIElements.MurdererAvatar.Image = State.PLACEHOLDER_IMAGE
        end
    end
    
    -- Обновляем Sheriff
    if sheriff then
        if State.currentSheriffUserId ~= sheriff.UserId then
            State.currentSheriffUserId = sheriff.UserId
            setAvatar(State.UIElements.SheriffAvatar, sheriff)
        end
    else
        if State.currentSheriffUserId ~= nil then
            State.currentSheriffUserId = nil
            State.UIElements.SheriffAvatar.Image = State.PLACEHOLDER_IMAGE
        end
    end
end

local function CreateAvatarUI()
    pcall(function() CoreGui:FindFirstChild("MM2_AvatarDisplay"):Destroy() end)
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "MM2_AvatarDisplay"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10
    gui.Parent = CoreGui
    
    local container = Instance.new("Frame")
    container.Position = UDim2.new(1, -270, 1, -100)
    container.Size = UDim2.new(0, 170, 0, 90)
    container.BackgroundTransparency = 1
    container.Parent = gui
    
    -- Таблица конфигурации для аватаров
    local avatarConfigs = {
        Murderer = {
            position = UDim2.new(0, 0, 0, 0),
            color = CONFIG.Colors.Murder,
            text = "Murderer"
        },
        Sheriff = {
            position = UDim2.new(0, 90, 0, 0),
            color = CONFIG.Colors.Sheriff,
            text = "Sheriff"
        }
    }
    
    -- Функция создания аватара из конфига
    local function createFromConfig(config)
        local props = {
            frame = {Size = UDim2.new(0, 80, 0, 90), BackgroundColor3 = CONFIG.Colors.Section, BackgroundTransparency = 0.2, Position = config.position},
            corner = {CornerRadius = UDim.new(0, 8)},
            stroke = {Color = config.color, Thickness = 2},
            image = {Position = UDim2.new(0.5, 0, 0, 5), Size = UDim2.new(0, 60, 0, 60), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(40, 40, 45), Image = ""},
            imgCorner = {CornerRadius = UDim.new(0, 6)},
            label = {Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = config.text, TextColor3 = config.color, Font = Enum.Font.GothamBold, TextSize = 10, TextStrokeTransparency = 0.5}
        }
        
        local frame = Instance.new("Frame", container)
        for k,v in pairs(props.frame) do frame[k] = v end
        
        local corner = Instance.new("UICorner", frame)
        for k,v in pairs(props.corner) do corner[k] = v end
        
        local stroke = Instance.new("UIStroke", frame)
        for k,v in pairs(props.stroke) do stroke[k] = v end
        
        local img = Instance.new("ImageLabel", frame)
        for k,v in pairs(props.image) do img[k] = v end
        
        local imgCorner = Instance.new("UICorner", img)
        for k,v in pairs(props.imgCorner) do imgCorner[k] = v end
        
        local label = Instance.new("TextLabel", frame)
        for k,v in pairs(props.label) do label[k] = v end
        
        return img
    end
    
    -- Создание аватаров
    State.UIElements.MurdererAvatar = createFromConfig(avatarConfigs.Murderer)
    State.UIElements.SheriffAvatar = createFromConfig(avatarConfigs.Sheriff)
    State.UIElements.AvatarDisplayGui = gui
end

-- Функция очистки аватара Sheriff (вызывается при Gun drop)
local function clearSheriffAvatar()
    if State.UIElements.SheriffAvatar then
        State.UIElements.SheriffAvatar.Image = ""
        State.currentSheriffUserId = nil
    end
end

-- Функция очистки всех аватаров (вызывается при окончании раунда)
local function clearAllAvatars()
    if State.UIElements.MurdererAvatar then
        State.UIElements.MurdererAvatar.Image = ""
    end
    if State.UIElements.SheriffAvatar then
        State.UIElements.SheriffAvatar.Image = ""
    end
    State.currentMurdererUserId = nil
    State.currentSheriffUserId = nil
end


-- Role ESP loop
local function StartRoleChecking()
    SetupPlayerDataListener()
    if State.RoleCheckLoop then
        pcall(function()
            State.RoleCheckLoop:Disconnect()
        end)
        State.RoleCheckLoop = nil
    end

    for player, highlight in pairs(State.PlayerHighlights) do
        pcall(function()
            highlight:Destroy()
        end)
        State.PlayerHighlights[player] = nil
    end

    State.RoleCheckLoop = RunService.Heartbeat:Connect(function()
        pcall(function()
            local murder  = getMurder()
            local sheriff = getSheriff()

            local murderers = {}
            local sheriffs  = {}
            local innocents = {}

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr == murder then
                    table.insert(murderers, plr)
                elseif plr == sheriff then
                    table.insert(sheriffs, plr)
                else
                    table.insert(innocents, plr)
                end
            end

            for _, plr in ipairs(murderers) do
                UpdatePlayerHighlight(plr, "Murder")
            end
            for _, plr in ipairs(sheriffs) do
                UpdatePlayerHighlight(plr, "Sheriff")
            end
            for _, plr in ipairs(innocents) do
                UpdatePlayerHighlight(plr, "Innocent")
            end

            if murder and sheriff and State.roundStart then
                State.roundActive = true
                State.roundStart  = false
                State.prevMurd    = murder
                State.prevSher    = sheriff
                State.heroSent    = false

                if State.NotificationsEnabled then
                    ShowNotification(
                        "<font color=\"rgb(255, 85, 85)\">🗡️ Murderer:</font> " .. murder.Name,
                        CONFIG.Colors.Text
                    )
                    task.wait(0.1)
                    ShowNotification(
                        "<font color=\"rgb(50, 150, 255)\">🔫 Sheriff:</font> " .. sheriff.Name,
                        CONFIG.Colors.Text
                    )
                end

                task.spawn(function()
                    updateRoleAvatars()
                end)
            end

            if not murder and State.roundActive then
                State.roundActive = false
                State.roundStart  = true
                State.prevMurd    = nil
                State.prevSher    = nil
                State.heroSent    = false
                
                -- Очистка серверных данных
                State.PlayerData = {}
                
                if State.NotificationsEnabled then
                    ShowNotification(
                        "<font color=\"rgb(220, 220, 220)\">Round ended</font>",
                        CONFIG.Colors.Text
                    )
                end
                clearAllAvatars()
            end

            -- Обнаружение смены шерифа (Hero)
            if sheriff
                and State.prevSher
                and sheriff ~= State.prevSher
                and murder
                and murder == State.prevMurd
                and not State.heroSent then

                State.prevSher = sheriff
                State.heroSent = true

                if State.NotificationsEnabled then
                    ShowNotification(
                        "<font color=\"rgb(50, 150, 255)\">⭐ Hero:</font> " .. sheriff.Name,
                        CONFIG.Colors.Text
                    )
                end
                task.spawn(function()
                    updateRoleAvatars()
                end)
            end
        end)
    end)
    table.insert(State.Connections, State.RoleCheckLoop)
end

----------------------------------------------------------------
-- Gun ESP + уведомление
----------------------------------------------------------------

local function getMap()
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:FindFirstChild("CoinContainer") then
            return v
        end
    end
    return nil
end

local function getGun()
    local map = getMap()
    if not map then return nil end
    return map:FindFirstChild("GunDrop")
end

local function CreateGunESP(gunPart)
    if not gunPart or not gunPart:IsA("BasePart") then return end

    if not gunPart.Parent then
        if State.GunCache[gunPart] then
            RemoveGunESP(gunPart)
        end
        return
    end

    if State.GunCache[gunPart] then
        RemoveGunESP(gunPart)
    end

    local highlight = Instance.new("Highlight")
    highlight.Adornee            = gunPart
    highlight.FillColor          = CONFIG.Colors.Gun
    highlight.FillTransparency   = 0.8
    highlight.OutlineColor       = CONFIG.Colors.Gun
    highlight.OutlineTransparency = 0.3
    highlight.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled            = State.GunESP
    highlight.Parent             = gunPart

    local billboard = Instance.new("BillboardGui")
    billboard.Name       = "GunESPLabel"
    billboard.Adornee    = gunPart
    billboard.Size       = UDim2.new(0, 140, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent      = gunPart

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size                   = UDim2.new(1, 0, 1, 0)
    label.Text                   = "GUN"
    label.TextColor3             = Color3.fromRGB(255, 255, 255)
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 12
    label.TextStrokeTransparency = 0.6
    label.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    label.Parent                 = billboard

    State.GunCache[gunPart] = {
        highlight = highlight,
        billboard = billboard
    }
end

local function RemoveGunESP(gunPart)
    if not gunPart or not State.GunCache[gunPart] then return end

    local espData = State.GunCache[gunPart]

    pcall(function()
        if espData.highlight then
            espData.highlight:Destroy()
        end
        if espData.billboard then
            espData.billboard:Destroy()
        end
    end)

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

----------------------------------------------------------------
-- Trap ESP (работает только с Gun ESP)
----------------------------------------------------------------
local RemoveTrapESP

local function CreateTrapESP(trapModel)
    if not trapModel then return end
    if not trapModel:IsA("Model") then return end
    if not trapModel.Parent then return end
    
    if State.TrapCache[trapModel] then
        RemoveTrapESP(trapModel)
    end
    
    local mainPart = trapModel:FindFirstChild("TrapVisual")
    if not mainPart or not mainPart:IsA("BasePart") then return end
    
    -- ✅ ПРОВЕРКА ПОЗИЦИИ: Игнорируем ловушки близко к центру (спавн/лобби)
    local pos = mainPart.Position
    if math.abs(pos.X) < 100 and math.abs(pos.Y) < 100 and math.abs(pos.Z) < 100 then
        return  -- Слишком близко к центру - это не игровая ловушка
    end
    if State.NotificationsEnabled then
        task.spawn(function()
            ShowNotification(
                "<font color=\"rgb(255, 85, 85)\">⚠️ Trap placed!</font>",
                CONFIG.Colors.Murder  -- Используем цвет убийцы
            )
        end)
    end
    pcall(function()
        mainPart.Material = Enum.Material.Glass
        mainPart.Transparency = -math.huge
        mainPart.Reflectance = -math.huge
        mainPart.Color = Color3.fromRGB(255, 0, 4)
    end)
    
    if not trapModel:FindFirstChildOfClass("Humanoid") then
        local humanoid = Instance.new("Humanoid")
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.Health = 0
        humanoid.MaxHealth = 0
        humanoid.Parent = trapModel
    end
    
    local highlight = Instance.new("Highlight")
    highlight.Adornee = trapModel
    highlight.FillColor = Color3.fromRGB(255, 0, 4)
    highlight.FillTransparency = 0.8
    highlight.OutlineColor = Color3.fromRGB(255, 0, 4)
    highlight.OutlineTransparency = 0.5
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = State.GunESP
    highlight.Parent = trapModel
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TrapESPLabel"
    billboard.Adornee = mainPart
    billboard.Size = UDim2.new(0, 140, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = game:GetService("CoreGui")
    
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = "Trap"
    label.TextColor3 = Color3.fromRGB(255, 85, 85)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextStrokeTransparency = 0.7
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = billboard
    
    State.TrapCache[trapModel] = {
        highlight = highlight,
        billboard = billboard,
        trapPart = mainPart
    }
end

RemoveTrapESP = function(trapModel)
    if not trapModel or not State.TrapCache[trapModel] then return end
    
    local espData = State.TrapCache[trapModel]
    
    pcall(function()
        if espData.highlight then espData.highlight:Destroy() end
        if espData.billboard then espData.billboard:Destroy() end
        
        if espData.trapPart and espData.trapPart.Parent then
            espData.trapPart.Transparency = 1
            espData.trapPart.Material = Enum.Material.Plastic
        end
    end)
    
    State.TrapCache[trapModel] = nil
end

local function UpdateTrapESPVisibility()
    for trapModel, espData in pairs(State.TrapCache) do
        if espData.highlight then
            espData.highlight.Enabled = State.GunESP
        end
        if espData.billboard then
            espData.billboard.Enabled = State.GunESP
        end
    end
end

local function ScanMurdererTraps()
    if not State.GunESP then return end
    
    local murder = getMurder()
    if not murder then
        -- Нет убийцы - удаляем все ловушки
        for cachedTrap in pairs(State.TrapCache) do
            RemoveTrapESP(cachedTrap)
        end
        return
    end
    
    local murdererFolder = Workspace:FindFirstChild(murder.Name)
    if not murdererFolder then return end
    
    local foundTraps = {}
    
    for _, child in ipairs(murdererFolder:GetDescendants()) do
        if child.Name == "Trap" and child:IsA("Model") then
            if child:FindFirstChild("TrapVisual") and child:FindFirstChild("PlacedPlayer") then
                foundTraps[child] = true
                
                if not State.TrapCache[child] then
                    CreateTrapESP(child)
                end
            end
        end
    end
    
    for cachedTrap in pairs(State.TrapCache) do
        if not foundTraps[cachedTrap] or not cachedTrap.Parent then
            RemoveTrapESP(cachedTrap)
        end
    end
end

-- ✅ АВТОМАТИЧЕСКОЕ ОТСЛЕЖИВАНИЕ ЛОВУШЕК
local function StartTrapTracking()
    local lastScan = 0
    
    local connection = RunService.Heartbeat:Connect(function()
        if not State.GunESP then return end
        
        local currentTime = tick()
        if currentTime - lastScan >= 1 then
            lastScan = currentTime
            pcall(ScanMurdererTraps)
        end
    end)
    
    table.insert(State.Connections, connection)
end

local function SetupGunTracking()
    if State.currentMapConnection then
        State.currentMapConnection:Disconnect()
        State.currentMapConnection = nil
    end

    State.currentMapConnection = RunService.Heartbeat:Connect(function()
        pcall(function()
            local gun = getGun()

            if gun and gun ~= State.previousGun then
                State.CurrentGunDrop = gun

                if State.NotificationsEnabled then
                    task.spawn(function()
                        ShowNotification(
                            "<font color=\"rgb(255, 200, 50)\">Gun dropped!</font>",
                            CONFIG.Colors.Gun
                        )
                    end)
                    task.spawn(function()
                        clearSheriffAvatar()
                    end)
                end               

                State.previousGun = gun
            end

            if not gun and State.previousGun then
                State.previousGun = nil
            end

            if gun and State.GunESP then
                if not State.GunCache[gun] then
                    CreateGunESP(gun)
                else
                    local espData = State.GunCache[gun]
                    if espData.highlight then
                        espData.highlight.Enabled = State.GunESP
                    end
                end
            end

            for cachedGun, _ in pairs(State.GunCache) do
                if cachedGun ~= gun or not gun then
                    RemoveGunESP(cachedGun)
                end
            end
            -- if State.GunESP then
            --     ScanForTraps()
            -- end
        end)
    end)

    table.insert(State.Connections, State.currentMapConnection)
end
-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 7: Fling (СТРОКИ 611-660)
-- ══════════════════════════════════════════════════════════════════════════════

local AntiFlingState = {
    LastPos = Vector3.zero,
    DetectionConn = nil,
    NeutralizerConn = nil,
    Flingers = {},
    NotifCooldown = false,
    Thresholds = {
        Angular = 50,
        Linear = 100,
        Danger = 250
    }
}

-- EnableAntiFling() - Включение защиты от флинга
local function EnableAntiFling()
    if State.AntiFlingEnabled then return end
    State.AntiFlingEnabled = true
    
    -- Обнаружение флингеров
    AntiFlingState.DetectionConn = RunService.Heartbeat:Connect(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character.PrimaryPart then
                local part = plr.Character.PrimaryPart
                local angVel = part.AssemblyAngularVelocity.Magnitude
                local linVel = part.AssemblyLinearVelocity.Magnitude
                
                if angVel > AntiFlingState.Thresholds.Angular or linVel > AntiFlingState.Thresholds.Linear then
                    AntiFlingState.Flingers[plr.Name] = true
                    
                    pcall(function()
                        for _, obj in ipairs(plr.Character:GetDescendants()) do
                            if obj:IsA("BasePart") then
                                pcall(function()
                                    obj.CanCollide = false
                                    obj.Massless = true  -- Вместо CustomPhysicalProperties
                                    obj.AssemblyAngularVelocity = Vector3.zero
                                    obj.AssemblyLinearVelocity = Vector3.zero
                                end)
                            end
                        end
                    end)
                end
            end
        end
    end)
    
    -- Защита локального игрока
    AntiFlingState.NeutralizerConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char or not char.PrimaryPart then return end
        
        local part = char.PrimaryPart
        
        if State.IsFlingInProgress then
            AntiFlingState.LastPos = part.Position
            return
        end
        
        local velMag = part.AssemblyLinearVelocity.Magnitude
        local angMag = part.AssemblyAngularVelocity.Magnitude
        
        if velMag > AntiFlingState.Thresholds.Danger or angMag > AntiFlingState.Thresholds.Danger then
            if State.NotificationsEnabled and not AntiFlingState.NotifCooldown then
                ShowNotification(
                    "<font color=\"rgb(220, 220, 220)\">Anti-Fling: Velocity neutralized</font>",
                    CONFIG.Colors.Text
                )
                AntiFlingState.NotifCooldown = true
                task.delay(3, function() AntiFlingState.NotifCooldown = false end)
            end
            
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
            
            if AntiFlingState.LastPos ~= Vector3.zero then
                part.CFrame = CFrame.new(AntiFlingState.LastPos)
            end
        else
            AntiFlingState.LastPos = part.Position
        end
    end)
    
    table.insert(State.Connections, AntiFlingState.DetectionConn)
    table.insert(State.Connections, AntiFlingState.NeutralizerConn)
end

-- DisableAntiFling() - Отключение защиты
local function DisableAntiFling()
    State.AntiFlingEnabled = false
    AntiFlingState.Flingers = {}
    
    if AntiFlingState.DetectionConn then
        AntiFlingState.DetectionConn:Disconnect()
        AntiFlingState.DetectionConn = nil
    end
    
    if AntiFlingState.NeutralizerConn then
        AntiFlingState.NeutralizerConn:Disconnect()
        AntiFlingState.NeutralizerConn = nil
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 9: FLING FUNCTIONS (СТРОКИ 791-1050)
-- ══════════════════════════════════════════════════════════════════════════════

-- FlingPlayer() - Главная функция флинга
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

    local FlingData = {
        -- Локальный игрок
        Character = LocalPlayer.Character,
        Humanoid = nil,
        RootPart = nil,
        
        -- Целевой игрок
        TCharacter = playerToFling.Character,
        THumanoid = nil,
        TRootPart = nil,
        THead = nil,
        Accessory = nil,
        Handle = nil,
        
        -- Настройки
        antiFlingWasEnabled = State.AntiFlingEnabled,
        OldPos = nil,
        
        -- Временные объекты
        BV = nil
    }
    
    if not FlingData.Character then return end
    
    FlingData.Humanoid = FlingData.Character:FindFirstChildOfClass("Humanoid")
    FlingData.RootPart = FlingData.Humanoid and FlingData.Humanoid.RootPart
    if not FlingData.RootPart then return end
    
    if FlingData.antiFlingWasEnabled then
        DisableAntiFling()
    end
    State.IsFlingInProgress = true

    FlingData.THumanoid = FlingData.TCharacter:FindFirstChildOfClass("Humanoid")
    FlingData.TRootPart = FlingData.THumanoid and FlingData.THumanoid.RootPart
    FlingData.THead = FlingData.TCharacter:FindFirstChild("Head")
    FlingData.Accessory = FlingData.TCharacter:FindFirstChildOfClass("Accessory")
    FlingData.Handle = FlingData.Accessory and FlingData.Accessory:FindFirstChild("Handle")

    if not FlingData.TRootPart and not FlingData.THead and not FlingData.Handle then
        if State.NotificationsEnabled then
            ShowNotification(
                "<font color=\"rgb(255, 85, 85)\">Body parts missing</font>",
                CONFIG.Colors.Text
            )
        end
        return
    end

    if FlingData.RootPart.Velocity.Magnitude < 50 then
        FlingData.OldPos = FlingData.RootPart.CFrame
    end

    local targetPart = FlingData.TRootPart or FlingData.THead or FlingData.Handle
    
    if targetPart.Velocity.Magnitude > 500 then
        if State.NotificationsEnabled then
            ShowNotification(
                "<font color=\"rgb(220,220,220)\">Fling: Already flung</font>",
                CONFIG.Colors.Text
            )
        end
        return
    end

    Workspace.CurrentCamera.CameraSubject = targetPart
    Workspace.FallenPartsDestroyHeight = 0/0

    FlingData.BV = Instance.new("BodyVelocity")
    FlingData.BV.Name = "EpixVel"
    FlingData.BV.Parent = FlingData.RootPart
    FlingData.BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
    FlingData.BV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)

    FlingData.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    local function FPos(BasePart, Pos, Ang)
        local newCFrame = CFrame.new(BasePart.Position) * Pos * Ang
        FlingData.RootPart.CFrame = newCFrame
        FlingData.RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
        FlingData.RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    local function SFBasePart(BasePart)
        local TimeToWait = 2
        local Time = tick()
        local Angle = 0
        
        repeat
            if FlingData.RootPart and FlingData.THumanoid then
                if BasePart.Velocity.Magnitude < 50 then
                    Angle = Angle + 100

                    FPos(BasePart, CFrame.new(0, 1.5, 0) + FlingData.THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()

                    FPos(BasePart, CFrame.new(0, -1.5, 0) + FlingData.THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()

                    FPos(BasePart, CFrame.new(2.25, 1.5, -2.25) + FlingData.THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()

                    FPos(BasePart, CFrame.new(-2.25, -1.5, 2.25) + FlingData.THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()

                    FPos(BasePart, CFrame.new(0, 1.5, 0) + FlingData.THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()

                    FPos(BasePart, CFrame.new(0, -1.5, 0) + FlingData.THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                else
                    FPos(BasePart, CFrame.new(0, 1.5, FlingData.THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()

                    FPos(BasePart, CFrame.new(0, -1.5, -FlingData.THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                    task.wait()
                end
            else
                break
            end
        until BasePart.Velocity.Magnitude > 500 or 
              BasePart.Parent ~= playerToFling.Character or 
              playerToFling.Parent ~= Players or 
              playerToFling.Character ~= FlingData.TCharacter or 
              FlingData.THumanoid.Sit or 
              FlingData.Humanoid.Health <= 0 or 
              tick() > Time + TimeToWait
    end

    if FlingData.TRootPart and FlingData.THead then
        if (FlingData.TRootPart.CFrame.p - FlingData.THead.CFrame.p).Magnitude > 5 then
            SFBasePart(FlingData.THead)
        else
            SFBasePart(FlingData.TRootPart)
        end
    elseif FlingData.TRootPart and not FlingData.THead then
        SFBasePart(FlingData.TRootPart)
    elseif not FlingData.TRootPart and FlingData.THead then
        SFBasePart(FlingData.THead)
    elseif not FlingData.TRootPart and not FlingData.THead and FlingData.Accessory and FlingData.Handle then
        SFBasePart(FlingData.Handle)
    end

    FlingData.BV:Destroy()
    FlingData.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    Workspace.CurrentCamera.CameraSubject = FlingData.Humanoid

    if FlingData.OldPos then
        repeat
            FlingData.RootPart.CFrame = FlingData.OldPos * CFrame.new(0, 0.5, 0)
            FlingData.Humanoid:ChangeState("GettingUp")

            for _, part in pairs(FlingData.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Velocity = Vector3.new()
                    part.RotVelocity = Vector3.new()
                end
            end

            task.wait()
        until (FlingData.RootPart.Position - FlingData.OldPos.p).Magnitude < 25
    end

    Workspace.FallenPartsDestroyHeight = State.FPDH
    
    State.IsFlingInProgress = false
    if FlingData.antiFlingWasEnabled then
        task.delay(1, function()
            EnableAntiFling()
        end)
    end

    if State.NotificationsEnabled then
        ShowNotification(
            "<font color=\"rgb(220,220,220)\">Player flung: " .. playerToFling.Name .. "</font>",
            CONFIG.Colors.Text
        )
    end
end

-- FlingMurderer() - Флинг убийцы
local function FlingMurderer()
    local murderer = getMurder()
    if not murderer then
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">Murderer not found</font>", CONFIG.Colors.Text)
        end
        return
    end
    
    if murderer == LocalPlayer then
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">You cannot fling yourself!</font>", CONFIG.Colors.Text)
        end
        return
    end
    FlingPlayer(murderer)
end

local function WalkFlingStop(forced)
    if not forced then
        State.WalkFlingEnabledByUser = false
    end

    if not State.WalkFlingActive then return end
    State.WalkFlingActive = false
    
    if State.WalkFlingConnection then 
        State.WalkFlingConnection:Disconnect() 
        State.WalkFlingConnection = nil 
    end
    
    -- Полный сброс физики персонажа
    task.spawn(function()
        local char = LocalPlayer.Character
        if not char then return end
        
        -- Сбрасываем скорость ВСЕХ частей тела
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                    part.Velocity = Vector3.zero
                    part.RotVelocity = Vector3.zero
                end)
            end
        end
        
        -- Ждем несколько кадров для стабилизации
        for i = 1, 3 do
            RunService.Heartbeat:Wait()
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end)
end

local function WalkFlingStart()
    State.WalkFlingEnabledByUser = true
    if State.WalkFlingActive then return end
    
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- === ЛОГИКА ПЕРЕВКЛЮЧЕНИЯ АНТИФЛИНГА ===
    local wasAntiFlingOn = State.AntiFlingEnabled
    
    if wasAntiFlingOn then
        DisableAntiFling() -- 1. Выключаем антифлинг
    end
    -- ========================================

    State.WalkFlingActive = true -- 2. Включаем флаг WalkFling

    local movel = 0.1
    
    State.WalkFlingConnection = RunService.Heartbeat:Connect(function()
        -- ВАЖНО: Получаем СВЕЖУЮ ссылку каждый кадр
        local currentChar = LocalPlayer.Character
        local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        local currentHum = currentChar and currentChar:FindFirstChild("Humanoid")
        
        if not currentRoot or not currentHum or currentHum.Health <= 0 then
            WalkFlingStop(true)
            return 
        end
        
        if not State.WalkFlingActive then 
            WalkFlingStop()
            return 
        end
        
        local vel = currentRoot.AssemblyLinearVelocity
        
        if vel.Magnitude > 2 then 
            currentRoot.AssemblyLinearVelocity = vel * 10000 + Vector3.new(0, 10000, 0)
            RunService.RenderStepped:Wait()
            if not State.WalkFlingActive then return end
            currentRoot.AssemblyLinearVelocity = vel
            RunService.Stepped:Wait()
            if not State.WalkFlingActive then return end
            currentRoot.AssemblyLinearVelocity = vel + Vector3.new(0, movel, 0)
            movel = -movel
        end
    end)
    
    -- === ВКЛЮЧАЕМ АНТИФЛИНГ ОБРАТНО ===
    if wasAntiFlingOn then
        EnableAntiFling() -- 3. Включаем антифлинг после создания соединения
    end
    -- ===================================
end

-- === АВТОМАТИЧЕСКИЙ ПЕРЕЗАПУСК ПРИ СМЕНЕ ПЕРСОНАЖА ===
LocalPlayer.CharacterAdded:Connect(function(character)
    if State.WalkFlingEnabledByUser then
        -- Принудительно останавливаем старое соединение
        WalkFlingStop(true)
        
        -- Ждем HumanoidRootPart
        local root = character:WaitForChild("HumanoidRootPart", 5)
        local hum = character:WaitForChild("Humanoid", 5)
        
        if root and hum and hum.Health > 0 then
            task.wait(0.1) -- Задержка для стабильности
            WalkFlingStart() -- Просто вызываем Start с полной логикой
        end
    end
end)

-- Наблюдатель (запасной вариант)
task.spawn(function()
    while ScriptAlive do
        task.wait(1)
        if not ScriptAlive then break end
        if State.WalkFlingEnabledByUser and not State.WalkFlingActive then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                WalkFlingStart()
            end
        end
    end
end)

ToggleWalkFling = function()
    if State.WalkFlingEnabledByUser then
        WalkFlingStop(false)
    else
        WalkFlingStart()
    end
end

-- FlingSheriff() - Флинг шерифа
local function FlingSheriff()
    local sheriff = getSheriffForAutoFarm()
    if not sheriff then
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">Sheriff not found</font>", CONFIG.Colors.Text)
        end
        return
    end
    
    if sheriff == LocalPlayer then
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">You cannot fling yourself!</font>", CONFIG.Colors.Text)
        end
        return
    end
    FlingPlayer(sheriff)
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 10: NOCLIP SYSTEM (СТРОКИ 1051-1180)
-- ══════════════════════════════════════════════════════════════════════════════

-- EnableNoClip() - Включение NoClip
local function EnableNoClip()
    if State.NoClipEnabled then return end
    State.NoClipEnabled = true
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local NoClipObjects = {}
    
    for _, obj in ipairs(character:GetChildren()) do
        if obj:IsA("BasePart") then
            table.insert(NoClipObjects, obj)
        end
    end
    
    State.NoClipObjects = NoClipObjects
    
    State.NoClipRespawnConnection = TrackConnection(LocalPlayer.CharacterAdded:Connect(function(newChar)

        task.wait(0.15)
        
        table.clear(NoClipObjects)
        
        for _, obj in ipairs(newChar:GetChildren()) do
            if obj:IsA("BasePart") then
                table.insert(NoClipObjects, obj)
            end
        end
    end))
    
    State.NoClipConnection = TrackConnection(RunService.Stepped:Connect(function()
        for i = 1, #NoClipObjects do
            NoClipObjects[i].CanCollide = false
        end
    end))
    
    if State.NotificationsEnabled then
        ShowNotification("<font color=\"rgb(220,220,220)\">Noclip: </font><font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Text)
    end
end

-- DisableNoClip() - Отключение NoClip
local function DisableNoClip()
    if not State.NoClipEnabled then return end
    State.NoClipEnabled = false
    
    if State.NoClipConnection then
        State.NoClipConnection:Disconnect()
        State.NoClipConnection = nil
    end
    
    if State.NoClipRespawnConnection then
        State.NoClipRespawnConnection:Disconnect()
        State.NoClipRespawnConnection = nil
    end
    
    if State.NoClipObjects then
        local character = LocalPlayer.Character
        if character then
            for i = 1, #State.NoClipObjects do
                local part = State.NoClipObjects[i]
                if part and part.Parent then
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

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 11: AUTO FARM SYSTEM (СТРОКИ 1181-1600)
-- ══════════════════════════════════════════════════════════════════════════════

local coinLabelCache = nil
local lastCacheTime = 0

local function GetCollectedCoinsCount()
    -- УРОВЕНЬ 1: Проверка кэша (2 секунды)
    if coinLabelCache and coinLabelCache.Parent and (tick() - lastCacheTime) < 2 then
        local success, value = pcall(function()
            return tonumber(coinLabelCache.Text) or 0
        end)
        if success then
            return value
        end
    end

    -- ✅ УРОВЕНЬ 2: Прямой путь - "Coin" вместо "SnowToken"
    local success, coins = pcall(function()
        local label = LocalPlayer.PlayerGui
            :FindFirstChild("MainGUI")
            :FindFirstChild("Game")
            :FindFirstChild("CoinBags")
            :FindFirstChild("Container")
            :FindFirstChild("Coin")
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

    if success and coins >= 0 then  -- ✅ >= 0 вместо > 0
        return coins
    end

    -- УРОВЕНЬ 3: Fallback - GetDescendants поиск максимального значения
    local maxValue = 0
    pcall(function()
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") and gui.Name == "Coins" then
                local path = gui:GetFullName()
                if path:match("CurrencyFrame.Icon.Coins") then
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

local function AddCoinToBlacklist(coin)
    State.CoinBlacklist[coin] = true
end

-- ✅ Очистка между раундами
local function CleanupCoinBlacklist()
    --print("[Auto Farm] 🧹 Очистка CoinBlacklist...")
    local cleaned = 0
    for coin, _ in pairs(State.CoinBlacklist) do
        if not coin.Parent then
            State.CoinBlacklist[coin] = nil
            cleaned = cleaned + 1
        end
    end
    --print(("[Auto Farm] 🧹 Удалено %d мёртвых ссылок"):format(cleaned))
end

-- ResetCharacter() - Ресет с сохранением GodMode
local function ResetCharacter()
    --print("[Auto Farm] 🔄 Делаю ресет...")
    
    local wasGodModeEnabled = State.GodModeEnabled
    
    if wasGodModeEnabled then
        --print("[Auto Farm] 🛡️ GodMode был включен, временно отключаю...")
        State.GodModeEnabled = false
        
        -- ✅ Отключаем ВСЕ connections
        if State.healthConnection then
            State.healthConnection:Disconnect()
            State.healthConnection = nil
        end
        if State.stateConnection then
            State.stateConnection:Disconnect()
            State.stateConnection = nil
        end
        if State.damageBlockerConnection then
            State.damageBlockerConnection:Disconnect()
            State.damageBlockerConnection = nil
        end
        
        for _, connection in ipairs(State.GodModeConnections) do
            if connection and connection.Connected then
                connection:Disconnect()
            end
        end
        State.GodModeConnections = {}  -- ✅ Очищаем таблицу
        
        -- Возвращаем нормальное здоровье
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                pcall(function()
                    humanoid.MaxHealth = 100
                    humanoid.Health = 100
                end)
            end
            
            local ff = character:FindFirstChild("ForceField")
            if ff then
                ff:Destroy()
            end
        end
    end
    
    -- ✅ ДЕЛАЕМ РЕСЕТ
    pcall(function()
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.Health = 0
            end
        end
    end)
    
    -- ✅ ЖДЁМ НОВОГО ПЕРСОНАЖА
    if wasGodModeEnabled then
        task.spawn(function()
            -- ✅ ВАЖНО: проверяем что автофарм всё ещё работает
            if not State.AutoFarmEnabled then
                --print("[Auto Farm] ⚠️ Автофарм выключен, прерываю восстановление GodMode")
                return
            end
            
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            
            -- ✅ Проверка ещё раз перед восстановлением
            if not State.AutoFarmEnabled then
                return
            end
            
            --print("[Auto Farm] ⏳ Новый персонаж появился, жду Humanoid...")
            
            local humanoid = character:WaitForChild("Humanoid", 10)
            if not humanoid then
                --print("[Auto Farm] ⚠️ Humanoid не найден за 10 секунд!")
                return
            end
            
            -- ✅ Финальная проверка
            if not State.AutoFarmEnabled then
                return
            end
            
            task.wait(0.5)
            
            --print("[Auto Farm] 🛡️ Humanoid найден, восстанавливаю GodMode...")
            
            State.GodModeEnabled = true
            
            if ApplyGodMode then ApplyGodMode() end
            if SetupHealthProtection then SetupHealthProtection() end
            if SetupDamageBlocker then SetupDamageBlocker() end
            
            -- ✅ Очищаем старые connections перед созданием новых
            for _, connection in ipairs(State.GodModeConnections) do
                if connection and connection.Connected then
                    connection:Disconnect()
                end
            end
            State.GodModeConnections = {}
            
            -- HP monitoring
            local godModeConnection = RunService.Heartbeat:Connect(function()
                if State.GodModeEnabled and LocalPlayer.Character then
                    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum then
                        if hum.Health ~= math.huge then
                            hum.Health = math.huge
                        end
                        local state = hum:GetState()
                        if state == Enum.HumanoidStateType.Dead then
                            hum:ChangeState(Enum.HumanoidStateType.Running)
                        end
                    end
                end
            end)
            table.insert(State.GodModeConnections, godModeConnection)
            
            -- Respawn protection
            local respawnConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
                if State.GodModeEnabled then
                    task.wait(0.5)
                    if ApplyGodMode then ApplyGodMode() end
                    if SetupHealthProtection then SetupHealthProtection() end
                    if SetupDamageBlocker then SetupDamageBlocker() end
                end
            end)
            table.insert(State.GodModeConnections, respawnConnection)
            
            --print("[Auto Farm] ✅ GodMode восстановлен!")
        end)
    end
end


local function FloatCharacter()
    local character = LocalPlayer.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    -- ✅ FIX: Проверка существования и здоровья
    if not hrp or not humanoid or humanoid.Health <= 0 then 
        return false 
    end
    
    -- Удаляем старый BodyPosition если есть
    local oldBP = hrp:FindFirstChild("AFK_BodyPosition")
    if oldBP then oldBP:Destroy() end
    
    -- Создаём BodyPosition для левитации
    local bodyPos = Instance.new("BodyPosition")
    bodyPos.Name = "AFK_BodyPosition"
    bodyPos.Position = hrp.Position
    bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyPos.D = 1250
    bodyPos.P = 10000
    bodyPos.Parent = hrp
    
    -- Также создаём BodyGyro для стабилизации вращения
    local oldBG = hrp:FindFirstChild("AFK_BodyGyro")
    if oldBG then oldBG:Destroy() end
    
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "AFK_BodyGyro"
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.P = 10000
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp
    
    --print("[Auto Farm] 🎈 Левитация включена")
    return true
end

-- ✅ ИСПРАВЛЕНО: Добавлена проверка существования
local function UnfloatCharacter()
    local character = LocalPlayer.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    -- ✅ FIX: Проверка существования перед удалением
    local bodyPos = hrp:FindFirstChild("AFK_BodyPosition")
    if bodyPos and bodyPos.Parent then
        bodyPos:Destroy()
    end
    
    local bodyGyro = hrp:FindFirstChild("AFK_BodyGyro")
    if bodyGyro and bodyGyro.Parent then
        bodyGyro:Destroy()
    end
    
    --print("[Auto Farm] 🎈 Левитация выключена")
    return true
end

local function FindSafeAFKSpot()
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    -- ✅ FIX: Проверка здоровья
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then 
        return nil 
    end
    
    -- Ищем карту
    local map = nil
    for _, o in ipairs(Workspace:GetChildren()) do
        if o:FindFirstChild("CoinContainer") and o:FindFirstChild("Spawns") then
            map = o
            break
        end
    end
    
    if not map then
        return hrp.CFrame * CFrame.new(0, 300, 0)
    end
    
    local spawnsFolder = map:FindFirstChild("Spawns")
    if not spawnsFolder then
        return hrp.CFrame * CFrame.new(0, 300, 0)
    end
    
    local spawns = spawnsFolder:GetChildren()
    if #spawns == 0 then
        return hrp.CFrame * CFrame.new(0, 300, 0)
    end
    
    local randomSpawn = spawns[math.random(1, #spawns)]

    if randomSpawn:IsA("BasePart") then
        return randomSpawn.CFrame * CFrame.new(0, 300, 0)
    elseif randomSpawn:IsA("Model") then
        local spawnPart = randomSpawn:FindFirstChildWhichIsA("BasePart")
        if spawnPart then
            return spawnPart.CFrame * CFrame.new(0, 300, 0)
        end
    end
    
    return hrp.CFrame * CFrame.new(0, 300, 0)
end


local ToggleInvisibility
local InitializeVisibleParts

local InvisibilityConnection = nil
local VisibleParts = {}

local function FindNearestCoin()
    local character = LocalPlayer.Character
    if not character then return nil end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end

    local closestCoin = nil
    local closestDistance = math.huge
    local hrpPosition = humanoidRootPart.Position

    local coinContainer = nil
    pcall(function()
        local map = getMap()
        if map then
            coinContainer = map:FindFirstChild("CoinContainer")
        end
    end)

    local searchRoot = coinContainer or Workspace

    for _, coin in ipairs(searchRoot:GetDescendants()) do
        if coin:IsA("BasePart") 
           and coin.Name == "Coin_Server"
           and coin:FindFirstChildWhichIsA("TouchTransmitter") 
           and not State.CoinBlacklist[coin] then

            local coinVisual = coin:FindFirstChild("CoinVisual")
            if coinVisual then
                local distance = (coin.Position - hrpPosition).Magnitude

                if distance < closestDistance then
                    closestDistance = distance
                    closestCoin = coin
                end
            end
        end
    end

    return closestCoin, closestDistance -- ✅ ВОЗВРАЩАЕМ ЕЩЁ И РАССТОЯНИЕ
end

-- ✅ НОВАЯ ФУНКЦИЯ: Быстрая проверка на более близкую монету
local function FindBetterCoin(currentCoin, currentDistance, threshold)
    threshold = threshold or 10 -- Минимальная разница в studs для смены цели
    
    local character = LocalPlayer.Character
    if not character then return nil end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end

    local hrpPosition = humanoidRootPart.Position
    
    local coinContainer = nil
    pcall(function()
        local map = getMap()
        if map then
            coinContainer = map:FindFirstChild("CoinContainer")
        end
    end)

    local searchRoot = coinContainer or Workspace

    for _, coin in ipairs(searchRoot:GetDescendants()) do
        if coin ~= currentCoin 
           and coin:IsA("BasePart") 
           and coin.Name == "Coin_Server"
           and coin:FindFirstChildWhichIsA("TouchTransmitter") 
           and not State.CoinBlacklist[coin] then

            local coinVisual = coin:FindFirstChild("CoinVisual")
            if coinVisual then
                local distance = (coin.Position - hrpPosition).Magnitude
                
                -- ✅ Новая монета должна быть ЗНАЧИТЕЛЬНО ближе
                if distance < (currentDistance - threshold) then
                    return coin, distance
                end
            end
        end
    end

    return nil
end

-- SmoothFlyToCoin() - Плавный полёт к монете
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
    
    -- ✅ Переменные для динамической проверки
    local lastCheckTime = tick()
    local checkInterval = 0.3 -- Проверяем каждые 0.3 секунды
    
    while tick() - startTime < duration do
        if not State.AutoFarmEnabled then break end
        
        -- ✅ ПРОВЕРКА: существует ли монета
        if not coin or not coin.Parent then
            return false, nil
        end
        
        local coinVisual = coin:FindFirstChild("CoinVisual")
        if not coinVisual then
            return false, nil
        end
        
        -- ✅ ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: монета всё ещё собираемая
        local touchTransmitter = coin:FindFirstChildWhichIsA("TouchTransmitter")
        if not touchTransmitter then
            return false, nil
        end
        
        local character = LocalPlayer.Character
        if not character or not humanoidRootPart.Parent then break end
        
        -- ✅ ДИНАМИЧЕСКАЯ ПРОВЕРКА НА БОЛЕЕ БЛИЗКУЮ МОНЕТУ
        local currentTime = tick()
        if currentTime - lastCheckTime >= checkInterval then
            lastCheckTime = currentTime
            
            local currentDistance = (humanoidRootPart.Position - coin.Position).Magnitude
            local betterCoin, betterDistance = FindBetterCoin(coin, currentDistance, 10)
            
            if betterCoin then
                -- ✅ Найдена более близкая монета - прерываем текущий полёт
                return "switch", betterCoin
            end
        end
        
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
        
        -- ✅ ИСПРАВЛЕНО: Выключаем невидимость на 85% полёта (перед firetouchinterest)
        if alpha >= 0.90 and not collectionAttempted then
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
    
    if State.UndergroundMode then
        local finalCFrame = CFrame.new(humanoidRootPart.Position) * CFrame.Angles(math.rad(90), 0, 0)
        humanoidRootPart.CFrame = finalCFrame
    end
    
    return true, nil
end

local shootMurderer
local InstantKillAll
local knifeThrow
local ToggleGodMode 

local function CountPlayersWithKnife()
    local count = 0
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            local backpack = player:FindFirstChild("Backpack")
            local character = player.Character
            
            -- Проверяем нож в руках или в инвентаре
            local knifeInHand = character:FindFirstChild("Knife")
            local knifeInBackpack = backpack and backpack:FindFirstChild("Knife")
            
            if knifeInHand or knifeInBackpack then
                count = count + 1
            end
        end
    end
    
    return count
end
--[[
local function DiagnoseAutoFarm()
    print("=== AUTO FARM DIAGNOSTICS ===")
    
    -- Проверка 1: Карта и контейнер
    local map = getMap()
    print("✓ Map found:", map ~= nil)
    if map then
        local container = map:FindFirstChild("CoinContainer")
        print("✓ CoinContainer:", container ~= nil)
        if container then
            local coins = 0
            for _, child in ipairs(container:GetChildren()) do
                if child.Name == "Coin_Server" then coins = coins + 1 end
            end
            print("✓ Coins in container:", coins)
        end
    end
    
    -- Проверка 2: GUI и валюта
    pcall(function()
        local container = LocalPlayer.PlayerGui.MainGUI.Game.CoinBags.Container
        print("\n=== ACTIVE CURRENCY ===")
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Frame") and child.Visible then
                local coinsLabel = child:FindFirstChild("CurrencyFrame", true)
                if coinsLabel then
                    coinsLabel = coinsLabel:FindFirstChild("Icon", true)
                    if coinsLabel then
                        coinsLabel = coinsLabel:FindFirstChild("Coins")
                        if coinsLabel then
                            print("✓ Active:", child.Name, "=", coinsLabel.Text)
                        end
                    end
                end
            end
        end
    end)
    
    -- Проверка 3: Функции
    print("\n=== FUNCTION TEST ===")
    print("✓ GetCollectedCoinsCount():", GetCollectedCoinsCount())
    print("✓ FindNearestCoin():", FindNearestCoin())
    print("✓ CoinBlacklist size:", #State.CoinBlacklist)
    
    print("=== END DIAGNOSTICS ===")
end
--]]

-- StartAutoFarm() - Запуск авто фарма (с интеграцией XP Farm)
local function StartAutoFarm()
    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end
    
    if not State.AutoFarmEnabled then return end
    
    State.CoinBlacklist = {}
    
    State.CoinFarmThread = task.spawn(function()
        local allowFly = false
        
        if State.GodModeWithAutoFarm and not State.GodModeEnabled then
            pcall(function()
                ToggleGodMode()
            end)
        end

        if State.AutoFarmEnabled and not State.IsInvisible then
            pcall(function()
                ToggleInvisibility()
            end)
        end
                
        local noCoinsAttempts = 0
        local maxNoCoinsAttempts = 4
        local lastTeleportTime = 0
        
        while State.AutoFarmEnabled do
            --print("[DEBUG] ═══ Цикл автофарма ═══")
            
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
            
            local murdererExists = getMurderForAutoFarm() ~= nil
            --print("[DEBUG] Мурдерер существует:", murdererExists)
            
            if not murdererExists then
                --print("[DEBUG] ⏳ Нет мурдерера, жду раунд...")
                State.CoinBlacklist = {}
                noCoinsAttempts = 0
                allowFly = false
                pcall(function()
                    UnfloatCharacter()
                end)
                if State.AutoFarmEnabled and not State.IsInvisible then
                    pcall(function()
                        ToggleInvisibility()
                    end)
                end
                task.wait(2)
                continue
            end
            
            local currentCoins = GetCollectedCoinsCount()
            
            if currentCoins >= 40 then
                noCoinsAttempts = maxNoCoinsAttempts
            else
                local coin = FindNearestCoin()
                --print("[DEBUG] 🪙 Ближайшая монета:", coin)

                if not coin then
                    noCoinsAttempts = noCoinsAttempts + 1
                    --print("[DEBUG] ⚠️ Монета не найдена, попытка", noCoinsAttempts, "/", maxNoCoinsAttempts)
                    --DiagnoseAutoFarm()
                    
                    if noCoinsAttempts < maxNoCoinsAttempts then
                        task.wait(0.3)
                    end
                else
                    noCoinsAttempts = 0

                    CreateCoinTracer(character, coin)
                    
                    pcall(function()
                        if not allowFly then
                            local currentTime = tick()
                            local timeSinceLastTP = currentTime - lastTeleportTime
                            
                            if timeSinceLastTP < State.CoinFarmDelay and lastTeleportTime > 0 then
                                local waitTime = State.CoinFarmDelay - timeSinceLastTP
                                task.wait(waitTime)
                            end

                            if State.AutoFarmEnabled and State.IsInvisible then
                                pcall(function()
                                    ToggleInvisibility()
                                end)
                            end
                            local targetCFrame = coin.CFrame + Vector3.new(0, 2, 0)
                            
                            if targetCFrame.Position.Y > -500 and targetCFrame.Position.Y < 10000 then
                                humanoidRootPart.CFrame = targetCFrame
                                lastTeleportTime = tick()
                                
                                if firetouchinterest then
                                    firetouchinterest(humanoidRootPart, coin, 0)
                                    task.wait(0.05)
                                    firetouchinterest(humanoidRootPart, coin, 1)
                                end

                                
                                task.wait(0.2)
                                coinLabelCache = nil
                                local coinsAfter = GetCollectedCoinsCount()
                                
                                RemoveCoinTracer()
                                AddCoinToBlacklist(coin)
                                allowFly = true
                            end
                        else
                            EnableNoClip()                           
                            -- ✅ ОБРАБОТКА ДИНАМИЧЕСКОЙ СМЕНЫ ЦЕЛИ
                            local currentTargetCoin = coin
                            local maxRedirects = 5
                            local redirectCount = 0
                            
                            while currentTargetCoin and redirectCount < maxRedirects do
                                local result, newTarget = SmoothFlyToCoin(currentTargetCoin, humanoidRootPart, State.CoinFarmFlySpeed)
                                
                                if result == "switch" and newTarget then
                                    -- ✅ ПРОСТО ПЕРЕКЛЮЧАЕМСЯ, БЕЗ BLACKLIST!
                                    RemoveCoinTracer()
                                    CreateCoinTracer(character, newTarget)
                                    
                                    currentTargetCoin = newTarget
                                    redirectCount = redirectCount + 1
                                    
                                elseif result == true then
                                    -- ✅ Успешно долетели до цели
                                    break
                                else
                                    -- ❌ Монета исчезла (кто-то собрал)
                                    break
                                end
                            end
                            
                            coinLabelCache = nil
                            RemoveCoinTracer()
                            
                            if currentTargetCoin then
                                AddCoinToBlacklist(currentTargetCoin)
                            end
                        end
                    end)
                end
            end
            
            -- ═══════════════════════════════════════════════════════════
            -- ГЛАВНАЯ ЛОГИКА: Snowball Fight VS Обычный режим
            -- ═══════════════════════════════════════════════════════════
            
            if noCoinsAttempts >= maxNoCoinsAttempts then
                pcall(function()
                    DisableNoClip()
                end)
                
                local playersWithKnife = CountPlayersWithKnife()
                local isSnowballMode = playersWithKnife > 1
                
                -- ═══════════════════════════════════════════════════════════
                -- SNOWBALL FIGHT РЕЖИМ
                -- ═══════════════════════════════════════════════════════════
                if isSnowballMode then
                    
                    if State.XPFarmEnabled then
                        -- XP Farm включен: используем knifeThrow
                        --[[
                        if not State.spawnAtPlayer then
                            State.spawnAtPlayer = true
                        end
                        
                        local throwAttempts = 0
                        local maxThrowAttempts = 1
                        local throwDelay = 3
                        
                        while getMurder() ~= nil and State.AutoFarmEnabled and State.XPFarmEnabled and throwAttempts < maxThrowAttempts do
                            pcall(function()
                                knifeThrow(true)
                            end)
                            
                            throwAttempts = throwAttempts + 1
                            task.wait(throwDelay)
                        end
                        --]]
                        -- Fallback: InstantKillAll
                        if getMurderForAutoFarm() ~= nil and State.AutoFarmEnabled and State.XPFarmEnabled then
                            pcall(function()
                                InstantKillAll()
                            end)
                        end
                        
                        -- Ждём конца раунда
                        repeat
                            task.wait(1)
                        until getMurderForAutoFarm() == nil or not State.AutoFarmEnabled
                        
                    else
                        -- XP Farm выключен: просто ресет
                        pcall(function()
                            UnfloatCharacter()
                        end)
                        
                        if State.GodModeWithAutoFarm and State.GodModeEnabled then
                            pcall(function()
                                ToggleGodMode()
                            end)
                        end
                        
                        ResetCharacter()
                        State.CoinBlacklist = {}
                        noCoinsAttempts = 0
                        allowFly = false
                        
                        task.wait(2)
                        
                        if State.GodModeWithAutoFarm then
                            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                            local humanoid = character:WaitForChild("Humanoid", 5)
                            
                            if humanoid then
                                task.wait(1)
                                
                                if not State.GodModeEnabled then
                                    pcall(function()
                                        ToggleGodMode()
                                    end)
                                end
                                task.wait(0.3)
                            end
                        end          
                        -- Ждём конца раунда
                        repeat
                            task.wait(1)
                        until getMurderForAutoFarm() == nil or not State.AutoFarmEnabled
                    end
                    
                    -- Общий cleanup после Snowball
                    if not State.AutoFarmEnabled then
                        break
                    end
                    
                    pcall(function()
                        UnfloatCharacter()
                    end)
                    
                    CleanupCoinBlacklist()
                    task.wait(5)
                    
                    -- Ждём нового раунда
                    repeat
                        if not State.IsInvisible then
                            pcall(function()
                                ToggleInvisibility()
                            end)
                        end
                        task.wait(1)
                    until getMurderForAutoFarm() ~= nil or not State.AutoFarmEnabled
                    
                    if not State.AutoFarmEnabled then
                        break
                    end
                    
                    State.CoinBlacklist = {}
                    noCoinsAttempts = 0
                    allowFly = false

                elseif State.XPFarmEnabled then
                    --print("[Auto Farm] ⏳ XP Farm включен, передаю управление...")
                    
                    currentCoins = GetCollectedCoinsCount()
                    --print("[Auto Farm] 💰 Собрано монет: " .. currentCoins .. "/50")
                    
                    if currentCoins >= 40 then
                        character = LocalPlayer.Character
                        if character then
                            humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                            
                            if humanoidRootPart then
                                local safeSpot = FindSafeAFKSpot()
                                if safeSpot then
                                    humanoidRootPart.CFrame = safeSpot + Vector3.new(0, 5, 0)
                                    --print("[XP Farm] 📍 Телепортировался в безопасное место")
                                    
                                    task.wait(0.5)
                                    local floatSuccess = FloatCharacter()
                                    if floatSuccess then
                                        --print("[XP Farm] 🎈 Закрепление активировано")
                                    end
                                    
                                    task.wait(0.5)
                                end
                                
                                if State.XPFarmEnabled then
                                    local murderer = getMurderForAutoFarm()
                                    local sheriff = getSheriffForAutoFarm()
                                    
                                    if murderer == LocalPlayer then
                                        --print("[XP Farm] 🔪 Мы мурдерер! Активирую knifeThrow...")
                                        --[[
                                        -- ✅ Включаем spawnAtPlayer если был выключен
                                        if not State.spawnAtPlayer then
                                            State.spawnAtPlayer = true
                                            --print("[XP Farm] ✅ spawnAtPlayer включен")
                                        end
                                        
                                        -- ✅ Счётчик попыток knifeThrow
                                        local throwAttempts = 0
                                        local maxThrowAttempts = 1
                                        local throwDelay = 3
                                        
                                        -- ✅ Цикл knifeThrow с ограничением попыток
                                        while getMurder() ~= nil and State.AutoFarmEnabled and State.XPFarmEnabled and throwAttempts < maxThrowAttempts do
                                            local success, error = pcall(function()
                                                knifeThrow(true)  -- true = silent mode
                                            end)
                                            
                                            throwAttempts = throwAttempts + 1
                                            
                                            if success then
                                                --print("[XP Farm] 🔪 Нож брошен (" .. throwAttempts .. "/" .. maxThrowAttempts .. ")")
                                            else
                                                --print("[XP Farm] ❌ Ошибка броска ножа: " .. tostring(error))
                                            end
                                            
                                            task.wait(throwDelay)
                                        end
                                        --]]
                                        -- ✅ Fallback: если после 1 попыток раунд не завершился
                                        if getMurderForAutoFarm() ~= nil and State.AutoFarmEnabled and State.XPFarmEnabled then
                                            --print("[XP Farm] ⚠️ knifeThrow не сработал за 10 попыток! Использую InstantKillAll...")
                                            
                                            local success, error = pcall(function()
                                                InstantKillAll()
                                            end)
                                            
                                            if success then
                                                --print("[XP Farm] ✅ InstantKillAll выполнен успешно!")
                                            else
                                                --print("[XP Farm] ❌ InstantKillAll ошибка: " .. tostring(error))
                                            end
                                        else
                                            --print("[XP Farm] ✅ Раунд завершён через knifeThrow или XP Farm отключен")
                                        end
                                                                    
                                    elseif sheriff == LocalPlayer then
                                            --print("[XP Farm] 🔫 Мы шериф, стреляем в мурдерера...")
                                            
                                            local shootAttempts = 0
                                            local maxShootAttempts = 30

                                            while getMurderForAutoFarm() ~= nil and State.AutoFarmEnabled and State.XPFarmEnabled and shootAttempts < maxShootAttempts do
                                                character = LocalPlayer.Character
                                                if not character then 
                                                    --print("[XP Farm] ⚠️ Персонаж исчез, прекращаю стрельбу")
                                                    break 
                                                end
                                                
                                                local murdererPlayer = getMurderForAutoFarm()
                                                if not murdererPlayer then 
                                                    --print("[XP Farm] ✅ Раунд завершён! Мурдерер мёртв.")
                                                    break 
                                                end
                                                
                                                -- ✅ Проверяем существование персонажа мурдерера
                                                local murdererChar = murdererPlayer.Character
                                                if not murdererChar then 
                                                    --print("[XP Farm] ⚠️ У мурдерера нет персонажа, жду...")
                                                    task.wait(0.5)
                                                    continue 
                                                end
                                                
                                                -- ✅ Стреляем только если кулдаун готов
                                                if State.CanShootMurderer then
                                                    shootAttempts = shootAttempts + 1
                                                    
                                                    pcall(function()
                                                        shootMurderer(true) -- ✅ тихий режим, без спама уведомлениями
                                                    end)
                                                    
                                                    --print("[XP Farm] 🎯 Выстрел #" .. shootAttempts .. " произведён")
                                                    task.wait(State.ShootCooldown + 0.1) -- ✅ учитываем реальный кулдаун с запасом
                                                else
                                                    -- Кулдаун ещё идёт – немного ждём
                                                    task.wait(0.5)
                                                end
                                            end

                                            -- ✅ Проверяем причину выхода из цикла
                                            if getMurderForAutoFarm() == nil then
                                                --print("[XP Farm] ✅ Мурдерер успешно убит! Раунд завершён.")
                                            elseif shootAttempts >= maxShootAttempts then
                                                --print("[XP Farm] ⚠️ Достигнут лимит выстрелов (" .. maxShootAttempts .. "), прекращаю стрельбу")
                                            elseif not State.XPFarmEnabled then
                                                --print("[XP Farm] ⚠️ XP Farm был отключен во время стрельбы")
                                            elseif not State.AutoFarmEnabled then
                                                --print("[XP Farm] ⚠️ Auto Farm был отключен во время стрельбы")
                                            end
                                    else
                                        --print("[XP Farm] 👤 Инносент | Флинг мурдерера")
                                        
                                        -- ✅ Сразу после закрепления - первый флинг
                                        pcall(function()
                                            FlingMurderer()
                                        end)
                                        --print("[XP Farm] 💫 Первый флинг выполнен")
                                        task.wait(1)
                                        
                                        local flingAttempts = 1  -- Уже выполнили 1 флинг
                                        local maxFlingAttempts = 10
                                        
                                        while getMurderForAutoFarm() ~= nil and State.AutoFarmEnabled and State.XPFarmEnabled and flingAttempts < maxFlingAttempts do
                                            local murdererPlayer = getMurderForAutoFarm()
                                            if not murdererPlayer then break end
                                            
                                            local murdererChar = murdererPlayer.Character
                                            if not murdererChar then
                                                task.wait(0.5)
                                                continue
                                            end
                                            
                                            local murdererHRP = murdererChar:FindFirstChild("HumanoidRootPart")
                                            if murdererHRP then
                                                local velocity = murdererHRP.AssemblyLinearVelocity.Magnitude
                                                
                                                if velocity > 500 then
                                                    --print("[XP Farm] ✅ Мурдерер уже сфлингован (velocity: " .. math.floor(velocity) .. ")!")
                                                    break
                                                elseif velocity > 100 then
                                                    --print("[XP Farm] ⏭️ Мурдерер летит (velocity: " .. math.floor(velocity) .. "), пропускаю...")
                                                    task.wait(1)
                                                    continue
                                                end
                                            end
                                            
                                            pcall(function()
                                                FlingMurderer()
                                            end)
                                            
                                            flingAttempts = flingAttempts + 1
                                            --print("[XP Farm] 💫 Флинг #" .. flingAttempts)
                                            
                                            task.wait(3)
                                            
                                            if getMurderForAutoFarm() == nil then
                                                --print("[XP Farm] ✅ Мурдерер был сфлингован!")
                                                break
                                            end
                                        end
                                        
                                        if not State.XPFarmEnabled then
                                            --print("[XP Farm] ⚠️ XP Farm был отключен во время флинга")
                                        end
                                    end
                                else
                                    --print("[XP Farm] ⚠️ XP Farm был отключен, пропускаю действия")
                                end
                            end
                        end
                    end
                    repeat
                        task.wait(1)
                    until getMurderForAutoFarm() == nil or not State.AutoFarmEnabled
                    
                    if not State.AutoFarmEnabled then
                        break
                    end
                    
                    pcall(function()
                        UnfloatCharacter()
                    end)
                    
                    CleanupCoinBlacklist()
                    task.wait(5)
                    
                    if getMurderForAutoFarm() ~= nil then
                        State.CoinBlacklist = {}
                        noCoinsAttempts = 0
                        continue
                    end
                    
                    if State.GodModeWithAutoFarm and State.GodModeEnabled then
                        pcall(function()
                            ToggleGodMode()
                        end)
                    end

                    ResetCharacter()
                    State.CoinBlacklist = {}
                    noCoinsAttempts = 0

                    task.wait(2)

                    if State.GodModeWithAutoFarm then
                        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                        local humanoid = character:WaitForChild("Humanoid", 5)
                        
                        if humanoid then
                            task.wait(1)
                            
                            if not State.GodModeEnabled then
                                pcall(function()
                                    ToggleGodMode()
                                end)
                            end
                        end
                    end
                    
                    repeat
                        if not State.IsInvisible then
                            pcall(function()
                                ToggleInvisibility()
                            end)
                        end
                        task.wait(1)
                    until getMurderForAutoFarm() ~= nil or not State.AutoFarmEnabled
                    
                    if not State.AutoFarmEnabled then
                        break
                    end
                    
                    State.CoinBlacklist = {}
                    noCoinsAttempts = 0
                    allowFly = false

                else
                    --print("[Auto Farm] 🔄 XP Farm выключен - делаю быстрый ресет без ожидания конца раунда...")
                    CleanupCoinBlacklist()
                    pcall(function()
                        UnfloatCharacter()
                    end)

                    -- ✅ Выключаем годмод перед ресетом
                    if State.GodModeWithAutoFarm and State.GodModeEnabled then
                        pcall(function()
                            ToggleGodMode()  -- Выключаем только если был включен автофармом
                        end)
                        --print("[Auto Farm] 🛡️ GodMode автоматически выключен")
                    end
                    
                    ResetCharacter()
                    State.CoinBlacklist = {}
                    noCoinsAttempts = 0
                    allowFly = false

                    task.wait(2)

                    -- ✅ ИСПРАВЛЕННЫЙ КОД: Включаем годмод после респавна
                    if State.GodModeWithAutoFarm then  -- ✅ БЕЗ проверки State.GodModeEnabled!
                        -- Ждём появления персонажа
                        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                        local humanoid = character:WaitForChild("Humanoid", 5)

                        if humanoid then
                            task.wait(1)  -- Даём серверу инициализировать персонажа

                            if not State.GodModeEnabled then
                                pcall(function()
                                    ToggleGodMode()
                                end)
                                --print("[Auto Farm] 🛡️ GodMode повторно включен после респавна")
                            end
                        end
                    end

                    --print("[Auto Farm] ⏳ Жду конца текущего раунда...")
                    repeat
                        task.wait(1)
                    until getMurderForAutoFarm() == nil or not State.AutoFarmEnabled

                    if not State.AutoFarmEnabled then
                        --print("[Auto Farm] ⚠️ Автофарм был выключен во время ожидания")
                        break
                    end

                    --print("[Auto Farm] ⏳ Раунд закончился, жду начала нового раунда...")
                    
                    repeat
                        if not State.IsInvisible then
                            pcall(function()
                                ToggleInvisibility()
                            end)
                        end
                        task.wait(1)
                    until getMurderForAutoFarm() ~= nil or not State.AutoFarmEnabled

                    if not State.AutoFarmEnabled then
                        --print("[Auto Farm] ⚠️ Автофарм был выключен во время ожидания нового раунда")
                        break
                    end

                    --print("[Auto Farm] ✅ Новый раунд начался! Сбрасываю счётчики и продолжаю фарм...")
                    State.CoinBlacklist = {}
                    noCoinsAttempts = 0
                end
            end
        end
        
        State.CoinFarmThread = nil
        --print("[Auto Farm] 🛑 Остановлен")
    end)
end

-- ✅ ОБНОВЛЁННАЯ StopAutoFarm с правильным cleanup
local function StopAutoFarm()
    RemoveCoinTracer()
    State.AutoFarmEnabled = false

    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end

    pcall(UnfloatCharacter)
    pcall(DisableNoClip)
    
    -- ✅ ДОБАВЛЕНО: очистка кэша
    coinLabelCache = nil
    lastCacheTime = 0
    
    State.CoinBlacklist = {}
    State.spawnAtPlayer = spawnAtPlayerOriginalState

    --print("[Auto Farm] 🛑 Остановлен")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- XP FARM SYSTEM
-- ══════════════════════════════════════════════════════════════════════════════

-- Главная функция XP фарма (оптимизированная версия)
local function StartXPFarm()
    -- Просто активируем флаг, Auto Farm сделает всё сам
    State.XPFarmEnabled = true
    --print("[XP Farm] ✅ Включен (интегрирован с Auto Farm)")
end

local function StopXPFarm()
    State.XPFarmEnabled = false
    pcall(function()
        UnfloatCharacter()
    end)
    --print("[XP Farm] ❌ Выключен")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 12: GODMODE SYSTEM (СТРОКИ 1601-1800)
-- ══════════════════════════════════════════════════════════════════════════════
local ApplyGodMode, SetupHealthProtection, SetupDamageBlocker

-- ApplyGodMode() - Установка Health = math.huge
ApplyGodMode = function()
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

-- SetupHealthProtection() - Защита Health/StateChanged
SetupHealthProtection = function()
    if State.healthConnection then
        State.healthConnection:Disconnect()
    end
    
    if State.stateConnection then
        State.stateConnection:Disconnect()
    end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    State.stateConnection = humanoid.StateChanged:Connect(function(oldState, newState)
        if State.GodModeEnabled then
            if newState == Enum.HumanoidStateType.Dead then
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
                humanoid.Health = math.huge
            end
        end
    end)
    table.insert(State.Connections, State.stateConnection)
    
    State.healthConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        if State.GodModeEnabled and humanoid.Health < math.huge then
            humanoid.Health = math.huge
        end
    end)
    
    table.insert(State.Connections, State.healthConnection)
end
-- SetupDamageBlocker() - Блокировка Ragdoll/CreatorTag
SetupDamageBlocker = function()
    if State.damageBlockerConnection then
        State.damageBlockerConnection:Disconnect()
    end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    State.damageBlockerConnection = character.ChildAdded:Connect(function(child)
        if State.GodModeEnabled then
            if child.Name == "Ragdoll" or child.Name == "CreatorTag" or 
               (child:IsA("ObjectValue") and child.Name == "creator") then
                task.spawn(function()
                    child:Destroy()
                end)
            end
        end
    end)
    
    table.insert(State.Connections, State.damageBlockerConnection)
end

-- ToggleGodMode() - Включение/отключение
ToggleGodMode = function()
    State.GodModeEnabled = not State.GodModeEnabled
    if State.GodModeEnabled then
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(220,220,220)\">GodMode</font> <font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Text)
        end
        
        ApplyGodMode()
        SetupHealthProtection()
        SetupDamageBlocker()
        
        -- HP monitoring
        local godModeConnection = RunService.Heartbeat:Connect(function()
            if State.GodModeEnabled and LocalPlayer.Character then
                local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    if humanoid.Health ~= math.huge then
                        humanoid.Health = math.huge
                    end
                    local state = humanoid:GetState()
                    if state == Enum.HumanoidStateType.Dead then
                        humanoid:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
            end
        end)
        table.insert(State.GodModeConnections, godModeConnection)  -- ✅ В ОТДЕЛЬНОЕ хранилище
        
        local respawnConnection = LocalPlayer.CharacterAdded:Connect(function(character)
            if State.GodModeEnabled then
                task.wait(0.5)
                ApplyGodMode()
                SetupHealthProtection()
                SetupDamageBlocker()
            end
        end)
        table.insert(State.GodModeConnections, respawnConnection)
    else
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(220,220,220)\">GodMode</font> <font color=\"rgb(255, 85, 85)\">OFF</font>",CONFIG.Colors.Text)
        end
        
        -- Отключаем локальные connections
        if State.healthConnection then
            State.healthConnection:Disconnect()
            State.healthConnection = nil
        end
        if State.stateConnection then
            State.stateConnection:Disconnect()
            State.stateConnection = nil
        end
        if State.damageBlockerConnection then
            State.damageBlockerConnection:Disconnect()
            State.damageBlockerConnection = nil
        end
        
        -- ✅ Очищаем ТОЛЬКО GodMode connections
        for _, connection in ipairs(State.GodModeConnections) do
            if connection and connection.Connected then
                connection:Disconnect()
            end
        end
        State.GodModeConnections = {}
        
        -- Восстанавливаем персонажа
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

----------------------------------------------------------------
-- PLAYER NICKNAMES ESP
----------------------------------------------------------------

local nicknamesConnection = nil
local playerConnections = {}

local function CreatePlayerNicknameESP(player)
    if not player or player == LocalPlayer then return end
    
    -- ✅ Дополнительные проверки
    if not player.Parent then return end
    if not player:IsDescendantOf(game) then return end
    
    local character = player.Character
    if not character or not character.Parent then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp.Parent then return end
    
    -- Удаляем старый ESP если есть
    if State.PlayerNicknamesCache[player] then
        RemovePlayerNicknameESP(player)
    end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PlayerNicknameESP"
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 140, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = State.PlayerNicknamesESP
    billboard.Parent = hrp
    
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = player.Name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextStrokeTransparency = 0.6
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = billboard
    
    State.PlayerNicknamesCache[player] = {
        billboard = billboard
    }
end


local function RemovePlayerNicknameESP(player)
    if not player or not State.PlayerNicknamesCache[player] then return end
    
    local espData = State.PlayerNicknamesCache[player]
    
    pcall(function()
        if espData.billboard then
            espData.billboard:Destroy()
        end
    end)
    
    State.PlayerNicknamesCache[player] = nil
end

local function UpdatePlayerNicknamesVisibility()
    for player, espData in pairs(State.PlayerNicknamesCache) do
        if espData.billboard then
            espData.billboard.Enabled = State.PlayerNicknamesESP
        end
    end
end

local function SetupPlayerTracking(player)
    if player == LocalPlayer then return end
    if playerConnections[player] then return end
    
    playerConnections[player] = {}
    
    -- CharacterAdded
    playerConnections[player].charAdded = player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if State.PlayerNicknamesESP then
            CreatePlayerNicknameESP(player)
        end
    end)
    
    -- CharacterRemoving
    playerConnections[player].charRemoving = player.CharacterRemoving:Connect(function()
        RemovePlayerNicknameESP(player)
    end)
    
    -- Если у игрока уже есть персонаж
    if player.Character and State.PlayerNicknamesESP then
        CreatePlayerNicknameESP(player)
    end
end

local function RemovePlayerTracking(player)
    if playerConnections[player] then
        for _, conn in pairs(playerConnections[player]) do
            pcall(function() conn:Disconnect() end)
        end
        playerConnections[player] = nil
    end
    RemovePlayerNicknameESP(player)
end

local function SetupPlayerNicknamesTracking()
    if nicknamesConnection then
        nicknamesConnection:Disconnect()
        nicknamesConnection = nil
    end
    
    -- Очищаем старые подключения
    for player, _ in pairs(playerConnections) do
        RemovePlayerTracking(player)
    end
    
    -- Настраиваем отслеживание для существующих игроков
    for _, player in ipairs(Players:GetPlayers()) do
        SetupPlayerTracking(player)
    end
    
    -- Отслеживаем новых игроков
    TrackConnection(Players.PlayerAdded:Connect(function(player)
        SetupPlayerTracking(player)
    end))
    
    -- Отслеживаем выход игроков
    TrackConnection(Players.PlayerRemoving:Connect(function(player)
        RemovePlayerTracking(player)
    end))
    
    -- Heartbeat для обновления видимости
    nicknamesConnection = RunService.Heartbeat:Connect(function()
        pcall(function()
            for player, espData in pairs(State.PlayerNicknamesCache) do
                if espData.billboard then
                    espData.billboard.Enabled = State.PlayerNicknamesESP
                end
            end
        end)
    end)
    
    table.insert(State.Connections, nicknamesConnection)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 15: COMBAT FUNCTIONS (СТРОКИ 2351-2800)
-- ══════════════════════════════════════════════════════════════════════════════

-- PlayEmote() - Воспроизведение эмоций
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

knifeThrow = function(silent)
    local murderer = getMurder()
    if murderer ~= LocalPlayer then
        if not silent then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220,220,220)\">You're not murderer.</font>", CONFIG.Colors.Text)
        end
        return
    end

    -- ОПТИМИЗАЦИЯ: проверяем нож БЕЗ экипировки, если его нет
    local knife = LocalPlayer.Character:FindFirstChild("Knife")
    
    if not knife then
        -- Мгновенная экипировка БЕЗ task.wait()
        if LocalPlayer.Backpack:FindFirstChild("Knife") then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum then
                -- EquipTool работает мгновенно - задержка не нужна
                hum:EquipTool(LocalPlayer.Backpack:FindFirstChild("Knife"))
                -- Обновляем ссылку сразу
                knife = LocalPlayer.Character:FindFirstChild("Knife")
            end
        end
        
        -- Финальная проверка
        if not knife then
            if not silent then
                ShowNotification("<font color=\"rgb(220, 220, 220)\">You don't have the knife..?</font>", CONFIG.Colors.Text)
            end
            return
        end
    end

    if not LocalPlayer.Character:FindFirstChild("RightHand") then
        if not silent then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">No RightHand</font>", nil)
        end
        return
    end

    local mouse = LocalPlayer:GetMouse()
    local spawnPosition
    local targetPosition
    

    -- Обычный бросок
    spawnPosition = LocalPlayer.Character.RightHand.Position
    targetPosition = mouse.Hit.Position


    if not targetPosition then
        if not silent then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">No target position</font>", nil)
        end
        return
    end

    -- Аргументы для броска
    local argsThrowRemote = {
        [1] = CFrame.new(spawnPosition),
        [2] = CFrame.new(targetPosition)
    }

    -- МГНОВЕННАЯ ОТПРАВКА на сервер
    local success, err = pcall(function()
        LocalPlayer.Character.Knife.Events.KnifeThrown:FireServer(unpack(argsThrowRemote))
    end)

    if success then
        task.wait()  -- ✅ Ждем только при успехе
        
        if knife then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum then
                hum:UnequipTools()
            end
        end
    else
        -- ❌ Ошибка броска - нож остается экипированным
        if not silent then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">" .. tostring(err) .. "</font>", nil)
        end
    end
end

shootMurderer = function(forceMagic)
    -- Определяем режим: если forceMagic == true, используем Magic, иначе проверяем настройку
    local useMode = forceMagic and "Magic" or (State.ShootMurdererMode or "Magic")
    
    -- Проверка кулдауна
    if not State.CanShootMurderer then
        if not forceMagic then
            ShowNotification("<font color=\"rgb(255, 165, 0)\">Wait </font><font color=\"rgb(220,220,220)\">Gun is on cooldown</font>", CONFIG.Colors.Text)
        end
        return
    end
    
    -- МГНОВЕННАЯ ЭКИПИРОВКА ПИСТОЛЕТА (С фиксом репликации)
    local gun = LocalPlayer.Character:FindFirstChild("Gun")
    
    if not gun then
        if LocalPlayer.Backpack:FindFirstChild("Gun") then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum then
                hum:EquipTool(LocalPlayer.Backpack:FindFirstChild("Gun"))
                -- ВАЖНО: Микро-задержка, чтобы сервер успел понять, что оружие в руках
                task.wait(0.03)
                gun = LocalPlayer.Character:FindFirstChild("Gun")
            end
        end
        
        if not gun then
            if not forceMagic then
                ShowNotification("<font color=\"rgb(220, 220, 220)\">You don't have the gun..?</font>", CONFIG.Colors.Text)
            end
            return
        end
    end
    
    -- Проверка роли (ПОСЛЕ экипировки)
    local sheriff = getSheriff()
    if sheriff ~= LocalPlayer then
        if not forceMagic then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220,220,220)\">You're not sheriff/hero.</font>", CONFIG.Colors.Text)
        end
        return
    end
    
    -- Поиск убийцы
    local murderer = getMurder()
    if not murderer or not murderer.Character then
        if not forceMagic then
            ShowNotification("<font color=\"rgb(255, 165, 0)\">Warning </font><font color=\"rgb(220,220,220)\">Murderer not found</font>", CONFIG.Colors.Text)
        end
        return
    end
    
    if not LocalPlayer.Character:FindFirstChild("RightHand") then
        if not forceMagic then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">No RightHand</font>", nil)
        end
        return
    end
    
    local murdererHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
    
    if not murdererHRP then
        if not forceMagic then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">Murderer has no HRP</font>", nil)
        end
        return
    end
    
    local argsShootRemote
    
    if useMode == "Magic" then
        -- === MAGIC MODE: Телепортация пули (текущая логика) ===
        local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
        local pingValue = tonumber(ping:match("%d+")) or 50
        local predictionTime = (pingValue / 1000) + 0.05
        
        local enemyVelocity = murdererHRP.AssemblyLinearVelocity
        local predictedPos = murdererHRP.Position + (enemyVelocity * predictionTime)
        
        local spawnPosition, targetPosition

        if enemyVelocity.Magnitude > 2 then
            -- Цель бежит: Спавним пулю СПЕРЕДИ (5 studs) и стреляем В НЕГО
            local moveDir = enemyVelocity.Unit
            spawnPosition = predictedPos + (moveDir * 5)
            targetPosition = predictedPos
        else
            -- Цель стоит: Спавним СЗАДИ (3 studs) используя LookVector
            local backDir = -murdererHRP.CFrame.LookVector
            spawnPosition = predictedPos + (backDir * 3)
            targetPosition = predictedPos
        end
        
        argsShootRemote = {
            [1] = CFrame.lookAt(spawnPosition, targetPosition),
            [2] = CFrame.new(targetPosition)
        }
    else
        -- === SILENT MODE: Стрельба от дула пистолета ===
        local rightHand = LocalPlayer.Character:FindFirstChild("RightHand")
        local gunHandle = gun:FindFirstChild("Handle") or gun:FindFirstChild("GunBarrel")
        
        if not rightHand then
            if not forceMagic then
                ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">No RightHand</font>", nil)
            end
            return
        end
        
        -- 1. ТОЧНАЯ ПОЗИЦИЯ ДУЛА
        local muzzleCFrame
        if gunHandle then
            muzzleCFrame = gunHandle.CFrame
        else
            muzzleCFrame = rightHand.CFrame * CFrame.new(0, 0, -2)
        end
        
        local muzzlePosition = muzzleCFrame.Position
        
        -- 2. ПРЕДИКЦИЯ (ИДЕНТИЧНА MAGIC MODE)
        local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
        local pingValue = tonumber(ping:match("%d+")) or 50
        local predictionTime = (pingValue / 1000) + 0.05
        
        local enemyVelocity = murdererHRP.AssemblyLinearVelocity
        local predictedPos = murdererHRP.Position + (enemyVelocity * predictionTime)
        
        -- 3. ФОРМИРОВАНИЕ CFrame (стреляем от дула в предсказанную позицию)
        local shootFromCFrame = CFrame.lookAt(muzzlePosition, predictedPos)
        local shootToCFrame = CFrame.new(predictedPos)
        
        argsShootRemote = {
            [1] = shootFromCFrame,
            [2] = shootToCFrame
        }
    end

    
    -- АКТИВИРУЕМ КУЛДАУН
    State.CanShootMurderer = false
    
    -- МГНОВЕННАЯ ОТПРАВКА на сервер
    local success, err = pcall(function()
        -- Оптимизированный поиск ремута
        local remote = gun:FindFirstChild("Events") and gun.Events:FindFirstChild("Shoot")
            or gun:FindFirstChild("KnifeServer") and gun.KnifeServer:FindFirstChild("ShootGun")
            
        if not remote then
            -- Fallback
            for _, child in pairs(gun:GetDescendants()) do
                if child:IsA("RemoteEvent") and (child.Name:lower():find("shoot") or child.Name:lower():find("fire")) then
                    remote = child
                    break
                end
            end
        end
        
        if remote then
            remote:FireServer(unpack(argsShootRemote))
        else
            error("Remote not found")
        end
    end)
    
    if success then
        if not forceMagic then
            local modeText = useMode == "Magic" and "Magic" or "Silent"
            ShowNotification("<font color=\"rgb(168,228,160)\">Shot fired! </font><font color=\"rgb(220,220,220)\">[" .. modeText .. "] Cooldown: " .. State.ShootCooldown .. "s</font>", CONFIG.Colors.Text)
        end
        
        -- ВОССТАНОВЛЕНИЕ КУЛДАУНА
        task.delay(State.ShootCooldown, function()
            State.CanShootMurderer = true
            if not forceMagic then
                ShowNotification("<font color=\"rgb(85, 255, 255)\">Ready </font><font color=\"rgb(220,220,220)\">You can shoot again</font>", CONFIG.Colors.Text)
            end
        end)
    else
        -- Если ошибка - сбрасываем кулдаун
        State.CanShootMurderer = true
        if not forceMagic then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">" .. tostring(err) .. "</font>", nil)
        end
    end
end

-- pickupGun() - Подбор пистолета
local function pickupGun(silent)
    local gun = Workspace:FindFirstChild("GunDrop", true)
    
    if not gun then
        if not silent and State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">No gun on map</font>", CONFIG.Colors.Text)
        end
        return false
    end
    
    local character = LocalPlayer.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    -- ✅ ЗАЩИТА: проверяем что gun существует и имеет Parent
    if not gun or not gun.Parent then return false end
    
    -- Используем firetouchinterest
    pcall(function()
        firetouchinterest(hrp, gun, 0)
        task.wait(0.1)
        firetouchinterest(hrp, gun, 1)
    end)
    
    if not silent and State.NotificationsEnabled then
        ShowNotification("<font color=\"rgb(220, 220, 220)\">Gun: Picked up</font>", CONFIG.Colors.Text)
    end
    
    return true
end

local function EnableInstantPickup()
    if State.InstantPickupThread then
        task.cancel(State.InstantPickupThread)
        State.InstantPickupThread = nil
    end
    
    State.InstantPickupEnabled = true
    
    -- ✅ ЗАЩИТА: проверяем SetupGunTracking перед вызовом
    if not State.currentMapConnection then
        pcall(function()
            SetupGunTracking()
        end)
    end
    
    local lastAttemptedGun = nil
    
    State.InstantPickupThread = task.spawn(function()
        while State.InstantPickupEnabled do
            local murderer = getMurder()
            
            if not murderer then
                task.wait(0.5)
                lastAttemptedGun = nil
                continue
            end
            
            if murderer == LocalPlayer then
                task.wait(1)
                continue
            end
            
            local gun = State.CurrentGunDrop
            
            -- ✅ ЗАЩИТА: проверяем существование gun и его Parent
            if gun and gun.Parent and gun ~= lastAttemptedGun then
    
                local sheriff = getSheriff()
                if sheriff == LocalPlayer then
                    lastAttemptedGun = gun
                    continue
                end
                
                if LocalPlayer.Character:FindFirstChild("Gun") or 
                   LocalPlayer.Backpack:FindFirstChild("Gun") then
                    lastAttemptedGun = gun
                    continue
                end
                
                local pickupSuccess = false
                
                for attempt = 1, 5 do
                    -- ✅ ЗАЩИТА: проверяем gun перед каждой попыткой
                    if not gun or not gun.Parent then
                        break
                    end
                    
                    pickupGun(true)
                    task.wait(0.15)
                    
                    if LocalPlayer.Character:FindFirstChild("Gun") or 
                       LocalPlayer.Backpack:FindFirstChild("Gun") then
                        pickupSuccess = true
                        
                        if State.NotificationsEnabled then
                            task.spawn(function()
                                ShowNotification(
                                    "<font color=\"rgb(168,228,160)\">Gun: Instant Pickup ✓</font>",
                                    CONFIG.Colors.Text
                                )
                            end)
                            task.spawn(function()
                                updateRoleAvatars()
                            end)
                        end
                        break
                    end
                    
                    if State.CurrentGunDrop ~= gun or not State.CurrentGunDrop then
                        task.spawn(function()
                            updateRoleAvatars()
                        end)
                        break
                    end
                end
                
                lastAttemptedGun = gun
                
                if not pickupSuccess then
                    repeat
                        task.wait(0.1)
                        if not State.InstantPickupEnabled then
                            return
                        end
                        
                        if State.CurrentGunDrop and State.CurrentGunDrop ~= lastAttemptedGun then
                            break
                        end
                        
                        if not State.CurrentGunDrop then
                            break
                        end
                        
                    until false
                end
            end
            
            task.wait(0.05)
        end
    end)
end

local function DisableInstantPickup()
    State.InstantPickupEnabled = false
    
    if State.InstantPickupThread then
        task.cancel(State.InstantPickupThread)
        State.InstantPickupThread = nil
    end
end

InstantKillAll = function()
    --print("[InstantKillAll] 🔪 Запуск...")
    
    local murderer = getMurder()
    if murderer ~= LocalPlayer then
        --print("[InstantKillAll] ❌ Вы не мурдерер!")
        if State.NotificationsEnabled then
            ShowNotification(
                "<font color=\"rgb(255, 85, 85)\">Error:</font> <font color=\"rgb(220,220,220)\">You are not the murderer</font>",
                CONFIG.Colors.Text
            )
        end
        return
    end
    
    local character = LocalPlayer.Character
    if not character then
        --print("[InstantKillAll] ❌ Character не найден!")
        return
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        --print("[InstantKillAll] ❌ HumanoidRootPart не найден!")
        return
    end
    
    -- ✅ Проверяем есть ли нож
    if not character:FindFirstChild("Knife") then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid and LocalPlayer.Backpack:FindFirstChild("Knife") then
            humanoid:EquipTool(LocalPlayer.Backpack:FindFirstChild("Knife"))
            task.wait(0.3)
        end
    end
    
    local knife = character:FindFirstChild("Knife")
    if not knife then
        --print("[InstantKillAll] ❌ Нож не найден!")
        if State.NotificationsEnabled then
            ShowNotification(
                "<font color=\"rgb(255, 85, 85)\">Error:</font> <font color=\"rgb(220,220,220)\">Knife not found</font>",
                CONFIG.Colors.Text
            )
        end
        return
    end
    
    local originalCFrame = hrp.CFrame
    local teleportedPlayers = 0
    
    -- ✅ ИЗМЕНЕНИЕ: Телепортируем игроков ПЕРЕД собой (как в KillAura)
    local killAuraDistance = State.KillAuraDistance or 2.5
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetHRP = player.Character:FindFirstChild("HumanoidRootPart")
            if targetHRP then
                -- ✅ Телепортируем игрока ПЕРЕД нами на расстоянии killAuraDistance
                targetHRP.CFrame = hrp.CFrame + hrp.CFrame.LookVector * killAuraDistance
                targetHRP.Anchored = true
                teleportedPlayers = teleportedPlayers + 1
            end
        end
    end
    
    if State.NotificationsEnabled then
        ShowNotification(
            "<font color=\"rgb(220,220,220)\">InstantKillAll: Players teleported: " .. teleportedPlayers .. ", attacking...</font>",
            CONFIG.Colors.Text
        )
    end
    
    --print("[InstantKillAll] 📍 Телепортировано: " .. teleportedPlayers .. " игроков ПЕРЕД собой")
    
    task.wait(0.2   )
    
    -- ✅ Активируем нож 3 раза
    for i = 1, 3 do
        knife = character:FindFirstChild("Knife")
        if knife and knife.Parent then
            knife:Activate()
            --print("[InstantKillAll] 🔪 Активация ножа #" .. i)
        else
            --print("[InstantKillAll] ⚠️ Нож пропал во время атаки!")
            break
        end
        
        if i < 3 then
            task.wait(1.5)
        end
    end
    
    task.wait(0.5)
    
    -- ✅ Освобождаем игроков
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetHRP = player.Character:FindFirstChild("HumanoidRootPart")
            if targetHRP then
                targetHRP.Anchored = false
            end
        end
    end
    
    --print("[InstantKillAll] ✅ Завершено!")
    
    if State.NotificationsEnabled then
        ShowNotification(
            "<font color=\"rgb(220,220,220)\">InstantKillAll:</font> <font color=\"rgb(168,228,160)\">Complete!</font>",
            CONFIG.Colors.Green
        )
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 16: VIEW CLIP & TELEPORT (СТРОКИ 2801-2930)
-- ══════════════════════════════════════════════════════════════════════════════

-- EnableViewClip() - DevCameraOcclusionMode.Invisicam
local function EnableViewClip()
    State.ViewClipEnabled = true
    LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
end

-- DisableViewClip() - DevCameraOcclusionMode.Zoom
local function DisableViewClip()
    State.ViewClipEnabled = false
    LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
end

-- TeleportToMouse() - TP на mouse.Hit.Position
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

-- ============= Глобальные переменные для невидимости =============
local InvisibilityConnection = nil
local VisibleParts = {} -- Список только видимых частей (Transparency == 0)

-- ============= Инициализация видимых частей =============
InitializeVisibleParts = function()
    VisibleParts = {}
    local Character = LocalPlayer.Character
    if not Character then return end
    
    -- Собираем только части с прозрачностью 0 (полностью видимые)
    for _, part in pairs(Character:GetDescendants()) do
        if part:IsA('BasePart') and part.Transparency == 0 then
            table.insert(VisibleParts, part)
        end
    end
end

-- ============= Функция переключения невидимости =============
ToggleInvisibility = function()
    State.IsInvisible = not State.IsInvisible
    
    if State.IsInvisible then
        
        -- Отключаем старое подключение если есть
        if InvisibilityConnection then
            InvisibilityConnection:Disconnect()
        end
        
        -- Инициализируем список видимых частей
        InitializeVisibleParts()
        
        -- Создаем цикл невидимости
        InvisibilityConnection = game:GetService('RunService').Heartbeat:Connect(function()
            if not State.IsInvisible then return end
            
            local Character = LocalPlayer.Character
            if not Character then return end
            
            local RootPart = Character:FindFirstChild('HumanoidRootPart')
            local Humanoid = Character:FindFirstChild('Humanoid')
            if not RootPart or not Humanoid then return end
            
            -- ✅ ОБНОВЛЯЕМ ПРОЗРАЧНОСТЬ КАЖДЫЙ КАДР
            for _, part in pairs(Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.Transparency = 0.5
                elseif part:IsA("Decal") then
                    part.Transparency = 0.5
                end
            end
            
            -- Сохраняем текущую позицию и смещение камеры
            local OriginalCFrame = RootPart.CFrame
            local OriginalCameraOffset = Humanoid.CameraOffset
            
            -- Перемещаем персонажа вниз на 200000 единиц
            local NewCFrame = OriginalCFrame * CFrame.new(0, -200000, 0)
            local RelativePosition = NewCFrame:ToObjectSpace(CFrame.new(OriginalCFrame.Position)).Position

            -- Применяем новую позицию и корректируем камеру
            RootPart.CFrame = NewCFrame
            Humanoid.CameraOffset = RelativePosition

            -- Ждем следующего кадра
            game:GetService('RunService').RenderStepped:Wait()

            -- Возвращаем персонажа на исходную позицию
            RootPart.CFrame = OriginalCFrame
            Humanoid.CameraOffset = OriginalCameraOffset
        end)
        
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(220,220,220)\">Invisibility</font> <font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Text)
        end
    else
        
        -- Отключаем цикл невидимости
        if InvisibilityConnection then
            InvisibilityConnection:Disconnect()
            InvisibilityConnection = nil
        end
        
        -- Возвращаем прозрачность всех частей на 0
        local Character = LocalPlayer.Character
        if Character then
            for _, part in pairs(Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.Transparency = 0
                elseif part:IsA("Decal") then
                    part.Transparency = 0
                end
            end
        end
        
        -- Очищаем список (он теперь не нужен, но оставим для совместимости)
        VisibleParts = {}
        
        -- Сбрасываем смещение камеры
        if Character then
            local Humanoid = Character:FindFirstChild('Humanoid')
            if Humanoid then
                Humanoid.CameraOffset = Vector3.new(0, 0, 0)
            end
        end
        
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(220,220,220)\">Invisibility</font> <font color=\"rgb(255,85,85)\">OFF</font>", CONFIG.Colors.Text)
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 17: KEYBIND SYSTEM (СТРОКИ 2931-3050)
-- ══════════════════════════════════════════════════════════════════════════════

-- FindKeybindButton() - Поиск кнопки по KeyCode
local function FindKeybindButton(keyCode)
    for bindName, boundKey in pairs(State.Keybinds) do
        if boundKey == keyCode then
            return bindName
        end
    end
    return nil
end

-- ClearKeybind() - Очистка привязки
local function ClearKeybind(bindName, button)
    State.Keybinds[bindName] = Enum.KeyCode.Unknown
    button.Text = "Not Bound"
    
    local originalColor = button.BackgroundColor3
    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 40, 40)}):Play()
    task.wait(0.15)
    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = originalColor}):Play()
end

-- SetKeybind() - Установка привязки
local function SetKeybind(key, keyCode, button, callbacks)
    -- Проверка дубликатов
    for actionName, boundKey in pairs(State.Keybinds) do
        if boundKey == keyCode and actionName ~= key then
            State.Keybinds[actionName] = Enum.KeyCode.Unknown
            
            for _, element in pairs(State.UIElements) do
                if element.Name == actionName .. "_Button" then
                    element.Text = "Not Bound"
                    break
                end
            end
        end
    end
    
    State.Keybinds[key] = keyCode
    button.Text = keyCode.Name
    State.ListeningForKeybind = nil
    
    local originalColor = button.BackgroundColor3
    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = CONFIG.Colors.Accent}):Play()
    task.wait(0.15)
    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = originalColor}):Play()
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 18: UTILITY FUNCTIONS (СТРОКИ 3051-3200)
-- ══════════════════════════════════════════════════════════════════════════════

-- SetupAntiAFK() - VirtualUser:CaptureController()
local function SetupAntiAFK()
    local VirtualUser = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    
    task.spawn(function()
        while getgenv().MM2_Script do
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

local function Rejoin()
    task.wait(0.5)
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
    task.wait(2)
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local function ExecuteInf()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
end

local respawning = {} -- Таблица для отслеживания состояния респавна по игрокам

local function respawn(plr)
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Защита от повторного вызова
    if respawning[plr.UserId] then 
        return 
    end
    respawning[plr.UserId] = true

    local ogpos = hrp.CFrame
    local ogpos2 = workspace.CurrentCamera.CFrame

    -- Уникальный ID для этого респавна
    local respawnId = tick()
    
    task.spawn(function()
        local newChar = plr.CharacterAdded:Wait()
        
        -- Проверка что это все еще актуальный респавн
        if not respawning[plr.UserId] or respawning[plr.UserId] ~= respawnId then 
            return 
        end
        
        local newHrp = newChar:WaitForChild("HumanoidRootPart", 5)
        local newHum = newChar:WaitForChild("Humanoid", 5)
        
        if newHrp and newHum then
            -- Ждем полной загрузки персонажа
            if newHum.Health == 0 then
                newHum.HealthChanged:Wait()
            end
            
            task.wait(0.1) -- Небольшая задержка для загрузки всех частей
            
            newHrp.Anchored = true
            newHrp.CFrame = ogpos
            
            -- Обновляем камеру после телепортации
            task.wait()
            workspace.CurrentCamera.CFrame = ogpos2
            
            task.wait(0.05)
            newHrp.Anchored = false
        end
        
        -- Очищаем флаг через небольшую задержку
        task.wait(0.2)
        respawning[plr.UserId] = nil
    end)

    respawning[plr.UserId] = respawnId
    char:BreakJoints()
end

-- Очистка при выходе игрока
game.Players.PlayerRemoving:Connect(function(plr)
    respawning[plr.UserId] = nil
end)


-- ══════════════════════════════════════════════════════════════════════════════
-- VOTE SPAMMER SYSTEM
-- ══════════════════════════════════════════════════════════════════════════════

local mapNames = {
    ["bank 2"] = "Bank 2",
    ["biolab"] = "BioLab",
    ["bio lab"] = "BioLab",
    ["factory"] = "Factory",
    ["hospital 3"] = "Hospital 3",
    ["hotel 2"] = "Hotel 2",
    ["house 2"] = "House 2",
    ["mansion 2"] = "Mansion 2",
    ["mil base"] = "Mil Base",
    ["milbase"] = "Mil Base",
    ["office 3"] = "Office 3",
    ["police station"] = "Police Station",
    ["research facility"] = "Research Facility",
    ["workplace"] = "Workplace"
}

local mapPriorities = {
    ["House 2"] = 1,
    ["Bank 2"] = 2,
    ["Factory"] = 3,
    ["Hospital 3"] = 4,
    ["Workplace"] = 5,
    ["Mansion 2"] = 6,
    ["Office 3"] = 7,
    ["Police Station"] = 8,
    ["Hotel 2"] = 9,
    ["Research Facility"] = 10,
    ["BioLab"] = 11,
    ["Mil Base"] = 12
}

local VotePad = {}
VotePad.__index = VotePad

function VotePad.new(padModel)
    local self = setmetatable({}, VotePad)
    self.Model = padModel
    self.MapName = nil
    self.Votes = 0
    self.TextElements = {}
    self.HasImage = false
    self.ClickPart = nil
    self.IsActive = false
    self.Priority = 999
    self:Initialize()
    return self
end

function VotePad:Initialize()
    for _, obj in pairs(self.Model:GetDescendants()) do
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            if obj.Image ~= "" then
                self.HasImage = true
            end
        end
    end
    
    for _, obj in pairs(self.Model:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            table.insert(self.TextElements, obj)
            local text = obj.Text
            local textLower = text:lower()
            
            if not self.MapName then
                for searchName, displayName in pairs(mapNames) do
                    if textLower:find(searchName) then
                        self.MapName = displayName
                        self.Priority = mapPriorities[displayName] or 999
                        break
                    end
                end
            end
            
            if text:find("Votes:") then
                local votes = text:match("Votes:%s*(%d+)")
                self.Votes = tonumber(votes) or 0
            end
        end
    end
    
    self.IsActive = (self.MapName ~= nil) and self.HasImage
    self.ClickPart = self.Model:FindFirstChildWhichIsA("Part", true) or 
                     self.Model:FindFirstChildWhichIsA("MeshPart", true)
end

function VotePad:UpdateVotes()
    self.HasImage = false
    for _, obj in pairs(self.Model:GetDescendants()) do
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            if obj.Image ~= "" then
                self.HasImage = true
                break
            end
        end
    end
    
    for _, element in pairs(self.TextElements) do
        if element.Text:find("Votes:") then
            local votes = element.Text:match("Votes:%s*(%d+)")
            self.Votes = tonumber(votes) or 0
        end
    end
    
    self.IsActive = (self.MapName ~= nil) and self.HasImage
    return self.Votes
end

function VotePad:GetPosition()
    if self.ClickPart then
        return self.ClickPart.Position
    elseif self.Model:IsA("Model") and self.Model.PrimaryPart then
        return self.Model.PrimaryPart.Position
    elseif self.Model:IsA("BasePart") then
        return self.Model.Position
    end
    return nil
end

local VoteSpammer = {}
VoteSpammer.__index = VoteSpammer

function VoteSpammer.new()
    local self = setmetatable({}, VoteSpammer)
    self.VotePads = {}
    self.ActiveVotePads = {}
    self.Active = false
    self.AutoSpam = false
    self.VoteGoal = State.VoteGoal or 8
    self.Player = LocalPlayer
    
    self.IsWaitingForVoting = false
    self.IsGoalReached = false
    self.CurrentVotingSession = 0
    self.TeleportedThisSession = false
    self.CurrentTargetPad = nil
    self.GodModeWasDisabled = false  -- Флаг что мы выключали GodMode
    
    return self
end

function VoteSpammer:Scan()
    self.VotePads = {}
    self.ActiveVotePads = {}
    
    local regularLobby = Workspace:FindFirstChild("RegularLobby")
    if not regularLobby then return end
    
    for _, child in pairs(regularLobby:GetChildren()) do
        if child.Name:find("VotePad") then
            local votePad = VotePad.new(child)
            if votePad.MapName then
                table.insert(self.VotePads, votePad)
                if votePad.IsActive then
                    table.insert(self.ActiveVotePads, votePad)
                end
            end
        end
    end
    
    table.sort(self.ActiveVotePads, function(a, b)
        return a.Priority < b.Priority
    end)
end

function VoteSpammer:GetTargetPad()
    if #self.ActiveVotePads > 0 then
        return self.ActiveVotePads[1]
    end
    return nil
end

function VoteSpammer:TeleportToVotePad(votePad)
    local character = self.Player.Character
    if not character then return false end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    
    local position = votePad:GetPosition()
    if not position then return false end
    
    humanoidRootPart.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
    return true
end

function VoteSpammer:StartAutoSpam()
    if self.AutoSpam then
        return
    end
    
    self.AutoSpam = true
    self.GodModeWasDisabled = false
    
    if State.NotificationsEnabled then
        ShowNotification("Vote Spammer: <font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Text)
    end
    
    task.spawn(function()
        while self.AutoSpam do
            self:Scan()
            
            -- Обновляем VoteGoal из State
            self.VoteGoal = State.VoteGoal or 8
            
            -- Голосование неактивно
            if #self.ActiveVotePads == 0 then
                if not self.IsWaitingForVoting then
                    self.IsWaitingForVoting = true
                    self.IsGoalReached = false
                    self.TeleportedThisSession = false
                    self.CurrentTargetPad = nil
                    
                    -- ✅ Включаем GodMode обратно (голосование закончилось)
                    if self.GodModeWasDisabled and State.GodModeWithAutoFarm then
                        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                        local humanoid = character:WaitForChild("Humanoid", 5)
                        
                        if humanoid then
                            task.wait(1)
                            
                            if not State.GodModeEnabled then
                                pcall(function()
                                    ToggleGodMode()
                                end)
                            end
                        end
                        self.GodModeWasDisabled = false
                    end
                end
                task.wait(2)
                continue
            end
            
            -- Новое голосование началось
            if self.IsWaitingForVoting then
                self.CurrentVotingSession = self.CurrentVotingSession + 1
                local targetPad = self:GetTargetPad()
                
                -- ✅ Выключаем GodMode перед началом голосования
                if State.GodModeWithAutoFarm and State.GodModeEnabled then
                    pcall(function()
                        ToggleGodMode()
                    end)
                    self.GodModeWasDisabled = true
                    task.wait(0.3)
                end
                
                if targetPad then
                    self.CurrentTargetPad = targetPad
                end
                self.IsWaitingForVoting = false
                self.IsGoalReached = false
            end
            
            local targetPad = self:GetTargetPad()
            if not targetPad then
                task.wait(2)
                continue
            end
            
            targetPad:UpdateVotes()
            
            -- Цель достигнута
            if targetPad.Votes >= self.VoteGoal then
                if not self.IsGoalReached then
                    -- ✅ Включаем GodMode обратно (цель достигнута)
                    if self.GodModeWasDisabled and State.GodModeWithAutoFarm then
                        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                        local humanoid = character:WaitForChild("Humanoid", 5)
                        
                        if humanoid then
                            task.wait(1)
                            
                            if not State.GodModeEnabled then
                                pcall(function()
                                    ToggleGodMode()
                                end)
                            end
                        end
                        self.GodModeWasDisabled = false
                    end
                    self.IsGoalReached = true
                end
                task.wait(2)
                continue
            end
            
            -- Телепорт один раз за сессию
            if not self.TeleportedThisSession then
                if not self:TeleportToVotePad(targetPad) then
                    task.wait(1)
                    continue
                end
                self.TeleportedThisSession = true
                task.wait(0.4)
            end
            
            -- Респавн для голосования
            respawn(self.Player)
            task.wait(0.4)
            
            targetPad:UpdateVotes()
        end
    end)
end

function VoteSpammer:StopAutoSpam()
    if not self.AutoSpam then
        return
    end
    
    self.AutoSpam = false
    
    -- ✅ Включаем GodMode обратно при остановке
    if self.GodModeWasDisabled and State.GodModeWithAutoFarm then
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local humanoid = character:WaitForChild("Humanoid", 5)
        
        if humanoid then
            task.wait(1)
            
            if not State.GodModeEnabled then
                pcall(function()
                    ToggleGodMode()
                end)
            end
        end
        self.GodModeWasDisabled = false
    end
    
    if State.NotificationsEnabled then
        ShowNotification("Vote Spammer: <font color=\"rgb(255,85,85)\">OFF</font>", CONFIG.Colors.Text)
    end
end

-- Создаем глобальный экземпляр
if not _G.VoteSpammer then
    _G.VoteSpammer = VoteSpammer.new()
end

-- Toggle функция
local function ToggleVoteSpammer(enabled)
    if enabled then
        _G.VoteSpammer:StartAutoSpam()
    else
        _G.VoteSpammer:StopAutoSpam()
    end
end

local function ServerHop()
    
    -- Конфигурация
    local CONFIG = {
        MIN_PLAYERS = 1,
        MAX_PLAYERS_THRESHOLD = 0.95, -- Не заходить на почти полные серверы
        MAX_ATTEMPTS = 10,
        RETRY_DELAY = 1
    }
    
    -- Получение списка серверов
    local function GetServers()
        local servers = {}
        local cursor = ""
        local attempts = 0
        
        while attempts < 3 do -- Максимум 3 страницы (300 серверов)
            local url = string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
                game.PlaceId
            )
            
            if cursor ~= "" then
                url = url .. "&cursor=" .. cursor
            end
            
            local success, response = pcall(function()
                return game:HttpGet(url)
            end)
            
            if not success then
                warn("[ServerHop] Ошибка загрузки серверов:", response)
                break
            end
            
            local data = HttpService:JSONDecode(response)
            
            if data and data.data then
                for _, server in ipairs(data.data) do
                    -- Фильтрация: не текущий сервер, есть игроки, не переполнен
                    if server.id ~= game.JobId 
                        and server.playing >= CONFIG.MIN_PLAYERS 
                        and server.playing < (server.maxPlayers * CONFIG.MAX_PLAYERS_THRESHOLD) then
                        table.insert(servers, server)
                    end
                end
            end
            
            -- Если нашли достаточно серверов - хватит
            if #servers >= 10 then
                break
            end
            
            cursor = data.nextPageCursor or ""
            if cursor == "" then break end
            
            attempts = attempts + 1
            task.wait(0.1)
        end
        
        return servers
    end
    
    -- Выбор лучшего сервера (предпочтение серверам с меньшим заполнением)
    local function SelectBestServer(servers)
        if #servers == 0 then return nil end
        
        -- Сортировка по количеству игроков (предпочтение менее заполненным)
        table.sort(servers, function(a, b)
            local fillA = a.playing / a.maxPlayers
            local fillB = b.playing / b.maxPlayers
            return fillA < fillB
        end)
        
        -- Выбираем случайный из топ-5 лучших серверов
        local topCount = math.min(5, #servers)
        return servers[math.random(1, topCount)]
    end
    
    -- Телепортация
    local function TeleportToJob(jobId)
        for attempt = 1, 3 do
            local success, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
            end)
            
            if success then
                return true
            else
                warn("[ServerHop] Попытка", attempt, "не удалась:", err)
                task.wait(CONFIG.RETRY_DELAY)
            end
        end
        return false
    end
    
    -- ═══════════════════════════════════════════════════════════
    -- ОСНОВНАЯ ЛОГИКА
    -- ═══════════════════════════════════════════════════════════
    
    print("[ServerHop] Поиск серверов...")
    
    local servers = GetServers()
    
    if #servers == 0 then
        warn("[ServerHop] Не найдено подходящих серверов!")
        return false
    end
    
    print("[ServerHop] Найдено серверов:", #servers)
    
    local selectedServer = SelectBestServer(servers)
    
    if not selectedServer then
        warn("[ServerHop] Не удалось выбрать сервер!")
        return false
    end
    
    print(string.format(
        "[ServerHop] Подключение к серверу: %d/%d игроков",
        selectedServer.playing,
        selectedServer.maxPlayers
    ))
    
    return TeleportToJob(selectedServer.id)
end


local function ServerLagger()
    if State.NotificationsEnabled then
        ShowNotification(
            "<font color=\"rgb(255, 85, 85)\">Server Lagger: </font><font color=\"rgb(220,220,220)\">Success</font>",
            CONFIG.Colors.Text
        )
    end
   
    pcall(function()
        local GetSyncData = ReplicatedStorage.GetSyncData
        local InvokeServer = GetSyncData.InvokeServer
        local counter = 0
       
        while true do
            for i = 1, 1 do
                task.spawn(InvokeServer, GetSyncData)
            end
           
            counter = counter + 1
            if counter == 3 then
                counter = 0
                wait(0)
            end
        end
    end)
end

local function SpeedGlitch()
    local player = game.Players.LocalPlayer
    player.Character:WaitForChild('Humanoid')
    wait(0.1)
    
    -- Проверка с новым именем
    if player.Backpack:FindFirstChild("SpeedGlitchTool") or player.Character:FindFirstChild("SpeedGlitchTool") then
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">already given!</font>", CONFIG.Colors.Text)
        end
        return
    end
    
    do
        local tool = Instance.new('Tool')
        tool.Name = "SpeedGlitchTool"  -- Новое имя
        tool.CanBeDropped = false  -- Нельзя уронить
        tool.Grip = CFrame.new(0, -6.292601585388184, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
        tool.GripForward = Vector3.new(-0, -0, -1)
        tool.GripPos = Vector3.new(0, -6.292601585388184, 0)
        tool.GripRight = Vector3.new(1, 0, 0)
        tool.GripUp = Vector3.new(0, 1, 0)
        tool.ManualActivationOnly = false
        tool.RequiresHandle = true
        tool.ToolTip = "Speed Glitch"  -- Подсказка при наведении
        tool.TextureId = ""  -- Пустая иконка (будет показывать текст)

        local child1 = Instance.new('Part')
        child1.Name = "Handle"
        child1.Size = Vector3.new(1.5, 12, 1.5)
        child1.BrickColor = BrickColor.new("Medium stone grey")
        child1.Material = Enum.Material.Plastic
        child1.Reflectance = 0
        child1.Transparency = 1  -- НЕВИДИМЫЙ
        child1.CanCollide = false
        child1.Shape = Enum.PartType.Block
        child1.TopSurface = Enum.SurfaceType.Smooth
        child1.BottomSurface = Enum.SurfaceType.Smooth
        child1.Anchored = false
        child1.LeftSurface = Enum.SurfaceType.Smooth
        child1.RightSurface = Enum.SurfaceType.Smooth
        child1.FrontSurface = Enum.SurfaceType.Smooth
        child1.BackSurface = Enum.SurfaceType.Smooth

        local child2 = Instance.new('SpecialMesh')
        child2.Name = "Mesh"
        child2.Scale = Vector3.new(0.5, 1.2000000476837158, 0.5)
        child2.MeshType = Enum.MeshType.Head
        child2.Offset = Vector3.new(0, 0, 0)
        child2.Parent = child1

        local child4 = Instance.new('Part')
        child4.Name = "Sign"
        child4.Size = Vector3.new(4.5, 4.5, 1.5)
        child4.BrickColor = BrickColor.new("Bright yellow")
        child4.Material = Enum.Material.Plastic
        child4.Reflectance = 0
        child4.Transparency = 1  -- НЕВИДИМЫЙ
        child4.CanCollide = false
        child4.Shape = Enum.PartType.Block
        child4.TopSurface = Enum.SurfaceType.Smooth
        child4.BottomSurface = Enum.SurfaceType.Smooth
        child4.Anchored = false
        child4.LeftSurface = Enum.SurfaceType.Smooth
        child4.RightSurface = Enum.SurfaceType.Smooth
        child4.FrontSurface = Enum.SurfaceType.Smooth
        child4.BackSurface = Enum.SurfaceType.Smooth

        local child5 = Instance.new('BlockMesh')
        child5.Name = "Mesh"
        child5.Parent = child4

        -- DECALS УДАЛЕНЫ - больше не видны
        
        child4.Parent = child1
        child1.Parent = tool

        local weld = Instance.new('Weld')
        weld.Name = "HandleToSign"
        weld.Part0 = child1
        weld.Part1 = child4
        weld.C0 = CFrame.new(0, 3.75, 0)
        weld.C1 = CFrame.new(0, 0, 0)
        weld.Parent = child1

        tool.Parent = player.Backpack
        
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(168,228,160)\">Success: </font><font color=\"rgb(220,220,220)\">Speed Glitch tool given!</font>", CONFIG.Colors.Text)
        end
    end
end


-- СНАЧАЛА объявляем функции
local function HandleEmoteInput(input)
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
end

local function HandleActionInput(input)
    if input.KeyCode == State.Keybinds.knifeThrow and State.Keybinds.knifeThrow ~= Enum.KeyCode.Unknown then
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
        if State.NoClipEnabled then
            DisableNoClip()
        else
            EnableNoClip()
        end
    end

    if input.KeyCode == State.Keybinds.Invisibility and State.Keybinds.Invisibility ~= Enum.KeyCode.Unknown then
        pcall(function() ToggleInvisibility() end)
    end
end

-- Auto Rejoin on Disconnect
local function HandleAutoRejoin(enabled)
    State.AutoRejoinEnabled = enabled
    
    if enabled then
        task.spawn(function()
            repeat task.wait() until game.CoreGui:FindFirstChild('RobloxPromptGui')
            
            local promptOverlay = game.CoreGui.RobloxPromptGui.promptOverlay
            local connection
            
            connection = promptOverlay.ChildAdded:Connect(function(prompt)
                if State.AutoRejoinEnabled and prompt.Name == 'ErrorPrompt' then
                    task.wait(0.5)
                    Rejoin()
                end
            end)
            
            getgenv().AutoRejoinConnection = connection
            TrackConnection(connection)
        end)
    else
        if getgenv().AutoRejoinConnection then
            getgenv().AutoRejoinConnection:Disconnect()
            getgenv().AutoRejoinConnection = nil
        end
    end
end

local DEFAULT_INTERVAL = 25 * 60

-- Функция для установки интервала
local function SetReconnectInterval(minutes)
    local mins = tonumber(minutes) or 25
    State.ReconnectInterval = mins * 60
    print(string.format("[Auto Reconnect] Interval: %d min (%d sec)", mins, State.ReconnectInterval))
end

local function HandleAutoReconnect(enabled)
    State.AutoReconnectEnabled = enabled
    
    if enabled then
        local interval = State.ReconnectInterval or DEFAULT_INTERVAL
        
        State.ReconnectThread = task.spawn(function()
            local elapsed = 0
            
            while State.AutoReconnectEnabled do
                task.wait(1)
                elapsed += 1
                
                if elapsed >= interval then
                    Rejoin()
                    return
                end
            end
        end)
    else
        if State.ReconnectThread then
            task.cancel(State.ReconnectThread)
            State.ReconnectThread = nil
        end
    end
end
-- А ТЕПЕРЬ создаём GUI с Handlers
local GUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Yany1944/rbxmain/refs/heads/main/Libraryes/GUI.lua"))()({
    CONFIG = CONFIG,
    State = State,
    Players = Players,
    CoreGui = CoreGui,
    TweenService = TweenService,
    UserInputService = UserInputService,
    LocalPlayer = LocalPlayer,
    TrackConnection = function(conn)
        if conn then table.insert(State.Connections, conn) end
        return conn
    end,
    ShowNotification = ShowNotification,
    Handlers = {
        -- Character
        ApplyWalkSpeed = ApplyWalkSpeed,
        ApplyJumpPower = ApplyJumpPower,
        ApplyMaxCameraZoom = ApplyMaxCameraZoom,
        ApplyFOV = function(v) pcall(function() ApplyFOV(v) end) end,
        ViewClip = function(on) if on then EnableViewClip() else DisableViewClip() end end,

        -- Notifications toggle
        NotificationsEnabled = function(on) State.NotificationsEnabled = on end,

        -- ESP
        GunESP = function(on) State.GunESP = on UpdateGunESPVisibility() UpdateTrapESPVisibility() end,
        PlayerNicknamesESP = function(on)
        State.PlayerNicknamesESP = on
        if on then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    CreatePlayerNicknameESP(player)
                end
            end
        else
            -- Удаляем все ESP при выключении
            for player, _ in pairs(State.PlayerNicknamesCache) do
                RemovePlayerNicknameESP(player)
            end
        end
        
        UpdatePlayerNicknamesVisibility()
    end,
        MurderESP = function(on) State.MurderESP = on end,
        SheriffESP = function(on) State.SheriffESP = on end,
        InnocentESP = function(on) State.InnocentESP = on end,
        

        -- Visuals
        UIOnly = function(on) State.UIOnlyEnabled = on if on then EnableUIOnly() else DisableUIOnly() end end,
        BulletTracers = ToggleBulletTracers,

        InstantPickup = function(on) if on then EnableInstantPickup() else DisableInstantPickup() end end,

        -- Farming
        AutoFarm = function(on)
            State.AutoFarmEnabled = on
            if on then
                State.CoinBlacklist = {}
                State.StartSessionCoins = GetCollectedCoinsCount()
                ShowNotification("Auto Farm: <font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Text)
                StartAutoFarm()
            else
                StopAutoFarm()
                ShowNotification("Auto Farm: <font color=\"rgb(255,85,85)\">OFF</font>", CONFIG.Colors.Text)
            end
        end,
        XPFarm = function(on) State.XPFarmEnabled = on if on then StartXPFarm() else StopXPFarm() end end,
        UndergroundMode = function(on) State.UndergroundMode = on end,
        CoinFarmFlySpeed = function(v) State.CoinFarmFlySpeed = v end,
        CoinFarmDelay = function(v) State.CoinFarmDelay = v end,
        AFKMode = function(on) State.AFKModeEnabled = on if on then EnableMaxOptimization() else DisableMaxOptimization() end end,
        FPSBoost = EnableFPSBoost,

        -- AntiFling / WalkFling
        AntiFling = function(on) if on then EnableAntiFling() else DisableAntiFling() end end,
        WalkFling = function(on) if on then WalkFlingStart() else WalkFlingStop() end end,

        FlingMurderer = FlingMurderer,
        FlingSheriff  = FlingSheriff,

        -- Server
        Rejoin = Rejoin,
        ExecInf = ExecuteInf,
        ServerHop = ServerHop,
        SpeedGlitchTool = SpeedGlitch,
        ServerLagger = ServerLagger,
        HandleAutoRejoin = HandleAutoRejoin,
        HandleAutoReconnect = HandleAutoReconnect,
        SetReconnectInterval = SetReconnectInterval,
        RespawnPlr = function() respawn(game:GetService("Players").LocalPlayer) end,
        
        -- Keybind system / input
        ClearKeybind = ClearKeybind,
        SetKeybind = SetKeybind,
        OnInputEmotes = function(input) HandleEmoteInput(input) end,
        OnInputActions = function(input) HandleActionInput(input) end,
        OnInputEnded = function(input)
            if input.KeyCode == State.Keybinds.ClickTP then
                State.ClickTPActive = false
            end
        end,
        OnMouseClick = function()
            if State.ClickTPActive then TeleportToMouse() end
        end,

        ShootMurdererMode = function(value)
            State.ShootMurdererMode = value
        end,

        Shutdown = function() FullShutdown() end,

        VoteSpammer = ToggleVoteSpammer,

        AutoLoadOnTeleport = function(on)
            State.AutoLoadOnTeleport = on
        end,
    }
})

GUI.Init()
--[[
-- ОПТИМИЗИРОВАННАЯ СИСТЕМА МОНЕТ (с поддержкой запятых)
task.spawn(function()
    task.wait(0.5)
    
    local header = State.UIElements.MainGui and State.UIElements.MainGui:FindFirstChild("MainFrame")
    if header then header = header:FindFirstChild("Header") end
    if not header then return end
    
    -- Создаем label с автоматической шириной
    local coinsLabel = Instance.new("TextLabel")
    coinsLabel.Name = "CoinsDisplay"
    coinsLabel.Text = ""
    coinsLabel.RichText = true
    coinsLabel.Font = Enum.Font.GothamBold
    coinsLabel.TextSize = 14
    coinsLabel.TextColor3 = CONFIG.Colors.Text
    coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
    coinsLabel.BackgroundTransparency = 1
    coinsLabel.TextScaled = false
    coinsLabel.Parent = header
    
    -- Функция парсинга числа (убирает запятые)
    local function parseNumber(text)
        if not text then return 0 end
        -- Убираем все запятые: "26,292" -> "26292"
        local cleaned = tostring(text):gsub(",", "")
        return tonumber(cleaned) or 0
    end
    
    -- Функция обновления позиции и текста
    local function updateCoins(coins)
        -- Форматируем с запятыми для читаемости
        local formatted = tostring(coins):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        coinsLabel.Text = string.format("Coins: <font color=\"rgb(255, 215, 110)\">%s</font>", formatted)
        
        -- Динамический расчет ширины по количеству символов (включая запятые)
        local displayLength = #formatted
        local width = math.clamp(60 + (displayLength * 8), 85, 150)
        
        -- Позиция: отступ от крестика (35px) + margin (10px) + ширина label
        coinsLabel.Size = UDim2.new(0, width, 1, 0)
        coinsLabel.Position = UDim2.new(1, -(45 + width), 0, 0)
    end
    
    task.wait(1.5)
    
    -- Подключение к GUI игры
    local success, coinsElement = pcall(function()
        return LocalPlayer.PlayerGui:WaitForChild("CrossPlatform", 5)
            :WaitForChild("Christmas2025", 5)
            :WaitForChild("Container", 5)
            :WaitForChild("Main", 5)
            :WaitForChild("Gifting", 5)
            :WaitForChild("Title", 5)
            :WaitForChild("Tokens", 5)
            :WaitForChild("Container", 5)
            :WaitForChild("TextLabel", 5)
    end)
    
    if success and coinsElement then
        -- Начальное обновление с парсингом
        local initialCoins = parseNumber(coinsElement.Text)
        updateCoins(initialCoins)
        
        -- ЕДИНСТВЕННОЕ подключение - срабатывает только при изменении
        local connection = coinsElement:GetPropertyChangedSignal("Text"):Connect(function()
            local coins = parseNumber(coinsElement.Text)
            updateCoins(coins)
        end)
        
        -- Cleanup при удалении GUI
        table.insert(State.Connections, connection)
    else
        coinsLabel.Text = "Coins: <font color=\"rgb(255, 0, 0)\">N/A</font>"
        coinsLabel.Size = UDim2.new(0, 100, 1, 0)
        coinsLabel.Position = UDim2.new(1, -145, 0, 0)
    end
end)
--]]
----------------------------------------------------------------
-- СОЗДАНИЕ ВКЛАДОК И ПРИВЯЗКА К Handlers
----------------------------------------------------------------
do
    local MainTab = GUI.CreateTab("Main")

        MainTab:CreateSection("CHARACTER SETTINGS")
        MainTab:CreateInputField("WalkSpeed", "Set custom walk speed", State.WalkSpeed, "ApplyWalkSpeed")
        MainTab:CreateInputField("JumpPower", "Set custom jump power", State.JumpPower, "ApplyJumpPower")
        MainTab:CreateInputField("Max Camera Zoom", "Set maximum camera distance", State.MaxCameraZoom, "ApplyMaxCameraZoom")

        MainTab:CreateSection("CAMERA")
        MainTab:CreateInputField("Field of View", "Set custom camera FOV", State.CameraFOV, "ApplyFOV")
        MainTab:CreateToggle("ViewClip", "Camera clips through walls", "ViewClip", true)
        MainTab:CreateKeybindButton("Toggle Invisible", "invisibility", "Invisibility")

        MainTab:CreateSection("TELEPORT & OTHER")
        MainTab:CreateKeybindButton("Click TP (Hold Key)", "clicktp", "ClickTP")
        MainTab:CreateKeybindButton("Toggle NoClip", "NoClip", "NoClip")
        MainTab:CreateKeybindButton("Toggle GodMode", "godmode", "GodMode")

        MainTab:CreateSection("Speed Glitch")
        MainTab:CreateButton("", "Speed Glitch Tool", CONFIG.Colors.Accent, "SpeedGlitchTool")
        ----------------------------------------------------------------------------
        MainTab:CreateButton("", "Fast respawn", CONFIG.Colors.Accent, "RespawnPlr")
end

do
    local VisualsTab = GUI.CreateTab("Visuals")

        VisualsTab:CreateSection("NOTIFICATIONS")
        VisualsTab:CreateToggle("Enable Notifications", "Show role and gun notifications", "NotificationsEnabled",false)

        VisualsTab:CreateSection("ESP OPTIONS (Highlight)")
        VisualsTab:CreateToggle("Gun ESP", "Highlight dropped guns", "GunESP",false)
        VisualsTab:CreateToggle("Murder ESP", "Highlight murderer", "MurderESP",false)
        VisualsTab:CreateToggle("Sheriff ESP", "Highlight sheriff", "SheriffESP",false)
        VisualsTab:CreateToggle("Innocent ESP", "Highlight innocent players", "InnocentESP",false)
        VisualsTab:CreateToggle("Show Nicknames", "Display player nicknames above head", "PlayerNicknamesESP", false)

        VisualsTab:CreateSection("Misc")
        VisualsTab:CreateToggle("UI Only", "Hide all UI except script GUI", "UIOnly", false)
        VisualsTab:CreateToggle("Bullet Tracers", "Show bullet/knife trajectory", "BulletTracers")
end

do
    local CombatTab = GUI.CreateTab("Combat")

        CombatTab:CreateSection("MURDERER TOOLS")
        CombatTab:CreateKeybindButton("Fast throw", "knifeThrow", "knifeThrow")
        CombatTab:CreateToggle("Murderer Kill Aura", "Auto kill nearby players", "KillAura")
        CombatTab:CreateKeybindButton("Instant Kill All (Murderer)", "instantkillall", "InstantKillAll")

        CombatTab:CreateSection("SHERIFF TOOLS")
        CombatTab:CreateDropdown("Shoot Mode", "Shooting method", {"Magic", "Silent"}, State.ShootMurdererMode or "Magic", "ShootMurdererMode")
        CombatTab:CreateKeybindButton("Shoot Murderer (Instakill)", "shootmurderer", "ShootMurderer")
        CombatTab:CreateKeybindButton("Pickup Dropped Gun (TP)", "pickupgun", "PickupGun")
        CombatTab:CreateToggle("Instant Pickup Gun", "Auto pickup gun when dropped", "InstantPickup", _G.AUTOEXEC_ENABLED)
end

do
    local FarmTab = GUI.CreateTab("Farming")

        FarmTab:CreateSection("AUTO FARM")
        FarmTab:CreateToggle("Auto Farm Coins", "Automatic coin collection", "AutoFarm", _G.AUTOEXEC_ENABLED)
        FarmTab:CreateToggle("XP Farm", "Auto win rounds: Kill as Murderer, Shoot as Sheriff, Fling as Innocent", "XPFarm", _G.AUTOEXEC_ENABLED)
        FarmTab:CreateToggle("Underground Mode", "Fly under the map (safer)", "UndergroundMode",true)
        FarmTab:CreateSlider("Fly Speed", "Flying speed (10-30)", 10, 30, State.CoinFarmFlySpeed, "CoinFarmFlySpeed", 1)
        FarmTab:CreateSlider("TP Delay", "Delay between TPs (0.5-5.0)", 0.5, 5.0, State.CoinFarmDelay, "CoinFarmDelay", 0.5)
        FarmTab:CreateToggle("AFK Mode", "Disable rendering to reduce GPU usage", "AFKMode")
        FarmTab:CreateToggle("Auto Reconnect (Farm)", "Reconnect every 25 min during autofarm to avoid AFK kick", "HandleAutoReconnect", _G.AUTOEXEC_ENABLED)
        FarmTab:CreateInputField("Reconnect interval","Default: 25 min", math.floor(State.ReconnectInterval / 60), "SetReconnectInterval")
        FarmTab:CreateSection("VOTE SPAM")
        FarmTab:CreateToggle("Auto Vote Spam", "Automatically vote for priority maps", "VoteSpammer", false)
        FarmTab:CreateInputField("Vote Goal", "Target votes (default: 8)", State.VoteGoal, function(value) State.VoteGoal = tonumber(value) or 8 end)
        FarmTab:CreateButton("", "FPS Boost", CONFIG.Colors.Accent, "FPSBoost")
end

do
    local FunTab = GUI.CreateTab("Fun")

        FunTab:CreateSection("ANIMATION KEYBINDS")
        FunTab:CreateKeybindButton("Sit Animation", "sit", "Sit")
        FunTab:CreateKeybindButton("Dab Animation", "dab", "Dab")
        FunTab:CreateKeybindButton("Zen Animation", "zen", "Zen")
        FunTab:CreateKeybindButton("Ninja Animation", "ninja", "Ninja")
        FunTab:CreateKeybindButton("Floss Animation", "floss", "Floss")

        FunTab:CreateSection("ANTI-FLING")
        FunTab:CreateToggle("Enable Anti-Fling", "Protect yourself from flingers", "AntiFling",true)
        FunTab:CreateToggle("Walk Fling", "Fling players by walking into them", "WalkFling", _G.AUTOEXEC_ENABLED)

        FunTab:CreateSection("FLING PLAYER")
        FunTab:CreatePlayerDropdown("Select Target", "Choose player to fling")
        FunTab:CreateKeybindButton("Fling Selected Player", "fling", "FlingPlayer")

        FunTab:CreateSection("FLING ROLE")
        FunTab:CreateButton("", "Fling Murderer", Color3.fromRGB(255, 85, 85), "FlingMurderer")
        FunTab:CreateButton("", "Fling Sheriff", Color3.fromRGB(90, 140, 255), "FlingSheriff")
end

do
    local UtilityTab = GUI.CreateTab("Server")

        UtilityTab:CreateSection("SERVER MANAGEMENT")
        UtilityTab:CreateButton("", "🔄 Rejoin Server", CONFIG.Colors.Accent, "Rejoin")
        UtilityTab:CreateButton("", "🌐 Server Hop", Color3.fromRGB(100, 200, 100), "ServerHop")
        UtilityTab:CreateToggle("Auto Rejoin on Disconnect","Automatically rejoin server if kicked/disconnected","HandleAutoRejoin",true)
        UtilityTab:CreateButton("", "Execute Infinite Yield", CONFIG.Colors.Accent, "ExecInf")

        UtilityTab:CreateSection("DANGER ZONE")
        UtilityTab:CreateButton("", "💣 SERVER CRASHER", Color3.fromRGB(255, 85, 85), "ServerLagger")
end
---------
LocalPlayer.CharacterAdded:Connect(function()
    CleanupMemory()
    task.wait(1)
    ApplyCharacterSettings()

    State.prevMurd = nil
    State.prevSher = nil
    State.heroSent = false
    State.roundStart = true
    State.roundActive = false
end)

-- ═══════════════════════════════════════════════════════════════
--                      ЗАПУСК СКРИПТА
-- ═══════════════════════════════════════════════════════════════

CreateNotificationUI()
CreateAvatarUI()
ApplyCharacterSettings()
SetupGunTracking()
StartTrapTracking   ()
SetupPlayerNicknamesTracking()
pcall(function()
    ApplyFOV(State.CameraFOV)
end)
SetupAntiAFK()
StartRoleChecking()
if _G.AUTOEXEC_ENABLED then
    task.spawn(function()
        task.wait(2)
        pcall(function()
            task.wait(0.1)
            EnableFPSBoost()
        end)
    end)
end
--print("╔════════════════════════════════════════════╗")
--print("║   MM2 ESP v6.0 - Successfully Loaded!     ║")
--print("║   Press [" .. CONFIG.HideKey.Name .. "] to toggle GUI               ║")
--print("╚════════════════════════════════════════════╝")
