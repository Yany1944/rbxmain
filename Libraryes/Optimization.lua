-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 1: ИНИЦИАЛИЗАЦИЯ И СОСТОЯНИЕ
-- ══════════════════════════════════════════════════════════════════════════════
return function(env)
    if not game:IsLoaded() then game.Loaded:Wait() end
    local okEnv, shared = pcall(function() return getgenv() end)
    assert(okEnv and shared, "Optimization: executor environment unavailable")
    if shared.MM2_OptimizationModule then return shared.MM2_OptimizationModule end

    local Players = game:GetService("Players")
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer
    local CONFIG = {
        FPSCap = 9999,
        AntiGlare = {BrightnessScale = 0.2, Ambient = Color3.fromRGB(0, 0, 0)},
        AnimationInterval = 0.2,
        CoinScript = "CoinVisualizer",
        CoinCallback = "UpdateCoins",
        Candidates = "BasePart, Decal, Texture, SpecialMesh, SurfaceAppearance, ParticleEmitter, Trail, Beam, Smoke, Fire, Sparkles, PostEffect, ForceField",
        Options = {
            {Key = "NoRender", Flag = "AFKMode", Label = "No Render", Hint = "Disable 3D rendering; keep the interface"},
            {Key = "AntiGlare", Label = "Anti-Glare", Hint = "Reduce lighting glare and ambient brightness"},
            {Key = "RemoveTextures", Label = "Remove Textures", Hint = "Hide textures and surface appearances"},
            {Key = "RemoveParticles", Label = "Remove Particles / Effects", Hint = "Disable particles, trails and post effects"},
            {Key = "StopAnimations", Label = "Stop Animations", Hint = "Freeze other players and coin rotation"},
            {Key = "NoShadows", Label = "No Shadows", Hint = "Disable global and part shadows"},
            {Key = "RemoveReflections", Label = "Remove Reflections", Hint = "Disable part, environment and water reflections"},
            {Key = "LowQuality", Label = "Low Quality", Hint = "Use the lowest rendering quality"},
            {Key = "FPSUnlocker", Label = "FPS Unlocker", Hint = "Remove the framerate cap (9999)"},
            {Key = "PlasticMaterials", Label = "Plastic Materials", Hint = "Use smooth plastic for world geometry"},
        },
    }
    local State = {
        Enabled = {}, Records = {}, Connections = {}, CoinConnections = {},
        AnimationSpeeds = {}, Unloaded = false,
    }
    local Module = {State = State, Handlers = {}}

    local function notify(message)
        pcall(env.ShowNotification, "Optimization: " .. message)
    end

    local function disconnect(connection)
        if connection then pcall(function() connection:Disconnect() end) end
    end

    local function setControl(key, value)
        for _,option in ipairs(CONFIG.Options) do
            if option.Key == key then
                local control = env.GUI.Flags[option.Flag or ("Optimize" .. key)]
                if control then control:Set(value, false) end
                break
            end
        end
        if key == "NoRender" then env.State.AFKModeEnabled = value end
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 2: ОБРАТИМЫЕ СВОЙСТВА И ПРИОРИТЕТ ОПТИМИЗАЦИИ
    -- ══════════════════════════════════════════════════════════════════════════
    -- Перехватываем только изменения конкретного свойства. Когда шейдер или
    -- игра меняют его, сохраняем новое значение для последующего восстановления.
    local function forceProperty(key, object, property, value)
        local records = State.Records[key]
        local props = records and records[object]
        if props and props[property] then return end
        local ok, original = pcall(function() return object[property] end)
        if not ok then return end
        local transform = type(value) == "function" and value or nil
        local record = {Original = original, Forced = transform and transform(original) or value, Writing = true}
        local applied = pcall(function()
            object[property] = record.Forced
            record.Forced = object[property]
        end)
        record.Writing = false
        if not applied then return end
        if not records then records = {}; State.Records[key] = records end
        if not props then props = {}; records[object] = props end
        props[property] = record
        local connected, connection = pcall(function()
            return object:GetPropertyChangedSignal(property):Connect(function()
                if record.Writing or State.Unloaded or not State.Enabled[key] then return end
                pcall(function()
                    local current = object[property]
                    if current == record.Forced then return end
                    record.Original = current
                    if transform then record.Forced = transform(current) end
                    record.Writing = true
                    object[property] = record.Forced
                    record.Forced = object[property]
                    record.Writing = false
                end)
                record.Writing = false
            end)
        end)
        if connected then record.Connection = connection end
        local destroyOK, destroyConnection = pcall(function()
            return object.Destroying:Connect(function()
                disconnect(record.Connection)
                disconnect(record.DestroyConnection)
                props[property] = nil
                if not next(props) then records[object] = nil end
            end)
        end)
        if destroyOK then record.DestroyConnection = destroyConnection end
    end

    local function restoreProperties(key)
        local records = State.Records[key]
        if not records then return end
        State.Records[key] = nil
        for object,props in pairs(records) do
            for property,record in pairs(props) do
                disconnect(record.Connection)
                disconnect(record.DestroyConnection)
                pcall(function() object[property] = record.Original end)
            end
        end
    end

    local function applyObject(key, object)
        pcall(function()
            if key == "RemoveTextures" then
                if object:IsA("Decal") or object:IsA("Texture") then
                    forceProperty(key, object, "Transparency", 1)
                elseif object:IsA("MeshPart") then
                    forceProperty(key, object, "TextureID", "")
                elseif object:IsA("SpecialMesh") then
                    forceProperty(key, object, "TextureId", "")
                elseif object:IsA("SurfaceAppearance") then
                    forceProperty(key, object, "Parent", nil)
                end
                if object:IsA("BasePart") then forceProperty(key, object, "MaterialVariant", "") end
            elseif key == "RemoveParticles" then
                if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
                    or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") or object:IsA("PostEffect") then
                    forceProperty(key, object, "Enabled", false)
                    if object:IsA("ParticleEmitter") or object:IsA("Trail") then pcall(function() object:Clear() end) end
                elseif object:IsA("ForceField") then
                    forceProperty(key, object, "Visible", false)
                end
            elseif key == "NoShadows" and object:IsA("BasePart") then
                forceProperty(key, object, "CastShadow", false)
            elseif key == "RemoveReflections" and object:IsA("BasePart") then
                forceProperty(key, object, "Reflectance", 0)
            elseif key == "PlasticMaterials" and object:IsA("BasePart") then
                forceProperty(key, object, "Material", Enum.Material.SmoothPlastic)
            end
        end)
    end

    local function scan(key)
        for _,object in ipairs(Workspace:QueryDescendants(CONFIG.Candidates)) do applyObject(key, object) end
        for _,object in ipairs(Lighting:GetChildren()) do applyObject(key, object) end
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 3: АНИМАЦИИ И МОНЕТЫ
    -- ══════════════════════════════════════════════════════════════════════════
    local function restoreAnimations()
        disconnect(State.AnimationConnection)
        disconnect(State.CoinTick)
        State.AnimationConnection, State.CoinTick = nil, nil
        for _,record in ipairs(State.CoinConnections) do
            pcall(function() record.Connection:Enable() end)
        end
        table.clear(State.CoinConnections)
        for track,record in pairs(State.AnimationSpeeds) do
            disconnect(record.Connection)
            pcall(function() track:AdjustSpeed(record.Speed) end)
        end
        table.clear(State.AnimationSpeeds)
    end

    local function pausePlayerAnimations()
        for _,player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                pcall(function()
                    local character = player.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
                    if not animator then return end
                    for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
                        if not State.AnimationSpeeds[track] then
                            local record = {Speed = track.Speed}
                            State.AnimationSpeeds[track] = record
                            record.Connection = track.Stopped:Connect(function()
                                disconnect(record.Connection)
                                State.AnimationSpeeds[track] = nil
                            end)
                        end
                        track:AdjustSpeed(0)
                    end
                end)
            end
        end
    end

    local function pauseCoins()
        local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
        local coinScript = scripts and scripts:FindFirstChild(CONFIG.CoinScript)
        if not coinScript or type(getconnections) ~= "function" then return false end
        local ok, connections = pcall(getconnections, RunService.PreSimulation)
        if not ok then return false end
        for _,connection in ipairs(connections) do
            pcall(function()
                local callback = connection.Function
                if type(callback) ~= "function" or not connection.Enabled then return end
                local environment = getfenv(callback)
                if environment.script ~= coinScript or debug.info(callback, "n") ~= CONFIG.CoinCallback then return end
                connection:Disable()
                table.insert(State.CoinConnections, {Connection = connection, Callback = callback})
            end)
        end
        if #State.CoinConnections == 0 then return false end
        -- UpdateCoins(0) сохраняет удаление и затухание собранных монет,
        -- но не меняет их CFrame: вращение и взлёт полностью остановлены.
        State.CoinTick = RunService.PreSimulation:Connect(function()
            for _,record in ipairs(State.CoinConnections) do pcall(record.Callback, 0) end
        end)
        return true
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 4: ПЕРЕКЛЮЧАТЕЛИ И FPS BOOST
    -- ══════════════════════════════════════════════════════════════════════════
    function Module.Set(key, enabled)
        if State.Unloaded then return false end
        enabled = enabled == true
        if State.Enabled[key] == enabled then setControl(key, enabled); return true end
        if enabled and key == "FPSUnlocker" then
            if type(getfpscap) ~= "function" or type(setfpscap) ~= "function" then
                notify("Executor не поддерживает чтение и восстановление лимита FPS")
                setControl(key, false)
                return false
            end
            local ok, cap = pcall(getfpscap)
            if not ok or type(cap) ~= "number" or not pcall(setfpscap, CONFIG.FPSCap) then
                notify("Не удалось изменить лимит FPS")
                setControl(key, false)
                return false
            end
            State.FPSCap = cap
        elseif enabled and key == "NoRender" then
            local ok = pcall(function() RunService:Set3dRenderingEnabled(false) end)
            if not ok then notify("No Render недоступен"); setControl(key, false); return false end
        elseif enabled and key == "StopAnimations" then
            if not pauseCoins() then
                restoreAnimations()
                notify("Не найден доступный UpdateCoins; Stop Animations не включён")
                setControl(key, false)
                return false
            end
            pausePlayerAnimations()
            local elapsed = 0
            State.AnimationConnection = RunService.Heartbeat:Connect(function(dt)
                elapsed += dt
                if elapsed < CONFIG.AnimationInterval then return end
                elapsed = 0
                pausePlayerAnimations()
            end)
        end
        State.Enabled[key] = enabled
        if not enabled then
            if key == "NoRender" then pcall(function() RunService:Set3dRenderingEnabled(true) end) end
            if key == "StopAnimations" then restoreAnimations() end
            if key == "FPSUnlocker" and State.FPSCap then pcall(setfpscap, State.FPSCap); State.FPSCap = nil end
            restoreProperties(key)
        elseif key == "AntiGlare" then
            -- Anti-Glare 100% в Pulse: яркость ×0.2, оба ambient-цвета чёрные.
            forceProperty(key, Lighting, "Brightness", function(value) return value * CONFIG.AntiGlare.BrightnessScale end)
            forceProperty(key, Lighting, "Ambient", CONFIG.AntiGlare.Ambient)
            forceProperty(key, Lighting, "OutdoorAmbient", CONFIG.AntiGlare.Ambient)
        elseif key == "NoShadows" then
            forceProperty(key, Lighting, "GlobalShadows", false)
            scan(key)
        elseif key == "RemoveReflections" then
            forceProperty(key, Lighting, "EnvironmentSpecularScale", 0)
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then forceProperty(key, terrain, "WaterReflectance", 0) end
            scan(key)
        elseif key == "LowQuality" then
            pcall(function() forceProperty(key, settings().Rendering, "QualityLevel", Enum.QualityLevel.Level01) end)
            pcall(function() forceProperty(key, UserSettings():GetService("UserGameSettings"), "SavedQualityLevel", Enum.SavedQualitySetting.QualityLevel1) end)
            if not State.Records[key] or not next(State.Records[key]) then
                State.Enabled[key] = false
                notify("Изменение качества недоступно")
            end
        elseif key == "RemoveTextures" or key == "RemoveParticles" or key == "PlasticMaterials" then
            scan(key)
        end
        setControl(key, State.Enabled[key] == true)
        return State.Enabled[key] == enabled
    end

    function Module.Boost()
        -- No Render включаем последним: остальные контролы успевают обновиться.
        for _,option in ipairs(CONFIG.Options) do
            if option.Key ~= "NoRender" then Module.Set(option.Key, true) end
        end
        Module.Set("NoRender", true)
    end

    function Module.BuildSection(tab)
        tab:CreateSection("OPTIMIZATION", "right")
        for _,option in ipairs(CONFIG.Options) do
            tab:CreateToggle(option.Label, option.Hint, option.Flag or ("Optimize" .. option.Key), false)
        end
        tab:CreateButton("FPS Boost", "Enable all optimizations + plastic materials", env.CONFIG.Colors.Accent, "FPSBoost")
    end

    for _,option in ipairs(CONFIG.Options) do
        State.Enabled[option.Key] = false
        Module.Handlers[option.Flag or ("Optimize" .. option.Key)] = function(on) return Module.Set(option.Key, on) end
    end
    Module.Handlers.FPSBoost = Module.Boost

    local function onAdded(object)
        if State.Unloaded then return end
        for key,on in pairs(State.Enabled) do if on then applyObject(key, object) end end
    end
    table.insert(State.Connections, Workspace.DescendantAdded:Connect(onAdded))
    table.insert(State.Connections, Lighting.ChildAdded:Connect(onAdded))

    function Module.Destroy()
        if State.Unloaded then return end
        for _,option in ipairs(CONFIG.Options) do Module.Set(option.Key, false) end
        State.Unloaded = true
        restoreAnimations()
        for _,connection in ipairs(State.Connections) do disconnect(connection) end
        table.clear(State.Connections)
        if shared.MM2_OptimizationModule == Module then shared.MM2_OptimizationModule = nil end
    end
    shared.MM2_OptimizationModule = Module
    return Module
end
