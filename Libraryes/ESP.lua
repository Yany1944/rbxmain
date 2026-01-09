-- ESP.lua

return function(deps)
    local Players = deps.Players
    local Workspace = deps.Workspace
    local RunService = deps.RunService
    local CONFIG = deps.CONFIG
    local State = deps.State
    local TrackConnection = deps.TrackConnection
    local ShowNotification = deps.ShowNotification
    
    local LocalPlayer = Players.LocalPlayer


    local ESP = {}

    ----------------------------------------------------------------
    -- СЮДА ПЕРЕНОСИШЬ КОНКРЕТНЫЕ ФУНКЦИИ ИЗ MAIN:
    ----------------------------------------------------------------
    -- 1) getMurder, getSheriff (Блок 7)
    -- 2) CreateHighlight (твоя функция создания Highlight для персонажа)
    -- 3) UpdatePlayerHighlight (из конца файла, сразу перед getMap)
    -- 4) getMap, getGun, CreateGunESP, RemoveGunESP,
    --    UpdateGunESPVisibility, SetupGunTracking
    -- 5) StartRoleChecking
    ----------------------------------------------------------------

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

    -- Пример заглушки, сюда вставляешь твой код:
    local currentMapConnection = nil
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
    highlight.Adornee = gunPart
    highlight.FillColor = Color3.fromRGB(255, 200, 50)  -- Золотистый
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 200, 50)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = State.GunESP
    highlight.Parent = gunPart
    
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

            for cachedGun, espData in pairs(State.GunCache) do
                if cachedGun ~= gun or not gun then
                    RemoveGunESP(cachedGun)
                end
            end
        end)
    end)
    
    table.insert(State.Connections, currentMapConnection)
    end

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

    ----------------------------------------------------------------
    -- Публичный API
    ----------------------------------------------------------------

    function ESP.Init()
        SetupGunTracking()
        StartRoleChecking()
    end

    function ESP.SetFlags(flags)
        if flags.GunESP ~= nil then
            State.GunESP = flags.GunESP
            UpdateGunESPVisibility()
        end
        if flags.MurderESP ~= nil then
            State.MurderESP = flags.MurderESP
        end
        if flags.SheriffESP ~= nil then
            State.SheriffESP = flags.SheriffESP
        end
        if flags.InnocentESP ~= nil then
            State.InnocentESP = flags.InnocentESP
        end
    end

    function ESP.Cleanup()
        -- Очистка highlights
        if State.PlayerHighlights then
            for _, highlight in pairs(State.PlayerHighlights) do
                if highlight and highlight.Parent then
                    pcall(function() highlight:Destroy() end)
                end
            end
            State.PlayerHighlights = {}
        end

        -- Очистка GunCache
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

        -- Отключение RoleCheckLoop
        if State.RoleCheckLoop then
            pcall(function() State.RoleCheckLoop:Disconnect() end)
            State.RoleCheckLoop = nil
        end

        -- Отключение GunTracking
        if currentMapConnection then
            pcall(function() currentMapConnection:Disconnect() end)
            currentMapConnection = nil
        end
    end

    return ESP
end
