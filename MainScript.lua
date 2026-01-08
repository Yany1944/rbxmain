-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 1: INITIALIZATION & PROTECTION (СТРОКИ 1-70)
-- ══════════════════════════════════════════════════════════════════════════════

--if game.PlaceId ~= 142823291 then return end

-- Loadstring Emotes (строка 3)
loadstring(game:HttpGet("https://raw.githubusercontent.com/Yany1944/rbxmain/refs/heads/main/Emotes.lua"))()

-- Game.Loaded проверка (строка 5-7)
if not game:IsLoaded() then game.Loaded:Wait() end

-- Защита от повторного запуска (строка 9-12)
if getgenv().MM2_ESP_Script then return end
getgenv().MM2_ESP_Script = true

-- CoreGui Toggle Fix (строка 13-31)
pcall(function()
    local StarterGui = game:GetService("StarterGui")
    -- Отключаем CoreGui
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

-- Warn/Error Override (строка 34-62)
local oldWarn = warn
local oldError = error

warn = function(...)
    local msg = tostring(...)
    if msg:match("useSliderMotionStates") or msg:match("CorePackages") or msg:match("Slider") then
        return
    end
    return oldWarn(...)
end

error = function(msg, level)
    if type(msg) == "string" then
        if msg:match("useSliderMotionStates") or msg:match("CorePackages") or msg:match("Slider") then
            return
        end
    end
    return oldError(msg, level)
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 2: CONFIG & SERVICES (СТРОКИ 65-115)
-- ══════════════════════════════════════════════════════════════════════════════

local CONFIG = {
        HideKey = Enum.KeyCode.Q,
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
    
    -- Combat
    ExtendedHitboxSize = 15,
    ExtendedHitboxEnabled = false,
    KillAuraDistance = 2.5,
    spawnAtPlayer = false,
    CanShootMurderer = true,
    ShootCooldown = 3,
    
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
    
    -- Role detection
    prevMurd = nil,
    prevSher = nil,
    heroSent = false,
    roundStart = true,
    roundActive = false,
    
    -- ESP internals
    PlayerHighlights = {},
    GunCache = {},

    -- Ping chams
    PingChamsEnabled = false,
    PingChamsBuffer = {},
    PingChamsRTT = 0.2,
    PingChamsLastPingUpdate = 0,
    PingChamsPingBuf = {},
    PingChamsGhostModel = nil,
    PingChamsGhostPart = nil,
    PingChamsGUI = nil,
    PingChamsGuiAnchor = nil,
    PingChamsGhostClone = nil,
    PingChamsGhostMap = {},
    PingChamsRenderConn = nil,
    
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
    
    -- Trolling
    OrbitEnabled = false,
    OrbitThread = nil,
    OrbitAngle = 0,
    OrbitRadius = 5,
    OrbitSpeed = 2,
    OrbitHeight = 0,
    OrbitTilt = 0,
    LoopFlingEnabled = false,
    LoopFlingThread = nil,
    BlockPathEnabled = false,
    BlockPathThread = nil,
    BlockPathPosition = 0,
    BlockPathSpeed = 0.2,
    BlockPathDirection = 1,
    
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
        InstantKillAll = Enum.KeyCode.Unknown
    }
}

local currentMapConnection = nil
local currentMap = nil

-- ============= PING CHAMS SYSTEM =============
local PINGCHAMS_BUFFERMAXSECONDS = 3.0
local PINGCHAMS_PINGUPDATEINTERVAL = 0.2
local Accent = Color3.fromRGB(220, 145, 230)

local PINGCHAMS_SETTINGS = {
    material = Enum.Material.ForceField,
    rttMultiplier = 0.5,
    serverPhysicsDelay = 0.050,
    clientInterpolation = 0.033,
    extraSafety = 0.010,
}

local function PingChams_median(tbl)
    if not tbl or type(tbl) ~= "table" or #tbl == 0 then return nil end
    local copy = {}
    for i = 1, #tbl do copy[i] = tbl[i] end
    table.sort(copy)
    local n = #copy
    return n % 2 == 1 and copy[(n+1)/2] or (copy[n/2] + copy[n/2+1]) * 0.5
end

local function PingChams_pushPing(sec)
    table.insert(State.PingChamsPingBuf, sec)
    if #State.PingChamsPingBuf > 20 then
        table.remove(State.PingChamsPingBuf, 1)
    end
end

local function PingChams_probePingMsStats()
    local ms
    local okPS, ps = pcall(function() return game:GetService("Stats").PerformanceStats end)
    if okPS and ps and typeof(ps.Ping) == "number" and ps.Ping > 0 then
        ms = ps.Ping
    end
    if not ms then
        local okItem, item = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"] end)
        if okItem and item then
            local okStr, s = pcall(function() return item:GetValueString() end)
            if okStr and s and tonumber(s) then
                ms = tonumber(s)
            else
                local okVal, v = pcall(function() return item:GetValue() end)
                if okVal and typeof(v) == "number" then ms = v end
            end
        end
    end
    return ms
end

local function PingChams_updatePing()
    local now = tick()
    if now - State.PingChamsLastPingUpdate < PINGCHAMS_PINGUPDATEINTERVAL then return end
    State.PingChamsLastPingUpdate = now
    
    local ms = PingChams_probePingMsStats()
    if ms then
        local sec = math.clamp(ms * 0.001, 0.002, 1.0)
        PingChams_pushPing(sec)
        local med = PingChams_median(State.PingChamsPingBuf)
        local alpha = #State.PingChamsPingBuf >= 5 and 0.25 or 0.5
        if med then
            State.PingChamsRTT = State.PingChamsRTT * (1 - alpha) + med * alpha
        else
            State.PingChamsRTT = sec
        end
    end
end

local function PingChams_sizeFromCharacter(char)
    if not char then return Vector3.new(4,6,2) end
    local ok, size = pcall(function() return char:GetExtentsSize() end)
    if ok and size then
        return Vector3.new(math.max(2, size.X), math.max(3, size.Y), math.max(1, size.Z))
    end
    return Vector3.new(4,6,2)
end

local function PingChams_collectRigParts(char)
    local parts = {}
    if not char then return parts end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
            table.insert(parts, d)
        end
    end
    return parts
end

local function PingChams_getRootPart(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or 
           char:FindFirstChild("Torso") or 
           char:FindFirstChild("UpperTorso") or 
           char:FindFirstChild("LowerTorso")
end

local function PingChams_clearGhostClone()
    State.PingChamsGhostMap = {}
    if State.PingChamsGhostClone then
        pcall(function() State.PingChamsGhostClone:Destroy() end)
        State.PingChamsGhostClone = nil
    end
end

local function PingChams_rebuildGhostClone(char, col, trans)
    PingChams_clearGhostClone()
    State.PingChamsGhostClone = Instance.new("Model")
    State.PingChamsGhostClone.Name = "GhostClone"
    State.PingChamsGhostClone.Parent = State.PingChamsGhostModel
    
    local parts = PingChams_collectRigParts(char)
    for _, src in ipairs(parts) do
        local gp
        if src:IsA("MeshPart") or src:IsA("Part") then
            gp = src:Clone()
            for _, d in ipairs(gp:GetDescendants()) do
                if d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Motor6D") then
                    pcall(function() d:Destroy() end)
                end
            end
            gp.Size = gp.Size * 1.03
        else
            gp = Instance.new("Part")
            gp.Size = src.Size * 1.03
        end
        
        gp.Name = "Ghost_"..src.Name
        gp.Anchored = true
        gp.CanCollide = false
        gp.CanQuery = false
        gp.CanTouch = false
        gp.CastShadow = false
        gp.Material = PINGCHAMS_SETTINGS.material
        gp.Color = col
        gp.Transparency = trans
        gp.Parent = State.PingChamsGhostClone
        
        State.PingChamsGhostMap[src.Name] = gp
    end
end

local function PingChams_ensureGhost()
    if not State.PingChamsGhostModel then
        State.PingChamsGhostModel = Instance.new("Model")
        State.PingChamsGhostModel.Name = "ServerApproxGhost"
        State.PingChamsGhostModel.Parent = workspace
    end
    
    if not State.PingChamsGhostPart then
        State.PingChamsGhostPart = Instance.new("Part")
        State.PingChamsGhostPart.Name = "ServerApproxPart"
        State.PingChamsGhostPart.Anchored = true
        State.PingChamsGhostPart.CanCollide = false
        State.PingChamsGhostPart.CanQuery = false
        State.PingChamsGhostPart.CanTouch = false
        State.PingChamsGhostPart.Transparency = 1
        State.PingChamsGhostPart.Size = PingChams_sizeFromCharacter(LocalPlayer.Character)
        State.PingChamsGhostPart.Parent = State.PingChamsGhostModel
    end
    
    if not State.PingChamsGuiAnchor then
        State.PingChamsGuiAnchor = Instance.new("Part")
        State.PingChamsGuiAnchor.Name = "GuiAnchor"
        State.PingChamsGuiAnchor.Anchored = true
        State.PingChamsGuiAnchor.CanCollide = false
        State.PingChamsGuiAnchor.CanQuery = false
        State.PingChamsGuiAnchor.CanTouch = false
        State.PingChamsGuiAnchor.Transparency = 1
        State.PingChamsGuiAnchor.Size = Vector3.new(1, 1, 1)
        State.PingChamsGuiAnchor.Parent = State.PingChamsGhostModel
    end
    
    if not State.PingChamsGUI then
        State.PingChamsGUI = Instance.new("BillboardGui")
        State.PingChamsGUI.Name = "PingInfo"
        State.PingChamsGUI.Size = UDim2.new(0, 180, 0, 30)
        State.PingChamsGUI.Adornee = State.PingChamsGuiAnchor
        State.PingChamsGUI.StudsOffset = Vector3.new(0, 0.7, 0)
        State.PingChamsGUI.AlwaysOnTop = true
        State.PingChamsGUI.Parent = State.PingChamsGhostModel
        
        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextScaled = false
        lbl.TextSize = 14
        lbl.TextColor3 = Accent
        lbl.Text = "Ping -- ms"
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        lbl.Parent = State.PingChamsGUI
    end
end

local function PingChams_captureOffsets(char, root)
    local map = {}
    if not char or not root then return map end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d ~= root then
            pcall(function()
                map[d.Name] = root.CFrame:ToObjectSpace(d.CFrame)
            end)
        end
    end
    return map
end

local function PingChams_pushSample(tClient, char)
    local root = PingChams_getRootPart(char)
    if not root then return end
    
    local offsets = PingChams_captureOffsets(char, root)
    local vel = Vector3.new()
    
    local ok1, v = pcall(function() return root.AssemblyLinearVelocity end)
    if ok1 and typeof(v) == "Vector3" then vel = v end
    
    table.insert(State.PingChamsBuffer, {
        t = tClient,
        cf = root.CFrame,
        offsets = offsets,
        vel = vel
    })
    
    local cutoff = tClient - PINGCHAMS_BUFFERMAXSECONDS
    while #State.PingChamsBuffer > 0 and State.PingChamsBuffer[1].t < cutoff do
        table.remove(State.PingChamsBuffer, 1)
    end
end

local function PingChams_lerpCFrame(a, b, alpha)
    local pos = a.Position:Lerp(b.Position, alpha)
    local ax, ay, az = a:ToOrientation()
    local bx, by, bz = b:ToOrientation()
    local dx = math.atan2(math.sin(bx - ax), math.cos(bx - ax))
    local dy = math.atan2(math.sin(by - ay), math.cos(by - ay))
    local dz = math.atan2(math.sin(bz - az), math.cos(bz - az))
    local rx = ax + dx * alpha
    local ry = ay + dy * alpha
    local rz = az + dz * alpha
    return CFrame.new(pos) * CFrame.fromOrientation(rx, ry, rz)
end

local function PingChams_sampleAtClientTime(target)
    if #State.PingChamsBuffer == 0 then return nil end
    
    for i = 1, #State.PingChamsBuffer do
        local s = State.PingChamsBuffer[i]
        if s.t >= target then
            local p = State.PingChamsBuffer[math.max(i-1, 1)]
            local n = s
            
            if p.t == n.t then
                return {root = p.cf, offsets = p.offsets}
            end
            
            local alpha = math.clamp((target - p.t) / (n.t - p.t), 0, 1)
            local cf = PingChams_lerpCFrame(p.cf, n.cf, alpha)
            local offsets = {}
            
            if p.offsets or n.offsets then
                for name, aOff in pairs(p.offsets or {}) do
                    local bOff = n.offsets and n.offsets[name] or aOff
                    offsets[name] = PingChams_lerpCFrame(aOff, bOff, alpha)
                end
                for name, bOff in pairs(n.offsets or {}) do
                    if not offsets[name] then
                        local aOff = p.offsets and p.offsets[name] or bOff
                        offsets[name] = PingChams_lerpCFrame(aOff, bOff, alpha)
                    end
                end
            end
            
            return {root = cf, offsets = offsets}
        end
    end
    
    local last = State.PingChamsBuffer[#State.PingChamsBuffer]
    return {root = last.cf, offsets = last.offsets}
end

local function StartPingChams()
    if State.PingChamsRenderConn then return end
    
    State.PingChamsRenderConn = RunService.RenderStepped:Connect(function()
        pcall(function()
            if not State.PingChamsEnabled then return end
            
            PingChams_updatePing()
            PingChams_ensureGhost()
            
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if not State.PingChamsGhostModel or State.PingChamsGhostClone == nil then
                        PingChams_rebuildGhostClone(char, Accent, 0.6)
                    end
                    PingChams_pushSample(tick(), char)
                end
                
                if State.PingChamsGhostPart then
                    local sz = PingChams_sizeFromCharacter(char)
                    State.PingChamsGhostPart.Size = sz
                end
            end
            
            local oneWayLatency = State.PingChamsRTT * 0.5
            local serverPhysicsDelay = 0.050
            local clientBuffer = 0.020
            local totalDelay = oneWayLatency + serverPhysicsDelay + clientBuffer
            local sampleDelay = math.clamp(totalDelay, 0.06, 0.9)
            
            local now = tick()
            local samplePast = PingChams_sampleAtClientTime(now - sampleDelay)
            
            if not State.PingChamsGhostClone and LocalPlayer.Character then
                PingChams_rebuildGhostClone(LocalPlayer.Character, Accent, 0.6)
            end
            
            if samplePast and samplePast.root then
                local rootPast = samplePast.root
                
                local lastSmoothT = _G.GhostPastSmoothT or tick()
                local nowT = tick()
                local dtSmooth = math.max(0.0001, nowT - lastSmoothT)
                local smoothAlpha = math.clamp(dtSmooth * 10, 0.12, 0.55)
                _G.GhostPastSmooth = _G.GhostPastSmooth or rootPast
                _G.GhostPastSmooth = PingChams_lerpCFrame(_G.GhostPastSmooth, rootPast, smoothAlpha)
                _G.GhostPastSmoothT = nowT
                
                if State.PingChamsGhostPart then
                    State.PingChamsGhostPart.CFrame = _G.GhostPastSmooth
                end
                
                if State.PingChamsGuiAnchor then
                    local yOffset = State.PingChamsGhostPart and (State.PingChamsGhostPart.Size.Y / 2 + 0.5) or 3.5
                    local guiPos = _G.GhostPastSmooth.Position + Vector3.new(0, yOffset, 0)
                    State.PingChamsGuiAnchor.CFrame = CFrame.new(guiPos)
                end
                
                local lpRoot = PingChams_getRootPart(LocalPlayer.Character)
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                local speedMeas = lpRoot and lpRoot.AssemblyLinearVelocity.Magnitude or 0
                local speedIntent = 0
                if hum and hum.MoveDirection.Magnitude > 0.01 then
                    speedIntent = hum.MoveDirection.Magnitude * (hum.WalkSpeed or 16)
                end
                local speed = math.max(speedMeas, speedIntent)
                
                local transPast = math.clamp(0.9 - math.min(speed / 16, 1) * 0.65, 0.2, 1)
                
                local lastFadeT = _G.GhostPastTransT or tick()
                local nowFadeT = tick()
                local dt = math.max(0.0001, nowFadeT - lastFadeT)
                local a = math.clamp(dt * 5.0, 0.05, 0.5)
                _G.GhostPastTransSm = _G.GhostPastTransSm or transPast
                _G.GhostPastTransSm = _G.GhostPastTransSm + (transPast - _G.GhostPastTransSm) * a
                _G.GhostPastTransT = nowFadeT
                
                for name, gp in pairs(State.PingChamsGhostMap) do
                    local off = samplePast.offsets and samplePast.offsets[name]
                    gp.Color = Accent
                    gp.Transparency = _G.GhostPastTransSm
                    gp.Material = PINGCHAMS_SETTINGS.material
                    if off then
                        gp.CFrame = _G.GhostPastSmooth * off
                    end
                end
                
                if State.PingChamsGUI and State.PingChamsGUI:FindFirstChild("Label") then
                    local realBacktrack = totalDelay * 1000
                    State.PingChamsGUI.Label.Text = string.format("Backtrack: %.0f ms | Ping: %.0f ms", realBacktrack, State.PingChamsRTT * 1000)
                    State.PingChamsGUI.Label.TextColor3 = Accent
                    
                    local vis = math.clamp((speed - 14) / 1, 0, 1)
                    local targetTT = 1 - vis
                    
                    local lastTT = _G.GhostTextTransT or tick()
                    local nowTT = tick()
                    local dtTT = math.max(0.0001, nowTT - lastTT)
                    local aTT = math.clamp(dtTT * 3, 0.03, 0.25)
                    _G.GhostTextTransSm = _G.GhostTextTransSm or targetTT
                    _G.GhostTextTransSm = _G.GhostTextTransSm + (targetTT - _G.GhostTextTransSm) * aTT
                    _G.GhostTextTransT = nowTT
                    
                    State.PingChamsGUI.Label.TextTransparency = _G.GhostTextTransSm
                    State.PingChamsGUI.Label.TextStrokeTransparency = _G.GhostTextTransSm
                    State.PingChamsGUI.Enabled = _G.GhostTextTransSm < 0.995
                end
            else
                for _, gp in pairs(State.PingChamsGhostMap) do
                    gp.Transparency = 1
                end
            end
            
            if not State.PingChamsEnabled then
                if State.PingChamsGUI and State.PingChamsGUI:FindFirstChild("Label") then
                    State.PingChamsGUI.Label.Visible = false
                end
                for _, gp in pairs(State.PingChamsGhostMap) do
                    gp.Transparency = 1
                end
            end
        end)
    end)
end

local function StopPingChams()
    if State.PingChamsRenderConn then
        State.PingChamsRenderConn:Disconnect()
        State.PingChamsRenderConn = nil
    end
    if State.PingChamsGUI then
        pcall(function() State.PingChamsGUI:Destroy() end)
        State.PingChamsGUI = nil
    end
    if State.PingChamsGuiAnchor then
        pcall(function() State.PingChamsGuiAnchor:Destroy() end)
        State.PingChamsGuiAnchor = nil
    end
    if State.PingChamsGhostModel then
        pcall(function() State.PingChamsGhostModel:Destroy() end)
        State.PingChamsGhostModel = nil
        State.PingChamsGhostClone = nil
    end
    State.PingChamsGhostMap = {}
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    pcall(function()
        if State.PingChamsGhostPart and LocalPlayer.Character then
            State.PingChamsGhostPart.Size = PingChams_sizeFromCharacter(LocalPlayer.Character)
        end
    end)
end)


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 4: SYSTEM FUNCTIONS (СТРОКИ 253-410)
-- ══════════════════════════════════════════════════════════════════════════════

-- CleanupMemory() - Очистка при респавне
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

    -- Очистка gun ESP (только визуальные объекты)
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
    
    -- Очистка очереди уведомлений (безопасно)
    State.NotificationQueue = {}
    State.CurrentNotification = nil

    -- Очистка coin blacklist (безопасно - относится к Auto Farm)
    State.CoinBlacklist = {}

end

local function FullShutdown()
    print("[FullShutdown] Starting complete cleanup...")
    
    -- ✅ Остановка всех активных фич
    pcall(function()
        if State.AutoFarmEnabled then StopAutoFarm() end
        if State.XPFarmEnabled then StopXPFarm() end
        if State.NoClipEnabled then DisableNoClip() end
        if State.AntiFlingEnabled then DisableAntiFling() end
        if State.ExtendedHitboxEnabled then DisableExtendedHitbox() end
        if State.GodModeEnabled then ToggleGodMode() end
        if State.InstantPickupEnabled then DisableInstantPickup() end
        if killAuraCon then ToggleKillAura(false) end
    end)
    
    -- ✅ Остановка Trolling threads
    pcall(function()
        if State.OrbitThread then
            task.cancel(State.OrbitThread)
            State.OrbitThread = nil
        end
        if State.LoopFlingThread then
            task.cancel(State.LoopFlingThread)
            State.LoopFlingThread = nil
        end
        if State.BlockPathThread then
            task.cancel(State.BlockPathThread)
            State.BlockPathThread = nil
        end
        State.OrbitEnabled = false
        State.LoopFlingEnabled = false
        State.BlockPathEnabled = false
    end)
    
    -- ✅ Очистка ESP
    pcall(function()
        for _, highlight in pairs(State.PlayerHighlights) do
            if highlight and highlight.Parent then
                highlight:Destroy()
            end
        end
        State.PlayerHighlights = {}
    end)
    
    pcall(function()
        for _, espData in pairs(State.GunCache) do
            if espData then
                if espData.highlight then espData.highlight:Destroy() end
                if espData.billboard then espData.billboard:Destroy() end
            end
        end
        State.GunCache = {}
    end)
    
    -- ✅ Отключение Role Check Loop
    pcall(function()
        if State.RoleCheckLoop then
            State.RoleCheckLoop:Disconnect()
            State.RoleCheckLoop = nil
        end
    end)
    
    -- ✅ Отключение Gun Tracking
    pcall(function()
        if currentMapConnection then
            currentMapConnection:Disconnect()
            currentMapConnection = nil
        end
        currentMap = nil
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
                humanoid.WalkSpeed = 16
                humanoid.JumpPower = 50
            end
            
            local ff = character:FindFirstChild("ForceField")
            if ff then ff:Destroy() end
        end
        
        LocalPlayer.CameraMaxZoomDistance = 128
        
        local camera = Workspace.CurrentCamera
        if camera then
            camera.FieldOfView = 70
        end
    end)
    
    -- ✅ Восстановление FallenPartsDestroyHeight
    pcall(function()
        workspace.FallenPartsDestroyHeight = State.FPDH
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
    
    print("[FullShutdown] ✅ Complete!")
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
local afkModeActive = false
local fpsBoostActive = false
local uiOnlyActive = false
local savedUIState = {}
local savedUIOnlyState = {}  -- ← ИСПРАВЛЕНО: было nil
local savedSettings = {
    Lighting = {},
    Camera = {}
}
-- ==============================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ==============================

-- Функция применения UI оптимизации
local function ApplyUIOptimization()
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
        
        local coreGuiTypes = {
            Enum.CoreGuiType.PlayerList,
            Enum.CoreGuiType.Health,
            Enum.CoreGuiType.Backpack,
            Enum.CoreGuiType.Chat,
            Enum.CoreGuiType.EmotesMenu,
            Enum.CoreGuiType.SelfView
        }
        
        for _, guiType in ipairs(coreGuiTypes) do
            StarterGui:SetCoreGuiEnabled(guiType, false)
        end
    end)
    
    pcall(function()
        StarterGui:SetCore("TopbarEnabled", false)
    end)
    
    pcall(function()
        local targetTable = afkModeActive and savedUIState or savedUIOnlyState
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
    
    if afkModeActive then
        ApplyUIOptimization()
        pcall(function()
            RunService:Set3dRenderingEnabled(false)
        end)
    elseif uiOnlyActive then
        ApplyUIOptimization()
    end
end)
-- ==============================
-- AFK MODE FUNCTIONS
-- ==============================

EnableMaxOptimization = function()
    if afkModeActive then 
        return 
    end
    
    afkModeActive = true
    
    -- 1. ОТКЛЮЧЕНИЕ 3D РЕНДЕРИНГА
    pcall(function()
        RunService:Set3dRenderingEnabled(false)
    end)
    
    -- 2. ПОЛНОЕ ОТКЛЮЧЕНИЕ ВСЕХ GUI
    ApplyUIOptimization()
    
    -- 3. ОТКЛЮЧЕНИЕ ОСВЕЩЕНИЯ
    pcall(function()
        savedSettings.Lighting = {
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
                savedSettings.Lighting[effect.Name] = effect
                effect.Parent = nil
            end
        end
    end)
    
    -- 4. CAMERA OPTIMIZATION
    pcall(function()
        local camera = workspace.CurrentCamera
        if camera then
            savedSettings.Camera.FieldOfView = camera.FieldOfView
            camera.FieldOfView = 50
        end
    end)
    
    -- 5. RENDER DISTANCE
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(workspace, "StreamingMinRadius", 32)
            sethiddenproperty(workspace, "StreamingTargetRadius", 64)
        end
    end)
end

DisableMaxOptimization = function()
    if not afkModeActive then 
        return 
    end
    
    afkModeActive = false
    
    -- 1. ВКЛЮЧЕНИЕ 3D РЕНДЕРИНГА
    pcall(function()
        RunService:Set3dRenderingEnabled(true)
    end)
    
    -- 2. ВОССТАНОВЛЕНИЕ GUI
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
        
        task.wait(0.1)
        
        local coreGuiTypes = {
            Enum.CoreGuiType.PlayerList,
            Enum.CoreGuiType.Health,
            Enum.CoreGuiType.Backpack,
            Enum.CoreGuiType.Chat,
            Enum.CoreGuiType.EmotesMenu,
            Enum.CoreGuiType.SelfView
        }
        
        for _, guiType in ipairs(coreGuiTypes) do
            StarterGui:SetCoreGuiEnabled(guiType, true)
        end
    end)
    
    pcall(function()
        StarterGui:SetCore("TopbarEnabled", true)
    end)
    
    pcall(function()
        for gui, wasEnabled in pairs(savedUIState) do
            if gui and gui.Parent then
                gui.Enabled = wasEnabled
            end
        end
        savedUIState = {}
    end)
    
    -- 3. ВОССТАНОВЛЕНИЕ ОСВЕЩЕНИЯ
    pcall(function()
        if savedSettings.Lighting.GlobalShadows ~= nil then
            Lighting.GlobalShadows = savedSettings.Lighting.GlobalShadows
            Lighting.Brightness = savedSettings.Lighting.Brightness
            Lighting.Ambient = savedSettings.Lighting.Ambient
            Lighting.OutdoorAmbient = savedSettings.Lighting.OutdoorAmbient
            Lighting.FogEnd = savedSettings.Lighting.FogEnd
            Lighting.Technology = savedSettings.Lighting.Technology
            
            for name, effect in pairs(savedSettings.Lighting) do
                if typeof(effect) == "Instance" then
                    effect.Parent = Lighting
                end
            end
            
            savedSettings.Lighting = {}
        end
    end)
    
    -- 4. ВОССТАНОВЛЕНИЕ КАМЕРЫ
    pcall(function()
        local camera = workspace.CurrentCamera
        if camera and savedSettings.Camera.FieldOfView then
            camera.FieldOfView = savedSettings.Camera.FieldOfView
        end
    end)
end

local function EnableUIOnly()
    if uiOnlyActive then return end
    uiOnlyActive = true
    savedUIOnlyState = {}
    ApplyUIOptimization()
end

local function DisableUIOnly()
    if not uiOnlyActive then return end
    uiOnlyActive = false
    
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
        
        task.wait(0.1)
        
        local coreGuiTypes = {
            Enum.CoreGuiType.PlayerList,
            Enum.CoreGuiType.Health,
            Enum.CoreGuiType.Backpack,
            Enum.CoreGuiType.Chat,
            Enum.CoreGuiType.EmotesMenu,
            Enum.CoreGuiType.SelfView
        }
        
        for _, guiType in ipairs(coreGuiTypes) do
            StarterGui:SetCoreGuiEnabled(guiType, true)
        end
    end)
    
    pcall(function()
        StarterGui:SetCore("TopbarEnabled", true)
    end)
    
    pcall(function()
        -- ИСПРАВЛЕНО: проверка на пустую таблицу
        if savedUIOnlyState and next(savedUIOnlyState) ~= nil then
            for gui, wasEnabled in pairs(savedUIOnlyState) do
                if gui and gui.Parent then
                    gui.Enabled = wasEnabled
                end
            end
        end
        savedUIOnlyState = {}
    end)
end
-- ==============================
-- FPS BOOST FUNCTION
-- ==============================

local function EnableFPSBoost()
    if fpsBoostActive then
        return
    end
    
    fpsBoostActive = true
    
    -- 1. TERRAIN OPTIMIZATION
    pcall(function()
        local Terrain = workspace:FindFirstChildOfClass('Terrain')
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
        for _, v in pairs(workspace:GetDescendants()) do
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
    workspace.DescendantAdded:Connect(function(child)
        if not fpsBoostActive then return end
        
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


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 7: ROLE DETECTION (СТРОКИ 611-660)
-- ══════════════════════════════════════════════════════════════════════════════

local AntiFlingLastPos = Vector3.zero
local FlingDetectionConnection = nil
local FlingNeutralizerConnection = nil
local DetectedFlingers = {}
local FlingBlockedNotified = false

-- getMurder() - Поиск убийцы
local function getMurder()
    for _, plr in ipairs(Players:GetPlayers()) do
        local character = plr.Character
        local backpack = plr:FindFirstChild("Backpack")
        
        if (character and character:FindFirstChild("Knife")) or (backpack and backpack:FindFirstChild("Knife")) then
            return plr
        end
    end
    return nil
end

-- getSheriff() - Поиск шерифа
local function getSheriff()
    for _, plr in ipairs(Players:GetPlayers()) do
        local character = plr.Character
        local backpack = plr:FindFirstChild("Backpack")
        
        if (character and character:FindFirstChild("Gun")) or (backpack and backpack:FindFirstChild("Gun")) then
            return plr
        end
    end
    return nil
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 8: ANTI-FLING (СТРОКИ 661-790)
-- ══════════════════════════════════════════════════════════════════════════════

-- EnableAntiFling() - Включение защиты от флинга
local function EnableAntiFling()
    if State.AntiFlingEnabled then return end
    State.AntiFlingEnabled = true

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
    

    FlingNeutralizerConnection = RunService.Heartbeat:Connect(function()
        local character = LocalPlayer.Character
        if character and character.PrimaryPart then
            local primaryPart = character.PrimaryPart
            if State.IsFlingInProgress then
                AntiFlingLastPos = primaryPart.Position
                return
            end
			
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

-- DisableAntiFling() - Отключение защиты
local function DisableAntiFling()
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

    local Character = LocalPlayer.Character
    if not Character then return end
    
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart
    if not RootPart then return end
    
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
        local newCFrame = CFrame.new(BasePart.Position) * Pos * Ang
        RootPart.CFrame = newCFrame  -- ✅ ИСПРАВЛЕНО: прямая установка вместо SetPrimaryPartCFrame
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
    while true do
        task.wait(1)
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
    -- Поиск шерифа (аналогично FindMurderer)
    local sheriff = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            local gun = player.Character:FindFirstChild("Gun")
            if gun then
                sheriff = player
                break
            end
            
            if player.Backpack then
                local gunInBackpack = player.Backpack:FindFirstChild("Gun")
                if gunInBackpack then
                    sheriff = player
                    break
                end
            end
        end
    end
    
    if not sheriff then
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">Sheriff not found</font>", CONFIG.Colors.Text)
        end
        return
    end
    
    -- Проверка: не флингим сам себя
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
    
    State.NoClipRespawnConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(0.15)
        
        table.clear(NoClipObjects)
        
        for _, obj in ipairs(newChar:GetChildren()) do
            if obj:IsA("BasePart") then
                table.insert(NoClipObjects, obj)
            end
        end
    end)
    
    State.NoClipConnection = RunService.Stepped:Connect(function()
        for i = 1, #NoClipObjects do
            NoClipObjects[i].CanCollide = false
        end
    end)
    
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

    -- УРОВЕНЬ 2: Попытка прямого пути с pcall защитой
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

    if success and coins > 0 then
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
    print("[Auto Farm] 🧹 Очистка CoinBlacklist...")
    local cleaned = 0
    for coin, _ in pairs(State.CoinBlacklist) do
        if not coin.Parent then
            State.CoinBlacklist[coin] = nil
            cleaned = cleaned + 1
        end
    end
    print(("[Auto Farm] 🧹 Удалено %d мёртвых ссылок"):format(cleaned))
end

-- ResetCharacter() - Ресет с сохранением GodMode
local function ResetCharacter()
    print("[Auto Farm] 🔄 Делаю ресет...")
    
    -- Сохраняем статус GodMode
    local wasGodModeEnabled = State.GodModeEnabled
    
    -- Отключаем GodMode перед ресетом
    if wasGodModeEnabled then
        print("[Auto Farm] 🛡️ GodMode был включен, временно отключаю...")
        State.GodModeEnabled = false
        
        -- Отключаем все connections
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
        
        for _, connection in ipairs(State.GodModeConnections) do
            if connection and connection.Connected then
                connection:Disconnect()
            end
        end
        State.GodModeConnections = {}
        
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
            -- Ждём появления персонажа
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            print("[Auto Farm] ⏳ Новый персонаж появился, жду Humanoid...")
            
            -- ✅ ЖДЁМ HUMANOID
            local humanoid = character:WaitForChild("Humanoid", 10)
            if not humanoid then
                print("[Auto Farm] ⚠️ Humanoid не найден за 10 секунд!")
                return
            end
            
            -- ✅ ДОПОЛНИТЕЛЬНАЯ ЗАДЕРЖКА
            task.wait(0.5)
            
            print("[Auto Farm] 🛡️ Humanoid найден, восстанавливаю GodMode...")
            
            -- Восстанавливаем GodMode
            State.GodModeEnabled = true
            
            if ApplyGodMode then
                ApplyGodMode()
            end
            if SetupHealthProtection then
                SetupHealthProtection()
            end
            if SetupDamageBlocker then
                SetupDamageBlocker()
            end
            
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
            
            print("[Auto Farm] ✅ GodMode восстановлен!")
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
    
    print("[Auto Farm] 🎈 Левитация включена")
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
    
    print("[Auto Farm] 🎈 Левитация выключена")
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
    
    while tick() - startTime < duration do
        if not State.AutoFarmEnabled then break end
        
        -- ✅ ПРОВЕРКА: существует ли монета
        if not coin or not coin.Parent then
            return false
        end
        
        -- ✅ ПРОВЕРКА: видима ли монета (CoinVisual.Transparency)
        local coinVisual = coin:FindFirstChild("CoinVisual")
        if not coinVisual or coinVisual.Transparency ~= 0 then
            return false
        end
        
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
    
    return true
end

local shootMurderer
local InstantKillAll
local knifeThrow
local ToggleGodMode 

local spawnAtPlayerOriginalState = false
local instantPickupWasEnabled = false

-- StartAutoFarm() - Запуск авто фарма (с интеграцией XP Farm)
local function StartAutoFarm()
    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end
    
    if not State.AutoFarmEnabled then return end
    
    State.CoinBlacklist = {}
    spawnAtPlayerOriginalState = State.spawnAtPlayer
    instantPickupWasEnabled = State.InstantPickupEnabled
    
    State.CoinFarmThread = task.spawn(function()
        print("[Auto Farm] 🚀 Запущен")
        if State.UndergroundMode then
            print("[Auto Farm] 🕳️ Режим под землёй: ВКЛ")
        end
        -- ✅ Включаем годмод при старте автофарма
        if State.GodModeWithAutoFarm and not State.GodModeEnabled then
            pcall(function()
                ToggleGodMode()  -- Включаем только если был выключен
            end)
            print("[Auto Farm] 🛡️ GodMode автоматически включен")
        end

        if State.XPFarmEnabled and not State.InstantPickupEnabled then
            pcall(function()
                EnableInstantPickup()
            end)
            print("[Auto Farm] 🔫 InstantPickup автоматически включен для XP Farm")
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
            
            local murdererExists = getMurder() ~= nil
            
            if not murdererExists then
                print("[Auto Farm] ⏳ Жду начала раунда...")
                State.CoinBlacklist = {}
                noCoinsAttempts = 0
                if State.spawnAtPlayer and not spawnAtPlayerOriginalState then
                    State.spawnAtPlayer = false
                end
                pcall(function()
                    UnfloatCharacter()
                end)
                task.wait(2)
                continue
            end
            
            local currentCoins = GetCollectedCoinsCount()
            
            if currentCoins >= 50 then
                print("[Auto Farm] ✅ Все 50 монет собраны!")
                noCoinsAttempts = maxNoCoinsAttempts
            else
                local coin = FindNearestCoin()
                
                if not coin then
                    noCoinsAttempts = noCoinsAttempts + 1
                    print("[Auto Farm] 🔍 Монета не найдена (попытка " .. noCoinsAttempts .. "/" .. maxNoCoinsAttempts .. ")")
                    
                    if noCoinsAttempts < maxNoCoinsAttempts then
                        task.wait(0.3)
                    end
                else
                    noCoinsAttempts = 0
                    
                    pcall(function()
                        if currentCoins < 1 then
                            local currentTime = tick()
                            local timeSinceLastTP = currentTime - lastTeleportTime
                            
                            if timeSinceLastTP < State.CoinFarmDelay and lastTeleportTime > 0 then
                                local waitTime = State.CoinFarmDelay - timeSinceLastTP
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
                                
                                task.wait(0.2)
                                
                                coinLabelCache = nil
                                local coinsAfter = GetCollectedCoinsCount()
                                if coinsAfter > currentCoins then
                                    print("[Auto Farm] ✅ Монета собрана (TP) | Всего: " .. coinsAfter)
                                end
                                
                                AddCoinToBlacklist(coin)
                            end
                        else
                            if State.UndergroundMode then
                                print("[Auto Farm] 🕳️ Полёт под землёй к монете")
                            else
                                print("[Auto Farm] ✈️ Полёт к монете")
                            end
                            
                            EnableNoClip()
                            SmoothFlyToCoin(coin, humanoidRootPart, State.CoinFarmFlySpeed)
                            
                            coinLabelCache = nil
                            local coinsAfter = GetCollectedCoinsCount()
                            if coinsAfter > currentCoins then
                                print("[Auto Farm] ✅ Монета собрана (Fly) | Всего: " .. coinsAfter)
                            end
                            
                            AddCoinToBlacklist(coin)
                        end
                    end)
                end
            end
            
            if noCoinsAttempts >= maxNoCoinsAttempts then
                print("[Auto Farm] ✅ Все доступные монеты собраны!")
                
                pcall(function()
                    DisableNoClip()
                end)
                
                if State.XPFarmEnabled then
                    print("[Auto Farm] ⏳ XP Farm включен, передаю управление...")
                    
                    currentCoins = GetCollectedCoinsCount()
                    print("[Auto Farm] 💰 Собрано монет: " .. currentCoins .. "/50")
                    
                    if currentCoins >= 50 then
                        character = LocalPlayer.Character
                        if character then
                            humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                            
                            if humanoidRootPart then
                                local safeSpot = FindSafeAFKSpot()
                                if safeSpot then
                                    humanoidRootPart.CFrame = safeSpot + Vector3.new(0, 5, 0)
                                    print("[XP Farm] 📍 Телепортировался в безопасное место")
                                    
                                    task.wait(0.5)
                                    local floatSuccess = FloatCharacter()
                                    if floatSuccess then
                                        print("[XP Farm] 🎈 Закрепление активировано")
                                    end
                                    
                                    task.wait(0.5)
                                end
                                
                                if State.XPFarmEnabled then
                                    local murderer = getMurder()
                                    local sheriff = getSheriff()
                                    
                                    if murderer == LocalPlayer then
                                        print("[XP Farm] 🔪 Мы мурдерер! Активирую knifeThrow...")
                                        
                                        -- ✅ Включаем spawnAtPlayer если был выключен
                                        if not State.spawnAtPlayer then
                                            State.spawnAtPlayer = true
                                            print("[XP Farm] ✅ spawnAtPlayer включен")
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
                                                print("[XP Farm] 🔪 Нож брошен (" .. throwAttempts .. "/" .. maxThrowAttempts .. ")")
                                            else
                                                print("[XP Farm] ❌ Ошибка броска ножа: " .. tostring(error))
                                            end
                                            
                                            task.wait(throwDelay)
                                        end
                                        
                                        -- ✅ Fallback: если после 30 попыток раунд не завершился
                                        if getMurder() ~= nil and State.AutoFarmEnabled and State.XPFarmEnabled then
                                            print("[XP Farm] ⚠️ knifeThrow не сработал за 10 попыток! Использую InstantKillAll...")
                                            
                                            local success, error = pcall(function()
                                                InstantKillAll()
                                            end)
                                            
                                            if success then
                                                print("[XP Farm] ✅ InstantKillAll выполнен успешно!")
                                            else
                                                print("[XP Farm] ❌ InstantKillAll ошибка: " .. tostring(error))
                                            end
                                        else
                                            print("[XP Farm] ✅ Раунд завершён через knifeThrow или XP Farm отключен")
                                        end
                                                                    
                                    elseif sheriff == LocalPlayer then
                                            print("[XP Farm] 🔫 Мы шериф, стреляем в мурдерера...")
                                            
                                            local shootAttempts = 0
                                            local maxShootAttempts = 30

                                            while getMurder() ~= nil and State.AutoFarmEnabled and State.XPFarmEnabled and shootAttempts < maxShootAttempts do
                                                character = LocalPlayer.Character
                                                if not character then 
                                                    print("[XP Farm] ⚠️ Персонаж исчез, прекращаю стрельбу")
                                                    break 
                                                end
                                                
                                                local murdererPlayer = getMurder()
                                                if not murdererPlayer then 
                                                    print("[XP Farm] ✅ Раунд завершён! Мурдерер мёртв.")
                                                    break 
                                                end
                                                
                                                -- ✅ Проверяем существование персонажа мурдерера
                                                local murdererChar = murdererPlayer.Character
                                                if not murdererChar then 
                                                    print("[XP Farm] ⚠️ У мурдерера нет персонажа, жду...")
                                                    task.wait(0.5)
                                                    continue 
                                                end
                                                
                                                -- ✅ Стреляем только если кулдаун готов
                                                if State.CanShootMurderer then
                                                    shootAttempts = shootAttempts + 1
                                                    
                                                    pcall(function()
                                                        shootMurderer(true) -- ✅ тихий режим, без спама уведомлениями
                                                    end)
                                                    
                                                    print("[XP Farm] 🎯 Выстрел #" .. shootAttempts .. " произведён")
                                                    task.wait(State.ShootCooldown + 0.1) -- ✅ учитываем реальный кулдаун с запасом
                                                else
                                                    -- Кулдаун ещё идёт – немного ждём
                                                    task.wait(0.5)
                                                end
                                            end

                                            -- ✅ Проверяем причину выхода из цикла
                                            if getMurder() == nil then
                                                print("[XP Farm] ✅ Мурдерер успешно убит! Раунд завершён.")
                                            elseif shootAttempts >= maxShootAttempts then
                                                print("[XP Farm] ⚠️ Достигнут лимит выстрелов (" .. maxShootAttempts .. "), прекращаю стрельбу")
                                            elseif not State.XPFarmEnabled then
                                                print("[XP Farm] ⚠️ XP Farm был отключен во время стрельбы")
                                            elseif not State.AutoFarmEnabled then
                                                print("[XP Farm] ⚠️ Auto Farm был отключен во время стрельбы")
                                            end
                                    else
                                        print("[XP Farm] 👤 Инносент | Флинг мурдерера")
                                        
                                        -- ✅ Сразу после закрепления - первый флинг
                                        pcall(function()
                                            FlingMurderer()
                                        end)
                                        print("[XP Farm] 💫 Первый флинг выполнен")
                                        task.wait(1)
                                        
                                        local flingAttempts = 1  -- Уже выполнили 1 флинг
                                        local maxFlingAttempts = 10
                                        
                                        while getMurder() ~= nil and State.AutoFarmEnabled and State.XPFarmEnabled and flingAttempts < maxFlingAttempts do
                                            local murdererPlayer = getMurder()
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
                                                    print("[XP Farm] ✅ Мурдерер уже сфлингован (velocity: " .. math.floor(velocity) .. ")!")
                                                    break
                                                elseif velocity > 100 then
                                                    print("[XP Farm] ⏭️ Мурдерер летит (velocity: " .. math.floor(velocity) .. "), пропускаю...")
                                                    task.wait(1)
                                                    continue
                                                end
                                            end
                                            
                                            pcall(function()
                                                FlingMurderer()
                                            end)
                                            
                                            flingAttempts = flingAttempts + 1
                                            print("[XP Farm] 💫 Флинг #" .. flingAttempts)
                                            
                                            task.wait(3)
                                            
                                            if getMurder() == nil then
                                                print("[XP Farm] ✅ Мурдерер был сфлингован!")
                                                break
                                            end
                                        end
                                        
                                        if not State.XPFarmEnabled then
                                            print("[XP Farm] ⚠️ XP Farm был отключен во время флинга")
                                        end
                                    end
                                else
                                    print("[XP Farm] ⚠️ XP Farm был отключен, пропускаю действия")
                                end
                            end
                        end
                    end
                end
                
                if State.XPFarmEnabled then
                    print("[Auto Farm] ⏳ XP Farm включен - жду смерти мурдерера...")
                    repeat
                        task.wait(1)
                    until getMurder() == nil or not State.AutoFarmEnabled
                    
                    if not State.AutoFarmEnabled then
                        print("[Auto Farm] ⚠️ Автофарм был выключен, выхожу из цикла...")
                        break
                    end
                    
                    pcall(function()
                        UnfloatCharacter()
                    end)
                    
                    print("[Auto Farm] 🎉 Мурдерер мёртв! Жду официального окончания раунда...")
                    CleanupCoinBlacklist()
                    task.wait(5)
                    
                    if getMurder() ~= nil then
                        print("[Auto Farm] ⚠️ Новый раунд уже начался! Пропускаю ресет...")
                        State.CoinBlacklist = {}
                        noCoinsAttempts = 0
                        continue
                    end
                    
                    print("[Auto Farm] 🔄 Раунд полностью закончился! Делаю ресет...")
                    
                    -- ✅ Выключаем годмод перед ресетом
                    if State.GodModeWithAutoFarm and State.GodModeEnabled then
                        pcall(function()
                            ToggleGodMode()  -- Выключаем
                        end)
                        print("[Auto Farm] 🛡️ GodMode временно выключен перед ресетом")
                    end

                    ResetCharacter()
                    State.CoinBlacklist = {}
                    noCoinsAttempts = 0

                    task.wait(3)

                    -- ✅ Включаем годмод после респавна
                    if State.GodModeWithAutoFarm then  -- ✅ БЕЗ проверки State.GodModeEnabled!
                        -- Ждём появления персонажа
                        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                        local humanoid = character:WaitForChild("Humanoid", 5)
                        
                        if humanoid then
                            task.wait(1)  -- Даём серверу инициализировать персонажа
                            
                            if not State.GodModeEnabled then  -- ✅ ТЕПЕРЬ проверяем
                                pcall(function()
                                    ToggleGodMode()  -- Включаем
                                end)
                                print("[Auto Farm] 🛡️ GodMode повторно включен после респавна")
                            end
                        end
                    end
                    
                    print("[Auto Farm] ⏳ Жду начала нового раунда...")
                    repeat
                        task.wait(1)
                    until getMurder() ~= nil or not State.AutoFarmEnabled
                    
                    if not State.AutoFarmEnabled then
                        print("[Auto Farm] ⚠️ Автофарм был выключен во время ожидания раунда")
                        break
                    end
                    
                    print("[Auto Farm] ✅ Новый раунд начался! Сбрасываю счётчики и продолжаю фарм...")
                    State.CoinBlacklist = {}
                    noCoinsAttempts = 0
                    
                else
                    print("[Auto Farm] 🔄 XP Farm выключен - делаю быстрый ресет без ожидания конца раунда...")
                    CleanupCoinBlacklist()
                    pcall(function()
                        UnfloatCharacter()
                    end)

                    -- ✅ Выключаем годмод перед ресетом
                    if State.GodModeWithAutoFarm and State.GodModeEnabled then
                        pcall(function()
                            ToggleGodMode()  -- Выключаем только если был включен автофармом
                        end)
                        print("[Auto Farm] 🛡️ GodMode автоматически выключен")
                    end

                    ResetCharacter()
                    State.CoinBlacklist = {}
                    noCoinsAttempts = 0

                    task.wait(3)

                    -- ✅ ИСПРАВЛЕННЫЙ КОД: Включаем годмод после респавна
                    if State.GodModeWithAutoFarm then  -- ✅ БЕЗ проверки State.GodModeEnabled!
                        -- Ждём появления персонажа
                        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                        local humanoid = character:WaitForChild("Humanoid", 5)

                        if humanoid then
                            task.wait(1)  -- Даём серверу инициализировать персонажа

                            if not State.GodModeEnabled then  -- ✅ ТЕПЕРЬ проверяем
                                pcall(function()
                                    ToggleGodMode()  -- Включаем
                                end)
                                print("[Auto Farm] 🛡️ GodMode повторно включен после респавна")
                            end
                        end
                    end

                    print("[Auto Farm] ⏳ Жду конца текущего раунда...")
                    repeat
                        task.wait(1)
                    until getMurder() == nil or not State.AutoFarmEnabled

                    if not State.AutoFarmEnabled then
                        print("[Auto Farm] ⚠️ Автофарм был выключен во время ожидания")
                        break
                    end

                    print("[Auto Farm] ⏳ Раунд закончился, жду начала нового раунда...")
                    repeat
                        task.wait(1)
                    until getMurder() ~= nil or not State.AutoFarmEnabled

                    if not State.AutoFarmEnabled then
                        print("[Auto Farm] ⚠️ Автофарм был выключен во время ожидания нового раунда")
                        break
                    end

                    print("[Auto Farm] ✅ Новый раунд начался! Сбрасываю счётчики и продолжаю фарм...")
                    State.CoinBlacklist = {}
                    noCoinsAttempts = 0
                end
            end
        end
        
        State.CoinFarmThread = nil
        print("[Auto Farm] 🛑 Остановлен")
    end)
end

-- ✅ ОБНОВЛЁННАЯ StopAutoFarm с правильным cleanup
local function StopAutoFarm()
    State.AutoFarmEnabled = false

    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end

    pcall(UnfloatCharacter)
    pcall(DisableNoClip)
    State.CoinBlacklist = {}
    
    State.spawnAtPlayer = spawnAtPlayerOriginalState
    
    -- ✅ ДОБАВИТЬ:
    if State.XPFarmEnabled and State.InstantPickupEnabled and not instantPickupWasEnabled then
        pcall(function()
            DisableInstantPickup()
        end)
    end

    print("[Auto Farm] 🛑 Остановлен")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- XP FARM SYSTEM
-- ══════════════════════════════════════════════════════════════════════════════

-- Главная функция XP фарма (оптимизированная версия)
local function StartXPFarm()
    -- Просто активируем флаг, Auto Farm сделает всё сам
    State.XPFarmEnabled = true
    print("[XP Farm] ✅ Включен (интегрирован с Auto Farm)")
end

local function StopXPFarm()
    State.XPFarmEnabled = false
    pcall(function()
        UnfloatCharacter()
    end)
    print("[XP Farm] ❌ Выключен")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 12: GODMODE SYSTEM (СТРОКИ 1601-1800)
-- ══════════════════════════════════════════════════════════════════════════════

local healthConnection = nil
local damageBlockerConnection = nil
local stateConnection = nil
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
    
    stateConnection = humanoid.StateChanged:Connect(function(oldState, newState)
        if State.GodModeEnabled then
            if newState == Enum.HumanoidStateType.Dead then
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
                humanoid.Health = math.huge
            end
        end
    end)
    table.insert(State.Connections, stateConnection)
    
    healthConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        if State.GodModeEnabled and humanoid.Health < math.huge then
            humanoid.Health = math.huge
        end
    end)
    
    table.insert(State.Connections, healthConnection)
end
-- SetupDamageBlocker() - Блокировка Ragdoll/CreatorTag
SetupDamageBlocker = function()
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

-- ToggleGodMode() - Включение/отключение
ToggleGodMode = function()
    State.GodModeEnabled = not State.GodModeEnabled
    if State.GodModeEnabled then
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(220,220,220)\">GodMode</font> <font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Green)
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
        table.insert(State.GodModeConnections, respawnConnection)  -- ✅ В ОТДЕЛЬНОЕ хранилище
    else
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(220,220,220)\">GodMode</font> <font color=\"rgb(255, 85, 85)\">OFF</font>",CONFIG.Colors.Text)
        end
        
        -- Отключаем локальные connections
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


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 13: TROLLING FEATURES (СТРОКИ 1801-2050)
-- ══════════════════════════════════════════════════════════════════════════════

-- RigidOrbitPlayer() - Орбита вокруг игрока
local function RigidOrbitPlayer(targetName, enabled)
    if enabled then
        State.OrbitAngle = 0
        
        State.OrbitThread = task.spawn(function()
            while State.OrbitEnabled do
                pcall(function()
                    local target = getPlayerByName(targetName)
                    if target and target.Character then
                        local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
                        local myChar = LocalPlayer.Character
                        
                        if targetHRP and myChar then
                            local myHRP = myChar:FindFirstChild("HumanoidRootPart")
                            if myHRP then
                                State.OrbitAngle = State.OrbitAngle + State.OrbitSpeed
                                
                                local angleRad = math.rad(State.OrbitAngle)
                                local tiltRad = math.rad(State.OrbitTilt)
                                
                                local x = math.cos(angleRad) * State.OrbitRadius
                                local z = math.sin(angleRad) * State.OrbitRadius
                                
                                local y = math.sin(angleRad) * State.OrbitRadius * math.sin(tiltRad)
                                local adjustedX = x * math.cos(tiltRad)
                                local adjustedZ = z * math.cos(tiltRad)
                                
                                myHRP.CFrame = targetHRP.CFrame * CFrame.new(
                                    adjustedX,
                                    State.OrbitHeight + y,
                                    adjustedZ
                                )
                            end
                        end
                    end
                end)
                task.wait()
            end
        end)
    else
        if State.OrbitThread then
            task.cancel(State.OrbitThread)
            State.OrbitThread = nil
        end
    end
end

-- SimpleLoopFling() - Цикличный флинг
local function SimpleLoopFling(targetName, enabled)
    if enabled then
        State.LoopFlingThread = task.spawn(function()
            while State.LoopFlingEnabled do
                pcall(function()
                    local target = getPlayerByName(targetName)
                    if target then
                        FlingPlayer(target)
                    end
                end)
                task.wait(3)
            end
        end)
    else
        if State.LoopFlingThread then
            task.cancel(State.LoopFlingThread)
            State.LoopFlingThread = nil
        end
    end
end

-- PendulumBlockPath() - Маятник перед игроком
local function PendulumBlockPath(targetName, enabled)
    if enabled then
        State.BlockPathPosition = 0
        State.BlockPathDirection = 1
        
        State.BlockPathThread = task.spawn(function()
            while State.BlockPathEnabled do
                pcall(function()
                    local target = getPlayerByName(targetName)
                    if target and target.Character then
                        local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
                        local myChar = LocalPlayer.Character
                        
                        if targetHRP and myChar then
                            local myHRP = myChar:FindFirstChild("HumanoidRootPart")
                            if myHRP then
                                State.BlockPathPosition = State.BlockPathPosition + (State.BlockPathSpeed * State.BlockPathDirection)
                                
                                if State.BlockPathPosition >= 5 then
                                    State.BlockPathDirection = -1
                                elseif State.BlockPathPosition <= -5 then
                                    State.BlockPathDirection = 1
                                end
                                
                                local offset = CFrame.new(0, 0, State.BlockPathPosition)
                                
                                myHRP.CFrame = targetHRP.CFrame * offset
                                
                                myHRP.CFrame = CFrame.new(myHRP.Position, targetHRP.Position)
                            end
                        end
                    end
                end)
                task.wait()
            end
        end)
    else
        if State.BlockPathThread then
            task.cancel(State.BlockPathThread)
            State.BlockPathThread = nil
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 14: ESP SYSTEM (СТРОКИ 2051-2350)
-- ══════════════════════════════════════════════════════════════════════════════

-- CreateHighlight() - Создание Highlight
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

-- UpdatePlayerHighlight() - Обновление ESP игрока
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
            existingHighlight.FillColor = color
            existingHighlight.OutlineColor = color
            existingHighlight.Enabled = true
        else
            pcall(function() existingHighlight:Destroy() end)
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

-- getMap() - Поиск карты
local function getMap()
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:FindFirstChild("CoinContainer") then
            return v
        end
    end
    return nil
end

-- getGun() - Поиск пистолета
local function getGun()
    local map = getMap()
    if not map then return nil end
    return map:FindFirstChild("GunDrop")
end

-- CreateGunESP() - Создание Gun ESP
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
    
    -- ✅ ЗОЛОТИСТЫЙ Highlight
    local highlight = Instance.new("Highlight")
    highlight.Adornee = gunPart
    highlight.FillColor = Color3.fromRGB(255, 200, 50)  -- Золотистый
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 200, 50)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = State.GunESP
    highlight.Parent = gunPart
    
    -- ✅ КРАСИВЫЙ текст
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "GunESPLabel"
    billboard.Adornee = gunPart
    billboard.Size = UDim2.new(0, 140, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = gunPart
    
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = "GUN"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)  -- Белый текст
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextStrokeTransparency = 0.6  -- Сильная обводка
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = billboard
    
    State.GunCache[gunPart] = {
        highlight = highlight,
        billboard = billboard
    }
end

-- RemoveGunESP() - Удаление Gun ESP
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

-- UpdateGunESPVisibility() - Обновление видимости
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

-- SetupGunTracking() - Heartbeat для Gun ESP
local previousGun = nil

local function SetupGunTracking()
    -- Отключаем старые connections
    if currentMapConnection then
        currentMapConnection:Disconnect()
        currentMapConnection = nil
    end
    
    -- ✅ HEARTBEAT для постоянной проверки
    currentMapConnection = RunService.Heartbeat:Connect(function()
        pcall(function()
            local gun = getGun()
            
            -- ✅ УВЕДОМЛЕНИЕ о выпадении пистолета
            if gun and gun ~= previousGun then
                if State.NotificationsEnabled then
                    ShowNotification(
                        "<font color=\"rgb(255, 200, 50)\">Gun dropped!</font>",
                        CONFIG.Colors.Gun
                    )
                end
                previousGun = gun
            end
            
            -- Если пистолет исчез (подобрали)
            if not gun and previousGun then
                previousGun = nil
            end
            
            -- Если пистолет есть
            if gun and State.GunESP then
                -- Создаём ESP если его нет
                if not State.GunCache[gun] then
                    CreateGunESP(gun)
                else
                    -- Обновляем видимость
                    local espData = State.GunCache[gun]
                    if espData.highlight then
                        espData.highlight.Enabled = State.GunESP
                    end
                end
            end
            
            -- Очистка старых ESP (пистолет был подобран)
            for cachedGun, espData in pairs(State.GunCache) do
                if cachedGun ~= gun or not gun then
                    RemoveGunESP(cachedGun)
                end
            end
        end)
    end)
    
    table.insert(State.Connections, currentMapConnection)
end

-- StartRoleChecking() - Heartbeat для Role ESP
local function StartRoleChecking()
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
            local murder = getMurder()
            local sheriff = getSheriff()
            
            local murderers = {}
            local sheriffs = {}
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
                State.roundStart = false
                State.prevMurd = murder
                State.prevSher = sheriff
                State.heroSent = false
                
                if State.NotificationsEnabled then
                    ShowNotification("<font color=\"rgb(255, 85, 85)\">🔪 Murderer:</font> " .. murder.Name, CONFIG.Colors.Text)
                    task.wait(0.1)
                    ShowNotification("<font color=\"rgb(50, 150, 255)\">🔫 Sheriff:</font> " .. sheriff.Name, CONFIG.Colors.Text)
                end
            end
            
            if not murder and State.roundActive then
                State.roundActive = false
                State.roundStart = true
                State.prevMurd = nil
                State.prevSher = nil
                State.heroSent = false
                
                if State.NotificationsEnabled then
                    ShowNotification("<font color=\"rgb(220, 220, 220)\">Round ended</font>", CONFIG.Colors.Text)
                end
            end
            
            if sheriff and State.prevSher and sheriff ~= State.prevSher and murder and murder == State.prevMurd and not State.heroSent then
                State.prevSher = sheriff
                State.heroSent = true
                
                if State.NotificationsEnabled then
                    ShowNotification("<font color=\"rgb(50, 150, 255)\">New Sheriff:</font> " .. sheriff.Name, CONFIG.Colors.Text)
                end
            end
        end)
    end)
    
    table.insert(State.Connections, State.RoleCheckLoop)
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
    
    -- Режим спавна рядом с игроком
    if State.spawnAtPlayer then
        local nearestPlayer = findNearestPlayer()
        if nearestPlayer and nearestPlayer.Character then
            local targetHRP = nearestPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetHRP then
                -- Позади игрока на 4 studs, центр торса
                local behindOffset = -targetHRP.CFrame.LookVector * 4
                local upOffset = Vector3.new(0, 0.5, 0)
                spawnPosition = targetHRP.Position + behindOffset + upOffset
                
                -- Вектор через центр HumanoidRootPart
                local directionToTorso = (targetHRP.Position - spawnPosition).Unit
                targetPosition = targetHRP.Position + (directionToTorso * 500)
            else
                spawnPosition = LocalPlayer.Character.RightHand.Position
                targetPosition = mouse.Hit.Position
            end
        else
            spawnPosition = LocalPlayer.Character.RightHand.Position
            targetPosition = mouse.Hit.Position
        end
    else
        -- Обычный бросок
        spawnPosition = LocalPlayer.Character.RightHand.Position
        targetPosition = mouse.Hit.Position
    end

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
    
    if not success and not silent then
        ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">" .. tostring(err) .. "</font>", nil)
    end
end


shootMurderer = function(silent)
    -- Проверка кулдауна
    if not State.CanShootMurderer then
        if not silent then
            ShowNotification("<font color=\"rgb(255, 165, 0)\">Wait </font><font color=\"rgb(220,220,220)\">Gun is on cooldown</font>", CONFIG.Colors.Text)
        end
        return
    end
    
    -- Проверка роли
    local sheriff = getSheriff()
    if sheriff ~= LocalPlayer then
        if not silent then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220,220,220)\">You're not sheriff/hero.</font>", CONFIG.Colors.Text)
        end
        return
    end
    
    -- Поиск убийцы
    local murderer = getMurder()
    if not murderer or not murderer.Character then
        if not silent then
            ShowNotification("<font color=\"rgb(255, 165, 0)\">Warning </font><font color=\"rgb(220,220,220)\">Murderer not found</font>", CONFIG.Colors.Text)
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
            if not silent then
                ShowNotification("<font color=\"rgb(220, 220, 220)\">You don't have the gun..?</font>", CONFIG.Colors.Text)
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
    
    local murdererHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
    
    if not murdererHRP then
        if not silent then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">Murderer has no HRP</font>", nil)
        end
        return
    end
    
    -- === НОВАЯ ЛОГИКА 100% ПОПАДАНИЯ (Counter-Movement) ===
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
    
    -- Аргументы для выстрела (Используем lookAt для правильного хитбокса пули)
    local argsShootRemote = {
        [1] = CFrame.lookAt(spawnPosition, targetPosition),
        [2] = CFrame.new(targetPosition)
    }
    -- ========================================================
    
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
        if not silent then
            ShowNotification("<font color=\"rgb(85, 255, 85)\">Shot fired! </font><font color=\"rgb(220,220,220)\">Cooldown: " .. State.ShootCooldown .. "s</font>", CONFIG.Colors.Text)
        end
        
        -- ВОССТАНОВЛЕНИЕ КУЛДАУНА
        task.delay(State.ShootCooldown, function()
            State.CanShootMurderer = true
            if not silent then
                ShowNotification("<font color=\"rgb(85, 255, 255)\">Ready </font><font color=\"rgb(220,220,220)\">You can shoot again</font>", CONFIG.Colors.Text)
            end
        end)
    else
        -- Если ошибка - сбрасываем кулдаун
        State.CanShootMurderer = true
        if not silent then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">" .. tostring(err) .. "</font>", nil)
        end
    end
end

-- pickupGun() - Подбор пистолета
local function pickupGun()
    local gun = Workspace:FindFirstChild("GunDrop", true)
    
    if not gun then
        ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">No gun on map</font>", CONFIG.Colors.Text)
        return
    end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Используем firetouchinterest - никакого телепорта
    firetouchinterest(hrp, gun, 0)
    task.wait(0.02)
    firetouchinterest(hrp, gun, 1)
    
    ShowNotification("<font color=\"rgb(220, 220, 220)\">Gun: Picked up</font>", CONFIG.Colors.Text)
end

-- EnableInstantPickup - Включить автоподбор пистолета
local function EnableInstantPickup()
    if State.InstantPickupThread then
        task.cancel(State.InstantPickupThread)
        State.InstantPickupThread = nil
    end
    
    State.InstantPickupEnabled = true
    
    State.InstantPickupThread = task.spawn(function()
        
        while State.InstantPickupEnabled do
            local murderer = getMurder()
            
            -- Ждём начала раунда
            if not murderer then
                task.wait(2)
                continue
            end
            
            -- Если мы мурдерер - пропускаем
            if murderer == LocalPlayer then
                task.wait(1)
                continue
            end
            
            local gun = getGun()
            local sheriff = getSheriff()
            
            -- Пистолет есть и нет шерифа - пытаемся подобрать
            if gun and not sheriff then
                local pickupSuccess = false
                
                -- ✅ 3 ПОПЫТКИ ПОДБОРА
                for attempt = 1, 3 do
                    if not getGun() then
                        pickupSuccess = true
                        break
                    end
                    pickupGun()
                    task.wait(0.15)
                    
                    -- Проверяем успех
                    if LocalPlayer.Character:FindFirstChild("Gun") or 
                       LocalPlayer.Backpack:FindFirstChild("Gun") then
                        pickupSuccess = true
                        break
                    end
                end
                
                -- ❌ ЕСЛИ НЕ ПОЛУЧИЛОСЬ - ЖДЁМ НОВЫЙ РАУНД
                if not pickupSuccess then
                    repeat
                        task.wait(1)
                        if not State.InstantPickupEnabled then
                            return
                        end
                    until getMurder() == nil
                    repeat
                        task.wait(1)
                        if not State.InstantPickupEnabled then
                            return
                        end
                    until getMurder() ~= nil
                    continue
                end
            end
            
            task.wait(0.2)
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


-- DisableInstantPickup - Отключить автоподбор пистолета
local function DisableInstantPickup()
    State.InstantPickupEnabled = false
    if State.InstantPickupThread then
        task.cancel(State.InstantPickupThread)
        State.InstantPickupThread = nil
    end
end

-- EnableExtendedHitbox() - Включение расширенного хитбокса
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

-- DisableExtendedHitbox() - Отключение хитбокса
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

-- UpdateHitboxSize() - Обновление размера
local function UpdateHitboxSize(newSize)
    State.ExtendedHitboxSize = newSize
end

-- ToggleKillAura() - Kill Aura
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

InstantKillAll = function()
    print("[InstantKillAll] 🔪 Запуск...")
    
    local murderer = getMurder()
    if murderer ~= LocalPlayer then
        print("[InstantKillAll] ❌ Вы не мурдерер!")
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
        print("[InstantKillAll] ❌ Character не найден!")
        return
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        print("[InstantKillAll] ❌ HumanoidRootPart не найден!")
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
        print("[InstantKillAll] ❌ Нож не найден!")
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
    
    print("[InstantKillAll] 📍 Телепортировано: " .. teleportedPlayers .. " игроков ПЕРЕД собой")
    
    task.wait(0.5)
    
    -- ✅ Активируем нож 3 раза
    for i = 1, 3 do
        knife = character:FindFirstChild("Knife")
        if knife and knife.Parent then
            knife:Activate()
            print("[InstantKillAll] 🔪 Активация ножа #" .. i)
        else
            print("[InstantKillAll] ⚠️ Нож пропал во время атаки!")
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
    
    print("[InstantKillAll] ✅ Завершено!")
    
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
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local LocalPlayer = game:GetService("Players").LocalPlayer
    
    -- Функция рекурсивного поиска
    local function SearchAndTeleport(cursor)
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor then
            url = url .. "&cursor=" .. cursor
        end
        
        -- Используем game:HttpGet (стандарт для эксплойтов)
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        
        if not success or not result or not result.data then 
            return -- Ошибка запроса, просто выходим, чтобы не редждойниться случайно
        end
        
        local validServers = {}
        
        for _, server in ipairs(result.data) do
            -- Строгая фильтрация
            if server.playing < server.maxPlayers 
               and server.playing > 0 
               and server.id ~= game.JobId -- ГАРАНТИЯ, что это не текущий сервер
            then
                table.insert(validServers, server)
            end
        end
        
        if #validServers > 0 then
            -- Если нашли сервера - прыгаем на первый (самый свободный из-за sortOrder=Asc)
            -- Или можно взять случайный: validServers[math.random(1, #validServers)]
            local target = validServers[1]
            
            TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, LocalPlayer)
        else
            -- Если на этой странице нет подходящих серверов, чекаем следующую
            if result.nextPageCursor then
                -- Небольшая задержка, чтобы не спамить запросами
                task.wait(0.1)
                SearchAndTeleport(result.nextPageCursor)
            else
                -- Сервера закончились, ничего не делаем (лучше ничего, чем реджойн)
                warn("Server Hop: No suitable servers found.")
            end
        end
    end
    
    -- Запускаем поиск
    task.spawn(function()
        SearchAndTeleport(nil)
    end)
end
-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 19: UI HELPER FUNCTIONS (СТРОКИ 3201-3450)
-- ══════════════════════════════════════════════════════════════════════════════

-- Create() - Универсальный конструктор
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

-- AddCorner() - UICorner
local function AddCorner(parent, radius)
    return Create("UICorner", {CornerRadius = UDim.new(0, radius), Parent = parent})
end

-- AddStroke() - UIStroke
local function AddStroke(parent, thickness, color, transparency)
    return Create("UIStroke", {
        Thickness = thickness or 1,
        Color = color or CONFIG.Colors.Stroke,
        Transparency = transparency or 0.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 20: UI CREATION (СТРОКИ 3451-5200+)
-- ══════════════════════════════════════════════════════════════════════════════

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
    VisualsTab:CreateToggle("Gun ESP", "Highlight dropped guns", function(s) State.GunESP = s; end)
    VisualsTab:CreateToggle("Murder ESP", "Highlight murderer", function(s) State.MurderESP = s; end)
    VisualsTab:CreateToggle("Sheriff ESP", "Highlight sheriff", function(s) State.SheriffESP = s; end)
    VisualsTab:CreateToggle("Innocent ESP", "Highlight innocent players", function(s) State.InnocentESP = s; end)
    VisualsTab:CreateSection("Misc")
    VisualsTab:CreateToggle("UI Only", "Hide all UI except script GUI", function(enabled) State.UIOnlyEnabled = enabled if enabled then EnableUIOnly() else DisableUIOnly() end end)
    VisualsTab:CreateToggle("Ping Chams", "Show server-side position", function(s) State.PingChamsEnabled = s if s then StartPingChams() else StopPingChams() end end)
    local CombatTab = CreateTab("Combat")
   
    CombatTab:CreateSection("EXTENDED HITBOX")
    CombatTab:CreateToggle("Enable Extended Hitbox", "Makes all players easier to hit", function(s) if s then EnableExtendedHitbox() else DisableExtendedHitbox() end end)
    CombatTab:CreateSlider("Hitbox Size", "Larger = easier to hit (10-30)", 10, 30, 15, function(v) State.ExtendedHitboxSize = v; if State.ExtendedHitboxEnabled then UpdateHitboxSize(v) end end, 1)
   
    CombatTab:CreateSection("MURDERER TOOLS")
    CombatTab:CreateKeybindButton("Fast throw", "knifeThrow", "knifeThrow")
    CombatTab:CreateToggle("Spawn Knife Near Player", "Spawns knife next to target instead of from your hand", function(s) State.spawnAtPlayer = s end)
    CombatTab:CreateToggle("Murderer Kill Aura", "Auto kill nearby players", function(s) ToggleKillAura(s) end)
    CombatTab:CreateKeybindButton("Instant Kill All (Murderer)", "instantkillall", "InstantKillAll")
   
    CombatTab:CreateSection("SHERIFF TOOLS")
    CombatTab:CreateKeybindButton("Shoot Murderer (Instakill)", "shootmurderer", "ShootMurderer")
    CombatTab:CreateToggle("Instant Pickup Gun", "Auto pickup gun when dropped", function(s) if s then EnableInstantPickup() else DisableInstantPickup() end end)
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
    FarmTab:CreateToggle("XP Farm", "Auto win rounds: Kill as Murderer, Shoot as Sheriff, Fling as Innocent",  function(s) State.XPFarmEnabled = s if s then StartXPFarm() else StopXPFarm() end end)
   
    FarmTab:CreateToggle("Underground Mode", "Fly under the map (safer)", function(s) State.UndergroundMode = s end)
    FarmTab:CreateSlider("Fly Speed", "Flying speed (10-30)", 10, 30, 22, function(v) State.CoinFarmFlySpeed = v end, 1)
    FarmTab:CreateSlider("TP Delay", "Delay between TPs (0.5-5.0)", 0.5, 5.0, 2.0, function(v) State.CoinFarmDelay = v end, 0.5)
    FarmTab:CreateToggle("AFK Mode", "Disable rendering to reduce GPU usage", function(enabled) State.AFKModeEnabled = enabled if enabled then EnableMaxOptimization() else DisableMaxOptimization() end end)
    FarmTab:CreateButton("", "FPS Boost", CONFIG.Colors.Accent, function()
    EnableFPSBoost()
end)

    local FunTab = CreateTab("Fun")
   
    FunTab:CreateSection("ANIMATION KEYBINDS")
    FunTab:CreateKeybindButton("Sit Animation", "sit", "Sit")
    FunTab:CreateKeybindButton("Dab Animation", "dab", "Dab")
    FunTab:CreateKeybindButton("Zen Animation", "zen", "Zen")
    FunTab:CreateKeybindButton("Ninja Animation", "ninja", "Ninja")
    FunTab:CreateKeybindButton("Floss Animation", "floss", "Floss")
   
    FunTab:CreateSection("ANTI-FLING")
    FunTab:CreateToggle("Enable Anti-Fling", "Protect yourself from flingers", function(s) if s then EnableAntiFling() else DisableAntiFling() end end)
    FunTab:CreateToggle("Walk Fling", "Fling players by walking into them", function(s) if s then WalkFlingStart() else WalkFlingStop() end end)
    FunTab:CreateSection("FLING PLAYER")
    FunTab:CreatePlayerDropdown("Select Target", "Choose player to fling")
    FunTab:CreateKeybindButton("Fling Selected Player", "fling", "FlingPlayer")
    FunTab:CreateSection("FLING ROLE")
    FunTab:CreateButton("", "Fling Murderer", Color3.fromRGB(255, 85, 85), function() FlingMurderer() end)
    FunTab:CreateButton("", "Fling Sheriff", Color3.fromRGB(90, 140, 255), function() FlingSheriff() end)


    local UtilityTab = CreateTab("Utility")
   
    UtilityTab:CreateSection("SERVER MANAGEMENT")
    UtilityTab:CreateButton("", "🔄 Rejoin Server", CONFIG.Colors.Accent, function() Rejoin() end)
    UtilityTab:CreateButton("", "🌐 Server Hop", Color3.fromRGB(100, 200, 100), function() ServerHop() end)

    local TrollingTab = CreateTab("Trolling")

    TrollingTab:CreateSection("🎯 SELECT TARGET")
    TrollingTab:CreatePlayerDropdown("Target Player", "Choose victim for trolling")

    TrollingTab:CreateSection("💀 TROLLING MODES")

    TrollingTab:CreateToggle("Orbit Mode", "Rotate around player (rigid)", function(s)
        State.OrbitEnabled = s
        if State.SelectedPlayerForFling then
            RigidOrbitPlayer(State.SelectedPlayerForFling, s)
            if s and State.NotificationsEnabled then
                ShowNotification("<font color=\"rgb(255, 200, 50)\">🌀 Orbiting " .. State.SelectedPlayerForFling .. "</font>", CONFIG.Colors.Orange)
            end
        else
            if s and State.NotificationsEnabled then
                ShowNotification("<font color=\"rgb(255, 85, 85)\">❌ Select target first!</font>", CONFIG.Colors.Red)
            end
            State.OrbitEnabled = false
        end
    end)

    TrollingTab:CreateToggle("Loop Fling", "Fling player every 3s", function(s)
        State.LoopFlingEnabled = s
        if State.SelectedPlayerForFling then
            SimpleLoopFling(State.SelectedPlayerForFling, s)
            if s and State.NotificationsEnabled then
                ShowNotification("<font color=\"rgb(255, 200, 50)\">💥 Loop Flinging " .. State.SelectedPlayerForFling .. "</font>", CONFIG.Colors.Orange)
            end
        else
            if s and State.NotificationsEnabled then
                ShowNotification("<font color=\"rgb(255, 85, 85)\">❌ Select target first!</font>", CONFIG.Colors.Red)
            end
            State.LoopFlingEnabled = false
        end
    end)

    TrollingTab:CreateToggle("Block Path", "Block path with pendulum motion", function(s)
        State.BlockPathEnabled = s
        if State.SelectedPlayerForFling then
            PendulumBlockPath(State.SelectedPlayerForFling, s)
            if s and State.NotificationsEnabled then
                ShowNotification("<font color=\"rgb(255, 200, 50)\">🚧 Blocking " .. State.SelectedPlayerForFling .. "</font>", CONFIG.Colors.Orange)
            end
        else
            if s and State.NotificationsEnabled then
                ShowNotification("<font color=\"rgb(255, 85, 85)\">❌ Select target first!</font>", CONFIG.Colors.Red)
            end
            State.BlockPathEnabled = false
        end
    end)

    TrollingTab:CreateSection("⚙️ ORBIT SETTINGS")

    TrollingTab:CreateSlider("Radius", "Distance from target (2-20)", 2, 20, 5, function(v)
        State.OrbitRadius = v
    end, 0.5)

    TrollingTab:CreateSlider("Speed", "Rotation speed (0.5-15)", 0.5, 15, 3, function(v)
        State.OrbitSpeed = v
    end, 0.5)

    TrollingTab:CreateSlider("Height", "Base height (-10 to 20)", -10, 20, 0, function(v)
        State.OrbitHeight = v
    end, 1)

    TrollingTab:CreateSlider("Tilt", "Orbital angle (-90 to 90)", -90, 90, 0, function(v)
        State.OrbitTilt = v
    end, 5)

    -- Block Path Settings
    TrollingTab:CreateSection("⚙️ BLOCK PATH SETTINGS")

    TrollingTab:CreateSlider("Pendulum Speed", "Movement speed (0.05-0.3)", 0.05, 0.3, 0.1, function(v)
        State.BlockPathSpeed = v
    end, 0.05)

    -- Orbit Presets
    TrollingTab:CreateSection("⚡ ORBIT PRESETS")

    TrollingTab:CreateButton("", "⚡ Fast Spin", Color3.fromRGB(255, 170, 50), function()
        State.OrbitRadius = 4
        State.OrbitSpeed = 10
        State.OrbitHeight = 0
        State.OrbitTilt = 0
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 170, 50)\">⚡ Fast Spin</font>", CONFIG.Colors.Orange)
        end
    end)

    TrollingTab:CreateButton("", "🎢 Vertical Loop", Color3.fromRGB(255, 85, 85), function()
        State.OrbitRadius = 5
        State.OrbitSpeed = 5
        State.OrbitHeight = 0
        State.OrbitTilt = 90
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">🎢 Vertical Loop</font>", CONFIG.Colors.Red)
        end
    end)

    TrollingTab:CreateButton("", "💫 Chaotic Spin", Color3.fromRGB(200, 100, 200), function()
        State.OrbitRadius = 2 
        State.OrbitSpeed = 15
        State.OrbitHeight = 0
        State.OrbitTilt = 30
        if State.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(200, 100, 200)\">💫 Chaotic Spin</font>", Color3.fromRGB(200, 100, 200))
        end
    end)


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
    print("[Shutdown] Starting cleanup...")
    
    -- Закрыть все открытые дропдауны
    if State.UIElements.OpenDropdowns then
        for _, closeFunc in ipairs(State.UIElements.OpenDropdowns) do
            pcall(closeFunc)
        end
        State.UIElements.OpenDropdowns = {}
    end

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
        ToggleGodMode()
    end
    if State.ViewClipEnabled then
        DisableViewClip()
    end
    
    if killAuraCon then
        ToggleKillAura(false)
    end

    -- Очистка ESP / gun / coin / keybinds
    FullShutdown()

    -- Отключение всех общих соединений
    for i, connection in ipairs(State.Connections) do
        pcall(function()
            if connection and connection.Disconnect then
                connection:Disconnect()
            end
        end)
    end
    State.Connections = {}

    if gui then pcall(function() gui:Destroy() end) end
    if State.UIElements.NotificationGui then
        pcall(function() State.UIElements.NotificationGui:Destroy() end)
        State.UIElements.NotificationGui = nil
        State.UIElements.NotificationContainer = nil
    end

    if oldWarn then warn = oldWarn end
    if oldError then error = oldError end

    -- Финальный флаг
    getgenv().MM2_ESP_Script = false
    print("[Shutdown] ✅ Complete! All connections cleared.")
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
        
        -- Обработка keybinds
        if State.ListeningForKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
            local key = input.KeyCode
            local bindData = State.ListeningForKeybind
            
            if key == Enum.KeyCode.Delete or key == Enum.KeyCode.Backspace then
                ClearKeybind(bindData.key, bindData.button)
                State.ListeningForKeybind = nil
                return
            end
            
            SetKeybind(bindData.key, key, bindData.button)
            State.ListeningForKeybind = nil
            return
        end
        
        -- Emotes
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
        
        -- Actions
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
    end)
    table.insert(State.Connections, inputBeganConnection)

    local inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == State.Keybinds.ClickTP then
            State.ClickTPActive = false
        end
    end)
    table.insert(State.Connections, inputEndedConnection)

    local mouse = LocalPlayer:GetMouse()
    local mouseClickConnection = mouse.Button1Down:Connect(function()
        if State.ClickTPActive then TeleportToMouse() end
    end)
    table.insert(State.Connections, mouseClickConnection)
end

Players.PlayerRemoving:Connect(function(player)
    if State.PlayerHighlights[player] then
        pcall(function()
            State.PlayerHighlights[player]:Destroy()
        end)
        State.PlayerHighlights[player] = nil
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        if State.PlayerHighlights[player] then
            pcall(function()
                State.PlayerHighlights[player]:Destroy()
            end)
            State.PlayerHighlights[player] = nil
        end
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function(character)
            task.wait(0.5)
            if State.PlayerHighlights[player] then
                pcall(function()
                    State.PlayerHighlights[player]:Destroy()
                end)
                State.PlayerHighlights[player] = nil
            end
        end)
    end
end
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

CreateUI()
CreateNotificationUI()
ApplyCharacterSettings()

-- ✅ Применяем FOV
pcall(function()
    ApplyFOV(State.CameraFOV)
end)

SetupGunTracking()
StartRoleChecking()
SetupAntiAFK()

-- выводим в консоль
print("╔════════════════════════════════════════════╗")
print("║   MM2 ESP v6.0 - Successfully Loaded!     ║")
print("║   Press [" .. CONFIG.HideKey.Name .. "] to toggle GUI               ║")
print("╚════════════════════════════════════════════╝")
