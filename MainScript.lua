-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 1: INITIALIZATION & PROTECTION
-- ══════════════════════════════════════════════════════════════════════════════

-- PlaceId проверка (если нужна)
--if game.PlaceId ~= 142823291 then return end

if not game:IsLoaded() then game.Loaded:Wait() end

local Core = (function()
    local sharedOk, shared = pcall(function() return getgenv() end)
    assert(sharedOk and shared, "Executor environment unavailable")
    if shared.MM2_Script then warn("Already running!"); return nil end
    local runtime = {Alive = true, Closing = false, Connections = {}, Threads = {}, Properties = {}, Errors = {}, Aimbot = {}, Movement = {}}
    shared.MM2_Script = true
    shared.MM2_Runtime = runtime

    function runtime.Try(name, callback)
        if type(callback) ~= "function" then return end
        local ok, err = pcall(callback)
        if not ok then
            table.insert(runtime.Errors, name .. ": " .. tostring(err))
            warn("[Violite cleanup] " .. name .. ": " .. tostring(err))
        end
    end

    function runtime.Track(connection)
        if not connection then return connection end
        if not runtime.Alive then pcall(function() connection:Disconnect() end); return connection end
        runtime.Connections[connection] = true
        return connection
    end

    function runtime.Connect(signal, callback)
        return runtime.Track(signal:Connect(function(...)
            if not runtime.Alive then return end
            local thread = coroutine.running()
            runtime.Threads[thread] = true
            local ok, err = pcall(callback, ...)
            runtime.Threads[thread] = nil
            if not ok then warn("[Violite callback] " .. tostring(err)) end
        end))
    end

    runtime.Tweens = {}
    function runtime.Tween(object, info, properties)
        local tween = runtime.TweenService:Create(object, info, properties)
        runtime.Tweens[tween] = true
        local connection
        connection = runtime.Connect(tween.Completed, function()
            runtime.Tweens[tween] = nil
            connection:Disconnect()
            runtime.Connections[connection] = nil
        end)
        return tween
    end
    runtime.Objects = {}
    function runtime.Own(object)
        runtime.Objects[object] = true
        local connection
        connection = runtime.Connect(object.Destroying, function()
            runtime.Objects[object] = nil
            if connection then connection:Disconnect(); runtime.Connections[connection] = nil end
        end)
        return object
    end
    function runtime.New(class, properties, parent)
        local object = runtime.Own(Instance.new(class))
        for key, value in pairs(properties or {}) do object[key] = value end
        if parent then object.Parent = parent end
        return object
    end

    runtime.Tasks = {}
    local function schedule(method, delaySeconds, callback, ...)
        if not runtime.Alive then return nil end
        local args = table.pack(...)
        local thread = coroutine.create(function()
            if not runtime.Alive then return end
            local ok, err = pcall(callback, table.unpack(args, 1, args.n))
            runtime.Threads[coroutine.running()] = nil
            if not ok then warn("[Violite task] " .. tostring(err)) end
        end)
        runtime.Threads[thread] = true
        if method == "delay" then task.delay(delaySeconds, thread) else task[method](thread) end
        return thread
    end
    function runtime.Tasks.spawn(callback, ...) return schedule("spawn", nil, callback, ...) end
    function runtime.Tasks.defer(callback, ...) return schedule("defer", nil, callback, ...) end
    function runtime.Tasks.delay(seconds, callback, ...) return schedule("delay", seconds, callback, ...) end
    runtime.Tasks.wait = task.wait
    function runtime.Tasks.cancel(thread)
        runtime.Threads[thread] = nil
        pcall(task.cancel, thread)
    end

    function runtime.Remember(object, property)
        local props = runtime.Properties[object]
        if props and props[property] ~= nil then return end
        local ok, value = pcall(function() return object[property] end)
        if not ok then return end
        if not props then props = {}; runtime.Properties[object] = props end
        props[property] = value
    end
    function runtime.RestoreProperties()
        for object, props in pairs(runtime.Properties) do
            for property, value in pairs(props) do pcall(function() object[property] = value end) end
        end
        table.clear(runtime.Properties)
    end
    function runtime.Shutdown()
        if runtime.Closing then return end
        runtime.Closing = true
        runtime.Alive = false
        -- Сначала восстановление позиции и Stop, затем отмена ожидающих callbacks.
        runtime.Try("Systems", runtime.Cleanup)
        runtime.Try("GUI", runtime.CleanupGUI)
        for connection in pairs(runtime.Connections) do pcall(function() connection:Disconnect() end) end
        table.clear(runtime.Connections)
        for thread in pairs(runtime.Threads) do
            if thread ~= coroutine.running() then pcall(task.cancel, thread) end
        end
        table.clear(runtime.Threads)
        for tween in pairs(runtime.Tweens) do pcall(function() tween:Cancel(); tween:Destroy() end) end
        table.clear(runtime.Tweens)
        runtime.RestoreProperties()
        for object in pairs(runtime.Objects) do pcall(function() object:Destroy() end) end
        table.clear(runtime.Objects)
        if shared.MM2_Runtime == runtime then
            shared.MM2_Script = nil
            shared.MM2_Runtime = nil
        end
    end
    -- Не держим завершённые ресурсы до закрытия окна при длительном фарме.
    runtime.Tasks.spawn(function()
        while runtime.Alive do
            task.wait(30)
            for connection in pairs(runtime.Connections) do
                if not connection.Connected then runtime.Connections[connection] = nil end
            end
            for thread in pairs(runtime.Threads) do
                if coroutine.status(thread) == "dead" then runtime.Threads[thread] = nil end
            end
        end
    end)
    return runtime
end)()
if not Core then return end

local startupOk, startupError = xpcall(function()
-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 2: CONFIG & SERVICES
-- ══════════════════════════════════════════════════════════════════════════════

local CONFIG = {
        Modules = {
            Visuals = "https://raw.githubusercontent.com/Yany1944/rbxmain/main/Libraryes/Visuals.lua",
            Optimization = "https://raw.githubusercontent.com/Yany1944/rbxmain/main/Libraryes/Optimization.lua",
            Movement = "https://raw.githubusercontent.com/Yany1944/rbxmain/main/Libraryes/Movement.lua",
        },
        HideKey = Enum.KeyCode.Insert,
        Colors = {
        Background = Color3.fromRGB(25, 25, 30),
        Section = Color3.fromRGB(35, 35, 40),
		Text = Color3.fromRGB(220, 220, 220),
        TextDark = Color3.fromRGB(150, 150, 150),
	--  Accent = Color3.fromRGB(90, 140, 255),
        Accent = Color3.fromRGB(220, 145, 230),
        Red = Color3.fromRGB(255, 85, 85),
        KeybindClear = Color3.fromRGB(80, 40, 40),
        Green = Color3.fromRGB(85, 255, 120),
        Orange = Color3.fromRGB(255, 170, 50),
        Stroke = Color3.fromRGB(50, 50, 55),
        Murder = Color3.fromRGB(255, 50, 50),
        Sheriff = Color3.fromRGB(50, 150, 255),
        Gun = Color3.fromRGB(255, 200, 50),
        Innocent = Color3.fromRGB(85, 255, 120),
        Tracers  = Color3.fromRGB(220, 145, 230),
        CoinTracer = Color3.fromRGB(255, 105, 180),
        FriendTracerNear = Color3.fromRGB(0, 255, 0),
        FriendTracerFar  = Color3.fromRGB(255, 0, 0),
        },
        -- Тосты в стиле основного GUI (токены Vercel Geist, как в Libraryes/GUI.lua)
        Notification = {
            Duration = 3,             -- сек до закрытия (повтор того же текста перезапускает)
            FadeTime = 0.22,          -- уход и схлопывание стопки
            EnterTime = 0.28,
            MaxVisible = 4,
            TopOffset = 100,          -- ниже верхней панели Roblox и таймера раунда MM2
            Gap = 8,
            SlideOffset = 10,
            MinWidth = 240, MaxWidth = 440,  -- ширина по тексту
            MinHeight = 44,
            PaddingX = 14, PaddingY = 11,
            IconSize = 16, IconGap = 10,
            TextSize = 15,
            Radius = 10,
            ProgressHeight = 2,
            ProgressTransparency = 0.35,
            -- Фон как у окна меню: цвет полотна и его прозрачность (без размытия).
            -- Тема GUI обновляет оба поля
            Background = Color3.fromRGB(0, 0, 0),      -- background-200 (полотно окна)
            BackgroundTransparency = 0.12,
            Border = Color3.fromRGB(46, 46, 46),        -- gray-400
            Text = Color3.fromRGB(237, 237, 237),       -- gray-1000
            TextDark = Color3.fromRGB(143, 143, 143),   -- gray-700
            Kinds = {
                Success = {Icon = "check-circle-fill", Color = Color3.fromRGB(98, 193, 116)},   -- green-900
                Error   = {Icon = "cross-circle-fill", Color = Color3.fromRGB(255, 97, 102)},   -- red-900
                Warning = {Icon = "warning-fill",      Color = Color3.fromRGB(255, 153, 10)},   -- amber-800
                Off     = {Icon = "stop-circle",       Color = Color3.fromRGB(143, 143, 143)},
                Info    = {Icon = "information-fill",  Color = Color3.fromRGB(82, 173, 250)},   -- blue-900
            },
            -- Светлые темы GUI: цветной текст и иконки темнее, чтобы на белом держать ≥ 4.5:1
            LightRichPalette = {
                ["255,85,85"]   = Color3.fromRGB(206, 34, 40),
                ["168,228,160"] = Color3.fromRGB(21, 128, 61),
                ["85,255,120"]  = Color3.fromRGB(21, 128, 61),
                ["255,165,0"]   = Color3.fromRGB(180, 83, 9),
                ["255,170,50"]  = Color3.fromRGB(180, 83, 9),
                ["255,200,50"]  = Color3.fromRGB(161, 98, 7),
                ["85,255,255"]  = Color3.fromRGB(29, 78, 216),
                ["50,150,255"]  = Color3.fromRGB(29, 78, 216),
            },
            LightKindColors = {
                Success = Color3.fromRGB(21, 128, 61), Error = Color3.fromRGB(206, 34, 40),
                Warning = Color3.fromRGB(180, 83, 9), Off = Color3.fromRGB(102, 102, 102),
                Info = Color3.fromRGB(29, 78, 216),
            },
            -- Цвета, которыми размечен текст в вызовах, → палитра Geist
            RichPalette = {
                ["220,220,220"] = Color3.fromRGB(237, 237, 237),
                ["255,85,85"]   = Color3.fromRGB(255, 97, 102),
                ["168,228,160"] = Color3.fromRGB(98, 193, 116),
                ["85,255,120"]  = Color3.fromRGB(98, 193, 116),
                ["255,165,0"]   = Color3.fromRGB(255, 153, 10),
                ["255,170,50"]  = Color3.fromRGB(255, 153, 10),
                ["255,200,50"]  = Color3.fromRGB(255, 196, 64),
                ["85,255,255"]  = Color3.fromRGB(82, 173, 250),
                ["50,150,255"]  = Color3.fromRGB(82, 173, 250),
            },
        },
        -- Подбор выпавшего гана. Сервер засчитывает касание только через TouchInterest,
        -- а он реплицируется на кадр позже самого GunDrop (замер: +3…8 мс). Касание до
        -- него уходит впустую — прежняя версия брала ган лишь второй попыткой:
        -- ~0.41 с против ~0.15 с (≈ один пинг) при старте от TouchInterest
        GunPickup = {
            TouchWait     = 1,      -- сек ждём появления TouchInterest у дропа
            RetryInterval = 0.05,   -- пауза между повторными касаниями
            Timeout       = 2,      -- сек до отказа, если сервер не выдаёт ган
        },
        -- Настройки Server Hop / Rejoin. Всё, что можно крутить, — только здесь.
        ServerHop = {
            VisitedFile      = "VioCFG/Violite/serverhop_visited.json", -- {jobId = os.time()}
            CacheFile        = "VioCFG/Violite/serverhop_cache.json",   -- кэш списка серверов
            VisitedLifetime  = 30 * 60,  -- сколько секунд считать сервер «только что посещённым»
            VisitedLimit     = 250,      -- страховка от разрастания файла истории
            CacheLifetime    = 240,      -- сколько секунд переиспользовать список серверов
            MinPlayers       = 1,        -- пустые сервера чаще всего мертвы/приватны
            MaxFillPercent   = 0.9,      -- не лезем в почти полный сервер (телепорт отвалится)
            FetchLimit       = 100,      -- limit= в запросе к games.roblox.com
            MaxPages         = 5,        -- максимум страниц пагинации за один хоп
            TopPick          = 5,        -- из скольких лучших кандидатов тянем случайного
            TeleportRetry    = 3,        -- сколько РАЗНЫХ серверов пробуем при явном отказе
            TeleportTimeout  = 12,       -- сек ожидания вердикта по одному телепорту
        },
        -- Система конфигов (профили настроек). Общая корневая папка обоих
        -- скриптов — VioCFG, у каждого скрипта свой неймспейс внутри.
        Configs = {
            Dir          = "VioCFG/Violite",              -- папка этого скрипта
            Extension    = ".vio",                        -- содержимое — JSON
            IndexFile    = "VioCFG/Violite/index.json",   -- запасной список имён (listfiles есть не везде)
            Script       = "violite",                     -- метка принадлежности в файле
            Version      = 1,                             -- версия схемы файла
        },
        -- Desync (вкладка Combat). Подмена реплицируемого CFrame/скорости корня.
        -- Замеры на двух аккаунтах в MM2: Spin и Pitch наблюдатель видит точно.
        -- Chaos: случайные линейная и угловая скорости, CFrame не пишется (запись CFrame
        -- гасит у наблюдателей экстраполяцию) — образ скачет (1500 studs/s → до ~40
        -- studs) и кувыркается. Своя физика всегда идёт по реальному телу (подмена
        -- снимается до симуляции), киллзоны и касания срабатывают по настоящей позиции.
        Desync = {
            Modes   = {"Jitter", "Spin", "Chaos"},
            Pitches = {Straight = 0, Up = 89, Down = -89},   -- градусы наклона корпуса
            PitchOrder = {"Straight", "Up", "Down"},
            SpinSpeed     = {90, 2000},    -- град/с
            Radius        = {0, 10},       -- studs смещения; он же сила Chaos
            ChaosPerStud  = 500,           -- studs/s случайной скорости Chaos на 1 stud радиуса
                                           -- (10 → 5000; 0 — только кувыркание)
            ChaosAngular  = 200,           -- рад/с случайной угловой скорости (кувыркание)
            -- Замер в раунде: через некоторое время (респаун, старт раунда, перезаход
            -- наблюдателя) наблюдатели перестают экстраполировать по нашей скорости —
            -- Chaos превращается в дрожь, хотя скорости до них доходят. Переключение
            -- на Jitter на ~0.25 с это оживляет — делаем его сами раз в интервал.
            -- Гибрид (CFrame-хаос через кадр + скорости) держал эффект стабильнее, но
            -- у игрока в раунде выбрасывал персонажа — отказались
            RefreshInterval  = 2.5,        -- сек между всплесками
            RefreshBurst     = 0.35,       -- сек длительность всплеска
            RefreshAmplitude = 3,          -- studs сдвига вбок (±, через кадр)
            -- Чамсы Chaos: сколько секунд наблюдатель дорисовывает нас по поддельной
            -- скорости (замер: 1500 studs/s → скачки до ~40 studs ≈ 1/40 с)
            ChaosChamsLead   = 1 / 40,
        },
        -- Fake Lag: удержание отправляемой позиции, отдельно от Desync.
        -- Длина каждого удержания — случайная между Min и Max Delay, разброс задаёт
        -- Randomization (0 — всегда Max, ровный паттерн; 10 — равномерно Min..Max)
        FakeLag = {
            MinDelay      = {0, 300},      -- мс
            MaxDelay      = {50, 300},    -- мс
            Randomization = {0, 10},       -- 0..10 → 0..100% разброса
            MaxDistance   = 12,            -- studs: дальше удержание сбрасываем (телепорт и т.п.)
        },
        -- Передвижение (вкладка Main). Speed и Fly двигают CFrame по MoveDirection:
        -- WalkSpeed/PlatformStand не меняются, наружу уходит обычная ходьба
        -- Toggle: бинд включает/выключает; Hold: работает, пока зажат; Always: всегда
        BindModes = {"Toggle", "Hold", "Always"},
        Speed = {
            Range = {0, 20},       -- studs/s сверх обычной ходьбы; 0 — без изменения
            Step  = 0.5,
        },
        Fly = {
            Modes = {"Fly", "Vehicle Fly", "Swim"},
            HoverVelocity = Vector3.new(0, math.pi - 2, 0),   -- подпор против гравитации (как в исходнике)
        },
        -- Aspect Ratio («растянутое разрешение»): после обновления камеры её CFrame
        -- домножается на сжатие по вертикали. 1 — как есть
        AspectRatio = {
            Range = {0.1, 1.2},
            Step  = 0.01,
            TweenRate = 20,        -- 1/с, плавность смены (≈0.15 с до цели)
            BindName = "Violite_AspectRatio",
        },
        -- Выстрел шерифа (Shoot Murderer / Wallbang / Auto Fire / Resolver).
        -- Замеры на двух аккаунтах (пинг ~235 мс у обоих):
        --   • сервер MM2 бьёт лучом origin→target без лаг-компенсации, засчитывает
        --     первое задетое: части тела И аксессуары; origin почти не проверяет;
        --   • серверный кулдаун ровно 3.0 с от принятого выстрела, ранние выстрелы
        --     молча отбрасываются и кулдаун не сбрасывают;
        --   • видимая позиция убийцы отстаёт от истины на ~0.39 с, MoveDirection —
        --     только на ~0.23 с (свойство идёт без буфера интерполяции физики);
        --   • сервер держит убийцу на ~0.10 с позади истины → упреждение от видимой
        --     позиции = пинг шерифа + ~0.055 с (подтверждено попаданиями).
        SheriffAim = {
            ServerLead     = 0.055,  -- сек сверх пинга до обработки выстрела сервером
            -- сек, на сколько MoveDirection опережает видимую позицию (замер 0.14–0.18,
            -- плавает с сетью): кандидаты, лучший выбирает самопроверка
            IntentLeads    = {0.08, 0.11, 0.14, 0.17, 0.20, 0.23},
            IntentLeadDefault = 3,   -- индекс стартового кандидата (0.14)
            MaxLead        = 0.6,    -- сек: выше пинг — предикт не тянем дальше
            Response       = 60,     -- 1/с, отклик скорости на смену ввода на земле (почти мгновенно)
            AirAccel       = 140,    -- studs/s²: в воздухе скорость меняется с постоянным ускорением
            SimStep        = 1 / 60,
            History        = 1.6,    -- сек истории наблюдений за целью
            ServerCooldown = 3.0,    -- сек, серверный кулдаун пистолета
            CooldownMargin = 0.06,   -- сек запаса, чтобы не стрелять в ещё идущий кулдаун
            ConfirmExtra   = 0.45,   -- сек сверх пинга ждём трассер своего выстрела
            PartMargin     = 0.12,   -- studs: хитбоксы сжимаем — край тела не считаем попаданием
            -- Auto Fire: стреляет, как только луч от точки вылета до точки упреждения чист
            MinTrackTime   = 0.45,   -- сек наблюдения за целью до первого автовыстрела
            AutoInterval   = 1 / 30, -- сек между оценками Auto Fire
            -- Смены ввода цели: средняя длина «отрезка» постоянного ввода по её истории,
            -- с априором (PriorSegments отрезков по PriorDuration с)
            PriorSegments  = 2,
            PriorDuration  = 0.9,
            SegmentAngle   = 25,     -- градусов: поворот ввода больше этого — новый отрезок
            ChangeSplit    = {Stop = 0.35, Reverse = 0.25, Left = 0.2, Right = 0.2},
            JumpRatePrior  = 0.25,   -- прыжков/с у цели до набора своей статистики
            InnocentRadius = 2.5,    -- studs: чужой игрок ближе к лучу — не стреляем (убьём невиновного)
            -- Самопроверка предикта на текущей цели (см. selfCheck). Ошибка входит в
            -- шанс как разброс поперёк луча (см. chanceFor), а не множителем: множитель
            -- при p80 = 0.86 studs резал любой шанс до 81% и Auto Fire молчал целый раунд,
            -- хотя с такой ошибкой выстрел в корпус попадает. От BadError — не стреляем
            SelfCheck = {
                Interval   = 0.1,    -- сек между контрольными предсказаниями
                Window     = 4,      -- сек памяти ошибок
                MinSamples = 4,
                Percentile = 0.8,
                GoodError  = 0.6,    -- studs: ниже — ошибку не учитываем
                BadError   = 2.0,    -- studs: выше — модель на этой цели не доверяем
                -- p80 поперечной ошибки ≈ 1.8σ; разброс — точки ±σ, ±2σ с весами нормали
                BlurOffsets = {0, 1, -1, 2, -2},
                BlurWeights = {0.40, 0.24, 0.24, 0.06, 0.06},
                KAlpha     = 0.05,   -- сглаживание ошибки кандидатов K
                KMinSamples = 15,    -- проверок до первого переключения K
            },
            -- Resolver: заявленная скорость против скорости по смещению позиции за окно.
            -- Честный игрок (замер с прыжками и стенами, окно 0.3 с): расхождение не
            -- выше 4.0 по горизонтали и 9.7 по вертикали; Anti-Aim даёт ~100 по вертикали
            Resolver = {
                Window        = 0.3,   -- сек окна сравнения
                VertMismatch  = 20,    -- studs/s
                HorizMismatch = 5,     -- studs/s, либо доля скорости ниже
                HorizRatio    = 0.25,
                Engage        = 0.6,   -- доля подозрительных кадров за последнюю секунду
                EngageTime    = 0.5,   -- сек подряд выше доли — включаем резолв
                Release       = 1.5,   -- сек без подозрений — выключаем
                TeleportSpeed = 150,   -- studs/s: быстрее — телепорт, окно сбрасываем
            },
        },
	}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
Core.TweenService = TweenService
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
Core.StarterGui = game:GetService("StarterGui")
Core.PhysicsService = game:GetService("PhysicsService")
local LocalPlayer = Players.LocalPlayer
-- Стандартная скорость плейса (обычно 16) — ориентир для Velocity Spoofer Zero.
CONFIG.DefaultWalkSpeed = 16
pcall(function() CONFIG.DefaultWalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed end)
Core.Remember(LocalPlayer, "CameraMaxZoomDistance")
Core.Remember(LocalPlayer, "DevCameraOcclusionMode")
if Workspace.CurrentCamera then Core.Remember(Workspace.CurrentCamera, "FieldOfView") end
Core.Track(Core.Connect(LocalPlayer.CharacterAdded, function(character)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if humanoid then
        Core.Remember(humanoid, "WalkSpeed")
        Core.Remember(humanoid, "JumpPower")
    end
end))
if LocalPlayer.Character then
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        Core.Remember(humanoid, "WalkSpeed")
        Core.Remember(humanoid, "JumpPower")
    end
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 3: STATE MANAGEMENT
-- ══════════════════════════════════════════════════════════════════════════════

local State = {
    Settings = {
        UIOnlyEnabled = false,
        CoinMuterEnabled = false,
    Keybinds = {
        Sit = Enum.KeyCode.Unknown,
        Dab = Enum.KeyCode.Unknown,
        Zen = Enum.KeyCode.Unknown,
        Ninja = Enum.KeyCode.Unknown,
        Floss = Enum.KeyCode.Unknown,
        ClickTP = Enum.KeyCode.Unknown,
        FlingPlayer = Enum.KeyCode.Unknown,
        knifeThrow = Enum.KeyCode.Unknown,
        NoClip = Enum.KeyCode.Unknown,
        ShootMurderer = Enum.KeyCode.Unknown,   -- Silent
        Wallbang = Enum.KeyCode.Unknown,        -- Magic
        PickupGun = Enum.KeyCode.Unknown,
        InstantKillAll = Enum.KeyCode.Unknown,
        Fly = Enum.KeyCode.Unknown,
        Speed = Enum.KeyCode.Unknown,
        Invisibility = Enum.KeyCode.Unknown,
        KillAura = Enum.KeyCode.Unknown,
    },
        GunESP = false,
        MurderESP = false,
        SheriffESP = false,
        InnocentESP = false,
        NotificationsEnabled = false,
        AvatarDisplayEnabled = false,
        JumpPower = 50,
        MaxCameraZoom = 15,
        CameraFOV = 70,
        ViewClipEnabled = false,
        AspectRatioEnabled = false,
        AspectRatioValue = 0.75,
        SpeedEnabled = false,       -- включён биндом в режиме Toggle
        SpeedValue = 6,             -- studs/s сверх ходьбы
        SpeedBindMode = "Hold",
        FlyToggleOn = false,        -- включён биндом в режиме Toggle
        FlyEnabled = false,         -- Fly реально работает (по режиму бинда)
        FlyType = "Fly",
        FlySpeed = 40,
        FlyBindMode = "Toggle",
        ExtendedHitboxSize = 15,
        ExtendedHitboxEnabled = false,
        VelocitySpoofEnabled = false,
        VelocitySpoofMode = "Anti-Aim",
        VelocitySpoofMurdererOnly = true,
        VelocitySpoofStrength = 150,
        VelocitySpoofSpeed = CONFIG.DefaultWalkSpeed,
        KillAuraRange = 7,
        KillAuraEnabled = false,
        KillAuraStatic = false,
        FakePositionEnabled = false,
        FakePositionMode = "Jitter",
        FakePositionRadius = 3,
        FakePositionPitch = "Straight",
        FakeSpinSpeed = 720,
        FakeSpinLocal = false,
        FakeLagEnabled = false,
        FakeLagMinDelay = 80,
        FakeLagMaxDelay = 200,
        FakeLagRandomization = 3,
        SpawnAtPlayer = false,
        CanShootMurderer = true,
        ShootCooldown = 3,
        ShootLead = 0.09,   -- упреждение сверх пинга для броска ножа; у выстрела — CONFIG.SheriffAim
        AutoFireEnabled = false,
        ResolverEnabled = false,
        AutoFarmEnabled = false,
        CoinFarmFlySpeed = 22,
        CoinFarmDelay = 2,
        UndergroundMode = false,
        UndergroundOffset = 2.5,
        IsInvisible = false,
        AutoLoadOnTeleport = true,
        AutoRejoinEnabled = false,
        AutoReconnectEnabled = false,
        ReconnectInterval = 60 * 60,
        XPFarmEnabled = false,
        AFKModeEnabled = false,
        InstantPickupEnabled = false,
        AntiFlingEnabled = false,
        FlingMethod = "skidfling",
        SkidLead = 0.9,
        FlingGhostVisual = false,
        WalkFlingEnabledByUser = false,
        NoClipEnabled = false,
        PlayerNicknamesESP = false,
        PingChamsEnabled = false,
        PingChamsShowLabel = true,
        PingChamsSampleDesync = false,
        PingChamsDesyncSampleInterval = 1 / 15,
        PingChamsDesyncInterpolation = 0.05,
        BulletTracersEnabled = false,
        FriendViewerEnabled = false,
        FriendViewerThreshold = 25,
        OrbitEnabled = false,
        OrbitRadius = 5,
        OrbitSpeed = 2,
        OrbitHeight = 0,
        OrbitTilt = 0,
        LoopFlingEnabled = false,
        LoopFlingMethod = "skidfling",
        LoopFlingInterval = 5,
        BlockPathEnabled = false,
        BlockPathSpeed = 0.2,
        FakeHeadless = false,
        FakeKorblox = false,
        AntiTrapEnabled = false,
    },
    Cache = {
        CoinBlacklist = {},
        PlayerHighlights = {},
        GunCache = {},
        TrapCache = {},
        PlayerData = {},
        PlayerNicknamesCache = {},
        PingChamsBuffer = {},
        PingChamsPingBuf = {},
        FriendPairCheck = {},
    },
    Runtime = {
        SettingsDirty = false,
        FlyConnection = nil,
        SwimConnection = nil,
        SpeedBindRow = nil,         -- GUI-строки «режим + бинд» (подсветка активности)
        FlyBindRow = nil,
        FakePositionOffset = Vector3.zero,
        CoinFarmThread = nil,
        LastCacheTime = 0,
        CurrentMapConnection = nil,
        CurrentMap = nil,
        PreviousGun = nil,
        ReconnectThread = nil,
        RejoinInProgress = false,
        ServerHopInProgress = false,
        InstantPickupThread = nil,
        GunPickupBusy = false,
        GunPickupTried = nil,
        GunTrackConns = {},
        GunReconcileThread = nil,
        GunTrackingActive = false,
        IsFlingInProgress = false,
        SelectedPlayerForFling = nil,
        SelectedPlayerForTrolling = nil,
        OldPos = nil,
        TrapTrackingConnection = nil,
        WalkFlingActive = false,
        WalkFlingConnection = nil,
        NoClipConnection = nil,
        NoClipRespawnConnection = nil,
        NoClipObjects = nil,
        PreviousMurderer = nil,
        PreviousSheriff = nil,
        HeroSent = false,
        RoundStart = true,
        RoundActive = false,
        PlaceholderImage = "",
        CurrentMurdererUserId = nil,
        CurrentSheriffUserId = nil,
        CurrentGunDrop = nil,
        PingChamsSampleChar = nil,
        PingChamsNextDesyncSample = nil,
        PingChamsRTT = 0.2,
        PingChamsLastPingUpdate = 0,
        PingChamsGhostModel = nil,
        PingChamsGhostPart = nil,
        PingChamsGUI = nil,
        PingChamsGuiAnchor = nil,
        PingChamsGhostClone = nil,
        PingChamsGhostMap = {},
        PingChamsGhostChar = nil,
        PingChamsGhostPartCount = 0,
        PingChamsRenderConn = nil,
        TracersList = {},
        FriendPairs = {},
        FriendBeams = {},
        FriendScanCoroutine = nil,
        FriendPlayerAddedConn = nil,
        FriendPlayerRemovingConn = nil,
        Connections = {},
        UIElements = {},
        RoleCheckLoop = nil,
        FallenPartsDestroyHeight = (function()
        local h = Workspace.FallenPartsDestroyHeight
        return (h == h) and h or -500
    end)(),
        ClickTPActive = false,
        ListeningForKeybind = nil,
        NotificationQueue = {},
        CurrentNotification = nil,
        OrbitThread = nil,
        OrbitAngle = 0,
        LoopFlingThread = nil,
        BlockPathThread = nil,
        BlockPathPosition = 0,
        BlockPathDirection = 1,
    },
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
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Yany1944/rbxmain/refs/heads/main/MainScript.lua", true))()
            end)
            if not success then
                warn("Ошибка автозагрузки:", err)
            end
        end
    ]]
    -- Очередь формируется только для реального перехода с включённой настройкой.
    Core.Connect(LocalPlayer.OnTeleport, function(teleportState)
        if teleportState == Enum.TeleportState.Started and State.Settings.AutoLoadOnTeleport and not TeleportCheck then
            local ok = pcall(queue_on_teleport, teleportScript)
            TeleportCheck = ok
        end
    end)
end

local function TrackConnection(conn)
    return Core.Track(conn)
end

-- ── Общие хелперы файлового хранилища (executor-функций может не быть).
-- Используются ServerHop'ом и системой конфигов. Собраны в одну таблицу:
-- верхний скоуп файла почти упёрся в лимит 200 локалов Luau
local Files = {}

-- Создаёт все папки из пути файла (сегменты до имени файла)
function Files.EnsureFoldersFor(path)
    pcall(function()
        if not (isfolder and makefolder) then return end
        local acc = nil
        local segs = {}
        for seg in string.gmatch(path, "[^/]+") do
            table.insert(segs, seg)
        end
        for i = 1, #segs - 1 do
            acc = acc and (acc .. "/" .. segs[i]) or segs[i]
            if not isfolder(acc) then makefolder(acc) end
        end
    end)
end

function Files.LoadJSON(path, default)
    local ok, data = pcall(function()
        if isfile and isfile(path) then
            return HttpService:JSONDecode(readfile(path))
        end
        return nil
    end)
    if ok and type(data) == "table" then return data end
    return default
end

function Files.SaveJSON(path, data)
    pcall(function()
        if not writefile then return end
        Files.EnsureFoldersFor(path)
        writefile(path, HttpService:JSONEncode(data))
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AIMBOT SYSTEM
-- ══════════════════════════════════════════════════════════════════════════════

do

-- ========================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ АИМБОТА
-- ========================================
local vec2, vec3 = Vector2.new, Vector3.new
local drawNew = Drawing and Drawing.new
local colRgb = Color3.fromRGB

-- ========================================
-- СИСТЕМА ИГРОКОВ ДЛЯ АИМБОТА
-- ========================================
local clientChar = LocalPlayer.Character
local clientMouse = LocalPlayer:GetMouse()
local clientCamera = Workspace.CurrentCamera or Workspace:FindFirstChildOfClass('Camera')
local clientTeam = LocalPlayer.Team

local function DisableAccessoryQueries(character)
    for _, accessory in ipairs(character:GetChildren()) do
        if accessory:IsA("Accessory") or accessory:IsA("Accoutrement") then
            local handle = accessory:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                Core.Remember(handle, "CanQuery")
                handle.CanQuery = false
            end
        end
    end
end

-- Применяем к локальному игроку
if clientChar then
    DisableAccessoryQueries(clientChar)
end

TrackConnection(Core.Connect(LocalPlayer.CharacterAdded, function(char)
    task.wait(1)
    DisableAccessoryQueries(char)
end))


local function GetRootPart(character)
    if not character or not character.Parent then return nil end

    local hrp = character:FindFirstChild('HumanoidRootPart')
    if hrp and hrp:IsA('BasePart') then return hrp end

    local torso = character:FindFirstChild('Torso')
    if torso and torso:IsA('BasePart') then return torso end

    local upperTorso = character:FindFirstChild('UpperTorso')
    if upperTorso and upperTorso:IsA('BasePart') then return upperTorso end

    if character.PrimaryPart and character.PrimaryPart.Parent then
        return character.PrimaryPart
    end

    local head = character:FindFirstChild('Head')
    if head and head:IsA('BasePart') then return head end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA('BasePart') then return child end
    end

    return nil
end

local function updateCharacter()
    clientChar = LocalPlayer.Character

    if not clientChar then
        return
    end

    task.wait(0.5)

    local root = GetRootPart(clientChar)
    local humanoid = clientChar:FindFirstChildOfClass("Humanoid")

    return root, humanoid
end

TrackConnection(Core.Connect(LocalPlayer.CharacterAdded, updateCharacter))
updateCharacter()

TrackConnection(Core.Connect(Workspace:GetPropertyChangedSignal('CurrentCamera'), function()
    clientCamera = Workspace.CurrentCamera or Workspace:FindFirstChildOfClass('Camera')
end))

TrackConnection(Core.Connect(LocalPlayer:GetPropertyChangedSignal('Team'), function()
    clientTeam = LocalPlayer.Team
end))

-- Система менеджеров игроков для аимбота
local playerNames = {}
local playerManagers = {}
local playerCons = {}

local function removePlayer(player)
    local name = player.Name
    if playerCons[name] then
        for _, con in pairs(playerCons[name]) do
            con:Disconnect()
        end
    end

    playerManagers[name] = nil
    playerCons[name] = nil

    local idx = table.find(playerNames, name)
    if idx then table.remove(playerNames, idx) end
end

local function readyPlayer(player)
    local name = player.Name
    if playerManagers[name] then removePlayer(player) end
    local manager = {}
    local cons = {}

    table.insert(playerNames, name)

    cons['chr-add'] = Core.Connect(player.CharacterAdded, function(char)
        task.wait(0.5)

        local success, err = pcall(function()
            if not char or not char.Parent then return end

            manager.Character = char
            manager.RootPart = GetRootPart(char)

            if char and char.Parent then
                manager.Humanoid = char:FindFirstChildOfClass('Humanoid')
            end
        end)

        if not success then
            warn(string.format("Player %s initialization error: %s", name, err))
        end
    end)

    cons['accessories'] = Core.Connect(player.CharacterAdded, function(char)
        task.wait(1)
        if char.Parent then DisableAccessoryQueries(char) end
    end)
    if player.Character then DisableAccessoryQueries(player.Character) end

    cons['chr-rem'] = Core.Connect(player.CharacterRemoving, function()
        manager.Character = nil
        manager.RootPart = nil
        manager.Humanoid = nil
    end)

    cons['team'] = Core.Connect(player:GetPropertyChangedSignal('Team'), function()
        manager.Team = player.Team
    end)

    -- Проверка при инициализации
    if player.Character then
        task.wait(0.5)

        if player.Character and player.Character.Parent then
            manager.Character = player.Character
            manager.RootPart = GetRootPart(player.Character)

            if player.Character and player.Character.Parent then
                manager.Humanoid = player.Character:FindFirstChildOfClass('Humanoid')
            end
        end
    end

    manager.Team = player.Team
    manager.Player = player

    playerManagers[name] = manager
    playerCons[name] = cons
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        readyPlayer(player)
    end
end

TrackConnection(Core.Connect(Players.PlayerAdded, readyPlayer))
TrackConnection(Core.Connect(Players.PlayerRemoving, removePlayer))

-- ========================================
-- КОНФИГУРАЦИЯ АИМБОТА
-- ========================================
State.Settings.AimbotConfig = {
    Enabled = false,

    AliveCheck = true,
    DistanceCheck = false,
    FovCheck = false,
    TeamCheck = false,
    VisibilityCheck = false,

    LockOn = false,
    Prediction = false,
    Deltatime = false,

    Distance = 2000,
    Fov = 50,
    -- Непрозрачность круга FOV (свойство Transparency у Drawing работает
    -- как альфа: 0 — круг не виден, 1 — сплошной)
    FovTransparency = 0.7,
    PredictionValue = 0.03,
    Smoothness = 6,
    VerticalOffset = 0.7,

    Method = 'Mouse',
    SafetyKey = nil,
    MouseButton = 'RMB'
}

-- ========================================
-- ПРОВЕРКА КНОПКИ МЫШИ
-- ========================================
local function IsMouseButtonPressed(button)
    if button == 'LMB' then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    elseif button == 'RMB' then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    else
        return false
    end
end

-- ========================================
-- ЛОГИКА АИМБОТА
-- ========================================
local AimbotState = {
    Target = nil,
    PreviousTarget = nil,
    FovCircle = nil,
    FovCircleOutline = nil,
    cachedMousePos = vec2(0, 0),
    lastMouseUpdate = 0,
    validPlayers = {},
    lastValidCheck = 0,
    Connection = nil
}
Core.Aimbot.State = AimbotState

local function StartAimbot()
    if AimbotState.Connection then
        AimbotState.Connection:Disconnect()
        AimbotState.Connection = nil
    end

    -- ИСПРАВЛЕНИЕ: Безопасное удаление с проверкой
    if AimbotState.FovCircle then
        pcall(function()
            AimbotState.FovCircle.Visible = false
            AimbotState.FovCircle:Remove()
        end)
        AimbotState.FovCircle = nil
    end

    if AimbotState.FovCircleOutline then
        pcall(function()
            AimbotState.FovCircleOutline.Visible = false
            AimbotState.FovCircleOutline:Remove()
        end)
        AimbotState.FovCircleOutline = nil
    end

    -- Создание новых кругов
    local okCircle, circle = pcall(function() return drawNew('Circle') end)
    local okOutline, outline = pcall(function() return drawNew('Circle') end)
    if not okCircle or not okOutline then
        if okCircle and circle then pcall(function() circle:Remove() end) end
        if okOutline and outline then pcall(function() outline:Remove() end) end
        State.Settings.AimbotConfig.Enabled = false
        warn("[Violite] Drawing API unavailable; Aimbot disabled")
        return
    end
    AimbotState.FovCircle = circle
    AimbotState.FovCircle.NumSides = 40
    AimbotState.FovCircle.Thickness = 2
    AimbotState.FovCircle.Visible = State.Settings.AimbotConfig.FovCheck
    AimbotState.FovCircle.Radius = State.Settings.AimbotConfig.Fov
    AimbotState.FovCircle.Color = CONFIG.Colors.Accent
    AimbotState.FovCircle.Transparency = State.Settings.AimbotConfig.FovTransparency
    AimbotState.FovCircle.ZIndex = 2

    AimbotState.FovCircleOutline = outline
    AimbotState.FovCircleOutline.NumSides = 40
    AimbotState.FovCircleOutline.Thickness = 2
    AimbotState.FovCircleOutline.Visible = State.Settings.AimbotConfig.FovCheck
    AimbotState.FovCircleOutline.Radius = State.Settings.AimbotConfig.Fov
    AimbotState.FovCircleOutline.Color = colRgb(0, 0, 0)
    -- Обводка живёт на том же значении, что и сам круг: ползунок гасит их
    -- вместе, иначе на нуле оставался бы висеть тёмный контур
    AimbotState.FovCircleOutline.Transparency = State.Settings.AimbotConfig.FovTransparency
    AimbotState.FovCircleOutline.ZIndex = 1

    local function isValidTarget(root, hum)
        if not root or not root.Parent then return false end
        if not root:IsA('BasePart') then return false end
        if State.Settings.AimbotConfig.AliveCheck and hum then
            return hum.Health and hum.Health > 0
        end
        return true
    end

    local function dist(cpos, rootpos)
        if State.Settings.AimbotConfig.DistanceCheck then
            return ((cpos - rootpos).Magnitude < State.Settings.AimbotConfig.Distance)
        else
            return true
        end
    end

    local function alive(hum)
        if State.Settings.AimbotConfig.AliveCheck then
            return hum and hum.Health and hum.Health > 0
        else
            return true
        end
    end

    local function team(pteam)
        if State.Settings.AimbotConfig.TeamCheck then
            return (pteam ~= clientTeam)
        else
            return true
        end
    end

    local function vis(root)
        if State.Settings.AimbotConfig.VisibilityCheck and clientChar and clientCamera then
            -- Луч от камеры, а не от HumanoidRootPart
            local origin = clientCamera.CFrame.Position
            local direction = (root.Position - origin)

            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = {clientChar, root.Parent}
            rayParams.IgnoreWater = true

            local rayResult = Workspace:Raycast(origin, direction, rayParams)

            if not rayResult then
                return true
            end

            return rayResult.Instance:IsDescendantOf(root.Parent)
        else
            return true
        end
    end


    local function lock(targ)
        if State.Settings.AimbotConfig.LockOn then
            if AimbotState.PreviousTarget then
                return (targ == AimbotState.PreviousTarget)
            else
                return true
            end
        else
            return true
        end
    end

    local function predic(part)
        if State.Settings.AimbotConfig.Prediction then
            return part and (part.Position + (part.AssemblyLinearVelocity * State.Settings.AimbotConfig.PredictionValue) + vec3(0, State.Settings.AimbotConfig.VerticalOffset, 0))
        else
            return part and (part.Position + vec3(0, State.Settings.AimbotConfig.VerticalOffset, 0))
        end
    end

    local function calculatePriority(rootPos, screenDist, isVisible)
        if not rootPos or not screenDist then return -999999 end
        local score = 10000 - screenDist

        if isVisible then score = score + 2000 end

        if clientRoot then
            local physicalDist = (clientRoot.Position - rootPos).Magnitude
            if physicalDist < 100 then score = score + 500 end
        end

        return score
    end

    local function updateValidPlayers()
        table.clear(AimbotState.validPlayers)

        for i = 1, #playerNames do
            local plrObject = playerManagers[playerNames[i]]

            if plrObject and plrObject.RootPart and plrObject.RootPart.Parent then
                if team(plrObject.Team) then
                    table.insert(AimbotState.validPlayers, plrObject)
                end
            end
        end
    end

    updateValidPlayers()

    local NextTarget

    if State.Settings.AimbotConfig.Method == 'Mouse' then
        NextTarget = function(mp)
            local FinalTarget, FinalVec2, FinalVec3
            local BestPriority = -999999
            local MousePosition = mp or vec2(clientMouse.X, clientMouse.Y)
            local CameraPos = clientCamera.CFrame.Position

            AimbotState.Target = nil

            for i = 1, #AimbotState.validPlayers do
                local plrObject = AimbotState.validPlayers[i]
                local Root, Humanoid = plrObject.RootPart, plrObject.Humanoid

                if not isValidTarget(Root, Humanoid) then continue end

                local CurVec3 = predic(Root)

                if (CurVec3 and lock(Root) and alive(Humanoid) and dist(CameraPos, CurVec3)) then
                    local CurVec2, CurVis = clientCamera:WorldToViewportPoint(CurVec3)

                    if CurVis then
                        CurVec2 = vec2(CurVec2.X, CurVec2.Y)
                        local CurMag = (MousePosition - CurVec2).Magnitude

                        if CurMag < (State.Settings.AimbotConfig.FovCheck and State.Settings.AimbotConfig.Fov or 9999) then
                            local isVisible = vis(Root)

                            -- Пропускаем невидимые цели, если включена проверка
                            if State.Settings.AimbotConfig.VisibilityCheck and not isVisible then
                                continue
                            end

                            local priority = calculatePriority(CurVec3, CurMag, isVisible)

                            if priority > BestPriority then
                                BestPriority = priority
                                FinalTarget = Root
                                FinalVec2 = CurVec2
                                FinalVec3 = CurVec3
                            end
                        end
                    end
                end
            end

            AimbotState.Target = FinalVec2
            return FinalTarget, FinalVec2, nil
        end

    elseif State.Settings.AimbotConfig.Method == 'Camera' then
        NextTarget = function(mp)
            local FinalTarget, FinalVec2, FinalVec3
            local BestPriority = -999999
            local MousePosition = mp or vec2(clientMouse.X, clientMouse.Y)  -- ИЗМЕНИТЬ
            local CameraPos = clientCamera.CFrame.Position

            AimbotState.Target = nil

            for i = 1, #AimbotState.validPlayers do
                local plrObject = AimbotState.validPlayers[i]
                local Root, Humanoid = plrObject.RootPart, plrObject.Humanoid

                if not isValidTarget(Root, Humanoid) then continue end

                local CurVec3 = predic(Root)

                if (CurVec3 and lock(Root) and alive(Humanoid) and dist(CameraPos, CurVec3)) then
                    local CurVec2, CurVis = clientCamera:WorldToViewportPoint(CurVec3)

                    if CurVis then
                        CurVec2 = vec2(CurVec2.X, CurVec2.Y)
                        local CurMag = (MousePosition - CurVec2).Magnitude

                        if CurMag < (State.Settings.AimbotConfig.FovCheck and State.Settings.AimbotConfig.Fov or 9999) then
                            local isVisible = vis(Root)

                            -- Пропускаем невидимые цели, если включена проверка
                            if State.Settings.AimbotConfig.VisibilityCheck and not isVisible then
                                continue
                            end

                            local priority = calculatePriority(CurVec3, CurMag, isVisible)

                            if priority > BestPriority then
                                BestPriority = priority
                                FinalTarget = Root
                                FinalVec2 = CurVec2
                                FinalVec3 = CurVec3
                            end
                        end
                    end
                end
            end

            AimbotState.Target = FinalVec2
            return FinalTarget, FinalVec3
        end
    end

    if State.Settings.AimbotConfig.Method == 'Camera' then
    AimbotState.Connection = Core.Connect(RunService.RenderStepped, function()
        if not AimbotState.FovCircle or not AimbotState.FovCircleOutline then
            return
        end
        local currentTime = tick()

        -- Обновляем позицию мыши каждый кадр БЕЗ задержки
        AimbotState.cachedMousePos = UserInputService:GetMouseLocation()

        AimbotState.FovCircle.Position = AimbotState.cachedMousePos
        AimbotState.FovCircleOutline.Position = AimbotState.cachedMousePos
        AimbotState.FovCircle.Color = CONFIG.Colors.Accent

        AimbotState.FovCircle.Visible = State.Settings.AimbotConfig.FovCheck
        AimbotState.FovCircleOutline.Visible = State.Settings.AimbotConfig.FovCheck

        if currentTime - AimbotState.lastValidCheck > 0.5 then
            updateValidPlayers()
            AimbotState.lastValidCheck = currentTime
        end

            local isActive = false
            if State.Settings.AimbotConfig.SafetyKey then
                isActive = UserInputService:IsKeyDown(State.Settings.AimbotConfig.SafetyKey)
            else
                isActive = IsMouseButtonPressed(State.Settings.AimbotConfig.MouseButton)
            end

            if not isActive then
                AimbotState.PreviousTarget = nil
                AimbotState.Target = nil
                return
            end

            -- ИСПРАВЛЕНИЕ: Проверяем видимость GUI MM2 скрипта, а не MainFrame из исходного аимбота
            if State.Runtime.UIElements.MainFrame and State.Runtime.UIElements.MainFrame.Visible then
                return
            end

            local target, position = NextTarget(AimbotState.cachedMousePos)
            AimbotState.PreviousTarget = target

            if position then
                local _ = clientCamera.CFrame
                clientCamera.CFrame = CFrame.new(_.Position, position):lerp(_, State.Settings.AimbotConfig.Smoothness)
            end
        end)
    elseif State.Settings.AimbotConfig.Method == 'Mouse' then
        AimbotState.Connection = Core.Connect(RunService.RenderStepped, function(dt)
        if not AimbotState.FovCircle or not AimbotState.FovCircleOutline then
            return
        end
            local currentTime = tick()

            -- Убираем ограничение частоты обновления
            AimbotState.cachedMousePos = UserInputService:GetMouseLocation()

            AimbotState.FovCircle.Position = AimbotState.cachedMousePos
            AimbotState.FovCircleOutline.Position = AimbotState.cachedMousePos
            AimbotState.FovCircle.Color = CONFIG.Colors.Accent

            AimbotState.FovCircle.Visible = State.Settings.AimbotConfig.FovCheck
            AimbotState.FovCircleOutline.Visible = State.Settings.AimbotConfig.FovCheck

            if currentTime - AimbotState.lastValidCheck > 0.5 then
                updateValidPlayers()
                AimbotState.lastValidCheck = currentTime
            end

            local isActive = false
            if State.Settings.AimbotConfig.SafetyKey then
                isActive = UserInputService:IsKeyDown(State.Settings.AimbotConfig.SafetyKey)
            else
                isActive = IsMouseButtonPressed(State.Settings.AimbotConfig.MouseButton)
            end

            if not isActive then
                AimbotState.PreviousTarget = nil
                AimbotState.Target = nil
                return
            end

            -- ИСПРАВЛЕНИЕ: Проверяем видимость GUI MM2 скрипта
            if State.Runtime.UIElements.MainGui and CoreGui:FindFirstChild("MM2_ESP_UI") then
                local mainGui = CoreGui:FindFirstChild("MM2_ESP_UI")
                if mainGui and mainGui:FindFirstChild("MainFrame") then
                    if mainGui.MainFrame.Visible then return end
                end
            end

            local target, position, _ = NextTarget(AimbotState.cachedMousePos)
            AimbotState.PreviousTarget = target

            if position then
                local delta = position - AimbotState.cachedMousePos

                -- ИСПРАВЛЕНИЕ: правильная формула со smoothness
                local smoothValue = math.max(State.Settings.AimbotConfig.Smoothness, 0.01) -- Минимум 0.01 чтобы избежать деления на 0

                if State.Settings.AimbotConfig.Deltatime then
                    -- Для deltatime режима
                    delta = delta / smoothValue * dt * 60 -- Нормализация под 60 FPS
                else
                    -- Обычный режим - делим на smoothness
                    delta = delta / smoothValue
                end

                if mousemoverel then
                    mousemoverel(delta.X, delta.Y)
                end
            end
        end)
    end

    TrackConnection(AimbotState.Connection)
end

local function StopAimbot()
    if AimbotState.Connection then
        pcall(function() AimbotState.Connection:Disconnect() end)
        AimbotState.Connection = nil
    end

    -- Безопасное удаление с проверкой
    if AimbotState.FovCircle then
        pcall(function() AimbotState.FovCircle:Remove() end)
        AimbotState.FovCircle = nil
    end

    if AimbotState.FovCircleOutline then
        pcall(function() AimbotState.FovCircleOutline:Remove() end)
        AimbotState.FovCircleOutline = nil
    end

    AimbotState.Target = nil
    AimbotState.PreviousTarget = nil
end

local function ToggleAimbot(enabled)
    State.Settings.AimbotConfig.Enabled = enabled

    if enabled then
        StartAimbot()
    else
        StopAimbot()
    end
end

-- Экспорт функций в глобальную область видимости
Core.Aimbot.SetEnabled = ToggleAimbot
Core.Aimbot.Start = StartAimbot
Core.Aimbot.Stop = StopAimbot

end -- Aimbot

-- ============= PING CHAMS SYSTEM =============
local PingChams = {}
do
    local BUFFER_MAX_SECONDS   = 3.0
    local PING_UPDATE_INTERVAL = 0.2
    local MATERIAL             = Enum.Material.ForceField

    function PingChams.median(tbl)
        if not tbl or type(tbl) ~= "table" or #tbl == 0 then return nil end
        local copy = {}
        for i = 1, #tbl do copy[i] = tbl[i] end
        table.sort(copy)
        local n = #copy
        return n % 2 == 1 and copy[(n+1)/2] or (copy[n/2] + copy[n/2+1]) * 0.5
    end

    function PingChams.pushPing(sec)
        table.insert(State.Cache.PingChamsPingBuf, sec)
        if #State.Cache.PingChamsPingBuf > 20 then
            table.remove(State.Cache.PingChamsPingBuf, 1)
        end
    end

    function PingChams.probePingMs()
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

    function PingChams.updatePing()
        local now = tick()
        if now - State.Runtime.PingChamsLastPingUpdate < PING_UPDATE_INTERVAL then return end
        State.Runtime.PingChamsLastPingUpdate = now

        local ms = PingChams.probePingMs()
        if ms then
            local sec = math.clamp(ms * 0.001, 0.002, 1.0)
            PingChams.pushPing(sec)
            local med   = PingChams.median(State.Cache.PingChamsPingBuf)
            local alpha = #State.Cache.PingChamsPingBuf >= 5 and 0.25 or 0.5
            if med then
                State.Runtime.PingChamsRTT = State.Runtime.PingChamsRTT * (1 - alpha) + med * alpha
            else
                State.Runtime.PingChamsRTT = sec
            end
        end
    end

    function PingChams.sizeFromChar(char)
        if not char then return Vector3.new(4, 6, 2) end
        local ok, size = pcall(function() return char:GetExtentsSize() end)
        if ok and size then
            return Vector3.new(math.max(2, size.X), math.max(3, size.Y), math.max(1, size.Z))
        end
        return Vector3.new(4, 6, 2)
    end

    function PingChams.collectRigParts(char)
        local parts = {}
        if not char then return parts end
        for _, d in ipairs(char:QueryDescendants("BasePart")) do
            if d.Name ~= "HumanoidRootPart" then
                table.insert(parts, d)
            end
        end
        return parts
    end

    function PingChams.getRootPart(char)
        if not char then return nil end
        return char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("LowerTorso")
    end

    function PingChams.clearGhostClone()
        State.Runtime.PingChamsGhostMap = {}
        State.Runtime.PingChamsGhostChar = nil
        State.Runtime.PingChamsGhostPartCount = 0
        if State.Runtime.PingChamsGhostClone then
            pcall(function() State.Runtime.PingChamsGhostClone:Destroy() end)
            State.Runtime.PingChamsGhostClone = nil
        end
    end

    function PingChams.rebuildGhostClone(char, col, trans)
        PingChams.clearGhostClone()
        State.Runtime.PingChamsGhostClone = Core.New("Model")
        State.Runtime.PingChamsGhostClone.Name = "GhostClone"
        State.Runtime.PingChamsGhostClone.Parent = State.Runtime.PingChamsGhostModel

        -- Ключуем по инстансу, а не по имени: у аксессуаров/тулов все парты
        -- называются "Handle" — по имени они перетирали друг друга в карте,
        -- и осиротевшие гост-парты навсегда зависали на месте rebuild'а
        local rigParts = PingChams.collectRigParts(char)
        State.Runtime.PingChamsGhostChar = char
        State.Runtime.PingChamsGhostPartCount = #rigParts

        for _, src in ipairs(rigParts) do
            local gp
            if src:IsA("MeshPart") or src:IsA("Part") then
                gp = Core.Own(src:Clone())
                -- Ауры Visuals (атрибут StandaloneVFX_Owner) и прочие эффекты живут внутри
                -- частей и клонировались вместе с ними — у призрака была вторая аура
                for _, d in ipairs(gp:GetDescendants()) do
                    if d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Motor6D")
                        or d:IsA("Decal")
                        or d:GetAttribute("StandaloneVFX_Owner") ~= nil
                        or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light")
                        or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
                        pcall(function() d:Destroy() end)
                    end
                end
                gp.Size = gp.Size * 1.03
            else
                gp = Core.New("Part")
                gp.Size = src.Size * 1.03
            end
            gp.Name         = "Ghost_" .. src.Name
            gp.Anchored     = true
            gp.CanCollide   = false
            gp.CanQuery     = false
            gp.CanTouch     = false
            gp.CastShadow   = false
            gp.Material     = MATERIAL
            gp.Color        = col
            gp.Transparency = trans
            gp.Parent       = State.Runtime.PingChamsGhostClone
            State.Runtime.PingChamsGhostMap[src] = gp
        end
    end

    function PingChams.ensureGhost()
        if not State.Runtime.PingChamsGhostModel then
            State.Runtime.PingChamsGhostModel = Core.New("Model")
            State.Runtime.PingChamsGhostModel.Name = "ServerApproxGhost"
            State.Runtime.PingChamsGhostModel.Parent = Workspace
        end

        if not State.Runtime.PingChamsGhostPart then
            local p = Core.New("Part")
            p.Name         = "ServerApproxPart"
            p.Anchored     = true
            p.CanCollide   = false
            p.CanQuery     = false
            p.CanTouch     = false
            p.Transparency = 1
            p.Size         = PingChams.sizeFromChar(LocalPlayer.Character)
            p.Parent       = State.Runtime.PingChamsGhostModel
            State.Runtime.PingChamsGhostPart = p
        end

        if not State.Runtime.PingChamsGuiAnchor then
            local a = Core.New("Part")
            a.Name         = "GuiAnchor"
            a.Anchored     = true
            a.CanCollide   = false
            a.CanQuery     = false
            a.CanTouch     = false
            a.Transparency = 1
            a.Size         = Vector3.new(1, 1, 1)
            a.Parent       = State.Runtime.PingChamsGhostModel
            State.Runtime.PingChamsGuiAnchor = a
        end

        if not State.Runtime.PingChamsGUI then
            local gui = Core.New("BillboardGui")
            gui.Name        = "PingInfo"
            gui.Size        = UDim2.new(0, 300, 0, 30)
            gui.Adornee     = State.Runtime.PingChamsGuiAnchor
            gui.StudsOffset = Vector3.new(0, 0.7, 0)
            gui.AlwaysOnTop = true
            gui.Enabled     = State.Settings.PingChamsShowLabel
            gui.Parent      = State.Runtime.PingChamsGhostModel
            local lbl = Core.New("TextLabel")
            lbl.Name                  = "Label"
            lbl.BackgroundTransparency = 1
            lbl.Size                  = UDim2.new(1, 0, 1, 0)
            lbl.Font                  = Enum.Font.GothamBold
            lbl.TextScaled            = false
            lbl.TextSize              = 14
            lbl.TextColor3            = CONFIG.Colors.Accent
            lbl.Text                  = "Ping -- ms"
            lbl.TextStrokeTransparency = 0
            lbl.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)
            lbl.Parent                = gui
            State.Runtime.PingChamsGUI = gui
        end
    end

    function PingChams.captureOffsets(char, root)
        local map = {}
        if not char or not root then return map end
        for _, d in ipairs(char:QueryDescendants("BasePart")) do
            if d ~= root then
                pcall(function()
                    map[d] = root.CFrame:ToObjectSpace(d.CFrame)
                end)
            end
        end
        return map
    end

    function PingChams.resetHistory()
        State.Cache.PingChamsBuffer = {}
        State.Runtime.PingChamsNextDesyncSample = nil
        State.Runtime.PingChamsSmoothFrame, State.Runtime.PingChamsSmoothTime = nil, nil
        State.Runtime.PingChamsTransparency, State.Runtime.PingChamsTransparencyTime = nil, nil
        State.Runtime.PingChamsTextTransparency, State.Runtime.PingChamsTextTime = nil, nil
    end

    function PingChams.setSource(char, desync)
        if State.Runtime.PingChamsSampleChar ~= char or State.Settings.PingChamsSampleDesync ~= desync then
            PingChams.resetHistory()
            State.Runtime.PingChamsSampleChar = char
            State.Settings.PingChamsSampleDesync = desync
        end
    end

    function PingChams.pushSample(tClient, char, replicatedFrame, desync)
        local root = PingChams.getRootPart(char)
        if not root then return end
        PingChams.setSource(char, desync == true)

        -- Локальный Jitter меняется каждый кадр, но наблюдатель получает лишь
        -- часть позиций. Частота оценена по второму клиенту, это не перехват пакетов.
        if desync then
            local nextSample = State.Runtime.PingChamsNextDesyncSample
            if nextSample and tClient < nextSample then return end
            local interval = State.Settings.PingChamsDesyncSampleInterval
            nextSample = nextSample or tClient
            State.Runtime.PingChamsNextDesyncSample = nextSample
                + (math.floor((tClient - nextSample) / interval) + 1) * interval
        end

        -- Снимаем позу до подмены HRP; в историю кладём оценку репликации.
        local offsets = PingChams.captureOffsets(char, root)
        local vel     = Vector3.new()
        local ok1, v  = pcall(function() return root.AssemblyLinearVelocity end)
        if ok1 and typeof(v) == "Vector3" then vel = v end

        table.insert(State.Cache.PingChamsBuffer, {
            t = tClient, cf = replicatedFrame or root.CFrame, offsets = offsets, vel = vel
        })

        local cutoff = tClient - BUFFER_MAX_SECONDS
        while #State.Cache.PingChamsBuffer > 0 and State.Cache.PingChamsBuffer[1].t < cutoff do
            table.remove(State.Cache.PingChamsBuffer, 1)
        end
    end

    function PingChams.lerpCFrame(a, b, alpha)
        local pos = a.Position:Lerp(b.Position, alpha)
        local ax, ay, az = a:ToOrientation()
        local bx, by, bz = b:ToOrientation()
        local rx = ax + math.atan2(math.sin(bx - ax), math.cos(bx - ax)) * alpha
        local ry = ay + math.atan2(math.sin(by - ay), math.cos(by - ay)) * alpha
        local rz = az + math.atan2(math.sin(bz - az), math.cos(bz - az)) * alpha
        return CFrame.new(pos) * CFrame.fromOrientation(rx, ry, rz)
    end

    function PingChams.sampleAtTime(target, desync)
        if #State.Cache.PingChamsBuffer == 0 then return nil end

        for i = 1, #State.Cache.PingChamsBuffer do
            local s = State.Cache.PingChamsBuffer[i]
            if s.t >= target then
                local p = State.Cache.PingChamsBuffer[math.max(i - 1, 1)]
                local n = s
                if p.t == n.t then
                    return {root = p.cf, offsets = p.offsets}
                end
                local alpha   = math.clamp((target - p.t) / (n.t - p.t), 0, 1)
                -- Интерполируем редкие снимки, а не чередующиеся кадры Jitter.
                -- В начале интервала держим предыдущую позу, затем летим к новой.
                if desync then
                    local duration = math.min(n.t - p.t, State.Settings.PingChamsDesyncInterpolation)
                    alpha = math.clamp(1 - (n.t - target) / duration, 0, 1)
                end
                local cf      = PingChams.lerpCFrame(p.cf, n.cf, alpha)
                local offsets = {}
                for part, aOff in pairs(p.offsets or {}) do
                    local bOff = n.offsets and n.offsets[part] or aOff
                    offsets[part] = PingChams.lerpCFrame(aOff, bOff, alpha)
                end
                for part, bOff in pairs(n.offsets or {}) do
                    if not offsets[part] then
                        local aOff = p.offsets and p.offsets[part] or bOff
                        offsets[part] = PingChams.lerpCFrame(aOff, bOff, alpha)
                    end
                end
                return {root = cf, offsets = offsets}
            end
        end

        local last = State.Cache.PingChamsBuffer[#State.Cache.PingChamsBuffer]
        return {root = last.cf, offsets = last.offsets}
    end
end -- do PingChams

local function StartPingChams()
    if State.Runtime.PingChamsRenderConn then return end

    State.Runtime.PingChamsRenderConn = Core.Connect(RunService.RenderStepped, function()
        pcall(function()
            if not State.Settings.PingChamsEnabled then return end

            PingChams.updatePing()
            PingChams.ensureGhost()

            local char = LocalPlayer.Character
            local desync = State.Settings.FakePositionEnabled == true or State.Settings.FakeLagEnabled == true
            PingChams.setSource(char, desync)
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    -- Пересобираем клон при респавне и при смене набора партов
                    -- (эквип/анэквип тула, добавление аксессуара), иначе гост
                    -- продолжает двигать несуществующие парты
                    local needRebuild = State.Runtime.PingChamsGhostClone == nil
                        or State.Runtime.PingChamsGhostChar ~= char
                        or State.Runtime.PingChamsGhostPartCount ~= #PingChams.collectRigParts(char)
                    if needRebuild then
                        PingChams.rebuildGhostClone(char, CONFIG.Colors.Accent, 0.6)
                    end
                    -- Десинк пишет историю сам, до восстановления настоящей
                    -- позиции. RenderStepped уже видит обычный CFrame игрока.
                    if not desync then PingChams.pushSample(tick(), char) end
                end
                if State.Runtime.PingChamsGhostPart then
                    State.Runtime.PingChamsGhostPart.Size = PingChams.sizeFromChar(char)
                end
            end

            local oneWayLatency      = State.Runtime.PingChamsRTT * 0.5
            local serverPhysicsDelay = 0.050
            local clientBuffer       = 0.020
            local totalDelay         = oneWayLatency + serverPhysicsDelay + clientBuffer
            local sampleDelay        = math.clamp(totalDelay, 0.06, 0.9)

            local now        = tick()
            local samplePast = PingChams.sampleAtTime(now - sampleDelay, desync)

            if not State.Runtime.PingChamsGhostClone and LocalPlayer.Character then
                PingChams.rebuildGhostClone(LocalPlayer.Character, CONFIG.Colors.Accent, 0.6)
            end

            if samplePast and samplePast.root then
                local rootPast   = samplePast.root
                local nowT       = tick()
                local dtSmooth   = math.max(0.0001, nowT - (State.Runtime.PingChamsSmoothTime or nowT))
                local smoothAlpha = math.clamp(dtSmooth * 10, 0.12, 0.55)
                State.Runtime.PingChamsSmoothFrame = desync and rootPast
                    or PingChams.lerpCFrame(State.Runtime.PingChamsSmoothFrame or rootPast, rootPast, smoothAlpha)
                State.Runtime.PingChamsSmoothTime = nowT

                if State.Runtime.PingChamsGhostPart then
                    State.Runtime.PingChamsGhostPart.CFrame = State.Runtime.PingChamsSmoothFrame
                end
                if State.Runtime.PingChamsGuiAnchor then
                    local yOffset = State.Runtime.PingChamsGhostPart and (State.Runtime.PingChamsGhostPart.Size.Y / 2 + 0.5) or 3.5
                    State.Runtime.PingChamsGuiAnchor.CFrame = CFrame.new(State.Runtime.PingChamsSmoothFrame.Position + Vector3.new(0, yOffset, 0))
                end

                local lpRoot     = PingChams.getRootPart(LocalPlayer.Character)
                local hum        = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                -- Настоящая скорость: Velocity Spoofer может держать на корне подменённую.
                local speedMeas  = lpRoot and (State.Runtime.GetRealVelocity and State.Runtime.GetRealVelocity(lpRoot) or lpRoot.AssemblyLinearVelocity).Magnitude or 0
                local speedIntent = 0
                if hum and hum.MoveDirection.Magnitude > 0.01 then
                    speedIntent = hum.MoveDirection.Magnitude * (hum.WalkSpeed or 16)
                end
                local speed = math.max(speedMeas, speedIntent)

                local transPast  = desync and 0.55 or math.clamp(0.9 - math.min(speed / 16, 1) * 0.65, 0.2, 1)
                local nowFadeT   = tick()
                local dt         = math.max(0.0001, nowFadeT - (State.Runtime.PingChamsTransparencyTime or nowFadeT))
                State.Runtime.PingChamsTransparency = (State.Runtime.PingChamsTransparency or transPast) + (transPast - (State.Runtime.PingChamsTransparency or transPast)) * math.clamp(dt * 5.0, 0.05, 0.5)
                State.Runtime.PingChamsTransparencyTime = nowFadeT

                for src, gp in pairs(State.Runtime.PingChamsGhostMap) do
                    local off = samplePast.offsets and samplePast.offsets[src]
                    if off then
                        gp.Color        = CONFIG.Colors.Accent
                        -- Скрытое на настоящем теле (Fake Headless — голова, Fake Korblox —
                        -- настоящая правая нога) скрыто и у призрака; нога Korblox —
                        -- обычная часть персонажа и показывается как есть
                        gp.Transparency = src.Transparency >= 0.99 and 1 or State.Runtime.PingChamsTransparency
                        gp.Material     = Enum.Material.ForceField
                        gp.CFrame       = State.Runtime.PingChamsSmoothFrame * off
                    else
                        -- Нет офсета в сэмпле (парт появился только что либо
                        -- буфер ещё со старым персонажем) — прячем, а не морозим
                        gp.Transparency = 1
                    end
                end

                if State.Runtime.PingChamsGUI and State.Runtime.PingChamsGUI:FindFirstChild("Label") then
                    local lbl = State.Runtime.PingChamsGUI.Label
                    lbl.Text = string.format(desync and "Desync ~%.0f ms | Ping: %.0f ms" or "Backtrack: %.0f ms | Ping: %.0f ms", sampleDelay * 1000, State.Runtime.PingChamsRTT * 1000)
                    lbl.TextColor3 = CONFIG.Colors.Accent

                    local nowTT   = tick()
                    local dtTT    = math.max(0.0001, nowTT - (State.Runtime.PingChamsTextTime or nowTT))
                    local targetTT = desync and 0 or 1 - math.clamp((speed - 14) / 1, 0, 1)
                    State.Runtime.PingChamsTextTransparency = (State.Runtime.PingChamsTextTransparency or targetTT) + (targetTT - (State.Runtime.PingChamsTextTransparency or targetTT)) * math.clamp(dtTT * 3, 0.03, 0.25)
                    State.Runtime.PingChamsTextTime = nowTT
                    lbl.TextTransparency      = State.Runtime.PingChamsTextTransparency
                    lbl.TextStrokeTransparency = State.Runtime.PingChamsTextTransparency
                    State.Runtime.PingChamsGUI.Enabled = State.Settings.PingChamsShowLabel and State.Runtime.PingChamsTextTransparency < 0.995
                end
            else
                if State.Runtime.PingChamsGUI then State.Runtime.PingChamsGUI.Enabled = false end
                for _, gp in pairs(State.Runtime.PingChamsGhostMap) do
                    gp.Transparency = 1
                end
            end

            if not State.Settings.PingChamsEnabled then
                if State.Runtime.PingChamsGUI and State.Runtime.PingChamsGUI:FindFirstChild("Label") then
                    State.Runtime.PingChamsGUI.Label.Visible = false
                end
                for _, gp in pairs(State.Runtime.PingChamsGhostMap) do
                    gp.Transparency = 1
                end
            end
        end)
    end)
end

local function StopPingChams()
    State.Settings.PingChamsEnabled = false
    if State.Runtime.PingChamsRenderConn then
        State.Runtime.PingChamsRenderConn:Disconnect()
        State.Runtime.PingChamsRenderConn = nil
    end
    if State.Runtime.PingChamsGUI then
        pcall(function() State.Runtime.PingChamsGUI:Destroy() end)
        State.Runtime.PingChamsGUI = nil
    end
    if State.Runtime.PingChamsGuiAnchor then
        pcall(function() State.Runtime.PingChamsGuiAnchor:Destroy() end)
        State.Runtime.PingChamsGuiAnchor = nil
    end
    if State.Runtime.PingChamsGhostModel then
        pcall(function() State.Runtime.PingChamsGhostModel:Destroy() end)
        State.Runtime.PingChamsGhostModel = nil
        State.Runtime.PingChamsGhostClone = nil
    end
    State.Runtime.PingChamsGhostMap = {}
    State.Runtime.PingChamsGhostPart = nil
    State.Runtime.PingChamsGhostChar = nil
    State.Runtime.PingChamsGhostPartCount = 0
    State.Runtime.PingChamsSampleChar = nil
    PingChams.resetHistory()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- COIN SOUND MUTER
-- ══════════════════════════════════════════════════════════════════════════════
local COIN_SOUND_NAME = "CoinSound"
local COIN_SOUND_ID   = "131323304"

local function isCoinSound(obj)
    if not obj:IsA("Sound") then return false end
    if obj.Name == COIN_SOUND_NAME then return true end
    return tostring(obj.SoundId):find(COIN_SOUND_ID, 1, true) ~= nil
end

local function hookCoinSound(sound)
    local sounds = State.Runtime.CoinMuterHooked
    if sounds[sound] then return end
    local record = {Volume = sound.Volume}
    sounds[sound] = record
    record.Connection = Core.Connect(sound:GetPropertyChangedSignal("Volume"), function()
        if State.Settings.CoinMuterEnabled and sound.Volume ~= 0 then
            record.Volume = sound.Volume
            sound.Volume = 0
        end
    end)
    sound.Volume = 0
end

local function StartCoinMuter()
    if State.Settings.CoinMuterEnabled then return end
    State.Settings.CoinMuterEnabled = true
    State.Runtime.CoinMuterHooked = {}
    State.Runtime.CoinMuterAddedConn = Core.Connect(Workspace.DescendantAdded, function(object)
        if isCoinSound(object) then hookCoinSound(object) end
    end)
    State.Runtime.CoinMuterRemovingConn = Core.Connect(Workspace.DescendantRemoving, function(object)
        local record = State.Runtime.CoinMuterHooked[object]
        if record then
            record.Connection:Disconnect()
            pcall(function() object.Volume = record.Volume end)
            State.Runtime.CoinMuterHooked[object] = nil
        end
    end)
    local ok, sounds = pcall(function() return Workspace:QueryDescendants("Sound") end)
    if not ok then sounds = Workspace:GetDescendants() end
    for _, object in ipairs(sounds) do if isCoinSound(object) then hookCoinSound(object) end end
end

local function StopCoinMuter()
    State.Settings.CoinMuterEnabled = false
    for _, key in ipairs({"CoinMuterAddedConn", "CoinMuterRemovingConn"}) do
        local connection = State.Runtime[key]
        if connection then connection:Disconnect(); State.Runtime[key] = nil end
    end
    for sound, record in pairs(State.Runtime.CoinMuterHooked or {}) do
        record.Connection:Disconnect()
        pcall(function() sound.Volume = record.Volume end)
    end
    State.Runtime.CoinMuterHooked = {}
end

TrackConnection(Core.Connect(LocalPlayer.CharacterAdded, function()
    task.wait(0.5)
    pcall(function()
        if State.Runtime.PingChamsGhostPart and LocalPlayer.Character then
            State.Runtime.PingChamsGhostPart.Size = PingChams.sizeFromChar(LocalPlayer.Character)
        end
    end)
end))


-- ============= BULLET/KNIFE TRACERS =============
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Blacklist
RayParams.IgnoreWater = true

local function CreateTracer(startPos, endPos, duration)
    if not State.Settings.BulletTracersEnabled then return end

    local attachment0 = Core.New("Attachment")
    attachment0.WorldPosition = startPos
    attachment0.Parent = Workspace.Terrain

    local attachment1 = Core.New("Attachment")
    attachment1.WorldPosition = endPos
    attachment1.Parent = Workspace.Terrain

    local beam = Core.New("Beam")
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(CONFIG.Colors.Tracers)
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

    table.insert(State.Runtime.TracersList, {beam = beam, att0 = attachment0, att1 = attachment1, time = tick()})

    Core.Tasks.delay(duration or 0.3, function()
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

        for i, v in ipairs(State.Runtime.TracersList) do
            if v.beam == beam then
                table.remove(State.Runtime.TracersList, i)
                break
            end
        end
    end)
end

-- ============= COIN TRACER SYSTEM =============
local CurrentCoinTracer = nil

local function CreateCoinTracer(character, targetCoin)
    if not character or not targetCoin then return end
    -- УБРАНА проверка State.BulletTracersEnabled

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
    local attachment0 = Core.New("Attachment")
    attachment0.Name = "CoinTracerStart"
    attachment0.Parent = hrp

    local attachment1 = Core.New("Attachment")
    attachment1.Name = "CoinTracerEnd"
    attachment1.Parent = targetCoin

    -- Создаем Beam
    local beam = Core.New("Beam")
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(CONFIG.Colors.CoinTracer)
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Brightness = 5
    beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
    beam.TextureMode = Enum.TextureMode.Stretch
    beam.TextureSpeed = 2
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0)
    })
    beam.Width0 = 0.3
    beam.Width1 = 0.3
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
TrackConnection(Core.Connect(RunService.RenderStepped, function()
    if CurrentCoinTracer then
        if not CurrentCoinTracer.coin or not CurrentCoinTracer.coin.Parent then
            RemoveCoinTracer()
            return
        end
        if not State.Settings.AutoFarmEnabled then
            RemoveCoinTracer()
            return
        end
    end
end))

-- ============= FRIEND VIEWER SYSTEM =============

local function MakeFriendKey(p1, p2)
    local a, b = p1.UserId, p2.UserId
    if a > b then a, b = b, a end
    return tostring(a) .. "_" .. tostring(b)
end

local function RemoveFriendBeam(key)
    local data = State.Runtime.FriendBeams[key]
    if data then
        pcall(function() data.beam:Destroy() end)
        pcall(function() data.att0:Destroy() end)
        pcall(function() data.att1:Destroy() end)
        State.Runtime.FriendBeams[key] = nil
    end
end

local function ClearAllFriendData()
    for key, _ in pairs(State.Runtime.FriendBeams) do
        RemoveFriendBeam(key)
    end
    State.Runtime.FriendBeams = {}
    State.Runtime.FriendPairs = {}
    State.Cache.FriendPairCheck = {}
end

local function CreateFriendBeam(pair)
    if State.Runtime.FriendBeams[pair.key] then return end
    local hrp1 = pair.p1 and pair.p1.Character and pair.p1.Character:FindFirstChild("HumanoidRootPart")
    local hrp2 = pair.p2 and pair.p2.Character and pair.p2.Character:FindFirstChild("HumanoidRootPart")
    if not hrp1 or not hrp2 then return end

    local attachment0 = Core.New("Attachment")
    attachment0.Name = "FriendTracerStart_" .. pair.key
    attachment0.Parent = hrp1

    local attachment1 = Core.New("Attachment")
    attachment1.Name = "FriendTracerEnd_" .. pair.key
    attachment1.Parent = hrp2

    local beam = Core.New("Beam")
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(CONFIG.Colors.FriendTracerFar)
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Brightness = 5
    beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
    beam.TextureMode = Enum.TextureMode.Stretch
    beam.TextureSpeed = 2
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0)
    })
    beam.Width0 = 0.3
    beam.Width1 = 0.3
    beam.ZOffset = 0.1
    beam.Parent = attachment0

    State.Runtime.FriendBeams[pair.key] = { beam = beam, att0 = attachment0, att1 = attachment1, p1 = pair.p1, p2 = pair.p2 }
end

local TryAddFriendPair -- forward declaration for use in StartFriendViewer

local function ScanAllFriendPairs()
    local list = Players:GetPlayers()
    for i = 1, #list do
        for j = i + 1, #list do
            TryAddFriendPair(list[i], list[j])
            task.wait(0.03)
        end
    end
end

local function RemovePlayerFromFriendData(player)
    for i = #State.Runtime.FriendPairs, 1, -1 do
        local pair = State.Runtime.FriendPairs[i]
        if pair.p1 == player or pair.p2 == player then
            RemoveFriendBeam(pair.key)
            State.Cache.FriendPairCheck[pair.key] = nil
            table.remove(State.Runtime.FriendPairs, i)
        end
    end
end

TryAddFriendPair = function(p1, p2)
    if not p1 or not p2 or p1 == p2 then return end
    local key = MakeFriendKey(p1, p2)
    if State.Cache.FriendPairCheck[key] then return end
    local ok, isFriend = pcall(function() return p2:IsFriendsWith(p1.UserId) end)
    if not ok or not isFriend then return end
    State.Cache.FriendPairCheck[key] = true
    local pair = { key = key, p1 = p1, p2 = p2 }
    table.insert(State.Runtime.FriendPairs, pair)
    if State.Settings.FriendViewerEnabled then
        CreateFriendBeam(pair)
    end
end

TrackConnection(Core.Connect(RunService.RenderStepped, function()
    if not State.Settings.FriendViewerEnabled then return end
    if not next(State.Runtime.FriendBeams) and #State.Runtime.FriendPairs == 0 then return end

    for key, data in pairs(State.Runtime.FriendBeams) do
        local hrp1 = data.p1 and data.p1.Character and data.p1.Character:FindFirstChild("HumanoidRootPart")
        local hrp2 = data.p2 and data.p2.Character and data.p2.Character:FindFirstChild("HumanoidRootPart")
        if not hrp1 or not hrp2 or not data.att0.Parent or not data.att1.Parent then
            RemoveFriendBeam(key)
        else
            local dist = (hrp1.Position - hrp2.Position).Magnitude
            local alpha = math.clamp(1 / (dist / State.Settings.FriendViewerThreshold), 0, 1)
            local color = CONFIG.Colors.FriendTracerFar:Lerp(CONFIG.Colors.FriendTracerNear, alpha)
            data.beam.Color = ColorSequence.new(color)
        end
    end

    for _, pair in ipairs(State.Runtime.FriendPairs) do
        if not State.Runtime.FriendBeams[pair.key] then
            local hrp1 = pair.p1 and pair.p1.Character and pair.p1.Character:FindFirstChild("HumanoidRootPart")
            local hrp2 = pair.p2 and pair.p2.Character and pair.p2.Character:FindFirstChild("HumanoidRootPart")
            if hrp1 and hrp2 then
                CreateFriendBeam(pair)
            end
        end
    end
end))

local function StartFriendViewer()
    if State.Settings.FriendViewerEnabled then return end
    State.Settings.FriendViewerEnabled = true

    State.Runtime.FriendScanCoroutine = Core.Tasks.spawn(function() ScanAllFriendPairs() end)

    State.Runtime.FriendPlayerAddedConn = Core.Connect(Players.PlayerAdded, function(newPlayer)
        Core.Tasks.spawn(function()
            task.wait(1)
            for _, other in ipairs(Players:GetPlayers()) do
                TryAddFriendPair(other, newPlayer)
                task.wait(0.03)
            end
        end)
    end)
    TrackConnection(State.Runtime.FriendPlayerAddedConn)

    State.Runtime.FriendPlayerRemovingConn = Core.Connect(Players.PlayerRemoving, function(player)
        RemovePlayerFromFriendData(player)
    end)
    TrackConnection(State.Runtime.FriendPlayerRemovingConn)
end

local function StopFriendViewer()
    State.Settings.FriendViewerEnabled = false
    if State.Runtime.FriendPlayerAddedConn then
        State.Runtime.FriendPlayerAddedConn:Disconnect()
        State.Runtime.FriendPlayerAddedConn = nil
    end
    if State.Runtime.FriendPlayerRemovingConn then
        State.Runtime.FriendPlayerRemovingConn:Disconnect()
        State.Runtime.FriendPlayerRemovingConn = nil
    end
    ClearAllFriendData()
end

-- ============= END FRIEND VIEWER SYSTEM =============

-- ════════════════════════════════════════════════════════════════════════════
-- KNIFE TRAJECTORY + BULLET TRACER (свой пистолет + shootMurderer)
-- ════════════════════════════════════════════════════════════════════════════
local ToggleBulletTracers  -- forward declaration: используется в Handlers (~стр. 7522)

do
    local TRACER_COUNT = 3

    local function SpawnTracers(startPos, endPos, duration)
        if not State.Settings.BulletTracersEnabled then return end
        for i = 1, TRACER_COUNT do
            CreateTracer(startPos, endPos, duration or 2)
        end
    end

    -- ─── KNIFE: подписка на серверную Model "ThrowingKnife" в Workspace ──────────
    local function HandleKnifeTrajectory(obj)
        if not State.Settings.BulletTracersEnabled then return end
        if not obj or obj.Name ~= "ThrowingKnife" or not obj:IsA("Model") then return end

        local bladePos = obj:WaitForChild("BladePosition", 0.3)
        if not bladePos or not bladePos:IsA("BasePart") then return end

        local throwDir = obj:FindFirstChild("ThrowDirection")
        if not throwDir or not throwDir:IsA("Vector3Value") then return end

        local dir = throwDir.Value
        if dir.Magnitude == 0 then return end

        local startPos = bladePos.Position
        local endPos = startPos + dir.Unit * 100

        SpawnTracers(startPos, endPos, 2)
    end

    -- ─── BULLET (свой пистолет): Tool.Activated на собственном Gun ───────────────
    local function IsGunTool(tool)
        if not tool or not tool:IsA("Tool") then return false end
        local events = tool:FindFirstChild("Events")
        local remote = (events and events:FindFirstChild("Shoot"))
            or tool:FindFirstChild("Shoot")
            or (tool:FindFirstChild("KnifeServer") and tool.KnifeServer:FindFirstChild("ShootGun"))
        return remote and remote:IsA("RemoteEvent")
    end

    local ownToolConnections = {}  -- { [Tool] = Activated connection }
    local lastGunTracerTime = 0

    local function ConnectOwnGun(tool)
        if not IsGunTool(tool) then return end
        if ownToolConnections[tool] then return end
        local conn = Core.Connect(tool.Activated, function()
            if not State.Settings.BulletTracersEnabled then return end
            local now = tick()
            if now - lastGunTracerTime < (State.Settings.ShootCooldown or 3) then return end
            lastGunTracerTime = now
            local handle = tool:FindFirstChild("Handle")
            if not handle then return end
            local mouse = LocalPlayer:GetMouse()
            if not mouse then return end
            SpawnTracers(handle.Position, mouse.Hit.Position, 2)
        end)
        ownToolConnections[tool] = conn
        TrackConnection(conn)
    end

    local function ClearOwnToolConnections()
        for _, conn in pairs(ownToolConnections) do
            pcall(function() conn:Disconnect() end)
        end
        ownToolConnections = {}
    end

    local function HookOwnContainer(container)
        if not container then return end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then ConnectOwnGun(tool) end
        end
        local conn = Core.Connect(container.ChildAdded, function(child)
            if child:IsA("Tool") then
                task.wait(0.1)  -- ждём пока в Tool догрузится Events.Shoot
                ConnectOwnGun(child)
            end
        end)
        TrackConnection(conn)
    end

    local knifeTrajectoryConn = nil
    local ownCharAddedConn = nil

    local function CleanupTracers()
        if knifeTrajectoryConn then
            pcall(function() knifeTrajectoryConn:Disconnect() end)
            knifeTrajectoryConn = nil
        end
        if ownCharAddedConn then
            pcall(function() ownCharAddedConn:Disconnect() end)
            ownCharAddedConn = nil
        end
        ClearOwnToolConnections()

        for _, tracer in ipairs(State.Runtime.TracersList) do
            pcall(function()
                tracer.beam:Destroy()
                tracer.att0:Destroy()
                tracer.att1:Destroy()
            end)
        end
        State.Runtime.TracersList = {}
    end

    ToggleBulletTracers = function(enabled)
        State.Settings.BulletTracersEnabled = enabled

        if enabled then
            -- Knife: Workspace.ChildAdded
            if knifeTrajectoryConn then pcall(function() knifeTrajectoryConn:Disconnect() end) end
            knifeTrajectoryConn = Core.Connect(Workspace.ChildAdded, function(obj)
                Core.Tasks.spawn(HandleKnifeTrajectory, obj)
            end)
            TrackConnection(knifeTrajectoryConn)

            -- Bullet: только свой Gun в Character / Backpack
            if LocalPlayer.Character then HookOwnContainer(LocalPlayer.Character) end
            local bp = LocalPlayer:FindFirstChild("Backpack")
            if bp then HookOwnContainer(bp) end

            -- Респавн — переподписаться на новый Character
            if ownCharAddedConn then pcall(function() ownCharAddedConn:Disconnect() end) end
            ownCharAddedConn = Core.Connect(LocalPlayer.CharacterAdded, function(character)
                task.wait(0.2)
                HookOwnContainer(character)
            end)
            TrackConnection(ownCharAddedConn)
        else
            CleanupTracers()
        end
    end
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 4: SYSTEM FUNCTIONS
-- ══════════════════════════════════════════════════════════════════════════════

-- CleanupMemory() - Очистка при респавне
local function CleanupMemory()
    -- Очистка очереди уведомлений (безопасно)
    State.Runtime.NotificationQueue = {}
    State.Runtime.CurrentNotification = nil

    -- Очистка coin blacklist (безопасно - относится к Auto Farm)
    State.Cache.CoinBlacklist = {}

end

local function cleanupSession()
    -- Модули восстанавливают освещение, рендер и приостановленные соединения.
    if State.Runtime.OptimizationModule then pcall(State.Runtime.OptimizationModule.Destroy) end
    if State.Runtime.VisualsModule then pcall(State.Runtime.VisualsModule.Destroy) end
    if State.Runtime.MovementModule then pcall(State.Runtime.MovementModule.Destroy) end


    -- Восстанавливаем настоящую позицию до остановки остальных систем.
    -- Паузу от флинга сбрасываем первой: иначе остановка флинга включит Fake Position обратно.
    if State.Runtime.ForgetFakePositionPause then pcall(State.Runtime.ForgetFakePositionPause) end
    if State.Runtime.SetFakeLag then pcall(State.Runtime.SetFakeLag, false) end
    if State.Runtime.SetFakePosition then pcall(State.Runtime.SetFakePosition, false) end
    pcall(StopPingChams)

    if Core.StopFeatures then Core.StopFeatures() end
    if State.Runtime.NetBoostReset then pcall(State.Runtime.NetBoostReset) end

    pcall(function()
        -- гасим Role ESP
        if State.Runtime.RoleCheckLoop then
            State.Runtime.RoleCheckLoop:Disconnect()
            State.Runtime.RoleCheckLoop = nil
        end

        -- уничтожаем хайлайты игроков
        for player, highlight in pairs(State.Cache.PlayerHighlights) do
            pcall(function()
                if highlight and highlight.Parent then
                    highlight:Destroy()
                end
            end)
            State.Cache.PlayerHighlights[player] = nil
        end

        -- очищаем Gun ESP
        for _, espData in pairs(State.Cache.GunCache) do
            pcall(function()
                if espData.highlight then espData.highlight:Destroy() end
                if espData.billboard then espData.billboard:Destroy() end
            end)
        end
        State.Cache.GunCache = {}
        State.Runtime.CurrentGunDrop = nil
                -- Player Nicknames ESP
        for player, espData in pairs(State.Cache.PlayerNicknamesCache) do
            pcall(function()
                if espData.billboard then
                    espData.billboard:Destroy()
                end
            end)
        end
        State.Cache.PlayerNicknamesCache = {}

        -- Friend Viewer cleanup
        if State.Runtime.FriendPlayerAddedConn then pcall(function() State.Runtime.FriendPlayerAddedConn:Disconnect() end); State.Runtime.FriendPlayerAddedConn = nil end
        if State.Runtime.FriendPlayerRemovingConn then pcall(function() State.Runtime.FriendPlayerRemovingConn:Disconnect() end); State.Runtime.FriendPlayerRemovingConn = nil end
        for key, data in pairs(State.Runtime.FriendBeams) do
            pcall(function() data.beam:Destroy(); data.att0:Destroy(); data.att1:Destroy() end)
        end
        State.Runtime.FriendBeams = {}
        State.Runtime.FriendPairs = {}
        State.Cache.FriendPairCheck = {}
        State.Settings.FriendViewerEnabled = false
    end)

    if Core.CleanupGUI then Core.Try("GUI", Core.CleanupGUI) end

    -- Остановка Trolling threads
    pcall(function()
        if State.Runtime.OrbitThread then
            task.cancel(State.Runtime.OrbitThread)
            State.Runtime.OrbitThread = nil
        end
        if State.Runtime.LoopFlingThread then
            task.cancel(State.Runtime.LoopFlingThread)
            State.Runtime.LoopFlingThread = nil
        end
        if State.Runtime.BlockPathThread then
            task.cancel(State.Runtime.BlockPathThread)
            State.Runtime.BlockPathThread = nil
        end
        State.Settings.OrbitEnabled = false
        State.Settings.LoopFlingEnabled = false
        State.Settings.BlockPathEnabled = false
    end)

    -- Гасим авто-реджойн/реконнект напрямую, а не через HandleAutoRejoin/
    -- HandleAutoReconnect: они объявлены ниже по файлу, здесь это ещё nil, и
    -- вызов молча съедался pcall'ом — после Shutdown коннект оставался жив и
    -- следующий ErrorPrompt дёргал телепорт из уже выгруженного скрипта.
    pcall(function()
        State.Settings.AutoRejoinEnabled = false
        if Core.AutoRejoinConnection then
            pcall(function() Core.AutoRejoinConnection:Disconnect() end)
            Core.AutoRejoinConnection = nil
        end

        State.Settings.AutoReconnectEnabled = false
        if State.Runtime.ReconnectThread then
            pcall(function() task.cancel(State.Runtime.ReconnectThread) end)
            State.Runtime.ReconnectThread = nil
        end
    end)

    -- Очистка всех general connections
    pcall(function()
        for _, connection in ipairs(State.Runtime.Connections) do
            if connection and connection.Connected then
                connection:Disconnect()
            end
        end
        State.Runtime.Connections = {}
    end)

    -- Восстановление FallenPartsDestroyHeight
    pcall(function()
        Workspace.FallenPartsDestroyHeight = State.Runtime.FallenPartsDestroyHeight
    end)

    -- Очистка Keybinds
    pcall(function()
        for key, _ in pairs(State.Settings.Keybinds) do
            State.Settings.Keybinds[key] = Enum.KeyCode.Unknown
        end
    end)

    -- Очистка UI State
    State.Runtime.ClickTPActive = false
    State.Runtime.ListeningForKeybind = nil

    -- Очистка Notifications
    State.Runtime.NotificationQueue = {}
    State.Runtime.CurrentNotification = nil

    -- Очистка Blacklist
    State.Cache.CoinBlacklist = {}

    -- Очистка Role detection
    State.Runtime.PreviousMurderer = nil
    State.Runtime.PreviousSheriff = nil
    State.Runtime.HeroSent = false
    State.Runtime.RoundStart = true
    State.Runtime.RoundActive = false
    pcall(function()
        if State.Runtime.UIElements.NotificationGui then
            State.Runtime.UIElements.NotificationGui:Destroy()
            State.Runtime.UIElements.NotificationGui = nil
            State.Runtime.UIElements.NotificationContainer = nil
        end

        for name, ui in pairs(State.Runtime.UIElements) do
            if typeof(ui) == "Instance" and ui.Parent then
                ui:Destroy()
            end
            State.Runtime.UIElements[name] = nil
        end
    end)

end
Core.Cleanup = cleanupSession
local FullShutdown = Core.Shutdown



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
    uiOnlyActive = false,
    savedUIOnlyState = {},
}

-- ==============================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ==============================

-- Функция применения UI оптимизации
local function ApplyUIOptimization()
    OptimizationState.CoreGui = OptimizationState.CoreGui or {}
    for _, guiType in ipairs(Enum.CoreGuiType:GetEnumItems()) do
        if guiType ~= Enum.CoreGuiType.All then
            pcall(function()
                if OptimizationState.CoreGui[guiType] == nil then OptimizationState.CoreGui[guiType] = Core.StarterGui:GetCoreGuiEnabled(guiType) end
                Core.StarterGui:SetCoreGuiEnabled(guiType, false)
            end)
        end
    end
    pcall(function()
        if OptimizationState.Topbar == nil then OptimizationState.Topbar = Core.StarterGui:GetCore("TopbarEnabled") end
        Core.StarterGui:SetCore("TopbarEnabled", false)
    end)

    pcall(function()
        local targetTable = OptimizationState.savedUIOnlyState
        for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui ~= State.Runtime.UIElements.MainGui then
                if targetTable[gui] == nil then
                    targetTable[gui] = gui.Enabled
                end
                gui.Enabled = false
            end
        end
    end)
end

-- ОБРАБОТЧИК РЕСПАВНА
Core.Connect(LocalPlayer.CharacterAdded, function(character)
    task.wait(0.5)

    if OptimizationState.uiOnlyActive then ApplyUIOptimization() end
end)

-- ==============================
-- AFK MODE FUNCTIONS
-- ==============================

-- No Render управляет только 3D: интерфейс и настройки World остаются доступны.
Core.Movement.EnableMaxOptimization = function()
    if State.Runtime.OptimizationModule then return State.Runtime.OptimizationModule.Set("NoRender", true) end
    State.Settings.AFKModeEnabled = false
    warn("[Violite] Optimization module unavailable")
end

Core.Movement.DisableMaxOptimization = function()
    if State.Runtime.OptimizationModule then return State.Runtime.OptimizationModule.Set("NoRender", false) end
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    State.Settings.AFKModeEnabled = false
end

Core.Movement.EnableUIOnly = function()
    if OptimizationState.uiOnlyActive then return end
    OptimizationState.uiOnlyActive = true
    OptimizationState.savedUIOnlyState = {}
    ApplyUIOptimization()
end

Core.Movement.DisableUIOnly = function()
    if not OptimizationState.uiOnlyActive then return end
    OptimizationState.uiOnlyActive = false

    for guiType, enabled in pairs(OptimizationState.CoreGui or {}) do
        pcall(function() Core.StarterGui:SetCoreGuiEnabled(guiType, enabled) end)
    end
    OptimizationState.CoreGui = {}
    if OptimizationState.Topbar ~= nil then
        pcall(function() Core.StarterGui:SetCore("TopbarEnabled", OptimizationState.Topbar) end)
        OptimizationState.Topbar = nil
    end

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

Core.Movement.EnableFPSBoost = function()
    if State.Runtime.OptimizationModule then return State.Runtime.OptimizationModule.Boost() end
    warn("[Violite] Optimization module unavailable")
end

-- Частота отправки физики. По умолчанию клиент шлёт 15 пакетов/с, а другие клиенты
-- достраивают нас между пакетами кривой по скорости — любая подмена (скорость,
-- позиция) выглядит дрожью. На 60 пакетах дрожь спуфа ~в 4 раза меньше
-- (замер на двух клиентах: P95 0.48 → 0.11 stud). Holders — функции, которым
-- сейчас нужна повышенная частота; исходное значение возвращается после последней.
do
    local boost = {Holders = {}, Original = nil, Active = false, Rate = "60", Flag = "S2PhysicsSenderRate"}

    local function apply()
        local want = next(boost.Holders) ~= nil
        if want == boost.Active then return end
        if type(setfflag) ~= "function" or type(getfflag) ~= "function" then return end
        if want then
            local ok, current = pcall(getfflag, boost.Flag)
            if not ok or current == nil then return end
            boost.Original = tostring(current)
            if pcall(setfflag, boost.Flag, boost.Rate) then boost.Active = true end
        else
            pcall(setfflag, boost.Flag, boost.Original or "15")
            boost.Active = false
        end
    end

    State.Runtime.NetBoost = function(reason, enabled)
        boost.Holders[reason] = enabled and true or nil
        apply()
    end

    -- Выгрузка скрипта: вернуть частоту, даже если кто-то не успел отпустить.
    State.Runtime.NetBoostReset = function()
        table.clear(boost.Holders)
        apply()
        State.Runtime.PhysicsNudgeReset()
    end
end

-- Стоящего персонажа Roblox не отправляет: подмена CFrame/скорости на Heartbeat до
-- сети не доходит (замер: Orbit на месте у наблюдателя с радиусом 0.00). Отправщик
-- судит по физике, поэтому в физику подмешиваем знакопеременные ±0.05 studs/s по Y —
-- в сумме ноль, а отправка живая (с этим Orbit на месте виден, радиус 2.2).
-- NetworkIsSleeping тут не помогает: у стоящего персонажа он и так false.
do
    local nudge = {Holders = {}, Sign = 1, Connection = nil}

    local function update()
        local want = next(nudge.Holders) ~= nil
        if want and not nudge.Connection then
            nudge.Connection = Core.Connect(RunService.Stepped, function()
                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if not root or root.Anchored then return end
                nudge.Sign = -nudge.Sign
                root.AssemblyLinearVelocity += Vector3.yAxis * (0.05 * nudge.Sign)
            end)
        elseif not want and nudge.Connection then
            nudge.Connection:Disconnect()
            nudge.Connection = nil
        end
    end

    State.Runtime.PhysicsNudge = function(reason, enabled)
        nudge.Holders[reason] = enabled and true or nil
        update()
    end

    State.Runtime.PhysicsNudgeReset = function()
        table.clear(nudge.Holders)
        update()
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 5: CHARACTER FUNCTIONS
-- ══════════════════════════════════════════════════════════════════════════════

-- Скорость ходьбы больше не меняем через WalkSpeed — см. Speed (блок Fly/Speed)

-- ApplyJumpPower() - Установка прыжка
function Core.Movement.ApplyJumpPower(power)
    State.Runtime.SettingsDirty = true
    State.Settings.JumpPower = power
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        Core.Remember(humanoid, "JumpPower")
        humanoid.JumpPower = power
        State.Settings.JumpPower = power
    end
end

-- ApplyMaxCameraZoom() - Установка зума
function Core.Movement.ApplyMaxCameraZoom(distance)
    State.Runtime.SettingsDirty = true
    LocalPlayer.CameraMaxZoomDistance = distance
    State.Settings.MaxCameraZoom = distance
end

-- ApplyCharacterSettings() - Применение всех настроек
function Core.Movement.ApplyCharacterSettings()
    Core.Movement.ApplyJumpPower(State.Settings.JumpPower)
    Core.Movement.ApplyMaxCameraZoom(State.Settings.MaxCameraZoom)
end

-- ApplyFOV() - Плавное изменение FOV
function Core.Movement.ApplyFOV(fov)
    State.Runtime.SettingsDirty = true
    local camera = Workspace.CurrentCamera
    if camera then
        Core.Remember(camera, "FieldOfView")
        Core.Tween(camera, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
            FieldOfView = fov
        }):Play()
        State.Settings.CameraFOV = fov
    end
end

-- Aspect Ratio (перенос из стороннего скрипта): сразу после обновления камеры
-- домножаем её CFrame на сжатие по вертикали — картинка растягивается, как при
-- «stretched res». Look/Right-векторы камеры при этом не меняются. Смена
-- значения и выключение идут плавно; когда коэффициент вернулся к 1 — отвязываемся.
do
    local AR = CONFIG.AspectRatio
    local current = 1
    local bound = false
    local lastBase, lastOut = nil, nil   -- исходный и выставленный нами CFrame камеры

    -- ESP-подписи (наши BillboardGui: ники, GUN, Trap, Ping) рисуются через ту же
    -- растянутую камеру: шрифт сплющивается, StudsOffset сжимается и подпись
    -- съезжает с головы. Пока растяжение активно, свои билборды прячем нулевым
    -- Size с обрезкой (Enabled остаётся за логикой ESP; PlayerToHideFrom и
    -- MaxDistance для своего клиента не прячут — проверено) и рисуем копии в ScreenGui над
    -- точкой, спроецированной уже растянутой камерой (WorldToViewportPoint её
    -- учитывает — сверено с ручной проекцией).
    local overlay, mirrors, nextScan = nil, {}, 0

    local function guiObjects(root)
        local list = {}
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("GuiObject") then table.insert(list, d) end
        end
        return list
    end

    local function releaseMirror(billboard)
        local mirror = mirrors[billboard]
        if not mirror then return end
        mirrors[billboard] = nil
        pcall(function() mirror.Frame:Destroy() end)
        pcall(function()
            billboard.Size = mirror.Size
            billboard.ClipsDescendants = mirror.Clips
        end)
    end

    local function releaseAll()
        for billboard in pairs(mirrors) do releaseMirror(billboard) end
        if overlay then pcall(function() overlay:Destroy() end); overlay = nil end
    end

    local function buildMirror(billboard)
        if not overlay or not overlay.Parent then
            overlay = Core.New("ScreenGui", {Name = "Violite_AspectESP", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = -1})
            local ok = pcall(function() overlay.Parent = gethui() end)
            if not ok or not overlay.Parent then overlay.Parent = CoreGui end
        end
        local frame = Core.New("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Parent = overlay})
        for _, child in ipairs(billboard:GetChildren()) do
            if child:IsA("GuiObject") then child:Clone().Parent = frame end
        end
        mirrors[billboard] = {Frame = frame, Source = guiObjects(billboard), Copy = guiObjects(frame),
            Size = billboard.Size, Clips = billboard.ClipsDescendants}
        frame.Size = UDim2.fromOffset(billboard.Size.X.Offset, billboard.Size.Y.Offset)
        -- Нулевой размер + обрезка: без обрезки текст вылезает за нулевую рамку
        billboard.Size = UDim2.new()
        billboard.ClipsDescendants = true
    end

    local function updateMirrors(camera)
        local now = os.clock()
        if now >= nextScan then
            nextScan = now + 0.5
            for object in pairs(Core.Objects) do
                if typeof(object) == "Instance" and object:IsA("BillboardGui") and not mirrors[object] and object.Parent then
                    pcall(buildMirror, object)
                end
            end
        end
        local up, right = camera.CFrame.UpVector.Unit, camera.CFrame.RightVector.Unit
        for billboard, mirror in pairs(mirrors) do
            local adornee = billboard.Adornee or billboard.Parent
            local anchor = adornee and ((adornee:IsA("Attachment") and adornee.WorldPosition)
                or (adornee:IsA("BasePart") and adornee.Position))
            -- Удалён / перестроен — отпускаем, пересоберём при следующем скане
            if not billboard.Parent or #mirror.Source ~= #guiObjects(billboard) then
                releaseMirror(billboard)
            else
                local visible = billboard.Enabled and anchor ~= nil
                if visible then
                    local offset = billboard.StudsOffset
                    local point = anchor + billboard.StudsOffsetWorldSpace + right * offset.X + up * offset.Y
                    local screen, inFront = camera:WorldToViewportPoint(point)
                    visible = inFront and screen.Z <= billboard.MaxDistance
                    if visible then
                        mirror.Frame.Position = UDim2.fromOffset(screen.X, screen.Y)
                        for i, source in ipairs(mirror.Source) do
                            local copy = mirror.Copy[i]
                            if copy then
                                copy.Visible = source.Visible
                                if source:IsA("TextLabel") then
                                    copy.Text = source.Text
                                    copy.TextColor3 = source.TextColor3
                                    copy.TextTransparency = source.TextTransparency
                                end
                            end
                        end
                    end
                end
                mirror.Frame.Visible = visible
            end
        end
    end

    local function unbind()
        if bound then
            pcall(function() RunService:UnbindFromRenderStep(AR.BindName) end)
            bound = false
        end
        -- Статичная камера осталась бы сжатой — возвращаем исходную матрицу
        local camera = Workspace.CurrentCamera
        if camera and lastOut and camera.CFrame == lastOut then camera.CFrame = lastBase end
        lastBase, lastOut = nil, nil
        releaseAll()
    end

    local function step(dt)
        local goal = State.Settings.AspectRatioEnabled and State.Settings.AspectRatioValue or 1
        current += (goal - current) * (1 - math.exp(-AR.TweenRate * dt))
        if not State.Settings.AspectRatioEnabled and math.abs(current - 1) < 1e-3 then
            current = 1
            unbind()
            return
        end
        local camera = Workspace.CurrentCamera
        if camera then
            -- Камеру этот кадр никто не обновил (Scriptable, спектатор) — сжимаем
            -- исходную матрицу, а не уже сжатую, иначе масштаб копится каждый кадр
            local base = camera.CFrame
            if lastOut and base == lastOut then base = lastBase end
            camera.CFrame = base * CFrame.new(0, 0, 0, 1, 0, 0, 0, current, 0, 0, 0, 1)
            lastBase, lastOut = base, camera.CFrame
            local ok, err = pcall(updateMirrors, camera)
            if not ok then warn("[Aspect Ratio] ESP: " .. tostring(err)) end
        end
    end

    Core.Movement.SetAspectRatio = function(enabled, instant)
        State.Settings.AspectRatioEnabled = enabled == true
        if instant and not State.Settings.AspectRatioEnabled then
            current = 1
            unbind()
            return
        end
        if not bound then
            bound = pcall(function()
                RunService:BindToRenderStep(AR.BindName, Enum.RenderPriority.Camera.Value + 1, step)
            end)
            if not bound then
                State.Settings.AspectRatioEnabled = false
                warn("[Violite] Aspect Ratio: BindToRenderStep недоступен")
            end
        end
    end

    Core.Movement.SetAspectRatioValue = function(value)
        State.Settings.AspectRatioValue = math.clamp(tonumber(value) or 1, AR.Range[1], AR.Range[2])
    end
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 6: NOTIFICATION SYSTEM
-- ══════════════════════════════════════════════════════════════════════════════
-- Тосты в стиле основного GUI (Vercel Geist): тёмная карточка с обводкой, иконка
-- типа из пака geist, BuilderSans 500, полоска таймера. Сигнатура прежняя —
-- ShowNotification(richText, defaultColor): тип определяем по тексту, старые
-- rgb-цвета из rich text переводим в палитру Geist (CONFIG.Notification.RichPalette).

local Notify = {
    Items = {},       -- активные тосты, старые первыми
    Order = 0,
    FontCache = nil,
}

function Notify.font(weight)
    Notify.FontCache = Notify.FontCache or {}
    if Notify.FontCache[weight] == nil then
        local ok, face = pcall(function()
            return Font.new("rbxasset://fonts/families/BuilderSans.json", weight, Enum.FontStyle.Normal)
        end)
        Notify.FontCache[weight] = ok and face or false
    end
    return Notify.FontCache[weight] or nil
end

-- Иконка из пака geist, который грузит основной GUI (кэш в getgenv); nil — пака нет
function Notify.icon(name)
    local ok, data = pcall(function()
        local pack = getgenv().Violite_GeistIcons
        local entry = pack and pack.Icons[name]
        local sheet = entry and (pack.Spritesheets[tostring(entry.Image)] or pack.Spritesheets[entry.Image])
        if type(sheet) ~= "string" then return nil end
        return { Image = sheet, Offset = entry.ImageRectPosition, Size = entry.ImageRectSize }
    end)
    return ok and data or nil
end

function Notify.plain(richText)
    return (tostring(richText or ""):gsub("<[^>]->", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Старые яркие цвета из вызовов → токены Geist; неизвестные оставляем как есть
function Notify.restyle(richText)
    local palette = CONFIG.Notification.RichPalette
    return (tostring(richText or ""):gsub('color="rgb%(([%d%s,]+)%)"', function(rgb)
        local key = rgb:gsub("%s", "")
        local color = palette[key]
        if not color then return nil end
        return string.format('color="rgb(%d,%d,%d)"', math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
    end))
end

-- Тип по смыслу текста; для обычных сообщений иконку красим первым цветом из текста
function Notify.kind(richText, defaultColor)
    local plain = Notify.plain(richText)
    local lower = plain:lower()
    local kinds = CONFIG.Notification.Kinds
    if lower:find("^error") or lower:find("failed") or lower:find("stopped:") or defaultColor == CONFIG.Colors.Red then
        return kinds.Error
    elseif lower:find("^warning") or lower:find("^wait") then
        return kinds.Warning
    elseif plain:find("%f[%w]OFF%f[%W]") or plain:find("OFF$") then
        return kinds.Off
    elseif plain:find("%f[%w]ON%f[%W]") or plain:find("ON$") or lower:find("^success") or lower:find("^ready")
        or lower:find("^shot fired") or lower:find("picked up") then
        return kinds.Success
    end
    local tint
    local first = tostring(richText or ""):match('color="rgb%(([%d%s,]+)%)"')
    if first then
        local key = first:gsub("%s", "")
        if key ~= "220,220,220" then
            local color = CONFIG.Notification.RichPalette[key]
            if color then
                tint = color
            else
                local r, g, b = key:match("(%d+),(%d+),(%d+)")
                if r then tint = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end
            end
        end
    end
    return { Icon = kinds.Info.Icon, Color = tint or kinds.Info.Color }
end

-- CreateNotificationUI() - Создание UI уведомлений
local function CreateNotificationUI()
    local parent = CoreGui
    pcall(function()
        if gethui then parent = gethui() end
    end)
    local cfg = CONFIG.Notification
    local notifGui = Core.New("ScreenGui")
    notifGui.Name = "MM2_Notifications"
    notifGui.ResetOnSpawn = false
    notifGui.DisplayOrder = 100
    notifGui.IgnoreGuiInset = true
    notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    notifGui.Parent = parent

    local container = Core.New("Frame")
    container.Name = "NotificationContainer"
    container.BackgroundTransparency = 1
    container.AnchorPoint = Vector2.new(0.5, 0)
    container.Position = UDim2.new(0.5, 0, 0, cfg.TopOffset)
    container.Size = UDim2.new(0, cfg.MaxWidth, 1, -cfg.TopOffset)
    container.Parent = notifGui

    local list = Core.New("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, cfg.Gap)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.VerticalAlignment = Enum.VerticalAlignment.Top
    list.Parent = container

    State.Runtime.UIElements.NotificationGui = notifGui
    State.Runtime.UIElements.NotificationContainer = container
end

-- Размер под текст: BuilderSans не поддерживается GetTextSize, поэтому меряем через
-- GetTextBoundsAsync, а при ошибке — по Gotham того же кегля
function Notify.measure(plain, maxTextWidth)
    local cfg = CONFIG.Notification
    local size
    pcall(function()
        local params = Instance.new("GetTextBoundsParams")
        params.Text = plain
        params.Font = Notify.font(Enum.FontWeight.Medium)
        params.Size = cfg.TextSize
        params.Width = maxTextWidth
        size = game:GetService("TextService"):GetTextBoundsAsync(params)
    end)
    if not size then
        size = game:GetService("TextService"):GetTextSize(plain, cfg.TextSize, Enum.Font.GothamMedium,
            Vector2.new(maxTextWidth, 1000))
    end
    return size
end

function Notify.dismiss(item)
    if item.Closing then return end
    item.Closing = true
    local cfg = CONFIG.Notification
    for index, other in ipairs(Notify.Items) do
        if other == item then table.remove(Notify.Items, index); break end
    end
    if item.Timer then item.Timer:Cancel() end
    local out = TweenInfo.new(cfg.FadeTime, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    Core.Tween(item.Group, out, { GroupTransparency = 1, Position = UDim2.new(0, 0, 0, -cfg.SlideOffset) }):Play()
    -- Слот схлопывается следом — стопка съезжает плавно, а не прыжком
    local collapse = Core.Tween(item.Slot, TweenInfo.new(cfg.FadeTime, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
        { Size = UDim2.new(0, item.Width, 0, 0) })
    collapse:Play()
    Core.Tasks.spawn(function()
        collapse.Completed:Wait()
        if item.Slot and item.Slot.Parent then item.Slot:Destroy() end
    end)
end

-- Полоска таймера и отложенное закрытие; повторный вызов перезапускает отсчёт
function Notify.arm(item)
    local cfg = CONFIG.Notification
    item.Serial = (item.Serial or 0) + 1
    local serial = item.Serial
    if item.Timer then item.Timer:Cancel() end
    item.Progress.Size = UDim2.new(1, 0, 0, cfg.ProgressHeight)
    item.Timer = Core.Tween(item.Progress, TweenInfo.new(cfg.Duration, Enum.EasingStyle.Linear),
        { Size = UDim2.new(0, 0, 0, cfg.ProgressHeight) })
    item.Timer:Play()
    Core.Tasks.delay(cfg.Duration, function()
        if item.Serial == serial then Notify.dismiss(item) end
    end)
end

-- ShowNotification() - Показ уведомления
local function ShowNotification(richText, defaultColor)
    if not State.Settings.NotificationsEnabled then return end

    Core.Tasks.spawn(function()
        if not State.Runtime.UIElements.NotificationGui or not State.Runtime.UIElements.NotificationGui.Parent then
            CreateNotificationUI()
        end
        local container = State.Runtime.UIElements.NotificationContainer
        if not container then return end
        local cfg = CONFIG.Notification
        local text = Notify.restyle(richText)
        local plain = Notify.plain(richText)

        -- Тот же текст уже на экране — счётчик вместо дубля
        for _, item in ipairs(Notify.Items) do
            if item.Plain == plain and not item.Closing then
                item.Count += 1
                item.Badge.Text = "×" .. item.Count
                item.Badge.Visible = true
                Notify.arm(item)
                return
            end
        end
        while #Notify.Items >= cfg.MaxVisible do
            Notify.dismiss(Notify.Items[1])
        end

        local kind = Notify.kind(richText, defaultColor)
        local badgeRoom = 30
        local chrome = cfg.PaddingX * 2 + cfg.IconSize + cfg.IconGap + badgeRoom
        local bounds = Notify.measure(plain, cfg.MaxWidth - chrome)
        local width = math.clamp(math.ceil(bounds.X) + chrome, cfg.MinWidth, cfg.MaxWidth)
        local height = math.max(cfg.MinHeight, math.ceil(bounds.Y) + cfg.PaddingY * 2)

        Notify.Order += 1
        local slot = Core.New("Frame", {
            Name = "NotificationItem",
            BackgroundTransparency = 1,
            Size = UDim2.new(0, width, 0, 0),
            LayoutOrder = -Notify.Order, -- новые сверху
        }, container)

        -- CanvasGroup гасит карточку целиком: фон, обводку, текст и иконку одним tween
        local group = Core.New("CanvasGroup", {
            BackgroundTransparency = 1,
            GroupTransparency = 1,
            Position = UDim2.new(0, 0, 0, -cfg.SlideOffset),
            Size = UDim2.new(1, 0, 0, height),
        }, slot)
        -- Карточка на 1px внутри группы — обводка рисуется наружу и иначе обрежется
        local card = Core.New("Frame", {
            BackgroundColor3 = cfg.Background,
            BackgroundTransparency = cfg.BackgroundTransparency,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 1, 0, 1),
            Size = UDim2.new(1, -2, 1, -2),
        }, group)
        Core.New("UICorner", { CornerRadius = UDim.new(0, cfg.Radius) }, card)
        Core.New("UIStroke", {
            Color = cfg.Border,
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, card)

        local iconHolder = Core.New("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, cfg.PaddingX - 1, 0.5, 0),
            Size = UDim2.new(0, cfg.IconSize, 0, cfg.IconSize),
        }, card)
        local sprite = Notify.icon(kind.Icon)
        if sprite then
            Core.New("ImageLabel", {
                BackgroundTransparency = 1,
                Image = sprite.Image,
                ImageRectOffset = sprite.Offset,
                ImageRectSize = sprite.Size,
                ImageColor3 = kind.Color,
                Size = UDim2.new(1, 0, 1, 0),
            }, iconHolder)
        else
            -- Пак ещё не загружен (GUI не открывался) — цветная точка того же типа
            local dot = Core.New("Frame", {
                BackgroundColor3 = kind.Color,
                BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 8, 0, 8),
            }, iconHolder)
            Core.New("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
        end

        local textX = cfg.PaddingX - 1 + cfg.IconSize + cfg.IconGap
        local label = Core.New("TextLabel", {
            BackgroundTransparency = 1,
            RichText = true,
            Text = text,
            TextSize = cfg.TextSize,
            TextColor3 = cfg.Text,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Position = UDim2.new(0, textX, 0, 0),
            Size = UDim2.new(1, -(textX + cfg.PaddingX + badgeRoom - 4), 1, 0),
        }, card)
        local medium = Notify.font(Enum.FontWeight.Medium)
        if medium then label.FontFace = medium else label.Font = Enum.Font.GothamMedium end

        local badge = Core.New("TextLabel", {
            BackgroundTransparency = 1,
            Visible = false,
            Text = "×1",
            TextSize = cfg.TextSize - 2,
            TextColor3 = cfg.TextDark,
            TextXAlignment = Enum.TextXAlignment.Right,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -cfg.PaddingX, 0.5, 0),
            Size = UDim2.new(0, badgeRoom, 0, 18),
        }, card)
        local regular = Notify.font(Enum.FontWeight.Regular)
        if regular then badge.FontFace = regular else badge.Font = Enum.Font.Gotham end

        local track = Core.New("Frame", {
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, cfg.Radius, 1, 0),
            Size = UDim2.new(1, -cfg.Radius * 2, 0, cfg.ProgressHeight),
        }, card)
        local progress = Core.New("Frame", {
            BackgroundColor3 = kind.Color,
            BackgroundTransparency = cfg.ProgressTransparency,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, cfg.ProgressHeight),
        }, track)

        local item = {
            Slot = slot, Group = group, Progress = progress, Badge = badge,
            Plain = plain, Count = 1, Width = width,
        }
        table.insert(Notify.Items, item)

        local enter = TweenInfo.new(cfg.EnterTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        Core.Tween(slot, enter, { Size = UDim2.new(0, width, 0, height) }):Play()
        Core.Tween(group, enter, { GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0) }):Play()
        Notify.arm(item)
    end)
end

----------------------------------------------------------------
-- ESP: роли + GunESP
----------------------------------------------------------------

local function SetupPlayerDataListener()
    local success, remotes = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 5)
    end)

    if not success or not remotes then return end

    local gameplay = remotes:FindFirstChild("Gameplay")
    if not gameplay then return end

    local dataChanged = gameplay:FindFirstChild("PlayerDataChanged")
    if not dataChanged then return end

    Core.Connect(dataChanged.OnClientEvent, function(data)
        State.Cache.PlayerData = data or {}
    end)
end

-- CreateHighlight() - создание Highlight для персонажа
local function CreateHighlight(adornee, color)
    if not adornee or not adornee.Parent then return nil end

    local highlight = Core.New("Highlight")
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
        if State.Cache.PlayerHighlights[player] then
            pcall(function()
                State.Cache.PlayerHighlights[player]:Destroy()
            end)
            State.Cache.PlayerHighlights[player] = nil
        end
        return
    end

    local color, shouldShow

    if role == "Murder" then
        color      = CONFIG.Colors.Murder
        shouldShow = State.Settings.MurderESP
    elseif role == "Sheriff" then
        color      = CONFIG.Colors.Sheriff
        shouldShow = State.Settings.SheriffESP
    elseif role == "Innocent" then
        color      = CONFIG.Colors.Innocent
        shouldShow = State.Settings.InnocentESP
    else
        shouldShow = false
    end

    if not shouldShow then
        if State.Cache.PlayerHighlights[player] then
            pcall(function()
                State.Cache.PlayerHighlights[player].Enabled = false
            end)
        end
        return
    end

    local existingHighlight = State.Cache.PlayerHighlights[player]

    if existingHighlight then
        if existingHighlight.Parent and existingHighlight.Adornee == character then
            existingHighlight.FillColor    = color
            existingHighlight.OutlineColor = color
            existingHighlight.Enabled      = true
        else
            pcall(function()
                existingHighlight:Destroy()
            end)
            State.Cache.PlayerHighlights[player] = nil

            local newHighlight = CreateHighlight(character, color)
            if newHighlight then
                State.Cache.PlayerHighlights[player] = newHighlight
            end
        end
    else
        local newHighlight = CreateHighlight(character, color)
        if newHighlight then
            State.Cache.PlayerHighlights[player] = newHighlight
        end
    end
end

-- itemName: "Knife"|"Gun"
-- useServerData: true = fallback to PlayerData (ESP), false = item-only (AutoFarm)
-- serverRole: "Murderer"|"Sheriff"  (used only when useServerData=true)
local function findRoleHolder(itemName, useServerData, serverRole)
    for _, plr in ipairs(Players:GetPlayers()) do
        local char    = plr.Character
        local backpack = plr:FindFirstChild("Backpack")
        if (char and char:FindFirstChild(itemName))
        or (backpack and backpack:FindFirstChild(itemName)) then
            return plr
        end
    end
    if useServerData and State.Cache.PlayerData then
        for playerName, data in pairs(State.Cache.PlayerData) do
            if data.Role == serverRole then
                local player = Players:FindFirstChild(playerName)
                if player then return player end
            end
        end
    end
    return nil
end

local function getMurder()               return findRoleHolder("Knife", true,  "Murderer") end
local function getSheriff()              return findRoleHolder("Gun",   true,  "Sheriff")  end
local function getMurderForAutoFarm()    return findRoleHolder("Knife", false, nil)         end
local function getSheriffForAutoFarm()   return findRoleHolder("Gun",   false, nil)         end

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

    if not State.Runtime.UIElements.MurdererAvatar or not State.Runtime.UIElements.SheriffAvatar then
        warn("❌ Avatar UI elements not found!")
        return
    end

    local murderer = getMurder()
    local sheriff = getSheriff()


    -- Обновляем Murderer
    if murderer then
        if State.Runtime.CurrentMurdererUserId ~= murderer.UserId then
            State.Runtime.CurrentMurdererUserId = murderer.UserId
            setAvatar(State.Runtime.UIElements.MurdererAvatar, murderer)
        end
    else
        if State.Runtime.CurrentMurdererUserId ~= nil then
            State.Runtime.CurrentMurdererUserId = nil
            State.Runtime.UIElements.MurdererAvatar.Image = State.Runtime.PlaceholderImage
        end
    end

    -- Обновляем Sheriff
    if sheriff then
        if State.Runtime.CurrentSheriffUserId ~= sheriff.UserId then
            State.Runtime.CurrentSheriffUserId = sheriff.UserId
            setAvatar(State.Runtime.UIElements.SheriffAvatar, sheriff)
        end
    else
        if State.Runtime.CurrentSheriffUserId ~= nil then
            State.Runtime.CurrentSheriffUserId = nil
            State.Runtime.UIElements.SheriffAvatar.Image = State.Runtime.PlaceholderImage
        end
    end
end

local function CreateAvatarUI()
    pcall(function() CoreGui:FindFirstChild("MM2_AvatarDisplay"):Destroy() end)

    local gui = Core.New("ScreenGui")
    gui.Name = "MM2_AvatarDisplay"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10
    gui.Parent = CoreGui

    local container = Core.New("Frame")
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

        local frame = Core.New("Frame", props.frame, container)

        local corner = Core.New("UICorner", props.corner, frame)

        local stroke = Core.New("UIStroke", props.stroke, frame)

        local img = Core.New("ImageLabel", props.image, frame)

        local imgCorner = Core.New("UICorner", props.imgCorner, img)

        local label = Core.New("TextLabel", props.label, frame)

        return img
    end

    -- Создание аватаров
    State.Runtime.UIElements.MurdererAvatar = createFromConfig(avatarConfigs.Murderer)
    State.Runtime.UIElements.SheriffAvatar = createFromConfig(avatarConfigs.Sheriff)
    State.Runtime.UIElements.AvatarDisplayGui = gui
end

-- Функция очистки аватара Sheriff (вызывается при Gun drop)
local function clearSheriffAvatar()
    if State.Runtime.UIElements.SheriffAvatar then
        State.Runtime.UIElements.SheriffAvatar.Image = ""
        State.Runtime.CurrentSheriffUserId = nil
    end
end

-- Функция очистки всех аватаров (вызывается при окончании раунда)
local function clearAllAvatars()
    if State.Runtime.UIElements.MurdererAvatar then
        State.Runtime.UIElements.MurdererAvatar.Image = ""
    end
    if State.Runtime.UIElements.SheriffAvatar then
        State.Runtime.UIElements.SheriffAvatar.Image = ""
    end
    State.Runtime.CurrentMurdererUserId = nil
    State.Runtime.CurrentSheriffUserId = nil
end

-- Управление видимостью карточек аватаров (фоновая логика не затрагивается)
local function SetAvatarDisplayVisibility(on)
    local gui = State.Runtime.UIElements.AvatarDisplayGui
    if gui then
        gui.Enabled = on and true or false
    end
end


-- Role ESP loop
local function StartRoleChecking()
    SetupPlayerDataListener()
    if State.Runtime.RoleCheckLoop then
        pcall(function()
            State.Runtime.RoleCheckLoop:Disconnect()
        end)
        State.Runtime.RoleCheckLoop = nil
    end

    for player, highlight in pairs(State.Cache.PlayerHighlights) do
        pcall(function()
            highlight:Destroy()
        end)
        State.Cache.PlayerHighlights[player] = nil
    end

    State.Runtime.RoleCheckLoop = Core.Connect(RunService.Heartbeat, function()
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

            if murder and sheriff and State.Runtime.RoundStart then
                State.Runtime.RoundActive = true
                State.Runtime.RoundStart  = false
                State.Runtime.PreviousMurderer    = murder
                State.Runtime.PreviousSheriff    = sheriff
                State.Runtime.HeroSent    = false

                if State.Settings.NotificationsEnabled then
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

                Core.Tasks.spawn(function()
                    updateRoleAvatars()
                end)
            end

            if not murder and State.Runtime.RoundActive then
                State.Runtime.RoundActive = false
                State.Runtime.RoundStart  = true
                State.Runtime.PreviousMurderer    = nil
                State.Runtime.PreviousSheriff    = nil
                State.Runtime.HeroSent    = false

                -- Очистка серверных данных
                State.Cache.PlayerData = {}

                if State.Settings.NotificationsEnabled then
                    ShowNotification(
                        "<font color=\"rgb(220, 220, 220)\">Round ended</font>",
                        CONFIG.Colors.Text
                    )
                end
                clearAllAvatars()
            end

            -- Обнаружение смены шерифа (Hero)
            if sheriff
                and State.Runtime.PreviousSheriff
                and sheriff ~= State.Runtime.PreviousSheriff
                and murder
                and murder == State.Runtime.PreviousMurderer
                and not State.Runtime.HeroSent then

                State.Runtime.PreviousSheriff = sheriff
                State.Runtime.HeroSent = true

                if State.Settings.NotificationsEnabled then
                    ShowNotification(
                        "<font color=\"rgb(50, 150, 255)\">⭐ Hero:</font> " .. sheriff.Name,
                        CONFIG.Colors.Text
                    )
                end
                Core.Tasks.spawn(function()
                    updateRoleAvatars()
                end)
            end
        end)
    end)
    Core.Track(State.Runtime.RoleCheckLoop)
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

-- ── Dropped Gun: единый источник истины ──────────────────────────────────────
-- Раньше ган искался как getMap() → map:FindFirstChild("GunDrop"), то есть
-- НЕрекурсивно и с обязательной привязкой к карте: если getMap() не нашёл карту
-- (или взял не ту при смене раунда, когда в Workspace на пару кадров лежат две),
-- либо GunDrop оказался не прямым ребёнком карты — возвращался nil.
-- Бинд же всегда искал рекурсивно по всему Workspace и поэтому подбирал ган
-- ровно тогда, когда ESP и Instant Pickup молчали. Это и есть причина
-- расхождения «бинд работает, а есп/автопикап нет».
-- Теперь резолвер ОДИН на все три потребителя.
-- ⚠️ Поле State, а не top-level local: главный чанк упирается в лимит Luau
-- «200 local registers» (проверяется только компиляцией в Roblox). Тот же приём
-- уже применён для State.FlingCleanup.
State.Runtime.ResolveGunDrop = function()
    local ok, gun = pcall(function()
        return Workspace:FindFirstChild("GunDrop", true)
    end)
    if not ok or not gun then return nil end
    if gun:IsA("BasePart") and gun.Parent then return gun end
    return nil
end

-- ⚠️ Forward-declaration обязательна: CreateGunESP ниже вызывает RemoveGunESP,
-- а `local function RemoveGunESP` объявлен ПОСЛЕ него. Без этой строки имя
-- внутри CreateGunESP компилировалось как ГЛОБАЛЬНОЕ (nil) и вызов падал
-- «attempt to call a nil value», а падение молча съедал внешний pcall трекинга.
-- Для ловушек такая строка есть (`local RemoveTrapESP`), для гана её забыли.
local RemoveGunESP

local function CreateGunESP(gunPart)
    if not gunPart or not gunPart:IsA("BasePart") then return end

    if not gunPart.Parent then
        if State.Cache.GunCache[gunPart] then
            RemoveGunESP(gunPart)
        end
        return
    end

    if State.Cache.GunCache[gunPart] then
        RemoveGunESP(gunPart)
    end

    local highlight = Core.New("Highlight")
    highlight.Adornee            = gunPart
    highlight.FillColor          = CONFIG.Colors.Gun
    highlight.FillTransparency   = 0.8
    highlight.OutlineColor       = CONFIG.Colors.Gun
    highlight.OutlineTransparency = 0.3
    highlight.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled            = State.Settings.GunESP
    highlight.Parent             = gunPart

    local billboard = Core.New("BillboardGui")
    billboard.Name       = "GunESPLabel"
    billboard.Adornee    = gunPart
    billboard.Size       = UDim2.new(0, 140, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent      = gunPart

    local label = Core.New("TextLabel")
    label.BackgroundTransparency = 1
    label.Size                   = UDim2.new(1, 0, 1, 0)
    label.Text                   = "GUN"
    label.TextColor3             = Color3.fromRGB(255, 255, 255)
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 12
    label.TextStrokeTransparency = 0.6
    label.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    label.Parent                 = billboard

    State.Cache.GunCache[gunPart] = {
        highlight = highlight,
        billboard = billboard
    }
end

-- Присваиваем в forward-объявленный локал выше (без `local`!), иначе создался бы
-- второй локал и CreateGunESP снова смотрел бы в пустоту.
function RemoveGunESP(gunPart)
    if not gunPart or not State.Cache.GunCache[gunPart] then return end

    local espData = State.Cache.GunCache[gunPart]

    pcall(function()
        if espData.highlight then
            espData.highlight:Destroy()
        end
        if espData.billboard then
            espData.billboard:Destroy()
        end
    end)

    State.Cache.GunCache[gunPart] = nil
end

local function UpdateGunESPVisibility()
    for gunPart, espData in pairs(State.Cache.GunCache) do
        if espData.highlight then
            espData.highlight.Enabled = State.Settings.GunESP
        end
        if espData.billboard then
            espData.billboard.Enabled = State.Settings.GunESP
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

    if State.Cache.TrapCache[trapModel] then
        RemoveTrapESP(trapModel)
    end

    local mainPart = trapModel:FindFirstChild("TrapVisual")
    if not mainPart or not mainPart:IsA("BasePart") then return end

    -- ПРОВЕРКА ПОЗИЦИИ: Игнорируем ловушки близко к центру (спавн/лобби)
    local pos = mainPart.Position
    if math.abs(pos.X) < 100 and math.abs(pos.Y) < 100 and math.abs(pos.Z) < 100 then
        return  -- Слишком близко к центру - это не игровая ловушка
    end
    if State.Settings.NotificationsEnabled then
        Core.Tasks.spawn(function()
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
        local humanoid = Core.New("Humanoid")
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.Health = 0
        humanoid.MaxHealth = 0
        humanoid.Parent = trapModel
    end

    local highlight = Core.New("Highlight")
    highlight.Adornee = trapModel
    highlight.FillColor = Color3.fromRGB(255, 0, 4)
    highlight.FillTransparency = 0.8
    highlight.OutlineColor = Color3.fromRGB(255, 0, 4)
    highlight.OutlineTransparency = 0.5
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = State.Settings.GunESP
    highlight.Parent = trapModel

    local billboard = Core.New("BillboardGui")
    billboard.Name = "TrapESPLabel"
    billboard.Adornee = mainPart
    billboard.Size = UDim2.new(0, 140, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = game:GetService("CoreGui")

    local label = Core.New("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = "Trap"
    label.TextColor3 = Color3.fromRGB(255, 85, 85)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextStrokeTransparency = 0.7
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = billboard

    State.Cache.TrapCache[trapModel] = {
        highlight = highlight,
        billboard = billboard,
        trapPart = mainPart
    }
end

RemoveTrapESP = function(trapModel)
    if not trapModel or not State.Cache.TrapCache[trapModel] then return end

    local espData = State.Cache.TrapCache[trapModel]

    pcall(function()
        if espData.highlight then espData.highlight:Destroy() end
        if espData.billboard then espData.billboard:Destroy() end

        if espData.trapPart and espData.trapPart.Parent then
            espData.trapPart.Transparency = 1
            espData.trapPart.Material = Enum.Material.Plastic
        end
    end)

    State.Cache.TrapCache[trapModel] = nil
end

local function UpdateTrapESPVisibility()
    for trapModel, espData in pairs(State.Cache.TrapCache) do
        if espData.highlight then
            espData.highlight.Enabled = State.Settings.GunESP
        end
        if espData.billboard then
            espData.billboard.Enabled = State.Settings.GunESP
        end
    end
end

local function ScanMurdererTraps()
    if not State.Settings.GunESP then return end

    local murder = getMurder()
    if not murder then
        -- Нет убийцы - удаляем все ловушки
        for cachedTrap in pairs(State.Cache.TrapCache) do
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

                if not State.Cache.TrapCache[child] then
                    CreateTrapESP(child)
                end
            end
        end
    end

    for cachedTrap in pairs(State.Cache.TrapCache) do
        if not foundTraps[cachedTrap] or not cachedTrap.Parent then
            RemoveTrapESP(cachedTrap)
        end
    end
end

-- АВТОМАТИЧЕСКОЕ ОТСЛЕЖИВАНИЕ ЛОВУШЕК
local function StartTrapTracking()
    local lastScan = 0

    local connection = Core.Connect(RunService.Heartbeat, function()
        if not State.Settings.GunESP then return end

        local currentTime = tick()
        if currentTime - lastScan >= 1 then
            lastScan = currentTime
            pcall(ScanMurdererTraps)
        end
    end)

    Core.Track(connection)
end

-- Anti-Trap: ловушка убийцы (перк Trap) действует только на клиенте жертвы. Сервер
-- шлёт TrapSystem.TrapHitLocal, а игровой TrapScriptClient ставит WalkSpeed 0.01 и
-- JumpPower 1 на 4 с, показывает TrapGUI и шлёт TrapReplicate (по нему остальные и
-- убийца видят сработавшую ловушку). Отключаем именно этот обработчик — нет ни
-- замедления, ни окна, ни сигнала убийце. Без getconnections — запасной путь:
-- свой обработчик сразу возвращает скорость и убирает окно.
do
    local anti = {Muted = {}, Fallback = nil, Watch = nil}

    local function trapRemote()
        local system = ReplicatedStorage:FindFirstChild("TrapSystem")
        return system and system:FindFirstChild("TrapHitLocal")
    end

    local function isGameHandler(fn)
        local ok, source = pcall(debug.info, fn, "s")
        return ok and type(source) == "string" and source:find("TrapScriptClient", 1, true) ~= nil
    end

    -- true — игровые обработчики найдены и отключены (или их нет)
    local function muteGameHandlers(remote)
        if type(getconnections) ~= "function" then return false end
        local ok = pcall(function()
            for _, conn in ipairs(getconnections(remote.OnClientEvent)) do
                if not anti.Muted[conn] and conn.Function and isGameHandler(conn.Function) then
                    conn:Disable()
                    anti.Muted[conn] = true
                end
            end
        end)
        return ok
    end

    local function unmuteGameHandlers()
        for conn in pairs(anti.Muted) do pcall(function() conn:Enable() end) end
        table.clear(anti.Muted)
    end

    -- Запасной путь: игровой обработчик уже замедлил — возвращаем как было
    local function undoTrap()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = CONFIG.DefaultWalkSpeed
            humanoid.JumpPower = State.Runtime.SettingsDirty and State.Settings.JumpPower or 50
        end
        local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local trapGui = gui and gui:FindFirstChild("TrapGUI")
        if trapGui then trapGui:Destroy() end
    end

    State.Runtime.SetAntiTrap = function(enabled)
        State.Settings.AntiTrapEnabled = enabled == true
        if anti.Fallback then anti.Fallback:Disconnect(); anti.Fallback = nil end
        if anti.Watch then Core.Tasks.cancel(anti.Watch); anti.Watch = nil end
        unmuteGameHandlers()
        if not State.Settings.AntiTrapEnabled then return end

        local remote = trapRemote()
        if not remote then
            -- Не MM2 или система ловушек ещё не загружена — ждём её в фоне
            anti.Watch = Core.Tasks.spawn(function()
                local system = ReplicatedStorage:WaitForChild("TrapSystem", 60)
                if system and system:WaitForChild("TrapHitLocal", 10) and State.Settings.AntiTrapEnabled then
                    State.Runtime.SetAntiTrap(true)
                end
            end)
            return
        end
        if not muteGameHandlers(remote) then
            anti.Fallback = Core.Connect(remote.OnClientEvent, function()
                Core.Tasks.defer(undoTrap)
            end)
        end
        -- Включили уже сидя в ловушке: игровой таймер «через 4 с вернуть» мог оборваться
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.WalkSpeed < 0.1 then undoTrap() end
        -- TrapScriptClient может переподключиться (перезагрузка PlayerScripts) — перепроверяем
        anti.Watch = Core.Tasks.spawn(function()
            while State.Settings.AntiTrapEnabled do
                task.wait(5)
                if not anti.Fallback then muteGameHandlers(remote) end
            end
        end)
    end
end

-- Единая точка реакции: «текущий ган — вот этот» либо «гана нет».
-- Зовётся и из событий, и из reconcile, поэтому обязана быть идемпотентной.
-- Поле State по той же причине, что ResolveGunDrop — лимит локалей чанка.
State.Runtime.ApplyGunDropState = function(gun)
    if gun and not gun.Parent then gun = nil end

    if gun ~= State.Runtime.CurrentGunDrop then
        -- Снимаем ESP со всего, что перестало быть текущим ганом
        for cachedGun in pairs(State.Cache.GunCache) do
            if cachedGun ~= gun then
                RemoveGunESP(cachedGun)
            end
        end

        State.Runtime.CurrentGunDrop = gun
        State.Runtime.PreviousGun = gun -- поле оставлено для совместимости

        if gun then
            -- Новый дроп — сбрасываем отметку «по этому уже отработали»
            State.Runtime.GunPickupTried = nil

            if State.Settings.NotificationsEnabled then
                Core.Tasks.spawn(function()
                    ShowNotification(
                        "<font color=\"rgb(255, 200, 50)\">Gun dropped!</font>",
                        CONFIG.Colors.Gun
                    )
                end)
            end
            -- ⚠️ Вне гейта уведомлений: аватар шерифа надо гасить всегда.
            -- Раньше clearSheriffAvatar висел ВНУТРИ if NotificationsEnabled,
            -- и с выключенными уведомлениями аватар оставался висеть
            Core.Tasks.spawn(function()
                pcall(clearSheriffAvatar)
            end)

            -- Автопикап дёргаем событием, а не опросом каждые 0.05 с.
            -- Хук на State, потому что сама функция объявлена ниже по файлу —
            -- тот же приём, что у State.FlingCleanup
            if State.Settings.InstantPickupEnabled and State.Runtime.TryInstantPickup then
                Core.Tasks.spawn(function()
                    pcall(State.Runtime.TryInstantPickup, gun)
                end)
            end
        end
    end

    -- ESP на текущий ган — идемпотентно
    if gun then
        if State.Settings.GunESP then
            if not State.Cache.GunCache[gun] then
                CreateGunESP(gun)
            else
                local espData = State.Cache.GunCache[gun]
                if espData.highlight then espData.highlight.Enabled = true end
                if espData.billboard then espData.billboard.Enabled = true end
            end
        elseif State.Cache.GunCache[gun] then
            -- Тогл выключили: ESP снимаем, но сам ган продолжаем отслеживать,
            -- иначе Instant Pickup перестал бы работать с выключенным ESP
            RemoveGunESP(gun)
        end
    end
end

-- ── Трекинг выпавшего гана: событийная модель ────────────────────────────────
-- Было: Heartbeat каждый кадр → getMap() → FindFirstChild. Дорого, давало до
-- кадра задержки и полностью молчало при промахе getMap().
-- Стало: DescendantAdded/DescendantRemoving + reconcile раз в секунду как
-- самолечение (скрипт мог подняться, когда ган уже лежал; событие могло не
-- прийти при стриминге или после перезапуска трекинга).
local function SetupGunTracking()
    -- Снимаем прежние коннекты: функция может вызываться повторно
    if State.Runtime.CurrentMapConnection then
        pcall(function() State.Runtime.CurrentMapConnection:Disconnect() end)
        State.Runtime.CurrentMapConnection = nil
    end
    for _, c in ipairs(State.Runtime.GunTrackConns) do
        pcall(function() c:Disconnect() end)
    end
    State.Runtime.GunTrackConns = {}

    -- Фильтр по имени первым делом: строковое сравнение несопоставимо дешевле
    -- обхода дерева, а DescendantAdded в MM2 дёргается часто
    local addedConn = Core.Connect(Workspace.DescendantAdded, function(d)
        if d.Name ~= "GunDrop" then return end
        if not d:IsA("BasePart") then return end
        pcall(State.Runtime.ApplyGunDropState, d)
    end)

    -- Реагируем, только если уходит ИМЕННО текущий ган
    local removingConn = Core.Connect(Workspace.DescendantRemoving, function(d)
        if d ~= State.Runtime.CurrentGunDrop then return end
        pcall(function()
            RemoveGunESP(d)
            State.Cache.GunCache[d] = nil
            State.Runtime.CurrentGunDrop = nil
            State.Runtime.PreviousGun = nil
            State.Runtime.GunPickupTried = nil
        end)
    end)

    table.insert(State.Runtime.GunTrackConns, addedConn)
    table.insert(State.Runtime.GunTrackConns, removingConn)
    Core.Track(addedConn)
    Core.Track(removingConn)

    if State.Runtime.GunReconcileThread then
        pcall(task.cancel, State.Runtime.GunReconcileThread)
        State.Runtime.GunReconcileThread = nil
    end
    State.Runtime.GunTrackingActive = true
    State.Runtime.GunReconcileThread = Core.Tasks.spawn(function()
        while State.Runtime.GunTrackingActive do
            pcall(function()
                State.Runtime.ApplyGunDropState(State.Runtime.ResolveGunDrop())
            end)
            task.wait(1)
        end
    end)

    -- Немедленная синхронизация: не ждём первого тика reconcile
    pcall(function()
        State.Runtime.ApplyGunDropState(State.Runtime.ResolveGunDrop())
    end)
end
-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 7: FLING / ANTI-FLING
-- ══════════════════════════════════════════════════════════════════════════════

local Fling = {
    -- L1: очередь и сессия
    Queue = {},
    Cooldowns = {},
    SessionActive = false,   -- идёт ли сессия флинга
    ReturnCF = nil,          -- точка возврата (была позиция клона)
    ReturnPhases = nil,
    RootAnchored = false,
    AnchorFrames = 0,
    SkidHold = nil,
    DeathConn = nil,
    AntiFlingConn = nil,

    -- L1: сохранённое состояние для восстановления
    SavedPartState = {},
    SavedScriptDisabled = {},
    TargetCollision = {},
    AntiFlingCollision = {},
    SelfCollision = {},      -- свои части, которым skidfling поднял CanCollide

    -- L9: избирательный режим антифлинга (во время WalkFling)
    StrippedChars = {},   -- персонаж -> с него снята коллизия
    FlingerSeen = {},     -- персонаж -> os.clock() последнего флингового всплеска
    FlingerAngular = 50,  -- порог угловой скорости
    FlingerLinear = 120,  -- порог линейной скорости (обычное падение ~50-90)
    FlingerHold = 3,      -- секунд держать защиту после последнего всплеска

    -- «Already flung»: цель быстрее FlungSpeed считается уже летящей. Настойчивый
    -- ForceClicks-й клик по ней за ForceWindow секунд всё равно запускает флинг
    FlungSpeed = 500,
    ForceClicks = 3,
    ForceWindow = 3,
    ForceClickLog = {},   -- userId -> {os.clock() последних кликов}
    SavedHumState = nil,
    MaskedChar = nil,
    DestroyHeightSet = false,
    SavedMovementMode = nil,

    -- L6: развёртка предикта. Не менять: треугольник (не синус), счётчик кадров
    -- (не os.clock), без сглаживания. Обоснование в FLING_SOURCE.md §7.2.
    SkidMaxLead = 40,
    SweepFrames = 6,
    SweepStep = 0,

    -- L4: управление клоном
    Keys = {
        w = false, a = false, s = false, d = false,
        jump = false, padJump = false,
        stick = Vector2.zero,
        move = Vector3.zero,
        wantJump = false,
    },

    MainPhaseKey = "__mm2_fling_main_phase",

    Anims = {
        R6 = {
            idle    = "rbxassetid://180435571",
            idleAlt = "rbxassetid://180435792",
            walk    = "rbxassetid://180426354",
            run     = nil,
            jump    = "rbxassetid://125750702",
            fall    = "rbxassetid://180436148",
        },
        R15 = {
            idle = "rbxassetid://507766666",
            walk = "rbxassetid://507777826",
            run  = "rbxassetid://507767714",
            jump = "rbxassetid://507765000",
            fall = "rbxassetid://507767968",
        },
    },
}

-- ─── L0: утилиты ──────────────────────────────────────────────────────────────

-- Единственная точка валидации метода. Принимает и внутреннее имя ("skidfling"),
-- и то, что показано в UI ("Vio"). Всё остальное сравнивает с "skidfling".
function Fling.NormalizeMethod(v)
    if v == "skidfling" or v == "Vio" then return "skidfling" end
    return "NaN"
end

-- Обратное преобразование: внутреннее имя -> подпись в UI.
function Fling.MethodLabel(m)
    if Fling.NormalizeMethod(m) == "skidfling" then return "Vio" end
    return "NaN"
end

-- Порядок важен: первый элемент — то, что стоит по умолчанию.
Fling.MethodChoices = {"Vio", "NaN"}

-- Метод конкретного элемента очереди: LoopFling кладёт сюда свой, ручной флинг
-- оставляет nil и работает на общем State.FlingMethod.
function Fling.ItemMethod(item)
    if item and item.Method then return item.Method end
    return Fling.NormalizeMethod(State.Settings.FlingMethod)
end

-- Метод, которым идёт текущая работа. Читается там, где элемента под рукой нет.
function Fling.ActiveMethod()
    return Fling.ItemMethod(Fling.Queue[1])
end

function Fling.CharParts(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local rp = (hum and hum.RootPart) or (char and char:FindFirstChild("HumanoidRootPart"))
    if rp and not rp:IsA("BasePart") then rp = nil end
    return hum, rp
end

function Fling.IsDead(hum)
    if not hum then return false end
    return hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead
end

function Fling.ZeroVelocity(part)
    part.AssemblyLinearVelocity = Vector3.zero
    part.AssemblyAngularVelocity = Vector3.zero
    part.Velocity = Vector3.zero
    part.RotVelocity = Vector3.zero
end

function Fling.CharFromPart(part)
    local m = part and part.Parent
    if not m then return nil end
    if m:IsA("Accessory") then m = m.Parent end
    if m and m:FindFirstChildOfClass("Humanoid") then return m end
    return nil
end

-- FallenPartsDestroyHeight: единственный владелец — State.FPDH. NaN не даёт
-- движку удалить отлетевшую цель при падении под карту.
function Fling.SetFlingDestroyHeight()
    if Fling.DestroyHeightSet then return end
    Workspace.FallenPartsDestroyHeight = 0/0
    Fling.DestroyHeightSet = true
end

function Fling.RestoreDestroyHeight()
    Workspace.FallenPartsDestroyHeight = State.Runtime.FallenPartsDestroyHeight
    Fling.DestroyHeightSet = false
end

-- ─── L2: маскировка настоящего персонажа ──────────────────────────────────────

function Fling.ResetRoot()
    Fling.SkidHold = nil
    local hum, rp = Fling.CharParts(LocalPlayer.Character)
    if rp then
        pcall(function() sethiddenproperty(rp, "PhysicsRepRootPart", nil) end)
        Fling.ZeroVelocity(rp)
    end
    if hum then
        hum.AutoRotate = true
        pcall(function() sethiddenproperty(hum, "MoveDirectionInternal", Vector3.zero) end)
        pcall(function() sethiddenproperty(hum, "NetworkHumanoidState", Enum.HumanoidStateType.Running) end)
    end
end

-- Пока идёт флинг, настоящий персонаж каждый кадр телепортируется к цели. Если у
-- игрока активен путь click-to-move, штатный ClickToMoveController ловит это как
-- OnPathBlocked и перезапрашивает путь через всю карту — оттуда и сыпется
-- "PathfindingService: path request is too long". Управление клоном идёт мимо
-- ControlModule, так что на время сессии click-to-move просто не нужен.
function Fling.SuppressClickToMove()
    if Fling.SavedMovementMode then return end
    Fling.SavedMovementMode = {
        computer = LocalPlayer.DevComputerMovementMode,
        touch = LocalPlayer.DevTouchMovementMode,
    }
    pcall(function()
        LocalPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.KeyboardMouse
        LocalPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Thumbstick
    end)
end

function Fling.RestoreClickToMove()
    local saved = Fling.SavedMovementMode
    if not saved then return end
    Fling.SavedMovementMode = nil
    pcall(function()
        LocalPlayer.DevComputerMovementMode = saved.computer
        LocalPlayer.DevTouchMovementMode = saved.touch
    end)
end

function Fling.SaveHumanoidState(hum)
    if Fling.SavedHumState and Fling.SavedHumState.hum == hum then return end
    Fling.SavedHumState = {
        hum = hum,
        autoRotate = hum.AutoRotate,
        walkSpeed = hum.WalkSpeed,
        jumpPower = hum.JumpPower,
        jumpHeight = hum.JumpHeight,
        useJumpPower = hum.UseJumpPower,
        requiresNeck = hum.RequiresNeck,
        breakJointsOnDeath = hum.BreakJointsOnDeath,
    }
end

function Fling.RestoreHumanoidState()
    local s = Fling.SavedHumState
    Fling.SavedHumState = nil
    if not s or not s.hum.Parent then return end
    s.hum.AutoRotate = s.autoRotate
    s.hum.WalkSpeed = s.walkSpeed
    s.hum.UseJumpPower = s.useJumpPower
    s.hum.JumpPower = s.jumpPower
    s.hum.JumpHeight = s.jumpHeight
    s.hum.RequiresNeck = s.requiresNeck
    s.hum.BreakJointsOnDeath = s.breakJointsOnDeath
end




function Fling.StopTracks(hum, airOnly)
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if not airOnly or Fling.IsAirAnimationId(Fling.TrackAnimationId(track)) then
            track:Stop(0)
        end
    end
end



-- Контакт skidfling'а даёт только тело персонажа, поэтому поднимаем CanCollide
-- ТОЛЬКО прямым детям-BasePart. Раньше шли по GetDescendants и включали коллизию
-- аксессуарам и инструментам, а обратно их никто не выключал: после флинга шляпы
-- продолжали цепляться за геометрию и ноклип "переставал работать" — его цикл
-- гасит коллизию тоже только у прямых детей. Исходные значения запоминаем и
-- возвращаем в EndSession.
function Fling.EnableSkidCollision(char)
    if not char then return end
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("BasePart") then
            if Fling.SelfCollision[obj] == nil then
                Fling.SelfCollision[obj] = obj.CanCollide
            end
            if obj.CanCollide ~= true then obj.CanCollide = true end
        end
    end
end

-- Возврат своей коллизии. Если ноклип включён, его Stepped-цикл следующим кадром
-- снова опустит эти же части в false — специально ничего доделывать не нужно.
function Fling.RestoreSelfCollision()
    for p, c in pairs(Fling.SelfCollision) do
        if p.Parent then
            pcall(function() p.CanCollide = c end)
        end
    end
    table.clear(Fling.SelfCollision)
end

-- ─── L3: зеркалирование поз и анимаций ────────────────────────────────────────

function Fling.TrackAnimationId(track)
    local anim = track.Animation
    local id = anim and anim.AnimationId
    if type(id) == "string" and #id > 0 then return id end
    return nil
end

function Fling.IsAirAnimationId(id)
    local a = Fling.Anims
    return id == a.R6.jump or id == a.R6.fall or id == a.R15.jump or id == a.R15.fall
end

function Fling.SnapshotTrackPhases(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    local phases = {}
    if not animator then return phases end

    local bestPhase, bestWeight = nil, -1
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local id = Fling.TrackAnimationId(track)
        if id then phases[id] = track.TimePosition end
        if not Fling.IsAirAnimationId(id) and track.WeightCurrent >= bestWeight then
            bestPhase = track.TimePosition
            bestWeight = track.WeightCurrent
        end
    end
    if bestPhase ~= nil then
        phases[Fling.MainPhaseKey] = bestPhase
    end
    return phases
end

function Fling.ApplyTrackPhases(hum, phases)
    if not hum or not phases then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local id = Fling.TrackAnimationId(track)
        local time = id and phases[id]
        if time == nil and not Fling.IsAirAnimationId(id) then
            time = phases[Fling.MainPhaseKey]
        end
        if time ~= nil then
            pcall(function()
                local len = track.Length
                track.TimePosition = (len > 0) and (time % len) or time
            end)
        end
    end
end



function Fling.CreateTrack(animator, id, priority, looped)
    if not id or #id == 0 then return nil end
    local a = Core.New("Animation")
    a.AnimationId = id
    local ok, t = pcall(function() return animator:LoadAnimation(a) end)
    a:Destroy()
    if ok and t then
        t.Priority = priority
        t.Looped = looped
        return t
    end
    return nil
end



-- ─── L4: session model ────────────────────────────────────────────────────────

function Fling.SetCameraSubject(subject)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local cf = cam.CFrame
    cam.CameraSubject = subject
    cam.CFrame = cf
end



-- ⚠️ Гост-режим («визуально остаюсь на месте, пока флингую») ВЫРЕЗАН.
-- Раньше на время флинга спавнился клон персонажа, игрок смотрел и управлял им,
-- а настоящее тело пряталось: MaskChar ставил LocalTransparencyModifier = 1 на
-- ВСЕ части и глушил анимации. Вместе с телом пропадало всё, что на нём висит —
-- нож, второй нож Dual, эффекты скинченджера, — и вернуть их удавалось не
-- всегда. Теперь клона нет: виден реальный полёт, а точка возврата просто
-- запоминается здесь.
-- Флинг и Fake Position оба подменяют физику корня. На время любого флинга
-- (очередь или Walk Fling) Fake Position выключаем и возвращаем после, если он
-- был включён. Holders — кто держит паузу, чтобы пересекающиеся флинги не
-- включили его раньше времени.
Fling.FakePositionPaused = false
Fling.FakePositionHolders = {}
Fling.FakePositionResumeToken = 0

function Fling.PauseFakePosition(reason)
    if State.Settings.FakePositionEnabled and State.Runtime.SetFakePosition then
        Fling.FakePositionPaused = true
        State.Runtime.SetFakePosition(false)
    end
    if Fling.FakePositionPaused then Fling.FakePositionHolders[reason] = true end
end

function Fling.ResumeFakePosition(reason)
    Fling.FakePositionHolders[reason] = nil
    if not Fling.FakePositionPaused or next(Fling.FakePositionHolders) then return end
    Fling.FakePositionResumeToken += 1
    local token = Fling.FakePositionResumeToken
    -- Ждём волны восстановления Humanoid из EndSession, иначе смещение ляжет на телепорт.
    Core.Tasks.delay(0.35, function()
        if token ~= Fling.FakePositionResumeToken or not Fling.FakePositionPaused then return end
        if Fling.SessionActive or State.Runtime.WalkFlingActive then
            Fling.FakePositionHolders[Fling.SessionActive and "session" or "walk"] = true
            return
        end
        Fling.FakePositionPaused = false
        if not State.Settings.FakePositionEnabled then State.Runtime.SetFakePosition(true) end
    end)
end

-- Пользователь сам переключил Fake Position — отложенное включение отменяется.
function Fling.ForgetFakePositionPause()
    Fling.FakePositionPaused = false
    table.clear(Fling.FakePositionHolders)
    Fling.FakePositionResumeToken += 1
end
-- cleanupSession объявлена выше Fling — доступ через State.Runtime.
State.Runtime.ForgetFakePositionPause = Fling.ForgetFakePositionPause

function Fling.BeginSession()
    local char = LocalPlayer.Character
    local _, rp = Fling.CharParts(char)
    if not char or not rp then return false end
    Fling.PauseFakePosition("session")
    -- Запоминаем, куда вернуть. Раньше эту роль играл рут клона.
    Fling.ReturnCF = rp.CFrame
    Fling.ReturnPhases = Fling.SnapshotTrackPhases(char)
    Fling.SessionActive = true
    return true
end

-- sync = true  -> вернуть игрока в точку, где начался флинг
-- sync = false -> бросить всё (смерть, аварийная остановка)
function Fling.EndSession(sync)
    local char = LocalPlayer.Character
    local hum, rp = Fling.CharParts(char)

    local retCf = sync and Fling.ReturnCF or nil
    local retPhases = sync and Fling.ReturnPhases or nil

    State.Runtime.IsFlingInProgress = false
    Fling.SessionActive = false
    Fling.ReturnCF = nil
    Fling.ReturnPhases = nil

    Fling.RestoreTargetCollision()
    Fling.RestoreSelfCollision()
    Fling.ResetRoot()
    Fling.RestoreHumanoidState()
    Fling.RestoreClickToMove()
    Fling.StopTracks(hum, true)
    Fling.ApplyTrackPhases(hum, retPhases)

    if retCf and rp then
        rp.CFrame = retCf
        rp.AssemblyLinearVelocity = Vector3.zero
        rp.AssemblyAngularVelocity = Vector3.zero
        rp.Velocity = Vector3.zero
        rp.RotVelocity = Vector3.zero
    end

    if sync and hum then
        -- Три волны восстановления. Движок перебивает состояние Humanoid ещё
        -- несколько кадров после телепорта, одной установки не хватает —
        -- персонаж залипает в Freefall. Порядок и задержки не менять.
        hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        hum.Jump = false
        hum.Sit = false
        hum.PlatformStand = false
        pcall(function() sethiddenproperty(hum, "MoveDirectionInternal", Vector3.zero) end)
        pcall(function() sethiddenproperty(hum, "NetworkHumanoidState", Enum.HumanoidStateType.Running) end)
        hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)

        Core.Tasks.defer(function()
            if not hum.Parent then return end
            hum.Jump = false
            hum.Sit = false
            hum.PlatformStand = false
            pcall(function() sethiddenproperty(hum, "MoveDirectionInternal", Vector3.zero) end)
            pcall(function() sethiddenproperty(hum, "NetworkHumanoidState", Enum.HumanoidStateType.Running) end)
            Fling.StopTracks(hum, true)
            Fling.ApplyTrackPhases(hum, retPhases)
            hum:ChangeState(Enum.HumanoidStateType.Running)
            -- Возврат мог сбиться, пока движок доигрывал физику: ставим ещё раз.
            if retCf and rp and rp.Parent then
                rp.CFrame = retCf
                rp.AssemblyLinearVelocity = Vector3.zero
            end
            Fling.SetCameraSubject(hum)

            Core.Tasks.spawn(function()
                if RunService.PreAnimation then
                    RunService.PreAnimation:Wait()
                else
                    RunService.RenderStepped:Wait()
                end
                if not hum.Parent then return end
                pcall(function() sethiddenproperty(hum, "NetworkHumanoidState", Enum.HumanoidStateType.Running) end)
                hum:ChangeState(Enum.HumanoidStateType.Running)
                Fling.ApplyTrackPhases(hum, retPhases)
            end)
        end)
    else
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
            Fling.SetCameraSubject(hum)
        end
    end

    Fling.RestoreDestroyHeight()
    Fling.ResumeFakePosition("session")
end

function Fling.DropDeadChar(char)
    if not char then return end
    table.clear(Fling.Queue)
    table.clear(Fling.Cooldowns)
    State.Runtime.IsFlingInProgress = false
    Fling.EndSession(false)
end

function Fling.BindCharacter(char)
    if Fling.DeathConn then
        Fling.DeathConn:Disconnect()
        Fling.DeathConn = nil
    end
    Fling.RestoreDestroyHeight()
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    Fling.DeathConn = Core.Connect(hum.Died, function()
        Fling.DropDeadChar(char)
    end)
    TrackConnection(Fling.DeathConn)
end

function Fling.CalcMove()
    local keys = Fling.Keys
    local v = Vector3.zero
    if keys.w then v = v + Vector3.new(0, 0, -1) end
    if keys.s then v = v + Vector3.new(0, 0,  1) end
    if keys.a then v = v + Vector3.new(-1, 0, 0) end
    if keys.d then v = v + Vector3.new( 1, 0, 0) end
    if keys.stick.Magnitude > 0.2 then
        v = v + Vector3.new(keys.stick.X, 0, keys.stick.Y)
    end
    if v.Magnitude > 1 then v = v.Unit end
    keys.move = v
    keys.wantJump = keys.jump or keys.padJump
end

function Fling.ClearMove()
    local keys = Fling.Keys
    keys.w, keys.a, keys.s, keys.d = false, false, false, false
    keys.jump = false
    keys.padJump = false
    keys.stick = Vector2.zero
    keys.move = Vector3.zero
    keys.wantJump = false
end

-- ─── L5: выбор точки попадания ────────────────────────────────────────────────

function Fling.TargetPart(char)
    if not char then return nil end
    local _, root = Fling.CharParts(char)
    if root then return root end
    if char.PrimaryPart then return char.PrimaryPart end

    local best, bestSize = nil, 0
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") and not obj:FindFirstAncestorOfClass("Accessory") then
            local size = obj.Size.X * obj.Size.Y * obj.Size.Z
            if size > bestSize then
                best, bestSize = obj, size
            end
        end
    end
    return best or root
end

function Fling.GetPart(tgt)
    if typeof(tgt) ~= "Instance" then return nil end
    if tgt:IsA("Model") then return Fling.TargetPart(tgt) end
    if tgt:IsA("BasePart") then
        local char = Fling.CharFromPart(tgt)
        if char then return Fling.TargetPart(char) or tgt end
        return tgt
    end
    return nil
end

-- Для skid нужен именно корень, а не ближайшая часть: флинг контактный.
function Fling.SkidTargetPart(tgt)
    if typeof(tgt) ~= "Instance" then return Fling.GetPart(tgt) end
    local char = tgt:IsA("Model") and tgt or (tgt:IsA("BasePart") and Fling.CharFromPart(tgt) or nil)
    if not char then return Fling.GetPart(tgt) end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    if root and root:IsA("BasePart") then return root end

    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head end

    local accessory = char:FindFirstChildOfClass("Accessory")
    local handle = accessory and accessory:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then return handle end

    return Fling.GetPart(tgt)
end

function Fling.TargetHumanoid(tgt)
    if typeof(tgt) ~= "Instance" then return nil end
    local char = tgt:IsA("Model") and tgt or (tgt:IsA("BasePart") and Fling.CharFromPart(tgt) or nil)
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end

function Fling.PlayerFromTarget(tgt)
    if typeof(tgt) ~= "Instance" then return nil end
    local char = tgt:IsA("Model") and tgt or (tgt:IsA("BasePart") and Fling.CharFromPart(tgt) or nil)
    return char and Players:GetPlayerFromCharacter(char) or nil
end

function Fling.RepeatPart(item)
    local player = item.Player
    if not player or not player.Parent then return nil end
    local char = player.Character
    if not char then return nil end
    local hum, root = Fling.CharParts(char)
    if not root or Fling.IsDead(hum) then return nil end
    local part = Fling.TargetPart(char) or root
    item.Target = part
    return part
end

function Fling.RestoreTargetCollision()
    for p, c in pairs(Fling.TargetCollision) do
        if p.Parent then p.CanCollide = c end
    end
    table.clear(Fling.TargetCollision)
end

-- Только для метода NaN. skidfling живёт контактом, снимать коллизию нельзя.
function Fling.NoCollideTarget(tgt)
    if typeof(tgt) ~= "Instance" then return end
    local char = tgt:IsA("Model") and tgt or (tgt:IsA("BasePart") and Fling.CharFromPart(tgt) or nil)
    if not char or char == LocalPlayer.Character then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            if Fling.TargetCollision[obj] == nil then
                Fling.TargetCollision[obj] = obj.CanCollide
            end
            obj.CanCollide = false
        end
    end
end

-- ─── L6: предикт (всегда включён) ─────────────────────────────────────────────

-- Упреждение на State.SkidLead секунд хода вдоль НАМЕРЕНИЯ цели (MoveDirection),
-- а не наблюдаемой скорости: намерение реплицируется без задержки на пинг.
-- Прицел не ставится в одну точку, а разворачивается по всему коридору
-- упреждения туда-обратно за SweepFrames кадров.
function Fling.PredictionOffset(base, thum)
    local velocity = base.AssemblyLinearVelocity
    local flat = Vector3.new(velocity.X, 0, velocity.Z)
    local speed = flat.Magnitude

    local dir
    local moveDirection = thum and thum.MoveDirection
    if moveDirection and moveDirection.Magnitude > 0.05 then
        dir = moveDirection.Unit
    elseif speed > 1 then
        dir = flat.Unit
    end
    if not dir then return Vector3.zero end

    local seconds = math.clamp(State.Settings.SkidLead or 0.9, 0.6, 1.2)

    -- Треугольник, а не синус: у синуса нулевая производная на краях, он залипает
    -- на концах коридора и проскакивает середину. Счётчик кадров, а не os.clock():
    -- при привязке ко времени развёртка перескакивает куски коридора на просадке
    -- fps. Сглаживания нет и быть не должно — оно размазывает края.
    local frames = Fling.SweepFrames
    Fling.SweepStep = (Fling.SweepStep + 1) % frames
    local phase = Fling.SweepStep / frames
    local tri = (phase < 0.5) and (phase * 2) or (2 - phase * 2)

    local lead = math.clamp(speed * seconds * tri, 0, Fling.SkidMaxLead)
    return dir * lead
end

function Fling.SkidTargetCFrame(base, thum)
    return CFrame.new(base.Position + Fling.PredictionOffset(base, thum))
end

-- Предикт для NaN: линейная экстраполяция с фиксированным лидом 0.045.
-- Константа подобрана под механику NaN, ползунок SkidLead на неё не влияет.
-- Возвращает (cf, done).
function Fling.Predict(tgt, item)
    if item and item.Repeat then
        local part = Fling.RepeatPart(item)
        if not part then
            local _, selfRoot = Fling.CharParts(LocalPlayer.Character)
            local cf = item.LastCFrame or (selfRoot and selfRoot.CFrame) or CFrame.identity
            return cf, (item.Player ~= nil and not item.Player.Parent)
        end
        tgt = part
    end

    if typeof(tgt) == "Instance" then
        local part = Fling.GetPart(tgt)
        if part then
            if not part:IsDescendantOf(Workspace) then
                local cf = (item and item.LastCFrame) or CFrame.identity
                return cf, not (item and item.Repeat)
            end

            local cf = CFrame.new(part.Position)

            -- отсечка телепорта: цель прыгнула больше чем на 200 стад — не ведём
            local oldPos = item and item.LastPosition
            if oldPos and (part.Position - oldPos).Magnitude > 200 then
                if item then
                    item.LastPosition = part.Position
                    item.LastCFrame = cf
                end
                return cf, not (item and item.Repeat)
            end

            if item then item.LastPosition = part.Position end
            cf = cf + part.AssemblyLinearVelocity * 0.045
            if item then item.LastCFrame = cf end
            return cf, false
        end
    end

    if typeof(tgt) == "CFrame" then return tgt, false end
    if typeof(tgt) == "Vector3" then return CFrame.new(tgt), false end
    return CFrame.identity, true
end

-- ─── L7: методы флинга ────────────────────────────────────────────────────────

-- Вызывается раз в кадр из драйвера. rp/hum — рут и гуманоид настоящего
-- персонажа, cf — результат Fling.Predict, method — метод текущего элемента.
function Fling.DoFling(rp, hum, tgt, cf, method)
    local tp = Fling.GetPart(tgt)
    local t = os.clock()
    -- микродрожание ±0.12 стада, чтобы контакт не залипал в одной точке.
    -- Прибавляется после предикта, прицел не искажает.
    local orbit = Vector3.new(
        math.sin(t * 95) * 0.12,
        math.cos(t * 83) * 0.08,
        math.cos(t * 101) * 0.12
    )

    if method == "skidfling" then
        local base = Fling.SkidTargetPart(tgt) or tp
        if base then
            local wanted = Fling.SkidTargetCFrame(base, Fling.TargetHumanoid(tgt)) + orbit
            rp.CFrame = wanted
            if LocalPlayer.Character then
                LocalPlayer.Character:PivotTo(wanted)
            end
            Fling.SkidHold = wanted
            -- защита снимает CanCollide с чужих тел и мешает своему же контакту
            Fling.RestoreAntiFlingCollision()
            Fling.EnableSkidCollision(LocalPlayer.Character)
        else
            Fling.SkidHold = nil
        end

        local huge = Vector3.new(9e7, 9e8, 9e7)
        local spin = Vector3.new(9e8, 9e8, 9e8)
        local char = LocalPlayer.Character
        for _, obj in ipairs(char and char:GetDescendants() or {}) do
            if obj:IsA("BasePart") then
                obj.Velocity = huge
                obj.RotVelocity = spin
                obj.AssemblyLinearVelocity = huge
                obj.AssemblyAngularVelocity = spin
            end
        end

        hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        pcall(function() sethiddenproperty(hum, "MoveDirectionInternal", Vector3.new(0/0, 0/0, 0/0)) end)
        pcall(function() sethiddenproperty(hum, "NetworkHumanoidState", Enum.HumanoidStateType.Freefall) end)
        return
    end

    -- NaN: подмена физического рута. Клиент начинает реплицировать физику части
    -- цели как свою, MoveDirectionInternal = NaN отравляет расчёт движения.
    if tp ~= nil then
        pcall(function() sethiddenproperty(rp, "PhysicsRepRootPart", tp) end)
    end
    rp.CFrame = cf + orbit
    Fling.ZeroVelocity(rp)
    pcall(function() sethiddenproperty(hum, "MoveDirectionInternal", Vector3.new(0/0, 0/0, 0/0)) end)
    pcall(function() sethiddenproperty(hum, "NetworkHumanoidState", Enum.HumanoidStateType.Freefall) end)
end

-- ─── L8: драйвер и очередь ────────────────────────────────────────────────────

function Fling.NextItem()
    local now = os.clock()
    while Fling.Queue[1] do
        local q = Fling.Queue[1]
        if not q.Repeat and q.Deadline ~= nil and now > q.Deadline then
            table.remove(Fling.Queue, 1)
            Fling.RestoreTargetCollision()
        else
            return q
        end
    end
    return nil
end

-- Автостоп: решает, когда цель считается отфлингованной. Пороги для skid выше —
-- он и разгоняет сильнее, и стартует медленнее.
function Fling.ShouldBackOff(item)
    local now = os.clock()
    item.Start = item.Start or now
    item.Deadline = item.Deadline or (now + (item.Duration or 2))

    if not item.Repeat and now > item.Deadline then return true end

    local part = item.Repeat and Fling.RepeatPart(item) or Fling.GetPart(item.Target)
    if item.Repeat and item.Player ~= nil and not item.Player.Parent then return true end
    if not part then return false end
    if not part:IsDescendantOf(Workspace) then return not item.Repeat end
    if item.Repeat then return false end

    item.StartPos = item.StartPos or part.Position
    if now - item.Start < 0.12 then return false end

    local velocity = part.AssemblyLinearVelocity
    if Fling.ItemMethod(item) == "skidfling" then
        if now - item.Start < 0.22 then return false end
        if velocity.Magnitude > 500 then return true end
        if (part.Position - item.StartPos).Magnitude > 150 then return true end
        return false
    end

    if velocity.Magnitude > 150 or math.abs(velocity.Y) > 115 then return true end
    if (part.Position - item.StartPos).Magnitude > 80 then return true end
    return false
end

function Fling.FinishCurrentItem(sync)
    local item = table.remove(Fling.Queue, 1)
    Fling.SkidHold = nil
    Fling.RestoreTargetCollision()

    if item and item.PlayerName and State.Settings.NotificationsEnabled then
        ShowNotification(
            "<font color=\"rgb(220,220,220)\">Player flung: " .. item.PlayerName .. "</font>",
            CONFIG.Colors.Text
        )
    end

    Fling.EndSession(sync)
end

function Fling.QueueTarget(tgt, duration, repeatMode, playerName, method)
    if not tgt then return false end

    for _, q in ipairs(Fling.Queue) do
        if q.Target == tgt then return false end
    end
    if tgt == LocalPlayer.Character then return false end

    if typeof(tgt) == "Instance" then
        if LocalPlayer.Character and tgt:IsDescendantOf(LocalPlayer.Character) then return false end
        -- антидубль: одна и та же цель не ставится в очередь чаще раза в секунду
        if Fling.Cooldowns[tgt] ~= nil then return false end
        Fling.Cooldowns[tgt] = true
        Core.Tasks.delay(1, function() Fling.Cooldowns[tgt] = nil end)
    end

    table.insert(Fling.Queue, {
        Target = tgt,
        Duration = duration,
        Repeat = repeatMode or false,
        Player = repeatMode and Fling.PlayerFromTarget(tgt) or nil,
        PlayerName = playerName,
        -- nil = работать на общем State.FlingMethod; LoopFling кладёт свой
        Method = method and Fling.NormalizeMethod(method) or nil,
    })
    return true
end

function Fling.ActivateSession()
    State.Runtime.IsFlingInProgress = true
    Fling.SuppressClickToMove()
    if not Fling.SessionActive then Fling.BeginSession() end
    Fling.ResetRoot()
end

function Fling.ClearQueue(sync)
    if sync == nil then sync = true end
    table.clear(Fling.Queue)
    table.clear(Fling.Cooldowns)
    Fling.RestoreTargetCollision()
    Fling.RestoreSelfCollision()
    State.Runtime.IsFlingInProgress = false
    if Fling.SessionActive then
        Fling.EndSession(sync)
    else
        Fling.ResetRoot()
    end
end

-- ─── L9: антифлинг ────────────────────────────────────────────────────────────
-- Стратегия: снимать CanCollide с чужих тел, то есть не давать импульсу
-- посчитаться вообще. Локально — защищает от флингов, которые считаются на вашей
-- стороне; если атакующий перехватил network ownership вашего персонажа, расчёт
-- идёт у него и локальный CanCollide ни на что не влияет.
-- Побочка: вы проходите сквозь других игроков, пока защита включена.

function Fling.RestoreAntiFlingCollision()
    for p, c in pairs(Fling.AntiFlingCollision) do
        if not p.Parent then
            Fling.AntiFlingCollision[p] = nil
        elseif Fling.TargetCollision[p] == nil then
            -- часть, которую сейчас флингуем, трогать нельзя
            p.CanCollide = c
            Fling.AntiFlingCollision[p] = nil
        end
    end
    table.clear(Fling.StrippedChars)
    table.clear(Fling.FlingerSeen)
end

-- Полное подавление — только под свой skidfling: он бьёт контактом именно по
-- ЦЕЛИ, и снятая с неё коллизия ломает свой же удар. Для NaN исключения нет,
-- он работает через реплику.
function Fling.AntiFlingSuppressed()
    if not State.Settings.AntiFlingEnabled then return true end
    if Fling.Queue[1] ~= nil and Fling.ActiveMethod() == "skidfling" then return true end
    return false
end

-- Признак атакующего: разогнан до скоростей, которых при обычной игре не бывает.
function Fling.LooksLikeFlinger(char)
    local _, root = Fling.CharParts(char)
    if not root then return false end
    return root.AssemblyAngularVelocity.Magnitude > Fling.FlingerAngular
        or root.AssemblyLinearVelocity.Magnitude > Fling.FlingerLinear
end

function Fling.RestoreCharCollision(char)
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            local saved = Fling.AntiFlingCollision[obj]
            if saved ~= nil and Fling.TargetCollision[obj] == nil then
                obj.CanCollide = saved
                Fling.AntiFlingCollision[obj] = nil
            end
        end
    end
    Fling.StrippedChars[char] = nil
end

function Fling.StripCharCollision(char)
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            if Fling.AntiFlingCollision[obj] == nil then
                Fling.AntiFlingCollision[obj] = obj.CanCollide
            end
            if obj.CanCollide ~= false then
                obj.CanCollide = false
            end
        end
    end
    Fling.StrippedChars[char] = true
end

function Fling.UpdateAntiFling()
    if Fling.AntiFlingSuppressed() then
        Fling.RestoreAntiFlingCollision()
        return
    end

    -- Во время WalkFling защита переходит в избирательный режим: коллизия
    -- снимается только с тех, кто прямо сейчас разогнан до флинговых скоростей.
    -- Обычные игроки остаются столкновимыми, иначе свой walkfling их не достаёт.
    local selective = State.Runtime.WalkFlingActive
    local now = os.clock()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character

            if not selective then
                Fling.StripCharCollision(char)
            else
                -- Флингер разгоняется рывками и между ними выглядит обычным
                -- игроком, поэтому опасным он считается ещё FlingerHold секунд
                -- после последнего всплеска — иначе защита пропустит удар,
                -- попав проверкой в промежуток.
                if Fling.LooksLikeFlinger(char) then
                    Fling.FlingerSeen[char] = now
                end

                local seen = Fling.FlingerSeen[char]
                if seen and (now - seen) < Fling.FlingerHold then
                    Fling.StripCharCollision(char)
                elseif Fling.StrippedChars[char] then
                    -- отбегался — вернуть коллизию, чтобы снова стал флингуемым
                    Fling.RestoreCharCollision(char)
                    Fling.FlingerSeen[char] = nil
                end
            end
        end
    end

    for part in pairs(Fling.AntiFlingCollision) do
        if not part.Parent then
            Fling.AntiFlingCollision[part] = nil
        end
    end

    for char in pairs(Fling.FlingerSeen) do
        if not char.Parent then
            Fling.FlingerSeen[char] = nil
            Fling.StrippedChars[char] = nil
        end
    end
end

-- EnableAntiFling() - Включение защиты от флинга
local function EnableAntiFling()
    if State.Settings.AntiFlingEnabled then return end
    State.Settings.AntiFlingEnabled = true

    Fling.AntiFlingConn = Core.Connect(RunService.Stepped, function()
        Fling.UpdateAntiFling()
    end)
    TrackConnection(Fling.AntiFlingConn)
end

-- DisableAntiFling() - Отключение защиты
local function DisableAntiFling()
    State.Settings.AntiFlingEnabled = false

    if Fling.AntiFlingConn then
        Fling.AntiFlingConn:Disconnect()
        Fling.AntiFlingConn = nil
    end

    Fling.RestoreAntiFlingCollision()
end

-- ─── Связи ────────────────────────────────────────────────────────────────────

-- Главный цикл. runtime.doFling — не «отфлингуй игрока», а один кадр процесса.
TrackConnection(Core.Connect(RunService.PreSimulation, function()
    local char = LocalPlayer.Character
    local hum, rp = Fling.CharParts(char)
    if not char or not hum or not rp then return end

    if Fling.IsDead(hum) then
        Fling.DropDeadChar(char)
        return
    end

    if not Fling.Queue[1] and not Fling.SessionActive then return end
    if Fling.Queue[1] and not Fling.SessionActive then Fling.BeginSession() end
    if not Fling.SessionActive then return end

    Fling.SetFlingDestroyHeight()
    Fling.SaveHumanoidState(hum)

    hum.AutoRotate = false
    hum.RequiresNeck = false
    hum.BreakJointsOnDeath = false
    if hum.WalkSpeed < 1 then hum.WalkSpeed = 16 end
    if hum.JumpPower < 1 then hum.JumpPower = 50 end
    hum:ChangeState(Enum.HumanoidStateType.Freefall)

    local item = Fling.NextItem()
    if not item then
        Fling.EndSession(true)
        return
    end
    if Fling.ShouldBackOff(item) then
        Fling.FinishCurrentItem(true)
        return
    end

    local cf, done = Fling.Predict(item.Target, item)
    if done then
        Fling.FinishCurrentItem(true)
        return
    end

    State.Runtime.IsFlingInProgress = true
    local method = Fling.ItemMethod(item)
    if method ~= "skidfling" then
        Fling.NoCollideTarget(item.Target)
    end
    Fling.DoFling(rp, hum, item.Target, cf, method)
end))

-- Удержание позиции для skid: физика перетирает CFrame между кадрами.
TrackConnection(Core.Connect(RunService.PostSimulation, function()
    local wanted = Fling.SkidHold
    if not wanted or Fling.Queue[1] == nil or not Fling.SessionActive
       or Fling.ActiveMethod() ~= "skidfling" then
        Fling.SkidHold = nil
        return
    end
    local char = LocalPlayer.Character
    local _, rp = Fling.CharParts(char)
    if not char or not rp then
        Fling.SkidHold = nil
        return
    end
    rp.CFrame = wanted
    char:PivotTo(wanted)
end))

-- ⚠️ Здесь были: движение клона относительно камеры, ввод для управления клоном
-- (WASD/стик) и BindToRenderStep("MM2FlingMask") с ежекадровой маскировкой
-- настоящего персонажа. Всё вырезано вместе с гост-режимом: клона больше нет,
-- игрок сам управляет своим телом и видит реальный полёт.

Fling.BindCharacter(LocalPlayer.Character)
TrackConnection(Core.Connect(LocalPlayer.CharacterAdded, function(char)
    Fling.BindCharacter(char)
end))

-- Хук для FullShutdown: он объявлен выше по файлу, где локал Fling ещё не виден.
State.Runtime.FlingCleanup = function()
    -- sync = false: не возвращать игрока, просто всё свернуть
    Fling.ClearQueue(false)
    DisableAntiFling()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 9: FLING FUNCTIONS
-- ══════════════════════════════════════════════════════════════════════════════

-- FlingPlayer() - Главная функция флинга.
-- В отличие от старой версии не блокирует поток: ставит цель в очередь и выходит.
-- Дальше работает драйвер на PreSimulation, автостоп решает, когда закончить.
local function FlingPlayer(playerToFling, repeatMode, method)
    if not playerToFling or not playerToFling.Character then
        if State.Settings.NotificationsEnabled then
            ShowNotification(
                "<font color=\"rgb(255, 85, 85)\">Fling error: </font><font color=\"rgb(220,220,220)\">Body parts missing</font>",
                CONFIG.Colors.Text
            )
        end
        return
    end

    if playerToFling == LocalPlayer then return end

    local targetPart = Fling.SkidTargetPart(playerToFling.Character)
    if not targetPart then
        if State.Settings.NotificationsEnabled then
            ShowNotification(
                "<font color=\"rgb(255, 85, 85)\">Body parts missing</font>",
                CONFIG.Colors.Text
            )
        end
        return
    end

    if targetPart.AssemblyLinearVelocity.Magnitude > Fling.FlungSpeed then
        -- Считаем клики по летящей цели за последние ForceWindow секунд
        local now = os.clock()
        local clicks = {}
        for _, t in ipairs(Fling.ForceClickLog[playerToFling.UserId] or {}) do
            if now - t <= Fling.ForceWindow then table.insert(clicks, t) end
        end
        table.insert(clicks, now)
        if #clicks < Fling.ForceClicks then
            Fling.ForceClickLog[playerToFling.UserId] = clicks
            if State.Settings.NotificationsEnabled then
                ShowNotification(
                    "<font color=\"rgb(220,220,220)\">Fling: Already flung</font>",
                    CONFIG.Colors.Text
                )
            end
            return
        end
        -- Третий клик подряд — флингуем, даже если цель ещё летит
        Fling.ForceClickLog[playerToFling.UserId] = nil
    end

    if not Fling.QueueTarget(targetPart, nil, repeatMode, playerToFling.Name, method) then return end
    Fling.ActivateSession()
end

-- FlingMurderer() - Флинг убийцы
local function FlingMurderer()
    local murderer = getMurder()
    if not murderer then
        if State.Settings.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">Murderer not found</font>", CONFIG.Colors.Text)
        end
        return
    end

    if murderer == LocalPlayer then
        if State.Settings.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">You cannot fling yourself!</font>", CONFIG.Colors.Text)
        end
        return
    end

    FlingPlayer(murderer)
end

-- Walk Fling: гигантская скорость уходит в сеть, а своя физика идёт с настоящей.
-- Схема как у Velocity Spoofer: подмена на Heartbeat, синхронное восстановление на
-- первом RenderStep. Раньше внутри Heartbeat ждали RenderStepped:Wait(): при
-- отложенных сигналах поток просыпался уже после физики, и персонаж сам улетал
-- (замер: сотни кадров со скачком >2 stud, до 397 stud за кадр).
local WalkFlingSpoof = {
    BindName = "MM2_WalkFlingRestore",
    Root = nil, Real = nil, Sent = nil,
    Range = 12,          -- подменяем, только когда кто-то рядом: иначе лишь дрожь для остальных
    NextNearbyCheck = 0, Nearby = false,
}

local function walkFlingRestore()
    local root, real, sent = WalkFlingSpoof.Root, WalkFlingSpoof.Real, WalkFlingSpoof.Sent
    WalkFlingSpoof.Root, WalkFlingSpoof.Real, WalkFlingSpoof.Sent = nil, nil, nil
    if root and root.Parent and real and sent then
        -- Убираем только свою подмену: изменения скорости между фазами сохраняются.
        root.AssemblyLinearVelocity = root.AssemblyLinearVelocity - sent + real
    end
end

local function walkFlingTargetNearby(root)
    local now = os.clock()
    if now < WalkFlingSpoof.NextNearbyCheck then return WalkFlingSpoof.Nearby end
    WalkFlingSpoof.NextNearbyCheck = now + 0.1
    WalkFlingSpoof.Nearby = false
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player ~= LocalPlayer and player.Character
        local other = character and character:FindFirstChild("HumanoidRootPart")
        if other and (other.Position - root.Position).Magnitude <= WalkFlingSpoof.Range then
            WalkFlingSpoof.Nearby = true
            break
        end
    end
    return WalkFlingSpoof.Nearby
end

local function WalkFlingStop(forced)
    if not forced then
        State.Settings.WalkFlingEnabledByUser = false
    end

    if not State.Runtime.WalkFlingActive then return end
    State.Runtime.WalkFlingActive = false

    if State.Runtime.WalkFlingConnection then
        State.Runtime.WalkFlingConnection:Disconnect()
        State.Runtime.WalkFlingConnection = nil
    end
    pcall(function() RunService:UnbindFromRenderStep(WalkFlingSpoof.BindName) end)
    pcall(walkFlingRestore)
    State.Runtime.NetBoost("walkfling", false)
    Fling.ResumeFakePosition("walk")

    -- Полный сброс физики персонажа
    Core.Tasks.spawn(function()
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
    State.Settings.WalkFlingEnabledByUser = true
    if State.Runtime.WalkFlingActive then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Антифлинг больше не выключается вручную: он сам подавляется, пока поднят
    -- State.WalkFlingActive (см. Fling.AntiFlingSuppressed). Иначе снятая с чужих
    -- тел коллизия убивала бы WalkFling — он тоже бьёт контактом.
    Fling.PauseFakePosition("walk")
    State.Runtime.WalkFlingActive = true
    -- 60 пакетов/с: подменённая скорость чаще доходит до цели в момент контакта.
    State.Runtime.NetBoost("walkfling", true)

    local bound = pcall(function()
        RunService:BindToRenderStep(WalkFlingSpoof.BindName, Enum.RenderPriority.First.Value, function()
            pcall(walkFlingRestore)
        end)
    end)
    if not bound then
        WalkFlingStop(true)
        return
    end

    State.Runtime.WalkFlingConnection = Core.Connect(RunService.Heartbeat, function()
        -- Каждый Heartbeat начинаем с настоящей скорости: подмена не накапливается.
        walkFlingRestore()
        -- ВАЖНО: Получаем СВЕЖУЮ ссылку каждый кадр
        local currentChar = LocalPlayer.Character
        local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        local currentHum = currentChar and currentChar:FindFirstChild("Humanoid")

        if not currentRoot or not currentHum or currentHum.Health <= 0 then
            WalkFlingStop(true)
            return
        end

        if not State.Runtime.WalkFlingActive then
            WalkFlingStop()
            return
        end

        local vel = currentRoot.AssemblyLinearVelocity
        if vel.Magnitude <= 2 or not walkFlingTargetNearby(currentRoot) then return end

        -- Прежний ±0.1 по Y не нужен: подмена только в движении (>2 studs/s), а
        -- движущийся персонаж и так отправляется.
        local sent = vel * 10000 + Vector3.new(0, 10000, 0)
        WalkFlingSpoof.Root, WalkFlingSpoof.Real, WalkFlingSpoof.Sent = currentRoot, vel, sent
        currentRoot.AssemblyLinearVelocity = sent
    end)
end

-- === АВТОМАТИЧЕСКИЙ ПЕРЕЗАПУСК ПРИ СМЕНЕ ПЕРСОНАЖА ===
Core.Connect(LocalPlayer.CharacterAdded, function(character)
    if State.Settings.WalkFlingEnabledByUser then
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
Core.Tasks.spawn(function()
    while Core.Alive do
        task.wait(1)
        if not Core.Alive then break end
        if State.Settings.WalkFlingEnabledByUser and not State.Runtime.WalkFlingActive then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                WalkFlingStart()
            end
        end
    end
end)

Core.Movement.ToggleWalkFling = function()
    if State.Settings.WalkFlingEnabledByUser then
        WalkFlingStop(false)
    else
        WalkFlingStart()
    end
end

-- FlingSheriff() - Флинг шерифа
-- ⚠️ Раньше здесь стоял getSheriffForAutoFarm() = findRoleHolder("Gun", false, nil):
-- поиск ТОЛЬКО по предмету, без фолбэка на серверные роли. Пока шериф не держал
-- Gun (начало раунда, ган выпал и лежит на карте), функция возвращала nil и
-- выдавала «Sheriff not found» — отсюда «флингается только когда получит ствол».
-- FlingMurderer таким не страдал, потому что зовёт getMurder() с фолбэком.
-- Берём getSheriff() = findRoleHolder("Gun", true, "Sheriff") — та же пара, что
-- getMurder() у убийцы: сперва по предмету, затем по роли из State.PlayerData.
local function FlingSheriff()
    local sheriff = getSheriff()
    if not sheriff then
        if State.Settings.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">Sheriff not found</font>", CONFIG.Colors.Text)
        end
        return
    end

    if sheriff == LocalPlayer then
        if State.Settings.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">You cannot fling yourself!</font>", CONFIG.Colors.Text)
        end
        return
    end

    FlingPlayer(sheriff)
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 10: NOCLIP SYSTEM
-- ══════════════════════════════════════════════════════════════════════════════

-- EnableNoClip() - Включение NoClip
local function EnableNoClip()
    if State.Settings.NoClipEnabled then return end
    State.Settings.NoClipEnabled = true

    local NoClipObjects = {}
    -- Исходный CanCollide каждой части до ноклипа. Выключение раньше ставило true
    -- ВСЕМ частям: у R15 руки/ноги по умолчанию без коллизии, а в MM2 они на
    -- физических суставах — упираясь в пол, вжимали тело в землю (особенно со
    -- Spin), и помогало только снова включить ноклип
    local originalCollide = setmetatable({}, {__mode = "k"})
    State.Runtime.NoClipOriginal = originalCollide
    -- Персонаж, под который собран список. Пересобираем не только по
    -- CharacterAdded: флинг и прочие фичи могут подменить/дополнить части, а
    -- пустой список молча выключал ноклип навсегда.
    local boundChar = nil

    local function collect(character)
        table.clear(NoClipObjects)
        boundChar = character
        if not character then return end
        for _, obj in ipairs(character:GetChildren()) do
            if obj:IsA("BasePart") then
                table.insert(NoClipObjects, obj)
                if originalCollide[obj] == nil then originalCollide[obj] = obj.CanCollide end
            end
        end
    end

    collect(LocalPlayer.Character)
    State.Runtime.NoClipObjects = NoClipObjects

    State.Runtime.NoClipRespawnConnection = TrackConnection(Core.Connect(LocalPlayer.CharacterAdded, function(newChar)
        task.wait(0.15)
        if not State.Settings.NoClipEnabled then return end
        collect(newChar)
    end))

    State.Runtime.NoClipConnection = TrackConnection(Core.Connect(RunService.Stepped, function()
        -- Во время флинга коллизия тела — рабочий инструмент skidfling'а.
        -- Ноклип на это время уступает, свои значения флинг вернёт сам.
        -- Три условия, а не одно: если State.IsFlingInProgress где-то залипнет,
        -- пустая очередь и закрытая сессия всё равно вернут ноклип в работу.
        if State.Runtime.IsFlingInProgress and Fling.SessionActive and Fling.Queue[1] then
            return
        end

        local character = LocalPlayer.Character
        if character ~= boundChar or #NoClipObjects == 0 then
            collect(character)
            State.Runtime.NoClipObjects = NoClipObjects
        end

        for i = 1, #NoClipObjects do
            local part = NoClipObjects[i]
            if part.Parent and part.CanCollide then
                part.CanCollide = false
            end
        end
    end))

    if State.Settings.NotificationsEnabled then
        ShowNotification("<font color=\"rgb(220,220,220)\">Noclip: </font><font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Text)
    end
end

-- DisableNoClip() - Отключение NoClip
local function DisableNoClip()
    if not State.Settings.NoClipEnabled then return end
    State.Settings.NoClipEnabled = false

    if State.Runtime.NoClipConnection then
        State.Runtime.NoClipConnection:Disconnect()
        State.Runtime.NoClipConnection = nil
    end

    if State.Runtime.NoClipRespawnConnection then
        State.Runtime.NoClipRespawnConnection:Disconnect()
        State.Runtime.NoClipRespawnConnection = nil
    end

    if State.Runtime.NoClipObjects then
        local character = LocalPlayer.Character
        local original = State.Runtime.NoClipOriginal or {}
        if character then
            for i = 1, #State.Runtime.NoClipObjects do
                local part = State.Runtime.NoClipObjects[i]
                if part and part.Parent then
                    -- Возвращаем как было; для неизвестной части — как у Humanoid
                    -- по умолчанию: коллизия только у торса и головы (корень без
                    -- снимка не трогаем — его вернёт снимок флинга ниже)
                    local saved = original[part]
                    if saved == nil and part.Name ~= "HumanoidRootPart" then
                        saved = part.Name == "Head" or part.Name == "Torso"
                            or part.Name == "UpperTorso" or part.Name == "LowerTorso"
                    end
                    if saved ~= nil then part.CanCollide = saved end
                end
            end
        end
        State.Runtime.NoClipOriginal = nil

        table.clear(State.Runtime.NoClipObjects)
        State.Runtime.NoClipObjects = nil
    end

    -- Снимок, снятый флингом, мог быть сделан при включённом ноклипе — то есть
    -- со значениями false. Если ноклип выключили посреди флинга, его завершение
    -- вернуло бы эти false и оставило тело неcтолкновимым уже без ноклипа.
    -- Набор частей у обоих одинаковый (прямые дети), поэтому снимок отдаём:
    -- рут возвращаем по нему (цикл выше его намеренно не трогает), остальное
    -- уже поднято в true.
    for part, saved in pairs(Fling.SelfCollision) do
        if part.Parent and part.Name == "HumanoidRootPart" then
            pcall(function() part.CanCollide = saved end)
        end
    end
    table.clear(Fling.SelfCollision)

    if State.Settings.NotificationsEnabled then
        ShowNotification("<font color=\"rgb(220,220,220)\">Noclip:</font> <font color=\"rgb(255, 85, 85)\">OFF</font>", CONFIG.Colors.Red)
    end
end


-- ═══════════════════════════════════════════════════════════
-- FLY ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
-- ═══════════════════════════════════════════════════════════
local function getRoot(char)
	if char and char:FindFirstChildOfClass("Humanoid") then
		return char:FindFirstChildOfClass("Humanoid").RootPart
	else
		return nil
	end
end
local swimming = false
local oldgrav = workspace.Gravity
local swimbeat = nil
local gravReset = nil

-- ═══════════════════════════════════════════════════════════
-- FLY SYSTEM
-- ═══════════════════════════════════════════════════════════
-- Fly / Vehicle Fly: каждый Heartbeat сдвигаем CFrame по MoveDirection и держим
-- маленькую скорость вверх, чтобы гравитация не тянула вниз. Прежний Fly (IY)
-- читал только НАЖАТИЯ WASD после включения — зажатую заранее W приходилось
-- перенажимать — и ставил PlatformStand + BodyGyro/BodyVelocity. Здесь ввод берётся
-- из MoveDirection каждый кадр, состояние гуманоида и физобъекты не трогаются.
-- Вертикаль: Space/E — вверх, Q — вниз, W/S — по наклону камеры.
local function startMotionFly(vehicle)
    if State.Runtime.FlyConnection then State.Runtime.FlyConnection:Disconnect() end
    State.Runtime.FlyConnection = Core.Connect(RunService.Heartbeat, function(dt)
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = humanoid and humanoid.RootPart
        if not root or humanoid.Health <= 0 then return end
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local typing = UserInputService:GetFocusedTextBox() ~= nil
        local function down(key) return not typing and UserInputService:IsKeyDown(key) end

        local look = camera.CFrame.LookVector
        local move = humanoid.MoveDirection
        local body = root
        if vehicle then
            -- Vehicle Fly — полёт сидя (Sit-эмоция, сиденье): у сидящего гуманоида
            -- MoveDirection нулевой, поэтому направление — по WASD относительно камеры.
            -- В незаякоренном сиденье двигаем всю его сборку
            local seat = humanoid.SeatPart
            local seatRoot = seat and seat.AssemblyRootPart
            if seatRoot and not seatRoot.Anchored then body = seatRoot end
            local forward = Vector3.new(look.X, 0, look.Z)
            local right = camera.CFrame.RightVector
            right = Vector3.new(right.X, 0, right.Z)
            forward = forward.Magnitude > 1e-3 and forward.Unit or Vector3.zero
            right = right.Magnitude > 1e-3 and right.Unit or Vector3.zero
            local f = (down(Enum.KeyCode.W) and 1 or 0) - (down(Enum.KeyCode.S) and 1 or 0)
            local r = (down(Enum.KeyCode.D) and 1 or 0) - (down(Enum.KeyCode.A) and 1 or 0)
            move = forward * f + right * r
            if move.Magnitude > 1 then move = move.Unit end
        end

        local vertical
        if down(Enum.KeyCode.Space) or down(Enum.KeyCode.E) then
            vertical = 1
        elseif down(Enum.KeyCode.Q) then
            vertical = -1
        else
            local pitch = (down(Enum.KeyCode.S) and -look.Y) or (down(Enum.KeyCode.W) and look.Y) or 0
            vertical = pitch * math.clamp(move.Magnitude, 0, 1)
        end

        body.AssemblyLinearVelocity = CONFIG.Fly.HoverVelocity
        State.Runtime.MoveRoot(body, Vector3.new(move.X, vertical, move.Z) * (dt * State.Settings.FlySpeed))
    end)
end

local function stopMotionFly()
    if State.Runtime.FlyConnection then
        State.Runtime.FlyConnection:Disconnect()
        State.Runtime.FlyConnection = nil
    end
    -- Остаточная подпорка скорости не должна подкидывать после выключения
    local root = getRoot(LocalPlayer.Character)
    if root then pcall(function() root.AssemblyLinearVelocity = Vector3.zero end) end
end

-- Swim
local function startSwim()
    local speaker = LocalPlayer
    if not swimming and speaker and speaker.Character and speaker.Character:FindFirstChildWhichIsA("Humanoid") then
        oldgrav = Workspace.Gravity
        Workspace.Gravity = 0

        local swimDied = function()
            Workspace.Gravity = oldgrav
            swimming = false
        end

        local Humanoid = speaker.Character:FindFirstChildWhichIsA("Humanoid")
        gravReset = Core.Connect(Humanoid.Died, swimDied)

        local enums = Enum.HumanoidStateType:GetEnumItems()
        table.remove(enums, table.find(enums, Enum.HumanoidStateType.None))
        for i, v in pairs(enums) do
            Humanoid:SetStateEnabled(v, false)
        end
        Humanoid:ChangeState(Enum.HumanoidStateType.Swimming)

        swimbeat = Core.Connect(RunService.Heartbeat, function()
            pcall(function()
                local root = getRoot(speaker.Character)
                if root then
                    root.Velocity = ((Humanoid.MoveDirection ~= Vector3.new() or UserInputService:IsKeyDown(Enum.KeyCode.Space)) and root.Velocity or Vector3.new())
                end
            end)
        end)

        swimming = true
        State.Runtime.SwimConnection = swimbeat
        Core.Track(gravReset)
        Core.Track(swimbeat)
    end
end

-- Отключение Swim
local function stopSwim()
    local speaker = LocalPlayer
    if speaker and speaker.Character and speaker.Character:FindFirstChildWhichIsA("Humanoid") then
        Workspace.Gravity = oldgrav
        swimming = false

        if gravReset then
            gravReset:Disconnect()
            gravReset = nil
        end
        if swimbeat ~= nil then
            swimbeat:Disconnect()
            swimbeat = nil
        end

        local Humanoid = speaker.Character:FindFirstChildWhichIsA("Humanoid")
        local enums = Enum.HumanoidStateType:GetEnumItems()
        table.remove(enums, table.find(enums, Enum.HumanoidStateType.None))
        for i, v in pairs(enums) do
            Humanoid:SetStateEnabled(v, true)
        end
    end
end

-- Главные функции управления. quiet — без уведомления (режим Hold: включение на
-- каждое удержание бинда не должно спамить тостами)
local function StartFly(flyType, quiet)
    if State.Settings.FlyEnabled then return end
    if not table.find(CONFIG.Fly.Modes, flyType) then flyType = CONFIG.Fly.Modes[1] end

    State.Settings.FlyEnabled = true
    State.Settings.FlyType = flyType

    if flyType == "Swim" then
        startSwim()
    else
        startMotionFly(flyType == "Vehicle Fly")
    end

    if not quiet and State.Settings.NotificationsEnabled then
        ShowNotification("<font color=\"rgb(220,220,220)\">Fly</font> (" .. flyType .. "): <font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Text)
    end
end

local function StopFly(quiet)
    if not State.Settings.FlyEnabled then return end

    local currentType = State.Settings.FlyType
    State.Settings.FlyEnabled = false

    if currentType == "Swim" then
        stopSwim()
    else
        stopMotionFly()
    end

    if not quiet and State.Settings.NotificationsEnabled then
        ShowNotification("<font color=\"rgb(220,220,220)\">Fly </font>(" .. currentType .. "): <font color=\"rgb(255, 85, 85)\">OFF</font>", CONFIG.Colors.Text)
    end
end

-- ═══════════════════════════════════════════════════════════
-- SPEED И РЕЖИМЫ БИНДОВ (Toggle / Hold)
-- ═══════════════════════════════════════════════════════════
-- Speed (перенос из стороннего скрипта, стиль normal): WalkSpeed не трогаем, а
-- каждый Heartbeat досдвигаем CFrame по MoveDirection на SpeedValue studs/s.
-- Свойство WalkSpeed остаётся ванильным (его проверяют клиентские античиты),
-- и наружу уходит обычная скорость ходьбы.
-- Режим бинда у Speed и Fly (выпадающий список в строке фичи):
--   Toggle — нажатие бинда включает/выключает; Hold — работает, пока бинд зажат;
--   Always — работает всегда. Пока фича работает, чип бинда подсвечен акцентом.
do
    local MovementBinds = {
        {Key = "Speed", Mode = "SpeedBindMode", Setting = "SpeedEnabled", Row = "SpeedBindRow"},
        {Key = "Fly", Mode = "FlyBindMode", Setting = "FlyToggleOn", Row = "FlyBindRow"},
    }

    State.Runtime.BindHeld = function(key)
        local bind = State.Settings.Keybinds[key]
        if not bind or bind == Enum.KeyCode.Unknown then return false end
        if UserInputService:GetFocusedTextBox() then return false end
        return UserInputService:IsKeyDown(bind)
    end

    local function bindActive(entry)
        local mode = State.Settings[entry.Mode]
        if mode == "Always" then return true end
        if mode == "Hold" then return State.Runtime.BindHeld(entry.Key) end
        return State.Settings[entry.Setting] == true
    end

    -- Нажатие бинда в режиме Toggle
    State.Runtime.OnMovementBind = function(input)
        for _, entry in ipairs(MovementBinds) do
            local bind = State.Settings.Keybinds[entry.Key]
            if bind and bind ~= Enum.KeyCode.Unknown and input.KeyCode == bind and State.Settings[entry.Mode] == "Toggle" then
                State.Settings[entry.Setting] = not State.Settings[entry.Setting]
            end
        end
    end

    -- Смена режима сбрасывает «включено биндом», чтобы Toggle не стартовал сам
    State.Runtime.SetBindMode = function(key, mode)
        if not table.find(CONFIG.BindModes, mode) then return end
        for _, entry in ipairs(MovementBinds) do
            if entry.Key == key then
                State.Settings[entry.Mode] = mode
                State.Settings[entry.Setting] = false
            end
        end
    end

    Core.Connect(RunService.Heartbeat, function(dt)
        local speedOn, wantFly = bindActive(MovementBinds[1]), bindActive(MovementBinds[2])
        for i, on in ipairs({speedOn, wantFly}) do
            local row = State.Runtime[MovementBinds[i].Row]
            if row and row.SetActive then row:SetActive(on) end
        end

        -- Fly: уведомления только в режиме Toggle — Hold/Always не спамят тостами
        if wantFly ~= State.Settings.FlyEnabled then
            local quiet = State.Settings.FlyBindMode ~= "Toggle"
            if wantFly then StartFly(State.Settings.FlyType, quiet) else StopFly(quiet) end
        end

        -- Speed
        local value = State.Settings.SpeedValue
        if not speedOn or value <= 0 or State.Settings.FlyEnabled then return end
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = humanoid and humanoid.RootPart
        if not root or humanoid.Health <= 0 or humanoid.SeatPart or humanoid.PlatformStand or root.Anchored then return end
        local move = humanoid.MoveDirection
        State.Runtime.MoveRoot(root, Vector3.new(move.X, 0, move.Z) * (dt * value))
    end)
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 11: AUTO FARM SYSTEM
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

    -- УРОВЕНЬ 2: Прямой путь - "Coin" вместо "SnowToken"
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

    if success and coins >= 0 then  -- >= 0 вместо > 0
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
    State.Cache.CoinBlacklist[coin] = true
end

-- Очистка между раундами
local function CleanupCoinBlacklist()

    local cleaned = 0
    for coin, _ in pairs(State.Cache.CoinBlacklist) do
        if not coin.Parent then
            State.Cache.CoinBlacklist[coin] = nil
            cleaned = cleaned + 1
        end
    end

end

-- ResetCharacter() - Ресет персонажа (автофарм: выйти из раунда до его конца)
local function ResetCharacter()
    pcall(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.Health = 0 end
    end)
end

local function FloatCharacter()
    local character = LocalPlayer.Character
    if not character then return false end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    -- FIX: Проверка существования и здоровья
    if not hrp or not humanoid or humanoid.Health <= 0 then
        return false
    end

    -- Удаляем старый BodyPosition если есть
    local oldBP = hrp:FindFirstChild("AFK_BodyPosition")
    if oldBP then oldBP:Destroy() end

    -- Создаём BodyPosition для левитации
    local bodyPos = Core.New("BodyPosition")
    bodyPos.Name = "AFK_BodyPosition"
    bodyPos.Position = hrp.Position
    bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyPos.D = 1250
    bodyPos.P = 10000
    bodyPos.Parent = hrp

    -- Также создаём BodyGyro для стабилизации вращения
    local oldBG = hrp:FindFirstChild("AFK_BodyGyro")
    if oldBG then oldBG:Destroy() end

    local bodyGyro = Core.New("BodyGyro")
    bodyGyro.Name = "AFK_BodyGyro"
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.P = 10000
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp

    return true
end

-- ИСПРАВЛЕНО: Добавлена проверка существования
local function UnfloatCharacter()
    local character = LocalPlayer.Character
    if not character then return false end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- FIX: Проверка существования перед удалением
    local bodyPos = hrp:FindFirstChild("AFK_BodyPosition")
    if bodyPos and bodyPos.Parent then
        bodyPos:Destroy()
    end

    local bodyGyro = hrp:FindFirstChild("AFK_BodyGyro")
    if bodyGyro and bodyGyro.Parent then
        bodyGyro:Destroy()
    end

    return true
end

local function FindSafeAFKSpot()
    local character = LocalPlayer.Character
    if not character then return nil end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    -- FIX: Проверка здоровья
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
           and not State.Cache.CoinBlacklist[coin] then

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

    return closestCoin, closestDistance -- ВОЗВРАЩАЕМ ЕЩЁ И РАССТОЯНИЕ
end

-- НОВАЯ ФУНКЦИЯ: Быстрая проверка на более близкую монету
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
           and not State.Cache.CoinBlacklist[coin] then

            local coinVisual = coin:FindFirstChild("CoinVisual")
            if coinVisual then
                local distance = (coin.Position - hrpPosition).Magnitude

                -- Новая монета должна быть ЗНАЧИТЕЛЬНО ближе
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
    speed = speed or State.Settings.CoinFarmFlySpeed

    local startPos = humanoidRootPart.Position

    local targetPos
    if State.Settings.UndergroundMode then
        targetPos = coin.Position - Vector3.new(0, State.Settings.UndergroundOffset, 0)
    else
        targetPos = coin.Position + Vector3.new(0, 1, 0)
    end

    local distance = (targetPos - startPos).Magnitude
    local duration = distance / speed

    local startTime = tick()
    local collectionAttempted = false

    -- Переменные для динамической проверки
    local lastCheckTime = tick()
    local checkInterval = 0.3 -- Проверяем каждые 0.3 секунды

    while tick() - startTime < duration do
        if not State.Settings.AutoFarmEnabled then break end

        -- ПРОВЕРКА: существует ли монета
        if not coin or not coin.Parent then
            return false, nil
        end

        local coinVisual = coin:FindFirstChild("CoinVisual")
        if not coinVisual then
            return false, nil
        end

        -- ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: монета всё ещё собираемая
        local touchTransmitter = coin:FindFirstChildWhichIsA("TouchTransmitter")
        if not touchTransmitter then
            return false, nil
        end

        local character = LocalPlayer.Character
        if not character or not humanoidRootPart.Parent then break end

        -- ДИНАМИЧЕСКАЯ ПРОВЕРКА НА БОЛЕЕ БЛИЗКУЮ МОНЕТУ
        local currentTime = tick()
        if currentTime - lastCheckTime >= checkInterval then
            lastCheckTime = currentTime

            local currentDistance = (humanoidRootPart.Position - coin.Position).Magnitude
            local betterCoin, betterDistance = FindBetterCoin(coin, currentDistance, 10)

            if betterCoin then
                -- Найдена более близкая монета - прерываем текущий полёт
                return "switch", betterCoin
            end
        end

        local elapsed = tick() - startTime
        local alpha = math.min(elapsed / duration, 1)

        local currentPos = startPos:Lerp(targetPos, alpha)

        local cframe
        if State.Settings.UndergroundMode then
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

        if alpha >= 0.90 and not collectionAttempted then
            collectionAttempted = true
            if firetouchinterest then
                Core.Tasks.spawn(function()
                    firetouchinterest(humanoidRootPart, coin, 0)
                    task.wait(0.05)
                    firetouchinterest(humanoidRootPart, coin, 1)
                end)
            end
        end

        task.wait()
    end

    if State.Settings.UndergroundMode then
        local finalCFrame = CFrame.new(humanoidRootPart.Position) * CFrame.Angles(math.rad(90), 0, 0)
        humanoidRootPart.CFrame = finalCFrame
    end

    return true, nil
end

local shootMurderer
local InstantKillAll
local knifeThrow

local function CountPlayersWithKnife()
    local count = 0
    local Players = game:GetService("Players")

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

-- StartAutoFarm() - Запуск авто фарма (с интеграцией XP Farm)
local function StartAutoFarm()
    if State.Runtime.CoinFarmThread then
        task.cancel(State.Runtime.CoinFarmThread)
        State.Runtime.CoinFarmThread = nil
    end

    if not State.Settings.AutoFarmEnabled then return end

    State.Cache.CoinBlacklist = {}

    State.Runtime.CoinFarmThread = Core.Tasks.spawn(function()
        local allowFly = false

        if State.Settings.AutoFarmEnabled and not State.Settings.IsInvisible then
            pcall(function()
                ToggleInvisibility()
            end)
        end

        local noCoinsAttempts = 0
        local maxNoCoinsAttempts = 4
        local lastTeleportTime = 0

        while State.Settings.AutoFarmEnabled do


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


            if not murdererExists then

                State.Cache.CoinBlacklist = {}
                noCoinsAttempts = 0
                allowFly = false
                pcall(function()
                    UnfloatCharacter()
                end)
                if State.Settings.AutoFarmEnabled and not State.Settings.IsInvisible then
                    pcall(function()
                        ToggleInvisibility()
                    end)
                end
                task.wait(1)
                continue
            end

            local currentCoins = GetCollectedCoinsCount()

            if currentCoins >= 40 then
                noCoinsAttempts = maxNoCoinsAttempts
            else
                local coin = FindNearestCoin()


                if not coin then
                    noCoinsAttempts = noCoinsAttempts + 1

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

                            if timeSinceLastTP < State.Settings.CoinFarmDelay and lastTeleportTime > 0 then
                                local waitTime = State.Settings.CoinFarmDelay - timeSinceLastTP
                                task.wait(waitTime)
                            end

                            if State.Settings.AutoFarmEnabled and State.Settings.IsInvisible then
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
                            -- ОБРАБОТКА ДИНАМИЧЕСКОЙ СМЕНЫ ЦЕЛИ
                            local currentTargetCoin = coin
                            local maxRedirects = 5
                            local redirectCount = 0

                            while currentTargetCoin and redirectCount < maxRedirects do
                                local result, newTarget = SmoothFlyToCoin(currentTargetCoin, humanoidRootPart, State.Settings.CoinFarmFlySpeed)

                                if result == "switch" and newTarget then
                                    -- ПРОСТО ПЕРЕКЛЮЧАЕМСЯ, БЕЗ BLACKLIST!
                                    RemoveCoinTracer()
                                    CreateCoinTracer(character, newTarget)

                                    currentTargetCoin = newTarget
                                    redirectCount = redirectCount + 1

                                elseif result == true then
                                    -- Успешно долетели до цели
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

                    if State.Settings.XPFarmEnabled then
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
                        if getMurderForAutoFarm() ~= nil and State.Settings.AutoFarmEnabled and State.Settings.XPFarmEnabled then
                            pcall(function()
                                InstantKillAll()
                            end)
                        end

                        -- Ждём конца раунда
                        repeat
                            task.wait(1)
                        until getMurderForAutoFarm() == nil or not State.Settings.AutoFarmEnabled

                    else
                        -- XP Farm выключен: просто ресет
                        pcall(function()
                            UnfloatCharacter()
                        end)

                        ResetCharacter()
                        State.Cache.CoinBlacklist = {}
                        noCoinsAttempts = 0
                        allowFly = false

                        task.wait(2)
                        -- Ждём конца раунда
                        repeat
                            task.wait(1)
                        until getMurderForAutoFarm() == nil or not State.Settings.AutoFarmEnabled
                    end

                    -- Общий cleanup после Snowball
                    if not State.Settings.AutoFarmEnabled then
                        break
                    end

                    pcall(function()
                        UnfloatCharacter()
                    end)

                    CleanupCoinBlacklist()
                    task.wait(5)

                    -- Ждём нового раунда
                    repeat
                        if not State.Settings.IsInvisible then
                            pcall(function()
                                ToggleInvisibility()
                            end)
                        end
                        task.wait(1)
                    until getMurderForAutoFarm() ~= nil or not State.Settings.AutoFarmEnabled

                    if not State.Settings.AutoFarmEnabled then
                        break
                    end

                    State.Cache.CoinBlacklist = {}
                    noCoinsAttempts = 0
                    allowFly = false

                elseif State.Settings.XPFarmEnabled then


                    currentCoins = GetCollectedCoinsCount()


                    if currentCoins >= 40 then
                        character = LocalPlayer.Character
                        if character then
                            humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

                            if humanoidRootPart then
                                local safeSpot = FindSafeAFKSpot()
                                if safeSpot then
                                    humanoidRootPart.CFrame = safeSpot + Vector3.new(0, 5, 0)


                                    task.wait(0.5)
                                    local floatSuccess = FloatCharacter()
                                    if floatSuccess then

                                    end

                                    task.wait(0.5)
                                end

                                if State.Settings.XPFarmEnabled then
                                    local murderer = getMurderForAutoFarm()
                                    local sheriff = getSheriffForAutoFarm()

                                    if murderer == LocalPlayer then

                                        --[[
                                        -- Включаем spawnAtPlayer если был выключен
                                        if not State.spawnAtPlayer then
                                            State.spawnAtPlayer = true

                                        end

                                        -- Счётчик попыток knifeThrow
                                        local throwAttempts = 0
                                        local maxThrowAttempts = 1
                                        local throwDelay = 3

                                        -- Цикл knifeThrow с ограничением попыток
                                        while getMurder() ~= nil and State.AutoFarmEnabled and State.XPFarmEnabled and throwAttempts < maxThrowAttempts do
                                            local success, error = pcall(function()
                                                knifeThrow(true)  -- true = silent mode
                                            end)

                                            throwAttempts = throwAttempts + 1

                                            if success then

                                            else

                                            end

                                            task.wait(throwDelay)
                                        end
                                        --]]
                                        -- Fallback: если после 1 попыток раунд не завершился
                                        if getMurderForAutoFarm() ~= nil and State.Settings.AutoFarmEnabled and State.Settings.XPFarmEnabled then


                                            local success, error = pcall(function()
                                                InstantKillAll()
                                            end)

                                            if success then

                                            else

                                            end
                                        else

                                        end

                                    elseif sheriff == LocalPlayer then


                                            local shootAttempts = 0
                                            local maxShootAttempts = 30

                                            while getMurderForAutoFarm() ~= nil and State.Settings.AutoFarmEnabled and State.Settings.XPFarmEnabled and shootAttempts < maxShootAttempts do
                                                character = LocalPlayer.Character
                                                if not character then

                                                    break
                                                end

                                                local murdererPlayer = getMurderForAutoFarm()
                                                if not murdererPlayer then

                                                    break
                                                end

                                                -- Проверяем существование персонажа мурдерера
                                                local murdererChar = murdererPlayer.Character
                                                if not murdererChar then

                                                    task.wait(0.5)
                                                    continue
                                                end

                                                -- Стреляем только если кулдаун готов
                                                if State.Settings.CanShootMurderer then
                                                    shootAttempts = shootAttempts + 1

                                                    pcall(function()
                                                        shootMurderer(true) -- тихий режим, без спама уведомлениями
                                                    end)

                                                    task.wait(State.Settings.ShootCooldown + 0.1) -- учитываем реальный кулдаун с запасом
                                                else
                                                    -- Кулдаун ещё идёт – немного ждём
                                                    task.wait(0.5)
                                                end
                                            end

                                            -- Проверяем причину выхода из цикла
                                            if getMurderForAutoFarm() == nil then

                                            elseif shootAttempts >= maxShootAttempts then

                                            elseif not State.Settings.XPFarmEnabled then

                                            elseif not State.Settings.AutoFarmEnabled then

                                            end
                                    else


                                        -- Сразу после закрепления - первый флинг
                                        pcall(function()
                                            FlingMurderer()
                                        end)

                                        task.wait(1)

                                        local flingAttempts = 1  -- Уже выполнили 1 флинг
                                        local maxFlingAttempts = 10

                                        while getMurderForAutoFarm() ~= nil and State.Settings.AutoFarmEnabled and State.Settings.XPFarmEnabled and flingAttempts < maxFlingAttempts do
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

                                                    break
                                                elseif velocity > 100 then

                                                    task.wait(1)
                                                    continue
                                                end
                                            end

                                            pcall(function()
                                                FlingMurderer()
                                            end)

                                            flingAttempts = flingAttempts + 1


                                            task.wait(3)

                                            if getMurderForAutoFarm() == nil then

                                                break
                                            end
                                        end

                                        if not State.Settings.XPFarmEnabled then

                                        end
                                    end
                                else

                                end
                            end
                        end
                    end
                    repeat
                        task.wait(1)
                    until getMurderForAutoFarm() == nil or not State.Settings.AutoFarmEnabled

                    if not State.Settings.AutoFarmEnabled then
                        break
                    end

                    pcall(function()
                        UnfloatCharacter()
                    end)

                    CleanupCoinBlacklist()
                    task.wait(5)

                    if getMurderForAutoFarm() ~= nil then
                        State.Cache.CoinBlacklist = {}
                        noCoinsAttempts = 0
                        continue
                    end

                    ResetCharacter()
                    State.Cache.CoinBlacklist = {}
                    noCoinsAttempts = 0

                    task.wait(2)

                    repeat
                        if not State.Settings.IsInvisible then
                            pcall(function()
                                ToggleInvisibility()
                            end)
                        end
                        task.wait(1)
                    until getMurderForAutoFarm() ~= nil or not State.Settings.AutoFarmEnabled

                    if not State.Settings.AutoFarmEnabled then
                        break
                    end

                    State.Cache.CoinBlacklist = {}
                    noCoinsAttempts = 0
                    allowFly = false

                else

                    CleanupCoinBlacklist()
                    pcall(function()
                        UnfloatCharacter()
                    end)

                    ResetCharacter()
                    State.Cache.CoinBlacklist = {}
                    noCoinsAttempts = 0
                    allowFly = false

                    task.wait(2)

                    repeat
                        task.wait(1)
                    until getMurderForAutoFarm() == nil or not State.Settings.AutoFarmEnabled

                    if not State.Settings.AutoFarmEnabled then

                        break
                    end


                    repeat
                        if not State.Settings.IsInvisible then
                            pcall(function()
                                ToggleInvisibility()
                            end)
                        end
                        task.wait(1)
                    until getMurderForAutoFarm() ~= nil or not State.Settings.AutoFarmEnabled

                    if not State.Settings.AutoFarmEnabled then

                        break
                    end

                    State.Cache.CoinBlacklist = {}
                    noCoinsAttempts = 0
                end
            end
        end

        State.Runtime.CoinFarmThread = nil

    end)
end

-- ОБНОВЛЁННАЯ StopAutoFarm с правильным cleanup
local function StopAutoFarm()
    RemoveCoinTracer()
    State.Settings.AutoFarmEnabled = false

    if State.Runtime.CoinFarmThread then
        task.cancel(State.Runtime.CoinFarmThread)
        State.Runtime.CoinFarmThread = nil
    end

    pcall(UnfloatCharacter)
    pcall(DisableNoClip)

    -- ДОБАВЛЕНО: очистка кэша
    coinLabelCache = nil
    lastCacheTime = 0

    State.Cache.CoinBlacklist = {}
    State.Settings.SpawnAtPlayer = spawnAtPlayerOriginalState

end


-- ══════════════════════════════════════════════════════════════════════════════
-- XP FARM SYSTEM
-- ══════════════════════════════════════════════════════════════════════════════

-- Главная функция XP фарма (оптимизированная версия)
local function StartXPFarm()
    -- Просто активируем флаг, Auto Farm сделает всё сам
    State.Settings.XPFarmEnabled = true

end

local function StopXPFarm()
    State.Settings.XPFarmEnabled = false
    pcall(function()
        UnfloatCharacter()
    end)

end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 12: PLAYER NICKNAMES ESP
-- ══════════════════════════════════════════════════════════════════════════════

----------------------------------------------------------------
-- PLAYER NICKNAMES ESP
----------------------------------------------------------------

local nicknamesConnection = nil
local playerConnections = {}

local function CreatePlayerNicknameESP(player)
    if not player or player == LocalPlayer then return end

    -- Дополнительные проверки
    if not player.Parent then return end
    if not player:IsDescendantOf(game) then return end

    local character = player.Character
    if not character or not character.Parent then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp.Parent then return end

    -- Удаляем старый ESP если есть
    if State.Cache.PlayerNicknamesCache[player] then
        RemovePlayerNicknameESP(player)
    end

    local billboard = Core.New("BillboardGui")
    billboard.Name = "PlayerNicknameESP"
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 140, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = State.Settings.PlayerNicknamesESP
    billboard.Parent = hrp

    local label = Core.New("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = player.Name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextStrokeTransparency = 0.6
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = billboard

    State.Cache.PlayerNicknamesCache[player] = {
        billboard = billboard
    }
end


local function RemovePlayerNicknameESP(player)
    if not player or not State.Cache.PlayerNicknamesCache[player] then return end

    local espData = State.Cache.PlayerNicknamesCache[player]

    pcall(function()
        if espData.billboard then
            espData.billboard:Destroy()
        end
    end)

    State.Cache.PlayerNicknamesCache[player] = nil
end

local function UpdatePlayerNicknamesVisibility()
    for player, espData in pairs(State.Cache.PlayerNicknamesCache) do
        if espData.billboard then
            espData.billboard.Enabled = State.Settings.PlayerNicknamesESP
        end
    end
end

local function SetupPlayerTracking(player)
    if player == LocalPlayer then return end
    if playerConnections[player] then return end

    playerConnections[player] = {}

    -- CharacterAdded
    playerConnections[player].charAdded = Core.Connect(player.CharacterAdded, function(char)
        task.wait(0.5)
        if State.Settings.PlayerNicknamesESP then
            CreatePlayerNicknameESP(player)
        end
    end)

    -- CharacterRemoving
    playerConnections[player].charRemoving = Core.Connect(player.CharacterRemoving, function()
        RemovePlayerNicknameESP(player)
    end)

    -- Если у игрока уже есть персонаж
    if player.Character and State.Settings.PlayerNicknamesESP then
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
    TrackConnection(Core.Connect(Players.PlayerAdded, function(player)
        SetupPlayerTracking(player)
    end))

    -- Отслеживаем выход игроков
    TrackConnection(Core.Connect(Players.PlayerRemoving, function(player)
        RemovePlayerTracking(player)
    end))

    -- Heartbeat для обновления видимости
    nicknamesConnection = Core.Connect(RunService.Heartbeat, function()
        pcall(function()
            for player, espData in pairs(State.Cache.PlayerNicknamesCache) do
                if espData.billboard then
                    espData.billboard.Enabled = State.Settings.PlayerNicknamesESP
                end
            end
        end)
    end)

    Core.Track(nicknamesConnection)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 13: TROLLING FEATURES
-- ══════════════════════════════════════════════════════════════════════════════

-- RigidOrbitPlayer() - Орбита вокруг игрока
local function RigidOrbitPlayer(targetName, enabled)
    if enabled then
        State.Runtime.OrbitAngle = 0
        State.Runtime.OrbitThread = Core.Tasks.spawn(function()
            while State.Settings.OrbitEnabled do
                pcall(function()
                    local target = getPlayerByName(targetName)
                    if target and target.Character then
                        local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
                        local myChar = LocalPlayer.Character

                        if targetHRP and myChar then
                            local myHRP = myChar:FindFirstChild("HumanoidRootPart")
                            if myHRP then
                                State.Runtime.OrbitAngle = State.Runtime.OrbitAngle + State.Settings.OrbitSpeed

                                local angleRad = math.rad(State.Runtime.OrbitAngle)
                                local tiltRad = math.rad(State.Settings.OrbitTilt)

                                local x = math.cos(angleRad) * State.Settings.OrbitRadius
                                local z = math.sin(angleRad) * State.Settings.OrbitRadius

                                local y = math.sin(angleRad) * State.Settings.OrbitRadius * math.sin(tiltRad)
                                local adjustedX = x * math.cos(tiltRad)
                                local adjustedZ = z * math.cos(tiltRad)

                                myHRP.CFrame = targetHRP.CFrame * CFrame.new(
                                    adjustedX,
                                    State.Settings.OrbitHeight + y,
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
        if State.Runtime.OrbitThread then
            task.cancel(State.Runtime.OrbitThread)
            State.Runtime.OrbitThread = nil
        end
    end
end

-- SimpleLoopFling() - Цикличный флинг.
-- Идёт своим методом (State.LoopFlingMethod), не трогая общий State.FlingMethod:
-- метод кладётся в элемент очереди, ручной флинг рядом продолжает работать своим.
local function SimpleLoopFling(targetName, enabled)
    if enabled then
        State.Runtime.LoopFlingThread = Core.Tasks.spawn(function()
            while State.Settings.LoopFlingEnabled do
                pcall(function()
                    local target = getPlayerByName(targetName)
                    if target then
                        FlingPlayer(target, false, State.Settings.LoopFlingMethod)
                    end
                end)
                task.wait(math.clamp(State.Settings.LoopFlingInterval or 5, 1, 15))
            end
        end)
    else
        if State.Runtime.LoopFlingThread then
            task.cancel(State.Runtime.LoopFlingThread)
            State.Runtime.LoopFlingThread = nil
        end
    end
end

-- PendulumBlockPath() - Маятник перед игроком
local function PendulumBlockPath(targetName, enabled)
    if enabled then
        State.Runtime.BlockPathPosition = 0
        State.Runtime.BlockPathDirection = 1

        State.Runtime.BlockPathThread = Core.Tasks.spawn(function()
            while State.Settings.BlockPathEnabled do
                pcall(function()
                    local target = getPlayerByName(targetName)
                    if target and target.Character then
                        local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
                        local myChar = LocalPlayer.Character

                        if targetHRP and myChar then
                            local myHRP = myChar:FindFirstChild("HumanoidRootPart")
                            if myHRP then
                                State.Runtime.BlockPathPosition = State.Runtime.BlockPathPosition + (State.Settings.BlockPathSpeed * State.Runtime.BlockPathDirection)

                                if State.Runtime.BlockPathPosition >= 5 then
                                    State.Runtime.BlockPathDirection = -1
                                elseif State.Runtime.BlockPathPosition <= -5 then
                                    State.Runtime.BlockPathDirection = 1
                                end

                                local offset = CFrame.new(0, 0, State.Runtime.BlockPathPosition)

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
        if State.Runtime.BlockPathThread then
            task.cancel(State.Runtime.BlockPathThread)
            State.Runtime.BlockPathThread = nil
        end
    end
end
-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 15: COMBAT FUNCTIONS
-- ══════════════════════════════════════════════════════════════════════════════

-- PlayEmote() - Воспроизведение эмоций
local function PlayEmote(emoteName)
    Core.Tasks.spawn(function()
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
    if State.Settings.SpawnAtPlayer then
        local nearestPlayer = findNearestPlayer()
        if nearestPlayer and nearestPlayer.Character then
            local targetHRP = nearestPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetHRP then
                -- Как у Magic: предикт по пингу + полёт ножа, прицел в реальный торс,
                -- точка появления ножа — с чистым путём до цели (раньше: ровно 4 studs
                -- за спиной без проверки стен и без упреждения)
                local targetHum = nearestPlayer.Character:FindFirstChildOfClass("Humanoid")
                local pingValue = 50
                pcall(function()
                    pingValue = tonumber(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString():match("%d+")) or 50
                end)
                local spawnDistance = 3
                local travel = spawnDistance / 96   -- ThrowSpeed ножа по умолчанию, studs/s
                local aimPoint = State.Runtime.ComputeAimPoint(nearestPlayer.Character, targetHRP, targetHum,
                    pingValue / 1000 + (State.Settings.ShootLead or 0.09) + travel)
                local velocity = targetHRP.AssemblyLinearVelocity
                local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
                local preferred = {-targetHRP.CFrame.LookVector}
                if flatVelocity.Magnitude > 2 then table.insert(preferred, 1, flatVelocity) end
                spawnPosition = State.Runtime.FindClearOrigin(aimPoint, nearestPlayer.Character, preferred, spawnDistance)

                -- Нож летит дальше цели — прицел не должен обрываться у тела
                local direction = (aimPoint - spawnPosition)
                direction = direction.Magnitude > 1e-3 and direction.Unit or -targetHRP.CFrame.LookVector
                targetPosition = aimPoint + direction * 500
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

    if success then
        task.wait()  -- Ждем только при успехе

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

-- ─── Предикт точки попадания под серверный hitscan ────────────────────────────
-- Сервер стреляет лучом origin→target и убивает первого задетого. Значит важна
-- ТОЧНОСТЬ мировой точки прицела НА ТЕЛЕ цели в момент обработки на сервере.
--   • Горизонталь (XZ): по ИНТЕНТУ — MoveDirection·WalkSpeed, а не по наблюдаемой
--     скорости. Намерение реплицируется без пинг-задержки и без шума от книбэков,
--     раньше ловит смену strafe. Если цель не управляется (стоит / летит / во
--     флинге, MoveDirection≈0) — падаем на фактическую XZ-скорость.
--   • Вертикаль (Y): параболическая, с учётом гравитации (pos + vy·t − ½·g·t²).
--     Линейный предикт по Y — причина промахов при прыжке: на подъёме завышает
--     («чуть выше»), на падении занижает.
--   • Пол под предсказанной XZ-колонкой (луч вниз): не даём прицелу уйти под
--     землю при приземлении — именно это давало «сильно ниже». Кламп ±2.4 к
--     ТЕКУЩЕМУ Y убран: при большом прыжке/высоком пинге тело уезжает дальше и
--     кламп сам уводил в промах. Параболу + пол не клампим, они уже физичны.
local function predictAimPoint(hrp, thum, t)
    t = math.clamp(t, 0.03, 0.25)  -- отсекаем выбросы при огромном пинге
    local pos = hrp.Position
    local vel = hrp.AssemblyLinearVelocity
    local char = hrp.Parent

    -- горизонталь по интенту
    local hx, hz
    local md = thum and thum.MoveDirection
    if md and md.Magnitude > 0.05 then
        local ws = (thum.WalkSpeed and thum.WalkSpeed > 0) and thum.WalkSpeed or 16
        local unit = Vector3.new(md.X, 0, md.Z).Unit
        hx, hz = unit.X * ws, unit.Z * ws
    else
        hx, hz = vel.X, vel.Z
    end
    local predX = pos.X + hx * t
    local predZ = pos.Z + hz * t

    -- вертикаль: парабола + пол под предсказанной точкой
    local g = Workspace.Gravity
    local predY = pos.Y + vel.Y * t - 0.5 * g * t * t

    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { char, LocalPlayer.Character }
    local down = Workspace:Raycast(Vector3.new(predX, pos.Y + 3, predZ), Vector3.new(0, -80, 0), rp)
    if down then
        -- превышение центра HRP над полом сейчас (адаптация под R6/R15/HipHeight)
        local standOffset = 2.9
        local curDown = Workspace:Raycast(Vector3.new(pos.X, pos.Y + 3, pos.Z), Vector3.new(0, -80, 0), rp)
        if curDown then standOffset = math.clamp(pos.Y - curDown.Position.Y, 1.5, 4) end
        predY = math.max(predY, down.Position.Y + standOffset)
    end

    return Vector3.new(predX, predY, predZ)
end

-- ─── Выбор части-цели для луча ─────────────────────────────────────────────────
-- Серверный hitscan засчитывает попадание по ВИДИМЫМ частям тела, а не по
-- невидимому HumanoidRootPart. У обычного рига HRP совпадает с торсом, но:
--   • скины со смещённым/нестандартным ригом уводят HRP от реальной геометрии;
--   • анимации (замах, подкат, эмоции) сильно двигают торс/конечности от HRP.
-- Тогда прицел в HRP попадает в пустоту рядом с телом → промах. Поэтому целимся
-- в реальную центральную часть: торс → голова → крупнейшая часть тела.
local AIM_PART_PRIORITY = { "UpperTorso", "Torso", "LowerTorso", "Head" }
local function pickAimPart(char)
    if not char then return nil end
    for _, name in ipairs(AIM_PART_PRIORITY) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    -- фолбэк под нестандартные скины: крупнейший BasePart тела
    local best, bestVol
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart")
           and not obj:FindFirstAncestorOfClass("Accessory")
           and not obj:FindFirstAncestorOfClass("Tool") then
            local v = obj.Size.X * obj.Size.Y * obj.Size.Z
            if not bestVol or v > bestVol then best, bestVol = obj, v end
        end
    end
    return best
end

-- Итоговая точка прицела: реальная часть тела + предсказанное перемещение
-- персонажа. predictAimPoint даёт будущую позицию HRP → берём её дельту и сдвигаем
-- на неё выбранную часть (анимационный оффсет части берём текущий — за окно пинга
-- он почти не меняется). Так прицел всегда на реальной геометрии, а не на корне.
local function computeAimPoint(char, hrp, thum, t)
    local predictedHRP = predictAimPoint(hrp, thum, t)
    local part = pickAimPart(char)
    if not part then return predictedHRP end
    return part.Position + (predictedHRP - hrp.Position)
end
-- knifeThrow объявлен в файле раньше — достаёт предиктор отсюда
State.Runtime.ComputeAimPoint = computeAimPoint

-- ─── Свободная точка вылета (Magic-выстрел и Spawn Knife Near Player) ─────────
-- Сервер бьёт лучом (или гонит нож) от присланной нами точки к цели, и стена
-- между ними съедает попадание. Раньше точка стояла на фиксированном смещении
-- (5 studs по ходу / 3 за спиной) — у стены она уходила внутрь стены или за неё.
-- Теперь перебираем направления от цели: сначала предпочтительные, потом круг и
-- круг под углом сверху; луч от цели к точке проверяет, что путь чист. Берём
-- первое полностью чистое, иначе — с наибольшим свободным расстоянием.
-- Лучи ловят всё с CanQuery (включая некасаемые), как консервативный серверный.
-- Функция в State.Runtime: у чанка почти исчерпан лимит локалей.
State.Runtime.FindClearOrigin = function(targetPos, targetChar, preferred, distance)
    distance = distance or 4
    local minDistance = math.min(1.5, distance)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {targetChar, LocalPlayer.Character, Workspace.CurrentCamera}

    local directions = {}
    for _, dir in ipairs(preferred or {}) do
        if dir.Magnitude > 1e-3 then table.insert(directions, dir.Unit) end
    end
    for i = 0, 11 do
        local a = i * math.pi / 6
        table.insert(directions, Vector3.new(math.cos(a), 0, math.sin(a)))
    end
    for i = 0, 7 do
        local a = i * math.pi / 4
        table.insert(directions, Vector3.new(math.cos(a), 1, math.sin(a)).Unit)
    end
    table.insert(directions, Vector3.yAxis)

    -- Луч, стартующий внутри детали, её не видит — поэтому путь проверяем в обе
    -- стороны: от цели наружу (находит стену) и от вылета к цели (как серверный луч)
    local function clearBack(origin)
        return Workspace:Raycast(origin, targetPos - origin, params) == nil
    end

    local bestOrigin, bestFree = nil, -1
    for _, dir in ipairs(directions) do
        local hit = Workspace:Raycast(targetPos, dir * distance, params)
        local free = hit and hit.Distance - 0.5 or distance
        local origin = targetPos + dir * math.max(free, 0.1)
        if clearBack(origin) then
            if not hit then return origin end
            if free > bestFree then bestFree, bestOrigin = free, origin end
        end
    end
    if bestFree >= minDistance then return bestOrigin end
    -- Цель зажата со всех сторон: вылет почти из самой цели
    return bestOrigin or targetPos + Vector3.yAxis * 0.5
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 15.1: SHERIFF AIM — трекер убийцы, предикт выстрела, Resolver, Auto Fire
-- ══════════════════════════════════════════════════════════════════════════════
-- Почему так (цифры — в CONFIG.SheriffAim):
--  • Промах шерифа — почти всегда смена ввода убийцы, пока выстрел «в пути». Но
--    MoveDirection приходит на ~0.14 с раньше позиции, и бо́льшая часть окна
--    упреждения уже известна: симулируем гуманоида по истории ввода, а не тянем
--    скорость по прямой. Неизвестен лишь хвост ≈ пинг − 0.1 с.
--  • Хвост раскладываем на сценарии (продолжит / стоп / разворот / вбок / прыжок)
--    с весами из поведения ЭТОЙ цели и считаем, какая доля весов даёт попадание
--    луча в её реальные хитбоксы (части тела + аксессуары, как на сервере).
--    Прицел — точка с наибольшей долей; Auto Fire стреляет, когда луч до неё чист.
--  • Resolver сверяет заявленную скорость со смещением реплицированной позиции:
--    честный игрок их не расходит, спуфер — сильно и подолгу.
-- Всё — через State.Runtime.SheriffAim: у главного чанка почти кончились локали.
do
    local SA = CONFIG.SheriffAim
    local RES = SA.Resolver
    local Aim = {
        Target = nil,          -- Player-убийца, за которым следим
        Samples = {},          -- {t, pos, vel, md, ws}: последние SA.History с
        Segments = {},         -- длительности завершённых отрезков постоянного ввода
        SegDir = nil, SegStart = nil,
        Jumps = {},            -- моменты отрыва от земли
        WasGrounded = true,
        StandOffset = nil,     -- высота HRP над полом стоящей цели
        TrackSince = nil,
        Spoof = false,         -- Resolver решил, что скорость цели подменена
        Suspects = {}, SuspectSince = nil, CleanSince = nil,
        SegTimes = {},         -- моменты смены ввода (для самопроверки)
        Checks = {},           -- предсказания, ждущие проверки: {due, t0, pos}
        Errors = {},           -- {t, err}: фактические ошибки предикта на этой цели
        NextCheck = 0,
        Health = 1,            -- множитель уверенности по самопроверке
        KIndex = CONFIG.SheriffAim.IntentLeadDefault,   -- текущий кандидат опережения ввода
        KError = {}, KSamples = 0,                      -- калибровка K (свойство сети, между целями не сбрасываем)
        NextShot = 0,          -- os.clock(), раньше которого сервер отбросит выстрел
        Pending = nil,         -- выстрел, для которого ждём серверный трассер
        Log = {},              -- последние автовыстрелы: шанс, резолв, итог
        NextAuto = 0,
    }
    State.Runtime.SheriffAim = Aim
    Core.SheriffAim = Aim      -- для замеров снаружи: getgenv().MM2_Runtime.SheriffAim

    local function flat(v) return Vector3.new(v.X, 0, v.Z) end

    local function pingSeconds()
        local ping = 0.2
        pcall(function()
            ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end)
        return math.clamp(ping, 0, SA.MaxLead)
    end
    Aim.Ping = pingSeconds

    -- Лучи по карте: без персонажей, камеры и серверных трассеров (Part+Beam в корне)
    local function mapParams(extra)
        local ignore = {Workspace.CurrentCamera}
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then table.insert(ignore, player.Character) end
        end
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("BasePart") and child.Name == "Part" and child:FindFirstChildOfClass("Beam") then
                table.insert(ignore, child)
            end
        end
        if extra then for _, inst in ipairs(extra) do table.insert(ignore, inst) end end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignore
        params.IgnoreWater = true
        return params
    end

    local function resetTrack(target)
        if target ~= Aim.Target and Aim.ResetDiag then Aim.ResetDiag() end
        Aim.Target = target
        table.clear(Aim.Samples); table.clear(Aim.Segments); table.clear(Aim.Jumps)
        table.clear(Aim.Suspects)
        table.clear(Aim.SegTimes); table.clear(Aim.Checks); table.clear(Aim.Errors)
        Aim.Health, Aim.NextCheck, Aim.LastRise = 1, 0, nil
        Aim.SegDir, Aim.SegStart = nil, nil
        Aim.WasGrounded, Aim.StandOffset = true, nil
        Aim.TrackSince = target and os.clock() or nil
        Aim.Spoof, Aim.SuspectSince, Aim.CleanSince = false, nil, nil
    end

    local function sameInput(a, b)
        local am, bm = a.Magnitude > 0.1, b.Magnitude > 0.1
        if am ~= bm then return false end
        if not am then return true end
        return a.Unit:Dot(b.Unit) >= math.cos(math.rad(SA.SegmentAngle))
    end

    -- Позиционная и средняя заявленная скорость цели за последние window с
    local function windowVelocity(window)
        local samples = Aim.Samples
        local n = #samples
        if n < 3 then return nil end
        local newest = samples[n]
        local i = n
        while i > 1 and newest.t - samples[i - 1].t <= window do i -= 1 end
        local dt = newest.t - samples[i].t
        if dt < window * 0.6 then return nil end
        local sum = Vector3.zero
        for k = i, n do sum += samples[k].vel end
        return (newest.pos - samples[i].pos) / dt, sum / (n - i + 1)
    end

    -- Resolver: доля кадров с подменой за последнюю секунду. Включаем, только если
    -- доля держится высокой EngageTime подряд; выключаем после Release без подозрений.
    -- Честного игрока окно 0.3 с не расходит (замер ≤ 4 / 9.7 studs/s) — при сомнении
    -- резолв не включается и выстрел идёт как без резолвера.
    local function updateResolver(now)
        if not State.Settings.ResolverEnabled then
            if Aim.Spoof or #Aim.Suspects > 0 then
                Aim.Spoof, Aim.SuspectSince, Aim.CleanSince = false, nil, nil
                table.clear(Aim.Suspects)
            end
            return
        end
        local posVel, repVel = windowVelocity(RES.Window)
        if not posVel then return end
        local horiz = (flat(posVel) - flat(repVel)).Magnitude
        local vert = math.abs(posVel.Y - repVel.Y)
        local suspect = vert > RES.VertMismatch
            or horiz > math.max(RES.HorizMismatch, RES.HorizRatio * flat(posVel).Magnitude)
        table.insert(Aim.Suspects, {now, suspect})
        while #Aim.Suspects > 1 and now - Aim.Suspects[1][1] > 1 do table.remove(Aim.Suspects, 1) end
        local count = 0
        for _, entry in ipairs(Aim.Suspects) do if entry[2] then count += 1 end end
        local share = count / #Aim.Suspects
        if share >= RES.Engage then Aim.SuspectSince = Aim.SuspectSince or now else Aim.SuspectSince = nil end
        if suspect then Aim.CleanSince = nil else Aim.CleanSince = Aim.CleanSince or now end
        if not Aim.Spoof and Aim.SuspectSince and now - Aim.SuspectSince >= RES.EngageTime then
            Aim.Spoof = true
        elseif Aim.Spoof and Aim.CleanSince and now - Aim.CleanSince >= RES.Release then
            Aim.Spoof = false
        end
    end

    -- Скорость, от которой стартует предикт: заявленная, а при резолве — по смещению
    local function sourceVelocity()
        local newest = Aim.Samples[#Aim.Samples]
        if Aim.Spoof then
            local posVel = windowVelocity(0.12) or windowVelocity(RES.Window)
            if posVel then return posVel end
        end
        return newest.vel
    end

    -- Пол под точкой: высота или nil
    local function floorY(pos, params)
        local hit = Workspace:Raycast(pos + Vector3.new(0, 1.5, 0), Vector3.new(0, -80, 0), params)
        return hit and hit.Position.Y or nil
    end

    -- Наблюдение за убийцей: каждый кадр, пока у нас пистолет или включён Auto Fire
    local function track(now)
        local murderer = getMurder()
        if murderer == LocalPlayer then murderer = nil end
        if murderer ~= Aim.Target then resetTrack(murderer) end
        local char = murderer and murderer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then
            -- смерть цели — конец раунда для статистики, даже если убийцей снова будет он же
            if #Aim.Samples > 0 then Aim.ResetDiag(); resetTrack(murderer) end
            return
        end
        local pos, md = hrp.Position, hum.MoveDirection
        local last = Aim.Samples[#Aim.Samples]
        if last and (pos - last.pos).Magnitude / math.max(now - last.t, 1 / 240) > RES.TeleportSpeed then
            resetTrack(murderer)   -- телепорт/респавн: старая история врёт
        end
        table.insert(Aim.Samples, {t = now, pos = pos, vel = hrp.AssemblyLinearVelocity,
            md = Vector3.new(md.X, 0, md.Z), ws = hum.WalkSpeed})
        while #Aim.Samples > 2 and now - Aim.Samples[1].t > SA.History do table.remove(Aim.Samples, 1) end

        -- Отрезки постоянного ввода → как часто эта цель меняет направление
        local input = Aim.Samples[#Aim.Samples].md
        if not Aim.SegDir then
            Aim.SegDir, Aim.SegStart = input, now
        elseif not sameInput(Aim.SegDir, input) then
            table.insert(Aim.Segments, now - Aim.SegStart)
            if #Aim.Segments > 24 then table.remove(Aim.Segments, 1) end
            table.insert(Aim.SegTimes, now)
            if #Aim.SegTimes > 32 then table.remove(Aim.SegTimes, 1) end
            Aim.SegDir, Aim.SegStart = input, now
        end

        updateResolver(now)

        -- Земля/прыжки: вертикаль берём из источника скорости (при резолве — по позиции)
        local params = mapParams()
        local floor = floorY(pos, params)
        local vy = sourceVelocity().Y
        local height = floor and pos.Y - floor
        local grounded = height ~= nil and height < (Aim.StandOffset or 3.2) + 0.7 and math.abs(vy) < 10
        if grounded and math.abs(vy) < 1.5 and height > 1 then
            Aim.StandOffset = Aim.StandOffset and (Aim.StandOffset * 0.8 + height * 0.2) or height
        end
        -- Отрыв: вертикальная скорость ПО СМЕЩЕНИЮ пересекла порог снизу. Так и
        -- спуфер не обманет, и не нужна точная «земля» (ступеньки тоже сюда попадут —
        -- для самопроверки это тоже «не ошибка модели»)
        local rise = windowVelocity(0.1)
        rise = rise and rise.Y or vy
        if (Aim.LastRise or 0) < 6 and rise >= 12 then
            table.insert(Aim.Jumps, now)
            if #Aim.Jumps > 16 then table.remove(Aim.Jumps, 1) end
        end
        Aim.LastRise = rise
        Aim.WasGrounded = grounded
        Aim.Grounded = grounded
    end

    -- Последний известный ввод на момент t (ступенька по истории)
    local function inputAt(t)
        local samples = Aim.Samples
        for i = #samples, 1, -1 do
            if samples[i].t <= t then return samples[i].md end
        end
        return samples[1].md
    end

    -- Горизонтальная симуляция гуманоида: первые K с — ввод из истории (он уже
    -- известен, но в видимую позицию ещё не попал), дальше — текущий или сценарный
    local function simulate(ctx, override, changeAt)
        local offset, velocity = Vector3.zero, ctx.v0
        local tau, stepMax = 0, SA.SimStep
        while tau < ctx.L - 1e-6 do
            local step = math.min(stepMax, ctx.L - tau)
            local input
            if tau < ctx.K then
                input = inputAt(ctx.now - ctx.K + tau)
            elseif override and tau >= ctx.K + changeAt then
                input = override
            else
                input = ctx.input
            end
            local want = input * ctx.ws - velocity
            if tau < ctx.airTime then
                -- в воздухе: разгон с ограниченным ускорением (замер ~140 studs/s²)
                local gap = want.Magnitude
                local limit = SA.AirAccel * step
                velocity += gap > limit and want * (limit / gap) or want
            else
                velocity += want * (1 - math.exp(-SA.Response * step))
            end
            offset += velocity * step
            tau += step
        end
        return offset
    end

    -- Стена на пути: упираемся в неё и скользим вдоль (одна итерация)
    local function collide(ctx, offset)
        local distance = offset.Magnitude
        if distance < 0.05 then return offset end
        local dir = offset / distance
        local hit = Workspace:Raycast(ctx.pos, dir * (distance + 1), ctx.params)
        if not hit then return offset end
        local allowed = math.max(hit.Distance - 1, 0)
        local remaining = offset - dir * allowed
        local normal = flat(hit.Normal)
        if normal.Magnitude > 1e-3 then
            normal = normal.Unit
            local slide = remaining - normal * remaining:Dot(normal)
            local start = ctx.pos + dir * allowed
            if slide.Magnitude > 0.05 and not Workspace:Raycast(start, slide.Unit * (slide.Magnitude + 1), ctx.params) then
                return dir * allowed + slide
            end
        end
        return dir * allowed
    end

    -- Вертикаль: на земле — пол под новой точкой, в воздухе — парабола до пола;
    -- jump — прыжок в начале неизвестного хвоста
    local function vertical(ctx, offset, jump)
        local g = Workspace.Gravity
        local base = ctx.pos + offset
        local dy
        if jump then
            local u = math.max(ctx.L - ctx.K, 0)
            dy = ctx.jumpVelocity * u - 0.5 * g * u * u
        elseif ctx.grounded then
            dy = 0
        else
            dy = ctx.vy * ctx.L - 0.5 * g * ctx.L * ctx.L
        end
        local floor = floorY(Vector3.new(base.X, ctx.pos.Y + math.max(dy, 0), base.Z), ctx.params)
        if floor then
            local stand = floor + ctx.standOffset - ctx.pos.Y
            if ctx.grounded and not jump then
                -- ступеньки/склон: следуем за полом, обрыв (> 3 studs) не угадываем
                if math.abs(stand) <= 3 then dy = stand end
            else
                dy = math.max(dy, stand)
            end
        end
        return dy
    end

    -- Контекст предикта на текущий кадр; nil — предсказывать нечего
    local function makeContext()
        local target = Aim.Target
        local char = target and target.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local newest = Aim.Samples[#Aim.Samples]
        if not hrp or not hum or not newest or #Aim.Samples < 3 then return nil end
        local velocity = sourceVelocity()
        local L = pingSeconds() + SA.ServerLead
        local input = newest.md
        -- Скорость ходьбы: свойство (серверное значение); если цель реально бежит
        -- быстрее по направлению ввода — берём наблюдаемую. Без резолва наблюдаемая —
        -- заявленная (её и режет Zero-спуфер), с резолвом — по смещению позиции
        local ws = (newest.ws and newest.ws > 0) and newest.ws or CONFIG.DefaultWalkSpeed
        local planar = flat(velocity)
        if input.Magnitude > 0.1 and planar.Magnitude > ws and planar.Unit:Dot(input.Unit) > 0.9 then
            ws = planar.Magnitude
        end
        -- Упёрся в стену / тянется медленнее своей скорости: ввод давно не менялся
        -- (дольше, чем идёт до видимой позиции), а по смещению цель почти стоит —
        -- ходьбу по вводу не додумываем, берём наблюдаемую скорость вдоль ввода
        local K = math.min(SA.IntentLeads[Aim.KIndex], L)
        if input.Magnitude > 0.1 and Aim.SegStart and newest.t - Aim.SegStart > K + 0.35 then
            local posVel = windowVelocity(0.25)
            if posVel then
                local along = flat(posVel):Dot(input.Unit)
                if along < ws * 0.7 then ws = math.max(along, 0) end
            end
        end
        local jumpVelocity = 50
        pcall(function()
            jumpVelocity = hum.UseJumpPower and hum.JumpPower or math.sqrt(2 * Workspace.Gravity * hum.JumpHeight)
        end)
        local params = mapParams()
        local grounded = Aim.Grounded ~= false
        local standOffset = Aim.StandOffset or 3
        -- Сколько ещё лететь до пола (для разгона в воздухе); пола нет — весь горизонт
        local airTime = 0
        if not grounded then
            airTime = L
            local floor = floorY(newest.pos, params)
            if floor then
                local g = Workspace.Gravity
                local drop = math.max(newest.pos.Y - (floor + standOffset), 0)
                airTime = math.min((velocity.Y + math.sqrt(velocity.Y ^ 2 + 2 * g * drop)) / g, L)
            end
        end
        return {
            char = char, hrp = hrp, now = newest.t, pos = newest.pos,
            v0 = planar, vy = velocity.Y, input = input, ws = ws,
            L = L, K = K, airTime = airTime,
            grounded = grounded, jumpVelocity = jumpVelocity,
            standOffset = standOffset,
            params = params,
        }
    end

    -- Сценарии неизвестного хвоста с весами. Смена ввода — в начале хвоста или в
    -- его середине (поровну); вероятность смены — из средней длины отрезков цели.
    local function buildScenarios(ctx)
        local u = math.max(ctx.L - ctx.K, 0)
        local total, count = SA.PriorDuration * SA.PriorSegments, SA.PriorSegments
        for _, d in ipairs(Aim.Segments) do total += d; count += 1 end
        local changeChance = 1 - math.exp(-u / math.max(total / count, 0.15))
        local jumpChance = 0
        if ctx.grounded then
            local span = math.min(ctx.now - (Aim.TrackSince or ctx.now), 20)
            local recent = 0
            for _, t in ipairs(Aim.Jumps) do if ctx.now - t <= 20 then recent += 1 end end
            local rate = (recent + SA.JumpRatePrior * 2) / (span + 2)
            jumpChance = 1 - math.exp(-rate * u)
        end

        local list = {}
        local function add(name, weight, override, changeAt, jump)
            if weight <= 0 then return end
            local offset = collide(ctx, simulate(ctx, override, changeAt or 0))
            table.insert(list, {name = name, w = weight,
                disp = Vector3.new(offset.X, vertical(ctx, offset, jump), offset.Z)})
        end

        local keep = 1 - changeChance
        add("keep", keep * (1 - jumpChance))
        add("jump", keep * jumpChance, nil, nil, true)
        local moving = ctx.input.Magnitude > 0.1
        local dir = moving and ctx.input.Unit or flat(ctx.hrp.CFrame.LookVector)
        dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.xAxis
        local left = Vector3.new(-dir.Z, 0, dir.X)
        local changes
        if moving then
            changes = {
                {"stop", SA.ChangeSplit.Stop, Vector3.zero},
                {"reverse", SA.ChangeSplit.Reverse, -dir},
                {"left", SA.ChangeSplit.Left, left},
                {"right", SA.ChangeSplit.Right, -left},
            }
        else
            changes = {{"forward", 0.25, dir}, {"back", 0.25, -dir}, {"left", 0.25, left}, {"right", 0.25, -left}}
        end
        for _, change in ipairs(changes) do
            add(change[1], changeChance * change[2] * 0.5, change[3], 0)
            add(change[1] .. "_late", changeChance * change[2] * 0.5, change[3], u * 0.5)
        end
        return list
    end

    -- Самопроверка: цель предикта — ровно то, что мы увидим через L секунд (сервер
    -- видит убийцу на то же время позже, на какое мы его видим). Поэтому ошибку
    -- модели на ЭТОЙ цели можно мерить вживую: ставим предсказание «ввод не
    -- поменяется» и сверяем с видимой позицией в срок. Смены ввода и прыжки внутри
    -- окна — не ошибка модели, такие проверки выбрасываем. Если модель стабильно
    -- врёт (стена, лаги, спуфер без резолвера) — её поперечная часть размывает
    -- попадание в chanceFor, а при ошибке от BadError Health = 0 и Auto Fire молчит.
    local function changedBetween(list, from, to)
        for i = #list, 1, -1 do
            local t = list[i]
            if t < from then return false end
            if t <= to then return true end
        end
        return false
    end

    local function selfCheck(now)
        local current = Aim.Samples[#Aim.Samples]
        if not current then return end
        local SC = SA.SelfCheck
        -- сверка созревших предсказаний
        while Aim.Checks[1] and Aim.Checks[1].due <= now do
            local check = table.remove(Aim.Checks, 1)
            -- ввод до t0 предикт уже знал; ошибка «не модели» — смена после t0
            local inputChanged = changedBetween(Aim.SegTimes, check.t0, check.due - check.K)
            local jumped = changedBetween(Aim.Jumps, check.t0 - 0.05, check.due)
            if not inputChanged and not jumped and now - check.due < 0.1 then
                local miss = current.pos - check.pos
                table.insert(Aim.Errors, {now, miss.Magnitude, flat(miss).Magnitude, miss.Y})
                -- калибровка K: средний квадрат горизонтальной ошибки каждого кандидата
                for i, pos in ipairs(check.byK) do
                    local e = flat(current.pos - pos).Magnitude
                    Aim.KError[i] = Aim.KError[i] and (Aim.KError[i] * (1 - SC.KAlpha) + e * e * SC.KAlpha) or e * e
                end
                Aim.KSamples += 1
                if Aim.KSamples >= SC.KMinSamples then
                    local best = Aim.KIndex
                    for i, e in pairs(Aim.KError) do
                        if e < Aim.KError[best] then best = i end
                    end
                    -- гистерезис: переключаемся, только если новый K заметно лучше
                    if Aim.KError[best] < Aim.KError[Aim.KIndex] * 0.85 then Aim.KIndex = best end
                end
            end
        end
        while Aim.Errors[1] and now - Aim.Errors[1][1] > SC.Window do table.remove(Aim.Errors, 1) end
        if #Aim.Errors >= SC.MinSamples then
            local sorted = {}
            for i, e in ipairs(Aim.Errors) do sorted[i] = e[2] end
            table.sort(sorted)
            local rank = math.max(1, math.ceil(#sorted * SC.Percentile))
            local err = sorted[rank]
            local horizontal = {}
            for i, e in ipairs(Aim.Errors) do horizontal[i] = e[3] end
            table.sort(horizontal)
            Aim.Health = err >= SC.BadError and 0 or 1
            Aim.ModelError, Aim.LateralError = err, horizontal[rank]
        else
            Aim.Health, Aim.ModelError, Aim.LateralError = 1, nil, nil
        end
        -- новое предсказание — сразу для всех кандидатов K
        if now < Aim.NextCheck then return end
        Aim.NextCheck = now + SC.Interval
        local ctx = makeContext()
        if not ctx then return end
        local check = {due = now + ctx.L, t0 = now, K = ctx.K, byK = {}}
        for i, K in ipairs(SA.IntentLeads) do
            ctx.K = math.min(K, ctx.L)
            local offset = collide(ctx, simulate(ctx))
            local pos = ctx.pos + Vector3.new(offset.X, vertical(ctx, offset, false), offset.Z)
            check.byK[i] = pos
            if i == Aim.KIndex then check.pos = pos end
        end
        table.insert(Aim.Checks, check)
    end

    -- Хитбоксы цели: видимые части и аксессуары (сервер засчитывает и их), без HRP
    -- (Extended Hitbox раздувает его только у нас) и без инструментов
    local function hitboxes(char)
        local boxes = {}
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.CanQuery
                and not part:FindFirstAncestorOfClass("Tool") then
                local half = part.Size / 2 - Vector3.one * SA.PartMargin
                table.insert(boxes, {cf = part.CFrame,
                    half = Vector3.new(math.max(half.X, 0.05), math.max(half.Y, 0.05), math.max(half.Z, 0.05))})
            end
        end
        return boxes
    end

    -- Луч (origin, единичное dir, длина maxT) против OBB (slab-метод)
    local function rayHitsBox(origin, dir, maxT, cf, half)
        local lo, ld = cf:PointToObjectSpace(origin), cf:VectorToObjectSpace(dir)
        local tmin, tmax = 0, maxT
        for _, axis in ipairs({"X", "Y", "Z"}) do
            local p, d, e = lo[axis], ld[axis], half[axis]
            if math.abs(d) < 1e-8 then
                if math.abs(p) > e then return false end
            else
                local t1, t2 = (-e - p) / d, (e - p) / d
                if t1 > t2 then t1, t2 = t2, t1 end
                tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
                if tmin > tmax then return false end
            end
        end
        return true
    end

    -- blur — σ поперечной ошибки модели (studs): каждый сценарий сдвигаем поперёк
    -- луча по горизонтали на ±σ, ±2σ. Сдвиг вдоль луча на попадание не влияет
    local function chanceFor(origin, aim, boxes, scenarios, blur)
        local delta = aim - origin
        local distance = delta.Magnitude
        if distance < 1e-3 then return 0 end
        local dir = delta / distance
        local maxT = distance + 12
        local SC = SA.SelfCheck
        local side = Vector3.new(-dir.Z, 0, dir.X)
        local offsets, weights = {0}, {1}
        if blur and blur > 0.05 and side.Magnitude > 1e-3 then
            side = side.Unit
            offsets, weights = SC.BlurOffsets, SC.BlurWeights
        end
        local chance = 0
        for _, s in ipairs(scenarios) do
            for k, offset in ipairs(offsets) do
                local shift = s.disp + (offset ~= 0 and side * (offset * blur) or Vector3.zero)
                for _, box in ipairs(boxes) do
                    if rayHitsBox(origin, dir, maxT, box.cf + shift, box.half) then
                        chance += s.w * weights[k]
                        break
                    end
                end
            end
        end
        return chance
    end

    -- Лучшая точка прицела для заданной точки вылета: {aim, chance, scenarios, ctx}
    Aim.Solve = function(origin)
        local ctx = makeContext()
        if not ctx then return nil end
        local scenarios = buildScenarios(ctx)
        local boxes = hitboxes(ctx.char)
        local torso = pickAimPart(ctx.char)
        local head = ctx.char:FindFirstChild("Head")
        local torsoPos = torso and torso.Position or ctx.hrp.Position
        local keep, stop = scenarios[1], nil
        for _, s in ipairs(scenarios) do if s.name == "stop" or s.name == "forward" then stop = s break end end
        local candidates = {torsoPos + keep.disp}
        if head then table.insert(candidates, head.Position + keep.disp) end
        if stop then
            table.insert(candidates, torsoPos + stop.disp)
            for _, f in ipairs({1 / 3, 2 / 3}) do
                table.insert(candidates, torsoPos + keep.disp:Lerp(stop.disp, f))
            end
            if head then table.insert(candidates, head.Position + keep.disp:Lerp(stop.disp, 0.5)) end
        end
        -- Сначала геометрия без разброса, затем разброс по ошибке модели для двух
        -- лучших точек (дорого считать для всех): выбираем устойчивую к ошибке
        local ranked = {}
        for _, aim in ipairs(candidates) do
            table.insert(ranked, {aim = aim, geo = chanceFor(origin, aim, boxes, scenarios)})
        end
        table.sort(ranked, function(a, b) return a.geo > b.geo end)
        local SC = SA.SelfCheck
        local lateral = Aim.LateralError
        local blur = lateral and lateral > SC.GoodError and lateral / 1.8 or nil
        local best = ranked[1]
        best.chance = best.geo
        if blur then
            best.chance = chanceFor(origin, best.aim, boxes, scenarios, blur)
            local second = ranked[2]
            if second and second.geo > best.chance then
                second.chance = chanceFor(origin, second.aim, boxes, scenarios, blur)
                if second.chance > best.chance + 1e-6 then best = second end
            end
        end
        return {aim = best.aim, chance = best.chance * Aim.Health, ctx = ctx, spoof = Aim.Spoof,
            geometric = best.geo, health = Aim.Health, blur = blur}
    end

    -- Можно ли стрелять по этой линии: карта не закрывает цель, и ни один другой
    -- игрок не стоит у луча (сервер убьёт первого задетого — невиновного)
    Aim.LineClear = function(origin, aim, ctx, allowWalls)
        local delta = aim - origin
        local distance = delta.Magnitude
        if distance < 1e-3 then return false end
        local dir = delta / distance
        local wall = Workspace:Raycast(origin, dir * 1000, ctx.params)
        local reach = wall and wall.Distance or 1000
        if not allowWalls and reach < distance - 1.5 then return false, "wall" end
        local L = ctx.L
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player ~= Aim.Target and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local p = root.Position + root.AssemblyLinearVelocity * L
                    local along = math.clamp((p - origin):Dot(dir), 0, reach)
                    if (origin + dir * along - p).Magnitude < SA.InnocentRadius then return false, "innocent" end
                end
            end
        end
        return true
    end

    -- Точка вылета как у игры: HRP.GunRaycastAttachment (иначе ручка пистолета).
    -- Если между головой и ней стена — стреляем от головы (игра такой выстрел запрещает)
    Aim.SilentOrigin = function(character, gun)
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local attachment = hrp and hrp:FindFirstChild("GunRaycastAttachment")
        local origin = attachment and attachment.WorldPosition
        if not origin then
            local handle = gun and (gun:FindFirstChild("Handle") or gun:FindFirstChild("GunBarrel"))
            origin = handle and handle.Position or (hrp and hrp.Position)
        end
        local head = character and character:FindFirstChild("Head")
        if origin and head then
            local params = mapParams()
            if Workspace:Raycast(head.Position, origin - head.Position, params) then origin = head.Position end
        end
        return origin
    end

    Aim.FindRemote = function(gun)
        local remote = gun:FindFirstChild("Shoot")
            or (gun:FindFirstChild("Events") and gun.Events:FindFirstChild("Shoot"))
            or (gun:FindFirstChild("KnifeServer") and gun.KnifeServer:FindFirstChild("ShootGun"))
        if remote and remote:IsA("RemoteEvent") then return remote end
        for _, child in ipairs(gun:GetDescendants()) do
            if child:IsA("RemoteEvent") and (child.Name:lower():find("shoot") or child.Name:lower():find("fire")) then
                return child
            end
        end
        return nil
    end

    -- Учёт серверного кулдауна: выстрел считаем принятым по трассеру от нашей точки
    Aim.RegisterShot = function(origin, info)
        local now = os.clock()
        local ping = pingSeconds()
        Aim.Pending = {origin = origin, sent = now, expire = now + ping + SA.ConfirmExtra, info = info}
        Aim.NextShot = now + ping * 0.5 + SA.ServerCooldown + SA.CooldownMargin
    end

    local function onTracer(child)
        local pending = Aim.Pending
        if not pending or not child:IsA("BasePart") then return end
        task.defer(function()
            if Aim.Pending ~= pending or not child.Parent then return end
            if child:FindFirstChildOfClass("Beam") and (child.Position - pending.origin).Magnitude < 0.05 then
                pending.confirmed = os.clock()
                -- сервер принял выстрел ~полпинга назад — от этого и считаем кулдаун
                Aim.NextShot = os.clock() - pingSeconds() * 0.5 + SA.ServerCooldown + SA.CooldownMargin
            end
        end)
    end

    -- Разбор автовыстрела: через L после отправки мы видим убийцу там, где его видел
    -- сервер при обработке выстрела. Сверяем тот же луч с его настоящими хитбоксами,
    -- картой и другими игроками — отсюда причина, если выстрел не убил
    local function observeShot(info)
        local obs = {}
        info.obs = obs
        local char = info.target and info.target.Character
        local delta = info.aim - info.origin
        local distance = delta.Magnitude
        if not char or distance < 1e-3 then return end
        local dir = delta / distance
        for _, box in ipairs(hitboxes(char)) do
            if rayHitsBox(info.origin, dir, distance + 12, box.cf, box.half) then obs.onTarget = true break end
        end
        local torso = pickAimPart(char) or char:FindFirstChild("HumanoidRootPart")
        if torso then
            local rel = torso.Position - info.origin
            obs.missBy = (rel - dir * rel:Dot(dir)).Magnitude
        end
        local wall = Workspace:Raycast(info.origin, dir * math.max(distance - 1.5, 0.1), mapParams())
        obs.wall = wall ~= nil
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player ~= info.target and player.Character then
                for _, box in ipairs(hitboxes(player.Character)) do
                    if rayHitsBox(info.origin, dir, distance, box.cf, box.half) then obs.blocker = player.Name break end
                end
                if obs.blocker then break end
            end
        end
    end

    local function missReason(info, pending)
        if not pending.confirmed then return "server rejected the shot (lag or cooldown)" end
        local obs = info.obs
        if not obs then return "murderer left before the check" end
        if obs.blocker then return "bullet hit " .. obs.blocker .. " first" end
        if obs.wall then return "wall moved into the line" end
        if obs.onTarget then return "line was on target, server didn't count it (lag)" end
        local off = obs.missBy and string.format(" (off by %.1f studs)", obs.missBy) or ""
        if changedBetween(Aim.SegTimes, info.t, info.due) then return "murderer changed direction" .. off end
        if changedBetween(Aim.Jumps, info.t - 0.05, info.due) then return "murderer jumped" .. off end
        if info.spoof then return "resolved position was wrong" .. off end
        if Aim.Spoof then return "velocity spoof detected too late" .. off end
        if not State.Settings.ResolverEnabled then return "prediction missed, spoofer? try Resolver" .. off end
        return "prediction missed" .. off
    end

    -- Итог автовыстрела: смерть цели вскоре после принятия выстрела; иначе — промах
    -- с причиной (единственное уведомление Auto Fire)
    local function settlePending(now)
        local pending = Aim.Pending
        if not pending then return end
        local info = pending.info
        if info and info.due and not info.obs and now >= info.due then pcall(observeShot, info) end
        if info and info.target then
            local char = info.target.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local dead = not char or not char.Parent or not hum or hum.Health <= 0 or getMurder() ~= info.target
            if dead and pending.confirmed then
                info.hit = true
            end
        end
        if now > pending.expire + (pending.confirmed and 0.4 or 0) then
            if not pending.confirmed then
                -- трассера нет: сервер выстрел отбросил, кулдаун не начинался
                Aim.NextShot = now
                State.Settings.CanShootMurderer = true
                if info then info.rejected = true end
            end
            if info and not info.hit then
                info.missReason = missReason(info, pending)
                ShowNotification("<font color=\"rgb(255, 85, 85)\">Auto Fire missed </font><font color=\"rgb(220,220,220)\">"
                    .. info.missReason .. "</font>", CONFIG.Colors.Text)
            end
            Aim.Pending = nil
        end
    end

    -- Диагностика Auto Fire: почему очередная оценка не выстрелила. Счётчики —
    -- за текущую цель (раунд); прошлый раунд остаётся в LastReport. Читать через
    -- getgenv().MM2_Runtime.SheriffAim.Report()
    local Diag = {Counts = {}, Evals = 0, Shots = 0}
    Aim.Diag = Diag

    local function diagReport(d)
        local parts = {}
        for reason, count in pairs(d.Counts) do table.insert(parts, {reason, count}) end
        table.sort(parts, function(a, b) return a[2] > b[2] end)
        local lines = {string.format("evals=%d shots=%d last: chance=%.0f%% geo=%.0f%% health=%.2f modelErr=%s blur=%s ping=%dms K=%.2f spoof=%s",
            d.Evals, d.Shots, (d.Chance or 0) * 100, (d.Geo or 0) * 100, d.Health or 1,
            d.ModelError and string.format("%.2f", d.ModelError) or "-", d.Blur and string.format("%.2f", d.Blur) or "-",
            math.floor((d.Ping or 0) * 1000 + 0.5),
            d.K or 0, tostring(d.Spoof))}
        for _, entry in ipairs(parts) do
            table.insert(lines, string.format("  %-12s %5d  %.0f%%", entry[1], entry[2], entry[2] / math.max(d.Evals, 1) * 100))
        end
        return table.concat(lines, "\n")
    end
    -- Итоги автовыстрелов по Log: принятые сервером и попадания, по режиму и резолву
    local function shotSummary()
        local groups, order = {}, {}
        for _, info in ipairs(Aim.Log) do
            if not info.rejected then
                local key = info.spoof and "resolved" or "plain"
                local g = groups[key]
                if not g then g = {shots = 0, hits = 0, chance = 0}; groups[key] = g; table.insert(order, key) end
                g.shots += 1
                g.chance += info.chance or 0
                if info.hit then g.hits += 1 end
            end
        end
        local parts = {}
        for _, key in ipairs(order) do
            local g = groups[key]
            table.insert(parts, string.format("%s %d/%d (avg chance %.0f%%)", key, g.hits, g.shots, g.chance / g.shots * 100))
        end
        local misses, missOrder = {}, {}
        for _, info in ipairs(Aim.Log) do
            local reason = info.missReason and info.missReason:gsub(" %(off by.*%)", "")
            if reason then
                if not misses[reason] then misses[reason] = 0; table.insert(missOrder, reason) end
                misses[reason] += 1
            end
        end
        for i, reason in ipairs(missOrder) do missOrder[i] = reason .. " x" .. misses[reason] end
        return (#parts > 0 and ("[Auto Fire] hits/shots: " .. table.concat(parts, ", ") .. "\n") or "")
            .. (#missOrder > 0 and ("[Auto Fire] misses: " .. table.concat(missOrder, "; ") .. "\n") or "")
    end
    Aim.Report = function()
        return shotSummary() .. "[Auto Fire] current:\n" .. diagReport(Diag) .. (Aim.LastReport and ("\n[Auto Fire] previous:\n" .. Aim.LastReport) or "")
    end
    Aim.ResetDiag = function()
        if Diag.Evals > 0 then Aim.LastReport = diagReport(Diag) end
        table.clear(Diag.Counts)
        Diag.Evals, Diag.Shots = 0, 0
        Diag.Chance, Diag.Geo = nil, nil
    end

    local function block(now, reason, solution)
        Diag.Counts[reason] = (Diag.Counts[reason] or 0) + 1
        Diag.Last = reason
        if solution then
            Diag.Chance, Diag.Geo, Diag.Health = solution.chance, solution.geometric, solution.health
            Diag.Spoof, Diag.K = solution.spoof, solution.ctx and solution.ctx.K
            Diag.Ping, Diag.ModelError = solution.ctx and solution.ctx.L - SA.ServerLead, Aim.ModelError
            Diag.Blur = solution.blur
        end
    end

    -- Auto Fire: оценка ~30 раз в секунду, выстрел при чистой линии до точки
    -- упреждения и готовом (по серверу) кулдауне
    local function autoFire(now)
        if not State.Settings.AutoFireEnabled or now < Aim.NextAuto then return end
        Aim.NextAuto = now + SA.AutoInterval
        Diag.Evals += 1
        if Aim.Pending then return block(now, "pending") end
        if now < Aim.NextShot or not State.Settings.CanShootMurderer then return block(now, "cooldown") end
        if not Aim.Target then return block(now, "no_target") end
        if not Aim.TrackSince or now - Aim.TrackSince < SA.MinTrackTime then return block(now, "tracking") end
        local character = LocalPlayer.Character
        local myHum = character and character:FindFirstChildOfClass("Humanoid")
        if not myHum or myHum.Health <= 0 then return block(now, "dead") end
        local gun = character:FindFirstChild("Gun")
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local stored = not gun and backpack and backpack:FindFirstChild("Gun")
        if not gun and not stored then return block(now, "no_gun") end

        local origin = Aim.SilentOrigin(character, gun or stored)
        if not origin then return block(now, "no_origin") end
        -- Как Only Visible во вкладке Aim, но луч от точки вылета пули до точки
        -- упреждения: разброса в MM2 нет, сервер бьёт ровно этим лучом, так что чистый
        -- луч = попадание, если предикт верен. Порог по шансу мешал больше, чем помогал
        -- (молчал целые раунды при чистой линии) — шанс остаётся только в логе
        local solution = Aim.Solve(origin)
        if not solution then return block(now, "no_solution") end
        local clear, why = Aim.LineClear(origin, solution.aim, solution.ctx)
        if not clear then return block(now, why or "wall", solution) end

        if stored then
            -- Экипировка реплицируется раньше ремоута (один упорядоченный поток),
            -- поэтому стреляем в том же кадре — задержка испортила бы упреждение
            myHum:EquipTool(stored)
            gun = character:FindFirstChild("Gun")
            if not gun then return block(now, "equip") end
            origin = Aim.SilentOrigin(character, gun)
            solution = Aim.Solve(origin)
            if not solution then return block(now, "no_solution") end
        end
        Diag.Counts.fired = (Diag.Counts.fired or 0) + 1
        Diag.Chance, Diag.Geo, Diag.Health = solution.chance, solution.geometric, solution.health
        Diag.ModelError, Diag.Blur = Aim.ModelError, solution.blur
        Diag.Shots += 1
        State.Runtime.FireSheriffShot(gun, origin, solution, true)
    end

    Core.Connect(Workspace.ChildAdded, onTracer)
    Core.Connect(RunService.Heartbeat, function()
        local now = os.clock()
        local character = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local armed = (character and character:FindFirstChild("Gun")) or (backpack and backpack:FindFirstChild("Gun"))
        if not armed and not State.Settings.AutoFireEnabled then
            if Aim.Target then resetTrack(nil) end
            return
        end
        local ok, err = pcall(track, now)
        if not ok then warn("[Sheriff Aim] " .. tostring(err)) return end
        ok, err = pcall(selfCheck, now)
        if not ok then warn("[Sheriff Aim] " .. tostring(err)) end
        settlePending(now)
        if armed then
            ok, err = pcall(autoFire, now)
            if not ok then warn("[Auto Fire] " .. tostring(err)) end
        end
    end)

    Aim.SetAutoFire = function(enabled)
        State.Settings.AutoFireEnabled = enabled == true
        Aim.NextAuto = 0
    end
    Aim.SetResolver = function(enabled)
        State.Settings.ResolverEnabled = enabled == true
        Aim.Spoof, Aim.SuspectSince, Aim.CleanSince = false, nil, nil
        table.clear(Aim.Suspects)
    end
end

-- Общая отправка выстрела шерифа: ремоут, кулдаун, трассер, уведомление.
-- solution — из SheriffAim.Solve; auto — вызов Auto Fire (свои уведомления)
State.Runtime.FireSheriffShot = function(gun, origin, solution, auto, modeText, quiet)
    local Aim = State.Runtime.SheriffAim
    local remote = Aim.FindRemote(gun)
    if not remote then return false, "Remote not found" end
    local aim = solution.aim
    State.Settings.CanShootMurderer = false
    -- due — когда видимая позиция убийцы совпадёт с той, что видел сервер при выстреле
    local now = os.clock()
    local info = auto and {t = now, chance = solution.chance, spoof = solution.spoof, target = Aim.Target,
        origin = origin, aim = aim, due = now + (solution.ctx and solution.ctx.L or Aim.Ping() + CONFIG.SheriffAim.ServerLead)} or nil
    local ok, err = pcall(function()
        remote:FireServer(CFrame.lookAt(origin, aim), CFrame.new(aim))
    end)
    if not ok then
        State.Settings.CanShootMurderer = true
        return false, err
    end
    Aim.RegisterShot(origin, info)
    if info then
        table.insert(Aim.Log, info)
        if #Aim.Log > 60 then table.remove(Aim.Log, 1) end
    end
    if State.Settings.BulletTracersEnabled then
        pcall(function()
            for _ = 1, 4 do CreateTracer(origin, aim, 2) end
        end)
    end
    -- Auto Fire молчит при выстреле и попадании — уведомляет только о промахе (settlePending)
    if not quiet and not auto then
        local label = modeText or "Silent"
        if solution.spoof then label ..= ", resolved" end
        ShowNotification("<font color=\"rgb(168,228,160)\">Shot fired! </font><font color=\"rgb(220,220,220)\">[" .. label .. "] Cooldown: " .. State.Settings.ShootCooldown .. "s</font>", CONFIG.Colors.Text)
    end
    Core.Tasks.delay(State.Settings.ShootCooldown, function()
        State.Settings.CanShootMurderer = true
        if not quiet and not auto then
            ShowNotification("<font color=\"rgb(85, 255, 255)\">Ready </font><font color=\"rgb(220,220,220)\">You can shoot again</font>", CONFIG.Colors.Text)
        end
    end)
    return true
end

shootMurderer = function(forceMagic, mode)
    -- Режим задаёт бинд: Shoot Murderer — Silent, Wallbang — Magic.
    -- forceMagic == true — тихий вызов из автофарма, всегда Magic
    local useMode = forceMagic and "Magic" or (mode or "Silent")

    -- Проверка кулдауна: свой флаг и серверный (по трассеру принятого выстрела) —
    -- выстрел в ещё идущий серверный кулдаун сервер молча выбросит
    if not State.Settings.CanShootMurderer or os.clock() < State.Runtime.SheriffAim.NextShot then
        if not forceMagic then
            ShowNotification("<font color=\"rgb(255, 165, 0)\">Wait </font><font color=\"rgb(220,220,220)\">Gun is on cooldown</font>", CONFIG.Colors.Text)
        end
        return
    end

    -- Персонаж может быть nil (респавн/смерть) — без него стрелять нечем
    local shooterChar = LocalPlayer.Character
    if not shooterChar then return end
    local shooterBackpack = LocalPlayer:FindFirstChild("Backpack")

    -- МГНОВЕННАЯ ЭКИПИРОВКА ПИСТОЛЕТА (С фиксом репликации)
    local gun = shooterChar:FindFirstChild("Gun")

    if not gun then
        local backpackGun = shooterBackpack and shooterBackpack:FindFirstChild("Gun")
        if backpackGun then
            local hum = shooterChar:FindFirstChild("Humanoid")
            if hum then
                hum:EquipTool(backpackGun)
                -- ВАЖНО: Микро-задержка, чтобы сервер успел понять, что оружие в руках
                task.wait(0.03)
                gun = shooterChar:FindFirstChild("Gun")
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
    local murdererHum = murderer.Character:FindFirstChildOfClass("Humanoid")

    if not murdererHRP then
        if not forceMagic then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">Murderer has no HRP</font>", nil)
        end
        return
    end

    local Aim = State.Runtime.SheriffAim
    local solution, origin

    if useMode == "Magic" then
        -- === MAGIC MODE: пуля вылетает рядом с убийцей ===
        -- Сначала точка прицела от нашей позиции, затем вылет с чистым путём до неё.
        -- Первым пробуем вылет по оси движения: вдоль неё ошибка скорости/тайминга
        -- не уводит луч с тела, остаётся только поворот
        local probeOrigin = Aim.SilentOrigin(shooterChar, gun) or murdererHRP.Position + Vector3.new(0, 20, 0)
        local first = Aim.Solve(probeOrigin)
        local predictedPos = first and first.aim or computeAimPoint(murderer.Character, murdererHRP, murdererHum,
            Aim.Ping() + CONFIG.SheriffAim.ServerLead)
        local enemyVelocity = first and first.ctx.v0 or Vector3.new(murdererHRP.AssemblyLinearVelocity.X, 0, murdererHRP.AssemblyLinearVelocity.Z)
        local preferred = {}
        if enemyVelocity.Magnitude > 2 then
            table.insert(preferred, enemyVelocity)
            table.insert(preferred, -enemyVelocity)
        end
        table.insert(preferred, -murdererHRP.CFrame.LookVector)
        local myRoot = shooterChar:FindFirstChild("HumanoidRootPart")
        if myRoot then table.insert(preferred, myRoot.Position - predictedPos) end
        origin = State.Runtime.FindClearOrigin(predictedPos, murderer.Character, preferred, 4)
        solution = Aim.Solve(origin) or {aim = predictedPos, chance = 0}
    else
        -- === SILENT MODE: из точки вылета игры (GunRaycastAttachment) ===
        -- Стена между нами и целью ловит пулю — это честный сайлент, вся ставка
        -- на предикт. Без истории наблюдений — старый предикт по пингу
        origin = Aim.SilentOrigin(shooterChar, gun)
        if not origin then
            if not forceMagic then
                ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">No shot origin</font>", nil)
            end
            return
        end
        solution = Aim.Solve(origin) or {aim = computeAimPoint(murderer.Character, murdererHRP, murdererHum,
            Aim.Ping() + CONFIG.SheriffAim.ServerLead), chance = 0}
    end

    local modeText = useMode == "Magic" and "Magic" or "Silent"
    local success, err = State.Runtime.FireSheriffShot(gun, origin, solution, false, modeText, forceMagic)
    if not success and not forceMagic then
        ShowNotification("<font color=\"rgb(255, 85, 85)\">Error </font><font color=\"rgb(220, 220, 220)\">" .. tostring(err) .. "</font>", nil)
    end
end

-- pickupGun() - Подбор пистолета (ручной бинд/кнопка)
-- Ган берём из общего трекинга, при промахе добираем прямым резолвером —
-- так бинд остаётся ровно настолько же надёжным, каким был
local function pickupGun(silent)
    local gun = State.Runtime.CurrentGunDrop
    if not gun or not gun.Parent then
        gun = State.Runtime.ResolveGunDrop()
    end

    if not gun then
        if not silent and State.Settings.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">No gun on map</font>", CONFIG.Colors.Text)
        end
        return false
    end

    local character = LocalPlayer.Character
    if not character then return false end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    if not gun.Parent then return false end

    -- Фиче-детект: без firetouchinterest подбор невозможен, но падать нельзя
    if not firetouchinterest then
        if not silent and State.Settings.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">firetouchinterest not supported</font>", CONFIG.Colors.Text)
        end
        return false
    end

    -- Касание засчитывается только через TouchInterest, а он приходит на кадр
    -- позже самого GunDrop (см. CONFIG.GunPickup) — ждём его покадрово
    local deadline = os.clock() + CONFIG.GunPickup.TouchWait
    while gun.Parent and not gun:FindFirstChildOfClass("TouchTransmitter") and os.clock() < deadline do
        task.wait()
    end
    if not gun.Parent then return false end

    -- Сервер реагирует на начало касания: 0 и 1 шлём сразу, без паузы между ними
    pcall(function()
        firetouchinterest(hrp, gun, 0)
        firetouchinterest(hrp, gun, 1)
    end)

    if not silent and State.Settings.NotificationsEnabled then
        ShowNotification("<font color=\"rgb(220, 220, 220)\">Gun: Picked up</font>", CONFIG.Colors.Text)
    end

    return true
end

-- ── Instant Pickup: событийный, без опроса ───────────────────────────────────
-- Прежняя версия крутила поток с task.wait(0.05), а при неудачной попытке
-- уходила в `repeat ... until false`, выход из которого был только по СМЕНЕ
-- State.CurrentGunDrop. Но CurrentGunDrop при исчезновении гана никогда не
-- обнулялся — поле держало уничтоженный инстанс, и поток вставал до конца
-- раунда. Теперь функция дёргается событием появления гана, отрабатывает и
-- выходит; повторный вход защищён GunPickupBusy.
-- Поле State (не local): лимит Luau «200 local registers» в главном чанке.
-- Заодно снимает нужду в отдельном хуке — ApplyGunDropState зовёт State.TryInstantPickup
State.Runtime.TryInstantPickup = function(gun)
    if not State.Settings.InstantPickupEnabled then return end

    -- Вложена сюда намеренно: снаружи не нужна, а лишний top-level local
    -- переполняет регистры чанка
    local function hasGunInInventory()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Gun") then return true end
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack and backpack:FindFirstChild("Gun") then return true end
        return false
    end

    gun = gun or State.Runtime.CurrentGunDrop
    if not gun or not gun.Parent then return end

    if State.Runtime.GunPickupBusy then return end
    if State.Runtime.GunPickupTried == gun then return end

    -- Условия раунда — те же, что были в прежней реализации
    local murderer = getMurder()
    if not murderer or murderer == LocalPlayer then return end
    if getSheriff() == LocalPlayer then return end
    if hasGunInInventory() then return end

    State.Runtime.GunPickupBusy = true
    State.Runtime.GunPickupTried = gun

    -- Первое касание — сразу после появления TouchInterest (ждёт pickupGun), дальше
    -- частые повторы на случай потерянного пакета: раньше шаг был 0.25 с, и промах
    -- первой попытки стоил четверть секунды гонки с живыми игроками
    local cfg = CONFIG.GunPickup
    local success = false
    local deadline = os.clock() + cfg.TouchWait + cfg.Timeout
    while os.clock() < deadline do
        if not State.Settings.InstantPickupEnabled then break end
        if not gun.Parent or State.Runtime.CurrentGunDrop ~= gun then break end

        pickupGun(true)
        task.wait(cfg.RetryInterval)

        if hasGunInInventory() then
            success = true
            break
        end
    end

    State.Runtime.GunPickupBusy = false

    if success and State.Settings.NotificationsEnabled then
        Core.Tasks.spawn(function()
            ShowNotification(
                "<font color=\"rgb(168,228,160)\">Gun: Instant Pickup ✓</font>",
                CONFIG.Colors.Text
            )
        end)
    end

    Core.Tasks.spawn(function()
        pcall(updateRoleAvatars)
    end)
end

local function EnableInstantPickup()
    State.Settings.InstantPickupEnabled = true
    State.Runtime.GunPickupTried = nil

    -- Трекинг мог быть ещё не поднят: автозагрузка конфига дёргает тогл раньше,
    -- чем отрабатывает блок запуска в конце файла
    if #State.Runtime.GunTrackConns == 0 then
        pcall(SetupGunTracking)
    end

    -- Ган мог уже лежать на карте — не ждём следующего события
    Core.Tasks.spawn(function()
        pcall(State.Runtime.TryInstantPickup, State.Runtime.CurrentGunDrop or State.Runtime.ResolveGunDrop())
    end)
end

local function DisableInstantPickup()
    State.Settings.InstantPickupEnabled = false
    State.Runtime.GunPickupTried = nil
    State.Runtime.GunPickupBusy = false

    -- Поток от прежней реализации: гасим, если он ещё жив
    if State.Runtime.InstantPickupThread then
        pcall(task.cancel, State.Runtime.InstantPickupThread)
        State.Runtime.InstantPickupThread = nil
    end
end

-- EnableExtendedHitbox() - Включение расширенного хитбокса
local OriginalSizes = {}
local HitboxConnection = nil

local function EnableExtendedHitbox()
    if State.Settings.ExtendedHitboxEnabled then return end
    State.Settings.ExtendedHitboxEnabled = true

    -- RenderStepped вместо Heartbeat - меньше лагов
    HitboxConnection = Core.Connect(RunService.RenderStepped, function()
        local size = Vector3.new(
            State.Settings.ExtendedHitboxSize,
            State.Settings.ExtendedHitboxSize,
            State.Settings.ExtendedHitboxSize
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
                        hrp.CanCollide = true  -- Оставляем true для коллизий
                    end
                end
            end
        end
    end)
end

-- DisableExtendedHitbox() - Отключение хитбокса
local function DisableExtendedHitbox()
    if not State.Settings.ExtendedHitboxEnabled then return end
    State.Settings.ExtendedHitboxEnabled = false

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
    State.Settings.ExtendedHitboxSize = newSize
end

-- Kill Aura Zone Visualization
local zoneSegments = 48
local zoneAttachments = {}
local zoneBeams = {}
local zoneRayParams = nil
local zoneRenderConn = nil
local ApplyKillAuraZoneStyle

local function CreateKillAuraZone()
    if #zoneAttachments > 0 then return end

    zoneRayParams = RaycastParams.new()
    zoneRayParams.FilterType = Enum.RaycastFilterType.Exclude
    zoneRayParams.IgnoreWater = true

    for i = 1, zoneSegments do
        local att = Core.New("Attachment")
        att.Name = "KillAuraZone_" .. i
        att.Parent = Workspace.Terrain
        zoneAttachments[i] = att
    end

    for i = 1, zoneSegments do
        local nextI = (i % zoneSegments) + 1
        local beam = Core.New("Beam")
        beam.Attachment0 = zoneAttachments[i]
        beam.Attachment1 = zoneAttachments[nextI]
        beam.Color = ColorSequence.new(CONFIG.Colors.Accent)
        beam.FaceCamera = true
        beam.LightEmission = 1
        beam.LightInfluence = 0
        beam.Brightness = 5
        beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
        beam.TextureMode = Enum.TextureMode.Stretch
        beam.TextureSpeed = 2
        beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 0.5)
        })
        beam.Width0 = 0.3
        beam.Width1 = 0.3
        beam.ZOffset = 0.1
        beam.Parent = zoneAttachments[i]
        zoneBeams[i] = beam
    end

    ApplyKillAuraZoneStyle()
end

local function UpdateKillAuraZone()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or #zoneAttachments == 0 then return end

    local origin = hrp.Position
    local radius = State.Settings.KillAuraRange or 7
    zoneRayParams.FilterDescendantsInstances = {char}

    for i = 1, zoneSegments do
        local angle = (i - 1) * (math.pi * 2) / zoneSegments
        local dir = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
        local endPos
        if State.Settings.KillAuraStatic then
            endPos = origin + dir
        else
            local result = Workspace:Raycast(origin, dir, zoneRayParams)
            endPos = (result and result.Position) or (origin + dir)
        end
        zoneAttachments[i].WorldPosition = endPos
    end
end

local function DestroyKillAuraZone()
    if zoneRenderConn then
        zoneRenderConn:Disconnect()
        zoneRenderConn = nil
    end
    for _, beam in ipairs(zoneBeams) do
        pcall(function() beam:Destroy() end)
    end
    for _, att in ipairs(zoneAttachments) do
        pcall(function() att:Destroy() end)
    end
    zoneAttachments = {}
    zoneBeams = {}
end

ApplyKillAuraZoneStyle = function()
    local speed = State.Settings.KillAuraStatic and 0 or 2
    for _, beam in ipairs(zoneBeams) do
        pcall(function() beam.TextureSpeed = speed end)
    end
end

-- Найти RemoteEvent HandleTouched внутри Knife (в Character или Backpack).
-- Tool.Events.HandleTouched доступен и из Backpack — equip не требуется.
local function GetKnifeHandleTouched()
    local char = LocalPlayer.Character
    local knife = char and char:FindFirstChild("Knife")
    if not knife then
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then knife = bp:FindFirstChild("Knife") end
    end
    if not knife then return nil end
    local events = knife:FindFirstChild("Events")
    if not events then return nil end
    return events:FindFirstChild("HandleTouched")
end

-- ToggleKillAura() - Kill Aura через HandleTouched:FireServer
local killAuraThread = nil

local function ToggleKillAura(state)
    if state then
        if State.Settings.KillAuraEnabled then return end
        State.Settings.KillAuraEnabled = true

        CreateKillAuraZone()
        if zoneRenderConn then zoneRenderConn:Disconnect() end
        zoneRenderConn = Core.Connect(RunService.RenderStepped, UpdateKillAuraZone)

        killAuraThread = Core.Tasks.spawn(function()
            while State.Settings.KillAuraEnabled do
                task.wait(0.1)
                if not State.Settings.KillAuraEnabled then break end

                if getMurder() ~= LocalPlayer then
                    ToggleKillAura(false)
                    return
                end

                local char = LocalPlayer.Character
                local localHRP = char and char:FindFirstChild("HumanoidRootPart")
                if not localHRP then continue end

                local handleTouched = GetKnifeHandleTouched()
                if not handleTouched then continue end

                local range = State.Settings.KillAuraRange or 7

                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local targetChar = player.Character
                        local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
                        local targetPart = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
                        if targetHRP and targetPart then
                            local distance = (targetHRP.Position - localHRP.Position).Magnitude
                            if distance <= range then
                                pcall(function() handleTouched:FireServer(targetPart) end)
                            end
                        end
                    end
                end
            end
            killAuraThread = nil
        end)
    else
        State.Settings.KillAuraEnabled = false
        if killAuraThread then
            pcall(task.cancel, killAuraThread)
            killAuraThread = nil
        end
        DestroyKillAuraZone()
    end
end

-- Velocity Spoofer: подменяем отправляемую скорость корня по схеме Fake Position —
-- подмена на Heartbeat (после физики, перед репликацией), восстановление на первом
-- RenderStep. Своя симуляция идёт с настоящей скоростью, а упреждение противников
-- (silent aim, предикт выстрела/броска) берёт фейковую.
do
    local runtime = {
        BindName = "MM2_VelocitySpoofRestore",
        Root = nil, Real = nil, Sent = nil,
        LegitJumpVelocity = 50, -- стартовая скорость прыжка при стандартных настройках плейса
    }
    State.Runtime.VelocitySpoofRuntime = runtime

    -- Прыжок «как у всех»: из настроек плейса, а не из текущего (возможно изменённого) Humanoid.
    -- Гравитацию читаем сейчас — Swim потом выставляет её в 0.
    pcall(function()
        local starter = game:GetService("StarterPlayer")
        if starter.CharacterUseJumpPower then
            runtime.LegitJumpVelocity = starter.CharacterJumpPower
        else
            runtime.LegitJumpVelocity = math.sqrt(2 * Workspace.Gravity * starter.CharacterJumpHeight)
        end
    end)

    -- Настоящая скорость для своих систем, пока корень несёт подменённую.
    State.Runtime.GetRealVelocity = function(root)
        local velocity = root.AssemblyLinearVelocity
        if runtime.Root == root and runtime.Real and runtime.Sent then
            return velocity - runtime.Sent + runtime.Real
        end
        return velocity
    end

    local function restoreVelocity()
        local root, real, sent = runtime.Root, runtime.Real, runtime.Sent
        runtime.Root, runtime.Real, runtime.Sent = nil, nil, nil
        if root and root.Parent and real and sent then
            -- Убираем только нашу подмену: изменения скорости игрой между фазами сохраняются.
            root.AssemblyLinearVelocity = root.AssemblyLinearVelocity - sent + real
        end
    end

    local function spoofedVelocity(real)
        if State.Settings.VelocitySpoofMode == "Zero" then
            -- Направление настоящее, величина не выше стандартной ходьбы: бег, WalkSpeed
            -- и fly снаружи выглядят обычной ходьбой, упреждение недолетает.
            local cap = math.clamp(tonumber(State.Settings.VelocitySpoofSpeed) or CONFIG.DefaultWalkSpeed, 0, 20)
            -- В полёте (любой Fly/Swim) ограничиваем всю скорость: вертикаль fly тоже выдаёт.
            if State.Settings.FlyEnabled then
                return real.Magnitude > cap and real.Unit * cap or real
            end
            local flat = Vector3.new(real.X, 0, real.Z)
            if flat.Magnitude > cap then flat = flat.Unit * cap end
            -- На земле вверх не быстрее обычного прыжка; падение оставляем физичным.
            return flat + Vector3.yAxis * math.min(real.Y, runtime.LegitJumpVelocity)
        end
        local strength = math.clamp(tonumber(State.Settings.VelocitySpoofStrength) or 150, 20, 500)
        return Vector3.yAxis * strength
    end

    -- Фейковая скорость выгибает нашу кривую у других между пакетами — видимая дрожь.
    -- Режим «только мардерер»: спуфим лишь в роли убийцы, чтобы мазали именно шерифы,
    -- а в остальных ролях выглядим обычно. Себя проверяем напрямую (свой рюкзак виден),
    -- с запасным вариантом по серверным данным роли.
    local function isMurderer()
        local now = os.clock()
        if now < (runtime.NextRoleCheck or 0) then return runtime.Murderer end
        runtime.NextRoleCheck = now + 0.1
        local character = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local knife = (character and character:FindFirstChild("Knife")) or (backpack and backpack:FindFirstChild("Knife"))
        local data = State.Cache.PlayerData and State.Cache.PlayerData[LocalPlayer.Name]
        runtime.Murderer = knife ~= nil or (type(data) == "table" and data.Role == "Murderer")
        return runtime.Murderer
    end

    -- Будет ли спуф в этом кадре. Fake Position по нему решает, трогать ли скорость:
    -- результат не зависит от порядка Heartbeat-подписок.
    -- Для Chaos: спуфнутая скорость как центр кляксы и снятие нашей подмены,
    -- если Heartbeat спуфа в этом кадре успел сработать раньше Chaos
    State.Runtime.SpoofedVelocity = function(real) return spoofedVelocity(real) end
    State.Runtime.VelocitySpoofRelease = function() pcall(restoreVelocity) end

    State.Runtime.VelocitySpoofActive = function()
        if not State.Settings.VelocitySpoofEnabled then return false end
        if Fling.SessionActive or State.Runtime.WalkFlingActive then return false end
        return not State.Settings.VelocitySpoofMurdererOnly or isMurderer()
    end

    -- Частоту держим, пока идёт спуф, и отпускаем через секунду без него —
    -- чтобы флаг не дёргался на каждом доставании/убирании оружия.
    local function updateBoost(spoofing)
        local now = os.clock()
        if spoofing then runtime.LastSpoof = now end
        local hold = spoofing or now - (runtime.LastSpoof or 0) < 1
        State.Runtime.NetBoost("velocity", hold)
        -- Без этого стоящий персонаж не отправляется, и спуф на месте не доходит.
        State.Runtime.PhysicsNudge("velocity", hold)
    end

    local function disableOnError(err)
        State.Runtime.SetVelocitySpoof(false)
        if State.Runtime.VelocitySpoofToggle then State.Runtime.VelocitySpoofToggle:Set(false, false) end
        warn("[Velocity Spoofer] " .. tostring(err))
        ShowNotification("Velocity Spoofer stopped: " .. tostring(err), CONFIG.Colors.Red)
    end

    State.Runtime.SetVelocitySpoof = function(enabled)
        State.Settings.VelocitySpoofEnabled = false
        if runtime.Connection then runtime.Connection:Disconnect(); runtime.Connection = nil end
        if runtime.Removing then runtime.Removing:Disconnect(); runtime.Removing = nil end
        if runtime.PreSim then runtime.PreSim:Disconnect(); runtime.PreSim = nil end
        if runtime.Bound then
            pcall(function() RunService:UnbindFromRenderStep(runtime.BindName) end)
            runtime.Bound = false
        end
        pcall(restoreVelocity)
        runtime.LastSpoof = nil
        State.Runtime.NetBoost("velocity", false)
        State.Runtime.PhysicsNudge("velocity", false)
        if not enabled then return end

        local ok, err = pcall(function()
            RunService:BindToRenderStep(runtime.BindName, Enum.RenderPriority.First.Value, function()
                local restored, restoreError = pcall(restoreVelocity)
                if not restored then disableOnError(restoreError) end
            end)
        end)
        if not ok then disableOnError(err); return end
        runtime.Bound = true
        State.Settings.VelocitySpoofEnabled = true
        runtime.Removing = Core.Connect(LocalPlayer.CharacterRemoving, function()
            runtime.Root, runtime.Real, runtime.Sent = nil, nil, nil
        end)
        -- Страховка: подмена снимается и прямо перед физикой — если отрисовка кадра
        -- пропустилась, своя симуляция всё равно не увидит фейковую скорость
        runtime.PreSim = Core.Connect(RunService.PreSimulation, function() pcall(restoreVelocity) end)
        runtime.Connection = Core.Connect(RunService.Heartbeat, function()
            local success, failure = pcall(function()
                -- Подмена не накапливается: каждый Heartbeat начинаем с настоящей скорости.
                restoreVelocity()
                if not State.Settings.VelocitySpoofEnabled then return end
                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                -- Флинг сам управляет скоростью корня — не мешаем ему.
                local spoofing = root and humanoid and humanoid.Health > 0 and not root.Anchored
                    and State.Runtime.VelocitySpoofActive()
                updateBoost(spoofing)
                if not spoofing then return end
                -- Chaos в Desync сам шлёт линейную скорость поверх нашей (спуф — центр
                -- кляксы, Chaos — разброс), поэтому в эти кадры не пишем, чтобы не
                -- складывать две подмены с разным порядком восстановления
                if State.Runtime.ChaosOwnsVelocity and State.Runtime.ChaosOwnsVelocity() then return end
                local real = root.AssemblyLinearVelocity
                local sent = spoofedVelocity(real)
                runtime.Root, runtime.Real, runtime.Sent = root, real, sent
                root.AssemblyLinearVelocity = sent
            end)
            if not success then disableOnError(failure) end
        end)
    end
end

-- Fake Position: подмена на отправку физики с восстановлением перед камерой.
do
    local runtime = {
        BindName = "MM2_FakePositionRestore",
        VisualBindName = "MM2_FakePositionLocalSpin",
        SpinAt = 0, LastSpinAt = 0,
        Flip = false, NextRandom = 0, NextTarget = 0,
        Frame = 0, LastFrame = -1,
        Radius = 3, SpinAngle = 0,
        Side = Vector3.xAxis, Vertical = -Vector3.yAxis,
        MotionDistance = 0.01, MotionAngle = math.rad(0.5),
        MotionSpeed = 0.1, MotionAngularSpeed = 0.05,
        Lag = {Root = nil, Position = nil, StartedAt = 0, Delay = 0, HeldFor = 0, Holding = false},
    }
    State.Runtime.FakePositionRuntime = runtime
    -- Chaos в последних кадрах сам слал линейную скорость — спуф в это время молчит
    State.Runtime.ChaosOwnsVelocity = function()
        return State.Settings.FakePositionEnabled and runtime.ChaosOwnedAt ~= nil
            and os.clock() - runtime.ChaosOwnedAt < 0.1
    end

    local function resetFakeLag()
        runtime.Lag.Root, runtime.Lag.Position = nil, nil
        runtime.Lag.StartedAt, runtime.Lag.Delay, runtime.Lag.HeldFor = 0, 0, 0
        runtime.Lag.Holding = false
    end

    -- Длина очередного удержания: Max Delay, к Min Delay — на случайную долю,
    -- не больше Randomization. Ограничено временем, а не FPS
    local function fakeLagDelay()
        local limits = CONFIG.FakeLag
        local maximum = math.clamp(tonumber(State.Settings.FakeLagMaxDelay) or 200, limits.MaxDelay[1], limits.MaxDelay[2])
        local minimum = math.min(maximum, math.clamp(tonumber(State.Settings.FakeLagMinDelay) or 80, limits.MinDelay[1], limits.MinDelay[2]))
        local spread = math.clamp(tonumber(State.Settings.FakeLagRandomization) or 0, limits.Randomization[1], limits.Randomization[2]) / limits.Randomization[2]
        return (maximum - (maximum - minimum) * spread * math.random()) / 1000
    end

    -- Удерживается только позиция; камера и реальное движение восстанавливаются
    -- прежним механизмом. Это оценка отправляемой позы, не перехват пакетов.
    local function fakeLagOffset(root, now, flush)
        local lag = runtime.Lag
        local position = root.Position
        local speed = State.Runtime.GetRealVelocity(root).Magnitude
        local elapsed = math.max(0, now - lag.StartedAt)
        local distance = lag.Position and (position - lag.Position).Magnitude or 0
        -- Не тянем старую точку через респавн, остановку, атаку или телепорт.
        if lag.Root ~= root or not lag.Position or flush or elapsed >= lag.Delay
            or distance >= CONFIG.FakeLag.MaxDistance
            or (speed < runtime.MotionSpeed and distance < runtime.MotionDistance) then
            lag.Root, lag.Position, lag.StartedAt = root, position, now
            lag.HeldFor, lag.Holding = 0, false
            lag.Delay = fakeLagDelay()
        else
            lag.HeldFor, lag.Holding = elapsed, true
        end
        return lag.Position - position
    end

    local function restorePosition()
        local root, original, sent = runtime.Root, runtime.Original, runtime.Sent
        local velReal, velSent = runtime.VelReal, runtime.VelSent
        local angReal, angSent = runtime.AngReal, runtime.AngSent
        runtime.Root, runtime.Original, runtime.Sent = nil, nil, nil
        runtime.VelReal, runtime.VelSent = nil, nil
        runtime.AngReal, runtime.AngSent = nil, nil
        State.Runtime.FakePositionOffset = Vector3.zero
        if not root or not root.Parent then return end
        if original and sent then
            -- Убираем только нашу добавку (позицию и поворот: Spin/Pitch),
            -- сохраняя движение между фазами: current = sent·Δ → original·Δ.
            root.CFrame = original * sent:ToObjectSpace(root.CFrame)
        end
        if velReal and velSent then
            root.AssemblyLinearVelocity = root.AssemblyLinearVelocity - velSent + velReal
        end
        if angReal and angSent then
            root.AssemblyAngularVelocity = root.AssemblyAngularVelocity - angSent + angReal
        end
    end

    -- Сдвиг корня нашими фичами (Speed, Fly). Пока Desync держит подменённый CFrame
    -- (Heartbeat → восстановление перед кадром/физикой), откат считается как
    -- original · sent⁻¹ · текущий: сдвиг, добавленный к подменённому корню, при
    -- откате поворачивался на угол Spin — Speed уводило в случайную сторону.
    -- Поэтому двигаем и обе запомненные позы: откат вернёт original + delta.
    State.Runtime.MoveRoot = function(root, delta)
        if runtime.Root == root and runtime.Original and runtime.Sent then
            runtime.Original += delta
            runtime.Sent += delta
        end
        root.CFrame += delta
    end

    -- Скорость, согласованная с отправляемой позицией. Другие клиенты тянут нас между
    -- пакетами по скорости: при удержании фейклага настоящая скорость уводила модель
    -- вперёд с откатом (дрожь) и заодно подсказывала упреждению, где мы на самом деле.
    -- Без Fake Lag не трогаем: у Jitter тряска — цель, у Spin позиция настоящая.
    local function consistentVelocity(lagging)
        if lagging and runtime.Lag.Holding then return Vector3.zero end
        return nil
    end

    local function desyncRadius()
        local limits = CONFIG.Desync.Radius
        return math.clamp(tonumber(State.Settings.FakePositionRadius) or 3, limits[1], limits[2])
    end

    local function randomUnit()
        local direction = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
        return direction.Magnitude > 1e-3 and direction.Unit or Vector3.yAxis
    end

    -- Chaos: только скорости, CFrame не пишем (запись CFrame гасит у наблюдателей
    -- экстраполяцию); редкие всплески Jitter делает Heartbeat (см. RefreshInterval). Линейная — вокруг настоящей
    -- (или спуфнутой, если включён Velocity Spoofer: он задаёт центр кляксы, Chaos —
    -- разброс); угловая — кувыркание.
    local function applyChaos(root, now)
        local strength = desyncRadius() * CONFIG.Desync.ChaosPerStud
        runtime.Root = root
        if strength > 0 then
            -- Линейную скорость ведём мы; при активном спуфе он задаёт центр кляксы
            local spoof = State.Runtime.VelocitySpoofActive()
            if spoof then State.Runtime.VelocitySpoofRelease() end
            local real = root.AssemblyLinearVelocity
            local base = spoof and State.Runtime.SpoofedVelocity(real) or real
            runtime.VelReal, runtime.VelSent = real, base + randomUnit() * strength
            root.AssemblyLinearVelocity = runtime.VelSent
            runtime.ChaosOwnedAt = now
        end
        local realW = root.AssemblyAngularVelocity
        runtime.AngReal, runtime.AngSent = realW, randomUnit() * CONFIG.Desync.ChaosAngular
        root.AssemblyAngularVelocity = runtime.AngSent
    end

    -- Поворот, который увидят другие: Spin крутит yaw, Pitch наклоняет корпус
    -- (вверх / вниз) поверх Jitter / Spin
    local function spinSpeed()
        local limits = CONFIG.Desync.SpinSpeed
        return math.rad(math.clamp(tonumber(State.Settings.FakeSpinSpeed) or 720, limits[1], limits[2]))
    end

    -- Поворот по yaw исходной позы + наклон Pitch; angle — угол Spin (nil — без Spin)
    local function composeRotation(original, angle)
        local rotation = original.Rotation
        if angle then
            local look = original.LookVector
            rotation = CFrame.Angles(0, math.atan2(-look.X, -look.Z) + angle, 0)
        end
        local pitch = CONFIG.Desync.Pitches[State.Settings.FakePositionPitch] or 0
        if pitch ~= 0 then rotation *= CFrame.Angles(math.rad(pitch), 0, 0) end
        return rotation
    end

    local function sentRotation(original, dt)
        -- Только Fake Lag: поворот настоящий
        if not State.Settings.FakePositionEnabled then return original.Rotation end
        if State.Settings.FakePositionMode ~= "Spin" then return composeRotation(original, nil) end
        runtime.SpinAngle = (runtime.SpinAngle + spinSpeed() * dt) % (2 * math.pi)
        runtime.SpinAt = os.clock()
        runtime.LastSpinAt = runtime.SpinAt
        return composeRotation(original, runtime.SpinAngle)
    end

    -- Spin Local Too: чисто визуально крутим себя так же, как нас видят другие.
    -- Персонажа не трогаем вовсе: замеры — наклон корня (Pitch Up/Down) Humanoid
    -- принимал за опрокидывание (FallingDown, персонаж падал и не бежал), а у R15 в
    -- MM2 корень связан с телом AnimationConstraint, который решает физика, — поворот
    -- сустава до отрисовки не доходит. Поэтому показываем локальную копию: клоны
    -- частей без суставов и коллизий раскладываются каждый кадр по позе настоящих
    -- частей (анимации сохраняются) и поворачиваются вокруг корня, а настоящие части
    -- скрываются только у нас через LocalTransparencyModifier.
    -- Ауры Visuals (эффекты внутри частей, атрибут StandaloneVFX_Owner) клонируются
    -- вместе с частями и едут с копией; на настоящем теле их эффекты на это время
    -- выключаем — LocalTransparencyModifier частицы и лучи не прячет, была бы вторая аура
    runtime.AvatarMap, runtime.AvatarHidden, runtime.AvatarEffects = {}, {}, {}
    runtime.AvatarCount, runtime.AvatarAuraCount, runtime.AvatarCheckAt = 0, 0, 0
    runtime.AvatarRebuildAt = nil

    -- Вызывается при правке ауры. Пересобираем с задержкой после последней правки:
    -- ползунок цвета дёргает обработчик на каждом шаге, копия не пересобирается каждый кадр
    State.Runtime.RefreshLocalSpin = function()
        runtime.AvatarRebuildAt = os.clock() + 0.15
    end

    local function auraObjects(character)
        local ok, found = pcall(function() return character:QueryDescendants("[$StandaloneVFX_Owner]") end)
        return ok and found or {}
    end

    -- Эффекты на частях (частицы, трейлы, лучи, свет, огонь: эффекты скинов ножа и
    -- пистолета, в руке и на дисплее). LocalTransparencyModifier их не прячет —
    -- на настоящем теле они висели на месте, а не крутились с копией. Поэтому
    -- настоящие гасим, копии включаем, а «намерение» владельца (скинченджер
    -- включает/выключает эффект, например на броске) переносим на копию
    local EFFECT_CLASSES = {ParticleEmitter = true, Trail = true, Beam = true, PointLight = true,
        SpotLight = true, SurfaceLight = true, Fire = true, Smoke = true, Sparkles = true}
    local FX_TAG = "VioliteSpinFx"
    runtime.AvatarFx, runtime.AvatarFxCount = {}, 0

    -- Эффекты самой части; во вложенных частях — их собственные (те — отдельные
    -- источники). Ауры Visuals ведёт hideRealAuras
    local function sourceEffects(src)
        local list = {}
        for _, d in ipairs(src:GetDescendants()) do
            if EFFECT_CLASSES[d.ClassName] and d:FindFirstAncestorWhichIsA("BasePart") == src
                and d:GetAttribute("StandaloneVFX_Owner") == nil then
                table.insert(list, d)
            end
        end
        return list
    end

    local function effectCount(sources)
        local count = 0
        for _, src in ipairs(sources) do count += #sourceEffects(src) end
        return count
    end

    -- Сигналы свойств могут приходить отложенно, поэтому свою запись отличаем
    -- счётчиком ожидаемых событий, а не флагом на время присваивания
    local function trackEffect(real, copy)
        local entry = {Copy = copy, Intent = real.Enabled, Own = 0}
        copy.Enabled = entry.Intent
        entry.Conn = Core.Connect(real:GetPropertyChangedSignal("Enabled"), function()
            if entry.Own > 0 then entry.Own -= 1; return end
            entry.Intent = real.Enabled
            if copy.Parent then copy.Enabled = entry.Intent end
            if real.Enabled then entry.Own += 1; real.Enabled = false end
        end)
        if real.Enabled then entry.Own += 1; real.Enabled = false end
        runtime.AvatarFx[real] = entry
    end

    local function unhideReal()
        for part in pairs(runtime.AvatarHidden) do
            if part.Parent then pcall(function() part.LocalTransparencyModifier = 0 end) end
        end
        table.clear(runtime.AvatarHidden)
        for effect in pairs(runtime.AvatarEffects) do
            if effect.Parent then pcall(function() effect.Enabled = true end) end
        end
        table.clear(runtime.AvatarEffects)
        for real, entry in pairs(runtime.AvatarFx) do
            pcall(function() entry.Conn:Disconnect() end)
            if real.Parent then pcall(function() real.Enabled = entry.Intent end) end
        end
        table.clear(runtime.AvatarFx)
    end

    local function hideRealAuras(character)
        for _, effect in ipairs(auraObjects(character)) do
            local ok, enabled = pcall(function() return effect.Enabled end)
            if ok and enabled == true and not runtime.AvatarEffects[effect] then
                runtime.AvatarEffects[effect] = true
                effect.Enabled = false
            end
        end
    end

    -- Флаг для скинченджера: пока копия активна, прозрачность наших частей ведём мы
    local function setSpinFlag(on)
        pcall(function() getgenv().VioliteLocalSpin = on or nil end)
    end

    local function destroyLocalSpin()
        setSpinFlag(false)
        unhideReal()
        if runtime.AvatarModel then pcall(function() runtime.AvatarModel:Destroy() end) end
        runtime.AvatarModel, runtime.AvatarChar, runtime.AvatarCount = nil, nil, 0
        table.clear(runtime.AvatarMap)
    end

    -- Все части, включая HumanoidRootPart: он невидим, но на нём сидят Magic Circle,
    -- крылья и др. — без его копии эти ауры оставались бы на настоящем корне.
    -- Плюс дисплеи оружия (нож на спине, пистолет на поясе): игра держит их в
    -- Workspace.WeaponDisplays на RigidConstraint к нашему торсу, скинченджер
    -- кладёт туда же свои фейки и детали. Жёсткая связь = одна сборка с нашим
    -- корнем — так находим все свои, не трогая чужие
    local function avatarSources(character)
        local sources = character:QueryDescendants("BasePart")
        local root = character:FindFirstChild("HumanoidRootPart")
        local displays = Workspace:FindFirstChild("WeaponDisplays")
        if root and displays then
            for _, part in ipairs(displays:GetDescendants()) do
                if part:IsA("BasePart") and part.AssemblyRootPart == root then
                    table.insert(sources, part)
                end
            end
        end
        return sources
    end

    -- Меш/текстура дисплеев: скинченджер меняет их на месте — копию надо пересобрать
    local function displaySignature(character, sources)
        local parts = {}
        for _, part in ipairs(sources) do
            if not part:IsDescendantOf(character) then
                local mesh = part:FindFirstChildOfClass("SpecialMesh")
                table.insert(parts, (mesh and mesh.MeshId .. mesh.TextureId) or (part:IsA("MeshPart") and part.MeshId .. part.TextureID) or part.Name)
            end
        end
        return table.concat(parts, "|")
    end

    -- Группа коллизий, которая не сталкивается с персонажем (в MM2 — PlayerNoCollision).
    -- Клиент свои группы регистрировать не может, берём из уже заведённых игрой
    local function noCollisionGroup(root)
        local found
        pcall(function()
            for _, group in ipairs(Core.PhysicsService:GetRegisteredCollisionGroups()) do
                if not Core.PhysicsService:CollisionGroupsAreCollidable(group.name, root.CollisionGroup) then
                    found = group.name
                    break
                end
            end
        end)
        return found
    end

    local function buildLocalSpin(character, sources)
        destroyLocalSpin()
        local root = character:FindFirstChild("HumanoidRootPart")
        local group = root and noCollisionGroup(root)
        local model = Core.New("Model")
        model.Name = "VioliteLocalSpin"
        for _, src in ipairs(sources) do
            -- Метим эффекты, чтобы найти их пары в клоне; метки сразу снимаем
            local effects = sourceEffects(src)
            for i, effect in ipairs(effects) do pcall(function() effect:SetAttribute(FX_TAG, i) end) end
            local ok, copy = pcall(function() return src:Clone() end)
            for _, effect in ipairs(effects) do pcall(function() effect:SetAttribute(FX_TAG, nil) end) end
            if ok and copy then
                Core.Own(copy)
                for _, d in ipairs(copy:GetDescendants()) do
                    local index = d:GetAttribute(FX_TAG)
                    if index then
                        d:SetAttribute(FX_TAG, nil)
                        if effects[index] then pcall(trackEffect, effects[index], d) end
                    end
                end
                for _, d in ipairs(copy:GetDescendants()) do
                    -- Вложенные части — отдельные источники (детали скинов на дисплеях),
                    -- в клоне родителя они были бы вторыми копиями без синхронизации
                    if d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("BaseScript") or d:IsA("Sound")
                        or d:IsA("BasePart") then
                        pcall(function() d:Destroy() end)
                    end
                end
                copy.Anchored = true
                copy.CanCollide = false
                copy.CanQuery = false
                copy.CanTouch = false
                copy.Massless = true
                if group then copy.CollisionGroup = group end
                copy.Parent = model
                runtime.AvatarMap[src] = copy
            end
        end
        -- Одежда (Shirt/Pants/ShirtGraphic) и цвета тела — объекты модели, на части их
        -- накладывает Humanoid. Без него копия была «голой»: кладём копии одежды и
        -- неактивный Humanoid (без машины состояний, ника и полоски здоровья).
        -- Замер: Humanoid принудительно включает торсу копии CanCollide/CanQuery —
        -- заякоренный торс внутри нашего тела давал Climbing ↔ Running и падение.
        -- Поэтому Humanoid — только если есть группа без столкновений с персонажем
        local realHumanoid = character:FindFirstChildOfClass("Humanoid")
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Clothing") or item:IsA("ShirtGraphic") or item:IsA("BodyColors") then
                local ok, copy = pcall(function() return item:Clone() end)
                if ok and copy then Core.Own(copy).Parent = model end
            end
        end
        if group then pcall(function()
            local humanoid = Core.New("Humanoid")
            humanoid.EvaluateStateMachine = false
            humanoid.RequiresNeck = false
            humanoid.BreakJointsOnDeath = false
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
            if realHumanoid then humanoid.RigType = realHumanoid.RigType end
            humanoid.Parent = model
        end) end
        model.Parent = Workspace.CurrentCamera
        runtime.AvatarModel, runtime.AvatarChar, runtime.AvatarCount = model, character, #sources
        runtime.AvatarDisplays = displaySignature(character, sources)
        runtime.AvatarFxCount = effectCount(sources)
        setSpinFlag(true)
        -- Клонировали с включёнными эффектами (unhideReal до клонирования их вернул),
        -- теперь гасим их на настоящем теле
        runtime.AvatarAuraCount = #auraObjects(character)
        hideRealAuras(character)
    end

    local function applyLocalSpin()
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local active = root and State.Settings.FakePositionEnabled and State.Settings.FakeSpinLocal
            and State.Settings.FakePositionMode == "Spin"
            -- Heartbeat Spin в последних кадрах работал (не пауза из-за флинга/посадки)
            and os.clock() - runtime.LastSpinAt <= 0.1
        -- Камера вплотную к голове: копия плавно гаснет, как Roblox гасит своё тело
        -- (иначе голова копии закрывала обзор); в первом лице копии нет вовсе
        local camera = Workspace.CurrentCamera
        local head = character and character:FindFirstChild("Head")
        local fade = 0
        if active and camera and head then
            local distance = (camera.CFrame.Position - head.Position).Magnitude
            fade = math.clamp(1 - (distance - 0.5) / 2.5, 0, 1)
            if fade >= 0.999 then active = false end
        end
        if not active then
            if runtime.AvatarModel then destroyLocalSpin() end
            return
        end
        -- Состав частей меняется (тул, аксессуар) — сверяем не каждый кадр
        local now = os.clock()
        if runtime.AvatarRebuildAt and now >= runtime.AvatarRebuildAt then
            runtime.AvatarRebuildAt = nil
            buildLocalSpin(character, avatarSources(character))
        elseif runtime.AvatarChar ~= character or not runtime.AvatarModel or not runtime.AvatarModel.Parent then
            buildLocalSpin(character, avatarSources(character))
        elseif now >= runtime.AvatarCheckAt then
            runtime.AvatarCheckAt = now + 0.5
            -- Сменился набор частей или аур (включили/выключили ауру) — пересобираем
            local sources = avatarSources(character)
            if #sources ~= runtime.AvatarCount or #auraObjects(character) ~= runtime.AvatarAuraCount
                or displaySignature(character, sources) ~= runtime.AvatarDisplays
                or effectCount(sources) ~= runtime.AvatarFxCount then
                buildLocalSpin(character, sources)
            end
        end
        -- Угол досчитываем к моменту отрисовки: вращение плавное при любом FPS
        local angle = runtime.SpinAngle + spinSpeed() * (now - runtime.SpinAt)
        local rootFrame = root.CFrame
        local shown = CFrame.new(rootFrame.Position) * composeRotation(rootFrame, angle)
        local inverse = rootFrame:Inverse()
        for src, copy in pairs(runtime.AvatarMap) do
            if src.Parent then
                copy.CFrame = shown * (inverse * src.CFrame)
                copy.Transparency = src.Transparency
                copy.Color = src.Color   -- хрома скинов перекрашивает части каждый кадр
                copy.LocalTransparencyModifier = fade
                runtime.AvatarHidden[src] = true
                src.LocalTransparencyModifier = 1
            else
                copy.Transparency = 1
            end
        end
    end

    -- Оценка образа Chaos для чамсов: наблюдатель дорисовывает нас по поддельным
    -- скоростям в пределах окна пакета — берём случайную точку этого окна
    local function chaosEstimate(root)
        local frame = root.CFrame
        local t = CONFIG.Desync.ChaosChamsLead * math.random()
        local position = frame.Position
        if runtime.VelSent and runtime.VelReal then
            position += (runtime.VelSent - runtime.VelReal) * t
        end
        local rotation = frame.Rotation
        local w = runtime.AngSent
        if w and w.Magnitude > 1e-3 then
            rotation = CFrame.fromAxisAngle(w.Unit, w.Magnitude * t) * rotation
        end
        return CFrame.new(position) * rotation
    end

    local function updateAxes(root)
        -- Смещение всегда ориентируем на угрозу (или ближайшего игрока)
        local direction = root.CFrame.LookVector
        local threat = getMurder()
        if threat == LocalPlayer then threat = getSheriff() end
        local targetRoot = threat and threat.Character and threat.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then
            local closest = math.huge
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local character = player.Character
                    local candidate = character and character:FindFirstChild("HumanoidRootPart")
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    if candidate and humanoid and humanoid.Health > 0 then
                        local distance = (candidate.Position - root.Position).Magnitude
                        if distance < closest then closest, targetRoot = distance, candidate end
                    end
                end
            end
        end
        if targetRoot then direction = targetRoot.Position - root.Position end
        if direction.Magnitude < 0.001 then direction = Vector3.zAxis end
        direction = direction.Unit
        local side = direction:Cross(Vector3.yAxis)
        if side.Magnitude < 0.001 then side = Vector3.xAxis end
        runtime.TargetSide = side.Unit
        runtime.TargetVertical = direction:Cross(runtime.TargetSide).Unit
        -- Первое направление после включения — сразу, дальше только плавно.
        if not runtime.AxesReady then
            runtime.Side, runtime.Vertical = runtime.TargetSide, runtime.TargetVertical
            runtime.AxesReady = true
        end
    end

    -- Оси и радиус тянутся к новым целям, а не прыгают: смена угрозы или случайного
    -- радиуса раньше давала рывок смещения у других (замер: 5 рывков >1 stud за 4 с).
    local function smoothTowardTargets(dt)
        local blend = 1 - math.exp(-dt * 10)
        local function approach(current, target)
            local mixed = current:Lerp(target, blend)
            -- Почти противоположные векторы при смешивании схлопываются — берём цель.
            return mixed.Magnitude > 0.05 and mixed.Unit or target
        end
        if runtime.TargetSide then runtime.Side = approach(runtime.Side, runtime.TargetSide) end
        if runtime.TargetVertical then runtime.Vertical = approach(runtime.Vertical, runtime.TargetVertical) end
        if runtime.RadiusTarget then runtime.Radius += (runtime.RadiusTarget - runtime.Radius) * blend end
    end

    local function estimateReplicatedFrame(root, realFrame, candidateFrame, paused)
        if runtime.EstimateRoot ~= root or not runtime.LastRealFrame then
            runtime.EstimateRoot = root
            runtime.LastRealFrame = realFrame
            runtime.EstimatedFrame = realFrame
        end
        local delta = runtime.LastRealFrame:ToObjectSpace(realFrame)
        local _, angle = delta:ToAxisAngle()
        local moving = delta.Position.Magnitude >= runtime.MotionDistance
            or math.abs(angle) >= runtime.MotionAngle
            or State.Runtime.GetRealVelocity(root).Magnitude >= runtime.MotionSpeed
            or root.AssemblyAngularVelocity.Magnitude >= runtime.MotionAngularSpeed
        runtime.EstimateMoving = moving

        -- Локальная подмена CFrame сама по себе не означает отправку физики.
        -- На покое удерживаем последнюю оценку; движение проверяем по настоящему
        -- корню, иначе собственный Jitter бесконечно считался бы движением.
        if moving or paused then
            runtime.LastRealFrame = realFrame
            runtime.EstimatedFrame = candidateFrame
        end
        return runtime.EstimatedFrame
    end

    local function disableOnError(err)
        State.Settings.FakeLagEnabled = false
        State.Runtime.SetFakePosition(false)
        if State.Runtime.FakePositionToggle then State.Runtime.FakePositionToggle:Set(false, false) end
        if State.Runtime.FakeLagToggle then State.Runtime.FakeLagToggle:Set(false, false) end
        warn("[Fake Position] " .. tostring(err))
        ShowNotification("Fake Position stopped: " .. tostring(err), CONFIG.Colors.Red)
    end

    -- Движок подмены общий для Desync и Fake Lag: работает, пока включён хоть один
    local startEngine
    State.Runtime.SetFakePosition = function(enabled)
        State.Settings.FakePositionEnabled = enabled == true
        startEngine()
    end
    State.Runtime.SetFakeLag = function(enabled)
        State.Settings.FakeLagEnabled = enabled == true
        startEngine()
    end

    startEngine = function()
        local desync, lagging = State.Settings.FakePositionEnabled, State.Settings.FakeLagEnabled
        State.Settings.FakePositionEnabled, State.Settings.FakeLagEnabled = false, false
        if runtime.Connection then runtime.Connection:Disconnect(); runtime.Connection = nil end
        if runtime.Removing then runtime.Removing:Disconnect(); runtime.Removing = nil end
        if runtime.PreSim then runtime.PreSim:Disconnect(); runtime.PreSim = nil end
        if runtime.Bound then
            pcall(function() RunService:UnbindFromRenderStep(runtime.BindName) end)
            runtime.Bound = false
        end
        pcall(restorePosition)
        pcall(function() RunService:UnbindFromRenderStep(runtime.VisualBindName) end)
        pcall(destroyLocalSpin)
        runtime.EstimateRoot, runtime.LastRealFrame, runtime.EstimatedFrame = nil, nil, nil
        runtime.EstimateMoving = false
        resetFakeLag()
        State.Runtime.NetBoost("fakeposition", false)
        State.Runtime.PhysicsNudge("fakeposition", false)
        if not desync and not lagging then return end

        runtime.SpinAngle, runtime.Flip, runtime.NextRandom, runtime.NextTarget = 0, false, 0, 0
        runtime.Frame, runtime.LastFrame = 0, -1
        runtime.AxesReady = false
        local ok, err = pcall(function()
            RunService:BindToRenderStep(runtime.BindName, Enum.RenderPriority.First.Value, function()
                runtime.Frame += 1
                local restored, restoreError = pcall(restorePosition)
                if not restored then disableOnError(restoreError) end
            end)
        end)
        if not ok then disableOnError(err); return end
        runtime.Bound = true
        State.Settings.FakePositionEnabled, State.Settings.FakeLagEnabled = desync, lagging
        -- 60 пакетов/с: Spin и Chaos у других плавнее, смещение ровнее.
        State.Runtime.NetBoost("fakeposition", true)
        runtime.Removing = Core.Connect(LocalPlayer.CharacterRemoving, function()
            pcall(restorePosition)
            pcall(destroyLocalSpin)
            resetFakeLag()
            runtime.NextTarget = 0
            runtime.EstimateRoot, runtime.LastRealFrame, runtime.EstimatedFrame = nil, nil, nil
        end)
        -- Страховка: подмена (CFrame и скорости) снимается и прямо перед физикой —
        -- своя симуляция никогда не идёт с фейковым состоянием, даже без отрисовки
        runtime.PreSim = Core.Connect(RunService.PreSimulation, function() pcall(restorePosition) end)
        pcall(function()
            RunService:BindToRenderStep(runtime.VisualBindName, Enum.RenderPriority.Camera.Value + 2, function()
                local ok, err = pcall(applyLocalSpin)
                if not ok then warn("[Desync] local spin: " .. tostring(err)); pcall(destroyLocalSpin) end
            end)
        end)
        runtime.Connection = Core.Connect(RunService.Heartbeat, function(dt)
            local success, failure = pcall(function()
                -- Страховка на случай пропущенной отрисовки: смещения не суммируются.
                restorePosition()
                local desyncOn = State.Settings.FakePositionEnabled
                if not desyncOn and not State.Settings.FakeLagEnabled then return end
                -- Heartbeat может сработать несколько раз между отрисовками.
                if runtime.LastFrame == runtime.Frame then return end
                runtime.LastFrame = runtime.Frame
                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if not root or not humanoid or humanoid.Health <= 0 then resetFakeLag(); return end
                -- Fake Lag не держим в невидимости: удержанная позиция выдала бы тело
                local lagging = State.Settings.FakeLagEnabled and not State.Settings.IsInvisible
                -- Толчок физики (отправка на месте): стоящего персонажа Roblox не шлёт.
                -- Spin, Chaos и наклон Pitch должны быть видны и на месте;
                -- Jitter намеренно трясётся лишь в движении — так легитнее.
                local mode = desyncOn and State.Settings.FakePositionMode or nil
                -- Chaos: раз в RefreshInterval на RefreshBurst идём веткой Jitter — это
                -- возвращает наблюдателям экстраполяцию (см. CONFIG.Desync)
                local burst = false
                if mode == "Chaos" then
                    local clock = os.clock()
                    if clock - (runtime.BurstAt or -math.huge) >= CONFIG.Desync.RefreshInterval then
                        runtime.BurstAt = clock
                    end
                    burst = clock - runtime.BurstAt < CONFIG.Desync.RefreshBurst
                    if burst then mode = "Jitter" end
                end
                local nudging = mode == "Spin" or mode == "Chaos"
                    or (desyncOn and (CONFIG.Desync.Pitches[State.Settings.FakePositionPitch] or 0) ~= 0)
                State.Runtime.PhysicsNudge("fakeposition", nudging)
                if Fling.SessionActive or State.Runtime.WalkFlingActive or State.Settings.FlyEnabled
                    or State.Settings.AutoFarmEnabled or humanoid.Sit or root.Anchored
                    or (not desyncOn and not lagging) then
                    resetFakeLag()
                    local estimate = estimateReplicatedFrame(root, root.CFrame, root.CFrame, true)
                    if State.Settings.PingChamsEnabled then pcall(PingChams.pushSample, tick(), character, estimate, true) end
                    return
                end
                local now = os.clock()
                if desyncOn then
                    if now >= runtime.NextTarget then
                        runtime.NextTarget = now + 0.25
                        updateAxes(root)
                    end
                    if now >= runtime.NextRandom then
                        runtime.NextRandom = now + 0.16 + math.random() * 0.24
                        runtime.RadiusTarget = desyncRadius() * (0.8 + math.random() * 0.2)
                    end
                    smoothTowardTargets(dt)
                end
                -- Chaos пишет только скорости (запись CFrame гасит экстраполяцию),
                -- поэтому Fake Lag на это время не держит позицию
                if mode == "Chaos" then
                    resetFakeLag()
                    applyChaos(root, now)
                    if State.Settings.PingChamsEnabled then
                        pcall(PingChams.pushSample, tick(), character, chaosEstimate(root), true)
                    end
                    return
                end
                local offset = Vector3.zero
                if lagging then
                    local attacking = character:FindFirstChildOfClass("Tool")
                        and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                    offset = fakeLagOffset(root, now, attacking)
                else
                    resetFakeLag()
                end
                if mode == "Jitter" then
                    runtime.Flip = not runtime.Flip
                    local amplitude = burst and CONFIG.Desync.RefreshAmplitude or runtime.Radius
                    offset += runtime.Side * (runtime.Flip and amplitude or -amplitude)
                end
                -- Spin: позиция настоящая (или удержанная Fake Lag), крутится только поворот
                runtime.Root, runtime.Original = root, root.CFrame
                runtime.Sent = CFrame.new(runtime.Original.Position + offset) * sentRotation(runtime.Original, dt)
                State.Runtime.FakePositionOffset = offset
                -- Режимы с толчком физики уходят в сеть и стоя — оценка идёт каждый кадр
                local estimate = estimateReplicatedFrame(root, runtime.Original, runtime.Sent, lagging or nudging)
                if State.Settings.PingChamsEnabled then
                    pcall(PingChams.pushSample, tick(), character, estimate, true)
                end
                root.CFrame = runtime.Sent
                -- Velocity Spoofer в этом кадре главнее: его скорость и есть цель.
                if not State.Runtime.VelocitySpoofActive() then
                    local real = root.AssemblyLinearVelocity
                    local velocity = consistentVelocity(lagging)
                    if velocity then
                        runtime.VelReal, runtime.VelSent = real, velocity
                        root.AssemblyLinearVelocity = velocity
                    end
                end
            end)
            if not success then disableOnError(failure) end
        end)
    end
end

InstantKillAll = function()
    local murderer = getMurder()
    if murderer ~= LocalPlayer then
        if State.Settings.NotificationsEnabled then
            ShowNotification(
                "<font color=\"rgb(255, 85, 85)\">Error:</font> <font color=\"rgb(220,220,220)\">You are not the murderer</font>",
                CONFIG.Colors.Text
            )
        end
        return
    end

    local handleTouched = GetKnifeHandleTouched()
    if not handleTouched then
        if State.Settings.NotificationsEnabled then
            ShowNotification(
                "<font color=\"rgb(255, 85, 85)\">Error:</font> <font color=\"rgb(220,220,220)\">Knife not found</font>",
                CONFIG.Colors.Text
            )
        end
        return
    end

    local killCount = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetPart = player.Character:FindFirstChild("UpperTorso") or player.Character:FindFirstChild("Torso")
            if targetPart then
                pcall(function() handleTouched:FireServer(targetPart) end)
                killCount = killCount + 1
                task.wait(0.05)
            end
        end
    end

    if State.Settings.NotificationsEnabled then
        ShowNotification(
            "<font color=\"rgb(220,220,220)\">InstantKillAll:</font> <font color=\"rgb(168,228,160)\">Killed " .. killCount .. " players</font>",
            CONFIG.Colors.Green
        )
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 16: VIEW CLIP & TELEPORT
-- ══════════════════════════════════════════════════════════════════════════════

-- EnableViewClip() - DevCameraOcclusionMode.Invisicam
function Core.Movement.EnableViewClip()
    State.Settings.ViewClipEnabled = true
    LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
end

-- DisableViewClip() - DevCameraOcclusionMode.Zoom
function Core.Movement.DisableViewClip()
    State.Settings.ViewClipEnabled = false
    LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
end

-- TeleportToMouse() - TP на mouse.Hit.Position
function Core.Movement.TeleportToMouse()
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

-- ============= Невидимость =============
local InvisibilityConnection = nil
Core.Invisibility = {Transparency = {}}

local function setCharacterTransparency(char, value)
    if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if (part:IsA("BasePart") and part.Name ~= "HumanoidRootPart") or part:IsA("Decal") then
            if value == 0 then
                local original = Core.Invisibility.Transparency[part]
                if original ~= nil then part.Transparency = original; Core.Invisibility.Transparency[part] = nil end
            else
                if Core.Invisibility.Transparency[part] == nil then Core.Invisibility.Transparency[part] = part.Transparency end
                part.Transparency = value
            end
        end
    end
end


local INVIS_DEPTH = 200000  -- юнитов вниз, чтобы скрыть от сервера

ToggleInvisibility = function()
    State.Settings.IsInvisible = not State.Settings.IsInvisible

    if State.Settings.IsInvisible then
        if InvisibilityConnection then InvisibilityConnection:Disconnect() end

        InvisibilityConnection = Core.Connect(RunService.Heartbeat, function()
            if not State.Settings.IsInvisible then return end

            local Character = LocalPlayer.Character
            if not Character then return end

            local RootPart = Character:FindFirstChild('HumanoidRootPart')
            local Humanoid = Character:FindFirstChild('Humanoid')
            if not RootPart or not Humanoid then return end

            if Core.Invisibility.Character ~= Character then
                Core.Invisibility.Character = Character
                setCharacterTransparency(Character, 0.5)
                if Core.Invisibility.Added then Core.Invisibility.Added:Disconnect() end
                Core.Invisibility.Added = Core.Connect(Character.DescendantAdded, function(part)
                    if (part:IsA("BasePart") and part.Name ~= "HumanoidRootPart") or part:IsA("Decal") then
                        Core.Invisibility.Transparency[part] = part.Transparency
                        part.Transparency = 0.5
                    end
                end)
            end

            local OriginalCFrame       = RootPart.CFrame
            local OriginalCameraOffset = Humanoid.CameraOffset
            local NewCFrame            = OriginalCFrame * CFrame.new(0, -INVIS_DEPTH, 0)

            Core.Invisibility.Frame = {Root = RootPart, Humanoid = Humanoid, CFrame = OriginalCFrame, Offset = OriginalCameraOffset}
            RootPart.CFrame     = NewCFrame
            Humanoid.CameraOffset = NewCFrame:ToObjectSpace(CFrame.new(OriginalCFrame.Position)).Position

            RunService.RenderStepped:Wait()

            RootPart.CFrame     = OriginalCFrame
            Humanoid.CameraOffset = OriginalCameraOffset
            Core.Invisibility.Frame = nil
        end)

        if State.Settings.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(220,220,220)\">Invisibility</font> <font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Text)
        end
    else
        if InvisibilityConnection then
            InvisibilityConnection:Disconnect()
            InvisibilityConnection = nil
        end

        Core.Invisibility.Character = nil
        if Core.Invisibility.Added then Core.Invisibility.Added:Disconnect(); Core.Invisibility.Added = nil end
        local frame = Core.Invisibility.Frame
        if frame then
            pcall(function() frame.Root.CFrame = frame.CFrame; frame.Humanoid.CameraOffset = frame.Offset end)
            Core.Invisibility.Frame = nil
        end
        for part, value in pairs(Core.Invisibility.Transparency) do pcall(function() part.Transparency = value end) end
        table.clear(Core.Invisibility.Transparency)
        local Character = LocalPlayer.Character
        setCharacterTransparency(Character, 0)


        if State.Settings.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(220,220,220)\">Invisibility</font> <font color=\"rgb(255,85,85)\">OFF</font>", CONFIG.Colors.Text)
        end
    end
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 17: KEYBIND SYSTEM
-- ══════════════════════════════════════════════════════════════════════════════

local function ClearKeybind(bindName, button)
    State.Settings.Keybinds[bindName] = Enum.KeyCode.Unknown
    button.Text = "Not Bound"

    local originalColor = button.BackgroundColor3
    Core.Tween(button, TweenInfo.new(0.15), {BackgroundColor3 = CONFIG.Colors.KeybindClear}):Play()
    task.wait(0.15)
    Core.Tween(button, TweenInfo.new(0.15), {BackgroundColor3 = originalColor}):Play()
end

local function SetKeybind(key, keyCode, button, callbacks)
    -- Проверка дубликатов
    for actionName, boundKey in pairs(State.Settings.Keybinds) do
        if boundKey == keyCode and actionName ~= key then
            State.Settings.Keybinds[actionName] = Enum.KeyCode.Unknown

            for _, element in pairs(State.Runtime.UIElements) do
                if element.Name == actionName .. "_Button" then
                    element.Text = "Not Bound"
                    break
                end
            end
        end
    end

    State.Settings.Keybinds[key] = keyCode
    button.Text = keyCode.Name
    State.Runtime.ListeningForKeybind = nil

    local originalColor = button.BackgroundColor3
    Core.Tween(button, TweenInfo.new(0.15), {BackgroundColor3 = CONFIG.Colors.Accent}):Play()
    task.wait(0.15)
    Core.Tween(button, TweenInfo.new(0.15), {BackgroundColor3 = originalColor}):Play()
end


-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 18: UTILITY FUNCTIONS
-- ══════════════════════════════════════════════════════════════════════════════

-- SetupAntiAFK() - VirtualUser:CaptureController()
local function SetupAntiAFK()
    local VirtualUser = game:GetService("VirtualUser")
    Core.Connect(LocalPlayer.Idled, function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    Core.Tasks.spawn(function()
        while Core.Alive do
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

-- ══════════════════════════════════════════════════════════════════════════════
-- REJOIN v2 — перезаход без вылета
-- ══════════════════════════════════════════════════════════════════════════════
-- Старая версия роняла клиент по двум причинам:
--   1) она ВСЕГДА через 2 секунды дожимала вторым Teleport() поверх первого,
--      ещё летящего TeleportToPlaceInstance — два телепорта одновременно
--      и есть тот самый краш;
--   2) она вызывалась прямо в потоке клика по кнопке и делала там task.wait.
-- Теперь: одна попытка за раз (single-flight), инстанс-перезаход только пока
-- соединение с сервером живо, фолбэк на обычный Teleport — исключительно после
-- реального отказа (TeleportInitFailed), а не по таймеру.
local function Rejoin()
    if State.Runtime.RejoinInProgress then return end
    State.Runtime.RejoinInProgress = true

    Core.Tasks.spawn(function()
        local failed = false
        local conn

        -- Единственный достоверный сигнал провала телепорта на клиенте.
        pcall(function()
            conn = Core.Connect(TeleportService.TeleportInitFailed, function(player)
                if player == LocalPlayer then failed = true end
            end)
        end)

        -- Если реплика уже отвалилась (кик/дисконнект), то заходить в тот же
        -- JobId бессмысленно — инстанс нас ещё держит, и телепорт зависает.
        local connectionAlive = false
        pcall(function()
            connectionAlive = game:GetService("NetworkClient")
                :FindFirstChildWhichIsA("ClientReplicator") ~= nil
        end)

        local jobId = game.JobId
        local instanceTried = false

        if connectionAlive and type(jobId) == "string" and jobId ~= "" then
            instanceTried = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
            end)

            -- Ждём вердикт. Если телепорт принят — этот тред умрёт вместе с
            -- клиентом, и дальше мы просто не дойдём.
            if instanceTried then
                local elapsed = 0
                while elapsed < CONFIG.ServerHop.TeleportTimeout and not failed do
                    task.wait(0.25)
                    elapsed += 0.25
                end
            end
        end

        -- Фолбэк: либо инстанс-перезаход не запускался, либо он явно отказал.
        if (not instanceTried) or failed then
            pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
            task.wait(CONFIG.ServerHop.TeleportTimeout)
        end

        if conn then pcall(function() conn:Disconnect() end) end
        State.Runtime.RejoinInProgress = false
    end)
end

local function ExecuteInf()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
end

local respawning = {}

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

    Core.Tasks.spawn(function()
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
Core.Connect(Players.PlayerRemoving, function(plr)
    respawning[plr.UserId] = nil
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- SERVER HOP v3
-- ══════════════════════════════════════════════════════════════════════════════
local function ServerHop()
    if State.Runtime.ServerHopInProgress then
        if State.Settings.NotificationsEnabled then
            ShowNotification(
                "<font color=\"rgb(255, 170, 50)\">ServerHop: </font><font color=\"rgb(220,220,220)\">Already searching...</font>",
                CONFIG.Colors.Text
            )
        end
        return
    end
    State.Runtime.ServerHopInProgress = true

    -- Сеть и ожидание телепорта не должны блокировать поток клика по кнопке.
    Core.Tasks.spawn(function()
        local SH = CONFIG.ServerHop
        local now = os.time()

        local function notify(color, text)
            if State.Settings.NotificationsEnabled then
                ShowNotification(
                    string.format("<font color=\"%s\">ServerHop: </font><font color=\"rgb(220,220,220)\">%s</font>", color, text),
                    CONFIG.Colors.Text
                )
            end
        end

        -- Файловое хранилище — общие LoadJSON/SaveJSON из шапки модуля

        -- ── История посещений: {jobId = timestamp}, протухает по времени ─────
        local visited = {}
        do
            local raw = Files.LoadJSON(SH.VisitedFile, {})
            local ordered = {}
            for jobId, stamp in pairs(raw) do
                if type(jobId) == "string" and type(stamp) == "number"
                    and (now - stamp) < SH.VisitedLifetime then
                    table.insert(ordered, { id = jobId, t = stamp })
                end
            end
            -- Свежие — вперёд, хвост сверх лимита выбрасываем, чтобы файл не рос.
            table.sort(ordered, function(a, b) return a.t > b.t end)
            for i = 1, math.min(#ordered, SH.VisitedLimit) do
                visited[ordered[i].id] = ordered[i].t
            end
        end

        local function SaveVisited()
            Files.SaveJSON(SH.VisitedFile, visited)
        end

        local function MarkVisited(jobId)
            if type(jobId) == "string" and jobId ~= "" then
                visited[jobId] = os.time()
                SaveVisited()
            end
        end

        -- Текущий сервер тоже в историю: иначе после хопа с нового сервера можно
        -- сразу прыгнуть обратно (пинг-понг A → B → A).
        MarkVisited(game.JobId)

        -- ── Получение списка серверов ────────────────────────────────────────
        local function FetchPage(cursor)
            local url = string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=%d",
                game.PlaceId,
                SH.FetchLimit
            )
            if cursor then url = url .. "&cursor=" .. cursor end

            local ok, result = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(url))
            end)
            if ok and type(result) == "table" then return result end
            return nil
        end

        local function FetchServers()
            local list, cursor, pages = {}, nil, 0
            repeat
                local page = FetchPage(cursor)
                if not page or type(page.data) ~= "table" then break end

                for _, srv in ipairs(page.data) do
                    if type(srv.id) == "string"
                        and type(srv.playing) == "number"
                        and type(srv.maxPlayers) == "number" then
                        table.insert(list, {
                            id = srv.id,
                            playing = srv.playing,
                            maxPlayers = srv.maxPlayers
                        })
                    end
                end

                cursor = page.nextPageCursor
                pages += 1
                task.wait(0.15)
            until (not cursor) or pages >= SH.MaxPages
            return list
        end

        -- ── Кэш списка серверов ──────────────────────────────────────────────
        local cache = Files.LoadJSON(SH.CacheFile, nil)
        local cacheValid = cache
            and cache.place == game.PlaceId
            and type(cache.servers) == "table"
            and #cache.servers > 0
            and (now - (tonumber(cache.timestamp) or 0)) < SH.CacheLifetime

        local servers
        if cacheValid then
            servers = cache.servers
        else
            servers = FetchServers()
            if #servers > 0 then
                Files.SaveJSON(SH.CacheFile, {
                    place = game.PlaceId,
                    timestamp = now,
                    servers = servers
                })
            elseif cache and cache.place == game.PlaceId and type(cache.servers) == "table" then
                -- API не ответил — лучше протухший список, чем ничего.
                servers = cache.servers
            end
        end

        if type(servers) ~= "table" or #servers == 0 then
            notify("rgb(255, 85, 85)", "Failed to fetch servers")
            State.Runtime.ServerHopInProgress = false
            return
        end

        -- ── Отбор кандидатов ─────────────────────────────────────────────────
        local function Score(playing, maxPlayers)
            local score = (1 - playing / maxPlayers) * 100
            if playing >= 2 and playing <= 6 then score = score + 50 end
            return score
        end

        local function Collect(skipVisited, strict)
            local out = {}
            for _, srv in ipairs(servers) do
                local pass = srv.id ~= game.JobId
                    and srv.playing > 0
                    and srv.playing < srv.maxPlayers

                if pass and skipVisited and visited[srv.id] then pass = false end
                if pass and strict then
                    pass = srv.playing >= SH.MinPlayers
                        and srv.playing < srv.maxPlayers * SH.MaxFillPercent
                end

                if pass then
                    table.insert(out, {
                        id = srv.id,
                        playing = srv.playing,
                        maxPlayers = srv.maxPlayers,
                        score = Score(srv.playing, srv.maxPlayers)
                    })
                end
            end
            return out
        end

        local candidates = Collect(true, true)
        if #candidates == 0 then candidates = Collect(true, false) end
        if #candidates == 0 then
            -- Все известные сервера посещены за последние VisitedLifetime секунд.
            -- Без сброса хоп встал бы намертво, поэтому историю чистим.
            visited = {}
            MarkVisited(game.JobId)
            candidates = Collect(true, true)
            if #candidates == 0 then candidates = Collect(true, false) end
        end

        if #candidates == 0 then
            notify("rgb(255, 85, 85)", "No suitable servers found")
            State.Runtime.ServerHopInProgress = false
            return
        end

        table.sort(candidates, function(a, b) return a.score > b.score end)

        -- ── Телепорт ─────────────────────────────────────────────────────────
        local failed = false
        local conn
        pcall(function()
            conn = Core.Connect(TeleportService.TeleportInitFailed, function(player)
                if player == LocalPlayer then failed = true end
            end)
        end)

        for attempt = 1, SH.TeleportRetry do
            if #candidates == 0 then break end

            -- Случайный из топа — чтобы все клиенты не сваливались в один сервер.
            local target = table.remove(candidates, math.random(1, math.min(SH.TopPick, #candidates)))
            if not target then break end

            -- Пишем ДО телепорта: после успешного телепорта код уже не отработает.
            MarkVisited(target.id)

            notify("rgb(85, 255, 120)", string.format(
                "Joining %d/%d players (Score: %.0f)",
                target.playing, target.maxPlayers, target.score
            ))

            failed = false
            local started = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, LocalPlayer)
            end)

            if started then
                local elapsed = 0
                while elapsed < SH.TeleportTimeout and not failed do
                    task.wait(0.25)
                    elapsed += 0.25
                end
                -- Отказа не было: телепорт принят. Второй телепорт поверх первого
                -- — ровно та причина вылетов, из-за которой всё это переписывалось.
                if not failed then break end
            end

            -- Явный отказ: сервер умер/полон. Список серверов протух — сбрасываем
            -- кэш, чтобы следующий хоп сходил в API заново.
            Files.SaveJSON(SH.CacheFile, { place = game.PlaceId, timestamp = 0, servers = {} })
            task.wait(1)
        end

        if conn then pcall(function() conn:Disconnect() end) end

        if failed then
            notify("rgb(255, 85, 85)", "Teleport failed, try again")
        end
        State.Runtime.ServerHopInProgress = false
    end)
end

local function ServerLagger()
    if State.Settings.NotificationsEnabled then
        ShowNotification(
            "<font color=\"rgb(255, 85, 85)\">Server Lagger: </font><font color=\"rgb(220,220,220)\">Success</font>",
            CONFIG.Colors.Text
        )
    end
    local syncRF   = ReplicatedStorage:FindFirstChild("GetSyncData")
    local heavyRFs = {
        ReplicatedStorage:FindFirstChild("GetData2",      true),
        ReplicatedStorage:FindFirstChild("GetProfileData", true),
        ReplicatedStorage:FindFirstChild("SearchSongs",    true),
    }

    local function spawnLoop(rf)
        if not rf then return end
        Core.Tasks.spawn(function()
            while true do
                Core.Tasks.spawn(function()
                    pcall(function() rf:InvokeServer() end)
                end)
                task.wait()
            end
        end)
    end

    -- GetSyncData: 3 параллельных spawner'а (тяжёлый handler)
    spawnLoop(syncRF)
    spawnLoop(syncRF)
    spawnLoop(syncRF)

    -- Тяжёлые по байтам: по одному spawner'у
    for _, rf in ipairs(heavyRFs) do
        spawnLoop(rf)
    end
end

local function SpeedGlitch()
    local player = Players.LocalPlayer
    player.Character:WaitForChild('Humanoid')
    task.wait(0.1)

    -- Проверка с новым именем
    if player.Backpack:FindFirstChild("SpeedGlitchTool") or player.Character:FindFirstChild("SpeedGlitchTool") then
        if State.Settings.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">already given!</font>", CONFIG.Colors.Text)
        end
        return
    end

    do
        local tool = Core.New('Tool')
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

        local child1 = Core.New('Part')
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

        local child2 = Core.New('SpecialMesh')
        child2.Name = "Mesh"
        child2.Scale = Vector3.new(0.5, 1.2000000476837158, 0.5)
        child2.MeshType = Enum.MeshType.Head
        child2.Offset = Vector3.new(0, 0, 0)
        child2.Parent = child1

        local child4 = Core.New('Part')
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

        local child5 = Core.New('BlockMesh')
        child5.Name = "Mesh"
        child5.Parent = child4

        -- DECALS УДАЛЕНЫ - больше не видны

        child4.Parent = child1
        child1.Parent = tool

        local weld = Core.New('Weld')
        weld.Name = "HandleToSign"
        weld.Part0 = child1
        weld.Part1 = child4
        weld.C0 = CFrame.new(0, 3.75, 0)
        weld.C1 = CFrame.new(0, 0, 0)
        weld.Parent = child1

        tool.Parent = player.Backpack

        if State.Settings.NotificationsEnabled then
            ShowNotification("<font color=\"rgb(168,228,160)\">Success: </font><font color=\"rgb(220,220,220)\">Speed Glitch tool given!</font>", CONFIG.Colors.Text)
        end
    end
end


-- СНАЧАЛА объявляем функции
local function HandleEmoteInput(input)
    if input.KeyCode == State.Settings.Keybinds.Sit and State.Settings.Keybinds.Sit ~= Enum.KeyCode.Unknown then
        PlayEmote("sit")
    elseif input.KeyCode == State.Settings.Keybinds.Dab and State.Settings.Keybinds.Dab ~= Enum.KeyCode.Unknown then
        PlayEmote("dab")
    elseif input.KeyCode == State.Settings.Keybinds.Zen and State.Settings.Keybinds.Zen ~= Enum.KeyCode.Unknown then
        PlayEmote("zen")
    elseif input.KeyCode == State.Settings.Keybinds.Ninja and State.Settings.Keybinds.Ninja ~= Enum.KeyCode.Unknown then
        PlayEmote("ninja")
    elseif input.KeyCode == State.Settings.Keybinds.Floss and State.Settings.Keybinds.Floss ~= Enum.KeyCode.Unknown then
        PlayEmote("floss")
    end
end

local function HandleActionInput(input)
    if input.KeyCode == State.Settings.Keybinds.knifeThrow and State.Settings.Keybinds.knifeThrow ~= Enum.KeyCode.Unknown then
        pcall(function() knifeThrow(true) end)
    end

    if input.KeyCode == State.Settings.Keybinds.InstantKillAll and State.Settings.Keybinds.InstantKillAll ~= Enum.KeyCode.Unknown then
        pcall(function() InstantKillAll() end)
    end

    if input.KeyCode == State.Settings.Keybinds.ShootMurderer and State.Settings.Keybinds.ShootMurderer ~= Enum.KeyCode.Unknown then
        pcall(function() shootMurderer(false, "Silent") end)
    end

    if input.KeyCode == State.Settings.Keybinds.Wallbang and State.Settings.Keybinds.Wallbang ~= Enum.KeyCode.Unknown then
        pcall(function() shootMurderer(false, "Magic") end)
    end

    if input.KeyCode == State.Settings.Keybinds.PickupGun and State.Settings.Keybinds.PickupGun ~= Enum.KeyCode.Unknown then
        pcall(function() pickupGun() end)
    end

    if input.KeyCode == State.Settings.Keybinds.ClickTP and State.Settings.Keybinds.ClickTP ~= Enum.KeyCode.Unknown then
        State.Runtime.ClickTPActive = true
    end

    if input.KeyCode == State.Settings.Keybinds.FlingPlayer and State.Settings.Keybinds.FlingPlayer ~= Enum.KeyCode.Unknown then
        if State.Runtime.SelectedPlayerForFling then
            local targetPlayer = getPlayerByName(State.Runtime.SelectedPlayerForFling)
            if targetPlayer and targetPlayer.Character then
                pcall(function() FlingPlayer(targetPlayer) end)
            end
        end
    end

    -- Speed / Fly: в режиме Toggle бинд переключает тогл; Hold проверяется каждый кадр
    State.Runtime.OnMovementBind(input)

    if State.Runtime.MovementModule then State.Runtime.MovementModule.OnInput(input) end

    if input.KeyCode == State.Settings.Keybinds.NoClip and State.Settings.Keybinds.NoClip ~= Enum.KeyCode.Unknown then
        if State.Settings.NoClipEnabled then
            DisableNoClip()
        else
            EnableNoClip()
        end
    end

    if input.KeyCode == State.Settings.Keybinds.Invisibility and State.Settings.Keybinds.Invisibility ~= Enum.KeyCode.Unknown then
        pcall(function() ToggleInvisibility() end)
    end

    if input.KeyCode == State.Settings.Keybinds.KillAura and State.Settings.Keybinds.KillAura ~= Enum.KeyCode.Unknown then
        pcall(function()
            if State.Settings.KillAuraEnabled then
                ToggleKillAura(false)
            else
                if getMurder() ~= LocalPlayer then
                    if State.Settings.NotificationsEnabled then
                        ShowNotification("<font color=\"rgb(255, 85, 85)\">Error: </font><font color=\"rgb(220,220,220)\">You are not the murderer</font>", CONFIG.Colors.Text)
                    end
                    State.Settings.KillAuraEnabled = false
                    return
                end
                ToggleKillAura(true)
            end
        end)
    end
end

-- Auto Rejoin on Disconnect
local function HandleAutoRejoin(enabled)
    State.Settings.AutoRejoinEnabled = enabled
    if Core.AutoRejoinTask then pcall(task.cancel, Core.AutoRejoinTask); Core.AutoRejoinTask = nil end

    -- Пересоздаём коннект с нуля: без этого повторное включение тумблера
    -- вешало второй ChildAdded и Rejoin вызывался дважды на один ErrorPrompt.
    if Core.AutoRejoinConnection then
        pcall(function() Core.AutoRejoinConnection:Disconnect() end)
        Core.AutoRejoinConnection = nil
    end

    if not enabled then return end

    Core.AutoRejoinTask = Core.Tasks.spawn(function()
        local promptGui
        local waited = 0
        -- Ограниченное ожидание: на части executor'ов RobloxPromptGui нет вовсе,
        -- и бесконечный repeat висел бы в памяти до конца сессии.
        repeat
            promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
            if promptGui then break end
            task.wait(0.25)
            waited += 0.25
        until waited >= 30

        if not Core.Alive or not State.Settings.AutoRejoinEnabled then return end
        local overlay = promptGui and promptGui:FindFirstChild("promptOverlay")
        if not overlay then
            warn("[Auto Rejoin] RobloxPromptGui не найден — автореджойн недоступен")
            return
        end

        local connection = Core.Connect(overlay.ChildAdded, function(prompt)
            if State.Settings.AutoRejoinEnabled and prompt.Name == "ErrorPrompt" then
                task.wait(0.5)
                Rejoin() -- сам разберётся: соединение мертво → обычный Teleport
            end
        end)

        Core.AutoRejoinConnection = connection
        TrackConnection(connection)
    end)
end

local DEFAULT_INTERVAL = 25 * 60

-- Функция для установки интервала
local function SetReconnectInterval(minutes)
    local mins = tonumber(minutes) or 25
    State.Settings.ReconnectInterval = math.max(1, mins) * 60
    print(string.format("[Auto Reconnect] Interval: %d min (%d sec)", mins, State.Settings.ReconnectInterval))
end

local function HandleAutoReconnect(enabled)
    if State.Runtime.ReconnectThread then pcall(task.cancel, State.Runtime.ReconnectThread); State.Runtime.ReconnectThread = nil end
    State.Settings.AutoReconnectEnabled = enabled

    if enabled then

        State.Runtime.ReconnectThread = Core.Tasks.spawn(function()
            local elapsed = 0

            while State.Settings.AutoReconnectEnabled do
                task.wait(1)
                elapsed += 1

                if elapsed >= (State.Settings.ReconnectInterval or DEFAULT_INTERVAL) then
                    Rejoin()
                    return
                end
            end
        end)
    else
        if State.Runtime.ReconnectThread then
            -- Тред мог уже завершиться сам — task.cancel по мёртвому треду кидает.
            pcall(function() task.cancel(State.Runtime.ReconnectThread) end)
            State.Runtime.ReconnectThread = nil
        end
    end
end
-- ══════════════════════════════════════════════════════════════════════════════
-- СВОДКА СЕССИИ (инфо-блок в сайдбаре GUI)
-- ══════════════════════════════════════════════════════════════════════════════

State.Runtime.Session = {
    Version    = "2.2",
    -- База (StartCoins + StartedAt) НЕ ставится при загрузке: счётчик монет в
    -- шопе догружается/дощёлкивает с нуля, и раннее чтение дало бы ложную базу,
    -- из-за которой Coins/h подскакивал. База фиксируется в EnsureBaseline, когда
    -- баланс стабилизировался. Включение автофарма делает сброс (MarkFarmStart).
    StartedAt  = nil,
    StartCoins = nil,
    _pending   = nil,   -- кандидат в базу, ждём стабилизации
}

-- Разделитель тысяч: 26292 → 26,292
function State.Runtime.Session.FormatThousands(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

-- Баланс монет аккаунта. Витрина шопа существует и когда шоп закрыт.
-- Только читает значение, базу не трогает.
function State.Runtime.Session.ReadCoins()
    local ok, value = pcall(function()
        local label = LocalPlayer.PlayerGui
            .CrossPlatform.Shop.Medium.Title.Coins.Container.Amount
        return tonumber((tostring(label.Text):gsub(",", "")))
    end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

-- База фиксируется, только когда баланс совпал в двух чтениях подряд — то есть
-- данные догрузились и счётчик перестал дощёлкивать. Так загрузка/анимация не
-- засчитывается в фарм. StartedAt стартует тем же моментом, что и StartCoins.
function State.Runtime.Session.EnsureBaseline(coins)
    if State.Runtime.Session.StartCoins then return end
    if State.Runtime.Session._pending == coins then
        State.Runtime.Session.StartCoins = coins
        State.Runtime.Session.StartedAt = tick()
        State.Runtime.Session._pending = nil
    else
        State.Runtime.Session._pending = coins
    end
end

-- Сброс сессии: точка отсчёта Coins/h переезжает на текущий момент.
-- Вызывается при включении автофарма (монеты к этому времени уже загружены)
function State.Runtime.Session.MarkFarmStart()
    State.Runtime.Session.StartedAt = tick()
    State.Runtime.Session.StartCoins = State.Runtime.Session.ReadCoins() or 0
    State.Runtime.Session._pending = nil
end

function State.Runtime.Session.GetCoinsText()
    local coins = State.Runtime.Session.ReadCoins()
    if not coins then return nil end
    return State.Runtime.Session.FormatThousands(coins)
end

function State.Runtime.Session.GetRateText()
    local coins = State.Runtime.Session.ReadCoins()
    if not coins then return nil end           -- монеты ещё не загрузились
    State.Runtime.Session.EnsureBaseline(coins)
    if not State.Runtime.Session.StartCoins then return "—" end   -- база стабилизируется
    -- Защита от ложной базы. Витрина шопа при загрузке отдаёт placeholder-баланс
    -- (напр. ~43k), который держится пару чтений подряд и попадает в базу. Когда
    -- подгружается реальный (меньший) баланс, gained уходит в минус и Coins/h
    -- скатывается в -2kk/ч. Любое падение баланса ниже базы = база была ложной
    -- (либо игрок реально потратил монеты) — пересобираем базу от текущего
    -- значения и начинаем отсчёт заново.
    if coins < State.Runtime.Session.StartCoins then
        State.Runtime.Session.StartCoins = coins
        State.Runtime.Session.StartedAt = tick()
        return State.Runtime.Session.FormatThousands(0)
    end
    -- Считаем сразу: до первой монеты gained = 0 → показываем 0, с первой
    -- монетой пошёл счёт. Знаменатель зажат снизу до 1с, чтобы не делить на ~0.
    local hours = (tick() - State.Runtime.Session.StartedAt) / 3600
    if hours < (1 / 3600) then hours = 1 / 3600 end
    local gained = coins - State.Runtime.Session.StartCoins
    return State.Runtime.Session.FormatThousands(gained / hours)
end

-- Роль: сперва серверные данные, затем предмет в руках/рюкзаке
function State.Runtime.Session.GetRole()
    local name = LocalPlayer and LocalPlayer.Name
    if name and State.Cache.PlayerData then
        local data = State.Cache.PlayerData[name]
        if data and type(data.Role) == "string" and data.Role ~= "" then
            return data.Role
        end
    end
    local ok, role = pcall(function()
        local char = LocalPlayer.Character
        local bp = LocalPlayer:FindFirstChild("Backpack")
        local function has(item)
            return (char and char:FindFirstChild(item) ~= nil)
                or (bp and bp:FindFirstChild(item) ~= nil)
        end
        if has("Knife") then return "Murderer" end
        if has("Gun") then return "Sheriff" end
        return "Innocent"
    end)
    if ok then return role end
    return nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК: FAKE COSMETICS (HEADLESS & KORBLOX)
-- ══════════════════════════════════════════════════════════════════════════════

do
    local KORBLOX_RIGHT_LEG_ID = 139607718

    local FakeCosmetics = {
        hl = nil,
        kb = nil,
        Remote = {},   -- [Player] = {Player, Data, Headless, Korblox, Connection}
    }

    -- Headless на любом персонаже: прячем голову и её декали, помним исходную прозрачность.
    -- Catalog может подменить Head динамической головой — прячем и новую
    local function startHeadless(character)
        local hl = { Character = character, Hidden = {}, Connections = {}, Alive = true }
        local function hideObject(item)
            if hl.Hidden[item] == nil then hl.Hidden[item] = item.Transparency end
            pcall(function() item.Transparency = 1 end)
        end
        local function hideHead(head)
            if not head:IsA("BasePart") then return end
            hideObject(head)
            for _, desc in ipairs(head:GetDescendants()) do
                if desc:IsA("Decal") then hideObject(desc) end
            end
            table.insert(hl.Connections, Core.Connect(head.DescendantAdded, function(desc)
                if hl.Alive and desc:IsA("Decal") then hideObject(desc) end
            end))
        end
        function hl.Cleanup()
            if not hl.Alive then return end
            hl.Alive = false
            for _, connection in ipairs(hl.Connections) do connection:Disconnect() end
            table.clear(hl.Connections)
            for item, transparency in pairs(hl.Hidden) do
                if item.Parent then pcall(function() item.Transparency = transparency end) end
            end
            table.clear(hl.Hidden)
        end
        local head = character:FindFirstChild("Head")
        if head then hideHead(head) end
        -- Лицо классической головы бывает вне Head (старые риги) — как и раньше, по имени
        for _, desc in ipairs(character:GetDescendants()) do
            if desc:IsA("Decal") and desc.Name == "face" then hideObject(desc) end
        end
        table.insert(hl.Connections, Core.Connect(character.ChildAdded, function(child)
            if hl.Alive and child.Name == "Head" then hideHead(child) end
        end))
        table.insert(hl.Connections, Core.Connect(character.Destroying, hl.Cleanup))
        return hl
    end

    -- Нога Korblox на любом R15-персонаже; onCleanup — чтобы владелец забыл ссылку
    local function startKorblox(character, onCleanup)
        local kb = { Character = character, Connections = {}, Hidden = {}, Revision = 0, Alive = true }
        local function restoreParts()
            for part, transparency in pairs(kb.Hidden) do
                if part.Parent then pcall(function() part.Transparency = transparency end) end
            end
            table.clear(kb.Hidden)
        end
        function kb.Cleanup()
            if not kb.Alive then return end
            kb.Alive = false
            kb.Revision += 1
            for _, connection in ipairs(kb.Connections) do connection:Disconnect() end
            table.clear(kb.Connections)
            if kb.Visual then kb.Visual:Destroy(); kb.Visual = nil end
            restoreParts()
            if onCleanup then onCleanup(kb) end
        end
        local function connect(signal, callback)
            table.insert(kb.Connections, Core.Connect(signal, callback))
        end
        local function build(revision)
            local donor, description, source, visual
            local ok, err = pcall(function()
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local upper = character:FindFirstChild("RightUpperLeg")
                if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 or not upper then return end
                local hip = upper:FindFirstChild("RightHipRigAttachment")
                if not hip then return end

                -- Roblox рассчитывает геометрию и крепление для конкретного тела и его масштабов.
                source = humanoid:GetAppliedDescription()
                description = Core.New("HumanoidDescription")
                for _, name in ipairs({"Head", "Torso", "LeftArm", "RightArm", "LeftLeg",
                    "HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale"}) do
                    description[name] = source[name]
                end
                for valueName, field in pairs({BodyHeightScale = "HeightScale", BodyWidthScale = "WidthScale",
                    BodyDepthScale = "DepthScale", HeadScale = "HeadScale", BodyTypeScale = "BodyTypeScale",
                    BodyProportionScale = "ProportionScale"}) do
                    local value = humanoid:FindFirstChild(valueName)
                    if value and value:IsA("NumberValue") then description[field] = value.Value end
                end
                description.RightLeg = KORBLOX_RIGHT_LEG_ID
                description.RightLegColor = source.RightLegColor
                donor = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
                if not kb.Alive or kb.Revision ~= revision or upper.Parent ~= character then return end
                local leg = donor:FindFirstChild("RightUpperLeg")
                local donorHip = leg and leg:FindFirstChild("RightHipRigAttachment")
                if not leg or not donorHip then error("Korblox model has no right hip attachment") end

                -- Отдельная визуальная нога сохраняет исходный риг, анимации и физику персонажа.
                visual = Core.Own(leg:Clone())
                visual.Name = "FakeKorbloxVisual"
                for _, child in ipairs(visual:QueryDescendants("JointInstance,WeldConstraint,LuaSourceContainer")) do child:Destroy() end
                visual.Anchored = false
                visual.Massless = true
                visual.CanCollide, visual.CanTouch, visual.CanQuery = false, false, false
                local offset = hip.CFrame * donorHip.CFrame:Inverse()
                visual.CFrame = upper.CFrame * offset
                local weld = Core.New("Weld")
                weld.Name = "FakeKorbloxWeld"
                weld.Part0, weld.Part1, weld.C0 = upper, visual, offset
                weld.Parent = visual
                if kb.Visual then kb.Visual:Destroy() end
                restoreParts()
                kb.Visual = visual
                visual.Parent = character
                for _, name in ipairs({"RightUpperLeg", "RightLowerLeg", "RightFoot"}) do
                    local part = character:FindFirstChild(name)
                    if part and part:IsA("BasePart") then
                        kb.Hidden[part] = part.Transparency
                        part.Transparency = 1
                    end
                end
                visual = nil
            end)
            if visual then visual:Destroy() end
            if donor then donor:Destroy() end
            if description then description:Destroy() end
            if source then source:Destroy() end
            if not ok and kb.Alive and kb.Revision == revision then
                warn("[Fake Korblox] " .. tostring(err))
            end
        end
        local function schedule()
            if not kb.Alive then return end
            kb.Revision += 1
            if kb.Pending then return end
            kb.Pending = true
            Core.Tasks.spawn(function()
                -- Объединяем изменения частей и масштабов при применении образа в одну сборку.
                repeat
                    local revision = kb.Revision
                    task.wait(0.2)
                    if not kb.Alive then break end
                    if revision == kb.Revision then build(revision) end
                until not kb.Alive or revision == kb.Revision
                kb.Pending = false
            end)
        end
        local watched = setmetatable({}, { __mode = "k" })
        local function watch(item)
            if watched[item] then return end
            watched[item] = true
            if item:IsA("Humanoid") then
                connect(item.ApplyDescriptionFinished, schedule)
            elseif item:IsA("NumberValue") and item.Parent and item.Parent:IsA("Humanoid") then
                connect(item.Changed, schedule)
            elseif item:IsA("BasePart") and (item.Name == "RightUpperLeg" or item.Name == "LowerTorso") then
                connect(item:GetPropertyChangedSignal("Size"), schedule)
            elseif item:IsA("Attachment") and item.Name == "RightHipRigAttachment" and item.Parent.Name == "RightUpperLeg" then
                connect(item:GetPropertyChangedSignal("CFrame"), schedule)
            end
        end
        for _, item in ipairs(character:QueryDescendants("Humanoid,NumberValue,BasePart,Attachment")) do watch(item) end
        connect(character.DescendantAdded, function(item)
            if item.Name == "FakeKorbloxVisual" or (kb.Visual and item:IsDescendantOf(kb.Visual)) then return end
            watch(item)
            if item.Name == "RightUpperLeg" or item.Name == "RightHipRigAttachment" or item:IsA("Humanoid") then schedule() end
        end)
        connect(character.ChildRemoved, function(item)
            if item.Name == "RightUpperLeg" then
                if kb.Visual then kb.Visual:Destroy(); kb.Visual = nil end
                restoreParts()
                schedule()
            end
        end)
        connect(character.Destroying, kb.Cleanup)
        schedule()
        return kb
    end

    local function ApplyFakeHeadless(enabled, character)
        character = character or LocalPlayer.Character
        if not enabled then
            if FakeCosmetics.hl then FakeCosmetics.hl.Cleanup(); FakeCosmetics.hl = nil end
            return
        end

        if not character then return end
        local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 2)
        if not head then return end

        if FakeCosmetics.hl and FakeCosmetics.hl.Alive and FakeCosmetics.hl.Character == character then
            return
        end
        if FakeCosmetics.hl then FakeCosmetics.hl.Cleanup() end
        FakeCosmetics.hl = startHeadless(character)
    end

    local function ApplyFakeKorblox(enabled, character)
        local previous = FakeCosmetics.kb
        if not enabled then
            if previous then previous.Cleanup() end
            return
        end
        character = character or LocalPlayer.Character
        if not character then return end
        if previous and previous.Character == character then return end
        if previous then previous.Cleanup() end
        FakeCosmetics.kb = startKorblox(character, function(kb)
            if FakeCosmetics.kb == kb then FakeCosmetics.kb = nil end
        end)
    end

    -- Синхронизация с пользователями скрипта: skinchanger приносит через relay {h, k}
    -- чужого игрока и зовёт провайдер cosmetics. Вешаем то же самое на его персонажа
    local function clearRemote(player)
        local entry = FakeCosmetics.Remote[player]
        if not entry then return end
        FakeCosmetics.Remote[player] = nil
        if entry.Connection then entry.Connection:Disconnect() end
        if entry.Headless then entry.Headless.Cleanup() end
        if entry.Korblox then entry.Korblox.Cleanup() end
    end

    local function dressRemote(entry)
        if FakeCosmetics.Remote[entry.Player] ~= entry then return end
        local character = entry.Player.Character
        local hl, kb = entry.Headless, entry.Korblox
        if hl and (not hl.Alive or hl.Character ~= character or not entry.Data.h) then hl.Cleanup(); entry.Headless = nil end
        if kb and (not kb.Alive or kb.Character ~= character or not entry.Data.k) then kb.Cleanup(); entry.Korblox = nil end
        if not character or not character.Parent then return end
        if entry.Data.h and not entry.Headless then entry.Headless = startHeadless(character) end
        if entry.Data.k and not entry.Korblox then entry.Korblox = startKorblox(character) end
    end

    local function applyRemote(player, data)
        if typeof(player) ~= "Instance" or not player:IsA("Player") or player == LocalPlayer then return end
        local headless = type(data) == "table" and data.h == true
        local korblox = type(data) == "table" and data.k == true
        if not headless and not korblox then clearRemote(player); return end
        local entry = FakeCosmetics.Remote[player]
        if not entry then
            entry = { Player = player }
            FakeCosmetics.Remote[player] = entry
            entry.Connection = Core.Connect(player.CharacterAdded, function()
                task.defer(dressRemote, entry)
            end)
        end
        entry.Data = { h = headless, k = korblox }
        dressRemote(entry)
    end

    local lookProvider = {
        Export = function()
            local headless, korblox = State.Settings.FakeHeadless == true, State.Settings.FakeKorblox == true
            return (headless or korblox) and { h = headless, k = korblox } or nil
        end,
        Apply = applyRemote,
    }
    pcall(function()
        local env = getgenv()
        env.LookSync = env.LookSync or { Providers = {} }
        env.LookSync.Providers.cosmetics = lookProvider
    end)
    Core.Connect(Players.PlayerRemoving, clearRemote)

    local function StopLookSync()
        pcall(function()
            local registry = getgenv().LookSync
            if registry and registry.Providers.cosmetics == lookProvider then registry.Providers.cosmetics = nil end
        end)
        local players = {}
        for player in pairs(FakeCosmetics.Remote) do players[#players + 1] = player end
        for _, player in ipairs(players) do clearRemote(player) end
    end

    State.Runtime.ApplyFakeHeadless = ApplyFakeHeadless
    State.Runtime.ApplyFakeKorblox = ApplyFakeKorblox
    State.Runtime.StopLookSync = StopLookSync
end

-- Все функции уже объявлены: ошибка одной системы не пропускает остальные.
Core.StopFeatures = function()
    State.Settings.NotificationsEnabled = false
    for _, entry in ipairs({
        {"Invisibility", function() if State.Settings.IsInvisible then ToggleInvisibility() end end},
        {"Aimbot", function() Core.Aimbot.SetEnabled(false) end},
        {"AutoFarm", StopAutoFarm}, {"XP Farm", StopXPFarm},
        {"WalkFling", function() WalkFlingStop(false) end},
        {"Fling", State.Runtime.FlingCleanup},
        {"Fly", function() State.Settings.FlyToggleOn = false; State.Settings.FlyBindMode = "Toggle"; StopFly(true) end},
        {"Speed", function() State.Settings.SpeedEnabled = false; State.Settings.SpeedBindMode = "Toggle" end},
        {"AspectRatio", function() Core.Movement.SetAspectRatio(false, true) end},
        {"NoClip", DisableNoClip}, {"AntiFling", DisableAntiFling},
        {"Hitbox", DisableExtendedHitbox}, {"Pickup", DisableInstantPickup},
        {"VelocitySpoof", function() State.Runtime.SetVelocitySpoof(false) end},
        {"KillAura", function() ToggleKillAura(false) end},
        {"AutoFire", function() State.Runtime.SheriffAim.SetAutoFire(false) end},
        {"CoinMuter", StopCoinMuter}, {"FriendViewer", StopFriendViewer},
        {"AntiTrap", function() State.Runtime.SetAntiTrap(false) end},
        {"BulletTracers", function() ToggleBulletTracers(false) end},
        {"CoinTracer", RemoveCoinTracer},
        {"Headless", function() State.Runtime.ApplyFakeHeadless(false) end},
        {"Korblox", function() State.Runtime.ApplyFakeKorblox(false) end},
        {"LookSync", function() if State.Runtime.StopLookSync then State.Runtime.StopLookSync() end end},
        {"UI optimization", Core.Movement.DisableUIOnly},
    }) do
        Core.Try(entry[1], entry[2])
    end
end

local GUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Yany1944/rbxmain/refs/heads/main/Libraryes/GUI.lua"))()({
    CONFIG = CONFIG,
    State = State,
    Players = Players,
    CoreGui = CoreGui,
    TweenService = TweenService,
    UserInputService = UserInputService,
    LocalPlayer = LocalPlayer,
    TrackConnection = Core.Track,
    Tasks = Core.Tasks,
    SyncControls = function() if Core.SyncControls then Core.SyncControls() end end,
    ShowNotification = ShowNotification,
    Handlers = setmetatable({
        -- Character
        ApplyJumpPower = Core.Movement.ApplyJumpPower,
        ApplyMaxCameraZoom = Core.Movement.ApplyMaxCameraZoom,
        ApplyFOV = function(v) pcall(function() Core.Movement.ApplyFOV(v) end) end,
        AspectRatio = function(on) Core.Movement.SetAspectRatio(on) end,
        AspectRatioValue = function(v) Core.Movement.SetAspectRatioValue(v) end,
        SpeedValue = function(v)
            local range = CONFIG.Speed.Range
            State.Settings.SpeedValue = math.clamp(tonumber(v) or 0, range[1], range[2])
        end,
        SpeedBindMode = function(v) State.Runtime.SetBindMode("Speed", v) end,
        ViewClip = function(on) if on then Core.Movement.EnableViewClip() else Core.Movement.DisableViewClip() end end,

        -- Cosmetics
        -- Копия Spin Local Too клонирует части с их видом — после смены косметики пересобираем
        FakeHeadless = function(on)
            State.Settings.FakeHeadless = on
            if State.Runtime.ApplyFakeHeadless then State.Runtime.ApplyFakeHeadless(on) end
            if State.Runtime.RefreshLocalSpin then State.Runtime.RefreshLocalSpin() end
        end,
        FakeKorblox = function(on)
            State.Settings.FakeKorblox = on
            if State.Runtime.ApplyFakeKorblox then State.Runtime.ApplyFakeKorblox(on) end
            if State.Runtime.RefreshLocalSpin then State.Runtime.RefreshLocalSpin() end
        end,

        -- Notifications toggle
        NotificationsEnabled = function(on) State.Settings.NotificationsEnabled = on end,

        -- Avatar Display toggle (фоновая логика обновления аватаров не зависит от этого флага)
        AvatarDisplayEnabled = function(on)
            State.Settings.AvatarDisplayEnabled = on
            SetAvatarDisplayVisibility(on)
        end,

        -- ESP
        GunESP = function(on) State.Settings.GunESP = on UpdateGunESPVisibility() UpdateTrapESPVisibility() end,
        PlayerNicknamesESP = function(on)
        State.Settings.PlayerNicknamesESP = on
        if on then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    CreatePlayerNicknameESP(player)
                end
            end
        else
            -- Удаляем все ESP при выключении
            for player, _ in pairs(State.Cache.PlayerNicknamesCache) do
                RemovePlayerNicknameESP(player)
            end
        end

        UpdatePlayerNicknamesVisibility()
    end,
        MurderESP = function(on) State.Settings.MurderESP = on end,
        SheriffESP = function(on) State.Settings.SheriffESP = on end,
        InnocentESP = function(on) State.Settings.InnocentESP = on end,


        -- Visuals
        UIOnly = function(on) State.Settings.UIOnlyEnabled = on if on then Core.Movement.EnableUIOnly() else Core.Movement.DisableUIOnly() end end,
        BulletTracers = ToggleBulletTracers,
        FriendViewer = function(on) if on then StartFriendViewer() else StopFriendViewer() end end,
        CoinMuter = function(on) if on then StartCoinMuter() else StopCoinMuter() end end,

        -- Combat
        PingChams = function(on) State.Settings.PingChamsEnabled = on if on then StartPingChams() else StopPingChams() end end,
        PingChamsShowLabel = function(on)
            State.Settings.PingChamsShowLabel = on
            if State.Runtime.PingChamsGUI then
                State.Runtime.PingChamsGUI.Enabled = on and (State.Runtime.PingChamsTextTransparency or 1) < 0.995
            end
        end,
        FakePosition = function(on) Fling.ForgetFakePositionPause() State.Runtime.SetFakePosition(on) end,
        FakePositionMode = function(v)
            if table.find(CONFIG.Desync.Modes, v) then State.Settings.FakePositionMode = v end
        end,
        FakePositionRadius = function(v) State.Settings.FakePositionRadius = math.clamp(tonumber(v) or 3, CONFIG.Desync.Radius[1], CONFIG.Desync.Radius[2]) end,
        FakePositionPitch = function(v) if CONFIG.Desync.Pitches[v] then State.Settings.FakePositionPitch = v end end,
        FakeSpinLocal = function(on) State.Settings.FakeSpinLocal = on end,
        FakeSpinSpeed = function(v) State.Settings.FakeSpinSpeed = math.clamp(tonumber(v) or 720, CONFIG.Desync.SpinSpeed[1], CONFIG.Desync.SpinSpeed[2]) end,
        FakeLag = function(on) State.Runtime.SetFakeLag(on) end,
        FakeLagMinDelay = function(v) State.Settings.FakeLagMinDelay = math.clamp(tonumber(v) or 80, CONFIG.FakeLag.MinDelay[1], CONFIG.FakeLag.MinDelay[2]) end,
        FakeLagMaxDelay = function(v) State.Settings.FakeLagMaxDelay = math.clamp(tonumber(v) or 200, CONFIG.FakeLag.MaxDelay[1], CONFIG.FakeLag.MaxDelay[2]) end,
        FakeLagRandomization = function(v) State.Settings.FakeLagRandomization = math.clamp(tonumber(v) or 3, CONFIG.FakeLag.Randomization[1], CONFIG.FakeLag.Randomization[2]) end,
        ExtendedHitbox = function(on) if on then EnableExtendedHitbox() else DisableExtendedHitbox() end end,
        ExtendedHitboxSize = function(v) State.Settings.ExtendedHitboxSize = v if State.Settings.ExtendedHitboxEnabled then UpdateHitboxSize(v) end end,
        VelocitySpoof = function(on) State.Runtime.SetVelocitySpoof(on) end,
        VelocitySpoofMode = function(v) if v == "Anti-Aim" or v == "Zero" then State.Settings.VelocitySpoofMode = v end end,
        VelocitySpoofMurdererOnly = function(on) State.Settings.VelocitySpoofMurdererOnly = on end,
        VelocitySpoofStrength = function(v) State.Settings.VelocitySpoofStrength = math.clamp(tonumber(v) or 150, 20, 500) end,
        VelocitySpoofSpeed = function(v) State.Settings.VelocitySpoofSpeed = math.clamp(tonumber(v) or CONFIG.DefaultWalkSpeed, 0, 20) end,
        SpawnAtPlayer = function(on) State.Settings.SpawnAtPlayer = on end,
        AutoFire = function(on) State.Runtime.SheriffAim.SetAutoFire(on) end,
        Resolver = function(on) State.Runtime.SheriffAim.SetResolver(on) end,
        KillAuraRange = function(v) State.Settings.KillAuraRange = v end,
        KillAuraStatic = function(on)
            State.Settings.KillAuraStatic = on
            ApplyKillAuraZoneStyle()
        end,
        InstantPickup = function(on) if on then EnableInstantPickup() else DisableInstantPickup() end end,
        AntiTrap = function(on) State.Runtime.SetAntiTrap(on) end,

        -- Farming
        AutoFarm = function(on)
            State.Settings.AutoFarmEnabled = on
            if on then
                State.Cache.CoinBlacklist = {}
                State.Runtime.StartSessionCoins = GetCollectedCoinsCount()
                State.Runtime.Session.MarkFarmStart()   -- точка отсчёта Coins/h
                ShowNotification("Auto Farm: <font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Text)
                StartAutoFarm()
            else
                StopAutoFarm()
                ShowNotification("Auto Farm: <font color=\"rgb(255,85,85)\">OFF</font>", CONFIG.Colors.Text)
            end
        end,
        XPFarm = function(on) State.Settings.XPFarmEnabled = on if on then StartXPFarm() else StopXPFarm() end end,
        UndergroundMode = function(on) State.Settings.UndergroundMode = on end,
        CoinFarmFlySpeed = function(v) State.Settings.CoinFarmFlySpeed = v end,
        CoinFarmDelay = function(v) State.Settings.CoinFarmDelay = v end,
        AFKMode = function(on) State.Settings.AFKModeEnabled = on if on then Core.Movement.EnableMaxOptimization() else Core.Movement.DisableMaxOptimization() end end,
        FPSBoost = Core.Movement.EnableFPSBoost,

        -- AntiFling / WalkFling
        AntiFling = function(on) if on then EnableAntiFling() else DisableAntiFling() end end,
        WalkFling = function(on) if on then WalkFlingStart() else WalkFlingStop() end end,

        -- Fling
        FlingMethod = function(v) State.Settings.FlingMethod = Fling.NormalizeMethod(v) end,
        SkidLead = function(v) State.Settings.SkidLead = math.clamp(v, 0.6, 1.2) end,

        FlingMurderer = FlingMurderer,
        FlingSheriff  = FlingSheriff,

        Orbit = function(on) State.Settings.OrbitEnabled = on RigidOrbitPlayer(State.Runtime.SelectedPlayerForTrolling or State.Runtime.SelectedPlayerForFling, on) end,
        LoopFling = function(on) State.Settings.LoopFlingEnabled = on SimpleLoopFling(State.Runtime.SelectedPlayerForTrolling or State.Runtime.SelectedPlayerForFling, on) end,
        BlockPath = function(on) State.Settings.BlockPathEnabled = on PendulumBlockPath(State.Runtime.SelectedPlayerForTrolling or State.Runtime.SelectedPlayerForFling, on) end,
        LoopFlingMethod = function(v) State.Settings.LoopFlingMethod = Fling.NormalizeMethod(v) end,
        LoopFlingInterval = function(v) State.Settings.LoopFlingInterval = math.clamp(v, 1, 15) end,
        OrbitRadius = function(v) State.Settings.OrbitRadius = v end,
        OrbitSpeed = function(v) State.Settings.OrbitSpeed = v end,
        OrbitHeight = function(v) State.Settings.OrbitHeight = v end,
        OrbitTilt = function(v) State.Settings.OrbitTilt = v end,
        BlockPathSpeed = function(v) State.Settings.BlockPathSpeed = v end,
        OrbitPresetFastSpin = function() State.Settings.OrbitRadius = 4; State.Settings.OrbitSpeed = 10; State.Settings.OrbitHeight = 0; State.Settings.OrbitTilt = 0 end,
        OrbitPresetVerticalLoop = function() State.Settings.OrbitRadius = 5; State.Settings.OrbitSpeed = 5; State.Settings.OrbitHeight = 0; State.Settings.OrbitTilt = 90 end,
        OrbitPresetChaoticSpin = function() State.Settings.OrbitRadius = 2; State.Settings.OrbitSpeed = 15; State.Settings.OrbitHeight = 0; State.Settings.OrbitTilt = 30 end,

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
            if input.KeyCode == State.Settings.Keybinds.ClickTP then
                State.Runtime.ClickTPActive = false
            end
        end,
        OnMouseClick = function()
            if State.Runtime.ClickTPActive then Core.Movement.TeleportToMouse() end
        end,

        -- AIMBOT HANDLERS (добавить в Handlers = {})
        AimbotEnabled = function(value)
            if value then
                if Core.Aimbot.Start then
                    Core.Aimbot.Start()
                end
            else
                if Core.Aimbot.Stop then
                    Core.Aimbot.Stop()
                end
            end
            State.Settings.AimbotConfig.Enabled = value
        end,

        AimbotAliveCheck = function(value)
            State.Settings.AimbotConfig.AliveCheck = value
        end,

        AimbotDistanceCheck = function(value)
            State.Settings.AimbotConfig.DistanceCheck = value
        end,

        AimbotFovCheck = function(value)
            State.Settings.AimbotConfig.FovCheck = value
            -- ИСПРАВЛЕНИЕ: Добавлена проверка на существование
            if Core.Aimbot.State and Core.Aimbot.State.FovCircle then
                Core.Aimbot.State.FovCircle.Visible = value
            end
            if Core.Aimbot.State and Core.Aimbot.State.FovCircleOutline then
                Core.Aimbot.State.FovCircleOutline.Visible = value
            end
        end,

        AimbotTeamCheck = function(value)
            State.Settings.AimbotConfig.TeamCheck = value
        end,

        AimbotVisibilityCheck = function(value)
            State.Settings.AimbotConfig.VisibilityCheck = value
        end,

        AimbotLockOn = function(value)
            State.Settings.AimbotConfig.LockOn = value
        end,

        AimbotPrediction = function(value)
            State.Settings.AimbotConfig.Prediction = value
        end,

        AimbotDeltatime = function(value)
            State.Settings.AimbotConfig.Deltatime = value
        end,

        AimbotDistance = function(value)
            State.Settings.AimbotConfig.Distance = value
        end,

        AimbotFov = function(value)
            State.Settings.AimbotConfig.Fov = value
            -- ИСПРАВЛЕНИЕ: Добавлена проверка на существование
            if Core.Aimbot.State and Core.Aimbot.State.FovCircle then
                Core.Aimbot.State.FovCircle.Radius = value
            end
            if Core.Aimbot.State and Core.Aimbot.State.FovCircleOutline then
                Core.Aimbot.State.FovCircleOutline.Radius = value
            end
        end,

        AimbotFovTransparency = function(value)
            State.Settings.AimbotConfig.FovTransparency = value
            if Core.Aimbot.State and Core.Aimbot.State.FovCircle then
                Core.Aimbot.State.FovCircle.Transparency = value
            end
            if Core.Aimbot.State and Core.Aimbot.State.FovCircleOutline then
                Core.Aimbot.State.FovCircleOutline.Transparency = value
            end
        end,

        AimbotSmoothness = function(value)
            State.Settings.AimbotConfig.Smoothness = value
        end,

        AimbotPredictionValue = function(value)
            State.Settings.AimbotConfig.PredictionValue = value / 100
        end,

        AimbotVerticalOffset = function(value)
            State.Settings.AimbotConfig.VerticalOffset = value / 100
        end,

        AimbotMethod = function(value)
            State.Settings.AimbotConfig.Method = value
            if State.Settings.AimbotConfig.Enabled then
                if Core.Aimbot.Stop then Core.Aimbot.Stop() end
                -- Небольшая задержка для перезапуска
                task.wait(0.1)
                if Core.Aimbot.Start then Core.Aimbot.Start() end
            end
        end,

        AimbotMouseButton = function(value)
            State.Settings.AimbotConfig.MouseButton = value
        end,

        -- FLY ОБРАБОТЧИКИ
        -- Смена режима на лету: гасим текущий, Heartbeat Fly поднимет новый в следующем
        -- кадре. Старые конфиги с «CFrame Fly» (вырезан) падают на Fly
        FlyMode = function(value)
            if not table.find(CONFIG.Fly.Modes, value) then value = CONFIG.Fly.Modes[1] end
            if State.Settings.FlyEnabled then StopFly(true) end
            State.Settings.FlyType = value
        end,
        FlyBindMode = function(v) State.Runtime.SetBindMode("Fly", v) end,

        FlySpeed = function(value)
            State.Settings.FlySpeed = value
        end,

        Shutdown = function() FullShutdown() end,

        AutoLoadOnTeleport = function(on)
            State.Settings.AutoLoadOnTeleport = on
        end,

        -- ── Сводка для инфо-блока в сайдбаре ─────────────────────────────
        GetCoins        = function() return State.Runtime.Session.GetCoinsText() end,
        GetCoinsPerHour = function() return State.Runtime.Session.GetRateText() end,
        GetVersion      = function() return State.Runtime.Session.Version end,
        GetRole         = function() return State.Runtime.Session.GetRole() end,
    }, {__index = function(_, key)
        if State.Runtime.VisualsModule and State.Runtime.VisualsModule.Handlers[key] then
            local handler = State.Runtime.VisualsModule.Handlers[key]
            -- Любая правка ауры (вкл/выкл, цвет, насыщенность, яркость, сброс) — копия
            -- Spin Local Too должна пересобраться, иначе показывала бы старую ауру
            if type(key) == "string" and (key:sub(1, 4) == "Aura" or key == "ResetAuras") then
                return function(...)
                    local result = table.pack(handler(...))
                    if State.Runtime.RefreshLocalSpin then State.Runtime.RefreshLocalSpin() end
                    return table.unpack(result, 1, result.n)
                end
            end
            return handler
        end
        if State.Runtime.MovementModule and State.Runtime.MovementModule.Handlers[key] then
            return State.Runtime.MovementModule.Handlers[key]
        end
        return State.Runtime.OptimizationModule and State.Runtime.OptimizationModule.Handlers[key]
    end})
})

-- Уведомления в палитре текущей темы GUI: фон, рамка и текст — токены темы,
-- цветные акценты текста и иконок в светлых темах — затемнённые варианты
do
    local cfg = CONFIG.Notification
    local darkPalette, darkKinds = table.clone(cfg.RichPalette), {}
    for name, kind in pairs(cfg.Kinds) do darkKinds[name] = kind.Color end
    local function applyNotificationTheme(tokens)
        cfg.Background, cfg.Border = tokens.Canvas, tokens.Border
        cfg.BackgroundTransparency = tokens.RootTransparency or cfg.BackgroundTransparency
        cfg.Text, cfg.TextDark = tokens.Text, tokens.TextDark
        local palette = table.clone(darkPalette)
        if tokens.IsLight then
            for key, color in pairs(cfg.LightRichPalette) do palette[key] = color end
        end
        palette["220,220,220"] = tokens.Text
        cfg.RichPalette = palette
        for name, kind in pairs(cfg.Kinds) do
            kind.Color = tokens.IsLight and cfg.LightKindColors[name] or darkKinds[name]
        end
    end
    if GUI.GetThemeTokens and GUI.OnThemeChanged then
        applyNotificationTheme(GUI.GetThemeTokens())
        GUI.OnThemeChanged(applyNotificationTheme)
    end
end

Core.CleanupGUI = GUI.Cleanup
GUI.Init()

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 19: ВНЕШНИЕ МОДУЛИ WORLD / AURAS / OPTIMIZATION
-- ══════════════════════════════════════════════════════════════════════════════
do
    -- Отдельная функция даёт загрузчику собственный бюджет регистров Luau.
    (function()
        local context = {
            GUI = GUI, CONFIG = CONFIG, State = State, ShowNotification = ShowNotification, Tasks = Core.Tasks,
            Connect = Core.Connect, Remember = Core.Remember,
            -- Movement уступает корень флингу (Fling — локальная таблица MainScript)
            IsMovementBusy = function() return Fling.SessionActive == true end,
        }
        for _,entry in ipairs({{"Visuals", "VisualsModule"}, {"Optimization", "OptimizationModule"}, {"Movement", "MovementModule"}}) do
            local ok, result = pcall(function()
                local source = game:HttpGet(CONFIG.Modules[entry[1]], true)
                local chunk, compileError = loadstring(source)
                assert(chunk, compileError)
                local factory = chunk()
                assert(type(factory) == "function", "Invalid module factory")
                return factory(context)
            end)
            if ok then
                State.Runtime[entry[2]] = result
            else
                warn("[Violite] " .. entry[1] .. ": " .. tostring(result))
                ShowNotification(entry[1] .. " module failed to load", CONFIG.Colors.Accent)
            end
        end
        if State.Runtime.UIElements.MainGui then
            table.insert(State.Runtime.Connections, Core.Connect(State.Runtime.UIElements.MainGui.Destroying, function()
                Core.Shutdown()
            end))
        end
    end)()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК: CONFIG MANAGER — профили настроек (.vio в VioCFG/Violite)
-- ══════════════════════════════════════════════════════════════════════════════
-- Разделение ролей (модель WindUI): GUI ведёт реестр элементов —
-- GUI.GetElements() отдаёт flag → {__type, Value, Default, Set}, — а менеджер
-- владеет файлами, типовыми парсерами и автозагрузкой.
-- Файл .vio самоописывающийся, у каждого значения свой __type:
--   { __version, __script, __savedAt, __autoload, __custom,
--     __elements = { [flag] = { __type = "Toggle", value = true } } }
-- __autoload лежит ВНУТРИ конфига, а не в отдельном маркере — рассинхрону
-- взяться неоткуда. Контракт для GUI.AttachConfigSystem: List, Save, Load,
-- Create, Delete, Rename, Share, SetAutoload, GetAutoload.

-- IIFE вместо do-блока: внутренние локалы живут в своём скоупе регистров
-- и не давят на лимит 200 локалов верхнего уровня файла
local ConfigManager = (function()
    local CFG = CONFIG.Configs
    -- Orbit управляется кнопками пресетов, поэтому эти четыре числа не имеют контролов.
    local customDefaults = {
        OrbitRadius = State.Settings.OrbitRadius, OrbitSpeed = State.Settings.OrbitSpeed,
        OrbitHeight = State.Settings.OrbitHeight, OrbitTilt = State.Settings.OrbitTilt,
    }

    local function canUseFiles()
        return writefile ~= nil and readfile ~= nil and isfile ~= nil
    end

    -- Фидбек конфиг-операций показываем всегда: ShowNotification гейтится
    -- State.NotificationsEnabled, на время вызова форсируем флаг
    local function cfgNotify(text)
        pcall(function()
            local was = State.Settings.NotificationsEnabled
            State.Settings.NotificationsEnabled = true
            ShowNotification(
                string.format(
                    "<font color=\"rgb(220,145,230)\">Configs: </font><font color=\"rgb(220,220,220)\">%s</font>",
                    text
                ),
                CONFIG.Colors.Text
            )
            State.Settings.NotificationsEnabled = was
        end)
    end

    ------------------------------------------------------------------
    -- ПАРСЕРЫ ПО ТИПАМ ЭЛЕМЕНТОВ (аналог таблицы Parser в WindUI).
    -- Save отдаёт запись для файла, Load приводит значение к типу и
    -- применяет через element:Set(value, true) — тем же путём, что и клик
    ------------------------------------------------------------------

    -- Текущее значение элемента. У кейбинда Get читает State.Keybinds,
    -- поэтому бинд, назначенный захватом клавиши, тоже попадает в конфиг
    local function currentValue(element)
        if element.Get then
            local ok, v = pcall(element.Get, element)
            if ok then return v end
        end
        return element.Value
    end

    local function saveEntry(element)
        return { __type = element.__type, value = currentValue(element) }
    end

    local Parser = {
        Toggle = {
            Save = saveEntry,
            Load = function(element, value) element:Set(value and true or false, true) end,
        },
        Slider = {
            Save = saveEntry,
            Load = function(element, value) element:Set(tonumber(value), true) end,
        },
        Input = {
            Save = saveEntry,
            Load = function(element, value) element:Set(tonumber(value), true) end,
        },
        Dropdown = {
            Save = saveEntry,
            Load = function(element, value) element:Set(tostring(value), true) end,
        },
        Keybind = {
            Save = saveEntry,
            Load = function(element, value) element:Set(tostring(value), true) end,
        },
    }

    -- Порядок применения: сначала значения и бинды, тоглы последними —
    -- фича, которую включает тогл, должна стартовать уже с нужными параметрами
    local LOAD_ORDER = {
        Slider = 1, Input = 1, Dropdown = 1, Keybind = 2, Toggle = 3,
    }

    ------------------------------------------------------------------
    -- ФАЙЛЫ: имена, пути, перечисление
    ------------------------------------------------------------------

    local function sanitizeName(name)
        name = tostring(name or "")
        name = name:gsub("[^%w_%-% ]", "")
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if #name > 32 then name = name:sub(1, 32) end
        return name
    end

    local function configPath(name)
        return CFG.Dir .. "/" .. name .. CFG.Extension
    end

    -- Индекс имён — подстраховка для executor'ов без listfiles
    local function readIndex()
        local list = Files.LoadJSON(CFG.IndexFile, {})
        local out = {}
        for _, n in ipairs(list) do
            if type(n) == "string" then table.insert(out, n) end
        end
        return out
    end

    local function writeIndex(list)
        Files.SaveJSON(CFG.IndexFile, list)
    end

    local function indexFind(list, name)
        for i, n in ipairs(list) do
            if n == name then return i end
        end
        return nil
    end

    local function readConfig(name)
        local raw
        local ok = pcall(function()
            if isfile and isfile(configPath(name)) then
                raw = readfile(configPath(name))
            end
        end)
        if not ok or type(raw) ~= "string" then
            return nil, "Config file not found"
        end
        local okDecode, data = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if not okDecode or type(data) ~= "table" then
            return nil, "Config file is corrupted"
        end
        return data
    end

    local function writeConfig(name, data)
        local ok = pcall(function()
            Files.EnsureFoldersFor(configPath(name))
            writefile(configPath(name), HttpService:JSONEncode(data))
        end)
        if not ok then return false, "Failed to write config file" end
        local index = readIndex()
        if not indexFind(index, name) then
            table.insert(index, name)
            writeIndex(index)
        end
        return true
    end

    -- Сканируем папку через listfiles, индекс дополняет результат
    local EXT_PATTERN = "([^\\/]+)" .. (CFG.Extension:gsub("(%W)", "%%%1")) .. "$"

    local function listConfigs()
        local names, seen = {}, {}
        if listfiles and isfolder and isfolder(CFG.Dir) then
            local ok, files = pcall(listfiles, CFG.Dir)
            if ok and type(files) == "table" then
                for _, path in ipairs(files) do
                    local name = tostring(path):match(EXT_PATTERN)
                    if name and not seen[name] then
                        seen[name] = true
                        table.insert(names, name)
                    end
                end
            end
        end
        for _, name in ipairs(readIndex()) do
            if not seen[name] and isfile and isfile(configPath(name)) then
                seen[name] = true
                table.insert(names, name)
            end
        end
        table.sort(names)
        return names
    end

    ------------------------------------------------------------------
    -- АВТОЗАГРУЗКА: флаг живёт внутри конфигов, имя кэшируем —
    -- панель дёргает GetAutoload на каждой перерисовке
    ------------------------------------------------------------------

    local autoloadCache = nil   -- nil = не вычислен, false = автозагрузки нет

    local function computeAutoload()
        for _, name in ipairs(listConfigs()) do
            local data = readConfig(name)
            if data and data.__autoload then return name end
        end
        return false
    end

    ------------------------------------------------------------------
    -- СБОРКА И ПРИМЕНЕНИЕ
    ------------------------------------------------------------------

    -- defaults = true собирает «пустой» конфиг: дефолты контролов вместо текущих
    local function buildPayload(defaults, autoload)
        local elements = {}
        for flag, element in pairs(GUI.GetElements()) do
            local parser = Parser[element.__type]
            if parser then
                local ok, entry = pcall(parser.Save, element)
                if ok and type(entry) == "table" then
                    if defaults then entry.value = element.Default end
                    if entry.value ~= nil then elements[flag] = entry end
                end
            end
        end
        return {
            __version  = CFG.Version,
            __script   = CFG.Script,
            __savedAt  = os.time(),
            __autoload = autoload and true or false,
            __custom   = {
                OrbitRadius = defaults and customDefaults.OrbitRadius or State.Settings.OrbitRadius,
                OrbitSpeed = defaults and customDefaults.OrbitSpeed or State.Settings.OrbitSpeed,
                OrbitHeight = defaults and customDefaults.OrbitHeight or State.Settings.OrbitHeight,
                OrbitTilt = defaults and customDefaults.OrbitTilt or State.Settings.OrbitTilt,
            },
            __elements = elements,
        }
    end

    local function applyConfig(data)
        if type(data) ~= "table" or type(data.__elements) ~= "table" then
            return false, "Config file is corrupted"
        end
        if data.__script ~= CFG.Script then
            return false, "Config belongs to another script"
        end
        if type(data.__version) ~= "number" or data.__version > CFG.Version then
            return false, "Config version is not supported"
        end

        for key, fallback in pairs(customDefaults) do
            local value = type(data.__custom) == "table" and data.__custom[key] or nil
            if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then value = fallback end
            State.Settings[key] = value
        end

        -- Идём по РЕЕСТРУ, а не по файлу: контрол, которого в конфиге нет
        -- (старый файл, новая фича) или чей тип не совпал, возвращается к
        -- своему дефолту — иначе после смены конфига на экране оставались бы
        -- настройки предыдущего
        local queue = {}
        for flag, element in pairs(GUI.GetElements()) do
            local parser = Parser[element.__type]
            if parser then
                local entry = data.__elements[flag]
                local value
                if type(entry) == "table" and entry.__type == element.__type then
                    value = entry.value
                else
                    value = element.Default
                end
                local kind = element.__type
                local valid = (kind == "Toggle" and type(value) == "boolean")
                    or ((kind == "Slider" or kind == "Input") and type(value) == "number" and value == value and math.abs(value) < math.huge)
                    or ((kind == "Dropdown" or kind == "Keybind") and type(value) == "string")
                if not valid then value = element.Default end
                if value ~= nil then
                    table.insert(queue, {
                        flag = flag,
                        element = element,
                        parser  = parser,
                        value   = value,
                        order   = (element.__type == "Toggle" and value == false) and 0 or (LOAD_ORDER[element.__type] or 1),
                    })
                end
            end
        end
        table.sort(queue, function(a, b)
            if a.order == b.order then return a.flag < b.flag end
            return a.order < b.order
        end)
        local errors = {}

        for _, item in ipairs(queue) do
            -- совпавшее значение не трогаем: повторный вызов тяжёлых
            -- хендлеров (автофарм и т.п.) перезапускал бы их потоки
            if currentValue(item.element) ~= item.value then
                local ok, err = pcall(item.parser.Load, item.element, item.value)
                if not ok then table.insert(errors, item.flag .. ": " .. tostring(err)) end
            end
        end
        if #errors > 0 then return false, table.concat(errors, "; ") end
        return true
    end

    ------------------------------------------------------------------
    -- ПУБЛИЧНЫЙ КОНТРАКТ
    ------------------------------------------------------------------

    local ConfigManager = {
        List = function()
            return listConfigs()
        end,

        GetAutoload = function()
            if autoloadCache == nil then
                autoloadCache = computeAutoload()
            end
            return autoloadCache or nil
        end,

        SetAutoload = function(name)
            if not canUseFiles() then return false, "Executor has no file API" end
            -- автозагрузочный конфиг ровно один: у остальных флаг снимаем
            for _, cfgName in ipairs(listConfigs()) do
                local data = readConfig(cfgName)
                if data then
                    local want = (cfgName == name)
                    if (data.__autoload and true or false) ~= want then
                        data.__autoload = want
                        writeConfig(cfgName, data)
                    end
                end
            end
            autoloadCache = name or false
            cfgNotify(name and ("Autoload: " .. name) or "Autoload disabled")
            return true
        end,

        Save = function(name)
            if not canUseFiles() then return false, "Executor has no file API" end
            name = sanitizeName(name)
            if name == "" then return false, "Bad config name" end
            -- флаг автозагрузки принадлежит конфигу, а не сохранению
            local existing = readConfig(name)
            local ok, err = writeConfig(name,
                buildPayload(false, existing and existing.__autoload))
            if ok then cfgNotify("Saved: " .. name) end
            return ok, err
        end,

        Load = function(name)
            if not canUseFiles() then return false, "Executor has no file API" end
            local data, err = readConfig(name)
            if not data then return false, err end
            local ok, applyErr = applyConfig(data)
            if ok then cfgNotify("Loaded: " .. name) end
            return ok, applyErr
        end,

        -- «Пустой» конфиг: дефолтные значения всех контролов
        Create = function(name)
            if not canUseFiles() then return false, "Executor has no file API" end
            name = sanitizeName(name)
            if name == "" then return false, "Bad config name" end
            if indexFind(listConfigs(), name) then return false, "Config already exists" end
            local ok, err = writeConfig(name, buildPayload(true, false))
            if ok then cfgNotify("Created: " .. name) end
            return ok, err
        end,

        Delete = function(name)
            if not canUseFiles() then return false, "Executor has no file API" end
            local index = readIndex()
            local pos = indexFind(index, name)
            if pos then
                table.remove(index, pos)
                writeIndex(index)
            end
            pcall(function()
                if delfile and isfile(configPath(name)) then
                    delfile(configPath(name))
                end
            end)
            if autoloadCache == name then autoloadCache = nil end
            cfgNotify("Deleted: " .. name)
            return true
        end,

        Rename = function(oldName, newName)
            if not canUseFiles() then return false, "Executor has no file API" end
            newName = sanitizeName(newName)
            if newName == "" then return false, "Bad config name" end
            if indexFind(listConfigs(), newName) then return false, "Name already taken" end
            -- переносим файл целиком: флаг автозагрузки едет вместе с данными
            local data, err = readConfig(oldName)
            if not data then return false, err end
            local ok = pcall(function()
                Files.EnsureFoldersFor(configPath(newName))
                writefile(configPath(newName), HttpService:JSONEncode(data))
                if delfile and isfile(configPath(oldName)) then
                    delfile(configPath(oldName))
                end
            end)
            if not ok then return false, "Failed to write config file" end
            local index = readIndex()
            local pos = indexFind(index, oldName)
            if pos then index[pos] = newName else table.insert(index, newName) end
            writeIndex(index)
            if autoloadCache == oldName then autoloadCache = newName end
            cfgNotify("Renamed: " .. oldName .. " → " .. newName)
            return true
        end,

        Share = function(name)
            if not setclipboard then return false, "Executor has no clipboard API" end
            local raw
            local ok = pcall(function()
                if isfile and isfile(configPath(name)) then
                    raw = readfile(configPath(name))
                end
            end)
            if not ok or type(raw) ~= "string" then
                return false, "Config file not found"
            end
            pcall(setclipboard, raw)
            cfgNotify("Copied to clipboard: " .. name)
            return true
        end,
    }

    return ConfigManager
end)()

----------------------------------------------------------------
-- СОЗДАНИЕ ВКЛАДОК И ПРИВЯЗКА К Handlers
----------------------------------------------------------------
do
    local MainTab = GUI.CreateTab("Main")

        MainTab:CreateSection("CHARACTER SETTINGS")
        -- Строка «режим бинда + бинд»; старый закэшированный GUI.lua её не знает —
        -- тогда режим и бинд отдельными строками
        local function bindModeRow(title, desc, handlerKey, default, keybindKey)
            if MainTab.CreateBindModeRow then
                return MainTab:CreateBindModeRow(title, desc, handlerKey, CONFIG.BindModes, default, keybindKey)
            end
            local element = MainTab:CreateDropdown(title, desc, CONFIG.BindModes, default, handlerKey)
            MainTab:CreateKeybindButton(title .. " Key", keybindKey, keybindKey)
            return element
        end

        State.Runtime.SpeedBindRow = bindModeRow("Speed", "WalkSpeed stays vanilla", "SpeedBindMode", State.Settings.SpeedBindMode, "Speed")
        MainTab:CreateSlider("Speed Value", "Extra studs/s, 0 = off", CONFIG.Speed.Range[1], CONFIG.Speed.Range[2], State.Settings.SpeedValue, "SpeedValue", CONFIG.Speed.Step)
        MainTab:CreateInputField("JumpPower", "Set custom jump power", State.Settings.JumpPower, "ApplyJumpPower")
        MainTab:CreateInputField("Max Camera Zoom", "Set maximum camera distance", State.Settings.MaxCameraZoom, "ApplyMaxCameraZoom")

        MainTab:CreateSection("CAMERA")
        MainTab:CreateInputField("Field of View", "Set custom camera FOV", State.Settings.CameraFOV, "ApplyFOV")
        MainTab:CreateToggle("Aspect Ratio", "Stretched screen, like stretched res", "AspectRatio", false)
        MainTab:CreateSlider("Aspect Ratio Value", "1 = normal, lower = stretched", CONFIG.AspectRatio.Range[1], CONFIG.AspectRatio.Range[2], State.Settings.AspectRatioValue, "AspectRatioValue", CONFIG.AspectRatio.Step)
        MainTab:CreateToggle("ViewClip", "Camera clips through walls", "ViewClip",false)
        MainTab:CreateKeybindButton("Toggle Invisible", "invisibility", "Invisibility")

        MainTab:CreateSection("Speed Glitch")
        MainTab:CreateButton("", "Speed Glitch Tool", CONFIG.Colors.Accent, "SpeedGlitchTool")

        -- Bhop / автострейф: секции строит модуль Libraryes/Movement.lua
        -- (физику Source — ниже, под FLY SETTINGS; старая версия модуля строит всё сразу)
        local movement = State.Runtime.MovementModule
        if movement then
            if movement.BuildMainSection then movement.BuildMainSection(MainTab) else movement.BuildSections(MainTab) end
        end

        MainTab:CreateSection("TELEPORT & OTHER", "right")
        MainTab:CreateKeybindButton("Click TP (Hold Key + LMB)", "clicktp", "ClickTP")
        MainTab:CreateKeybindButton("Toggle NoClip", "NoClip", "NoClip")

        MainTab:CreateSection("FLY SETTINGS", "right")
        State.Runtime.FlyBindRow = bindModeRow("Fly", "Space/E up, Q down", "FlyBindMode", State.Settings.FlyBindMode, "Fly")
        MainTab:CreateDropdown("Fly Mode", "Select fly type", CONFIG.Fly.Modes, "Fly", "FlyMode")
        MainTab:CreateSlider("Fly Speed", "Adjust flying speed", 10, 80, State.Settings.FlySpeed, "FlySpeed", 5)
        ----------------------------------------------------------------------------
        MainTab:CreateButton("", "Fast respawn", CONFIG.Colors.Accent, "RespawnPlr")

        if movement and movement.BuildPhysicsSection then movement.BuildPhysicsSection(MainTab) end
end

do
    local AimTab = GUI.CreateTab("Aim")

        AimTab:CreateSection("AIMBOT")
        AimTab:CreateToggle("Enable Aimbot", "Toggle aimbot on/off", "AimbotEnabled",false)

        AimTab:CreateSection("TARGETING CHECKS")
        AimTab:CreateToggle("Alive Check", "Only target alive players", "AimbotAliveCheck",true)
        AimTab:CreateToggle("Distance Check", "Set maximum distance to target", "AimbotDistanceCheck",true)
        AimTab:CreateToggle("FOV Check", "Only aim within FOV circle", "AimbotFovCheck",true)
        AimTab:CreateToggle("Team Check", "Don't target teammates", "AimbotTeamCheck",false)
        AimTab:CreateToggle("Visibility Check", "Only target visible players", "AimbotVisibilityCheck")

        AimTab:CreateSection("TARGETING VALUES")
        AimTab:CreateSlider("Distance", "Maximum target distance", 100, 5000, State.Settings.AimbotConfig.Distance, "AimbotDistance", 50)
        AimTab:CreateSlider("FOV", "Field of view radius", 50, 500, State.Settings.AimbotConfig.Fov, "AimbotFov", 10)
        AimTab:CreateSlider("FOV Transparency", "Circle opacity: 0 = invisible, 1 = solid", 0, 1, State.Settings.AimbotConfig.FovTransparency, "AimbotFovTransparency", 0.05)
        AimTab:CreateSlider("Smoothness", "Aim smoothness", 1, 10, State.Settings.AimbotConfig.Smoothness, "AimbotSmoothness", 0.1)

        AimTab:CreateSection("ADVANCED OPTIONS", "right")
        AimTab:CreateToggle("Lock On Target", "Stay locked to same target", "AimbotLockOn",true)
        AimTab:CreateToggle("Prediction", "Predict player movement", "AimbotPrediction",true)
        AimTab:CreateToggle("Deltatime Safe", "FPS-independent smoothing", "AimbotDeltatime")
        AimTab:CreateDropdown("Method", "Aiming method", {"Mouse", "Camera"}, State.Settings.AimbotConfig.Method, "AimbotMethod")
        AimTab:CreateDropdown("Mouse Button", "Activation button", {"LMB", "RMB"}, State.Settings.AimbotConfig.MouseButton, "AimbotMouseButton")

        AimTab:CreateSection("PREDICTION & OFFSET", "right")
        AimTab:CreateSlider("Prediction", "Movement prediction strength", 0, 30, State.Settings.AimbotConfig.PredictionValue * 100, "AimbotPredictionValue", 1)
        AimTab:CreateSlider("Y Offset", "Vertical aiming offset", -200, 200, State.Settings.AimbotConfig.VerticalOffset * 100, "AimbotVerticalOffset", 5)
end

do
    local CombatTab = GUI.CreateTab("Combat")

        CombatTab:CreateSection("MURDERER TOOLS")
        CombatTab:CreateKeybindButton("Fast throw", "knifeThrow", "knifeThrow")
        CombatTab:CreateToggle("Spawn Knife Near Player", "Spawns knife next to closest target", "SpawnAtPlayer")

        CombatTab:CreateSection("KILL AURA")
        CombatTab:CreateKeybindButton("Kill Aura", "killaura", "KillAura")
        CombatTab:CreateSlider("Kill Aura Range", "Kill distance in studs", 1, 20, State.Settings.KillAuraRange, "KillAuraRange", 0.5)
        CombatTab:CreateToggle("Static Zone", "Disable circle animation", "KillAuraStatic", false)
        CombatTab:CreateKeybindButton("Instant Kill All", "instantkillall", "InstantKillAll")

        CombatTab:CreateSection("EXTENDED HITBOX")
        CombatTab:CreateToggle("Enable Extended Hitbox", "Makes all players easier to hit", "ExtendedHitbox")
        CombatTab:CreateSlider("Hitbox Size", "Larger = easier to hit", 10, 30, State.Settings.ExtendedHitboxSize, "ExtendedHitboxSize", 1)

        -- Режим выстрела — отдельным биндом: Shoot Murderer = Silent, Wallbang = Magic.
        -- 4-й аргумент (подпись) старый закэшированный GUI.lua просто игнорирует
        CombatTab:CreateSection("SHERIFF TOOLS", "right")
        CombatTab:CreateKeybindButton("Shoot Murderer", "shootmurderer", "ShootMurderer", "Silent shot from your gun with movement lead")
        CombatTab:CreateToggle("Auto Fire", "Shoots the murderer once the line to him is clear", "AutoFire", false)
        CombatTab:CreateToggle("Resolver", "Use only versus velocity spoofer", "Resolver", false)
        CombatTab:CreateKeybindButton("Wallbang", "wallbang", "Wallbang", "Shot through walls from next to the murderer")
        CombatTab:CreateKeybindButton("Pickup Dropped Gun", "pickupgun", "PickupGun", "Grabs the dropped gun from anywhere")
        CombatTab:CreateToggle("Instant Pickup Gun", "Auto pickup gun when dropped", "InstantPickup", false)

        CombatTab:CreateSection("PROTECTION", "right")
        CombatTab:CreateToggle("Anti Trap", "Murderer traps don't slow you, murderer isn't notified", "AntiTrap", false)
end

do
    local AntiAimTab = GUI.CreateTab("Anti-Aim")

        AntiAimTab:CreateSection("DESYNC")
        State.Runtime.FakePositionToggle = AntiAimTab:CreateToggle("Desync", "Send a fake position / rotation to other players", "FakePosition", false)
        AntiAimTab:CreateDropdown("Desync Mode", "Jitter: side shake; Spin: rotation; Chaos: tumbling blob", CONFIG.Desync.Modes, State.Settings.FakePositionMode, "FakePositionMode")
        AntiAimTab:CreateDropdown("Pitch", "Body tilt seen by others (not in Chaos)", CONFIG.Desync.PitchOrder, State.Settings.FakePositionPitch, "FakePositionPitch")
        AntiAimTab:CreateSlider("Desync Radius", "Jitter offset in studs; Chaos strength (10 = 5000 studs/s)", CONFIG.Desync.Radius[1], CONFIG.Desync.Radius[2], State.Settings.FakePositionRadius, "FakePositionRadius", 0.1)
        AntiAimTab:CreateSlider("Spin Speed", "Spin mode: degrees per second", CONFIG.Desync.SpinSpeed[1], CONFIG.Desync.SpinSpeed[2], State.Settings.FakeSpinSpeed, "FakeSpinSpeed", 10)
        AntiAimTab:CreateToggle("Spin Local Too", "Spin mode: visually spin on your screen as others see you", "FakeSpinLocal", State.Settings.FakeSpinLocal)

        AntiAimTab:CreateSection("FAKE LAG")
        State.Runtime.FakeLagToggle = AntiAimTab:CreateToggle("Enable Fake Lag", "Hold your sent position for short bursts (paused in Chaos)", "FakeLag", false)
        AntiAimTab:CreateSlider("Min Delay", "Shortest hold in milliseconds", CONFIG.FakeLag.MinDelay[1], CONFIG.FakeLag.MinDelay[2], State.Settings.FakeLagMinDelay, "FakeLagMinDelay", 10)
        AntiAimTab:CreateSlider("Max Delay", "Longest hold in milliseconds", CONFIG.FakeLag.MaxDelay[1], CONFIG.FakeLag.MaxDelay[2], State.Settings.FakeLagMaxDelay, "FakeLagMaxDelay", 10)
        AntiAimTab:CreateSlider("Randomization", "0: always Max Delay; 10: random between Min and Max", CONFIG.FakeLag.Randomization[1], CONFIG.FakeLag.Randomization[2], State.Settings.FakeLagRandomization, "FakeLagRandomization", 1)

        AntiAimTab:CreateSection("VELOCITY SPOOFER", "right")
        State.Runtime.VelocitySpoofToggle = AntiAimTab:CreateToggle("Velocity Spoofer", "Report fake velocity to other players", "VelocitySpoof", false)
        AntiAimTab:CreateDropdown("Spoof Mode", "Anti-Aim: fake upward velocity; Zero: never above normal speed", {"Anti-Aim", "Zero"}, State.Settings.VelocitySpoofMode, "VelocitySpoofMode")
        AntiAimTab:CreateToggle("Only As Murderer", "On: spoof only while you are murderer (sheriffs miss). Off: always", "VelocitySpoofMurdererOnly", State.Settings.VelocitySpoofMurdererOnly)
        AntiAimTab:CreateSlider("Anti-Aim Strength", "Fake upward speed in studs/s; higher = more jitter for others", 20, 500, State.Settings.VelocitySpoofStrength, "VelocitySpoofStrength", 10)
        AntiAimTab:CreateSlider("Zero Max Speed", "Highest speed reported in Zero mode (place default: " .. CONFIG.DefaultWalkSpeed .. ")", 0, 20, State.Settings.VelocitySpoofSpeed, "VelocitySpoofSpeed", 1)

        AntiAimTab:CreateSection("DESYNC CHAMS", "right")
        AntiAimTab:CreateToggle("Ping / Desync Chams", "Show estimated fake position during desync; ping ghost otherwise", "PingChams")
        AntiAimTab:CreateToggle("Chams Label", "Show text above Ping / Desync Chams", "PingChamsShowLabel", State.Settings.PingChamsShowLabel)
end

do
    local VisualsTab = GUI.CreateTab("Visuals")

        VisualsTab:CreateSection("ESP")
        VisualsTab:CreateToggle("Murder ESP", "Highlight murderer", "MurderESP",false)
        VisualsTab:CreateToggle("Sheriff ESP", "Highlight sheriff", "SheriffESP",false)
        VisualsTab:CreateToggle("Innocent ESP", "Highlight innocent players", "InnocentESP",false)
        VisualsTab:CreateToggle("Show Nicknames", "Display player nicknames", "PlayerNicknamesESP", false)
        VisualsTab:CreateToggle("Dropped Gun", "Highlight dropped gun", "GunESP",false)
        VisualsTab:CreateToggle("Tracers", "Show bullet/knife trajectory", "BulletTracers")

        VisualsTab:CreateSection("Misc", "right")
        VisualsTab:CreateToggle("Enable Notifications", "Show notifications", "NotificationsEnabled",false)
        VisualsTab:CreateToggle("Role Cards", "Show Murderer and Sheriff avatar", "AvatarDisplayEnabled", false)
        VisualsTab:CreateToggle("Disable UI", "Hide all UI except script GUI", "UIOnly")
        VisualsTab:CreateToggle("Friend Viewer", "Show beams between Roblox friends", "FriendViewer", false)
        VisualsTab:CreateToggle("Coin Muter", "Mute coin pickup sound", "CoinMuter", false)
end

if State.Runtime.VisualsModule then State.Runtime.VisualsModule.BuildTabs() end

do
    local FarmTab = GUI.CreateTab("Farming")

        FarmTab:CreateSection("AUTO FARM")
        FarmTab:CreateToggle("Auto Farm", "Automatic coin farm", "AutoFarm", false)
        FarmTab:CreateToggle("XP Farm", "Auto win rounds", "XPFarm", false)
        FarmTab:CreateToggle("Underground Mode", "Fly under the map (safer)", "UndergroundMode",true)

        FarmTab:CreateSection("FARM TUNING", "right")
        FarmTab:CreateSlider("Fly Speed", "Flying speed", 15, 30, State.Settings.CoinFarmFlySpeed, "CoinFarmFlySpeed", 0.5)
        FarmTab:CreateSlider("TP Delay", "Delay between first TP", 0.5, 5.0, State.Settings.CoinFarmDelay, "CoinFarmDelay", 0.5)
        FarmTab:CreateToggle("Auto Reconnect", "Reconnect every 25 min", "HandleAutoReconnect", false)
        FarmTab:CreateInputField("Reconnect interval","Default: 25 min", math.floor(State.Settings.ReconnectInterval / 60), "SetReconnectInterval")
end

do
    local FunTab = GUI.CreateTab("Fun")

        FunTab:CreateSection("ANIMATION KEYBINDS")
        FunTab:CreateKeybindButton("Sit Animation", "sit", "Sit")
        FunTab:CreateKeybindButton("Dab Animation", "dab", "Dab")
        FunTab:CreateKeybindButton("Zen Animation", "zen", "Zen")
        FunTab:CreateKeybindButton("Ninja Animation", "ninja", "Ninja")
        FunTab:CreateKeybindButton("Floss Animation", "floss", "Floss")

        FunTab:CreateSection("AVATAR")
        FunTab:CreateToggle("Fake Headless", "Hide head and face locally", "FakeHeadless", false)
        FunTab:CreateToggle("Fake Korblox", "Replace right leg with Korblox", "FakeKorblox", false)

        FunTab:CreateSection("ANTI-FLING", "right")
        FunTab:CreateToggle("Enable Anti-Fling", "Protect yourself from flingers", "AntiFling",false)
        FunTab:CreateToggle("Walk Fling", "Fling players by walking into them", "WalkFling", false)

        FunTab:CreateSection("FLING SETTINGS", "right")
        FunTab:CreateDropdown("Fling Method", "Vio: contact, stronger. NaN: precise aim, weaker", Fling.MethodChoices, Fling.MethodLabel(State.Settings.FlingMethod), "FlingMethod")
        FunTab:CreateSlider("Prediction Range", "Lead time", 0.6, 1.2, State.Settings.SkidLead, "SkidLead", 0.05)

        FunTab:CreateSection("FLING PLAYER", "right")
        FunTab:CreatePlayerDropdown("Select Target", "Choose target to fling", "SelectedPlayerForFling")
        FunTab:CreateKeybindButton("Fling Selected Target", "fling", "FlingPlayer")

        FunTab:CreateSection("FLING ROLE", "right")
        FunTab:CreateButton("", "Fling Murderer", Color3.fromRGB(255, 85, 85), "FlingMurderer")
        FunTab:CreateButton("", "Fling Sheriff", Color3.fromRGB(90, 140, 255), "FlingSheriff")
end

do
    local TrollingTab = GUI.CreateTab("Troll")

        TrollingTab:CreateSection("SELECT TARGET")
        TrollingTab:CreatePlayerDropdown("Target Player", "Choose victim for trolling", "SelectedPlayerForTrolling")

        TrollingTab:CreateSection("TROLLING MODES")
        TrollingTab:CreateToggle("Orbit Mode", "Rotate around player", "Orbit")
        TrollingTab:CreateToggle("Loop Fling", "Fling target on a timer", "LoopFling")
        TrollingTab:CreateToggle("Block Path", "Block player path", "BlockPath")

        TrollingTab:CreateSection("BLOCK PATH SETTINGS")
        TrollingTab:CreateSlider("Pendulum Speed", "Movement speed", 0.05, 0.3, State.Settings.BlockPathSpeed, "BlockPathSpeed", 0.05)

        -- ORBIT SETTINGS скрыты: значения ставятся пресетами ниже.
        -- Хендлеры OrbitRadius/OrbitSpeed/OrbitHeight/OrbitTilt оставлены на месте,
        -- так что вернуть ползунки можно просто раскомментировав этот блок.
        -- TrollingTab:CreateSection("ORBIT SETTINGS")

        TrollingTab:CreateSection("ORBIT PRESETS", "right")
        TrollingTab:CreateButton("", "Fast Spin", Color3.fromRGB(255, 170, 50), "OrbitPresetFastSpin")
        TrollingTab:CreateButton("", "Vertical Loop", Color3.fromRGB(255, 85, 85), "OrbitPresetVerticalLoop")
        TrollingTab:CreateButton("", "Chaotic Spin", Color3.fromRGB(200, 100, 200), "OrbitPresetChaoticSpin")

        TrollingTab:CreateSection("LOOP FLING SETTINGS", "right")
        TrollingTab:CreateDropdown("Loop Fling Method", "Method used by Loop Fling only", Fling.MethodChoices, Fling.MethodLabel(State.Settings.LoopFlingMethod), "LoopFlingMethod")
        TrollingTab:CreateSlider("Repeat Every", "Seconds between flings", 1, 15, State.Settings.LoopFlingInterval, "LoopFlingInterval", 0.5)
end

do
    local UtilityTab = GUI.CreateTab("Server")

        UtilityTab:CreateSection("SERVER MANAGEMENT")
        UtilityTab:CreateButton("", "Rejoin Server", CONFIG.Colors.Accent, "Rejoin")
        UtilityTab:CreateButton("", "Server Hop", Color3.fromRGB(100, 200, 100), "ServerHop")
        UtilityTab:CreateToggle("Auto Rejoin on Disconnect","Automatically rejoin server if kicked/disconnected","HandleAutoRejoin",false)
        UtilityTab:CreateButton("", "Execute Infinite Yield", CONFIG.Colors.Accent, "ExecInf")
        -- Палитра интерфейса (закэшированный CDN старый GUI.lua тем не знает — тогда без пункта)
        if UtilityTab.CreateThemeDropdown then
            UtilityTab:CreateThemeDropdown("Theme", "Interface color palette")
        end

        UtilityTab:CreateSection("DANGER ZONE", "right")
        UtilityTab:CreateButton("", "SERVER CRASHER", Color3.fromRGB(255, 85, 85), "ServerLagger")
        if State.Runtime.OptimizationModule then State.Runtime.OptimizationModule.BuildSection(UtilityTab) end
end

-- ── Подключение системы конфигов: все вкладки построены, реестр флагов полон.
-- pcall на случай закэшированной старой версии GUI.lua без конфиг-API
pcall(function()
    if GUI.AttachConfigSystem then
        GUI.AttachConfigSystem(ConfigManager)
    end
end)

-- Связь registry с настройками: кнопки пресетов не должны сохранять старые значения слайдеров.
do
    (function()
        local aliases = {
            ApplyJumpPower = "JumpPower", ApplyMaxCameraZoom = "MaxCameraZoom", ApplyFOV = "CameraFOV",
            AspectRatio = "AspectRatioEnabled",
            UIOnly = "UIOnlyEnabled", CoinMuter = "CoinMuterEnabled", ViewClip = "ViewClipEnabled", FlyMode = "FlyType", AutoFarm = "AutoFarmEnabled", XPFarm = "XPFarmEnabled",
            AFKMode = "AFKModeEnabled", AntiFling = "AntiFlingEnabled", WalkFling = "WalkFlingEnabledByUser",
            ExtendedHitbox = "ExtendedHitboxEnabled", InstantPickup = "InstantPickupEnabled", BulletTracers = "BulletTracersEnabled",
            FriendViewer = "FriendViewerEnabled", PingChams = "PingChamsEnabled", FakePosition = "FakePositionEnabled", FakeLag = "FakeLagEnabled",
            VelocitySpoof = "VelocitySpoofEnabled", AntiTrap = "AntiTrapEnabled",
            AutoFire = "AutoFireEnabled", Resolver = "ResolverEnabled",
            Orbit = "OrbitEnabled", LoopFling = "LoopFlingEnabled", BlockPath = "BlockPathEnabled",
            HandleAutoRejoin = "AutoRejoinEnabled", HandleAutoReconnect = "AutoReconnectEnabled",
        }
        for flag, element in pairs(GUI.Flags) do
            local key = aliases[flag] or flag
            local source = State.Settings
            local scale = 1
            if flag:sub(1, 6) == "Aimbot" then
                source = State.Settings.AimbotConfig
                key = flag:sub(7)
                if key == "PredictionValue" or key == "VerticalOffset" then scale = 100 end
            elseif flag == "SetReconnectInterval" then key = "ReconnectInterval"; scale = 1 / 60 end
            if type(source[key]) ~= "table" and source[key] ~= nil and not element.Get then
                element.Get = function(self)
                    local value = source[key]
                    if type(value) == "number" then value *= scale end
                    if flag == "FlingMethod" or flag == "LoopFlingMethod" then value = Fling.MethodLabel(value) end
                    if self.Value ~= value then self:Set(value, false) end
                    return value
                end
            end
        end
        Core.SyncControls = function()
            for _, element in pairs(GUI.Flags) do
                if element.Get then pcall(element.Get, element) end
            end
        end
    end)()
end

-- Автозагрузка: заменяет прежний _G.AUTOEXEC_ENABLED. Ждём, пока тоглы
-- с default=true отработают свой авто-fire, и накатываем конфиг поверх
Core.Tasks.spawn(function()
    local auto = ConfigManager.GetAutoload()
    if not auto then return end
    task.wait(1)
    local okCall, okLoad = pcall(ConfigManager.Load, auto)
    if okCall and okLoad and GUI.SetActiveConfigName then
        pcall(GUI.SetActiveConfigName, auto)
    end
end)
---------
Core.Connect(LocalPlayer.CharacterAdded, function(newCharacter)
    CleanupMemory()
    task.wait(1)
    -- Пока настройки не тронуты (нет ни ручных правок, ни конфига) —
    -- респавн не трогаем: игра как без скрипта
    if State.Runtime.SettingsDirty then
        Core.Movement.ApplyCharacterSettings()
    end

    if State.Settings.FakeHeadless and State.Runtime.ApplyFakeHeadless then
        State.Runtime.ApplyFakeHeadless(true, newCharacter)
    end
    if State.Settings.FakeKorblox and State.Runtime.ApplyFakeKorblox then
        State.Runtime.ApplyFakeKorblox(true, newCharacter)
    end

    State.Runtime.PreviousMurderer = nil
    State.Runtime.PreviousSheriff = nil
    State.Runtime.HeroSent = false
    State.Runtime.RoundStart = true
    State.Runtime.RoundActive = false
end)

-- ═══════════════════════════════════════════════════════════════
--                      ЗАПУСК СКРИПТА
-- ═══════════════════════════════════════════════════════════════

CreateNotificationUI()
CreateAvatarUI()
SetAvatarDisplayVisibility(State.Settings.AvatarDisplayEnabled)
-- ApplyCharacterSettings()/ApplyFOV при старте убраны намеренно: без
-- автозагрузочного конфига скорость/прыжок/зум/FOV остаются ванильными
SetupGunTracking()
StartTrapTracking   ()
SetupPlayerNicknamesTracking()
SetupAntiAFK()
StartRoleChecking()





end, debug.traceback)
if not startupOk then
    Core.Shutdown()
    warn("[Violite startup] " .. tostring(startupError))
end