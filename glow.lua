--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer

local notify
local createTween

local enabled = true
local ghostModel, ghostPart, pingGui
local ghostFuturePart, futureGui
-- tracers removed
local ghostRig = {} -- [partName] = {part=BasePart, aura=ParticleEmitter}
local ghostClone -- past ping chams
local ghostMap = {} -- past chams [partName] = cloned BasePart
local ghostCloneFuture -- predictive chams
local ghostMapFuture = {} -- future chams
local portals = {}
local lastSampleRoot = nil
local lastColor = Color3.fromRGB(40,180,255)
local renderConn, inputConn, playerAddedConn, charAddedConn
local menuVisibleState = false
local playersVisibleState = false
local playersFrame
local targetHighlights = {} -- [playerName] = Highlight
local flingActive = false
local selectedTargets = {}
local invisibleFlingActive = false
local antiFlingActive = false
local walkFlingActive = false
local voidAnchor, voidChams, voidBV, voidBP, voidPrevSubject, voidPrevType, voidPrevMode
local voidY = 12000
local voidOldPos
local walkFlingConn
local antiFlingConn
local F2Clone, F2PrevSubject, F2PrevType, F2PrevMode, F2Active
local smoothingClone, smoothingConn, smoothingPrevSubject
local F2BConn, F2EConn, F2StepConn
local F2Keys = {w=false,a=false,s=false,d=false,up=false,down=false}
local AFLastSafe
local currentFlingTarget = nil
local function cleanup()
    flingActive = false
    pcall(function()
        if F2StepConn then F2StepConn:Disconnect() end
        if F2BConn then F2BConn:Disconnect() end
        if F2EConn then F2EConn:Disconnect() end
        if F2Clone then F2Clone:Destroy() end
        if smoothingConn then smoothingConn:Disconnect() smoothingConn = nil end
        if smoothingClone then smoothingClone:Destroy() smoothingClone = nil end
        if walkFlingConn then walkFlingConn:Disconnect() end
        if antiFlingConn then antiFlingConn:Disconnect() end
    end)
    if renderConn then renderConn:Disconnect() renderConn=nil end
    if inputConn then inputConn:Disconnect() inputConn=nil end
    if playerAddedConn then playerAddedConn:Disconnect() playerAddedConn=nil end
    if charAddedConn then charAddedConn:Disconnect() charAddedConn=nil end
    if controlGui then pcall(function() controlGui:Destroy() end) controlGui=nil end
    if tracerGui then pcall(function() tracerGui:Destroy() end) tracerGui=nil tracerLinePast=nil tracerLineFuture=nil end
    if pingGui then pcall(function() pingGui:Destroy() end) pingGui=nil end
    if futureGui then pcall(function() futureGui:Destroy() end) futureGui=nil end
    if ghostModel then pcall(function() ghostModel:Destroy() end) ghostModel=nil ghostClone=nil ghostCloneFuture=nil end
    for i=#portals,1,-1 do
        local p = portals[i]
        if p and p.model then pcall(function() p.model:Destroy() end) end
        portals[i]=nil
    end
end
if _G.GhostPing and _G.GhostPing.cleanup then pcall(_G.GhostPing.cleanup) end
if _G.GhostPingUI and _G.GhostPingUI.cleanupUI then pcall(_G.GhostPingUI.cleanupUI) end
local function cleanupUI()
    local pg = LP:FindFirstChild("PlayerGui")
    if controlGui then pcall(function() controlGui:Destroy() end) controlGui=nil end
    if tracerGui then pcall(function() tracerGui:Destroy() end) tracerGui=nil tracerLine=nil end
    if pg then
        local old1 = pg:FindFirstChild("GhostControlUI")
        if old1 then pcall(function() old1:Destroy() end) end
        local old2 = pg:FindFirstChild("GhostTracerGui")
        if old2 then pcall(function() old2:Destroy() end) end
    end
end
local settings = {
    pingChams = true,
    predictionChams = true,
    pingColor = Color3.fromRGB(40,180,255),
    predictionColor = Color3.fromRGB(160,100,255),
    material = Enum.Material.ForceField,
    opacity = 0.5,
    delayMul = 1.0,
    tracer = true,
    aaMode = "Off",
    aaSpinSpeed = 180,
    aaApply = false,
    menuKeybind = Enum.KeyCode.RightControl,
    uiScale = 1.0,
    watermarkEnabled = false,
    watermarkOptions = {
        ["Username"] = true,
        ["FPS"] = true,
        ["Ping"] = true,
        ["Avatar"] = true
    },
    lighting = {
        enabled = false,
        brightness = 2,
        exposure = 0,
        fogEnd = 100000,
        fogStart = 0,
        clockTime = 12,
        outdoorAmbient = Color3.fromRGB(128, 128, 128),
        ambient = Color3.fromRGB(0, 0, 0),
        colorShift_Top = Color3.fromRGB(0, 0, 0),
        colorShift_Bottom = Color3.fromRGB(0, 0, 0),
        shadowSoftness = 0.5,
        globalShadows = true
    },
    esp = {
        enabled = false,
        box = false,
        name = false,
        health = false,
        tracers = false,
        weapon = false,
        visibleOnly = false,
        teamCheck = false,
        maxDistance = 1000,
        showDistance = false,
        showHealth = false
    },
    exploits = {
        noCameraRotate = false,
        walkSpeedEnabled = false,
        walkSpeedActive = false,
        walkSpeed = 16,
        walkSpeedMethod = "Default", -- "Default" or "CFrame"
        jumpPowerEnabled = false,
        jumpPower = 50,
        fovEnabled = false,
        fovAmount = 90,
        gravityEnabled = false,
        gravityAmount = 196.2,
        antiVoidEnabled = false,
        showVoidLevel = false,
        voidGodMode = false,
        hipHeightEnabled = false,
        hipHeightAmount = 2,
        flightEnabled = false,
        flightActive = false,
        flightSpeed = 50,
        flightKeybind = Enum.KeyCode.F,
        walkSpeedKeybind = Enum.KeyCode.C,
        noclipEnabled = false,
        noclipActive = false,
        noclipKeybind = Enum.KeyCode.V
    },
    desync = {
        enabled = false,
        method = "Velocity", -- "Velocity", "CFrame", "Freeze"
        power = 50,
        range = 5,
        visualize = false,
        color = Color3.fromRGB(255, 0, 0),
        movement = {
            type = "None", -- "None", "Spinbot", "Backwards", "Upside down"
            speed = 50
        },
        chams = {
            enabled = false,
            color = Color3.fromRGB(0, 255, 255)
        }
    },
    fling = {
        smoothing = false
    }
}
local aaGyro
local isBinding = false
local isLoaded = false
local keybindListEnabled = false
local keybindListFrame = nil
local isAdmin = (LP.UserId == 10198515386 or LP.UserId == 10136987698)

local voidHighlight = Instance.new("Part")
voidHighlight.Name = "VoidHighlight"
voidHighlight.Anchored = true
voidHighlight.CanCollide = false
voidHighlight.CastShadow = false
voidHighlight.Material = Enum.Material.ForceField
voidHighlight.Transparency = 1
voidHighlight.Size = Vector3.new(5000, 1, 5000)
voidHighlight.Parent = workspace

local voidFloor = Instance.new("Part")
voidFloor.Name = "VoidFloor"
voidFloor.Anchored = true
voidFloor.CanCollide = false
voidFloor.Transparency = 1
voidFloor.Size = Vector3.new(100, 1, 100)
voidFloor.Parent = workspace

local function tagCharacter(char)
    if not char then return end
    task.wait(1) -- Wait for character to fully load
    if char:FindFirstChild("AtlantaSigma_User") then return end
    
    local tag = Instance.new("StringValue")
    tag.Name = "AtlantaSigma_User"
    tag.Value = "Active"
    tag.Parent = char
end

local desyncGhost
local desyncChamsFolder = nil
local function updateDesyncLogic()
    local lastRealPos = nil
    local spinAngle = 0
    while task.wait() do
        if settings.desync.enabled then
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local power = settings.desync.power
                local range = settings.desync.range
                
                -- Desync Movement Logic (Spinbot, Backwards, Upside down)
                local moveType = settings.desync.movement.type
                local oldCF = hrp.CFrame
                
                if moveType ~= "None" then
                    local fakeCF = oldCF
                    if moveType == "Spinbot" then
                        spinAngle = (spinAngle + settings.desync.movement.speed) % 360
                        fakeCF = oldCF * CFrame.Angles(0, math.rad(spinAngle), 0)
                    elseif moveType == "Backwards" then
                        fakeCF = oldCF * CFrame.Angles(0, math.rad(180), 0)
                    elseif moveType == "Upside down" then
                        fakeCF = oldCF * CFrame.Angles(math.rad(180), 0, 0)
                    end
                    
                    hrp.CFrame = fakeCF
                    RunService.Heartbeat:Wait()
                    hrp.CFrame = oldCF
                end

                -- Method Logic
                if settings.desync.method == "Velocity" then
                    local oldVel = hrp.AssemblyLinearVelocity
                    hrp.AssemblyLinearVelocity = Vector3.new(0, power * 100, 0)
                    RunService.Heartbeat:Wait()
                    hrp.AssemblyLinearVelocity = oldVel
                elseif settings.desync.method == "CFrame" then
                    local currentCF = hrp.CFrame
                    hrp.CFrame = currentCF * CFrame.new(0, range * 10, 0)
                    RunService.Heartbeat:Wait()
                    hrp.CFrame = currentCF
                elseif settings.desync.method == "Freeze" then
                    if not lastRealPos then lastRealPos = hrp.CFrame end
                    if tick() % 0.5 < 0.05 then
                        lastRealPos = hrp.CFrame
                    else
                        hrp.CFrame = lastRealPos
                        RunService.Heartbeat:Wait()
                    end
                end
                
                -- Desync Chams (Mirror what others see)
                if settings.desync.chams.enabled then
                    if not desyncChamsFolder then
                        desyncChamsFolder = Instance.new("Folder")
                        desyncChamsFolder.Name = "DesyncChams"
                        desyncChamsFolder.Parent = workspace
                        
                        local highlight = Instance.new("Highlight")
                        highlight.Name = "ChamHighlight"
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.FillTransparency = 0.5
                        highlight.OutlineTransparency = 0
                        highlight.Parent = desyncChamsFolder
                    end
                    
                    local highlight = desyncChamsFolder:FindFirstChild("ChamHighlight")
                    if highlight then
                        highlight.FillColor = settings.desync.chams.color
                        highlight.OutlineColor = settings.desync.chams.color
                    end

                    for _, part in pairs(char:GetChildren()) do
                        if part:IsA("BasePart") then
                            local chamPart = desyncChamsFolder:FindFirstChild(part.Name)
                            if not chamPart then
                                chamPart = Instance.new("Part")
                                chamPart.Name = part.Name
                                chamPart.Size = part.Size
                                chamPart.CanCollide = false
                                chamPart.Anchored = true
                                chamPart.Transparency = 1 -- Let highlight handle visuals
                                chamPart.Parent = desyncChamsFolder
                            end
                            
                            -- Calculate visual position
                            local visualCF = part.CFrame
                            if moveType == "Spinbot" then
                                visualCF = (hrp.CFrame * CFrame.Angles(0, math.rad(spinAngle), 0)) * (hrp.CFrame:Inverse() * part.CFrame)
                            elseif moveType == "Backwards" then
                                visualCF = (hrp.CFrame * CFrame.Angles(0, math.rad(180), 0)) * (hrp.CFrame:Inverse() * part.CFrame)
                            elseif moveType == "Upside down" then
                                visualCF = (hrp.CFrame * CFrame.Angles(math.rad(180), 0, 0)) * (hrp.CFrame:Inverse() * part.CFrame)
                            end
                            
                            chamPart.CFrame = visualCF
                        end
                    end
                elseif desyncChamsFolder then
                    desyncChamsFolder:ClearAllChildren()
                    desyncChamsFolder:Destroy()
                    desyncChamsFolder = nil
                end

                if settings.desync.visualize then
                    if not desyncGhost then
                        desyncGhost = Instance.new("Part")
                        desyncGhost.Name = "DesyncGhost"
                        desyncGhost.Anchored = true
                        desyncGhost.CanCollide = false
                        desyncGhost.Transparency = 0.5
                        desyncGhost.Material = Enum.Material.ForceField
                        desyncGhost.Size = Vector3.new(2, 2, 1)
                        desyncGhost.Parent = workspace
                    end
                    desyncGhost.Color = settings.desync.color
                    desyncGhost.CFrame = hrp.CFrame
                    desyncGhost.Visible = true
                elseif desyncGhost then
                    desyncGhost.Visible = false
                end
            end
        else
            lastRealPos = nil
            if desyncChamsFolder then
                desyncChamsFolder:ClearAllChildren()
                desyncChamsFolder:Destroy()
                desyncChamsFolder = nil
            end
            if desyncGhost then
                desyncGhost.Visible = false
            end
        end
    end
end
task.spawn(updateDesyncLogic)

local function updateFlingSmoothing()
    while task.wait() do
        local isFlinging = flingActive or walkFlingActive or invisibleFlingActive
        local shouldSmooth = settings.fling.smoothing and isFlinging
        
        if shouldSmooth then
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            
            -- Method 4: Visual Model Proxy (The "Ghost" Character)
            -- This is the most reliable method. We create a local-only model that looks like you,
            -- lock your camera to it, and move it smoothly. Meanwhile, your REAL character
            -- is flinging around at extreme velocities but is completely invisible to you.
            
            if not smoothingClone then
                smoothingClone = Instance.new("Model")
                smoothingClone.Name = "VisualProxy"
                
                -- Clone visuals
                for _, v in pairs(char:GetChildren()) do
                    if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                        local c = v:Clone()
                        c.CanCollide = false
                        c.Anchored = true
                        c.Parent = smoothingClone
                    elseif v:IsA("Accessory") then
                        local c = v:Clone()
                        local handle = c:FindFirstChild("Handle")
                        if handle then
                            handle.CanCollide = false
                            handle.Anchored = true
                        end
                        c.Parent = smoothingClone
                    end
                end
                
                smoothingClone.Parent = workspace
                smoothingPrevSubject = workspace.CurrentCamera.CameraSubject
                workspace.CurrentCamera.CameraSubject = smoothingClone:FindFirstChild("Head") or smoothingClone:GetChildren()[1]
            end
            
            -- Hide real character ONLY on client
            for _, v in pairs(char:GetChildren()) do
                if v:IsA("BasePart") then
                    v.LocalTransparencyModifier = 1
                elseif v:IsA("Accessory") and v:FindFirstChild("Handle") then
                    v.Handle.LocalTransparencyModifier = 1
                end
            end
            
            -- Update real character with chaos (Server-side fling)
            hrp.AssemblyLinearVelocity = Vector3.new(999999, 999999, 999999)
            hrp.AssemblyAngularVelocity = Vector3.new(999999, 999999, 999999)
            
            -- Move visual proxy smoothly to where we actually are
            local stableCF = hrp.CFrame
            -- Remove any crazy rotation from the stable CFrame for the proxy
            local look = stableCF.LookVector
            local flatCF = CFrame.new(stableCF.Position, stableCF.Position + Vector3.new(look.X, 0, look.Z))
            
            for _, v in pairs(smoothingClone:GetChildren()) do
                if v:IsA("BasePart") then
                    -- Calculate offset from real HRP
                    local realPart = char:FindFirstChild(v.Name)
                    if realPart then
                        local offset = hrp.CFrame:Inverse() * realPart.CFrame
                        v.CFrame = flatCF * offset
                    end
                elseif v:IsA("Accessory") then
                    local handle = v:FindFirstChild("Handle")
                    local realAcc = char:FindFirstChild(v.Name)
                    local realHandle = realAcc and realAcc:FindFirstChild("Handle")
                    if handle and realHandle then
                        local offset = hrp.CFrame:Inverse() * realHandle.CFrame
                        handle.CFrame = flatCF * offset
                    end
                end
            end
            
        elseif smoothingClone then
            -- Cleanup
            smoothingClone:Destroy()
            smoothingClone = nil
            
            local cam = workspace.CurrentCamera
            if smoothingPrevSubject then
                cam.CameraSubject = smoothingPrevSubject
            end
            
            -- Restore visibility
            local char = LP.Character
            if char then
                for _, v in pairs(char:GetChildren()) do
                    if v:IsA("BasePart") then
                        v.LocalTransparencyModifier = 0
                    elseif v:IsA("Accessory") and v:FindFirstChild("Handle") then
                        v.Handle.LocalTransparencyModifier = 0
                    end
                end
            end
        end
    end
end
task.spawn(updateFlingSmoothing)

local flightBV, flightBG
local function updateFlight()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    if settings.exploits.flightEnabled and settings.exploits.flightActive and root and hum then
        if not flightBV then
            flightBV = Instance.new("BodyVelocity")
            flightBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            flightBV.Velocity = Vector3.new(0, 0, 0)
            flightBV.Parent = root
            
            flightBG = Instance.new("BodyGyro")
            flightBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            flightBG.P = 10000
            flightBG.D = 100
            flightBG.CFrame = root.CFrame
            flightBG.Parent = root
        end
        
        hum.PlatformStand = true
        
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.new(0, 0, 0)
        
        if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        
        if moveDir.Magnitude > 0 then
            flightBV.Velocity = moveDir.Unit * settings.exploits.flightSpeed
        else
            flightBV.Velocity = Vector3.new(0, 0, 0)
        end
        
        flightBG.CFrame = cam.CFrame
    else
        if flightBV then flightBV:Destroy() flightBV = nil end
        if flightBG then flightBG:Destroy() flightBG = nil end
        if hum then hum.PlatformStand = false end
    end
end

LP.CharacterAdded:Connect(tagCharacter)
if LP.Character then task.spawn(tagCharacter, LP.Character) end

local BUFFER = {}
local BUFFER_MAX_SECONDS = 3.0
local rtt = 0.2
local lastPingUpdate = 0
local PING_UPDATE_INTERVAL = 0.2

local pingBuf = {}
local function median(tbl)
    local n = #tbl
    if n == 0 then return nil end
    table.sort(tbl)
    if n % 2 == 1 then
        return tbl[(n+1)//2]
    else
        return (tbl[n//2] + tbl[n//2+1]) * 0.5
    end
end
local function pushPing(sec)
    pingBuf[#pingBuf+1] = sec
    if #pingBuf > 20 then table.remove(pingBuf, 1) end
end
local function probePingMsStats()
    local ms
    local okPS, ps = pcall(function() return Stats.PerformanceStats end)
    if okPS and ps and typeof(ps.Ping) == "number" and ps.Ping > 0 then
        ms = ps.Ping
    end
    if not ms then
        local okItem, item = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"] end)
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
local function probePingMsRF()
    local okRS, RS = pcall(function() return game:GetService("ReplicatedStorage") end)
    if not okRS then return nil end
    local rf = RS:FindFirstChild("PingRF")
    if not rf or not rf.IsA or not rf:IsA("RemoteFunction") then return nil end
    local t0 = tick()
    local ok, _ = pcall(function() return rf:InvokeServer() end)
    if not ok then return nil end
    local t1 = tick()
    return (t1 - t0) * 1000.0
end

local function Fling2Begin()
    if F2Active then return end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    if not root then return end
    F2Active = true
    F2PrevSubject = workspace.CurrentCamera.CameraSubject
    F2PrevType = workspace.CurrentCamera.CameraType
    F2PrevMode = LP.CameraMode

    F2Clone = Instance.new("Model")
    F2Clone.Name = "FlingClone"
    for _,v in pairs(char:GetChildren()) do
        if v:IsA("BasePart") or v:IsA("Accessory") then
            local c = v:Clone()
            if c:IsA("BasePart") then
                c.CanCollide = false
                c.Transparency = 0.5
            elseif c:IsA("Accessory") and c:FindFirstChild("Handle") then
                c.Handle.CanCollide = false
                c.Handle.Transparency = 0.5
            end
            c.Parent = F2Clone
        end
    end
    F2Clone.Parent = workspace
    workspace.CurrentCamera.CameraSubject = F2Clone:FindFirstChild("Humanoid") or F2Clone:FindFirstChild("Head") or F2Clone.PrimaryPart
    
    F2BConn = UIS.InputBegan:Connect(function(input, gp)
        if gp or not F2Active then return end
        local k = input.KeyCode
        if k == Enum.KeyCode.W then F2Keys.w = true elseif k==Enum.KeyCode.A then F2Keys.a=true elseif k==Enum.KeyCode.S then F2Keys.s=true elseif k==Enum.KeyCode.D then F2Keys.d=true elseif k==Enum.KeyCode.Space then F2Keys.up=true elseif k==Enum.KeyCode.LeftShift then F2Keys.down=true end
    end)
    F2EConn = UIS.InputEnded:Connect(function(input, gp)
        if gp or not F2Active then return end
        local k = input.KeyCode
        if k == Enum.KeyCode.W then F2Keys.w = false elseif k==Enum.KeyCode.A then F2Keys.a=false elseif k==Enum.KeyCode.S then F2Keys.s=false elseif k==Enum.KeyCode.D then F2Keys.d=false elseif k==Enum.KeyCode.Space then F2Keys.up=false elseif k==Enum.KeyCode.LeftShift then F2Keys.down=false end
    end)
    F2StepConn = RunService.RenderStepped:Connect(function(dt)
        if not F2Active or not F2Clone or not F2Clone.PrimaryPart then return end
        local speed = 16
        local dx = (F2Keys.d and 1 or 0) - (F2Keys.a and 1 or 0)
        local dz = (F2Keys.s and 1 or 0) - (F2Keys.w and 1 or 0)
        local dy = (F2Keys.up and 1 or 0) - (F2Keys.down and 1 or 0)
        local vec = Vector3.new(dx, dy, dz)
        if vec.Magnitude > 0 then
            local cf = F2Clone:GetPivot()
            local move = cf * CFrame.new(vec.X*speed*dt, vec.Y*speed*dt, vec.Z*speed*dt)
            F2Clone:PivotTo(move)
            if hum and root then
                root.CFrame = move
                char:SetPrimaryPartCFrame(move)
                hum:MoveTo(move.Position)
            end
        end
    end)
end

local function Fling2End()
    if F2StepConn then F2StepConn:Disconnect() F2StepConn=nil end
    if F2BConn then F2BConn:Disconnect() F2BConn=nil end
    if F2EConn then F2EConn:Disconnect() F2EConn=nil end
    if F2Clone then pcall(function() F2Clone:Destroy() end) F2Clone=nil end
    local cam = workspace.CurrentCamera
    if F2PrevSubject then cam.CameraSubject = F2PrevSubject end
    if F2PrevType then cam.CameraType = F2PrevType end
    if F2PrevMode then pcall(function() LP.CameraMode = F2PrevMode end) end
    F2Active = false
    F2Keys = {w=false,a=false,s=false,d=false,up=false,down=false}
end

local function WalkFlingStart()
    if walkFlingActive then return end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    if not root then return end
    walkFlingActive = true
    notify("Walk Fling", "Walk Fling has been enabled.", 3)
    
    local movel = 0.1
    walkFlingConn = RunService.Heartbeat:Connect(function()
        if not walkFlingActive or not root or not root.Parent then 
            WalkFlingStop()
            return 
        end
        
        -- Logic from FPSBooster_Aggressive.client.lua
        local vel = root.Velocity
        if not settings.fling.smoothing then
            root.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
        end
        RunService.RenderStepped:Wait()
        if not walkFlingActive then return end
        root.Velocity = vel
        RunService.Stepped:Wait()
        if not walkFlingActive then return end
        root.Velocity = vel + Vector3.new(0, movel, 0)
        movel = -movel
    end)
end

local function WalkFlingStop()
    if not walkFlingActive then return end
    walkFlingActive = false
    if walkFlingConn then walkFlingConn:Disconnect() walkFlingConn=nil end
    notify("Walk Fling", "Walk Fling has been disabled.", 3)
    
    -- Reset velocities when stopping
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    if root then
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
end

local function AntiFlingStart()
    if antiFlingActive then return end
    antiFlingActive = true
    notify("Anti Fling", "Anti Fling has been enabled.", 3)
    antiFlingConn = RunService.RenderStepped:Connect(function()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = hum and hum.RootPart
        if not root then return end
        local v = root.AssemblyLinearVelocity or root.Velocity
        local limit = 120
        if v.Magnitude > limit then
            pcall(function() root.AssemblyLinearVelocity = Vector3.new() end)
            root.Velocity = Vector3.new()
            root.RotVelocity = Vector3.new()
            if AFLastSafe then
                root.CFrame = AFLastSafe
                pcall(function() char:SetPrimaryPartCFrame(AFLastSafe) end)
            end
        else
            AFLastSafe = root.CFrame
        end
        hum.PlatformStand = false
    end)
end

local function AntiFlingStop()
    if not antiFlingActive then return end
    antiFlingActive = false
    if antiFlingConn then antiFlingConn:Disconnect() antiFlingConn=nil end
    notify("Anti Fling", "Anti Fling has been disabled.", 3)
end

local function SkidFling(TargetPlayer)
    local Character = LP.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart
    local TCharacter = TargetPlayer.Character
    if not TCharacter then return end
    currentFlingTarget = TargetPlayer
    
    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")
    
    if Character and Humanoid and RootPart then
        local OldPos = RootPart.CFrame
        local FPDH = workspace.FallenPartsDestroyHeight
        workspace.FallenPartsDestroyHeight = 0/0
        
        local Time = tick()
        repeat
            if not flingActive then break end
            if not TRootPart or not TRootPart.Parent then break end
            
            local TPos = TRootPart.Position
            local TVel = TRootPart.AssemblyLinearVelocity or TRootPart.Velocity
            
            -- Enhanced Ping-based prediction logic
            local pingSec = rtt or 0.1
            
            -- Dynamic prediction: account for ping and a small frame buffer
            -- Prediction lead = ping + frame time (1/60) + small constant for server delay
            local predictionLead = pingSec + (1/60) + 0.05
            local predictedPos = TPos + (TVel * predictionLead)
            
            -- If target is moving fast, add a bit more lead
            if TVel.Magnitude > 10 then
                predictedPos = predictedPos + (TVel.Unit * 1.2)
            end
            
            -- Add some jitter to bypass anti-fling or catch edge cases
            local jitter = Vector3.new(math.random(-1, 1), math.random(-1, 1), math.random(-1, 1)) * 0.15
            predictedPos = predictedPos + jitter
            
            if invisibleFlingActive then
                RootPart.CFrame = CFrame.new(predictedPos)
            else
                -- Position flinger slightly above target for better impact if not invisible
                RootPart.CFrame = CFrame.new(predictedPos + Vector3.new(0, 0.5, 0))
            end
            
            if not settings.fling.smoothing then
                -- Maximize velocity and rotation for "skid" effect
                RootPart.Velocity = Vector3.new(1000000, 1000000, 1000000)
                -- Add extreme angular velocity to increase hit force
                RootPart.RotVelocity = Vector3.new(0, 1000000, 0)
            end
            
            task.wait()
        until tick() - Time > 1.5 or not TRootPart or not TRootPart.Parent
        
        RootPart.CFrame = OldPos
        RootPart.Velocity = Vector3.new()
        RootPart.RotVelocity = Vector3.new()
        workspace.FallenPartsDestroyHeight = FPDH
    end
end

local function StartFling()
    if flingActive then return end
    local count = 0
    for _ in pairs(selectedTargets) do count = count + 1 end
    if count == 0 then 
        notify("Fling Error", "Please select at least one target first!", 4)
        return 
    end
    flingActive = true
    notify("Multi-Fling", "Starting fling attack on " .. tostring(count) .. " targets.", 4)
    task.spawn(function()
        while flingActive do
            for _, player in pairs(selectedTargets) do
                if not flingActive then break end
                if player and player.Parent then
                    SkidFling(player)
                end
                task.wait(0.01)
            end
            task.wait(0.1)
        end
    end)
end

local function StopFling()
    if not flingActive then return end
    flingActive = false
    notify("Multi-Fling", "Fling attack stopped.", 3)
end

local function applyVisuals()
    for _, gp in pairs(ghostMap) do
        gp.Material = settings.material
    end
    for _, gp in pairs(ghostMapFuture) do
        gp.Material = settings.material
    end
    -- tracers removed
end

local function applyLighting()
    if not settings.lighting.enabled then return end
    local L = game:GetService("Lighting")
    L.Brightness = settings.lighting.brightness
    L.ExposureCompensation = settings.lighting.exposure
    L.FogEnd = settings.lighting.fogEnd
    L.FogStart = settings.lighting.fogStart
    L.ClockTime = settings.lighting.clockTime
    L.OutdoorAmbient = settings.lighting.outdoorAmbient
    L.Ambient = settings.lighting.ambient
    L.ColorShift_Top = settings.lighting.colorShift_Top
    L.ColorShift_Bottom = settings.lighting.colorShift_Bottom
    L.ShadowSoftness = settings.lighting.shadowSoftness
    L.GlobalShadows = settings.lighting.globalShadows
end

local espObjects = {}

local function GetPlayerWeapon(Character)
    for _, tool in ipairs(Character:GetChildren()) do
        if tool:IsA("Tool") or tool:IsA("HopperBin") then
            return tool.Name
        end
    end
    return "None"
end

local function updateESP()
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    local viewportSize = camera.ViewportSize
    local localRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local fovFactor = math.tan(math.rad(camera.FieldOfView / 2)) * 2

    for player, objects in pairs(espObjects) do
        local success, err = pcall(function()
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local hum = character and character:FindFirstChild("Humanoid")
            
            if settings.esp.enabled and character and root and hum and hum.Health > 0 then
                -- Team Check
                if settings.esp.teamCheck and player.Team == LP.Team then
                    for _, obj in pairs(objects) do obj.Visible = false end
                    return
                end

                -- Max Distance
                local distance = localRoot and (root.Position - localRoot.Position).Magnitude or 0
                if distance > settings.esp.maxDistance then
                    for _, obj in pairs(objects) do obj.Visible = false end
                    return
                end

                -- Visible Only (Raycast)
                if settings.esp.visibleOnly then
                    local rayOrigin = camera.CFrame.Position
                    local rayDirection = (root.Position - rayOrigin).Unit * distance
                    local rayParams = RaycastParams.new()
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude
                    rayParams.FilterDescendantsInstances = {LP.Character, camera}
                    
                    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)
                    if raycastResult and not raycastResult.Instance:IsDescendantOf(character) then
                        for _, obj in pairs(objects) do obj.Visible = false end
                        return
                    end
                end

                local pos, onScreen = camera:WorldToViewportPoint(root.Position)
                
                if onScreen then
                    -- Logic from FPSBooster_NoTextures.client.lua
                    local boxSize = Vector2.new(2000 / pos.Z, 3000 / pos.Z)
                    local boxPos = Vector2.new(pos.X - boxSize.X / 2, pos.Y - boxSize.Y / 2)
                    local boxWidth, boxHeight = boxSize.X, boxSize.Y
                    
                    -- Sanity check for size
                    if boxHeight > 2000 then boxHeight = 2000 end
                    if boxWidth > 2000 then boxWidth = 2000 end
                    if boxHeight < 1 then boxHeight = 1 end
                    if boxWidth < 1 then boxWidth = 1 end

                    -- Update Box
                    if settings.esp.box then
                        objects.box.Size = Vector2.new(boxWidth, boxHeight)
                        objects.box.Position = boxPos
                        objects.box.Color = theme.accent
                        objects.box.Thickness = 2
                        objects.box.Visible = true
                    else
                        objects.box.Visible = false
                    end
                    
                    -- Update Name
                    if settings.esp.name then
                        local infoText = player.DisplayName
                        if settings.esp.showDistance then
                            infoText = infoText .. string.format(" [%dm]", math.floor(distance))
                        end
                        if settings.esp.showHealth then
                            infoText = infoText .. string.format(" [%.0fHP]", hum.Health)
                        end
                        
                        objects.name.Text = infoText
                        objects.name.Position = Vector2.new(pos.X, boxPos.Y - 18)
                        objects.name.Color = Color3.fromRGB(255, 255, 255)
                        objects.name.Size = 13
                        objects.name.Visible = true
                    else
                        objects.name.Visible = false
                    end
                    
                    -- Update Health Bar
                    if settings.esp.health then
                        local healthPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        
                        objects.healthBg.Position = Vector2.new(boxPos.X - 6, boxPos.Y)
                        objects.healthBg.Size = Vector2.new(2, boxHeight)
                        objects.healthBg.Visible = true
                        
                        objects.healthBar.Position = Vector2.new(boxPos.X - 6, boxPos.Y + (boxHeight * (1 - healthPercent)))
                        objects.healthBar.Size = Vector2.new(2, boxHeight * healthPercent)
                        objects.healthBar.Color = Color3.fromHSV(healthPercent * 0.3, 1, 1)
                        objects.healthBar.Visible = true
                    else
                        objects.healthBg.Visible = false
                        objects.healthBar.Visible = false
                    end

                    -- Update Weapon
                    if settings.esp.weapon then
                        objects.weapon.Text = GetPlayerWeapon(character)
                        objects.weapon.Position = Vector2.new(pos.X, boxPos.Y + boxHeight + 5)
                        objects.weapon.Color = Color3.fromRGB(200, 200, 200)
                        objects.weapon.Size = 13
                        objects.weapon.Visible = true
                    else
                        objects.weapon.Visible = false
                    end

                    -- Update Tracers
                    if settings.esp.tracers then
                        objects.tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
                        objects.tracer.To = Vector2.new(pos.X, pos.Y) -- Point to center like FPSBooster
                        objects.tracer.Color = theme.accent
                        objects.tracer.Thickness = 1
                        objects.tracer.Visible = true
                    else
                        objects.tracer.Visible = false
                    end

                    -- Update Admin Script User Tag
                    if isAdmin then
                        local isScriptUser = character:FindFirstChild("AtlantaSigma_User")
                        if isScriptUser then
                            objects.scriptUser.Position = Vector2.new(pos.X, boxPos.Y - 35)
                            objects.scriptUser.Visible = true
                        else
                            objects.scriptUser.Visible = false
                        end
                    else
                        objects.scriptUser.Visible = false
                    end
                else
                    for _, obj in pairs(objects) do obj.Visible = false end
                end
            else
                for _, obj in pairs(objects) do obj.Visible = false end
            end
        end)
        
        if not success then
            -- Silent fail for individual players to prevent the whole ESP from freezing
        end
    end
end

local function createESP(player)
    if player == LP then return end
    if espObjects[player] then return end

    local objects = {
        box = Drawing.new("Square"),
        name = Drawing.new("Text"),
        healthBg = Drawing.new("Square"),
        healthBar = Drawing.new("Square"),
        tracer = Drawing.new("Line"),
        weapon = Drawing.new("Text"),
        scriptUser = Drawing.new("Text")
    }
    
    -- Box
    objects.box.Thickness = 1
    objects.box.Filled = false
    objects.box.Visible = false
    objects.box.ZIndex = 2
    
    -- Name
    objects.name.Size = 13
    objects.name.Center = true
    objects.name.Outline = true
    objects.name.Visible = false
    objects.name.ZIndex = 2
    
    -- Health Bar Background
    objects.healthBg.Thickness = 1
    objects.healthBg.Filled = true
    objects.healthBg.Color = Color3.fromRGB(0, 0, 0)
    objects.healthBg.Transparency = 0.5
    objects.healthBg.Visible = false
    objects.healthBg.ZIndex = 1
    
    -- Health Bar Fill
    objects.healthBar.Thickness = 1
    objects.healthBar.Filled = true
    objects.healthBar.Visible = false
    objects.healthBar.ZIndex = 2
    
    -- Tracer
    objects.tracer.Thickness = 1
    objects.tracer.Visible = false
    objects.tracer.ZIndex = 1

    -- Weapon
    objects.weapon.Size = 13
    objects.weapon.Center = true
    objects.weapon.Outline = true
    objects.weapon.Visible = false
    objects.weapon.ZIndex = 2

    -- Script User Tag
    objects.scriptUser.Size = 13
    objects.scriptUser.Center = true
    objects.scriptUser.Outline = true
    objects.scriptUser.Color = Color3.fromRGB(255, 200, 0)
    objects.scriptUser.Text = "[SCRIPT USER]"
    objects.scriptUser.Visible = false
    objects.scriptUser.ZIndex = 3
    
    espObjects[player] = objects
end

local function removeESP(player)
    local objects = espObjects[player]
    if objects then
        for _, obj in pairs(objects) do
            if obj.Remove then
                obj:Remove()
            end
        end
        espObjects[player] = nil
    end
end

Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)
for _, p in pairs(Players:GetPlayers()) do createESP(p) end

RunService.RenderStepped:Connect(updateESP)

task.spawn(function()
    while task.wait() do
        -- Flight
        updateFlight()

        -- Lighting
        if settings.lighting.enabled then
            applyLighting()
        end
        
        -- Exploits
        local character = LP.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        
        if humanoid then
            -- WalkSpeed
            if settings.exploits.walkSpeedEnabled and settings.exploits.walkSpeedActive then
                if settings.exploits.walkSpeedMethod == "Default" then
                    humanoid.WalkSpeed = settings.exploits.walkSpeed
                elseif settings.exploits.walkSpeedMethod == "CFrame" then
                    humanoid.WalkSpeed = 16
                    local root = character:FindFirstChild("HumanoidRootPart")
                    if root and humanoid.MoveDirection.Magnitude > 0 then
                        root.CFrame = root.CFrame + (humanoid.MoveDirection * (settings.exploits.walkSpeed / 50))
                    end
                end
            else
                humanoid.WalkSpeed = 16
            end

            -- JumpPower
            if settings.exploits.jumpPowerEnabled then
                humanoid.JumpPower = settings.exploits.jumpPower
                humanoid.UseJumpPower = true
            end
        end
        
        -- No Camera Rotate/Shake
        if settings.exploits.noCameraRotate then
            local camera = workspace.CurrentCamera
            if camera then
                -- This stops external shakes/rotations by forcing CFrame if needed, 
                -- but usually setting humanoid properties or overriding camera scripts is better.
                -- For now, we'll focus on the intent of "stopping anything from rotating or moving my camera" 
                -- by disabling camera bobbing if possible or just resetting rotation if it's forced.
            end
        end

        -- FOV
        if settings.exploits.fovEnabled then
            local camera = workspace.CurrentCamera
            if camera then
                camera.FieldOfView = settings.exploits.fovAmount
            end
        end

        -- Noclip
        if settings.exploits.noclipEnabled and settings.exploits.noclipActive and character then
            for _, v in pairs(character:GetDescendants()) do
                if v:IsA("BasePart") and v.CanCollide then
                    v.CanCollide = false
                end
            end
        end

        -- Gravity
        if settings.exploits.gravityEnabled then
            workspace.Gravity = settings.exploits.gravityAmount
        end

        -- HipHeight
        if settings.exploits.hipHeightEnabled then
            humanoid.HipHeight = settings.exploits.hipHeightAmount
        end

        -- Anti-Void & Void Highlight
        if character and character:FindFirstChild("HumanoidRootPart") then
            local root = character.HumanoidRootPart
            local voidY = workspace.FallenPartsDestroyHeight

            -- Update Highlight
            if settings.exploits.showVoidLevel then
                voidHighlight.Transparency = 0.5
                voidHighlight.CFrame = CFrame.new(root.Position.X, voidY, root.Position.Z)
            else
                voidHighlight.Transparency = 1
            end

            -- Anti-Void Logic
            if settings.exploits.antiVoidEnabled then
                local nextPos = root.Position + root.Velocity * 0.1 -- Predict position in next 0.1s
                if root.Position.Y < voidY + 20 or nextPos.Y < voidY + 15 then
                    root.Velocity = Vector3.new(0, 0, 0) -- Kill downward momentum instantly
                    root.CFrame = root.CFrame * CFrame.new(0, 30, 0) -- Teleport higher up
                    task.wait() -- Small yield to ensure physics update
                    root.Velocity = Vector3.new(0, 60, 0) -- Apply strong upward push
                end
            end

            -- Void God Mode (True Godmode Method)
            if settings.exploits.voidGodMode then
                -- Method: Temporarily move FallenPartsDestroyHeight to -infinity while in danger
                -- and force health/root properties to prevent death.
                if root.Position.Y < voidY + 10 then
                    workspace.FallenPartsDestroyHeight = -math.huge
                    humanoid.Health = 100
                    -- Reset velocity if falling too fast
                    if root.Velocity.Y < -50 then
                        root.Velocity = Vector3.new(root.Velocity.X, -10, root.Velocity.Z)
                    end
                else
                    -- Reset to original if safe
                    workspace.FallenPartsDestroyHeight = voidY
                end
                
                voidFloor.CanCollide = true
                voidFloor.CFrame = CFrame.new(root.Position.X, voidY + 5, root.Position.Z)
            else
                workspace.FallenPartsDestroyHeight = voidY
                voidFloor.CanCollide = false
            end
        else
            voidHighlight.Transparency = 1
            voidFloor.CanCollide = false
        end
    end
end)

local function createSlider(parent, labelText, initial, min, max, step, onChange)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,0,0,40)
    row.Parent = parent
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(180,180,180)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Size = UDim2.new(1,0,0,16)
    label.Parent = row
    local rail = Instance.new("Frame")
    rail.BackgroundColor3 = Color3.fromRGB(30,30,30)
    rail.BorderSizePixel = 0
    rail.Position = UDim2.new(0,0,0,20)
    rail.Size = UDim2.new(1,0,0,6)
    rail.Parent = row
    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(90,90,90)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new((initial-min)/(max-min),0,1,0)
    fill.Parent = rail
    local knob = Instance.new("Frame")
    knob.BackgroundColor3 = Color3.fromRGB(200,200,200)
    knob.BorderSizePixel = 0
    knob.AnchorPoint = Vector2.new(0.5,0.5)
    knob.Position = UDim2.new((initial-min)/(max-min),0,0.5,0)
    knob.Size = UDim2.new(0,10,0,10)
    knob.Parent = rail
    local dragging = false
    rail.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging = true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            local x = i.Position.X
            local abs = rail.AbsolutePosition.X
            local w = rail.AbsoluteSize.X
            local alpha = math.clamp((x-abs)/w,0,1)
            local val = min + math.floor(((max-min)*alpha)/step+0.5)*step
            fill.Size = UDim2.new((val-min)/(max-min),0,1,0)
            knob.Position = UDim2.new((val-min)/(max-min),0,0.5,0)
            onChange(val)
        end
    end)
end

local TweenService = game:GetService("TweenService")

local theme = {
    background = Color3.fromRGB(20, 20, 24),
    backgroundTrans = 0,
    sidebar = Color3.fromRGB(25, 25, 30),
    sidebarTrans = 0,
    accent = Color3.fromRGB(160, 100, 255),
    accentTrans = 0,
    text = Color3.fromRGB(220, 220, 220),
    textTrans = 0,
    textDim = Color3.fromRGB(150, 150, 150),
    textDimTrans = 0,
    glow = false,
    snow = false
}

local themeObjects = {}

local function registerTheme(instance, type, prop)
    table.insert(themeObjects, {instance=instance, type=type, prop=prop})
end

voidHighlight.Color = theme.accent
registerTheme(voidHighlight, "accent", "Color")

    local function applyThemeUpdates()
        for _, obj in ipairs(themeObjects) do
            if obj.instance and obj.instance.Parent then
                if obj.type == "background" then 
                    if obj.prop == "BackgroundColor3" then
                        obj.instance.BackgroundColor3 = theme.background
                        obj.instance.BackgroundTransparency = theme.backgroundTrans
                    else
                        obj.instance[obj.prop] = theme.background
                    end
                elseif obj.type == "sidebar" then 
                    if obj.prop == "BackgroundColor3" then
                        if obj.instance:GetAttribute("IsActiveTab") then
                            obj.instance.BackgroundColor3 = theme.accent
                            obj.instance.BackgroundTransparency = theme.accentTrans
                        else
                            obj.instance.BackgroundColor3 = theme.sidebar
                            obj.instance.BackgroundTransparency = theme.sidebarTrans
                        end
                    else
                        if obj.instance:GetAttribute("IsActiveTab") then
                            obj.instance[obj.prop] = theme.accent
                        else
                            obj.instance[obj.prop] = theme.sidebar
                        end
                    end
                elseif obj.type == "accent" then 
                    if obj.prop == "BackgroundColor3" then
                        obj.instance.BackgroundColor3 = theme.accent
                        obj.instance.BackgroundTransparency = theme.accentTrans
                    elseif obj.prop == "Color" and obj.instance:IsA("UIStroke") then
                        obj.instance.Color = theme.accent
                        obj.instance.Transparency = theme.accentTrans
                    else
                        obj.instance[obj.prop] = theme.accent
                    end
                elseif obj.type == "text" then 
                    if obj.prop == "TextColor3" then
                        obj.instance.TextColor3 = theme.text
                        obj.instance.TextTransparency = theme.textTrans
                    else
                        obj.instance[obj.prop] = theme.text
                    end
                elseif obj.type == "textDim" then 
                    if obj.prop == "TextColor3" then
                        obj.instance.TextColor3 = theme.textDim
                        obj.instance.TextTransparency = theme.textDimTrans
                    else
                        obj.instance[obj.prop] = theme.textDim
                    end
                elseif obj.type == "playerListBtn" then
                    if obj.instance:GetAttribute("Selected") then
                        obj.instance.BackgroundColor3 = theme.accent
                        obj.instance.BackgroundTransparency = theme.accentTrans
                    else
                        obj.instance.BackgroundColor3 = theme.sidebar
                        obj.instance.BackgroundTransparency = theme.sidebarTrans
                    end
                elseif obj.type == "toggleOn" then
                    if obj.instance[obj.prop] ~= Color3.fromRGB(40,40,45) then
                         obj.instance[obj.prop] = theme.accent
                    end
                end
            end
        end
    end

createTween = function(instance, properties, time, style, dir)
    local info = TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
    local tween = TweenService:Create(instance, info, properties)
    tween:Play()
    return tween
end

local notifyContainer
-- Roundness removed as per user request
-- Removing UICorner instances via search and replace...

notify = function(title, text, duration)
    if not notifyContainer then return end
    duration = duration or 5
    
    local notif = Instance.new("Frame")
    notif.Name = "Notification"
    notif.BackgroundColor3 = theme.background
    notif.BackgroundTransparency = theme.backgroundTrans
    notif.Size = UDim2.new(0, 250, 0, 60)
    notif.Position = UDim2.new(1, 20, 0, 0) -- Start offscreen
    notif.Parent = notifyContainer
    registerTheme(notif, "background", "BackgroundColor3")

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = title:upper()
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextColor3 = theme.accent
    titleLabel.TextTransparency = theme.accentTrans
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 10, 0, 8)
    titleLabel.Size = UDim2.new(1, -20, 0, 15)
    titleLabel.Parent = notif
    registerTheme(titleLabel, "accent", "TextColor3")

    local descLabel = Instance.new("TextLabel")
    descLabel.Text = text
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 12
    descLabel.TextColor3 = theme.text
    descLabel.TextTransparency = theme.textTrans
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextWrapped = true
    descLabel.BackgroundTransparency = 1
    descLabel.Position = UDim2.new(0, 10, 0, 25)
    descLabel.Size = UDim2.new(1, -20, 0, 0) -- Height handled by constraint
    descLabel.Parent = notif
    registerTheme(descLabel, "text", "TextColor3")

    local descConstraint = Instance.new("UITextSizeConstraint") -- Not used for wrapping height but for safety
    local descSize = game:GetService("TextService"):GetTextSize(text, 12, Enum.Font.Gotham, Vector2.new(230, 1000))
    local finalHeight = math.max(60, descSize.Y + 40)
    notif.Size = UDim2.new(0, 250, 0, finalHeight)
    descLabel.Size = UDim2.new(1, -20, 0, descSize.Y)

    local barBg = Instance.new("Frame")
    barBg.BackgroundColor3 = theme.sidebar
    barBg.BackgroundTransparency = theme.sidebarTrans
    barBg.BorderSizePixel = 0
    barBg.Position = UDim2.new(0, 0, 1, -3)
    barBg.Size = UDim2.new(1, 0, 0, 3)
    barBg.Parent = notif
    registerTheme(barBg, "sidebar", "BackgroundColor3")

    local bar = Instance.new("Frame")
    bar.BackgroundColor3 = theme.accent
    bar.BackgroundTransparency = theme.accentTrans
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(1, 0, 1, 0)
    bar.Parent = barBg
    registerTheme(bar, "accent", "BackgroundColor3")

    -- Animation
    createTween(notif, {Position = UDim2.new(0, 0, 0, 0)}, 0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    
    task.spawn(function()
        createTween(bar, {Size = UDim2.new(0, 0, 1, 0)}, duration, Enum.EasingStyle.Linear)
        task.wait(duration)
        local t = createTween(notif, {Position = UDim2.new(1, 20, 0, 0), BackgroundTransparency = 1}, 0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        createTween(titleLabel, {TextTransparency = 1}, 0.3)
        createTween(descLabel, {TextTransparency = 1}, 0.3)
        createTween(barBg, {BackgroundTransparency = 1}, 0.3)
        createTween(bar, {BackgroundTransparency = 1}, 0.3)
        t.Completed:Wait()
        notif:Destroy()
    end)
end

local controlGui
local mainFrame
local dockFrame
local watermarkFrame
local function buildSleekUI()
    if controlGui then return end
    controlGui = Instance.new("ScreenGui")
    controlGui.Name = "GhostControlUI"
    controlGui.ResetOnSpawn = false
    controlGui.IgnoreGuiInset = true
    controlGui.Enabled = true
    controlGui.DisplayOrder = 999
    controlGui.Parent = LP:WaitForChild("PlayerGui")

    notifyContainer = Instance.new("Frame")
    notifyContainer.Name = "NotificationContainer"
    notifyContainer.BackgroundTransparency = 1
    notifyContainer.Size = UDim2.new(0, 260, 1, -40)
    notifyContainer.Position = UDim2.new(1, -270, 0, 20)
    notifyContainer.Parent = controlGui

    local notifyLayout = Instance.new("UIListLayout")
    notifyLayout.Padding = UDim.new(0, 10)
    notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    notifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    notifyLayout.Parent = notifyContainer

    local function makeDraggable(frame)
        local dragStart, startPos, dragInput, dragging = nil, nil, nil, false
        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        frame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
        end)
        UIS.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    -- Watermark UI
    watermarkFrame = Instance.new("Frame")
    watermarkFrame.Name = "Watermark"
    watermarkFrame.BackgroundColor3 = theme.background
    watermarkFrame.BackgroundTransparency = 0.2
    watermarkFrame.Position = UDim2.new(0, 20, 0, 20)
    watermarkFrame.Visible = settings.watermarkEnabled
    watermarkFrame.Parent = controlGui
    registerTheme(watermarkFrame, "background", "BackgroundColor3")
    makeDraggable(watermarkFrame)

    local watermarkStroke = Instance.new("UIStroke")
    watermarkStroke.Color = theme.accent
    watermarkStroke.Thickness = 1
    watermarkStroke.Parent = watermarkFrame
    registerTheme(watermarkStroke, "accent", "Color")

    local watermarkAvatar = Instance.new("ImageLabel")
    watermarkAvatar.Name = "Avatar"
    watermarkAvatar.Size = UDim2.new(0, 18, 0, 18)
    watermarkAvatar.Position = UDim2.new(0, 6, 0.5, -9)
    watermarkAvatar.BackgroundTransparency = 1
    pcall(function()
        watermarkAvatar.Image = game:GetService("Players"):GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)
    watermarkAvatar.Visible = settings.watermarkOptions["Avatar"]
    watermarkAvatar.Parent = watermarkFrame

    local watermarkLabel = Instance.new("TextLabel")
    watermarkLabel.Name = "Label"
    watermarkLabel.Text = "skid"
    watermarkLabel.Font = Enum.Font.GothamMedium
    watermarkLabel.TextSize = 13
    watermarkLabel.TextColor3 = theme.text
    watermarkLabel.BackgroundTransparency = 1
    watermarkLabel.Size = UDim2.new(1, 0, 1, 0)
    watermarkLabel.Position = UDim2.new(0, 8, 0, 0)
    watermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
    watermarkLabel.Parent = watermarkFrame
    registerTheme(watermarkLabel, "text", "TextColor3")

    local function updateWatermark(fps)
        if not settings.watermarkEnabled then
            watermarkFrame.Visible = false
            return
        end
        watermarkFrame.Visible = true
        
        local showAvatar = settings.watermarkOptions["Avatar"]
        watermarkAvatar.Visible = showAvatar
        
        local parts = {"skid"}
        if settings.watermarkOptions["Username"] then
            table.insert(parts, LP.DisplayName .. " (@" .. LP.Name .. ")")
        end
        if settings.watermarkOptions["FPS"] and fps then
            table.insert(parts, "FPS: " .. tostring(fps))
        end
        if settings.watermarkOptions["Ping"] then
            local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            table.insert(parts, "Ping: " .. tostring(ping) .. "ms")
        end
        
        local fullText = table.concat(parts, " | ")
        watermarkLabel.Text = fullText
        
        local textSize = game:GetService("TextService"):GetTextSize(fullText, 13, Enum.Font.GothamMedium, Vector2.new(1000, 20))
        local avatarOffset = showAvatar and 28 or 8
        watermarkLabel.Position = UDim2.new(0, avatarOffset, 0, 0)
        watermarkFrame.Size = UDim2.new(0, textSize.X + avatarOffset + 8, 0, 24)
    end

    -- Proper FPS/Ping update loop for watermark
    task.spawn(function()
        local lastFpsUpdate = 0
        local fps = 60
        while true do
            local dt = RunService.RenderStepped:Wait()
            if settings.watermarkEnabled then
                if tick() - lastFpsUpdate > 0.5 then
                    fps = math.floor(1/dt)
                    lastFpsUpdate = tick()
                    updateWatermark(fps)
                end
            end
        end
    end)

    -- Loading Screen
    -- Create the centered menu-like loading window
    local loadingFrame = Instance.new("Frame")
    loadingFrame.Name = "LoadingWindow"
    loadingFrame.BackgroundColor3 = theme.background
    loadingFrame.BorderSizePixel = 0
    loadingFrame.Size = UDim2.new(0, 400, 0, 200)
    loadingFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    loadingFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    loadingFrame.Parent = controlGui

    local loadStroke = Instance.new("UIStroke")
    loadStroke.Color = Color3.fromRGB(45, 45, 50)
    loadStroke.Thickness = 1
    loadStroke.Parent = loadingFrame

    local logo = Instance.new("TextLabel")
    logo.Text = "skid"
    logo.Font = Enum.Font.GothamBold
    logo.TextSize = 36
    logo.TextColor3 = theme.accent
    logo.BackgroundTransparency = 1
    logo.Size = UDim2.new(1, 0, 0, 50)
    logo.Position = UDim2.new(0, 0, 0.25, 0)
    logo.TextTransparency = 1
    logo.Parent = loadingFrame

    local barBg = Instance.new("Frame")
    barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    barBg.BorderSizePixel = 0
    barBg.Size = UDim2.new(0.8, 0, 0, 6)
    barBg.AnchorPoint = Vector2.new(0.5, 0)
    barBg.Position = UDim2.new(0.5, 0, 0.7, 0)
    barBg.BackgroundTransparency = 1
    barBg.Parent = loadingFrame

    local barFill = Instance.new("Frame")
    barFill.BackgroundColor3 = theme.accent
    barFill.BorderSizePixel = 0
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.Parent = barBg

    local loadingLabel = Instance.new("TextLabel")
    loadingLabel.Text = "Initializing..."
    loadingLabel.Font = Enum.Font.Gotham
    loadingLabel.TextSize = 14
    loadingLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    loadingLabel.BackgroundTransparency = 1
    loadingLabel.Size = UDim2.new(0, 300, 0, 20)
    loadingLabel.AnchorPoint = Vector2.new(0.5, 1)
    loadingLabel.Position = UDim2.new(0.5, 0, 0.68, 0)
    loadingLabel.TextTransparency = 1
    loadingLabel.Parent = loadingFrame

    -- Main UI Container
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.BackgroundColor3 = theme.background
    registerTheme(mainFrame, "background", "BackgroundColor3")
    mainFrame.BorderSizePixel = 0
    mainFrame.Size = UDim2.new(0, 650, 0, 450)
    mainFrame.Position = UDim2.new(0.5, -325, 0.5, -225)
    mainFrame.ClipsDescendants = true
    mainFrame.Visible = false
    mainFrame.Parent = controlGui

    local mainScale = Instance.new("UIScale")
    mainScale.Name = "MainScale"
    mainScale.Scale = settings.uiScale
    mainScale.Parent = mainFrame

    -- Dock Bar
    dockFrame = Instance.new("Frame")
    dockFrame.Name = "DockBar"
    dockFrame.BackgroundColor3 = theme.background
    registerTheme(dockFrame, "background", "BackgroundColor3")
    dockFrame.Size = UDim2.new(0, 180, 0, 40)
    dockFrame.Position = UDim2.new(0.5, -90, 0, 20)
    dockFrame.BorderSizePixel = 0
    dockFrame.Visible = true
    dockFrame.Parent = controlGui

    local dockScale = Instance.new("UIScale")
    dockScale.Name = "DockScale"
    dockScale.Scale = settings.uiScale
    dockScale.Parent = dockFrame

    local dockLayout = Instance.new("UIListLayout")
    dockLayout.FillDirection = Enum.FillDirection.Horizontal
    dockLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    dockLayout.Padding = UDim.new(0, 5)
    dockLayout.Parent = dockFrame

    local dockStroke = Instance.new("UIStroke")
    dockStroke.Color = theme.accent
    registerTheme(dockStroke, "accent", "Color")
    dockStroke.Thickness = 1.5
    dockStroke.Parent = dockFrame

    local dockGlow = Instance.new("UIStroke")
    dockGlow.Name = "DockGlow"
    dockGlow.Color = theme.accent
    dockGlow.Thickness = 0
    dockGlow.Transparency = 0.5
    dockGlow.Parent = dockFrame

    local dockToggle = Instance.new("TextButton")
    dockToggle.Name = "ToggleButton"
    dockToggle.Modal = true
    dockToggle.Size = UDim2.new(0, 60, 1, 0)
    dockToggle.BackgroundTransparency = 1
    dockToggle.Text = "main"
    dockToggle.Font = Enum.Font.GothamBold
    dockToggle.TextSize = 16
    dockToggle.TextColor3 = theme.accent
    dockToggle.LayoutOrder = 1
    registerTheme(dockToggle, "accent", "TextColor3")
    dockToggle.Parent = dockFrame

    local separator = Instance.new("TextLabel")
    separator.Name = "Separator"
    separator.Size = UDim2.new(0, 10, 1, 0)
    separator.BackgroundTransparency = 1
    separator.Text = "|"
    separator.Font = Enum.Font.GothamBold
    separator.TextSize = 16
    separator.TextColor3 = Color3.fromRGB(60, 60, 65)
    separator.LayoutOrder = 2
    separator.Parent = dockFrame

    local playersToggle = Instance.new("TextButton")
    playersToggle.Name = "PlayersButton"
    playersToggle.Size = UDim2.new(0, 70, 1, 0)
    playersToggle.BackgroundTransparency = 1
    playersToggle.Text = "players"
    playersToggle.Font = Enum.Font.GothamBold
    playersToggle.TextSize = 16
    playersToggle.TextColor3 = theme.accent
    playersToggle.LayoutOrder = 3
    registerTheme(playersToggle, "accent", "TextColor3")
    playersToggle.Parent = dockFrame

    -- Players Toggle Glow
    local playersGlow = Instance.new("UIStroke")
    playersGlow.Name = "PlayersGlow"
    playersGlow.Color = theme.accent
    playersGlow.Thickness = 0
    playersGlow.Transparency = 0.5
    playersGlow.Parent = dockFrame -- We'll handle multiple glows or single frame glow logic later

    -- Dock Dragging
    local dockDragging, dockDragInput, dockDragStart, dockStartPos
    dockFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dockDragging = true
            dockDragStart = input.Position
            dockStartPos = dockFrame.Position
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dockDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dockDragStart
            dockFrame.Position = UDim2.new(dockStartPos.X.Scale, dockStartPos.X.Offset + delta.X, dockStartPos.Y.Scale, dockStartPos.Y.Offset + delta.Y)
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dockDragging = false end
    end)

    local function updateDockGlow()
        local active = mainFrame.Visible or (playersFrame and playersFrame.Visible)
        createTween(dockGlow, {Thickness = active and 3 or 0}, 0.3)
    end

    dockToggle.MouseButton1Click:Connect(function()
        menuVisibleState = not menuVisibleState
        mainFrame.Visible = menuVisibleState
        if updateSelectionInterface then updateSelectionInterface(false) end
        updateDockGlow()
    end)

    playersToggle.MouseButton1Click:Connect(function()
        playersVisibleState = not playersVisibleState
        if playersFrame then
            playersFrame.Visible = playersVisibleState
            updateSelectionInterface(false)
        end
        updateDockGlow()
    end)

    -- Hover effect for dock buttons
    local function setupHover(btn)
        btn.MouseEnter:Connect(function()
            createTween(dockStroke, {Color = theme.accent}, 0.2)
            createTween(btn, {TextSize = 18}, 0.2)
        end)
        btn.MouseLeave:Connect(function()
            createTween(dockStroke, {Color = Color3.fromRGB(45, 45, 50)}, 0.2)
            createTween(btn, {TextSize = 16}, 0.2)
        end)
    end
    setupHover(dockToggle)
    setupHover(playersToggle)

    local snowContainer = Instance.new("Frame")
    snowContainer.Name = "SnowContainer"
    snowContainer.BackgroundTransparency = 1
    snowContainer.Size = UDim2.new(1, 0, 1, 0)
    snowContainer.ZIndex = 10
    snowContainer.Parent = mainFrame

    -- Players Frame Implementation
    playersFrame = Instance.new("Frame")
    playersFrame.Name = "PlayersFrame"
    playersFrame.BackgroundColor3 = theme.background
    registerTheme(playersFrame, "background", "BackgroundColor3")
    playersFrame.BorderSizePixel = 0
    playersFrame.Size = UDim2.new(0, 300, 0, 400)
    playersFrame.Position = UDim2.new(0.5, 335, 0.5, -200) -- Positioned to the right of main frame
    playersFrame.Visible = false
    playersFrame.Parent = controlGui

    local playersScale = Instance.new("UIScale")
    playersScale.Name = "PlayersScale"
    playersScale.Scale = settings.uiScale
    playersScale.Parent = playersFrame

    -- Selection Interface (Avatars and Display Names)
    local selectionFrame = Instance.new("CanvasGroup")
    selectionFrame.Name = "SelectionInterface"
    selectionFrame.BackgroundColor3 = theme.background
    selectionFrame.BorderSizePixel = 0
    selectionFrame.Size = UDim2.new(0, 200, 0, 400)
    selectionFrame.Position = UDim2.new(1, 10, 0, 0) -- Positioned to the right of players frame
    selectionFrame.Visible = false
    selectionFrame.GroupTransparency = 1
    selectionFrame.Parent = playersFrame
    local selectionStroke = Instance.new("UIStroke")
    selectionStroke.Color = Color3.fromRGB(45, 45, 50)
    selectionStroke.Thickness = 1
    selectionStroke.Parent = selectionFrame

    local selectionTitle = Instance.new("TextLabel")
    selectionTitle.Size = UDim2.new(1, 0, 0, 40)
    selectionTitle.BackgroundTransparency = 1
    selectionTitle.Text = "Selected Targets"
    selectionTitle.TextColor3 = theme.accent
    selectionTitle.Font = Enum.Font.GothamBold
    selectionTitle.TextSize = 16
    selectionTitle.Parent = selectionFrame

    local selectionScroll = Instance.new("ScrollingFrame")
    selectionScroll.Size = UDim2.new(1, -10, 1, -50)
    selectionScroll.Position = UDim2.new(0, 5, 0, 45)
    selectionScroll.BackgroundTransparency = 1
    selectionScroll.BorderSizePixel = 0
    selectionScroll.ScrollBarThickness = 2
    selectionScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    selectionScroll.Parent = selectionFrame
    local selectionList = Instance.new("UIListLayout")
    selectionList.Padding = UDim.new(0, 8)
    selectionList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    selectionList.Parent = selectionScroll

    local function updateSelectionInterface(smooth)
        if not selectionFrame then return end
        
        -- Update Highlights
        for name, highlight in pairs(targetHighlights) do
            if not selectedTargets[name] then
                highlight:Destroy()
                targetHighlights[name] = nil
            end
        end

        for name, player in pairs(selectedTargets) do
            if not targetHighlights[name] and player and player.Character then
                local highlight = Instance.new("Highlight")
                highlight.Name = "SelectionHighlight_" .. name
                highlight.Adornee = player.Character
                highlight.FillColor = theme.accent
                highlight.OutlineColor = Color3.new(1, 1, 1)
                highlight.FillTransparency = 0.5
                highlight.OutlineTransparency = 0
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = player.Character
                targetHighlights[name] = highlight
                
                -- Update color if theme changes
                registerTheme(highlight, "accent", "FillColor")
            end
        end

        -- If parent (playersFrame) is hidden, we hide too
        if not playersFrame.Visible then
            selectionFrame.Visible = false
            selectionFrame.GroupTransparency = 1
            return
        end

        for _, child in ipairs(selectionScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        local count = 0
        for name, player in pairs(selectedTargets) do
            if player and player.Parent then
                count = count + 1
                local item = Instance.new("Frame")
                item.Size = UDim2.new(0.9, 0, 0, 50)
                item.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
                item.Parent = selectionScroll

                local img = Instance.new("ImageLabel")
                img.Size = UDim2.new(0, 40, 0, 40)
                img.Position = UDim2.new(0, 5, 0, 5)
                img.BackgroundTransparency = 1
                pcall(function()
                    img.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
                end)
                img.Parent = item

                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(1, -55, 1, 0)
                nameLabel.Position = UDim2.new(0, 50, 0, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = player.DisplayName
                nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
                nameLabel.Font = Enum.Font.GothamMedium
                nameLabel.TextSize = 12
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.Parent = item
            end
        end
        selectionScroll.CanvasSize = UDim2.new(0, 0, 0, count * 58)
        
        local shouldBeVisible = false
        if playersFrame and playersFrame.Visible and (count > 0) and (not mainFrame.Visible) then
            shouldBeVisible = true
        end
        
        if smooth == nil then smooth = true end -- Default to smooth

        if shouldBeVisible then
            if not selectionFrame.Visible then
                selectionFrame.Visible = true
                if smooth then
                    selectionFrame.GroupTransparency = 1
                    createTween(selectionFrame, {GroupTransparency = 0}, 0.3)
                else
                    selectionFrame.GroupTransparency = 0
                end
            end
        else
            if smooth then
                createTween(selectionFrame, {GroupTransparency = 1}, 0.3).Completed:Connect(function()
                    if not (playersFrame.Visible and (count > 0) and (not mainFrame.Visible)) then
                        selectionFrame.Visible = false
                    end
                end)
            else
                selectionFrame.Visible = false
                selectionFrame.GroupTransparency = 1
            end
        end
    end

    -- Players Frame Dragging
    local playersDragging, playersDragInput, playersDragStart, playersStartPos
    playersFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            playersDragging = true
            playersDragStart = input.Position
            playersStartPos = playersFrame.Position
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if playersDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - playersDragStart
            local newPos = UDim2.new(playersStartPos.X.Scale, playersStartPos.X.Offset + delta.X, playersStartPos.Y.Scale, playersStartPos.Y.Offset + delta.Y)
            playersFrame.Position = newPos
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then playersDragging = false end
    end)

    local playersTitle = Instance.new("TextLabel")
    playersTitle.Size = UDim2.new(1, 0, 0, 35)
    playersTitle.BackgroundTransparency = 1
    playersTitle.Text = "Multi-Target Fling"
    playersTitle.TextColor3 = theme.accent
    playersTitle.Font = Enum.Font.GothamBold
    playersTitle.TextSize = 18
    registerTheme(playersTitle, "accent", "TextColor3")
    playersTitle.Parent = playersFrame

    local searchFrame = Instance.new("Frame")
    searchFrame.Size = UDim2.new(1, -20, 0, 30)
    searchFrame.Position = UDim2.new(0, 10, 0, 35)
    searchFrame.BackgroundColor3 = theme.sidebar
    registerTheme(searchFrame, "sidebar", "BackgroundColor3")
    searchFrame.Parent = playersFrame

    local searchIcon = Instance.new("ImageLabel")
    searchIcon.Size = UDim2.new(0, 16, 0, 16)
    searchIcon.Position = UDim2.new(0, 8, 0.5, -8)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Image = "rbxassetid://6031154871"
    searchIcon.ImageColor3 = theme.textDim
    registerTheme(searchIcon, "textDim", "ImageColor3")
    searchIcon.Parent = searchFrame

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -35, 1, 0)
    searchBox.Position = UDim2.new(0, 30, 0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.Text = ""
    searchBox.PlaceholderText = "Search players..."
    searchBox.TextColor3 = theme.text
    searchBox.PlaceholderColor3 = theme.textDim
    registerTheme(searchBox, "text", "TextColor3")
    registerTheme(searchBox, "textDim", "PlaceholderColor3")
    searchBox.TextSize = 14
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.Parent = searchFrame

    local playerScroll = Instance.new("ScrollingFrame")
    playerScroll.Size = UDim2.new(1, -20, 0, 195) -- Adjusted height for search bar
    playerScroll.Position = UDim2.new(0, 10, 0, 70)
    playerScroll.BackgroundTransparency = 1
    playerScroll.BorderSizePixel = 0
    playerScroll.ScrollBarThickness = 2
    playerScroll.ClipsDescendants = true
    playerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    playerScroll.Parent = playersFrame

    local playerList = Instance.new("UIListLayout")
    playerList.Padding = UDim.new(0, 5)
    playerList.Parent = playerScroll

    local flingControls = Instance.new("Frame")
    flingControls.Size = UDim2.new(1, -20, 0, 120)
    flingControls.Position = UDim2.new(0, 10, 1, -130)
    flingControls.BackgroundTransparency = 1
    flingControls.Parent = playersFrame

    local function createPlayersToggle(name, pos, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.48, 0, 0, 30)
        btn.Position = pos
        btn.BackgroundColor3 = theme.sidebar
        registerTheme(btn, "sidebar", "BackgroundColor3")
        btn.Text = name
        btn.TextColor3 = theme.textDim
        registerTheme(btn, "textDim", "TextColor3")
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.Parent = flingControls

        local active = false
        btn.MouseButton1Click:Connect(function()
            active = not active
            btn.TextColor3 = active and theme.accent or theme.textDim
            callback(active)
        end)
        return btn
    end

    local invFlingBtn = createPlayersToggle("Invisible Fling", UDim2.new(0, 0, 0, 0), function(v) 
        invisibleFlingActive = v 
        if v then Fling2Begin() else Fling2End() end
    end)
    local walkFlingBtn = createPlayersToggle("Walk Fling", UDim2.new(0.52, 0, 0, 0), function(v) 
        if v then WalkFlingStart() else WalkFlingStop() end
    end)

    local antiFlingBtn = createPlayersToggle("Anti-Fling", UDim2.new(0, 0, 0, 40), function(v)
        if v then AntiFlingStart() else AntiFlingStop() end
    end)

    local startFling = Instance.new("TextButton")
    startFling.Size = UDim2.new(0.48, 0, 0, 30)
    startFling.Position = UDim2.new(0.52, 0, 0, 40)
    startFling.BackgroundColor3 = theme.sidebar
    registerTheme(startFling, "sidebar", "BackgroundColor3")
    startFling.Text = "Start Fling"
    startFling.TextColor3 = Color3.fromRGB(0, 255, 127) -- Keep start green? Or use accent? User says "fix the colors... as they dont match my colors". Usually start/stop are special.
    startFling.Font = Enum.Font.GothamBold
    startFling.TextSize = 14
    startFling.Parent = flingControls

    local stopFling = Instance.new("TextButton")
    stopFling.Size = UDim2.new(1, 0, 0, 30)
    stopFling.Position = UDim2.new(0, 0, 0, 80)
    stopFling.BackgroundColor3 = theme.sidebar
    registerTheme(stopFling, "sidebar", "BackgroundColor3")
    stopFling.Text = "Stop All Processes"
    stopFling.TextColor3 = Color3.fromRGB(255, 64, 64) -- Keep stop red?
    stopFling.Font = Enum.Font.GothamBold
    stopFling.TextSize = 14
    stopFling.Parent = flingControls

    local function updatePlayerList()
        local searchText = searchBox.Text:lower()
        for _, child in ipairs(playerScroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end

        local count = 0
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LP then continue end
            if searchText ~= "" and not (player.Name:lower():find(searchText) or player.DisplayName:lower():find(searchText)) then
                continue
            end
            count = count + 1
            
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 32)
            btn:SetAttribute("Selected", selectedTargets[player.Name] ~= nil)
            btn.BackgroundColor3 = selectedTargets[player.Name] and theme.accent or theme.sidebar
            btn.BackgroundTransparency = selectedTargets[player.Name] and theme.accentTrans or theme.sidebarTrans
            registerTheme(btn, "playerListBtn", "BackgroundColor3")
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.Parent = playerScroll

            local pfp = Instance.new("ImageLabel")
            pfp.Size = UDim2.new(0, 24, 0, 24)
            pfp.Position = UDim2.new(0, 4, 0.5, -12)
            pfp.BackgroundTransparency = 1
            pfp.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            pfp.Parent = btn

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -35, 1, 0)
            nameLabel.Position = UDim2.new(0, 32, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = player.DisplayName .. " (@" .. player.Name .. ")"
            nameLabel.TextColor3 = theme.text
            nameLabel.TextTransparency = theme.textTrans
            registerTheme(nameLabel, "text", "TextColor3")
            nameLabel.TextSize = 11
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = btn

            btn.MouseButton1Click:Connect(function()
                if selectedTargets[player.Name] then
                    selectedTargets[player.Name] = nil
                    btn:SetAttribute("Selected", false)
                    notify("Selection", "Deselected " .. player.DisplayName, 2)
                else
                    selectedTargets[player.Name] = player
                    btn:SetAttribute("Selected", true)
                    notify("Selection", "Selected " .. player.DisplayName, 2)
                end
                
                if btn:GetAttribute("Selected") then
                    btn.BackgroundColor3 = theme.accent
                    btn.BackgroundTransparency = theme.accentTrans
                else
                    btn.BackgroundColor3 = theme.sidebar
                    btn.BackgroundTransparency = theme.sidebarTrans
                end
                
                updateSelectionInterface(true)
            end)
        end
        playerScroll.CanvasSize = UDim2.new(0, 0, 0, count * 37)
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(updatePlayerList)
    startFling.MouseButton1Click:Connect(StartFling)
    stopFling.MouseButton1Click:Connect(function()
        StopFling()
        Fling2End()
        WalkFlingStop()
        AntiFlingStop()
    end)

    Players.PlayerAdded:Connect(updatePlayerList)
    Players.PlayerRemoving:Connect(function(player)
        selectedTargets[player.Name] = nil
        if targetHighlights[player.Name] then
            targetHighlights[player.Name]:Destroy()
            targetHighlights[player.Name] = nil
        end
        updatePlayerList()
        updateSelectionInterface(true)
    end)

    -- Character added listener to re-apply highlights if character respawns
    local function setupCharAdded(player)
        player.CharacterAdded:Connect(function()
            task.wait(0.5) -- Wait for char to load
            if selectedTargets[player.Name] then
                -- Force refresh highlight
                if targetHighlights[player.Name] then
                    targetHighlights[player.Name]:Destroy()
                    targetHighlights[player.Name] = nil
                end
                updateSelectionInterface(false)
            end
        end)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        setupCharAdded(player)
    end
    Players.PlayerAdded:Connect(setupCharAdded)
    updatePlayerList()
    updateSelectionInterface(false)

    -- Fling Logic (Enhanced from roblox.lua)
    -- All logic moved to core functions for maintainability
    
    stopFling.MouseButton1Click:Connect(function()
        StopFling()
        Fling2End()
        WalkFlingStop()
        AntiFlingStop()
        
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.HipHeight = 2 end
    end)

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(45, 45, 50)
    mainStroke.Thickness = 1
    mainStroke.Parent = mainFrame
    
    local glowStroke = Instance.new("UIStroke")
    glowStroke.Name = "GlowStroke"
    glowStroke.Color = theme.accent
    glowStroke.Thickness = 0
    glowStroke.Transparency = 0.5
    glowStroke.Parent = mainFrame

    -- Dragging
    local dragging, dragInput, dragStart, startPos
    local isSliderDragging = false -- Global flag to prevent menu drag when using sliders

    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not isSliderDragging then
                dragging = true
                dragStart = input.Position
                startPos = mainFrame.Position
            end
        end
    end)
    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging and not isSliderDragging then
            local delta = input.Position - dragStart
            createTween(mainFrame, {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)}, 0.05)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.BackgroundColor3 = theme.sidebar
    registerTheme(sidebar, "sidebar", "BackgroundColor3")
    sidebar.BorderSizePixel = 0
    sidebar.Size = UDim2.new(0, 160, 1, 0)
    sidebar.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = "skid"
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 22
    titleLabel.TextColor3 = theme.accent
    registerTheme(titleLabel, "accent", "TextColor3")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, 0, 0, 60)
    titleLabel.Parent = sidebar

    local tabContainer = Instance.new("Frame")
    tabContainer.BackgroundTransparency = 1
    tabContainer.Position = UDim2.new(0, 0, 0, 70)
    tabContainer.Size = UDim2.new(1, 0, 1, -70)
    tabContainer.Parent = sidebar

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabContainer

    -- Content Area
    local contentArea = Instance.new("Frame")
    contentArea.BackgroundTransparency = 1
    contentArea.Position = UDim2.new(0, 170, 0, 10)
    contentArea.Size = UDim2.new(1, -180, 1, -20)
    contentArea.Parent = mainFrame

    -- UI Helper Functions
    local tabs = {}
    local activeTab = nil

    local function switchTab(tabName)
        if activeTab == tabName then return end
        if activeTab and tabs[activeTab] then
            createTween(tabs[activeTab].btn, {BackgroundColor3 = theme.sidebar, TextColor3 = theme.textDim}, 0.2)
            tabs[activeTab].btn:SetAttribute("IsActiveTab", false)
            tabs[activeTab].page.Visible = false
        end
        activeTab = tabName
        if tabs[activeTab] then
            createTween(tabs[activeTab].btn, {BackgroundColor3 = theme.accent, TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.2)
            tabs[activeTab].btn:SetAttribute("IsActiveTab", true)
            tabs[activeTab].page.Visible = true
        end
    end

    local function createTabHeader(text)
        local label = Instance.new("TextLabel")
        label.Text = text
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextColor3 = Color3.fromRGB(80, 80, 85)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 0, 30)
        label.Parent = tabContainer

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 15)
        pad.Parent = label
    end

    local function createTab(name)
        local btn = Instance.new("TextButton")
        btn.Text = "    " .. name
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 14
        btn.TextColor3 = theme.textDim
        registerTheme(btn, "textDim", "TextColor3")
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.BackgroundColor3 = theme.sidebar
        registerTheme(btn, "sidebar", "BackgroundColor3")
        btn.BorderSizePixel = 0
        btn.Size = UDim2.new(0.9, 0, 0, 36)
        btn.Position = UDim2.new(0.05, 0, 0, 0)
        btn.AutoButtonColor = false
        btn.Parent = tabContainer

        local page = Instance.new("ScrollingFrame")
        page.BackgroundTransparency = 1
        page.Size = UDim2.new(1, 0, 1, 0)
        page.Visible = false
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 65)
        page.Parent = contentArea

        local pageLayout = Instance.new("UIListLayout")
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Padding = UDim.new(0, 10)
        pageLayout.Parent = page
        
        local pagePad = Instance.new("UIPadding")
        pagePad.PaddingRight = UDim.new(0, 6)
        pagePad.PaddingTop = UDim.new(0, 5)
        pagePad.PaddingBottom = UDim.new(0, 5)
        pagePad.Parent = page

        pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            page.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 10)
        end)

        btn.MouseButton1Click:Connect(function() switchTab(name) end)
        tabs[name] = {btn = btn, page = page}
        return page
    end

    local function createSection(parent, title)
        local frame = Instance.new("Frame")
        frame.BackgroundColor3 = theme.sidebar
        registerTheme(frame, "sidebar", "BackgroundColor3")
        frame.Size = UDim2.new(1, 0, 0, 0)
        frame.AutomaticSize = Enum.AutomaticSize.Y
        frame.Parent = parent

        local label = Instance.new("TextLabel")
        label.Text = title
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextColor3 = Color3.fromRGB(100, 100, 110)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, -20, 0, 30)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.Parent = frame

        local container = Instance.new("Frame")
        container.BackgroundTransparency = 1
        container.Position = UDim2.new(0, 10, 0, 30)
        container.Size = UDim2.new(1, -20, 0, 0)
        container.AutomaticSize = Enum.AutomaticSize.Y
        container.Parent = frame

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 8)
        layout.Parent = container
        
        local pad = Instance.new("UIPadding")
        pad.PaddingBottom = UDim.new(0, 10)
        pad.Parent = container

        return container
    end

    local function createToggle(parent, text, state, callback, hasColor)
        local btn = Instance.new("TextButton")
        btn.BackgroundTransparency = 1
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.Text = ""
        btn.Parent = parent

        local label = Instance.new("TextLabel")
        label.Text = text
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextColor3 = theme.text
        registerTheme(label, "text", "TextColor3")
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, hasColor and -100 or -50, 1, 0)
        label.Parent = btn

        local toggleBg = Instance.new("Frame")
        toggleBg.BackgroundColor3 = state and theme.accent or Color3.fromRGB(40, 40, 45)
        registerTheme(toggleBg, "toggleOn", "BackgroundColor3")
        toggleBg.Size = UDim2.new(0, 40, 0, 20)
        toggleBg.AnchorPoint = Vector2.new(1, 0.5)
        toggleBg.Position = UDim2.new(1, 0, 0.5, 0)
        toggleBg.Parent = btn

        local circle = Instance.new("Frame")
        circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        circle.Size = UDim2.new(0, 16, 0, 16)
        circle.AnchorPoint = Vector2.new(0, 0.5)
        circle.Position = state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        circle.Parent = toggleBg
        
        local toggled = state
        btn.MouseButton1Click:Connect(function()
            toggled = not toggled
            createTween(toggleBg, {BackgroundColor3 = toggled and theme.accent or Color3.fromRGB(40, 40, 45)}, 0.2)
            createTween(circle, {Position = toggled and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)}, 0.2)
            callback(toggled)
            notify(text, text .. " has been " .. (toggled and "enabled" or "disabled") .. ".", 3)
        end)
        return btn
    end

    local function createToggleWithKeybind(parent, text, state, initialBind, toggleCallback, bindCallback)
        local btn = Instance.new("TextButton")
        btn.BackgroundTransparency = 1
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.Text = ""
        btn.Parent = parent

        local label = Instance.new("TextLabel")
        label.Text = text
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextColor3 = theme.text
        registerTheme(label, "text", "TextColor3")
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, -120, 1, 0)
        label.Parent = btn

        local toggleBg = Instance.new("Frame")
        toggleBg.BackgroundColor3 = state and theme.accent or Color3.fromRGB(40, 40, 45)
        registerTheme(toggleBg, "toggleOn", "BackgroundColor3")
        toggleBg.Size = UDim2.new(0, 40, 0, 20)
        toggleBg.AnchorPoint = Vector2.new(1, 0.5)
        toggleBg.Position = UDim2.new(1, 0, 0.5, 0)
        toggleBg.Parent = btn

        local circle = Instance.new("Frame")
        circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        circle.Size = UDim2.new(0, 16, 0, 16)
        circle.AnchorPoint = Vector2.new(0, 0.5)
        circle.Position = state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        circle.Parent = toggleBg
        
        local bindBtn = Instance.new("TextButton")
        bindBtn.Text = initialBind.Name
        bindBtn.Font = Enum.Font.GothamMedium
        bindBtn.TextSize = 12
        bindBtn.TextColor3 = theme.text
        registerTheme(bindBtn, "text", "TextColor3")
        bindBtn.BackgroundColor3 = theme.sidebar
        registerTheme(bindBtn, "sidebar", "BackgroundColor3")
        bindBtn.Size = UDim2.new(0, 60, 0, 20)
        bindBtn.AnchorPoint = Vector2.new(1, 0.5)
        bindBtn.Position = UDim2.new(1, -45, 0.5, 0)
        bindBtn.Parent = btn

        local toggled = state
        btn.MouseButton1Click:Connect(function()
            toggled = not toggled
            createTween(toggleBg, {BackgroundColor3 = toggled and theme.accent or Color3.fromRGB(40, 40, 45)}, 0.2)
            createTween(circle, {Position = toggled and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)}, 0.2)
            toggleCallback(toggled)
            notify(text, text .. " has been " .. (toggled and "enabled" or "disabled") .. ".", 3)
            updateKeybindList()
        end)

        local binding = false
        bindBtn.MouseButton1Click:Connect(function()
            binding = true
            isBinding = true
            bindBtn.Text = "..."
        end)

        UIS.InputBegan:Connect(function(input)
            if binding then
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    binding = false
                    isBinding = false
                    local key = input.KeyCode
                    bindBtn.Text = key.Name
                    bindCallback(key)
                    updateKeybindList()
                elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                    binding = false
                    isBinding = false
                    bindBtn.Text = initialBind.Name
                end
            end
        end)

        return btn
    end

    local function createSlider(parent, text, value, min, max, step, callback)
        local frame = Instance.new("Frame")
        frame.BackgroundTransparency = 1
        frame.Size = UDim2.new(1, 0, 0, 50)
        frame.Parent = parent

        local label = Instance.new("TextLabel")
        label.Text = text
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextColor3 = theme.text
        registerTheme(label, "text", "TextColor3")
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Parent = frame

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Text = tostring(value)
        valueLabel.Font = Enum.Font.Gotham
        valueLabel.TextSize = 14
        valueLabel.TextColor3 = theme.textDim
        registerTheme(valueLabel, "textDim", "TextColor3")
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.BackgroundTransparency = 1
        valueLabel.Size = UDim2.new(1, 0, 0, 20)
        valueLabel.Parent = frame

        local sliderBg = Instance.new("TextButton")
        sliderBg.Text = ""
        sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        sliderBg.Size = UDim2.new(1, 0, 0, 6)
        sliderBg.Position = UDim2.new(0, 0, 0, 35)
        sliderBg.AutoButtonColor = false
        sliderBg.BorderSizePixel = 0
        sliderBg.Parent = frame

        -- Clickable hitbox (MASSIVE hitbox for easier dragging)
        local hitbox = Instance.new("TextButton")
        hitbox.Name = "Hitbox"
        hitbox.Text = ""
        hitbox.BackgroundTransparency = 1
        hitbox.Size = UDim2.new(1, 30, 0, 45) -- Very large vertical and horizontal hitbox
        hitbox.Position = UDim2.new(0, -15, 0.5, -22)
        hitbox.ZIndex = 10
        hitbox.Parent = sliderBg

        local fill = Instance.new("Frame")
        fill.BackgroundColor3 = theme.accent
        registerTheme(fill, "accent", "BackgroundColor3")
        fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        fill.BorderSizePixel = 0
        fill.Parent = sliderBg

        local knob = Instance.new("Frame")
        knob.Name = "Knob"
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0)
        knob.ZIndex = 5
        knob.Parent = sliderBg

        local knobStroke = Instance.new("UIStroke")
        knobStroke.Thickness = 1.5
        knobStroke.Color = Color3.fromRGB(0, 0, 0)
        knobStroke.Transparency = 0.5
        knobStroke.Parent = knob

        local dragging = false
        
        local function updateSlider(input)
            local alpha = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local newValue = (min + (max - min) * alpha)
            newValue = math.floor(newValue / step + 0.5) * step
            
            if step >= 1 then
                valueLabel.Text = string.format("%d", newValue)
            else
                local decimals = 0
                local s = tostring(step)
                if s:find("%.") then
                    decimals = #s:split(".")[2]
                end
                valueLabel.Text = string.format("%." .. decimals .. "f", newValue)
            end
            
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            knob.Position = UDim2.new(alpha, 0, 0.5, 0)
            callback(newValue)
        end

        hitbox.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then 
                dragging = true 
                isSliderDragging = true
                updateSlider(input)
            end
        end)

        UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then 
                dragging = false 
                isSliderDragging = false
            end
        end)

        UIS.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateSlider(input)
            end
        end)
    end

    local function updateKeybindList()
        if not keybindListFrame then return end
        
        local container = keybindListFrame:FindFirstChild("Container")
        if not container then return end

        local keybindsToShow = {
            {name = "Menu", key = settings.menuKeybind, enabled = true},
            {name = "Flight", key = settings.exploits.flightKeybind, enabled = settings.exploits.flightActive},
            {name = "WalkSpeed", key = settings.exploits.walkSpeedKeybind, enabled = settings.exploits.walkSpeedActive},
            {name = "Noclip", key = settings.exploits.noclipKeybind, enabled = settings.exploits.noclipActive}
        }

        -- Filter and update/create rows
        local visibleCount = 0
        local maxWidth = 170 -- Increased default min width further

        -- Collect currently visible and enabled binds
        local activeBinds = {}
        for _, bind in ipairs(keybindsToShow) do
            local isExploitEnabled = false
            if bind.name == "Menu" then
                isExploitEnabled = true
            elseif bind.name == "Flight" then
                isExploitEnabled = settings.exploits.flightEnabled
            elseif bind.name == "WalkSpeed" then
                isExploitEnabled = settings.exploits.walkSpeedEnabled
            elseif bind.name == "Noclip" then
                isExploitEnabled = settings.exploits.noclipEnabled
            end

            if isExploitEnabled then
                table.insert(activeBinds, bind)
            end
        end

        -- Update rows
        for i, bind in ipairs(activeBinds) do
            visibleCount = visibleCount + 1
            local row = container:FindFirstChild("Row_" .. bind.name)
            if not row then
                row = Instance.new("Frame")
                row.Name = "Row_" .. bind.name
                row.BackgroundTransparency = 1
                row.Size = UDim2.new(1, 0, 0, 30) -- Increased row height further
                row.Parent = container

                local nameLabel = Instance.new("TextLabel")
                nameLabel.Name = "NameLabel"
                nameLabel.Font = Enum.Font.Gotham
                nameLabel.TextSize = 15 -- Increased text size further
                nameLabel.TextColor3 = theme.accent
                nameLabel.TextTransparency = 0
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.BackgroundTransparency = 1
                nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
                nameLabel.Parent = row
                nameLabel.ZIndex = 1005
                registerTheme(nameLabel, "accent", "TextColor3")

                local nameStroke = Instance.new("UIStroke")
                nameStroke.Thickness = 0.5
                nameStroke.Color = Color3.fromRGB(0, 0, 0)
                nameStroke.Transparency = 0.5
                nameStroke.Parent = nameLabel

                local keyLabel = Instance.new("TextLabel")
                keyLabel.Name = "KeyLabel"
                keyLabel.Font = Enum.Font.GothamMedium
                keyLabel.TextSize = 15 -- Increased text size further
                keyLabel.TextColor3 = theme.accent
                keyLabel.TextTransparency = 0
                keyLabel.TextXAlignment = Enum.TextXAlignment.Right
                keyLabel.BackgroundTransparency = 1
                keyLabel.Size = UDim2.new(0.4, 0, 1, 0)
                keyLabel.Position = UDim2.new(0.6, 0, 0, 0)
                keyLabel.Parent = row
                keyLabel.ZIndex = 1005
                registerTheme(keyLabel, "accent", "TextColor3")

                local keyStroke = Instance.new("UIStroke")
                keyStroke.Thickness = 0.5
                keyStroke.Color = Color3.fromRGB(0, 0, 0)
                keyStroke.Transparency = 0.5
                keyStroke.Parent = keyLabel
            end

            row.LayoutOrder = i
            row.Visible = true
            row.NameLabel.Text = bind.name
            
            -- ULTRA BRIGHT colors for visibility
            if bind.enabled then
                row.NameLabel.TextColor3 = theme.accent
                row.NameLabel.TextTransparency = 0
                row.KeyLabel.TextColor3 = theme.accent
                row.KeyLabel.TextTransparency = 0
            else
                row.NameLabel.TextColor3 = theme.accent
                row.NameLabel.TextTransparency = 0.5
                row.KeyLabel.TextColor3 = theme.accent
                row.KeyLabel.TextTransparency = 0.5
            end

            local keyName = (typeof(bind.key) == "EnumItem" and bind.key.Name) or tostring(bind.key) or "None"
            row.KeyLabel.Text = "[" .. keyName .. "]"

            local combinedText = bind.name .. " [" .. keyName .. "]"
            local textBound = game:GetService("TextService"):GetTextSize(combinedText, 15, Enum.Font.Gotham, Vector2.new(1000, 1000))
            if textBound.X + 45 > maxWidth then
                maxWidth = textBound.X + 45
            end
        end

        -- Hide unused rows
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Frame") and child.Name:find("Row_") then
                local found = false
                for _, bind in ipairs(activeBinds) do
                    if child.Name == "Row_" .. bind.name then
                        found = true
                        break
                    end
                end
                if not found then
                    child.Visible = false
                end
            end
        end

        local targetHeight = 50 + (visibleCount * 30 + (visibleCount > 0 and (visibleCount-1)*8 or 0))
        createTween(keybindListFrame, {Size = UDim2.new(0, maxWidth, 0, targetHeight)}, 0.2)
    end

    local function createKeybindList()
        if keybindListFrame then return end

        keybindListFrame = Instance.new("Frame")
        keybindListFrame.Name = "KeybindListHUD"
        keybindListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25) -- Deep dark
        keybindListFrame.BackgroundTransparency = 0.15
        keybindListFrame.Size = UDim2.new(0, 200, 0, 140)
        keybindListFrame.Position = UDim2.new(0.98, -210, 0.4, 0)
        keybindListFrame.Visible = keybindListEnabled
        keybindListFrame.Parent = controlGui
        keybindListFrame.ZIndex = 1000

        local stroke = Instance.new("UIStroke")
        stroke.Color = theme.accent
        stroke.Transparency = 0.2
        stroke.Thickness = 1.5
        stroke.Parent = keybindListFrame
        registerTheme(stroke, "accent", "Color")

        local header = Instance.new("Frame")
        header.Name = "Header"
        header.Size = UDim2.new(1, 0, 0, 40)
        header.BackgroundTransparency = 1
        header.Parent = keybindListFrame
        header.ZIndex = 1001

        local title = Instance.new("TextLabel")
        title.Text = "KEYBINDS"
        title.Font = Enum.Font.GothamBold
        title.TextSize = 16
        title.TextColor3 = theme.accent
        title.TextTransparency = 0
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(1, 0, 1, 0)
        title.Parent = header
        title.ZIndex = 1002
        registerTheme(title, "accent", "TextColor3")

        local titleStroke = Instance.new("UIStroke")
        titleStroke.Thickness = 0.5
        titleStroke.Color = Color3.fromRGB(0, 0, 0)
        titleStroke.Transparency = 0.5
        titleStroke.Parent = title

        local accentBar = Instance.new("Frame")
        accentBar.BackgroundColor3 = theme.accent
        accentBar.Size = UDim2.new(0.94, 0, 0, 2.5)
        accentBar.Position = UDim2.new(0.03, 0, 1, -2)
        accentBar.BorderSizePixel = 0
        accentBar.Parent = header
        accentBar.ZIndex = 1002
        registerTheme(accentBar, "accent", "BackgroundColor3")

        local container = Instance.new("Frame")
        container.Name = "Container"
        container.BackgroundTransparency = 1
        container.Position = UDim2.new(0, 18, 0, 50)
        container.Size = UDim2.new(1, -36, 1, -65)
        container.Parent = keybindListFrame
        container.ZIndex = 1001

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 8)
        layout.Parent = container

        -- Dragging logic
        local dragging, dragStart, startPos
        header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = keybindListFrame.Position
                
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)

        UIS.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                keybindListFrame.Position = UDim2.new(
                    startPos.X.Scale, 
                    startPos.X.Offset + delta.X, 
                    startPos.Y.Scale, 
                    startPos.Y.Offset + delta.Y
                )
            end
        end)

        updateKeybindList()
        return keybindListFrame
    end

    local function createButton(parent, text, callback)
        local btn = Instance.new("TextButton")
        btn.Text = text
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 14
        btn.TextColor3 = theme.text
        registerTheme(btn, "text", "TextColor3")
        btn.BackgroundColor3 = theme.sidebar
        registerTheme(btn, "sidebar", "BackgroundColor3")
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.Parent = parent

        btn.MouseButton1Click:Connect(function()
            createTween(btn, {BackgroundColor3 = Color3.fromRGB(50, 50, 55)}, 0.1)
            wait(0.1)
            createTween(btn, {BackgroundColor3 = theme.sidebar}, 0.1)
            callback()
        end)
        return btn
    end

    local function createColorPicker(parent, text, initial, callback, initialTrans, isSideBySide)
        local h, s, v = initial:ToHSV()
        local t = initialTrans or 0
        
        local frame = Instance.new("Frame")
        frame.BackgroundTransparency = 1
        frame.Size = UDim2.new(1, 0, 0, 30)
        frame.Parent = parent

        if isSideBySide then
            frame.Size = UDim2.new(0, 40, 0, 30)
            frame.AnchorPoint = Vector2.new(1, 0.5)
            frame.Position = UDim2.new(1, -50, 0.5, 0) -- Align next to toggle switch
        end

        local label = Instance.new("TextLabel")
        label.Text = text
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextColor3 = theme.text
        registerTheme(label, "text", "TextColor3")
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(0.6, 0, 0, 30)
        label.Visible = not isSideBySide
        label.Parent = frame

        local previewBtn = Instance.new("TextButton")
        previewBtn.Text = ""
        previewBtn.BackgroundColor3 = initial
        previewBtn.BackgroundTransparency = t
        previewBtn.Size = UDim2.new(0, 40, 0, 20)
        previewBtn.AnchorPoint = Vector2.new(1, 0.5)
        previewBtn.Position = isSideBySide and UDim2.new(1, 0, 0, 15) or UDim2.new(1, -10, 0, 15)
        previewBtn.Parent = frame
        
        -- Detached Draggable Window (Ultra-Compact 2D Picker)
        local pickerWindow = Instance.new("Frame")
        pickerWindow.Name = "ColorPickerWindow_" .. text
        pickerWindow.Size = UDim2.new(0, 240, 0, 340)
        pickerWindow.Position = UDim2.new(0.5, -120, 0.5, -170)
        pickerWindow.BackgroundColor3 = theme.background
        registerTheme(pickerWindow, "background", "BackgroundColor3")
        pickerWindow.Visible = false
        pickerWindow.ZIndex = 100
        pickerWindow.Parent = controlGui

        local winStroke = Instance.new("UIStroke")
        winStroke.Color = Color3.fromRGB(60, 60, 65)
        winStroke.Thickness = 1
        winStroke.Parent = pickerWindow
        
        -- Title Bar
        local titleBar = Instance.new("TextButton")
        titleBar.Text = "    " .. text
        titleBar.Font = Enum.Font.GothamBold
        titleBar.TextSize = 13
        titleBar.TextColor3 = theme.text
        registerTheme(titleBar, "text", "TextColor3")
        titleBar.TextXAlignment = Enum.TextXAlignment.Left
        titleBar.BackgroundColor3 = theme.sidebar
        registerTheme(titleBar, "sidebar", "BackgroundColor3")
        titleBar.Size = UDim2.new(1, 0, 0, 35)
        titleBar.AutoButtonColor = false
        titleBar.ZIndex = 101
        titleBar.Parent = pickerWindow
        
        local titleCover = Instance.new("Frame")
        titleCover.BackgroundColor3 = theme.sidebar
        registerTheme(titleCover, "sidebar", "BackgroundColor3")
        titleCover.BorderSizePixel = 0
        titleCover.Size = UDim2.new(1, 0, 0, 8)
        titleCover.Position = UDim2.new(0, 0, 1, -8)
        titleCover.ZIndex = 101
        titleCover.Parent = titleBar

        -- Close Button
        local closeBtn = Instance.new("TextButton")
        closeBtn.Text = "X"
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 14
        closeBtn.TextColor3 = theme.textDim
        registerTheme(closeBtn, "textDim", "TextColor3")
        closeBtn.BackgroundTransparency = 1
        closeBtn.Size = UDim2.new(0, 35, 0, 35)
        closeBtn.Position = UDim2.new(1, -35, 0, 0)
        closeBtn.ZIndex = 102
        closeBtn.Parent = titleBar
        
        closeBtn.MouseButton1Click:Connect(function()
            pickerWindow.Visible = false
        end)

        -- Dragging Logic
        local dragging, dragInput, dragStart, startPos
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = pickerWindow.Position
            end
        end)
        titleBar.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                dragInput = input
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                pickerWindow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)

        local content = Instance.new("Frame")
        content.BackgroundTransparency = 1
        content.Position = UDim2.new(0, 12, 0, 45)
        content.Size = UDim2.new(1, -24, 1, -55)
        content.ZIndex = 101
        content.Parent = pickerWindow

        -- SV Square (Saturation & Value)
        local svSquare = Instance.new("Frame")
        svSquare.Size = UDim2.new(0, 180, 0, 180)
        svSquare.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svSquare.ZIndex = 102
        svSquare.Parent = content

        -- White Saturation Gradient
        local satGradFrame = Instance.new("Frame")
        satGradFrame.Size = UDim2.new(1, 0, 1, 0)
        satGradFrame.BackgroundTransparency = 0
        satGradFrame.ZIndex = 103
        satGradFrame.Parent = svSquare
        local satGrad = Instance.new("UIGradient")
        satGrad.Color = ColorSequence.new(Color3.new(1,1,1))
        satGrad.Transparency = NumberSequence.new(0, 1)
        satGrad.Parent = satGradFrame

        -- Black Value Gradient
        local valGradFrame = Instance.new("Frame")
        valGradFrame.Size = UDim2.new(1, 0, 1, 0)
        valGradFrame.BackgroundTransparency = 0
        valGradFrame.ZIndex = 104
        valGradFrame.Parent = svSquare
        local valGrad = Instance.new("UIGradient")
        valGrad.Color = ColorSequence.new(Color3.new(0,0,0))
        valGrad.Rotation = 90
        valGrad.Transparency = NumberSequence.new(1, 0)
        valGrad.Parent = valGradFrame

        -- SV Cursor
        local svCursor = Instance.new("Frame")
        svCursor.Size = UDim2.new(0, 10, 0, 10)
        svCursor.AnchorPoint = Vector2.new(0.5, 0.5)
        svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
        svCursor.BackgroundColor3 = Color3.new(1,1,1)
        svCursor.ZIndex = 105
        svCursor.Parent = svSquare
        local cursorStroke = Instance.new("UIStroke")
        cursorStroke.Thickness = 1.5
        cursorStroke.Color = Color3.new(0,0,0)
        cursorStroke.Parent = svCursor

        -- Hue Slider (Vertical)
        local hueSlider = Instance.new("Frame")
        hueSlider.Size = UDim2.new(0, 20, 0, 180)
        hueSlider.Position = UDim2.new(0, 195, 0, 0)
        hueSlider.ZIndex = 102
        hueSlider.Parent = content
        
        local hueGrad = Instance.new("UIGradient")
        hueGrad.Rotation = 90
        hueGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0,1,1)),
            ColorSequenceKeypoint.new(0.16, Color3.fromHSV(0.16,1,1)),
            ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33,1,1)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5,1,1)),
            ColorSequenceKeypoint.new(0.66, Color3.fromHSV(0.66,1,1)),
            ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83,1,1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(1,1,1))
        })
        hueGrad.Parent = hueSlider

        local hueKnob = Instance.new("Frame")
        hueKnob.Size = UDim2.new(1, 4, 0, 6)
        hueKnob.Position = UDim2.new(0, -2, h, 0)
        hueKnob.BackgroundColor3 = Color3.new(1,1,1)
        hueKnob.ZIndex = 103
        hueKnob.Parent = hueSlider
        local hKnobStroke = Instance.new("UIStroke")
        hKnobStroke.Thickness = 1.5
        hKnobStroke.Color = Color3.new(0,0,0)
        hKnobStroke.Parent = hueKnob

        -- Transparency Slider (Horizontal)
        local transSlider = Instance.new("Frame")
        transSlider.Size = UDim2.new(1, 0, 0, 20)
        transSlider.Position = UDim2.new(0, 0, 0, 195)
        transSlider.ZIndex = 102
        transSlider.Parent = content
        
        local transGrad = Instance.new("UIGradient")
        transGrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1)
        })
        transGrad.Parent = transSlider
        
        local transKnob = Instance.new("Frame")
        transKnob.Size = UDim2.new(0, 6, 1, 4)
        transKnob.Position = UDim2.new(t, -3, 0, -2)
        transKnob.BackgroundColor3 = Color3.new(1,1,1)
        transKnob.ZIndex = 103
        transKnob.Parent = transSlider
        local tKnobStroke = Instance.new("UIStroke")
        tKnobStroke.Thickness = 1.5
        tKnobStroke.Color = Color3.new(0,0,0)
        tKnobStroke.Parent = transKnob

        -- Display Area
        local display = Instance.new("Frame")
        display.Size = UDim2.new(1, 0, 0, 40)
        display.Position = UDim2.new(0, 0, 0, 230)
        display.BackgroundTransparency = 1
        display.ZIndex = 102
        display.Parent = content

        local colorPreview = Instance.new("Frame")
        colorPreview.Size = UDim2.new(0, 40, 0, 40)
        colorPreview.BackgroundColor3 = initial
        colorPreview.BackgroundTransparency = t
        colorPreview.ZIndex = 103
        colorPreview.Parent = display
        local cpStroke = Instance.new("UIStroke")
        cpStroke.Color = Color3.fromRGB(60, 60, 65)
        cpStroke.Thickness = 2
        cpStroke.Parent = colorPreview

        local valLabel = Instance.new("TextLabel")
        valLabel.Size = UDim2.new(1, -50, 1, 0)
        valLabel.Position = UDim2.new(0, 50, 0, 0)
        valLabel.BackgroundTransparency = 1
        valLabel.Text = "RGB: " .. math.floor(initial.R*255) .. ", " .. math.floor(initial.G*255) .. ", " .. math.floor(initial.B*255)
        valLabel.Font = Enum.Font.GothamMedium
        valLabel.TextSize = 12
        valLabel.TextColor3 = theme.text
        registerTheme(valLabel, "text", "TextColor3")
        valLabel.TextXAlignment = Enum.TextXAlignment.Left
        valLabel.ZIndex = 103
        valLabel.Parent = display

        local function updateColor()
            local newCol = Color3.fromHSV(h, s, v)
            previewBtn.BackgroundColor3 = newCol
            previewBtn.BackgroundTransparency = t
            colorPreview.BackgroundColor3 = newCol
            colorPreview.BackgroundTransparency = t
            svSquare.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            
            -- Update transparency gradient colors
            transGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, newCol),
                ColorSequenceKeypoint.new(1, newCol)
            })
            
            valLabel.Text = string.format("RGB: %d, %d, %d A: %d%%", 
                math.floor(newCol.R*255), 
                math.floor(newCol.G*255), 
                math.floor(newCol.B*255),
                math.floor((1-t)*100))
            
            callback(newCol, t)
        end

        -- SV Input
        local svDragging = false
        local function updateSV(input)
            local relativeX = math.clamp((input.Position.X - svSquare.AbsolutePosition.X) / svSquare.AbsoluteSize.X, 0, 1)
            local relativeY = math.clamp((input.Position.Y - svSquare.AbsolutePosition.Y) / svSquare.AbsoluteSize.Y, 0, 1)
            s = relativeX
            v = 1 - relativeY
            svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
            updateColor()
        end

        svSquare.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                svDragging = true
                isSliderDragging = true
                updateSV(input)
            end
        end)
        
        -- Hue Input
        local hueDragging = false
        local function updateHue(input)
            local relativeY = math.clamp((input.Position.Y - hueSlider.AbsolutePosition.Y) / hueSlider.AbsoluteSize.Y, 0, 1)
            h = relativeY
            hueKnob.Position = UDim2.new(0, -2, h, 0)
            updateColor()
        end

        hueSlider.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                hueDragging = true
                isSliderDragging = true
                updateHue(input)
            end
        end)

        -- Transparency Input
        local transDragging = false
        local function updateTrans(input)
            local relativeX = math.clamp((input.Position.X - transSlider.AbsolutePosition.X) / transSlider.AbsoluteSize.X, 0, 1)
            t = relativeX
            transKnob.Position = UDim2.new(t, -3, 0, -2)
            updateColor()
        end

        transSlider.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                transDragging = true
                isSliderDragging = true
                updateTrans(input)
            end
        end)

        UIS.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                if svDragging then updateSV(input) end
                if hueDragging then updateHue(input) end
                if transDragging then updateTrans(input) end
            end
        end)

        UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then 
                svDragging = false 
                hueDragging = false
                transDragging = false
                isSliderDragging = false
            end
        end)

        previewBtn.MouseButton1Click:Connect(function()
            pickerWindow.Visible = not pickerWindow.Visible
            if pickerWindow.Visible then
                pickerWindow.ZIndex = 100
            end
        end)

        updateColor()
        return previewBtn
    end

    local function createKeybind(parent, text, initial, callback)
        local currentKey = initial
        local frame = Instance.new("Frame")
        frame.BackgroundTransparency = 1
        frame.Size = UDim2.new(1, 0, 0, 30)
        frame.Parent = parent

        local label = Instance.new("TextLabel")
        label.Text = text
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextColor3 = theme.text
        registerTheme(label, "text", "TextColor3")
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, -60, 1, 0)
        label.Parent = frame

        local bindBtn = Instance.new("TextButton")
        bindBtn.Text = currentKey.Name
        bindBtn.Font = Enum.Font.GothamMedium
        bindBtn.TextSize = 12
        bindBtn.TextColor3 = theme.text
        registerTheme(bindBtn, "text", "TextColor3")
        bindBtn.BackgroundColor3 = theme.sidebar
        registerTheme(bindBtn, "sidebar", "BackgroundColor3")
        bindBtn.Size = UDim2.new(0, 60, 0, 24)
        bindBtn.AnchorPoint = Vector2.new(1, 0.5)
        bindBtn.Position = UDim2.new(1, 0, 0.5, 0)
        bindBtn.Parent = frame

        bindBtn.MouseButton1Click:Connect(function()
            binding = true
            isBinding = true
            bindBtn.Text = "..."
        end)

        UIS.InputBegan:Connect(function(input)
            if binding then
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    binding = false
                    isBinding = false
                    currentKey = input.KeyCode
                    bindBtn.Text = currentKey.Name
                    callback(currentKey)
                    updateKeybindList()
                elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
                    binding = false
                    isBinding = false
                    bindBtn.Text = currentKey.Name
                end
            end
        end)
        return bindBtn
    end

    local function createDropdown(parent, text, options, initial, callback)
        local frame = Instance.new("Frame")
        frame.BackgroundTransparency = 1
        frame.Size = UDim2.new(1, 0, 0, 55)
        frame.ZIndex = 5
        frame.Parent = parent

        local label = Instance.new("TextLabel")
        label.Text = text
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextColor3 = theme.text
        registerTheme(label, "text", "TextColor3")
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Parent = frame

        local dropBtn = Instance.new("TextButton")
        dropBtn.Text = initial
        dropBtn.Font = Enum.Font.GothamMedium
        dropBtn.TextSize = 13
        dropBtn.TextColor3 = theme.text
        registerTheme(dropBtn, "text", "TextColor3")
        dropBtn.TextXAlignment = Enum.TextXAlignment.Left
        dropBtn.BackgroundColor3 = theme.sidebar
        registerTheme(dropBtn, "sidebar", "BackgroundColor3")
        dropBtn.Size = UDim2.new(1, 0, 0, 30)
        dropBtn.Position = UDim2.new(0, 0, 0, 25)
        dropBtn.AutoButtonColor = false
        dropBtn.Parent = frame

        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = Color3.fromRGB(60, 60, 65)
        btnStroke.Thickness = 1
        btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        btnStroke.Parent = dropBtn

        local btnPad = Instance.new("UIPadding")
        btnPad.PaddingLeft = UDim.new(0, 10)
        btnPad.Parent = dropBtn

        local arrow = Instance.new("TextLabel")
        arrow.Text = "+"
        arrow.Font = Enum.Font.GothamBold
        arrow.TextSize = 16
        arrow.TextColor3 = theme.textDim
        registerTheme(arrow, "textDim", "TextColor3")
        arrow.BackgroundTransparency = 1
        arrow.Size = UDim2.new(0, 30, 1, 0)
        arrow.Position = UDim2.new(1, -30, 0, 0)
        arrow.Parent = dropBtn

        local listContainer = Instance.new("Frame")
        listContainer.BackgroundColor3 = theme.sidebar
        registerTheme(listContainer, "sidebar", "BackgroundColor3")
        listContainer.BorderSizePixel = 0
        listContainer.Position = UDim2.new(0, 0, 0, 60)
        listContainer.Size = UDim2.new(1, 0, 0, 0)
        listContainer.ClipsDescendants = true
        listContainer.Visible = false
        listContainer.ZIndex = 10
        listContainer.Parent = frame

        local listStroke = Instance.new("UIStroke")
        listStroke.Color = Color3.fromRGB(60, 60, 65)
        listStroke.Thickness = 1
        listStroke.Parent = listContainer

        local listLayout = Instance.new("UIListLayout")
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Padding = UDim.new(0, 2)
        listLayout.Parent = listContainer

        local listPad = Instance.new("UIPadding")
        listPad.PaddingTop = UDim.new(0, 5)
        listPad.PaddingBottom = UDim.new(0, 5)
        listPad.PaddingLeft = UDim.new(0, 5)
        listPad.PaddingRight = UDim.new(0, 5)
        listPad.Parent = listContainer

        local expanded = false
        local itemHeight = 25
        local selected = initial

        local function updateList()
            local listSize = math.min(#options * (itemHeight + 2) + 10, 150)
            createTween(listContainer, {Size = UDim2.new(1, 0, 0, expanded and listSize or 0)}, 0.2)
            createTween(frame, {Size = UDim2.new(1, 0, 0, expanded and (55 + listSize + 5) or 55)}, 0.2)
        end

        for i, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Text = "  " .. opt
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 13
            optBtn.TextColor3 = (opt == selected) and theme.accent or theme.textDim
            optBtn.TextXAlignment = Enum.TextXAlignment.Left
            optBtn.BackgroundTransparency = 1
            optBtn.Size = UDim2.new(1, 0, 0, itemHeight)
            optBtn.ZIndex = 11
            optBtn.Parent = listContainer

            optBtn.MouseButton1Click:Connect(function()
                selected = opt
                dropBtn.Text = opt
                expanded = false
                arrow.Text = "+"
                updateList()
                task.delay(0.2, function() if not expanded then listContainer.Visible = false end end)
                
                -- Update all option colors
                for _, otherBtn in ipairs(listContainer:GetChildren()) do
                    if otherBtn:IsA("TextButton") then
                        otherBtn.TextColor3 = (otherBtn.Text:sub(3) == selected) and theme.accent or theme.textDim
                    end
                end
                
                callback(opt)
            end)
        end

        dropBtn.MouseButton1Click:Connect(function()
            expanded = not expanded
            arrow.Text = expanded and "-" or "+"
            listContainer.Visible = true
            updateList()
            if not expanded then
                task.delay(0.2, function() if not expanded then listContainer.Visible = false end end)
            end
        end)
        return frame
    end

    local function createMultiDropdown(parent, text, items, callback, initial)
        local frame = Instance.new("Frame")
        frame.BackgroundTransparency = 1
        frame.Size = UDim2.new(1, 0, 0, 55)
        frame.ZIndex = 5
        frame.Parent = parent

        local label = Instance.new("TextLabel")
        label.Text = text
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextColor3 = theme.text
        registerTheme(label, "text", "TextColor3")
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Position = UDim2.new(0, 0, 0, 0)
        label.Parent = frame

        local dropdownBtn = Instance.new("TextButton")
        dropdownBtn.Text = "Select..."
        dropdownBtn.Font = Enum.Font.GothamMedium
        dropdownBtn.TextSize = 13
        dropdownBtn.TextColor3 = theme.textDim
        registerTheme(dropdownBtn, "textDim", "TextColor3")
        dropdownBtn.TextXAlignment = Enum.TextXAlignment.Left
        dropdownBtn.BackgroundColor3 = theme.sidebar
        registerTheme(dropdownBtn, "sidebar", "BackgroundColor3")
        dropdownBtn.Size = UDim2.new(1, 0, 0, 30)
        dropdownBtn.Position = UDim2.new(0, 0, 0, 25)
        dropdownBtn.AutoButtonColor = false
        dropdownBtn.Parent = frame
        
        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = Color3.fromRGB(60, 60, 65)
        btnStroke.Thickness = 1
        btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        btnStroke.Parent = dropdownBtn

        local btnPad = Instance.new("UIPadding")
        btnPad.PaddingLeft = UDim.new(0, 10)
        btnPad.Parent = dropdownBtn

        local arrow = Instance.new("TextLabel")
        arrow.Text = "+"
        arrow.Font = Enum.Font.GothamBold
        arrow.TextSize = 16
        arrow.TextColor3 = theme.textDim
        registerTheme(arrow, "textDim", "TextColor3")
        arrow.BackgroundTransparency = 1
        arrow.Size = UDim2.new(0, 30, 1, 0)
        arrow.Position = UDim2.new(1, -30, 0, 0)
        arrow.Parent = dropdownBtn

        local listContainer = Instance.new("Frame")
        listContainer.BackgroundColor3 = theme.sidebar
        registerTheme(listContainer, "sidebar", "BackgroundColor3")
        listContainer.BorderSizePixel = 0
        listContainer.Position = UDim2.new(0, 0, 0, 60)
        listContainer.Size = UDim2.new(1, 0, 0, 0)
        listContainer.ClipsDescendants = true
        listContainer.Visible = false
        listContainer.ZIndex = 10
        listContainer.Parent = frame
        
        local listStroke = Instance.new("UIStroke")
        listStroke.Color = Color3.fromRGB(60, 60, 65)
        listStroke.Thickness = 1
        listStroke.Parent = listContainer

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 2)
        layout.Parent = listContainer
        
        local listPad = Instance.new("UIPadding")
        listPad.PaddingTop = UDim.new(0, 5)
        listPad.PaddingBottom = UDim.new(0, 5)
        listPad.PaddingLeft = UDim.new(0, 5)
        listPad.PaddingRight = UDim.new(0, 5)
        listPad.Parent = listContainer

        local expanded = false
        local itemHeight = 25
        local selectedItems = initial or {}

        local function updateLabel()
            local active = {}
            for n, s in pairs(selectedItems) do
                if s then table.insert(active, n) end
            end
            if #active == 0 then
                dropdownBtn.Text = "Select..."
                dropdownBtn.TextColor3 = theme.textDim
            elseif #active == 1 then
                dropdownBtn.Text = active[1]
                dropdownBtn.TextColor3 = theme.text
            else
                dropdownBtn.Text = #active .. " Selected"
                dropdownBtn.TextColor3 = theme.text
            end
        end

        for _, name in ipairs(items) do
            local initialValue = selectedItems[name] or false
            selectedItems[name] = initialValue
            
            local itemBtn = Instance.new("TextButton")
            itemBtn.Text = "  " .. name
            itemBtn.Font = Enum.Font.Gotham
            itemBtn.TextSize = 13
            itemBtn.TextColor3 = initialValue and theme.accent or theme.textDim
            itemBtn.TextXAlignment = Enum.TextXAlignment.Left
            itemBtn.BackgroundTransparency = 1
            itemBtn.Size = UDim2.new(1, 0, 0, itemHeight)
            itemBtn.ZIndex = 11
            itemBtn.Parent = listContainer

            itemBtn.MouseButton1Click:Connect(function()
                selectedItems[name] = not selectedItems[name]
                itemBtn.TextColor3 = selectedItems[name] and theme.accent or theme.textDim
                updateLabel()
                callback(selectedItems)
            end)
        end
        updateLabel()

        dropdownBtn.MouseButton1Click:Connect(function()
            expanded = not expanded
            arrow.Text = expanded and "-" or "+"
            listContainer.Visible = true
            local listSize = expanded and (#items * (itemHeight + 2) + 10) or 0
            createTween(listContainer, {Size = UDim2.new(1, 0, 0, listSize)}, 0.2)
            createTween(frame, {Size = UDim2.new(1, 0, 0, expanded and (55 + listSize + 5) or 55)}, 0.2)
            if not expanded then
                task.delay(0.2, function() if not expanded then listContainer.Visible = false end end)
            end
        end)

        return frame
    end

    local function createTabHeader(text)
        local container = Instance.new("Frame")
        container.BackgroundTransparency = 1
        container.Size = UDim2.new(1, 0, 0, 30) -- Increased height
        container.Parent = tabContainer

        local header = Instance.new("TextLabel")
        header.Text = text
        header.Font = Enum.Font.GothamBlack -- Thicker font
        header.TextSize = 10 -- Smaller but bolder
        header.TextColor3 = theme.textDim
        registerTheme(header, "textDim", "TextColor3")
        header.TextTransparency = 0.5 -- More faded
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.BackgroundTransparency = 1
        header.Size = UDim2.new(1, 0, 1, 0)
        header.Position = UDim2.new(0, 15, 0, 5) -- Pushed down slightly
        header.Parent = container

        -- Optional: Add a subtle divider line below the text if desired, 
        -- but just making it small/bold/faded usually helps distinction.
        
        return container
    end

    -- Build Tabs
    createTabHeader("MAIN")
    local generalTab = createTab("General")
    local visualsTab = createTab("Visuals")
    local desyncTab = createTab("Desync")
    
    createTabHeader("MISC")
    local settingsTab = createTab("Settings")

    -- General Tab
    local exploitSec = createSection(generalTab, "Exploits")
    createToggle(exploitSec, "No Camera Rotation", settings.exploits.noCameraRotate, function(v)
        settings.exploits.noCameraRotate = v
    end)
    
    createToggleWithKeybind(exploitSec, "Enable WalkSpeed", settings.exploits.walkSpeedEnabled, settings.exploits.walkSpeedKeybind, function(v)
        settings.exploits.walkSpeedEnabled = v
        settings.exploits.walkSpeedActive = v
        if updateKeybindList then updateKeybindList() end
    end, function(k)
        settings.exploits.walkSpeedKeybind = k
        if updateKeybindList then updateKeybindList() end
    end)
    createSlider(exploitSec, "WalkSpeed", settings.exploits.walkSpeed, 16, 200, 1, function(v)
        settings.exploits.walkSpeed = v
    end)
    createDropdown(exploitSec, "WalkSpeed Method", {"Default", "CFrame"}, settings.exploits.walkSpeedMethod, function(v)
        settings.exploits.walkSpeedMethod = v
    end)

    createToggle(exploitSec, "Enable JumpPower", settings.exploits.jumpPowerEnabled, function(v)
        settings.exploits.jumpPowerEnabled = v
    end)
    createSlider(exploitSec, "JumpPower", settings.exploits.jumpPower, 50, 500, 1, function(v)
        settings.exploits.jumpPower = v
    end)

    createToggle(exploitSec, "Enable FOV", settings.exploits.fovEnabled, function(v)
        settings.exploits.fovEnabled = v
    end)
    createSlider(exploitSec, "FOV", settings.exploits.fovAmount, 30, 120, 1, function(v)
        settings.exploits.fovAmount = v
    end)

    createToggle(exploitSec, "Enable Gravity", settings.exploits.gravityEnabled, function(v)
        settings.exploits.gravityEnabled = v
        if not v then workspace.Gravity = 196.2 end
    end)
    createSlider(exploitSec, "Gravity", settings.exploits.gravityAmount, 0, 196.2, 0.1, function(v)
        settings.exploits.gravityAmount = v
    end)

    createToggle(exploitSec, "Enable HipHeight", settings.exploits.hipHeightEnabled, function(v)
        settings.exploits.hipHeightEnabled = v
        if not v then
            local char = LP.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if hum then
                hum.HipHeight = 2 -- Default HipHeight
            end
        end
    end)
    createSlider(exploitSec, "HipHeight", settings.exploits.hipHeightAmount, -2, 20, 0.1, function(v)
        settings.exploits.hipHeightAmount = v
    end)

    createToggle(exploitSec, "Anti-Void", settings.exploits.antiVoidEnabled, function(v)
        settings.exploits.antiVoidEnabled = v
    end)
    createToggle(exploitSec, "Show Void Level", settings.exploits.showVoidLevel, function(v)
        settings.exploits.showVoidLevel = v
    end)
    createToggle(exploitSec, "Void God Mode", settings.exploits.voidGodMode, function(v)
        settings.exploits.voidGodMode = v
    end)
    createToggleWithKeybind(exploitSec, "Flight", settings.exploits.flightEnabled, settings.exploits.flightKeybind, function(v)
        settings.exploits.flightEnabled = v
        settings.exploits.flightActive = v
        if updateKeybindList then updateKeybindList() end
    end, function(k)
        settings.exploits.flightKeybind = k
        if updateKeybindList then updateKeybindList() end
    end)

    createToggleWithKeybind(exploitSec, "Noclip", settings.exploits.noclipEnabled, settings.exploits.noclipKeybind, function(v)
        settings.exploits.noclipEnabled = v
        settings.exploits.noclipActive = v
        if updateKeybindList then updateKeybindList() end
    end, function(k)
        settings.exploits.noclipKeybind = k
        if updateKeybindList then updateKeybindList() end
    end)
    createSlider(exploitSec, "Flight Speed", settings.exploits.flightSpeed, 10, 300, 1, function(v)
        settings.exploits.flightSpeed = v
    end)

    -- Desync Tab
    local desyncSec = createSection(desyncTab, "Desync")
    createToggle(desyncSec, "Enabled", settings.desync.enabled, function(v)
        settings.desync.enabled = v
    end)
    createDropdown(desyncSec, "Method", {"Velocity", "CFrame", "Freeze"}, settings.desync.method, function(v)
        settings.desync.method = v
    end)
    createSlider(desyncSec, "Power", settings.desync.power, 1, 100, 1, function(v)
        settings.desync.power = v
    end)
    createSlider(desyncSec, "Range", settings.desync.range, 1, 20, 0.5, function(v)
        settings.desync.range = v
    end)
    local desyncVisToggle = createToggle(desyncSec, "Visualize", settings.desync.visualize, function(v)
        settings.desync.visualize = v
    end)
    createColorPicker(desyncVisToggle, "Visualize Color", settings.desync.color, function(v)
        settings.desync.color = v
    end, nil, true)

    local desyncMoveSec = createSection(desyncTab, "Movement")
    createDropdown(desyncMoveSec, "Type", {"None", "Spinbot", "Backwards", "Upside down"}, settings.desync.movement.type, function(v)
        settings.desync.movement.type = v
    end)
    createSlider(desyncMoveSec, "Spin Speed", settings.desync.movement.speed, 1, 100, 1, function(v)
        settings.desync.movement.speed = v
    end)

    local desyncFlingSec = createSection(desyncTab, "Fling")
    createToggle(desyncFlingSec, "Client Smoothing", settings.fling.smoothing, function(v)
        settings.fling.smoothing = v
    end)

    -- Visuals Tab
    local mainSec = createSection(visualsTab, "Main")
    local pingToggle = createToggle(mainSec, "Ping Chams", settings.pingChams, function(v) settings.pingChams = v end)
    createColorPicker(pingToggle, "Ping Color", settings.pingColor, function(v) settings.pingColor = v end, nil, true)
    
    local predToggle = createToggle(mainSec, "Prediction Chams", settings.predictionChams, function(v) settings.predictionChams = v end)
    createColorPicker(predToggle, "Prediction Color", settings.predictionColor, function(v) settings.predictionColor = v end, nil, true)
    
    local desyncToggle = createToggle(mainSec, "Desync Chams", settings.desync.chams.enabled, function(v)
        settings.desync.chams.enabled = v
    end)
    createColorPicker(desyncToggle, "Desync Chams Color", settings.desync.chams.color, function(v)
        settings.desync.chams.color = v
    end, nil, true)

    local latSec = createSection(visualsTab, "Latency")
    createSlider(latSec, "Delay Multiplier", settings.delayMul, 0.5, 1.5, 0.05, function(v) settings.delayMul = v end)

    local playerVisSec = createSection(visualsTab, "Player Visuals")
    createToggle(playerVisSec, "ESP", settings.esp.enabled, function(v)
        settings.esp.enabled = v
    end)
    createMultiDropdown(playerVisSec, "ESP Options", {"Bounding Box", "Name", "Health", "Tracers", "Weapon", "Visible Only", "Team Check", "Show Distance", "Show Health"}, function(selected)
        settings.esp.box = selected["Bounding Box"]
        settings.esp.name = selected["Name"]
        settings.esp.health = selected["Health"]
        settings.esp.tracers = selected["Tracers"]
        settings.esp.weapon = selected["Weapon"]
        settings.esp.visibleOnly = selected["Visible Only"]
        settings.esp.teamCheck = selected["Team Check"]
        settings.esp.showDistance = selected["Show Distance"]
        settings.esp.showHealth = selected["Show Health"]
    end, {
        ["Bounding Box"] = settings.esp.box,
        ["Name"] = settings.esp.name,
        ["Health"] = settings.esp.health,
        ["Tracers"] = settings.esp.tracers,
        ["Weapon"] = settings.esp.weapon,
        ["Visible Only"] = settings.esp.visibleOnly,
        ["Team Check"] = settings.esp.teamCheck,
        ["Show Distance"] = settings.esp.showDistance,
        ["Show Health"] = settings.esp.showHealth
    })
    createSlider(playerVisSec, "Max Distance", settings.esp.maxDistance, 100, 5000, 50, function(val)
        settings.esp.maxDistance = val
    end)

    local lightSec = createSection(visualsTab, "Lighting")
    createToggle(lightSec, "Enable Lighting Override", settings.lighting.enabled, function(v)
        settings.lighting.enabled = v
        if v then applyLighting() end
    end)
    createSlider(lightSec, "Brightness", settings.lighting.brightness, 0, 10, 0.1, function(v)
        settings.lighting.brightness = v
        applyLighting()
    end)
    createSlider(lightSec, "Exposure", settings.lighting.exposure, -5, 5, 0.1, function(v)
        settings.lighting.exposure = v
        applyLighting()
    end)
    createSlider(lightSec, "Fog Start", settings.lighting.fogStart, 0, 10000, 10, function(v)
        settings.lighting.fogStart = v
        applyLighting()
    end)
    createSlider(lightSec, "Fog End", settings.lighting.fogEnd, 0, 100000, 100, function(v)
        settings.lighting.fogEnd = v
        applyLighting()
    end)
    createSlider(lightSec, "Clock Time", settings.lighting.clockTime, 0, 24, 0.1, function(v)
        settings.lighting.clockTime = v
        applyLighting()
    end)
    createSlider(lightSec, "Shadow Softness", settings.lighting.shadowSoftness, 0, 1, 0.05, function(v)
        settings.lighting.shadowSoftness = v
        applyLighting()
    end)
    createToggle(lightSec, "Global Shadows", settings.lighting.globalShadows, function(v)
        settings.lighting.globalShadows = v
        applyLighting()
    end)
    createColorPicker(lightSec, "Outdoor Ambient", settings.lighting.outdoorAmbient, function(c, t)
         settings.lighting.outdoorAmbient = c
         applyLighting()
     end)
    createColorPicker(lightSec, "Ambient", settings.lighting.ambient, function(c, t)
         settings.lighting.ambient = c
         applyLighting()
    end)
    createColorPicker(lightSec, "ColorShift Top", settings.lighting.colorShift_Top, function(c, t)
        settings.lighting.colorShift_Top = c
        applyLighting()
    end)
    createColorPicker(lightSec, "ColorShift Bottom", settings.lighting.colorShift_Bottom, function(c, t)
        settings.lighting.colorShift_Bottom = c
        applyLighting()
    end)

    -- Settings Tab
    local menuSec = createSection(settingsTab, "Configuration")
    
    -- General Settings Header
    local genHeader = Instance.new("TextLabel")
    genHeader.Text = "GENERAL"
    genHeader.Font = Enum.Font.GothamBold
    genHeader.TextSize = 12
    genHeader.TextColor3 = theme.textDim
    genHeader.BackgroundTransparency = 1
    genHeader.Size = UDim2.new(1, 0, 0, 20)
    genHeader.TextXAlignment = Enum.TextXAlignment.Left
    genHeader.Parent = menuSec
    registerTheme(genHeader, "textDim", "TextColor3")

    createKeybind(menuSec, "Menu Keybind", settings.menuKeybind, function(key)
        settings.menuKeybind = key
        updateKeybindList()
    end)
    
    createToggle(menuSec, "Keybind List", keybindListEnabled, function(v)
        keybindListEnabled = v
        if v then
            if not keybindListFrame then createKeybindList() end
            keybindListFrame.Visible = true
        else
            if keybindListFrame then keybindListFrame.Visible = false end
        end
    end)
    
    createSlider(menuSec, "UI Scale", settings.uiScale, 0.5, 1.5, 0.05, function(v)
        settings.uiScale = v
        if mainFrame:FindFirstChild("MainScale") then mainFrame.MainScale.Scale = v end
        if dockFrame:FindFirstChild("DockScale") then dockFrame.DockScale.Scale = v end
        if playersFrame:FindFirstChild("PlayersScale") then playersFrame.PlayersScale.Scale = v end
    end)

    createButton(menuSec, "Rejoin Server", function()
        local ts = game:GetService("TeleportService")
        local players = game:GetService("Players")
        if #players:GetPlayers() <= 1 then
            players.LocalPlayer:Kick("\nRejoining...")
            wait()
            ts:Teleport(game.PlaceId, players.LocalPlayer)
        else
            ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, players.LocalPlayer)
        end
    end)

    -- Theme Settings Header
    local themeHeader = Instance.new("TextLabel")
    themeHeader.Text = "THEME"
    themeHeader.Font = Enum.Font.GothamBold
    themeHeader.TextSize = 12
    themeHeader.TextColor3 = theme.textDim
    themeHeader.BackgroundTransparency = 1
    themeHeader.Size = UDim2.new(1, 0, 0, 20)
    themeHeader.TextXAlignment = Enum.TextXAlignment.Left
    themeHeader.Parent = menuSec
    registerTheme(themeHeader, "textDim", "TextColor3")

    createColorPicker(menuSec, "Accent Color", theme.accent, function(c, t)
        theme.accent = c
        theme.accentTrans = t
        applyThemeUpdates()
        if glowStroke then glowStroke.Color = c end
    end, theme.accentTrans)
    createColorPicker(menuSec, "Background Color", theme.background, function(c, t)
        theme.background = c
        theme.backgroundTrans = t
        applyThemeUpdates()
    end, theme.backgroundTrans)
    createColorPicker(menuSec, "Foreground Color", theme.sidebar, function(c, t)
        theme.sidebar = c
        theme.sidebarTrans = t
        applyThemeUpdates()
    end, theme.sidebarTrans)
    createColorPicker(menuSec, "Text Color", theme.text, function(c, t)
        theme.text = c
        theme.textTrans = t
        applyThemeUpdates()
    end, theme.textTrans)
    createColorPicker(menuSec, "Dim Text Color", theme.textDim, function(c, t)
        theme.textDim = c
        theme.textDimTrans = t
        applyThemeUpdates()
    end, theme.textDimTrans)
    
    local snowLoopRunning = false
    createMultiDropdown(menuSec, "Menu Effects", {"Glow Effect", "Snow Effect"}, function(selected)
        theme.glow = selected["Glow Effect"]
        if glowStroke then
            glowStroke.Thickness = theme.glow and 4 or 0
        end
        
        theme.snow = selected["Snow Effect"]
        if theme.snow and not snowLoopRunning then
            snowLoopRunning = true
            task.spawn(function()
                while theme.snow and mainFrame.Visible do
                    local flake = Instance.new("Frame")
                    flake.BackgroundColor3 = Color3.new(1,1,1)
                    flake.BorderSizePixel = 0
                    flake.Size = UDim2.new(0, math.random(2,4), 0, math.random(2,4))
                    flake.Position = UDim2.new(math.random(), 0, -0.1, 0)
                    flake.BackgroundTransparency = math.random(0.3, 0.7)
                    flake.Parent = snowContainer
                    local dur = math.random(2, 5)
                    createTween(flake, {Position = UDim2.new(flake.Position.X.Scale + (math.random(-10,10)/100), 0, 1.1, 0), BackgroundTransparency = 1}, dur)
                    game:GetService("Debris"):AddItem(flake, dur)
                    task.wait(math.random(1,5)/20)
                end
                snowLoopRunning = false
            end)
        end
    end, {["Glow Effect"] = theme.glow, ["Snow Effect"] = theme.snow})

    createButton(menuSec, "Test Notification", function()
        notify("skid", "skid", 5)
    end)

    -- Watermark Header
    local watermarkHeader = Instance.new("TextLabel")
    watermarkHeader.Text = "WATERMARK"
    watermarkHeader.Font = Enum.Font.GothamBold
    watermarkHeader.TextSize = 12
    watermarkHeader.TextColor3 = theme.textDim
    watermarkHeader.BackgroundTransparency = 1
    watermarkHeader.Size = UDim2.new(1, 0, 0, 20)
    watermarkHeader.TextXAlignment = Enum.TextXAlignment.Left
    watermarkHeader.Parent = menuSec
    registerTheme(watermarkHeader, "textDim", "TextColor3")

    createToggle(menuSec, "Show Watermark", settings.watermarkEnabled, function(v)
        settings.watermarkEnabled = v
        watermarkFrame.Visible = v
        updateWatermark()
    end)

    createMultiDropdown(menuSec, "Watermark Options", {"Username", "FPS", "Ping", "Avatar"}, function(selected)
        settings.watermarkOptions = selected
        updateWatermark()
    end, settings.watermarkOptions)

    -- Select first tab
    switchTab("General")

    -- Loading Animation
    createTween(logo, {TextTransparency = 0, Position = UDim2.new(0, 0, 0.25, 0)}, 0.8)
    createTween(barBg, {BackgroundTransparency = 0, Position = UDim2.new(0.5, 0, 0.7, 0)}, 0.8)
    createTween(loadingLabel, {TextTransparency = 0}, 0.8)
    wait(0.5)
    
    loadingLabel.Text = "Loading Assets..."
    createTween(barFill, {Size = UDim2.new(0.3, 0, 1, 0)}, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
    wait(0.6)
    
    loadingLabel.Text = "Initializing Physics..."
    createTween(barFill, {Size = UDim2.new(0.7, 0, 1, 0)}, 0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
    wait(0.7)
    
    loadingLabel.Text = "Starting Services..."
    createTween(barFill, {Size = UDim2.new(1, 0, 1, 0)}, 0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
    wait(0.5)
    
    createTween(loadingFrame, {BackgroundTransparency = 1}, 0.5)
    createTween(logo, {TextTransparency = 1}, 0.5)
    createTween(barBg, {BackgroundTransparency = 1}, 0.5)
    createTween(barFill, {BackgroundTransparency = 1}, 0.5)
    createTween(loadingLabel, {TextTransparency = 1}, 0.5)
    
    mainFrame.Visible = false
    loadingFrame:Destroy()

    _G.GhostPingUI = { cleanupUI = cleanupUI }
end

local function updatePing()
    local now = tick()
    if now - lastPingUpdate < PING_UPDATE_INTERVAL then return end
    lastPingUpdate = now
    local samples = {}
    local rfMs = probePingMsRF()
    if rfMs then table.insert(samples, rfMs) end
    local sMs = probePingMsStats()
    if sMs then table.insert(samples, sMs) end
    if #samples > 0 then
        local ms = median(samples)
        local sec = math.clamp(ms * 0.001, 0.002, 1.0)
        pushPing(sec)
        local med = median({table.unpack(pingBuf)})
        local alpha = (#pingBuf >= 5) and 0.25 or 0.5
        if med then
            rtt = rtt * (1 - alpha) + med * alpha
        else
            rtt = sec
        end
    end
end

local function sizeFromCharacter(char)
    if not char then return Vector3.new(4,6,2) end
    local ok, size = pcall(function() return char:GetExtentsSize() end)
    if ok and size then
        return Vector3.new(math.max(2, size.X), math.max(3, size.Y), math.max(1, size.Z))
    end
    return Vector3.new(4,6,2)
end

local function collectRigParts(char)
    local parts = {}
    if not char then return parts end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
            parts[#parts+1] = d
        end
    end
    return parts
end

local function getRootPart(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("LowerTorso")
end

local function isFirstPerson()
    local cam = Workspace.CurrentCamera
    local head = LP.Character and LP.Character:FindFirstChild("Head")
    local lock = LP.CameraMode == Enum.CameraMode.LockFirstPerson
    local near = head and (cam.CFrame.Position - head.Position).Magnitude < 1.2
    return lock or near
end

local function clearGhostRig()
    for _, info in pairs(ghostRig) do
        if info.box then info.box:Destroy() end
        if info.part then info.part:Destroy() end
    end
    ghostRig = {}
end

local function clearGhostClone()
    ghostMap = {}
    if ghostClone then
        ghostClone:Destroy()
        ghostClone = nil
    end
end

local function rebuildGhostRig(char)
    clearGhostRig()
    local parts = collectRigParts(char)
    for _, src in ipairs(parts) do
        local gp = Instance.new("Part")
        gp.Name = "Ghost_"..src.Name
        gp.Anchored = true
        gp.CanCollide = false
        gp.Transparency = 1
        gp.Material = Enum.Material.Neon
        gp.Size = src.Size
        gp.Parent = ghostModel
        local aura = Instance.new("ParticleEmitter")
        aura.Name = "Aura_"..src.Name
        aura.Rate = 40
        aura.Lifetime = NumberRange.new(0.4, 0.7)
        aura.Speed = NumberRange.new(0.0, 0.05)
        aura.SpreadAngle = Vector2.new(20, 20)
        aura.Rotation = NumberRange.new(0, 360)
        aura.RotSpeed = NumberRange.new(-20, 20)
        aura.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, math.max(0.1, math.min(src.Size.Magnitude/12, 0.4))),
            NumberSequenceKeypoint.new(1, 0.0)
        })
        aura.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.0),
            NumberSequenceKeypoint.new(1, 1.0)
        })
        aura.LightInfluence = 0
        aura.LockedToPart = true
        aura.EmissionDirection = Enum.NormalId.Front
        aura.Enabled = true
        aura.Parent = gp
        ghostRig[src.Name] = {part = gp, aura = aura}
    end
end

local function rebuildGhostClone(char, col, trans)
    clearGhostClone()
    ghostClone = Instance.new("Model")
    ghostClone.Name = "GhostClone"
    ghostClone.Parent = ghostModel
    local parts = collectRigParts(char)
    for _, src in ipairs(parts) do
        local gp
        if src:IsA("MeshPart") or src:IsA("Part") then
            gp = src:Clone()
            for _, d in ipairs(gp:GetDescendants()) do
                if d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Motor6D") then
                    d:Destroy()
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
        gp.Material = Enum.Material.ForceField
        gp.Color = col
        gp.Transparency = trans
        gp.Parent = ghostClone
        ghostMap[src.Name] = gp
    end
end

local function clearGhostCloneFuture()
    ghostMapFuture = {}
    if ghostCloneFuture then
        ghostCloneFuture:Destroy()
        ghostCloneFuture = nil
    end
end

local function rebuildGhostCloneFuture(char, col, trans)
    clearGhostCloneFuture()
    ghostCloneFuture = Instance.new("Model")
    ghostCloneFuture.Name = "GhostCloneFuture"
    ghostCloneFuture.Parent = ghostModel
    local parts = collectRigParts(char)
    for _, src in ipairs(parts) do
        local gp
        if src:IsA("MeshPart") or src:IsA("Part") then
            gp = src:Clone()
            for _, d in ipairs(gp:GetDescendants()) do
                if d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Motor6D") then
                    d:Destroy()
                end
            end
        else
            gp = Instance.new("Part")
            gp.Size = src.Size
        end
        gp.Name = "GhostFuture_"..src.Name
        gp.Anchored = true
        gp.CanCollide = false
        gp.CanQuery = false
        gp.CanTouch = false
        gp.CastShadow = false
        gp.Material = Enum.Material.ForceField
        gp.Color = col
        gp.Transparency = trans
        gp.Parent = ghostCloneFuture
        ghostMapFuture[src.Name] = gp
    end
end


local function ensureGhost()
    if not ghostModel then
        ghostModel = Instance.new("Model")
        ghostModel.Name = "ServerApproxGhost"
        ghostModel.Parent = workspace
    end
    if not ghostPart then
        ghostPart = Instance.new("Part")
        ghostPart.Name = "ServerApproxPart"
        ghostPart.Anchored = true
        ghostPart.CanCollide = false
        ghostPart.CanQuery = false
        ghostPart.CanTouch = false
        ghostPart.Transparency = 1
        ghostPart.Size = sizeFromCharacter(LP.Character)
        ghostPart.Parent = ghostModel
    end
    if not ghostFuturePart then
        ghostFuturePart = Instance.new("Part")
        ghostFuturePart.Name = "PredictionApproxPart"
        ghostFuturePart.Anchored = true
        ghostFuturePart.CanCollide = false
        ghostFuturePart.CanQuery = false
        ghostFuturePart.CanTouch = false
        ghostFuturePart.Transparency = 1
        ghostFuturePart.Size = sizeFromCharacter(LP.Character)
        ghostFuturePart.Parent = ghostModel
    end
    -- tracers removed
    if not pingGui then
        pingGui = Instance.new("BillboardGui")
        pingGui.Name = "PingInfo"
        pingGui.Size = UDim2.new(0, 140, 0, 24)
        pingGui.Adornee = ghostPart
        pingGui.StudsOffset = Vector3.new(0, ghostPart and (ghostPart.Size.Y/2 + 2) or 6, 0)
        pingGui.AlwaysOnTop = true
        pingGui.Parent = ghostModel
        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextScaled = true
        lbl.TextColor3 = Color3.fromRGB(220,220,220)
        lbl.Text = "Ping: -- ms"
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        lbl.Parent = pingGui
    end
    if not futureGui then
        futureGui = Instance.new("BillboardGui")
        futureGui.Name = "FutureInfo"
        futureGui.Size = UDim2.new(0, 140, 0, 24)
        futureGui.Adornee = ghostFuturePart
        futureGui.StudsOffset = Vector3.new(0, ghostFuturePart and (ghostFuturePart.Size.Y/2 + 2) or 6, 0)
        futureGui.AlwaysOnTop = true
        futureGui.Parent = ghostModel
        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextScaled = true
        lbl.TextColor3 = Color3.fromRGB(220,220,220)
        lbl.Text = "Vel: --"
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        lbl.Parent = futureGui
    end
end

local function overwriteCharacterSelections()
    local char = LP.Character
    if not char then return end
    for _, inst in ipairs(char:GetDescendants()) do
        if inst:IsA("SelectionBox") then
            inst.Color3 = Color3.fromRGB(40,180,255)
            inst.LineThickness = 0.05
            inst.SurfaceTransparency = 1
            inst.Adornee = char
        end
    end
end

local function captureOffsets(char, root)
    local map = {}
    if not char or not root then return map end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d ~= root then
            -- relative to HRP at this moment
            map[d.Name] = root.CFrame:ToObjectSpace(d.CFrame)
        end
    end
    return map
end

local function pushSample(tClient, char)
    local root = getRootPart(char)
    if not root then return end
    local offsets = captureOffsets(char, root)
    local vel = Vector3.new()
    local angVel = Vector3.new()
    local moveDir = Vector3.new()
    local walkSpeed = 0
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local ok1, v = pcall(function() return root.AssemblyLinearVelocity end)
    if ok1 and typeof(v) == "Vector3" then vel = v end
    local ok2, w = pcall(function() return root.AssemblyAngularVelocity end)
    if ok2 and typeof(w) == "Vector3" then angVel = w end
    if hum then
        local ok3, md = pcall(function() return hum.MoveDirection end)
        if ok3 and typeof(md) == "Vector3" then moveDir = md end
        local ok4, ws = pcall(function() return hum.WalkSpeed end)
        if ok4 and type(ws) == "number" then walkSpeed = ws end
    end
    table.insert(BUFFER, {t=tClient, cf=root.CFrame, offsets=offsets, vel=vel, angVel=angVel, md=moveDir, ws=walkSpeed})
    local cutoff = tClient - BUFFER_MAX_SECONDS
    local i = 1
    while i <= #BUFFER and BUFFER[i].t < cutoff do
        table.remove(BUFFER, i)
    end
end

local function lerpCFrame(a, b, alpha)
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

local function sampleAtClientTime(target)
    if #BUFFER == 0 then return nil end
    local prev = BUFFER[1]
    for i = 1, #BUFFER do
        local s = BUFFER[i]
        if s.t >= target then
            local p = BUFFER[math.max(i-1,1)]
            local n = s
            if p.t == n.t then return {root=p.cf, offsets=p.offsets} end
            local alpha = math.clamp((target - p.t) / (n.t - p.t), 0, 1)
            -- interpolate HRP only; use nearest offsets for limbs
            local cf = lerpCFrame(p.cf, n.cf, alpha)
            local offsets = {}
            if p.offsets or n.offsets then
                for name, aOff in pairs(p.offsets or {}) do
                    local bOff = (n.offsets and n.offsets[name]) or aOff
                    offsets[name] = lerpCFrame(aOff, bOff, alpha)
                end
                for name, bOff in pairs(n.offsets or {}) do
                    if not offsets[name] then
                        local aOff = (p.offsets and p.offsets[name]) or bOff
                        offsets[name] = lerpCFrame(aOff, bOff, alpha)
                    end
                end
            end
            return {root=cf, offsets=offsets}
        end
        prev = s
    end
    return {root=prev.cf, offsets=prev.offsets}
end

local function predictAtClientTime(target)
    if #BUFFER < 1 then return nil end
    local meas = BUFFER[#BUFFER]
    local prev = BUFFER[#BUFFER-1] or meas
    local lx, ly, lz = meas.cf:ToOrientation()
    local dtMeas = math.max(0.0001, meas.t - (_G._PF and _G._PF.t or meas.t))
    local pf = _G._PF
    if not pf then
        local px, py, pz = prev.cf:ToOrientation()
        local dtPrev = math.max(0.0001, meas.t - prev.t)
        local initYawRate = (ly - py) / dtPrev
        pf = {
            pos = meas.cf.Position,
            vel = meas.vel or Vector3.new(),
            yaw = ly,
            yawRate = (meas.angVel and meas.angVel.Y) or initYawRate,
            pitch = lx,
            roll = lz,
            t = meas.t
        }
    else
        local xPred = pf.pos + pf.vel * dtMeas
        local vPred = pf.vel
        if meas.md and meas.ws and meas.md.Magnitude > 0.05 then
            local desiredPlanar = meas.md.Unit * meas.ws
            local desired = Vector3.new(desiredPlanar.X, vPred.Y, desiredPlanar.Z)
            vPred = vPred:Lerp(desired, 0.5)
        end
        local yawPred = pf.yaw + pf.yawRate * dtMeas
        local alpha = 0.6
        local beta = 0.3
        local posRes = (meas.cf.Position - xPred)
        local yawRes = (ly - yawPred)
        pf.pos = xPred + posRes * alpha
        pf.vel = vPred + (posRes * (beta / dtMeas))
        local maxSpd = 120
        if pf.vel.Magnitude > maxSpd then pf.vel = pf.vel.Unit * maxSpd end
        pf.yaw = yawPred + yawRes * alpha
        local yawRateNew = pf.yawRate + (yawRes * (beta / dtMeas))
        local maxYawRate = math.rad(540)
        if yawRateNew > maxYawRate then yawRateNew = maxYawRate end
        if yawRateNew < -maxYawRate then yawRateNew = -maxYawRate end
        pf.yawRate = yawRateNew
        pf.pitch = lx
        pf.roll = lz
        pf.t = meas.t
    end
    _G._PF = pf
    local d = math.max(0, target - meas.t)
    local pos = pf.pos + pf.vel * d
    local rx = pf.pitch
    local ry = pf.yaw + pf.yawRate * d
    local rz = pf.roll
    local predictedCF = CFrame.new(pos) * CFrame.fromOrientation(rx, ry, rz)
    local lastSmoothT = _G._GhostFutureSmoothT or tick()
    local nowT = tick()
    local dtSmooth = math.max(0.0001, nowT - lastSmoothT)
    local smoothAlpha = math.clamp(dtSmooth * 8, 0.08, 0.45)
    _G._GhostFutureSmooth = _G._GhostFutureSmooth or predictedCF
    local cf = lerpCFrame(_G._GhostFutureSmooth, predictedCF, smoothAlpha)
    _G._GhostFutureSmooth = cf
    _G._GhostFutureSmoothT = nowT
    return {root=cf, offsets=meas.offsets}
end

local function colorForDelay(d)
    local t = math.clamp((d - 0.03) / (0.5 - 0.03), 0, 1)
    local c1 = Color3.fromRGB(40,180,255)
    local c2 = Color3.fromRGB(255,180,60)
    local c3 = Color3.fromRGB(255,60,60)
    local mid = Color3.new(
        c1.R + (c2.R - c1.R) * t,
        c1.G + (c2.G - c1.G) * t,
        c1.B + (c2.B - c1.B) * t
    )
    local c = Color3.new(
        mid.R + (c3.R - mid.R) * t,
        mid.G + (c3.G - mid.G) * t,
        mid.B + (c3.B - mid.B) * t
    )
    return c
end

renderConn = RunService.RenderStepped:Connect(function()
    updatePing()
    ensureGhost()

    local char = LP.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            if not ghostModel or (ghostClone == nil) then
                rebuildGhostClone(char, Color3.fromRGB(40,180,255), 0.6)
            end
            pushSample(tick(), char)
        end
        local sz = sizeFromCharacter(char)
        ghostPart.Size = sz
        overwriteCharacterSelections()
    end

    local sampleDelay = math.clamp(rtt * settings.delayMul, 0.03, 0.8)
    BUFFER_MAX_SECONDS = math.clamp(sampleDelay * 6, 3, 8)
    local now = tick()
    local samplePast = sampleAtClientTime(now - sampleDelay)
    local futureLead = 0.12
    if _G._PF and _G._PF.vel then
        futureLead = math.clamp(_G._PF.vel.Magnitude * 0.004, 0.12, 0.40)
    else
        local last = BUFFER[#BUFFER]
        if last and last.vel then
            futureLead = math.clamp(last.vel.Magnitude * 0.004, 0.12, 0.40)
        end
    end
    local sampleFuture = predictAtClientTime(now + sampleDelay + futureLead)

    local alpha = math.clamp(0.6 - sampleDelay * 0.5, 0.1, 0.6)
    local trailLife = math.clamp(sampleDelay * 1.8, 0.15, 1.2)
    local colPast = settings.pingColor
    local colFuture = settings.predictionColor
    local colLocal = Color3.fromRGB(240,240,240)
    lastColor = colPast

    if (not ghostClone or not ghostCloneFuture) and LP.Character then
        rebuildGhostClone(LP.Character, Color3.fromRGB(40,180,255), 0.6)
        rebuildGhostCloneFuture(LP.Character, Color3.fromRGB(160,100,255), 0.6)
    end

    if samplePast and samplePast.root and settings.pingChams then
        local yawOffset = 0
        if settings.aaMode == "Spin" then
            yawOffset = math.rad((now * settings.aaSpinSpeed) % 360)
        elseif settings.aaMode == "Backwards" then
            yawOffset = math.pi
        end
        local rootPast = samplePast.root * CFrame.Angles(0, yawOffset, 0)
        do
            local lastSmoothT = _G._GhostPastSmoothT or tick()
            local nowT = tick()
            local dtSmooth = math.max(0.0001, nowT - lastSmoothT)
            local smoothAlpha = math.clamp(dtSmooth * 10, 0.12, 0.55)
            _G._GhostPastSmooth = _G._GhostPastSmooth or rootPast
            _G._GhostPastSmooth = lerpCFrame(_G._GhostPastSmooth, rootPast, smoothAlpha)
            _G._GhostPastSmoothT = nowT
        end
        ghostPart.CFrame = _G._GhostPastSmooth
        lastSampleRoot = _G._GhostPastSmooth
        local lpRoot = getRootPart(LP.Character)
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        local speedMeas = lpRoot and lpRoot.AssemblyLinearVelocity.Magnitude or 0
        local speedIntent = 0
        if hum and hum.MoveDirection.Magnitude > 0.01 then
            speedIntent = hum.MoveDirection.Magnitude * (hum.WalkSpeed or 16)
        end
        local speed = math.max(speedMeas, speedIntent)
        local transPast = math.clamp(0.9 - math.min(speed / 16, 1) * 0.65, 0.2, 1)
        do
            local lastFadeT = _G._GhostPastTransT or tick()
            local nowT = tick()
            local dt = math.max(0.0001, nowT - lastFadeT)
            local a = math.clamp(dt * 1.5, 0.02, 0.18)
            _G._GhostPastTransSm = _G._GhostPastTransSm or transPast
            _G._GhostPastTransSm = _G._GhostPastTransSm + (transPast - _G._GhostPastTransSm) * a
            _G._GhostPastTransT = nowT
        end
        for name, gp in pairs(ghostMap) do
            local off = samplePast.offsets and samplePast.offsets[name]
            gp.Color = colPast
            gp.Transparency = _G._GhostPastTransSm
            gp.Material = settings.material
            if off then
                gp.CFrame = _G._GhostPastSmooth * off
            end
        end
        -- legacy aura rig update
        for name, info in pairs(ghostRig) do
            local off = samplePast.offsets and samplePast.offsets[name]
            if off then
                info.part.CFrame = samplePast.root * off
                if info.aura then
                    info.aura.Color = ColorSequence.new(colPast)
                    info.aura.Rate = 20 + math.floor(sampleDelay * 120)
                    info.aura.Lifetime = NumberRange.new(
                        math.clamp(0.25 + sampleDelay * 0.6, 0.25, 1.5),
                        math.clamp(0.5 + sampleDelay * 0.8, 0.5, 1.8)
                    )
                    info.aura.Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, math.max(0.1, math.min(info.part.Size.Magnitude/12, 0.45))),
                        NumberSequenceKeypoint.new(1, 0.0)
                    })
                    info.aura.Enabled = _G._GhostPastTransSm < 0.999
                end
            end
        end
        -- tracer to past ghost
        local root = getRootPart(LP.Character)
        local cam = Workspace.CurrentCamera
        -- tracers removed
        local hrp = getRootPart(LP.Character)
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if settings.aaApply and hrp then
            if not aaGyro or aaGyro.Parent ~= hrp then
                aaGyro = Instance.new("BodyGyro")
                aaGyro.Name = "GhostAA_Gyro"
                aaGyro.P = 10000
                aaGyro.D = 500
                aaGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
                aaGyro.Parent = hrp
            end
            local _, y, _ = hrp.CFrame:ToOrientation()
            aaGyro.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, y + yawOffset, 0)
            hrp.AssemblyAngularVelocity = Vector3.new()
            if hum then hum.AutoRotate = false end
        else
            if aaGyro then aaGyro:Destroy() aaGyro = nil end
            if hum then hum.AutoRotate = true end
        end
    else
        for _, gp in pairs(ghostMap) do gp.Transparency = 1 end
    end

    if sampleFuture and sampleFuture.root and settings.predictionChams then
        local yawOffset = 0
        if settings.aaMode == "Spin" then
            yawOffset = math.rad((now * settings.aaSpinSpeed) % 360)
        elseif settings.aaMode == "Backwards" then
            yawOffset = math.pi
        end
        local rootFuture = sampleFuture.root * CFrame.Angles(0, yawOffset, 0)
        if ghostFuturePart then
            ghostFuturePart.CFrame = rootFuture
            ghostFuturePart.Size = ghostPart.Size
        end
        local lpRoot = getRootPart(LP.Character)
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        local speedMeas = lpRoot and lpRoot.AssemblyLinearVelocity.Magnitude or 0
        local speedIntent = 0
        if hum and hum.MoveDirection.Magnitude > 0.01 then
            speedIntent = hum.MoveDirection.Magnitude * (hum.WalkSpeed or 16)
        end
        local speed = math.max(speedMeas, speedIntent)
        local transFuture = math.clamp(0.9 - math.min(speed / 16, 1) * 0.65, 0.2, 1)
        if isFirstPerson() then
            transFuture = 1
        end
        do
            local lastFadeT = _G._GhostFutureTransT or tick()
            local nowT = tick()
            if isFirstPerson() then
                _G._GhostFutureTransSm = 1
            else
                local dt = math.max(0.0001, nowT - lastFadeT)
                local a = math.clamp(dt * 1.5, 0.02, 0.18)
                _G._GhostFutureTransSm = _G._GhostFutureTransSm or transFuture
                _G._GhostFutureTransSm = _G._GhostFutureTransSm + (transFuture - _G._GhostFutureTransSm) * a
            end
            _G._GhostFutureTransT = nowT
        end
        for name, gp in pairs(ghostMapFuture) do
            local off = sampleFuture.offsets and sampleFuture.offsets[name]
            gp.Color = colFuture
            gp.Transparency = _G._GhostFutureTransSm
            gp.Material = settings.material
            if off then
                gp.CFrame = rootFuture * off
            end
        end
        -- tracer to future ghost
        local root = getRootPart(LP.Character)
        local cam = Workspace.CurrentCamera
        -- tracers removed
        if futureGui and futureGui:FindFirstChild("Label") then
            local pf = _G._PF
            local velMag = (pf and pf.vel and pf.vel.Magnitude) or 0
            futureGui.Adornee = ghostFuturePart
            futureGui.StudsOffset = Vector3.new(0, ghostFuturePart and (ghostFuturePart.Size.Y/2 + 2) or 6, 0)
            futureGui.Label.Text = string.format("Vel: %.1f", velMag)
            futureGui.Label.TextColor3 = colFuture
            local vis = math.clamp(speed / 14, 0, 1)
            local targetTT = 1 - vis
            local lastTT = _G._GhostFutureTextTransT or tick()
            local nowTT = tick()
            local dtTT = math.max(0.0001, nowTT - lastTT)
            local aTT = math.clamp(dtTT * 3, 0.03, 0.25)
            _G._GhostFutureTextTransSm = _G._GhostFutureTextTransSm or targetTT
            _G._GhostFutureTextTransSm = _G._GhostFutureTextTransSm + (targetTT - _G._GhostFutureTextTransSm) * aTT
            _G._GhostFutureTextTransT = nowTT
            futureGui.Label.TextTransparency = _G._GhostFutureTextTransSm
            futureGui.Label.TextStrokeTransparency = _G._GhostFutureTextTransSm
            futureGui.Enabled = settings.predictionChams and (_G._GhostFutureTextTransSm < 0.98)
        end
    else
        for _, gp in pairs(ghostMapFuture) do gp.Transparency = 1 end
        if futureGui then futureGui.Enabled = false end
    end

    for _, gp in pairs(ghostMap) do gp.Color = colPast end
    for _, gp in pairs(ghostMapFuture) do gp.Color = colFuture end
    if pingGui and pingGui:FindFirstChild("Label") then
        pingGui.Adornee = ghostPart
        pingGui.StudsOffset = Vector3.new(0, ghostPart and (ghostPart.Size.Y/2 + 2) or 6, 0)
        pingGui.Label.Text = string.format("Ping: %.0f ms | Delay: %.3f s", rtt*1000, sampleDelay)
        pingGui.Label.TextColor3 = colPast
        local lpRoot = getRootPart(LP.Character)
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        local speedMeas = lpRoot and lpRoot.AssemblyLinearVelocity.Magnitude or 0
        local speedIntent = 0
        if hum and hum.MoveDirection.Magnitude > 0.01 then
            speedIntent = hum.MoveDirection.Magnitude * (hum.WalkSpeed or 16)
        end
        local speed = math.max(speedMeas, speedIntent)
        local vis = math.clamp(speed / 14, 0, 1)
        local targetTT = 1 - vis
        local lastTT = _G._GhostTextTransT or tick()
        local nowTT = tick()
        local dtTT = math.max(0.0001, nowTT - lastTT)
        local aTT = math.clamp(dtTT * 3, 0.03, 0.25)
        _G._GhostTextTransSm = _G._GhostTextTransSm or targetTT
        _G._GhostTextTransSm = _G._GhostTextTransSm + (targetTT - _G._GhostTextTransSm) * aTT
        _G._GhostTextTransT = nowTT
        pingGui.Label.TextTransparency = _G._GhostTextTransSm
        pingGui.Label.TextStrokeTransparency = _G._GhostTextTransSm
        pingGui.Enabled = settings.pingChams and (_G._GhostTextTransSm < 0.995)
    end

    if settings.pingChams or settings.predictionChams then
        if pingGui and pingGui:FindFirstChild("Label") then pingGui.Label.Visible = true end
        for _, info in pairs(ghostRig) do if info.aura then info.aura.Enabled = true end end
    else
        if pingGui and pingGui:FindFirstChild("Label") then pingGui.Label.Visible = false end
        for _, gp in pairs(ghostMap) do gp.Transparency = 1 end
        for _, gp in pairs(ghostMapFuture) do gp.Transparency = 1 end
        for _, info in pairs(ghostRig) do if info.aura then info.aura.Enabled = false end end
        -- tracers removed
    end
end)

_G.GhostPing = { cleanup = cleanup }

playerAddedConn = Players.PlayerAdded:Connect(function(p)
    if p == LP then
        charAddedConn = p.CharacterAdded:Connect(function()
            if ghostPart then ghostPart.Size = sizeFromCharacter(LP.Character) end
            overwriteCharacterSelections()
        end)
    end
end)

if LP.Character then
    overwriteCharacterSelections()
end

    -- Input Handler
    local lastBindingCheck = tick()
    inputConn = UIS.InputBegan:Connect(function(input, gpe)
        -- Safety check: if isBinding is true for more than 10 seconds, reset it
        if isBinding and tick() - lastBindingCheck > 10 then
            isBinding = false
        end
        if isBinding then lastBindingCheck = tick() end

        if gpe or isBinding then return end
    local key = input.KeyCode
    if key == settings.menuKeybind or key == Enum.KeyCode.Insert then
        if not isLoaded then
            notify("System", "Please wait for the script to finish loading...", 3)
            return
        end
        if dockFrame then
            dockFrame.Visible = not dockFrame.Visible
            
            -- Force unlock mouse even in first person
            if dockFrame.Visible then
                UIS.MouseIconEnabled = true
                if dockToggle then dockToggle.Modal = true end
            else
                if dockToggle then dockToggle.Modal = false end
            end
            
            if mainFrame then
                if dockFrame.Visible then
                    mainFrame.Visible = menuVisibleState
                    if playersFrame then playersFrame.Visible = playersVisibleState end
                else
                    mainFrame.Visible = false
                    if playersFrame then playersFrame.Visible = false end
                end
            end
            
            -- Sync selection interface
            if updateSelectionInterface then updateSelectionInterface(false) end
            -- Sync dock glow
            if updateDockGlow then updateDockGlow() end
        end
    elseif key == settings.exploits.flightKeybind then
        if settings.exploits.flightEnabled then
            settings.exploits.flightActive = not settings.exploits.flightActive
            notify("Flight", "Flight has been " .. (settings.exploits.flightActive and "enabled" or "disabled") .. ".", 3)
            updateKeybindList()
        end
    elseif key == settings.exploits.walkSpeedKeybind then
        if settings.exploits.walkSpeedEnabled then
            settings.exploits.walkSpeedActive = not settings.exploits.walkSpeedActive
            notify("WalkSpeed", "WalkSpeed has been " .. (settings.exploits.walkSpeedActive and "enabled" or "disabled") .. ".", 3)
            updateKeybindList()
        end
    elseif key == settings.exploits.noclipKeybind then
        if settings.exploits.noclipEnabled then
            settings.exploits.noclipActive = not settings.exploits.noclipActive
            notify("Noclip", "Noclip has been " .. (settings.exploits.noclipActive and "enabled" or "disabled") .. ".", 3)
            updateKeybindList()
        end
    end
end)

    -- Realtime Keybind Update Loop
    task.spawn(function()
        while task.wait(0.5) do
            if updateKeybindList then
                updateKeybindList()
            end
        end
    end)

    -- Initialize UI
    task.spawn(function()
    buildSleekUI()
    if isAdmin then
        task.wait(1)
        notify("Admin Whitelist", "Welcome back, Admin! Script user tags are now visible.", 10)
    end
    
    task.wait(2) -- Simulate loading time or wait for actual loading
    isLoaded = true
    notify("Notice", "super ultra alpha beta build", 5)
    notify("Notice", "press right control to open the dockbar", 5)
end)
