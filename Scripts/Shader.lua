
    local Lighting = game:GetService("Lighting")
    local ContentProvider = game:GetService("ContentProvider")

    -- Очистка старых эффектов
    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") or effect:IsA("Sky") or effect:IsA("Atmosphere") then
            effect:Destroy()
        end
    end

    wait(0.1)

    -- === ОСВЕЩЕНИЕ — молочно-розовый рассвет ===
    Lighting.Technology = Enum.Technology.Future
    Lighting.GlobalShadows = true
    Lighting.ShadowSoftness = 0.55             -- тени как вата
    Lighting.Ambient = Color3.fromRGB(255, 220, 235)       -- розовое молоко
    Lighting.OutdoorAmbient = Color3.fromRGB(255, 210, 230) -- персиково-розовый
    Lighting.ColorShift_Top = Color3.fromRGB(255, 235, 245)  -- белёсо-розовый верх
    Lighting.ColorShift_Bottom = Color3.fromRGB(230, 195, 220) -- пудровый низ
    Lighting.Brightness = 1.2                  -- светло и воздушно
    Lighting.ExposureCompensation = 0.1        -- overexposed как плёнка lomography
    Lighting.EnvironmentDiffuseScale = 1.0
    Lighting.EnvironmentSpecularScale = 0.9    -- мало бликов — матовость

    -- === BLOOM — лёгкое свечение ===
    local bloom = Instance.new("BloomEffect")
    bloom.Name = "Bloom"
    bloom.Intensity = 0.3        -- деликатно
    bloom.Size = 18              -- компактное
    bloom.Threshold = 1.1        -- светится только яркое
    bloom.Enabled = true
    bloom.Parent = Lighting

    -- === COLOR CORRECTION — синнаморолл палитра ===
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "ColorCorrection"
    cc.Brightness = 0.08          -- чуть засвечено
    cc.Contrast = -0.05           -- мягкий контраст, без резкости
    cc.Saturation = -0.15         -- пастельность — убираем насыщенность
    cc.TintColor = Color3.fromRGB(255, 240, 248)  -- белый с розовым дыханием
    cc.Enabled = true
    cc.Parent = Lighting

    -- === SUN RAYS — лучи как сквозь тюль ===
    local sunRays = Instance.new("SunRaysEffect")
    sunRays.Name = "SunRays"
    sunRays.Intensity = 0.04      -- едва заметны
    sunRays.Spread = 1.0
    sunRays.Enabled = true
    sunRays.Parent = Lighting

    -- === ATMOSPHERE — сахарная вата в воздухе ===
    local atmo = Instance.new("Atmosphere")
    atmo.Name = "Atmosphere"
    atmo.Density = 0.2           -- густая нежная дымка
    atmo.Offset = 0.1
    atmo.Color = Color3.fromRGB(255, 220, 235)   -- розовый туман
    atmo.Decay = Color3.fromRGB(255, 200, 220)   -- персиковое затухание
    atmo.Glare = 0.0
    atmo.Haze = 1.5               -- максимальная мечтательность
    atmo.Parent = Lighting

    -- === BLUR — почти незаметный ===
    local blur = Instance.new("BlurEffect")
    blur.Name = "Blur"
    blur.Size = 0.3              -- едва есть
    blur.Enabled = true
    blur.Parent = Lighting

    -- === DEPTH OF FIELD — мягче ===
    local dof = Instance.new("DepthOfFieldEffect")
    dof.Name = "DepthOfField"
    dof.FarIntensity = 0.2       -- дальний план чуть тает
    dof.NearIntensity = 0.0      -- ближний чёткий
    dof.FocusDistance = 30
    dof.InFocusRadius = 35       -- широкая зона фокуса
    dof.Enabled = true
    dof.Parent = Lighting

    -- === НЕБО ===
    local skyboxAssets = {
        Bk = "rbxassetid://271042516",
        Dn = "rbxassetid://271077243",
        Ft = "rbxassetid://271042556",
        Lf = "rbxassetid://271042310",
        Rt = "rbxassetid://271042467",
        Up = "rbxassetid://271077958"
    }

    local assetsToPreload = {}
    for _, id in pairs(skyboxAssets) do
        table.insert(assetsToPreload, id)
    end
    ContentProvider:PreloadAsync(assetsToPreload)
    wait(0.5)

    local sky = Instance.new("Sky")
    sky.Name = "CinnamorollSky"
    sky.SkyboxBk = skyboxAssets.Bk
    sky.SkyboxDn = skyboxAssets.Dn
    sky.SkyboxFt = skyboxAssets.Ft
    sky.SkyboxLf = skyboxAssets.Lf
    sky.SkyboxRt = skyboxAssets.Rt
    sky.SkyboxUp = skyboxAssets.Up
    sky.MoonAngularSize = 22       -- большая мягкая луна
    sky.SunAngularSize = 0
    sky.StarCount = 1500           -- мало звёзд — небо как молоко
    sky.CelestialBodiesShown = true
    sky.Parent = Lighting

    -- === SAKURA PETALS — лепестки сакуры за камерой ===
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")

    -- Idempotency: удаляем старый эмиттер и connection, если скрипт перезапускается
    local oldEmitter = Workspace:FindFirstChild("CinnamorollSakuraEmitter")
    if oldEmitter then oldEmitter:Destroy() end
    if _G.CinnamorollSakuraConn then
        pcall(function() _G.CinnamorollSakuraConn:Disconnect() end)
        _G.CinnamorollSakuraConn = nil
    end

    local emitterPart = Instance.new("Part")
    emitterPart.Name = "CinnamorollSakuraEmitter"
    emitterPart.Size = Vector3.new(80, 1, 80)
    emitterPart.Transparency = 1
    emitterPart.CanCollide = false
    emitterPart.CanQuery = false
    emitterPart.CanTouch = false
    emitterPart.Anchored = true
    emitterPart.TopSurface = Enum.SurfaceType.Smooth
    emitterPart.BottomSurface = Enum.SurfaceType.Smooth
    emitterPart.Parent = Workspace

    local petal = Instance.new("ParticleEmitter")
    petal.Name = "SakuraPetal"
    petal.Texture = "rbxasset://textures/particles/smoke_main.dds"
    petal.Lifetime = NumberRange.new(6, 10)
    petal.Rate = 12
    petal.Speed = NumberRange.new(0.5, 1.5)
    petal.SpreadAngle = Vector2.new(40, 60)
    petal.Rotation = NumberRange.new(0, 360)
    petal.RotSpeed = NumberRange.new(-60, 60)
    petal.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(0.5, 0.8),
        NumberSequenceKeypoint.new(1, 0.6),
    })
    petal.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.15, 0.4),
        NumberSequenceKeypoint.new(0.85, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    petal.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 220)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 235)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 195, 215)),
    })
    petal.LightEmission = 0.3
    petal.LightInfluence = 0.3
    petal.Acceleration = Vector3.new(0.3, -1, 0.3)
    petal.EmissionDirection = Enum.NormalId.Bottom
    petal.Enabled = true
    petal.Parent = emitterPart

    -- Эмиттер летит за камерой: облако партиклов всегда над/вокруг игрока
    _G.CinnamorollSakuraConn = RunService.RenderStepped:Connect(function()
        local camera = Workspace.CurrentCamera
        if camera and emitterPart.Parent then
            emitterPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 10, 0))
        end
    end)

    print("🌸 Cinnamoroll визуалы применены — нежнее некуда")