-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 1: INITIALIZATION & PROTECTION (СТРОКИ 1-70)
-- ══════════════════════════════════════════════════════════════════════════════

--if game.PlaceId ~= 142823291 then return end
local AUTOEXEC_ENABLED = true
-- Loadstring Emotes (строка 3)
loadstring(game:HttpGet("https://raw.githubusercontent.com/Yany1944/rbxmain/refs/heads/main/Scripts/Emotes.lua"))()

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
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
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
    CoinFarmFlySpeed = 21,
    CoinFarmDelay = 2,
    UndergroundMode = false,
    UndergroundOffset = 2.5,
    CoinBlacklist = {},
    LastCacheTime = 0,
    GodModeWithAutoFarm = true,

    -- Auto Rejoin & Reconnect
    AutoRejoinEnabled = false,
    AutoReconnectEnabled = false,
    ReconnectInterval = 25 * 60, -- 25 минут в секундах
    ReconnectThread = nil,

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
    CurrentGunDrop = nil,

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

    -- Tracers
    BulletTracersEnabled = false,
    TracersList = {},
    LastTracerTime = 0,
    
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

local ScriptAlive = true

local function TrackConnection(conn)
    if conn then
        table.insert(State.Connections, conn)
    end
    return conn
end
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

TrackConnection(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    pcall(function()
        if State.PingChamsGhostPart and LocalPlayer.Character then
            State.PingChamsGhostPart.Size = PingChams_sizeFromCharacter(LocalPlayer.Character)
        end
    end)
end))


-- ============= BULLET/KNIFE TRACERS =============
local TracersAccent = Color3.fromRGB(220, 145, 230)
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Blacklist
RayParams.IgnoreWater = true

local function CreateTracer(startPos, endPos, duration)
    if not State.BulletTracersEnabled then return end
    
    local attachment0 = Instance.new("Attachment")
    attachment0.WorldPosition = startPos
    attachment0.Parent = workspace.Terrain
    
    local attachment1 = Instance.new("Attachment")
    attachment1.WorldPosition = endPos
    attachment1.Parent = workspace.Terrain
    
    local beam = Instance.new("Beam")
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(TracersAccent)
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Brightness = 5
    beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
    beam.TextureMode = Enum.TextureMode.Stretch
    beam.TextureSpeed = 0
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0)
    })
    beam.Width0 = 0.3
    beam.Width1 = 0.3
    beam.ZOffset = 0.1
    beam.Parent = attachment0
    
    table.insert(State.TracersList, {beam = beam, att0 = attachment0, att1 = attachment1, time = tick()})
    
    task.delay(duration or 0.3, function()
        local fadeTime = 0.1
        local startTime = tick()
        local startTrans = 0
        local startBrightness = 5
        
        while tick() - startTime < fadeTime do
            local alpha = (tick() - startTime) / fadeTime
            local trans = startTrans + (1 - startTrans) * alpha
            beam.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, trans),
                NumberSequenceKeypoint.new(1, trans)
            })
            beam.Brightness = startBrightness * (1 - alpha)
            task.wait()
        end
        
        pcall(function()
            beam:Destroy()
            attachment0:Destroy()
            attachment1:Destroy()
        end)
        
        for i, v in ipairs(State.TracersList) do
            if v.beam == beam then
                table.remove(State.TracersList, i)
                break
            end
        end
    end)
end

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
    
    local raycastResult = workspace:Raycast(origin, direction * maxDistance, RayParams)
    if raycastResult then
        return raycastResult.Position
    else
        return origin + (direction * maxDistance)
    end
end

local function CreateTracerFromTool(tool)
    if not State.BulletTracersEnabled then return end
    if not tool or not tool:IsA("Tool") then return end
    local TRACER_COUNT = 4
    
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
    local direction = (targetPos - origin).Unit
    
    local maxDistance = 500
    local hitPos = PerformRaycast(origin, direction, maxDistance)
    for i = 1, TRACER_COUNT do
        CreateTracer(origin, hitPos, 0.8)
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
        local knifeThrowKey = State.knifeThrow or Enum.KeyCode.E
        
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

TrackConnection(LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    if State.BulletTracersEnabled then
        SetupToolTracers(character)
    end
end))

if LocalPlayer.Character then
    SetupToolTracers(LocalPlayer.Character)
end


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

LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    if State.BulletTracersEnabled then
        SetupToolTracers(character)
    end
end)

if LocalPlayer.Character then
    SetupToolTracers(LocalPlayer.Character)
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
        if State.ExtendedHitboxEnabled then DisableExtendedHitbox() end
        if State.GodModeEnabled then ToggleGodMode() end
        if State.InstantPickupEnabled then DisableInstantPickup() end
        if killAuraCon then ToggleKillAura(false) end
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
    end)

    pcall(function() GUI.Cleanup() end)

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

local fpsBoostDescendantConn

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
    fpsBoostDescendantConn = workspace.DescendantAdded:Connect(function(child)
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
    
    TrackConnection(fpsBoostDescendantConn)
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

-- CreateHighlight() - создание Highlight для персонажа
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

-- getMurder() / getSheriff()
local function getMurder()
    for _, plr in ipairs(Players:GetPlayers()) do
        local character = plr.Character
        local backpack  = plr:FindFirstChild("Backpack")

        if (character and character:FindFirstChild("Knife"))
            or (backpack and backpack:FindFirstChild("Knife")) then
            return plr
        end
    end
    return nil
end

local function getSheriff()
    for _, plr in ipairs(Players:GetPlayers()) do
        local character = plr.Character
        local backpack  = plr:FindFirstChild("Backpack")

        if (character and character:FindFirstChild("Gun"))
            or (backpack and backpack:FindFirstChild("Gun")) then
            return plr
        end
    end
    return nil
end

-- Role ESP loop
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
                        "<font color=\"rgb(255, 85, 85)\">🔪 Murderer:</font> " .. murder.Name,
                        CONFIG.Colors.Text
                    )
                    task.wait(0.1)
                    ShowNotification(
                        "<font color=\"rgb(50, 150, 255)\">🔫 Sheriff:</font> " .. sheriff.Name,
                        CONFIG.Colors.Text
                    )
                end
            end

            if not murder and State.roundActive then
                State.roundActive = false
                State.roundStart  = true
                State.prevMurd    = nil
                State.prevSher    = nil
                State.heroSent    = false

                if State.NotificationsEnabled then
                    ShowNotification(
                        "<font color=\"rgb(220, 220, 220)\">Round ended</font>",
                        CONFIG.Colors.Text
                    )
                end
            end

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
                        "<font color=\"rgb(50, 150, 255)\">New Sheriff:</font> " .. sheriff.Name,
                        CONFIG.Colors.Text
                    )
                end
            end
        end)
    end)

    table.insert(State.Connections, State.RoleCheckLoop)
end

----------------------------------------------------------------
-- Gun ESP + уведомление
----------------------------------------------------------------

local currentMapConnection = nil
local currentMap = nil
local previousGun = nil

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
    highlight.FillTransparency   = 0.5
    highlight.OutlineColor       = CONFIG.Colors.Gun
    highlight.OutlineTransparency = 0
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

local function SetupGunTracking()
    if currentMapConnection then
        currentMapConnection:Disconnect()
        currentMapConnection = nil
    end

    currentMapConnection = RunService.Heartbeat:Connect(function()
        pcall(function()
            local gun = getGun()

            if gun and gun ~= previousGun then
                State.CurrentGunDrop = gun
                if State.NotificationsEnabled then
                    ShowNotification(
                        "<font color=\"rgb(255, 200, 50)\">Gun dropped!</font>",
                        CONFIG.Colors.Gun
                    )
                end
                previousGun = gun
            end

            if not gun and previousGun then
                previousGun = nil
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
        end)
    end)

    table.insert(State.Connections, currentMapConnection)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 7: Fling (СТРОКИ 611-660)
-- ══════════════════════════════════════════════════════════════════════════════

local AntiFlingLastPos = Vector3.zero
local FlingDetectionConnection = nil
local FlingNeutralizerConnection = nil
local DetectedFlingers = {}
local FlingBlockedNotified = false

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
        
        -- ✅ Вызываем firetouchinterest на 80% полёта (раньше чем монета телепортируется)
        if alpha >= 0.85 and not collectionAttempted then
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
        --print("[Auto Farm] 🚀 Запущен")
        if State.UndergroundMode then
            --print("[Auto Farm] 🕳️ Режим под землёй: ВКЛ")
        end
        -- ✅ Включаем годмод при старте автофарма
        if State.GodModeWithAutoFarm and not State.GodModeEnabled then
            pcall(function()
                ToggleGodMode()  -- Включаем только если был выключен
            end)
            --print("[Auto Farm] 🛡️ GodMode автоматически включен")
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
                --print("[Auto Farm] ⏳ Жду начала раунда...")
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
                --print("[Auto Farm] ✅ Все 50 монет собраны!")
                noCoinsAttempts = maxNoCoinsAttempts
            else
                local coin = FindNearestCoin()
                
                if not coin then
                    noCoinsAttempts = noCoinsAttempts + 1
                    --print("[Auto Farm] 🔍 Монета не найдена (попытка " .. noCoinsAttempts .. "/" .. maxNoCoinsAttempts .. ")")
                    
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
                            
                            --print("[Auto Farm] 📍 ТП к монете #" .. (currentCoins + 1))
                            
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
                                    --print("[Auto Farm] ✅ Монета собрана (TP) | Всего: " .. coinsAfter)
                                end
                                
                                AddCoinToBlacklist(coin)
                            end
                        else
                            if State.UndergroundMode then
                                --print("[Auto Farm] 🕳️ Полёт под землёй к монете")
                            else
                                --print("[Auto Farm] ✈️ Полёт к монете")
                            end
                            
                            EnableNoClip()
                            SmoothFlyToCoin(coin, humanoidRootPart, State.CoinFarmFlySpeed)
                            
                            coinLabelCache = nil
                            local coinsAfter = GetCollectedCoinsCount()
                            if coinsAfter > currentCoins then
                                --print("[Auto Farm] ✅ Монета собрана (Fly) | Всего: " .. coinsAfter)
                            end
                            
                            AddCoinToBlacklist(coin)
                        end
                    end)
                end
            end
            
            if noCoinsAttempts >= maxNoCoinsAttempts then
                --print("[Auto Farm] ✅ Все доступные монеты собраны!")
                
                pcall(function()
                    DisableNoClip()
                end)
                
                if State.XPFarmEnabled then
                    --print("[Auto Farm] ⏳ XP Farm включен, передаю управление...")
                    
                    currentCoins = GetCollectedCoinsCount()
                    --print("[Auto Farm] 💰 Собрано монет: " .. currentCoins .. "/50")
                    
                    if currentCoins >= 50 then
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
                                    local murderer = getMurder()
                                    local sheriff = getSheriff()
                                    
                                    if murderer == LocalPlayer then
                                        --print("[XP Farm] 🔪 Мы мурдерер! Активирую knifeThrow...")
                                        
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
                                        
                                        -- ✅ Fallback: если после 30 попыток раунд не завершился
                                        if getMurder() ~= nil and State.AutoFarmEnabled and State.XPFarmEnabled then
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

                                            while getMurder() ~= nil and State.AutoFarmEnabled and State.XPFarmEnabled and shootAttempts < maxShootAttempts do
                                                character = LocalPlayer.Character
                                                if not character then 
                                                    --print("[XP Farm] ⚠️ Персонаж исчез, прекращаю стрельбу")
                                                    break 
                                                end
                                                
                                                local murdererPlayer = getMurder()
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
                                            if getMurder() == nil then
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
                                            
                                            if getMurder() == nil then
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
                end
                
                if State.XPFarmEnabled then
                    --print("[Auto Farm] ⏳ XP Farm включен - жду смерти мурдерера...")
                    repeat
                        task.wait(1)
                    until getMurder() == nil or not State.AutoFarmEnabled
                    
                    if not State.AutoFarmEnabled then
                        --print("[Auto Farm] ⚠️ Автофарм был выключен, выхожу из цикла...")
                        break
                    end
                    
                    pcall(function()
                        UnfloatCharacter()
                    end)
                    
                    --print("[Auto Farm] 🎉 Мурдерер мёртв! Жду официального окончания раунда...")
                    CleanupCoinBlacklist()
                    task.wait(5)
                    
                    if getMurder() ~= nil then
                        --print("[Auto Farm] ⚠️ Новый раунд уже начался! Пропускаю ресет...")
                        State.CoinBlacklist = {}
                        noCoinsAttempts = 0
                        continue
                    end
                    
                    --print("[Auto Farm] 🔄 Раунд полностью закончился! Делаю ресет...")
                    
                    -- ✅ Выключаем годмод перед ресетом
                    if State.GodModeWithAutoFarm and State.GodModeEnabled then
                        pcall(function()
                            ToggleGodMode()  -- Выключаем
                        end)
                        --print("[Auto Farm] 🛡️ GodMode временно выключен перед ресетом")
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
                                --print("[Auto Farm] 🛡️ GodMode повторно включен после респавна")
                            end
                        end
                    end
                    
                    --print("[Auto Farm] ⏳ Жду начала нового раунда...")
                    repeat
                        task.wait(1)
                    until getMurder() ~= nil or not State.AutoFarmEnabled
                    
                    if not State.AutoFarmEnabled then
                        --print("[Auto Farm] ⚠️ Автофарм был выключен во время ожидания раунда")
                        break
                    end
                    
                    --print("[Auto Farm] ✅ Новый раунд начался! Сбрасываю счётчики и продолжаю фарм...")
                    State.CoinBlacklist = {}
                    noCoinsAttempts = 0
                    
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
                                --print("[Auto Farm] 🛡️ GodMode повторно включен после респавна")
                            end
                        end
                    end

                    --print("[Auto Farm] ⏳ Жду конца текущего раунда...")
                    repeat
                        task.wait(1)
                    until getMurder() == nil or not State.AutoFarmEnabled

                    if not State.AutoFarmEnabled then
                        --print("[Auto Farm] ⚠️ Автофарм был выключен во время ожидания")
                        break
                    end

                    --print("[Auto Farm] ⏳ Раунд закончился, жду начала нового раунда...")
                    repeat
                        task.wait(1)
                    until getMurder() ~= nil or not State.AutoFarmEnabled

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
                task.wait(5)
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
    task.wait(0.1)
    firetouchinterest(hrp, gun, 1)
    
    ShowNotification("<font color=\"rgb(220, 220, 220)\">Gun: Picked up</font>", CONFIG.Colors.Text)
end

local function EnableInstantPickup()
    if State.InstantPickupThread then
        task.cancel(State.InstantPickupThread)
        State.InstantPickupThread = nil
    end
    
    State.InstantPickupEnabled = true
    
    -- ✅ ИСПОЛЬЗУЕМ ГЛОБАЛЬНУЮ ПЕРЕМЕННУЮ
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
            
            local gun = State.CurrentGunDrop  -- ✅ ИСПОЛЬЗУЕМ ГЛОБАЛЬНЫЙ
            local sheriff = getSheriff()
            
            -- ✅ НОВЫЙ ПИСТОЛЕТ (который мы ещё не пробовали)
            if gun and not sheriff and gun ~= lastAttemptedGun then
                
                -- Проверяем, уже подобран?
                if LocalPlayer.Character:FindFirstChild("Gun") or 
                   LocalPlayer.Backpack:FindFirstChild("Gun") then
                    lastAttemptedGun = gun
                    continue
                end
                
                local pickupSuccess = false
                
                -- ✅ 3 ПОПЫТКИ
                for attempt = 1, 3 do
                    pickupGun()
                    task.wait(0.5)
                    
                    -- Проверяем успех
                    if LocalPlayer.Character:FindFirstChild("Gun") or 
                       LocalPlayer.Backpack:FindFirstChild("Gun") then
                        pickupSuccess = true
                        break
                    end
                    
                    -- Пистолет исчез
                    if State.CurrentGunDrop ~= gun then
                        break
                    end
                end
                lastAttemptedGun = gun
                if not pickupSuccess then
                    repeat
                        task.wait(0.2)
                        if not State.InstantPickupEnabled then
                            return
                        end
                        
                        -- Выходим, когда появится НОВЫЙ пистолет
                        if State.CurrentGunDrop and State.CurrentGunDrop ~= lastAttemptedGun then
                            break
                        end
                        
                        -- Или когда старый исчезнет
                        if not State.CurrentGunDrop then
                            break
                        end
                        
                    until false
                end
            end
            
            task.wait(0.1)  -- Уменьшил для быстрой реакции
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
    
    task.wait(0.5)
    
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

local function ServerHop()
    -- ═══════════════════════════════════════════════════════════
    -- SERVER HOP SYSTEM v2.0 - Enhanced with file tracking
    -- ═══════════════════════════════════════════════════════════

    local CONFIG_SH = {
        FILE_NAME = "server-hop-cache.json",
        MIN_PLAYERS = 1,
        MAX_PLAYERS_PERCENT = 0.9,
        FETCH_LIMIT = 100,
        MAX_PAGES = 5,
        TELEPORT_RETRY = 3
    }

    local visitedServers = {}
    local currentHour = os.date("!*t").hour

    -- Загрузка кэша
    local function InitializeCache()
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_SH.FILE_NAME))
        end)

        if success and data then
            if data.hour and data.hour == currentHour and data.servers then
                visitedServers = data.servers
                return
            end
        end

        visitedServers = {}
        pcall(function()
            writefile(CONFIG_SH.FILE_NAME, HttpService:JSONEncode({
                hour = currentHour,
                servers = {}
            }))
        end)
    end

    -- Сохранение кэша
    local function SaveCache()
        pcall(function()
            writefile(CONFIG_SH.FILE_NAME, HttpService:JSONEncode({
                hour = currentHour,
                servers = visitedServers
            }))
        end)
    end

    -- Проверка посещённого сервера
    local function IsServerVisited(jobId)
        for _, id in ipairs(visitedServers) do
            if id == jobId then return true end
        end
        return false
    end

    -- Получение серверов
    local function FetchServers(cursor)
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=%d",
            game.PlaceId,
            CONFIG_SH.FETCH_LIMIT
        )

        if cursor then url = url .. "&cursor=" .. cursor end

        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)

        return success and result or nil
    end

    -- Оценка сервера
    local function CalculateScore(playing, maxPlayers)
        local fillRatio = playing / maxPlayers
        local score = (1 - fillRatio) * 100

        if playing >= 2 and playing <= 6 then
            score = score + 50
        end

        return score
    end

    -- Фильтрация серверов
    local function FilterServers(serverList)
        local validServers = {}

        for _, server in ipairs(serverList) do
            local jobId = server.id
            local playing = server.playing
            local maxPlayers = server.maxPlayers

            local isNotCurrentServer = jobId ~= game.JobId
            local isNotVisited = not IsServerVisited(jobId)
            local hasPlayers = playing >= CONFIG_SH.MIN_PLAYERS
            local notFull = playing < (maxPlayers * CONFIG_SH.MAX_PLAYERS_PERCENT)

            if isNotCurrentServer and isNotVisited and hasPlayers and notFull then
                table.insert(validServers, {
                    id = jobId,
                    playing = playing,
                    maxPlayers = maxPlayers,
                    score = CalculateScore(playing, maxPlayers)
                })
            end
        end

        return validServers
    end

    -- Телепортация
    local function TeleportToServer(jobId)
        for attempt = 1, CONFIG_SH.TELEPORT_RETRY do
            local success = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
            end)

            if success then
                table.insert(visitedServers, jobId)
                SaveCache()
                return true
            else
                task.wait(2)
            end
        end

        return false
    end

    -- Основная логика
    InitializeCache()

    local allServers = {}
    local cursor = nil
    local pagesScanned = 0

    repeat
        local result = FetchServers(cursor)

        if not result or not result.data then
            if State.NotificationsEnabled then
                ShowNotification(
                    "<font color=\"rgb(255, 85, 85)\">ServerHop: </font><font color=\"rgb(220,220,220)\">Failed to fetch servers</font>",
                    CONFIG.Colors.Text
                )
            end
            break
        end

        local filtered = FilterServers(result.data)

        for _, server in ipairs(filtered) do
            table.insert(allServers, server)
        end

        cursor = result.nextPageCursor
        pagesScanned = pagesScanned + 1

        if #allServers >= 20 then break end

        task.wait(0.1)

    until not cursor or pagesScanned >= CONFIG_SH.MAX_PAGES

    if #allServers == 0 then
        if State.NotificationsEnabled then
            ShowNotification(
                "<font color=\"rgb(255, 85, 85)\">ServerHop: </font><font color=\"rgb(220,220,220)\">No suitable servers found</font>",
                CONFIG.Colors.Text
            )
        end
        return
    end

    -- Сортировка и выбор
    table.sort(allServers, function(a, b)
        return a.score > b.score
    end)

    local topCount = math.min(3, #allServers)
    local selectedServer = allServers[math.random(1, topCount)]

    if State.NotificationsEnabled then
        ShowNotification(
            string.format(
                "<font color=\"rgb(85, 255, 120)\">ServerHop: </font><font color=\"rgb(220,220,220)\">Joining %d/%d players (Score: %.0f)</font>",
                selectedServer.playing,
                selectedServer.maxPlayers,
                selectedServer.score
            ),
            CONFIG.Colors.Text
        )
    end

    TeleportToServer(selectedServer.id)
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
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AUTO REJOIN & AUTO RECONNECT
-- ══════════════════════════════════════════════════════════════════════════════

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

-- Константа для дефолтного интервала
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
        GunESP = function(on) State.GunESP = on UpdateGunESPVisibility() end,
        MurderESP = function(on) State.MurderESP = on end,
        SheriffESP = function(on) State.SheriffESP = on end,
        InnocentESP = function(on) State.InnocentESP = on end,

        -- Visuals
        UIOnly = function(on) State.UIOnlyEnabled = on if on then EnableUIOnly() else DisableUIOnly() end end,
        PingChams = function(on) State.PingChamsEnabled = on if on then StartPingChams() else StopPingChams() end end,
        BulletTracers = ToggleBulletTracers,

        -- Combat
        ExtendedHitbox = function(on) if on then EnableExtendedHitbox() else DisableExtendedHitbox() end end,
        ExtendedHitboxSize = function(v) State.ExtendedHitboxSize = v if State.ExtendedHitboxEnabled then UpdateHitboxSize(v) end end,
        SpawnAtPlayer = function(on) State.spawnAtPlayer = on end,
        KillAura = ToggleKillAura,
        InstantPickup = function(on) if on then EnableInstantPickup() else DisableInstantPickup() end end,

        -- Farming
        AutoFarm = function(on)
            State.AutoFarmEnabled = on
            if on then
                State.CoinBlacklist = {}
                State.StartSessionCoins = GetCollectedCoinsCount()
                ShowNotification("Auto Farm: <font color=\"rgb(85,255,120)\">ON</font>", CONFIG.Colors.Text)
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

        -- Orbit / Troll
        Orbit = function(on) State.OrbitEnabled = on RigidOrbitPlayer(State.SelectedPlayerForFling, on) end,
        LoopFling = function(on) State.LoopFlingEnabled = on SimpleLoopFling(State.SelectedPlayerForFling, on) end,
        BlockPath = function(on) State.BlockPathEnabled = on PendulumBlockPath(State.SelectedPlayerForFling, on) end,
        OrbitRadius = function(v) State.OrbitRadius = v end,
        OrbitSpeed = function(v) State.OrbitSpeed = v end,
        OrbitHeight = function(v) State.OrbitHeight = v end,
        OrbitTilt = function(v) State.OrbitTilt = v end,
        BlockPathSpeed = function(v) State.BlockPathSpeed = v end,
        OrbitPresetFastSpin = function() State.OrbitRadius = 4; State.OrbitSpeed = 10; State.OrbitHeight = 0; State.OrbitTilt = 0 end,
        OrbitPresetVerticalLoop = function() State.OrbitRadius = 5; State.OrbitSpeed = 5; State.OrbitHeight = 0; State.OrbitTilt = 90 end,
        OrbitPresetChaoticSpin = function() State.OrbitRadius = 2; State.OrbitSpeed = 15; State.OrbitHeight = 0; State.OrbitTilt = 30 end,

        -- Server
        Rejoin = Rejoin,
        ServerHop = ServerHop,
        HandleAutoRejoin = HandleAutoRejoin,
        HandleAutoReconnect = HandleAutoReconnect,
        SetReconnectInterval = SetReconnectInterval,
        
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

        Shutdown = function() FullShutdown() end,
    }
})

GUI.Init()
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
ApplyCharacterSettings()

pcall(function()
    ApplyFOV(State.CameraFOV)
end)
SetupAntiAFK()
StartRoleChecking()
SetupGunTracking()
if AUTOEXEC_ENABLED then
    -- Автоклик кнопки Play (friend join menu)
    task.spawn(function()
        pcall(function()
            local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui", 10)
            if not playerGui then return end
            
            local function clickPlayButton()
                for _, gui in pairs(playerGui:GetDescendants()) do
                    if gui:IsA("TextButton") and gui.Text == "Play" and gui.Visible then
                        for _, connection in pairs(getconnections(gui.MouseButton1Click)) do
                            connection:Fire()
                        end
                        return true
                    end
                end
                return false
            end
            
            task.wait(0.5)
            if not clickPlayButton() then
                playerGui.DescendantAdded:Connect(function(descendant)
                    if descendant:IsA("TextButton") and descendant.Text == "Play" then
                        task.wait(0.2)
                        for _, connection in pairs(getconnections(descendant.MouseButton1Click)) do
                            connection:Fire()
                        end
                    end
                end)
            end
        end)
    end)
    
    task.spawn(function()
        task.wait(2)
        pcall(function()
            State.AutoFarmEnabled = true
            State.UndergroundMode = true
            StartAutoFarm()
            
            task.wait(0.1)
            State.XPFarmEnabled = true
            StartXPFarm()
            
            task.wait(0.1)
            EnableInstantPickup()
            
            task.wait(0.1)
            EnableAntiFling()
            
            task.wait(0.1)
            HandleAutoRejoin(true)
            
            task.wait(0.1)
            HandleAutoReconnect(true)
            
            task.wait(0.1)
            EnableFPSBoost()
        end)
    end)
end
--print("╔════════════════════════════════════════════╗")
--print("║   MM2 ESP v6.0 - Successfully Loaded!     ║")
--print("║   Press [" .. CONFIG.HideKey.Name .. "] to toggle GUI               ║")
--print("╚════════════════════════════════════════════╝")
