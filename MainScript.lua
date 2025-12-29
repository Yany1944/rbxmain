if game.PlaceId ~= 142823291 then return end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait(2)

if getgenv().MM2_ESP_Script then
    return
end
getgenv().MM2_ESP_Script = true

local CONFIG = {
    HideKey = Enum.KeyCode.Q,
    CheckInterval = 0.5,
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
    GunESP = false,
    MurderESP = false,
    SheriffESP = false,
    InnocentESP = false,
    AllowReset = true,
    NotificationsEnabled = false,
    GodModeEnabled = false,
    WalkSpeed = 18,
    JumpPower = 50,
    MaxCameraZoom = 100,

    Keybinds = {
        Sit = Enum.KeyCode.Unknown,
        Dab = Enum.KeyCode.Unknown,
        Zen = Enum.KeyCode.Unknown,
        Ninja = Enum.KeyCode.Unknown,
        Floss = Enum.KeyCode.Unknown,
        ClickTP = Enum.KeyCode.Unknown,
        GodMode = Enum.KeyCode.Unknown
    },
    prevMurd = nil,
    prevSher = nil,
    heroSent = false,
    roundStart = true,
    roundActive = false,
    PlayerHighlights = {},
    GunCache = {},
    Connections = {},
    UIElements = {},
    ClickTPActive = false,
    CoinFarmEnabled = false,
    CoinFarmFlySpeed = 35, 
    CoinFarmDelay = 2,
    CoinFarmCollected = {},
    CoinFarmThread = nil,
    AllCoinsCollected = false,
    ListeningForKeybind = nil,
    RoleCheckLoop = nil,
    NotificationQueue = {},
    CurrentNotification = nil
}

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

local function getMap()
    for _, v in next, Workspace:GetChildren() do
        if v:FindFirstChild("CoinContainer") then
            return v
        end
    end
    return nil
end

local function GetCollectedCoinsCount()
    local maxValue = 0

    pcall(function()
        for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if gui:IsA("TextLabel") and gui.Name == "Coins" then
                local parent = gui.Parent
                if parent and parent.Name == "Icon" then
                    local path = gui:GetFullName()
                    -- Universal: check if path ends with .CurrencyFrame.Icon.Coins
                    -- Works with Coin, SnowToken, Egg, Candy, BeachBall, any event!
                    if string.match(path, "%.CurrencyFrame%.Icon%.Coins$") then
                        local value = tonumber(gui.Text) or 0
                        -- Take maximum from all counters
                        if value > maxValue then
                            maxValue = value
                        end
                    end
                end
            end
        end
    end)

    return maxValue
end

local function getNearestCoin(maxDistance)
    local target
    local closestDistance = maxDistance or math.huge
    local map = getMap()
    local humanoidRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    if not map or not humanoidRootPart then return end

    local coinContainer = map:FindFirstChild("CoinContainer")
    if not coinContainer then return end

    for _, coin in pairs(coinContainer:GetChildren()) do
        if coin.Name == "Coin_Server" and not State.CoinFarmCollected[coin] then
            local distance = (coin.Position - humanoidRootPart.Position).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                target = coin
            end
        end
    end
    return target
end

local function SmoothFlyToCoin(coin, humanoidRootPart, speed)
    speed = speed or State.CoinFarmFlySpeed or 35

    local startPos = humanoidRootPart.Position
    local targetPos = coin.Position + Vector3.new(0, 2, 0)
    local distance = (targetPos - startPos).Magnitude
    local duration = distance / speed

    local startTime = tick()

    while tick() - startTime < duration do
        if not State.CoinFarmEnabled then break end

        local character = LocalPlayer.Character
        if not character or not humanoidRootPart.Parent then break end

        local elapsed = tick() - startTime
        local alpha = math.min(elapsed / duration, 1)

        local currentPos = startPos:Lerp(targetPos, alpha)
        humanoidRootPart.CFrame = CFrame.new(currentPos)

        RunService.Heartbeat:Wait()
    end

    if State.CoinFarmEnabled and humanoidRootPart.Parent then
        humanoidRootPart.CFrame = CFrame.new(targetPos)
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

local function ResetAndClearCoinFarm()
    if not State.AllowReset then return end

    State.AllowReset = false

    State.CoinFarmEnabled = false
    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end

    State.CoinFarmCollected = {}
    State.AllCoinsCollected = false

    local character = LocalPlayer.Character
    if character then
        DisableNoClip(character)

        pcall(function()
            character:BreakJoints()
        end)

        task.wait(6)
        State.AllowReset = true
    else
        task.wait(1)
        State.AllowReset = true
    end
end

local function StartCoinFarm()
    if State.CoinFarmThread then
        task.cancel(State.CoinFarmThread)
        State.CoinFarmThread = nil
    end

    if not State.CoinFarmEnabled then return end

    State.CoinFarmThread = task.spawn(function()
        local lastCoinCount = 0
        local noChangeCounter = 0

        while State.CoinFarmEnabled do
            task.wait(0.1)

            if not State.roundActive then
                task.wait(1)
                continue
            end

            local map = getMap()
            if not map then
                task.wait(1)
                continue
            end

            local character = LocalPlayer.Character
            if not character then continue end

            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then continue end

            local currentCoins = GetCollectedCoinsCount()

            if currentCoins == lastCoinCount then
                noChangeCounter = noChangeCounter + 1

                if noChangeCounter >= 50 and State.roundActive and currentCoins > 0 and not State.AllCoinsCollected then
                    State.AllCoinsCollected = true

                    if State.NotificationsEnabled then
                        task.spawn(function()
                            ShowNotification(
                                "All coins collected!",
                                CONFIG.Colors.Green,
                                "Total: " .. currentCoins,
                                CONFIG.Colors.Accent
                            )
                        end)
                    end

                    task.spawn(function()
                        task.wait(1)
                        ResetAndClearCoinFarm()
                    end)
                end
            else
                lastCoinCount = currentCoins
                noChangeCounter = 0
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

                if currentCoins < 3 then
                    local targetCFrame = coin.CFrame + Vector3.new(0, 2, 0)

                    if targetCFrame.Position.Y > -500 and targetCFrame.Position.Y < 10000 then
                        humanoidRootPart.CFrame = targetCFrame
                        task.wait(State.CoinFarmDelay)
                        State.CoinFarmCollected[coin] = true
                    end
                else
                    EnableNoClip(character)
                    SmoothFlyToCoin(coin, humanoidRootPart, State.CoinFarmFlySpeed)
                    task.wait(0.2)
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
    end)
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

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = gunPart
    billboard.Size = UDim2.new(0, 150, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
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

                    if State.CoinFarmEnabled then
                        State.CoinFarmEnabled = false
                        if State.CoinFarmThread then
                            task.cancel(State.CoinFarmThread)
                            State.CoinFarmThread = nil
                        end

                        local character = LocalPlayer.Character
                        if character then
                            DisableNoClip(character)
                        end
                    end

                    State.CoinFarmCollected = {}
                    State.AllCoinsCollected = false

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
                    State.AllowReset = true

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

                    State.CoinFarmCollected = {}
                    State.AllCoinsCollected = false

                    local coinFarmToggle = State.UIElements.CoinFarmToggle
                    if coinFarmToggle and coinFarmToggle.BackgroundColor3 == CONFIG.Colors.Accent then
                        task.wait(2)
                        State.CoinFarmEnabled = true
                        StartCoinFarm()
                    end
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

task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/Yany1944/rbxmain/refs/heads/main/AntiFling.lua'))()
    end)
end)

task.spawn(function()
    while getgenv().MM2_ESP_Script do
        pcall(function()
            for _, connection in next, getconnections(LocalPlayer.Idled) do 
                connection:Disable()
            end
        end)
        task.wait(1)
    end
end)

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
end

local function SetKeybind(bindName, keyCode, button, allButtons)
    local existingBind = FindKeybindButton(keyCode)
    if existingBind and existingBind ~= bindName then
        State.Keybinds[existingBind] = Enum.KeyCode.Unknown
        if allButtons[existingBind] then
            allButtons[existingBind].Text = "Not Bound"
        end
    end

    State.Keybinds[bindName] = keyCode
    button.Text = keyCode.Name
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

local function CreateUI()
    for _, child in ipairs(CoreGui:GetChildren()) do
        if child.Name == "MM2_ESP_UI" then child:Destroy() end
    end

    local gui = Create("ScreenGui", {
        Name = "MM2_ESP_UI",
        ResetOnSpawn = false,
        Parent = CoreGui
    })
    State.UIElements.MainGui = gui

    local mainFrame = Create("Frame", {
        Name = "MainFrame",
        BackgroundColor3 = CONFIG.Colors.Background,
        Position = UDim2.new(0.5, -225, 0.5, -325),
        Size = UDim2.new(0, 450, 0, 650),
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
        Text = "MM2 ESP + ANIMATIONS <font color=\"rgb(90,140,255)\">v5.2</font>",
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
        Text = "Ã—",
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
    task.wait(0.1)
    content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)

    local function CreateSection(title)
        local label = Create("TextLabel", {
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

    local function CreateToggle(title, desc, callback)
        local card = Create("Frame", {
            BackgroundColor3 = CONFIG.Colors.Section,
            Size = UDim2.new(1, 0, 0, 60),
            Parent = content
        })
        AddCorner(card, 8)
        AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

        local cardTitle = Create("TextLabel", {
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

        local cardDesc = Create("TextLabel", {
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

    local function CreateInputField(title, desc, defaultValue, callback)
        local card = Create("Frame", {
            BackgroundColor3 = CONFIG.Colors.Section,
            Size = UDim2.new(1, 0, 0, 60),
            Parent = content
        })
        AddCorner(card, 8)
        AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

        local cardTitle = Create("TextLabel", {
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

        local cardDesc = Create("TextLabel", {
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

    local keybindButtons = {}

    local function CreateKeybindButton(title, emoteId, keybindKey)
        local card = Create("Frame", {
            BackgroundColor3 = CONFIG.Colors.Section,
            Size = UDim2.new(1, 0, 0, 50),
            Parent = content
        })
        AddCorner(card, 8)
        AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

        local cardTitle = Create("TextLabel", {
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

        keybindButtons[keybindKey] = bindButton

        bindButton.MouseButton1Click:Connect(function()
            bindButton.Text = "Press Key..."
            State.ListeningForKeybind = {key = keybindKey, button = bindButton}
        end)

        return bindButton
    end

    local function CreateDropdown(title, desc, options, defaultValue, callback)
        local card = Create("Frame", {
            BackgroundColor3 = CONFIG.Colors.Section,
            Size = UDim2.new(1, 0, 0, 60),
            Parent = content
        })
        AddCorner(card, 8)
        AddStroke(card, 1, CONFIG.Colors.Stroke, 0.7)

        local cardTitle = Create("TextLabel", {
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

        local cardDesc = Create("TextLabel", {
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
            Text = defaultValue,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = CONFIG.Colors.Text,
            BackgroundColor3 = Color3.fromRGB(45, 45, 50),
            Position = UDim2.new(1, -110, 0.5, -12),
            Size = UDim2.new(0, 95, 0, 24),
            AutoButtonColor = false,
            Parent = card
        })
        AddCorner(dropdown, 6)
        AddStroke(dropdown, 1, CONFIG.Colors.Accent, 0.6)

        local dropdownList = Create("Frame", {
            BackgroundColor3 = CONFIG.Colors.Section,
            Position = UDim2.new(0, 325, 0, 10),
            Size = UDim2.new(0, 95, 0, #options * 25),
            Visible = false,
            ZIndex = 10,
            Parent = card
        })
        AddCorner(dropdownList, 6)
        AddStroke(dropdownList, 1, CONFIG.Colors.Accent, 0.6)

        for i, option in ipairs(options) do
            local optionButton = Create("TextButton", {
                Text = option,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = CONFIG.Colors.Text,
                BackgroundColor3 = Color3.fromRGB(40, 40, 45),
                Position = UDim2.new(0, 0, 0, (i-1) * 25),
                Size = UDim2.new(1, 0, 0, 25),
                AutoButtonColor = false,
                ZIndex = 11,
                Parent = dropdownList
            })

            optionButton.MouseButton1Click:Connect(function()
                dropdown.Text = option
                dropdownList.Visible = false
                callback(option)
            end)

            optionButton.MouseEnter:Connect(function()
                TweenService:Create(optionButton, TweenInfo.new(0.2), {BackgroundColor3 = CONFIG.Colors.Accent}):Play()
            end)
            optionButton.MouseLeave:Connect(function()
                TweenService:Create(optionButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 45)}):Play()
            end)
        end

        dropdown.MouseButton1Click:Connect(function()
            dropdownList.Visible = not dropdownList.Visible
        end)

        return dropdown
    end

    CreateSection("CHARACTER SETTINGS")

    CreateInputField("WalkSpeed", "Set custom walk speed", State.WalkSpeed, function(value)
        ApplyWalkSpeed(value)
    end)

    CreateInputField("JumpPower", "Set custom jump power", State.JumpPower, function(value)
        ApplyJumpPower(value)
    end)

    CreateInputField("Max Camera Zoom", "Set maximum camera distance", State.MaxCameraZoom, function(value)
        ApplyMaxCameraZoom(value)
    end)

    CreateSection("NOTIFICATIONS")

    CreateToggle("Enable Notifications", "Show role and gun notifications", function(state)
        State.NotificationsEnabled = state
    end)

    CreateSection("ESP OPTIONS (Highlight)")

    CreateToggle("Gun ESP", "Highlight dropped guns", function(state)
        State.GunESP = state
        if state then
            InitialGunScan()
        else
            UpdateGunESPVisibility()
        end
    end)

    CreateToggle("Murder ESP", "Highlight murderer", function(state)
        State.MurderESP = state
        UpdateAllHighlightsVisibility()
    end)

    CreateToggle("Sheriff ESP", "Highlight sheriff", function(state)
        State.SheriffESP = state
        UpdateAllHighlightsVisibility()
    end)

    CreateToggle("Innocent ESP", "Highlight innocent players", function(state)
        State.InnocentESP = state
        UpdateAllHighlightsVisibility()
    end)

    CreateSection("ANIMATION KEYBINDS")

    CreateKeybindButton("Sit Animation", "sit", "Sit")
    CreateKeybindButton("Dab Animation", "dab", "Dab")
    CreateKeybindButton("Zen Animation", "zen", "Zen")
    CreateKeybindButton("Ninja Animation", "ninja", "Ninja")
    CreateKeybindButton("Floss Animation", "floss", "Floss")

    CreateSection("TELEPORT")

    CreateKeybindButton("Click TP (Hold Key)", "clicktp", "ClickTP")

    CreateSection("COIN FARM")

    State.UIElements.CoinFarmToggle = CreateToggle("Coin Farm", "Automatically collects coins", function(state)
        State.CoinFarmEnabled = state
        if state then
            State.CoinFarmCollected = {}
            StartCoinFarm()
        else
            if State.CoinFarmThread then
                task.cancel(State.CoinFarmThread)
                State.CoinFarmThread = nil
            end

            local character = LocalPlayer.Character
            if character then
                DisableNoClip(character)
            end
        end
    end)

CreateInputField("Fly Speed", "Flight speed in Tween mode (studs/sec)", State.CoinFarmFlySpeed, function(value)
        if value >= 10 and value <= 100 then
            State.CoinFarmFlySpeed = value
        end
    end)

    CreateInputField("Teleport Delay", "Delay between teleports (Teleport mode)", State.CoinFarmDelay, function(value)
        State.CoinFarmDelay = value
    end)

    CreateSection("GODMODE")

    CreateKeybindButton("Toggle GodMode", "godmode", "GodMode")

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
        for player, highlight in pairs(State.PlayerHighlights) do
            pcall(function() highlight:Destroy() end)
        end
        for gunPart, espData in pairs(State.GunCache) do
            if espData.highlight then pcall(function() espData.highlight:Destroy() end) end
            if espData.billboard then pcall(function() espData.billboard:Destroy() end) end
        end

        for _, connection in ipairs(State.Connections) do
            pcall(function() connection:Disconnect() end)
        end

        gui:Destroy()
        if State.UIElements.NotificationGui then
            State.UIElements.NotificationGui:Destroy()
        end

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
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end

        if State.ListeningForKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
            local key = input.KeyCode
            local bindData = State.ListeningForKeybind

            if key == Enum.KeyCode.Delete or key == Enum.KeyCode.Backspace then
                ClearKeybind(bindData.key, bindData.button)
                State.ListeningForKeybind = nil
                return
            end

            SetKeybind(bindData.key, key, bindData.button, keybindButtons)
            State.ListeningForKeybind = nil
            return
        end

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

        if input.KeyCode == State.Keybinds.ClickTP and State.Keybinds.ClickTP ~= Enum.KeyCode.Unknown then
            State.ClickTPActive = true
        end
        if input.KeyCode == State.Keybinds.GodMode and State.Keybinds.GodMode ~= Enum.KeyCode.Unknown then
            ToggleGodMode()
        end
    end)
end

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == State.Keybinds.ClickTP then
        State.ClickTPActive = false
    end
end)

local mouse = LocalPlayer:GetMouse()
mouse.Button1Down:Connect(function()
    if State.ClickTPActive then
        TeleportToMouse()
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    ApplyCharacterSettings()

    State.prevMurd = nil
    State.prevSher = nil
    State.heroSent = false
    State.roundStart = true
    State.roundActive = false
    State.AllowReset = true
    State.CoinFarmCollected = {}
    State.AllCoinsCollected = false

    local character = LocalPlayer.Character
    if character then
        DisableNoClip(character)
    end
end)

CreateUI()
CreateNotificationUI()
ApplyCharacterSettings()
SetupGunTracking()
InitialGunScan()
StartRoleChecking()
