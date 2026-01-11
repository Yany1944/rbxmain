--[[
    MM2 AutoFarm Script
    Автономный скрипт автофарма для Murder Mystery 2
    Включает: автофарм монет, хп фарм, инстант пикап, ноуклип, годмод, 
    антифлинг, андерграунд мод, фпс буст, реджоин, серверхоп
]]--

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

-- Локальные переменные
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Состояние скрипта
local State = {
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
    
    -- HP Farm
    HPFarmEnabled = false,
    HPFarmThread = nil,
    
    -- Instant Pickup
    InstantPickupEnabled = false,
    InstantPickupThread = nil,
    
    -- Noclip
    NoclipEnabled = false,
    NoclipConnection = nil,
    
    -- GodMode
    GodModeEnabled = false,
    GodModeConnection = nil,
    
    -- Anti-Fling
    AntiFlingEnabled = false,
    AntiFlingConnection = nil,
    
    -- FPS Boost
    FPSBoostEnabled = false,
    
    -- Другое
    CachedCoins = {},
}

-- ==========================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ==========================================

-- Обновление персонажа
local function UpdateCharacter()
    Character = LocalPlayer.Character
    if Character then
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    end
end

LocalPlayer.CharacterAdded:Connect(UpdateCharacter)

-- Получить текущую роль игрока
local function GetPlayerRole()
    if not LocalPlayer then return nil end
    local playerData = LocalPlayer:FindFirstChild("PlayerData")
    if not playerData then return nil end
    local role = playerData:FindFirstChild("Role")
    return role and role.Value or nil
end

-- Проверка жизнеспособности персонажа
local function IsAlive()
    return Character and Humanoid and Humanoid.Health > 0 and HumanoidRootPart
end

-- ==========================================
-- COIN FARM ФУНКЦИИ
-- ==========================================

-- Получить все монеты
local function GetAllCoins()
    local coins = {}
    for _, coin in pairs(Workspace:GetDescendants()) do
        if coin:IsA("MeshPart") and coin.Name == "Coin" and coin:FindFirstChild("TouchInterest") then
            table.insert(coins, coin)
        end
    end
    return coins
end

-- Кеширование монет
local function CacheCoins()
    local currentTime = tick()
    if currentTime - State.LastCacheTime > 5 then
        State.CachedCoins = GetAllCoins()
        State.LastCacheTime = currentTime
    end
    return State.CachedCoins
end

-- Плавный полет к монете
local function SmoothFlyToCoin(coin, speed)
    if not IsAlive() or not coin or not coin.Parent then return false end
    
    local startTime = tick()
    local duration = 0.5
    local startPosition = HumanoidRootPart.Position
    local targetPosition = coin.Position
    
    -- Применение Underground оффсета
    if State.UndergroundMode then
        targetPosition = targetPosition - Vector3.new(0, State.UndergroundOffset, 0)
    end
    
    while tick() - startTime < duration do
        if not IsAlive() or not coin or not coin.Parent then return false end
        
        local t = (tick() - startTime) / duration
        local currentPos = startPosition:Lerp(targetPosition, t)
        HumanoidRootPart.CFrame = CFrame.new(currentPos)
        task.wait()
    end
    
    HumanoidRootPart.CFrame = CFrame.new(targetPosition)
    return true
end

-- Старт автофарма
local function StartAutoFarm()
    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end
    
    if not State.AutoFarmEnabled then return end
    
    State.CoinBlacklist = {}
    
    -- Включаем GodMode если нужно
    if State.GodModeWithAutoFarm and not State.GodModeEnabled then
        pcall(function()
            State.GodModeEnabled = true
            if Humanoid then
                Humanoid:ChangeState(11)
            end
        end)
    end
    
    State.CoinFarmThread = task.spawn(function()
        print("[Auto Farm] ▶ Запущен!")
        
        while State.AutoFarmEnabled do
            if IsAlive() then
                local coins = CacheCoins()
                local closestCoin = nil
                local closestDistance = math.huge
                
                for _, coin in pairs(coins) do
                    if coin and coin.Parent and not State.CoinBlacklist[coin] then
                        local distance = (HumanoidRootPart.Position - coin.Position).Magnitude
                        if distance < closestDistance then
                            closestDistance = distance
                            closestCoin = coin
                        end
                    end
                end
                
                if closestCoin then
                    local success = SmoothFlyToCoin(closestCoin, State.CoinFarmFlySpeed)
                    if not success then
                        State.CoinBlacklist[closestCoin] = true
                    end
                    task.wait(State.CoinFarmDelay / 10)
                else
                    task.wait(State.CoinFarmDelay)
                end
            else
                task.wait(1)
            end
        end
        
        print("[Auto Farm] ■ Остановлен")
    end)
end

-- Остановка автофарма
local function StopAutoFarm()
    State.AutoFarmEnabled = false
    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end
end

-- ==========================================
-- HP FARM ФУНКЦИИ
-- ==========================================

local function StartHPFarm()
    if State.HPFarmThread then
        task.cancel(State.HPFarmThread)
        State.HPFarmThread = nil
    end
    
    if not State.HPFarmEnabled then return end
    
    State.HPFarmThread = task.spawn(function()
        print("[HP Farm] ▶ Запущен!")
        
        while State.HPFarmEnabled do
            if IsAlive() and Humanoid and Humanoid.Health < Humanoid.MaxHealth then
                -- Восстановление HP
                Humanoid.Health = Humanoid.MaxHealth
            end
            task.wait(0.1)
        end
        
        print("[HP Farm] ■ Остановлен")
    end)
end

local function StopHPFarm()
    State.HPFarmEnabled = false
    if State.HPFarmThread then
        task.cancel(State.HPFarmThread)
        State.HPFarmThread = nil
    end
end

-- ==========================================
-- INSTANT PICKUP ФУНКЦИИ
-- ==========================================

local function StartInstantPickup()
    if State.InstantPickupThread then
        task.cancel(State.InstantPickupThread)
        State.InstantPickupThread = nil
    end
    
    if not State.InstantPickupEnabled then return end
    
    State.InstantPickupThread = task.spawn(function()
        print("[Instant Pickup] ▶ Запущен!")
        
        while State.InstantPickupEnabled do
            pcall(function()
                local role = GetPlayerRole()
                if role == "Murderer" then
                    -- Поиск ножа и перемещение к нему
                    local knife = Workspace:FindFirstChild("Knife", true)
                    if knife and knife:FindFirstChild("Handle") then
                        firetouchinterest(HumanoidRootPart, knife.Handle, 0)
                        firetouchinterest(HumanoidRootPart, knife.Handle, 1)
                    end
                elseif role == "Sheriff" then
                    -- Поиск пистолета
                    local gun = Workspace:FindFirstChild("GunDrop", true)
                    if gun and gun:FindFirstChild("Handle") then
                        firetouchinterest(HumanoidRootPart, gun.Handle, 0)
                        firetouchinterest(HumanoidRootPart, gun.Handle, 1)
                    end
                end
            end)
            task.wait(0.1)
        end
        
        print("[Instant Pickup] ■ Остановлен")
    end)
end

local function StopInstantPickup()
    State.InstantPickupEnabled = false
    if State.InstantPickupThread then
        task.cancel(State.InstantPickupThread)
        State.InstantPickupThread = nil
    end
end

-- ==========================================
-- NOCLIP ФУНКЦИИ
-- ==========================================

local function ToggleNoclip(enabled)
    State.NoclipEnabled = enabled
    
    if State.NoclipConnection then
        State.NoclipConnection:Disconnect()
        State.NoclipConnection = nil
    end
    
    if enabled then
        State.NoclipConnection = RunService.Stepped:Connect(function()
            if IsAlive() and Character then
                for _, part in pairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        print("[Noclip] ▶ Включен")
    else
        if Character then
            for _, part in pairs(Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
        print("[Noclip] ■ Выключен")
    end
end

-- ==========================================
-- GODMODE ФУНКЦИИ
-- ==========================================

local function ToggleGodMode(enabled)
    State.GodModeEnabled = enabled
    
    if State.GodModeConnection then
        State.GodModeConnection:Disconnect()
        State.GodModeConnection = nil
    end
    
    if enabled then
        State.GodModeConnection = RunService.Stepped:Connect(function()
            if IsAlive() and Humanoid then
                Humanoid:ChangeState(11)
            end
        end)
        print("[GodMode] ▶ Включен")
    else
        print("[GodMode] ■ Выключен")
    end
end

-- ==========================================
-- ANTI-FLING ФУНКЦИИ
-- ==========================================

local function ToggleAntiFling(enabled)
    State.AntiFlingEnabled = enabled
    
    if State.AntiFlingConnection then
        State.AntiFlingConnection:Disconnect()
        State.AntiFlingConnection = nil
    end
    
    if enabled then
        State.AntiFlingConnection = RunService.Heartbeat:Connect(function()
            if IsAlive() and HumanoidRootPart then
                local velocity = HumanoidRootPart.AssemblyLinearVelocity
                if velocity.Magnitude > 50 then
                    HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    HumanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end
        end)
        print("[Anti-Fling] ▶ Включен")
    else
        print("[Anti-Fling] ■ Выключен")
    end
end

-- ==========================================
-- FPS BOOST ФУНКЦИИ
-- ==========================================

local function ToggleFPSBoost(enabled)
    State.FPSBoostEnabled = enabled
    
    if enabled then
        -- Удаляем эффекты и текстуры для повышения FPS
        for _, obj in pairs(Workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                end
                if obj:IsA("MeshPart") or obj:IsA("Part") or obj:IsA("UnionOperation") then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                end
                if obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = 1
                end
            end)
        end
        
        -- Отключаем тени и эффекты освещения
        local lighting = game:GetService("Lighting")
        pcall(function()
            lighting.GlobalShadows = false
            lighting.FogEnd = 9e9
            lighting.Brightness = 0
            settings().Rendering.QualityLevel = "Level01"
        end)
        
        print("[FPS Boost] ▶ Включен")
    else
        -- Восстановление настроек
        local lighting = game:GetService("Lighting")
        pcall(function()
            lighting.GlobalShadows = true
            lighting.Brightness = 2
            settings().Rendering.QualityLevel = "Automatic"
        end)
        
        print("[FPS Boost] ■ Выключен")
    end
end

-- ==========================================
-- REJOIN ФУНКЦИИ
-- ==========================================

local function Rejoin()
    local ts = TeleportService
    local p = LocalPlayer
    
    print("[Rejoin] ↻ Переподключение...")
    
    ts:Teleport(game.PlaceId, p)
end

-- ==========================================
-- SERVERHOP ФУНКЦИИ
-- ==========================================

local function ServerHop()
    print("[ServerHop] 🔄 Поиск нового сервера...")
    
    local Http = game:GetService("HttpService")
    local TPS = TeleportService
    local Api = "https://games.roblox.com/v1/games/"
    
    local _place = game.PlaceId
    local _servers = Api.._place.."/servers/Public?sortOrder=Asc&limit=100"
    
    local function ListServers(cursor)
        local Raw = game:HttpGet(_servers .. ((cursor and "&cursor="..cursor) or ""))
        return Http:JSONDecode(Raw)
    end
    
    local Server, Next
    repeat
        local Servers = ListServers(Next)
        Server = Servers.data[math.random(1, #Servers.data)]
        Next = Servers.nextPageCursor
    until Server
    
    TPS:TeleportToPlaceInstance(_place, Server.id, LocalPlayer)
end

-- ==========================================
-- ПУБЛИЧНЫЙ API
-- ==========================================

local AutoFarm = {}

-- Auto Farm
function AutoFarm:ToggleAutoFarm(enabled)
    State.AutoFarmEnabled = enabled
    if enabled then
        StartAutoFarm()
    else
        StopAutoFarm()
    end
end

function AutoFarm:SetFlySpeed(speed)
    State.CoinFarmFlySpeed = speed
end

function AutoFarm:SetFarmDelay(delay)
    State.CoinFarmDelay = delay
end

function AutoFarm:ToggleUndergroundMode(enabled)
    State.UndergroundMode = enabled
end

function AutoFarm:SetUndergroundOffset(offset)
    State.UndergroundOffset = offset
end

function AutoFarm:ToggleGodModeWithAutoFarm(enabled)
    State.GodModeWithAutoFarm = enabled
end

-- HP Farm
function AutoFarm:ToggleHPFarm(enabled)
    State.HPFarmEnabled = enabled
    if enabled then
        StartHPFarm()
    else
        StopHPFarm()
    end
end

-- Instant Pickup
function AutoFarm:ToggleInstantPickup(enabled)
    State.InstantPickupEnabled = enabled
    if enabled then
        StartInstantPickup()
    else
        StopInstantPickup()
    end
end

-- Noclip
function AutoFarm:ToggleNoclip(enabled)
    ToggleNoclip(enabled)
end

-- GodMode
function AutoFarm:ToggleGodMode(enabled)
    ToggleGodMode(enabled)
end

-- Anti-Fling
function AutoFarm:ToggleAntiFling(enabled)
    ToggleAntiFling(enabled)
end

-- FPS Boost
function AutoFarm:ToggleFPSBoost(enabled)
    ToggleFPSBoost(enabled)
end

-- Rejoin & ServerHop
function AutoFarm:Rejoin()
    Rejoin()
end

function AutoFarm:ServerHop()
    ServerHop()
end

-- Получение состояния
function AutoFarm:GetState()
    return State
end

return AutoFarm
