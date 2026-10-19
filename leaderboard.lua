    -- ══════════════════════════════════════════════════════════════════════════════
    -- LEADERBOARD — облегчённая сборка MainScript для пачки альтов с автофармом
    -- ══════════════════════════════════════════════════════════════════════════════
    -- Собран из MainScript (та же архитектура: Core, State.Settings/Runtime/Cache,
    -- SheriffAim, Fling, ServerHop v3, Rejoin v2) без визуала, Desync, аимбота,
    -- косметики и конфиг-менеджера. Сверху — то, чего в MainScript нет: сумки
    -- ивентовой валюты, режимы Infection/FreezeTag, флинг мурдерера для зрителя,
    -- Smart Collect, Farm Sync, Vote Spam, Auto Prestige, Auto Battle Pass.
    -- Грузится только с CDN (raw GitHub), бандла нет.

    -- ══════════════════════════════════════════════════════════════════════════════
    -- БЛОК 1: INITIALIZATION & PROTECTION
    -- ══════════════════════════════════════════════════════════════════════════════

    -- PlaceId проверка (если нужна)
    --if game.PlaceId ~= 142823291 then return end

    if not game:IsLoaded() then game.Loaded:Wait() end

    local lp = game:GetService("Players").LocalPlayer
    while not lp do
        task.wait()
        lp = game:GetService("Players").LocalPlayer
    end

    local waitStart = os.clock()
    repeat
        task.wait(0.2)
    until lp:GetAttribute("Level") ~= nil
    or (lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("MainGUI"))
    or (os.clock() - waitStart > 15)

    task.wait(1) -- Дополнительная пауза, чтобы ProfileData гарантированно завершил InvokeServer()


    -- Пресет альта: все фермерские тумблеры (Auto Farm, XP Farm, Farm Sync, Auto
    -- Reconnect, Instant Pickup, Anti Trap, Auto Battle Pass...) включаются сами
    local AUTOFARM_ENABLED = true

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
            -- Частоты фоновой работы фич. Релиз исполняется в VM обфускатора (в разы
            -- медленнее), поэтому всё, что не обязано идти каждый кадр, идёт реже
            Perf = {
                RoleCheckInterval  = 0.1,  -- сек: роли и подсветка ESP (роли меняются раз в раунд)
                PingChamsPartCheck = 0.25, -- сек: проверка набора частей/размера для призрака
                AntiFlingFullPass  = 0.1,  -- сек: полный проход коллизии; корпус — каждый кадр
                AntiFlingPartsTTL  = 2,    -- сек: жизнь кэша частей персонажа (± разброс); новый персонаж — сразу
                AntiFlingCleanup   = 1,    -- сек: чистка записей об удалённых частях
            },
            -- Адреса модулей нужны только вне бандла (в бандле модули уже внутри)
            -- Лидерборд грузится только с CDN (бандла нет): адреса себя и модуля
            SelfUrl = "https://raw.githubusercontent.com/Yany1944/rbxmain/refs/heads/main/leaderboard.lua",
            Modules = {
                Optimization = "https://raw.githubusercontent.com/Yany1944/rbxmain/main/Libraryes/Optimization.lua",
            },
            -- Пресет альта: дефолты фермерских тумблеров (см. AUTOFARM_ENABLED в БЛОКЕ 1)
            AutoExec = AUTOFARM_ENABLED,
            -- Smart Collect: дальний перелёт между монетами укладывается в случайные
            -- MinTime..MaxTime секунд (как средний обычный перелёт со скоростью ~23),
            -- ближние летим с обычной Fly Speed
            SmartCollect = {
                MinTime = 2,
                MaxTime = 3,
            },
            -- Ивентовый Battle Pass (Halloween 2026: 600 валюты за тир, 30 тиров).
            -- Имя ивента, валюта и цены читаются из EventInfoService, здесь — только тайминги
            BattlePass = {
                Interval     = 30,    -- сек между проверками баланса
                ClaimDelay   = 0.4,   -- сек между ClaimBattlePassReward
            },
            -- Infection (зомби-раунд): что делаем после того, как сумка полна
            Infection = {
                MagnetTime   = 6,     -- сек держимся у одного зомби, потом берём другого
                KillAllEvery = 1,     -- сек между InstantKillAll, пока мы зомби
            },
            -- Флинг мурдерера, когда мы не участник раунда (инжект в лобби / нас убили)
            SpectatorFling = {
                Interval     = 3,     -- сек между попытками
                MaxAttempts  = 15,
            },
            HideKey = Enum.KeyCode.Q,
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
            -- Плавный зум при ViewClip: в режиме Invisicam PlayerModule не гоняет пружину
            -- ZoomController (она вызывается только из Poppercam) — повторяем её поверх камеры
            ViewClipZoom = {
                Stiffness = 4.5,       -- = ZOOM_STIFFNESS из ZoomController, та же «мягкость»
                BindName = "Violite_ViewClipZoom",
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
                -- Слежка за целью не чаще 60 Гц: при 240 FPS посекундная работа (луч до пола,
                -- окна скорости, сдвиг истории) росла вчетверо, а в обфусцированной сборке
                -- это давало заметные лаги при включённом Auto Fire. Предикт идёт по меткам
                -- времени, частота сэмплов на него не влияет
                TrackInterval  = 1 / 60,
                MapParamsTTL   = 0.1,    -- сек жизни кэша RaycastParams карты (без extra)
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
            -- Silent Knife: бросок ножа (бинд Fast throw и обычный бросок игры) летит в
            -- упреждённую точку цели у курсора. Нож — снаряд ThrowSpeed studs/s по прямой
            -- без гравитации (см. KnifeTracer), поэтому упреждение = пинг + ServerLead
            -- (как у выстрела шерифа) + время полёта до точки встречи
            SilentKnife = {
                MaxRange    = 300,   -- studs: дальше цель не берём
                MaxLead     = 1.5,   -- сек: потолок упреждения (дальний бросок по бегущей цели)
                Iterations  = 4,     -- итераций «время полёта ↔ точка встречи»
                MaxRiseSpeed = 60,   -- studs/s: вертикаль цели выше — спуф/флинг, её не тянем
            },
            -- Трассер выстрела: duration в CreateTracer — полное время жизни, последние
            -- FadeTime секунд из него трассер плавно растворяется (раньше висел целиком
            -- и гас за 0.1 с — пропадал рывком)
            BulletTracer = {
                FadeTime = 1.2,         -- сек растворения (не больше 60% жизни трассера)
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
            Desync = Enum.KeyCode.Unknown,
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
            FakePositionEnabled = false,      -- Desync реально работает (по режиму бинда)
            FakePositionToggleOn = false,     -- включён биндом в режиме Toggle
            FakePositionBindMode = "Toggle",
            FakePositionMode = "Jitter",
            FakePositionRadius = 3,
            FakePositionPitch = "Straight",
            FakeSpinSpeed = 720,
            FakeSpinLocal = false,
            FakeChaosAvoid = false,
            FakeLagEnabled = false,
            FakeLagMinDelay = 80,
            FakeLagMaxDelay = 200,
            FakeLagRandomization = 3,
            SpawnAtPlayer = false,
            SilentKnifeEnabled = false,
            HoldThrowEnabled = false,
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
            ReconnectInterval = 60 * 60,   -- альты: раз в час
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
            -- Лидерборд
            SmartCollectEnabled = false,
            AutoPrestigeEnabled = false,
            AutoBattlePassEnabled = false,
            BuyFinalRewardEnabled = false,
            VoteSpammerEnabled = false,
            VoteGoal = 8,
            FarmSyncEnabled = false,
            FPSCap = 60,
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
            FakePositionBindRow = nil,
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
            KnifeRoutes = {},          -- активные маршруты брошенных ножей (Tracers)
            KnifeRouteConn = nil,      -- Heartbeat, двигающий «голову» маршрутов
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

    -- Автозагрузка после телепорта (реджоин, хоп, Farm Sync, кик игры). Лидерборд
    -- живёт без бандла: после телепорта тянем этот же файл с GitHub raw. В очередь
    -- ставим один раз и сразу — телепорт может прийти откуда угодно; повторная
    -- постановка давала двойную загрузку на executor'ах без дедупликации очереди
        local TeleportCheck = false
        if queue_on_teleport then
            local teleportScript = [[
                repeat task.wait() until game:IsLoaded()
            task.wait(2)
                if game.PlaceId == 142823291 or game.PlaceId == 335132309 then
                    local success, err = pcall(function()
                        loadstring(game:HttpGet("]] .. CONFIG.SelfUrl .. [[", true))()
                    end)
                    if not success then
                        warn("Ошибка автозагрузки:", err)
                    end
                end
            ]]
        if State.Settings.AutoLoadOnTeleport and not TeleportCheck then
            TeleportCheck = pcall(queue_on_teleport, teleportScript)
        end
    end

    local function TrackConnection(conn)
        return Core.Track(conn)
    end
    --]]
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

        local lifetime = duration or 0.3
        local fadeTime = math.min(CONFIG.BulletTracer.FadeTime, lifetime * 0.6)
        Core.Tasks.delay(lifetime - fadeTime, function()
            local startTime = tick()
            local startTrans = 0
            local startBrightness = 5

            while tick() - startTime < fadeTime do
                -- sine in-out: растворение начинается и заканчивается мягко, без рывка
                local alpha = 0.5 - 0.5 * math.cos(math.pi * (tick() - startTime) / fadeTime)
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

    -- Маршруты ножей/пуль (Tracers) в лидерборде не нужны: остаётся только флаг,
    -- по которому CreateTracer рисует (или не рисует) трассер своего выстрела
    local function ToggleBulletTracers(on)
        State.Settings.BulletTracersEnabled = on and true or false
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
        -- Модуль оптимизации восстанавливает освещение, рендер и FPS cap.
        if State.Runtime.OptimizationModule then pcall(State.Runtime.OptimizationModule.Destroy) end

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
        end)

        if Core.CleanupGUI then Core.Try("GUI", Core.CleanupGUI) end

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
            local now = os.clock()
            if now < (State.Runtime.NextRoleCheck or 0) then return end
            State.Runtime.NextRoleCheck = now + CONFIG.Perf.RoleCheckInterval
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
    -- убийца видят сработавшую ловушку).
    -- Раньше игровой обработчик глушили через getconnections + conn:Disable() — на
    -- срабатывании ловушки (сервер стреляет событием в отключённое соединение) клиент
    -- падал целиком, без ошибки в логе. Теперь соединения игры не трогаем: свой
    -- обработчик в том же кадре снимает замедление и окно, а TrapReplicate режет хук
    -- __namecall — убийца сигнала не получает. Без hookmetamethod — только снятие замедления
    do
        local anti = {Handler = nil, Watch = nil, Hooked = false, Replicate = nil}

        local function trapSystem()
            return ReplicatedStorage:FindFirstChild("TrapSystem")
        end

        -- Хук ставится один раз и снять его нельзя без риска сорвать чужие хуки поверх
        -- (как в skinchanger), поэтому при выключенной фиче и после выгрузки он прозрачен
        local function hookReplicate(system)
            anti.Replicate = system:FindFirstChild("TrapReplicate")
            if anti.Hooked then return end
            if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then return end
            local wrap = type(newcclosure) == "function" and newcclosure or function(fn) return fn end
            local ok = pcall(function()
                local old
                old = hookmetamethod(game, "__namecall", wrap(function(self, ...)
                    if self == anti.Replicate and anti.Replicate ~= nil and Core.Alive
                        and State.Settings.AntiTrapEnabled and getnamecallmethod() == "FireServer" then
                        return
                    end
                    return old(self, ...)
                end))
            end)
            anti.Hooked = ok
        end

        -- Игровой обработчик уже замедлил — возвращаем как было
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
            if anti.Handler then anti.Handler:Disconnect(); anti.Handler = nil end
            if anti.Watch then Core.Tasks.cancel(anti.Watch); anti.Watch = nil end
            if not State.Settings.AntiTrapEnabled then return end

            local system = trapSystem()
            local remote = system and system:FindFirstChild("TrapHitLocal")
            if not remote then
                -- Не MM2 или система ловушек ещё не загружена — ждём её в фоне
                anti.Watch = Core.Tasks.spawn(function()
                    local found = ReplicatedStorage:WaitForChild("TrapSystem", 60)
                    if found and found:WaitForChild("TrapHitLocal", 10) and State.Settings.AntiTrapEnabled then
                        State.Runtime.SetAntiTrap(true)
                    end
                end)
                return
            end
            pcall(hookReplicate, system)
            -- Игровой обработчик подключён раньше и отрабатывает первым; defer — в том же
            -- кадре после него. Через 4 с игра сама ставит JumpPower 50 — возвращаем свой
            anti.Handler = Core.Connect(remote.OnClientEvent, function()
                Core.Tasks.defer(undoTrap)
                Core.Tasks.delay(4.1, function()
                    if State.Settings.AntiTrapEnabled then pcall(undoTrap) end
                end)
            end)
            -- Включили уже сидя в ловушке
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.WalkSpeed < 0.1 then undoTrap() end
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

    -- Части персонажа для антифлинга: снимать коллизию нужно каждый кадр (Humanoid
    -- возвращает её корпусу), а GetDescendants на каждого игрока за кадр создавал сотни
    -- объектов и десятки МБ мусора в секунду — в раунде это давало лаги. Состав частей
    -- кэшируем на CollisionPartsTTL, новые части подхватываются при обновлении
    -- Корпус (его коллизию Humanoid включает обратно на каждом шаге физики) — каждый
    -- кадр; остальные части — полным проходом раз в AntiFlingFullPass. Обновление кэша
    -- разнесено по времени случайным сдвигом, чтобы игроки не пересобирались в один кадр
    Fling.CollisionPartsCache = setmetatable({}, {__mode = "k"})
    Fling.CoreParts = {HumanoidRootPart = true, Head = true, Torso = true, UpperTorso = true, LowerTorso = true}
    function Fling.CollisionParts(char)
        local now = os.clock()
        local entry = Fling.CollisionPartsCache[char]
        if entry and now < entry.Expires then return entry end
        local parts, core = {}, {}
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") then
                parts[#parts + 1] = obj
                if Fling.CoreParts[obj.Name] and obj.Parent == char then core[#core + 1] = obj end
            end
        end
        local ttl = CONFIG.Perf.AntiFlingPartsTTL
        entry = {Parts = parts, Core = core, Expires = now + ttl * (0.5 + math.random()), NextFull = 0}
        Fling.CollisionPartsCache[char] = entry
        return entry
    end

    function Fling.StripCharCollision(char)
        Fling.WatchCharParts(char)
        local entry = Fling.CollisionParts(char)
        local now = os.clock()
        local list = entry.Core
        if not Fling.StrippedChars[char] or now >= entry.NextFull then
            entry.NextFull = now + CONFIG.Perf.AntiFlingFullPass
            list = entry.Parts
        end
        for _, obj in ipairs(list) do
            if obj.Parent then
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

        -- Чистка удалённых частей — раз в AntiFlingCleanup: таблица держит части всех
        -- игроков (сотни), обход каждый кадр стоил дороже самой защиты
        if now < (Fling.NextCleanup or 0) then return end
        Fling.NextCleanup = now + CONFIG.Perf.AntiFlingCleanup
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
        for char, conn in pairs(Fling.WatchedChars) do
            if not char.Parent then
                pcall(function() conn:Disconnect() end)
                Fling.WatchedChars[char] = nil
            end
        end
    end

    -- Новая часть у персонажа (взятый инструмент, аксессуар) сразу сбрасывает кэш:
    -- раньше она оставалась твёрдой до истечения AntiFlingPartsTTL (1–3 с) — этим
    -- окном и пользовались флинги, раскрученные через инструмент
    Fling.WatchedChars = setmetatable({}, {__mode = "k"})
    function Fling.WatchCharParts(char)
        if Fling.WatchedChars[char] then return end
        Fling.WatchedChars[char] = Core.Connect(char.DescendantAdded, function(obj)
            if obj:IsA("BasePart") then Fling.CollisionPartsCache[char] = nil end
        end)
    end

    -- ─── Второй рубеж: защита своего корня ────────────────────────────────────────
    -- Снятие коллизии не помогает, если флинг считается не у нас (перехват network
    -- ownership) или бьёт не телом игрока. Поэтому каждый кадр перед физикой смотрим
    -- на результат: настоящая скорость корня, недостижимая обычной игрой и нашими
    -- фичами, — это удар. Отменяем: угловую в ноль, позицию и скорость — на последние
    -- нормальные. Стоит на RenderStep сразу после восстановлений Velocity Spoofer,
    -- Desync и невидимости (приоритет First) — видим настоящую скорость, а не подмену
    Fling.Guard = {BindName = "MM2_AntiFlingGuard", SafeCFrame = nil, SafeVelocity = Vector3.zero, Root = nil, NotifyAt = 0, Hits = 0}
    State.Runtime.FlingGuard = Fling.Guard   -- для замеров: Hits — сколько ударов отменено
    Fling.GuardLimits = {
        Horizontal = 150,   -- studs/s: обычный бег, Speed, стрейфы
        Rise = 180,         -- studs/s вверх: прыжки, в том числе bhop Jump Impulse
        Fall = 400,         -- studs/s вниз: падение с большой высоты
        Angular = 60,       -- рад/с: поворот корпуса и анимации так не крутят
    }

    -- Сейчас нас законно разгоняют свои механики — защиту не включаем
    function Fling.GuardPaused(character, humanoid, root)
        if Fling.SessionActive or State.Runtime.IsFlingInProgress or State.Runtime.WalkFlingActive then return true end
        if State.Settings.FlyEnabled or State.Settings.AutoFarmEnabled then return true end
        if root.Anchored or humanoid.Health <= 0 or humanoid.Sit or humanoid.PlatformStand then return true end
        return character:FindFirstChild("SpeedGlitchTool") ~= nil
    end

    -- Скорость корня за пределами обычной игры (или NaN — его дают экстремальные
    -- флинги, и обычные сравнения «>» его пропускали)
    function Fling.GuardViolation(root, velocity, angular)
        local limits = Fling.GuardLimits
        local horizontalLimit, riseLimit = limits.Horizontal, limits.Rise
        local movement = State.Runtime.MovementModule
        if movement and movement.State and movement.State.Enabled then
            local values = movement.State.Values or {}
            horizontalLimit = math.max(horizontalLimit, (tonumber(values.MaxSpeed) or 0) * 1.3 + 20)
            riseLimit = math.max(riseLimit, (tonumber(values.JumpImpulse) or 0) * 1.4)
        end
        if velocity ~= velocity or angular ~= angular or root.Position ~= root.Position then return true end
        local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        return horizontal > horizontalLimit or velocity.Y > riseLimit or velocity.Y < -limits.Fall
            or angular.Magnitude > limits.Angular
    end

    -- Сразу после физики: удар виден здесь, даже если к следующей проверке скорость
    -- успела погаснуть (врезались в стену, гуманоид затормозил), а персонажа уже
    -- унесло. Тогда новое место не должно стать «безопасным» — помечаем кадр
    function Fling.GuardAfterPhysics()
        local guard = Fling.Guard
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = humanoid and humanoid.RootPart
        if not root or root ~= guard.Root or Fling.GuardPaused(character, humanoid, root) then return end
        local velocity = State.Runtime.GetRealVelocity and State.Runtime.GetRealVelocity(root) or root.AssemblyLinearVelocity
        local angular = root.AssemblyAngularVelocity
        -- Chaos в Desync на Heartbeat сам шлёт фейковые линейную и угловую скорости (до
        -- тысяч studs/s) и откатывает их к следующему кадру. Если его Heartbeat уже
        -- отработал — снимаем подмену так же, как его откат: текущая − отправленная + настоящая
        local desync = State.Runtime.FakePositionRuntime
        if desync and desync.Root == root then
            if desync.VelSent and desync.VelReal then velocity = velocity - desync.VelSent + desync.VelReal end
            if desync.AngSent and desync.AngReal then angular = angular - desync.AngSent + desync.AngReal end
        end
        if Fling.GuardViolation(root, velocity, angular) then guard.Hit = true end
    end

    function Fling.GuardSelf()
        local guard = Fling.Guard
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = humanoid and humanoid.RootPart
        if not root then guard.Root, guard.SafeCFrame = nil, nil return end
        if guard.Root ~= root then
            guard.Root, guard.SafeCFrame, guard.SafeVelocity, guard.Hit = root, root.CFrame, Vector3.zero, false
        end
        if Fling.GuardPaused(character, humanoid, root) then
            guard.SafeCFrame, guard.SafeVelocity, guard.Hit = root.CFrame, Vector3.zero, false
            return
        end

        local velocity = State.Runtime.GetRealVelocity and State.Runtime.GetRealVelocity(root) or root.AssemblyLinearVelocity
        local flung = guard.Hit or Fling.GuardViolation(root, velocity, root.AssemblyAngularVelocity)
        guard.Hit = false

        if not flung then
            guard.SafeCFrame, guard.SafeVelocity = root.CFrame, velocity
            return
        end

        guard.Hits += 1
        root.AssemblyAngularVelocity = Vector3.zero
        -- NaN в сохранённой скорости (удар пришёлся на кадр записи) — просто стоп
        root.AssemblyLinearVelocity = guard.SafeVelocity == guard.SafeVelocity and guard.SafeVelocity or Vector3.zero
        if guard.SafeCFrame and (root.Position - guard.SafeCFrame.Position).Magnitude > 2 then
            root.CFrame = guard.SafeCFrame
        end
        local now = os.clock()
        if State.Settings.NotificationsEnabled and now >= guard.NotifyAt then
            guard.NotifyAt = now + 5
            ShowNotification("<font color=\"rgb(168,228,160)\">Anti-Fling </font><font color=\"rgb(220,220,220)\">blocked a fling</font>", CONFIG.Colors.Text)
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
        Fling.Guard.Root, Fling.Guard.SafeCFrame, Fling.Guard.Hit = nil, nil, false
        Fling.GuardHeartbeat = Core.Connect(RunService.Heartbeat, function()
            local ok, err = pcall(Fling.GuardAfterPhysics)
            if not ok then warn("[Anti-Fling] " .. tostring(err)) end
        end)
        TrackConnection(Fling.GuardHeartbeat)
        pcall(function()
            RunService:BindToRenderStep(Fling.Guard.BindName, Enum.RenderPriority.First.Value + 1, function()
                local ok, err = pcall(Fling.GuardSelf)
                if not ok then warn("[Anti-Fling] " .. tostring(err)) end
            end)
        end)
    end

    -- DisableAntiFling() - Отключение защиты
    local function DisableAntiFling()
        State.Settings.AntiFlingEnabled = false

        if Fling.AntiFlingConn then
            Fling.AntiFlingConn:Disconnect()
            Fling.AntiFlingConn = nil
        end
        pcall(function() RunService:UnbindFromRenderStep(Fling.Guard.BindName) end)
        if Fling.GuardHeartbeat then Fling.GuardHeartbeat:Disconnect(); Fling.GuardHeartbeat = nil end
        for char, conn in pairs(Fling.WatchedChars) do
            pcall(function() conn:Disconnect() end)
            Fling.WatchedChars[char] = nil
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




    -- ══════════════════════════════════════════════════════════════════════════════
    -- БЛОК 11: AUTO FARM SYSTEM
    -- ══════════════════════════════════════════════════════════════════════════════
    -- Вся служебная логика фарма — в таблице Farm (лимит 200 локалов главного чанка).
    -- Отличия от MainScript:
    --   • сумки валюты читаются с ремоутов игры, а не из рамки "Coin" с порогом 40 —
    --     ивенты меняют и валюту (Candy, SnowToken...), и лимит (Candy = 50);
    --   • режим раунда (Classic / Infection / FreezeTag) берётся из LoadingMap/RoleSelect;
    --   • не участник раунда (инжект в лобби, нас убили) не летает к монетам, а флингует
    --     мурдерера, чтобы раунд кончился быстрее;
    --   • пока идёт флинг (кнопки Fun-вкладки), фарм не трогает персонажа;
    --   • нет респавнов после конца раунда, которые раньше нужны были GodMode/инвизу.
    local Farm = {
        Bags = {},             -- [BagName] = {Collected, Limit}
        BagsLive = false,      -- false = в этом раунде данных с ремоутов ещё не было
        BagsGuiFallback = true,-- GUI-фолбэк валиден только до первого лобби после инжекта
        Mode = nil,            -- "Classic" | "Infection" | "FreezeTag" (nil — не знаем)
    }

    local function AddCoinToBlacklist(coin)
        State.Cache.CoinBlacklist[coin] = true
    end

    -- Очистка между раундами
    local function CleanupCoinBlacklist()
        for coin, _ in pairs(State.Cache.CoinBlacklist) do
            if not coin.Parent then
                State.Cache.CoinBlacklist[coin] = nil
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
        if not hrp or not humanoid or humanoid.Health <= 0 then
            return false
        end

        local oldBP = hrp:FindFirstChild("AFK_BodyPosition")
        if oldBP then oldBP:Destroy() end

        local bodyPos = Core.New("BodyPosition")
        bodyPos.Name = "AFK_BodyPosition"
        bodyPos.Position = hrp.Position
        bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyPos.D = 1250
        bodyPos.P = 10000
        bodyPos.Parent = hrp

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

    local function UnfloatCharacter()
        local character = LocalPlayer.Character
        if not character then return false end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        local bodyPos = hrp:FindFirstChild("AFK_BodyPosition")
        if bodyPos and bodyPos.Parent then bodyPos:Destroy() end

        local bodyGyro = hrp:FindFirstChild("AFK_BodyGyro")
        if bodyGyro and bodyGyro.Parent then bodyGyro:Destroy() end

        return true
    end

    local function FindSafeAFKSpot()
        local character = LocalPlayer.Character
        if not character then return nil end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            return nil
        end

        local map = nil
        for _, o in ipairs(Workspace:GetChildren()) do
            if o:FindFirstChild("CoinContainer") and o:FindFirstChild("Spawns") then
                map = o
                break
            end
        end

        local spawns = map and map:FindFirstChild("Spawns")
        local list = spawns and spawns:GetChildren() or {}
        if #list == 0 then
            return hrp.CFrame * CFrame.new(0, 300, 0)
        end

        local randomSpawn = list[math.random(1, #list)]
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

    -- ─── Сумки валюты ───────────────────────────────────────────────────────────
    -- Слушаем те же ремоуты, что и GUI игры (MainGUI.Game.CoinBags.CoinBagContainerScript):
    --   CoinsStarted(bags)              — старт раунда: {[Bag] = {CollectionLimit, CollectedAmount, CurrencyID}}
    --   CoinCollected(bag, got, limit)  — после каждой подобранной монеты
    -- Монета на карте несёт атрибут CoinID == имя её сумки: монеты полной сумки
    -- пропускаем, а не возим персонажа впустую.
    function Farm.ResetBags()
        Farm.Bags = {}
        Farm.BagsLive = false
        Farm.BagsGuiFallback = false
    end

    -- Фолбэк для инжекта посреди раунда (CoinsStarted уже пролетел): видимые рамки
    -- сумок в GUI игры. Лимита там нет, но есть надпись "Full!". После первого же
    -- лобби фолбэк выключается — игра не сбрасывает "Full!" до следующего раунда.
    function Farm.ReadBagsFromGui()
        local bags = {}
        if not Farm.BagsGuiFallback then return bags end
        pcall(function()
            local container = LocalPlayer.PlayerGui.MainGUI.Game.CoinBags.Container
            for _, frame in ipairs(container:GetChildren()) do
                if frame:IsA("Frame") and frame.Visible then
                    local full = frame:FindFirstChild("Full")
                    bags[frame.Name] = {Full = full ~= nil and full.Visible}
                end
            end
        end)
        return bags
    end

    function Farm.IsBagFull(bagName)
        if Farm.BagsLive then
            local bag = Farm.Bags[bagName]
            return bag ~= nil and bag.Limit ~= nil and bag.Collected >= bag.Limit
        end
        local bag = Farm.ReadBagsFromGui()[bagName]
        return bag ~= nil and bag.Full
    end

    -- true, когда собирать больше нечего: все активные сумки раунда заполнены
    function Farm.AreAllBagsFull()
        local any = false
        if Farm.BagsLive then
            for _, bag in pairs(Farm.Bags) do
                any = true
                if not (bag.Limit and bag.Collected >= bag.Limit) then return false end
            end
            return any
        end
        for _, bag in pairs(Farm.ReadBagsFromGui()) do
            any = true
            if not bag.Full then return false end
        end
        return any
    end

    function Farm.IsCoinWanted(coin)
        local bagName = coin:GetAttribute("CoinID")
        if type(bagName) ~= "string" then return true end
        return not Farm.IsBagFull(bagName)
    end

    -- ─── Режим раунда и участие ─────────────────────────────────────────────────
    local ROLE_MODES = {Zombie = "Infection", Survivor = "Infection", Freezer = "FreezeTag", Runner = "FreezeTag"}

    function Farm.RoundMode()
        if Farm.Mode then return Farm.Mode end
        -- Инжект посреди раунда: LoadingMap/RoleSelect уже пролетели — режим по ролям
        for _, data in pairs(State.Cache.PlayerData or {}) do
            local mode = type(data) == "table" and ROLE_MODES[data.Role]
            if mode then return mode end
        end
        return "Classic"
    end

    function Farm.MyData()
        local data = State.Cache.PlayerData
        return type(data) == "table" and data[LocalPlayer.Name] or nil
    end

    -- Участник ли мы текущего раунда. Нет данных вообще — не мешаем (считаем участником)
    function Farm.IsParticipant()
        local data = State.Cache.PlayerData
        if type(data) ~= "table" or next(data) == nil then return true end
        local me = data[LocalPlayer.Name]
        if type(me) ~= "table" then return false end
        return me.Dead ~= true
    end

    function Farm.IsZombie(player)
        local character = player and player.Character
        if character and character:GetAttribute("Zombie") == true then return true end
        local data = State.Cache.PlayerData
        local entry = type(data) == "table" and player and data[player.Name]
        return type(entry) == "table" and entry.Role == "Zombie" and entry.Dead ~= true
    end

    function Farm.RoundActive()
        return getMurderForAutoFarm() ~= nil
    end

    -- Пока пользователь флингует (кнопки Fling Murderer/Sheriff/Selected), фарм не
    -- пишет CFrame и снимает левитацию — иначе флинг перебивается каждый кадр
    function Farm.FlingBusy()
        return Fling.SessionActive == true or State.Runtime.IsFlingInProgress == true
    end

    function Farm.WaitFlingIdle()
        if not Farm.FlingBusy() then return end
        pcall(UnfloatCharacter)
        pcall(DisableNoClip)
        repeat task.wait(0.1) until not Farm.FlingBusy() or not State.Settings.AutoFarmEnabled
    end

    -- Точка в лобби: после раунда, если мы висели на левитации над картой. Раньше
    -- левитацию снимали сразу — карту к этому моменту уже убрали, и персонаж падал
    -- в пустоту (жалоба: «закончил раунд с пистолетом — полетел вниз и умер»)
    function Farm.LobbySpawn()
        local lobby = Workspace:FindFirstChild("Lobby")
        local spawns = lobby and lobby:FindFirstChild("Spawns")
        local list = spawns and spawns:GetChildren() or {}
        for _ = 1, #list do
            local pick = list[math.random(1, #list)]
            local part = pick:IsA("BasePart") and pick or pick:FindFirstChildWhichIsA("BasePart", true)
            if part then return part.CFrame + Vector3.new(0, 4, 0) end
        end
        return nil
    end

    function Farm.ReturnToLobby()
        pcall(function()
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if hrp and hrp:FindFirstChild("AFK_BodyPosition") then
                local spawnCFrame = Farm.LobbySpawn()
                if spawnCFrame then
                    hrp.CFrame = spawnCFrame
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end)
        pcall(UnfloatCharacter)
    end

    function Farm.InvisibleWhileWaiting()
        if State.Settings.AutoFarmEnabled and not State.Settings.IsInvisible
            and not State.Runtime.AutoVoteSuppressInvis and not Farm.FlingBusy() then
            pcall(function() ToggleInvisibility() end)
        end
    end

    function Farm.WaitRoundEnd()
        repeat task.wait(1) until not Farm.RoundActive() or not State.Settings.AutoFarmEnabled
    end

    function Farm.WaitNewRound()
        repeat
            Farm.InvisibleWhileWaiting()
            task.wait(1)
        until Farm.RoundActive() or not State.Settings.AutoFarmEnabled
    end

    -- Раунд закончился: сумки и чёрный список больше не актуальны, с левитации — в лобби
    function Farm.OnRoundEnd()
        Farm.ResetBags()
        Farm.ReturnToLobby()
        CleanupCoinBlacklist()
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
            and not State.Cache.CoinBlacklist[coin]
            and Farm.IsCoinWanted(coin) then

                if coin:FindFirstChild("CoinVisual") then
                    local distance = (coin.Position - hrpPosition).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestCoin = coin
                    end
                end
            end
        end

        return closestCoin, closestDistance
    end

    -- Быстрая проверка на более близкую монету
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
            and not State.Cache.CoinBlacklist[coin]
            and Farm.IsCoinWanted(coin) then

                if coin:FindFirstChild("CoinVisual") then
                    local distance = (coin.Position - hrpPosition).Magnitude
                    if distance < (currentDistance - threshold) then
                        return coin, distance
                    end
                end
            end
        end

        return nil
    end

    -- firetouchinterest по монете, которую уже убрали, кидает «new overlap in
    -- different world» — касание оборачиваем
    function Farm.Touch(hrp, coin)
        if not firetouchinterest then return end
        pcall(firetouchinterest, hrp, coin, 0)
        task.wait(0.05)
        pcall(firetouchinterest, hrp, coin, 1)
    end

    -- Длительность перелёта. Smart Collect: на больших картах дальняя монета
    -- съедала много времени при обычной скорости — такой перелёт укладываем в
    -- случайные MinTime..MaxTime секунд (как средний перелёт со скоростью ~23,
    -- ~1 монета за 2-3 с), ближние летим как обычно
    function Farm.FlightDuration(distance, speed)
        local duration = distance / math.max(speed, 1)
        if State.Settings.SmartCollectEnabled then
            local cfg = CONFIG.SmartCollect
            local cap = cfg.MinTime + math.random() * (cfg.MaxTime - cfg.MinTime)
            if duration > cap then duration = cap end
        end
        return duration
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
        local duration = Farm.FlightDuration(distance, speed)

        local startTime = tick()
        local collectionAttempted = false

        local lastCheckTime = tick()
        local checkInterval = 0.3

        while tick() - startTime < duration do
            if not State.Settings.AutoFarmEnabled then break end
            -- Флинг пользователя важнее: отдаём ему персонажа
            if Farm.FlingBusy() then return false, nil end

            if not coin or not coin.Parent then
                return false, nil
            end
            if not coin:FindFirstChild("CoinVisual") then
                return false, nil
            end
            if not coin:FindFirstChildWhichIsA("TouchTransmitter") then
                return false, nil
            end

            local character = LocalPlayer.Character
            if not character or not humanoidRootPart.Parent then break end

            -- Динамическая проверка на более близкую монету
            local currentTime = tick()
            if currentTime - lastCheckTime >= checkInterval then
                lastCheckTime = currentTime

                local currentDistance = (humanoidRootPart.Position - coin.Position).Magnitude
                local betterCoin = FindBetterCoin(coin, currentDistance, 10)
                if betterCoin then
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
            humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
            humanoidRootPart.AssemblyAngularVelocity = Vector3.zero

            if alpha >= 0.90 and not collectionAttempted then
                collectionAttempted = true
                Core.Tasks.spawn(Farm.Touch, humanoidRootPart, coin)
            end

            task.wait()
        end

        if State.Settings.UndergroundMode and humanoidRootPart.Parent then
            humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position) * CFrame.Angles(math.rad(90), 0, 0)
        end

        return true, nil
    end

    local shootMurderer
    local InstantKillAll
    local knifeThrow

    -- ─── Сбор одной монеты (первая — телепортом, дальше — полётом) ─────────────
    function Farm.CollectStep(ctx, character, humanoidRootPart)
        local coin = FindNearestCoin()
        if not coin then
            ctx.noCoins += 1
            if ctx.noCoins < ctx.maxNoCoins then task.wait(0.3) end
            return
        end
        ctx.noCoins = 0

        CreateCoinTracer(character, coin)

        pcall(function()
            if not ctx.allowFly then
                local sinceTP = tick() - ctx.lastTeleport
                if sinceTP < State.Settings.CoinFarmDelay and ctx.lastTeleport > 0 then
                    task.wait(State.Settings.CoinFarmDelay - sinceTP)
                end
                if Farm.FlingBusy() then return end

                if State.Settings.AutoFarmEnabled and State.Settings.IsInvisible then
                    pcall(function() ToggleInvisibility() end)
                end
                local targetCFrame = coin.CFrame + Vector3.new(0, 2, 0)
                if targetCFrame.Position.Y > -500 and targetCFrame.Position.Y < 10000 then
                    humanoidRootPart.CFrame = targetCFrame
                    ctx.lastTeleport = tick()
                    Farm.Touch(humanoidRootPart, coin)
                    task.wait(0.2)
                    RemoveCoinTracer()
                    AddCoinToBlacklist(coin)
                    ctx.allowFly = true
                end
            else
                EnableNoClip()
                local target = coin
                local redirects = 0
                while target and redirects < 5 do
                    local result, newTarget = SmoothFlyToCoin(target, humanoidRootPart, State.Settings.CoinFarmFlySpeed)
                    if result == "switch" and newTarget then
                        RemoveCoinTracer()
                        CreateCoinTracer(character, newTarget)
                        target = newTarget
                        redirects += 1
                    else
                        break
                    end
                end
                RemoveCoinTracer()
                if target then AddCoinToBlacklist(target) end
            end
        end)
    end

    -- ─── Не участник раунда: флинг мурдерера вместо ожидания конца раунда ──────
    function Farm.SpectatorPhase()
        pcall(DisableNoClip)
        pcall(UnfloatCharacter)
        if Farm.RoundMode() == "Classic" then
            local cfg = CONFIG.SpectatorFling
            local attempts = 0
            while Farm.RoundActive() and State.Settings.AutoFarmEnabled and attempts < cfg.MaxAttempts do
                Farm.WaitFlingIdle()
                if Farm.IsParticipant() then return end   -- новый раунд, мы снова в игре
                local murderer = getMurderForAutoFarm()
                if not murderer or murderer == LocalPlayer then break end
                local root = murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart")
                if root and root.AssemblyLinearVelocity.Magnitude > 500 then
                    task.wait(1)            -- уже летит — не мешаем
                elseif root then
                    -- Невидимость прячет нас под картой: для контактного флинга она мешает
                    if State.Settings.IsInvisible then pcall(function() ToggleInvisibility() end) end
                    pcall(FlingMurderer)
                    attempts += 1
                    task.wait(cfg.Interval)
                else
                    task.wait(0.5)
                end
            end
        end
        Farm.WaitRoundEnd()
    end

    -- ─── Infection: сумка полна ─────────────────────────────────────────────────
    -- Survivor → встаём вплотную к ножу зомби, чтобы его удар гарантированно задел
    -- (после заражения мы сами зомби). Зомби → InstantKillAll по выжившим раз в
    -- KillAllEvery, как мурдерер в классике.
    function Farm.NearestZombie(skip)
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local best, bestDistance = nil, math.huge
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player ~= skip and Farm.IsZombie(player) then
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if root and humanoid and humanoid.Health > 0 then
                    local distance = (root.Position - hrp.Position).Magnitude
                    if distance < bestDistance then best, bestDistance = player, distance end
                end
            end
        end
        return best
    end

    function Farm.InfectionEndgame()
        local cfg = CONFIG.Infection
        pcall(DisableNoClip)
        pcall(UnfloatCharacter)
        if State.Settings.IsInvisible then pcall(function() ToggleInvisibility() end) end

        local lastZombie = nil
        while Farm.RoundActive() and State.Settings.AutoFarmEnabled do
            Farm.WaitFlingIdle()
            if Farm.IsZombie(LocalPlayer) then
                pcall(function() InstantKillAll(true) end)
                task.wait(cfg.KillAllEvery)
            elseif not Farm.IsParticipant() then
                break
            else
                local zombie = Farm.NearestZombie(lastZombie) or Farm.NearestZombie()
                if not zombie then
                    task.wait(0.5)
                else
                    lastZombie = zombie
                    local untilTime = tick() + cfg.MagnetTime
                    while tick() < untilTime and Farm.RoundActive() and State.Settings.AutoFarmEnabled
                        and not Farm.IsZombie(LocalPlayer) and not Farm.FlingBusy() do
                        local character = LocalPlayer.Character
                        local hrp = character and character:FindFirstChild("HumanoidRootPart")
                        local zchar = zombie.Character
                        local zroot = zchar and zchar:FindFirstChild("HumanoidRootPart")
                        if not hrp or not zroot then break end
                        -- Точка удара — нож в руке зомби; без ножа в руке — перед лицом
                        local knife = zchar:FindFirstChild("Knife")
                        local handle = knife and knife:FindFirstChild("Handle")
                        local anchor = handle and handle.Position or (zroot.CFrame * CFrame.new(0, 0, -2)).Position
                        hrp.CFrame = CFrame.lookAt(anchor, zroot.Position)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                        task.wait()
                    end
                end
            end
        end
        Farm.WaitRoundEnd()
    end

    -- ─── Classic + XP Farm: сумка полна ─────────────────────────────────────────
    function Farm.XPEndgame()
        local murderer = getMurderForAutoFarm()
        local sheriff = getSheriffForAutoFarm()

        if murderer == LocalPlayer or sheriff == LocalPlayer then
            -- Мурдерер/шериф пережидают на левитации над картой, вне досягаемости
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            local safeSpot = hrp and FindSafeAFKSpot()
            if safeSpot then
                hrp.CFrame = safeSpot + Vector3.new(0, 5, 0)
                task.wait(0.5)
                FloatCharacter()
                task.wait(0.5)
            end
        end

        if murderer == LocalPlayer then
            if Farm.RoundActive() and State.Settings.AutoFarmEnabled and State.Settings.XPFarmEnabled then
                pcall(function() InstantKillAll() end)
            end
        elseif sheriff == LocalPlayer then
            local shots = 0
            while Farm.RoundActive() and State.Settings.AutoFarmEnabled and State.Settings.XPFarmEnabled and shots < 30 do
                Farm.WaitFlingIdle()
                local target = getMurderForAutoFarm()
                if not target or not LocalPlayer.Character then break end
                if not target.Character then
                    task.wait(0.5)
                elseif State.Settings.CanShootMurderer then
                    shots += 1
                    pcall(function() shootMurderer(true) end)
                    task.wait(State.Settings.ShootCooldown + 0.1)
                else
                    task.wait(0.5)
                end
            end
        else
            -- Инносент: флинг мурдерера (без левитации — она перебивает флинг)
            local attempts = 0
            while Farm.RoundActive() and State.Settings.AutoFarmEnabled and State.Settings.XPFarmEnabled and attempts < 10 do
                Farm.WaitFlingIdle()
                local target = getMurderForAutoFarm()
                if not target then break end
                local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if not root then
                    task.wait(0.5)
                elseif root.AssemblyLinearVelocity.Magnitude > 500 then
                    break
                elseif root.AssemblyLinearVelocity.Magnitude > 100 then
                    task.wait(1)
                else
                    if State.Settings.IsInvisible then pcall(function() ToggleInvisibility() end) end
                    pcall(FlingMurderer)
                    attempts += 1
                    task.wait(attempts == 1 and 1 or 3)
                end
            end
        end
        Farm.WaitRoundEnd()
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
            local ctx = {allowFly = false, noCoins = 0, maxNoCoins = 4, lastTeleport = 0, inRound = false}

            local function resetRound()
                State.Cache.CoinBlacklist = {}
                ctx.noCoins = 0
                ctx.allowFly = false
            end

            Farm.InvisibleWhileWaiting()

            while State.Settings.AutoFarmEnabled do
                local character = LocalPlayer.Character
                local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
                if not humanoidRootPart then
                    task.wait(0.5)
                    continue
                end

                Farm.WaitFlingIdle()

                if not Farm.RoundActive() then
                    -- Лобби: раунд кончился (или ещё не начался)
                    if ctx.inRound or Farm.BagsGuiFallback then
                        ctx.inRound = false
                        Farm.OnRoundEnd()
                    end
                    resetRound()
                    Farm.InvisibleWhileWaiting()
                    task.wait(1)
                    continue
                end
                ctx.inRound = true

                -- Инжект в лобби посреди раунда или нас убили, а раунд идёт
                if not Farm.IsParticipant() then
                    Farm.SpectatorPhase()
                    if not State.Settings.AutoFarmEnabled then break end
                    if not Farm.RoundActive() then
                        ctx.inRound = false
                        Farm.OnRoundEnd()
                    end
                    resetRound()
                    continue
                end

                if Farm.AreAllBagsFull() then
                    ctx.noCoins = ctx.maxNoCoins
                else
                    Farm.CollectStep(ctx, character, humanoidRootPart)
                end

                if ctx.noCoins >= ctx.maxNoCoins then
                    pcall(DisableNoClip)
                    local mode = Farm.RoundMode()

                    if mode == "Infection" then
                        Farm.InfectionEndgame()
                    elseif mode == "FreezeTag" then
                        Farm.WaitRoundEnd()
                    elseif State.Settings.XPFarmEnabled then
                        Farm.XPEndgame()
                    else
                        -- Без XP: выходим из раунда сразу, чтобы не рисковать сумкой
                        pcall(UnfloatCharacter)
                        ResetCharacter()
                        Farm.WaitRoundEnd()
                    end

                    if not State.Settings.AutoFarmEnabled then break end
                    ctx.inRound = false
                    Farm.OnRoundEnd()
                    resetRound()
                    Farm.WaitNewRound()
                    if not State.Settings.AutoFarmEnabled then break end
                    resetRound()
                end
            end

            State.Runtime.CoinFarmThread = nil
        end)
    end

    local function StopAutoFarm()
        RemoveCoinTracer()
        State.Settings.AutoFarmEnabled = false

        if State.Runtime.CoinFarmThread then
            task.cancel(State.Runtime.CoinFarmThread)
            State.Runtime.CoinFarmThread = nil
        end

        pcall(UnfloatCharacter)
        pcall(DisableNoClip)
        State.Cache.CoinBlacklist = {}
    end

    -- ─── Слежка за раундом: сумки, режим, данные игроков ───────────────────────
    -- Запускается при старте (ЗАПУСК СКРИПТА). Remotes проверены на живом клиенте:
    -- ReplicatedStorage.Remotes.Gameplay.{CoinsStarted, CoinCollected, LoadingMap,
    -- RoleSelect, GameOver, GetCurrentPlayerData}
    State.Runtime.SetupRoundTracking = function()
        local gameplay = nil
        pcall(function()
            gameplay = ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("Gameplay", 10)
        end)
        if not gameplay then return end

        local started = gameplay:FindFirstChild("CoinsStarted")
        if started then
            Core.Connect(started.OnClientEvent, function(bags)
                local fresh = {}
                if type(bags) == "table" then
                    for name, info in pairs(bags) do
                        if type(info) == "table" then
                            fresh[tostring(name)] = {
                                Collected = tonumber(info.CollectedAmount) or 0,
                                Limit = tonumber(info.CollectionLimit),
                            }
                        end
                    end
                end
                Farm.Bags = fresh
                Farm.BagsLive = true
            end)
        end

        local collected = gameplay:FindFirstChild("CoinCollected")
        if collected then
            Core.Connect(collected.OnClientEvent, function(bagName, got, limit)
                if type(bagName) ~= "string" then return end
                local bag = Farm.Bags[bagName] or {}
                bag.Collected = tonumber(got) or bag.Collected or 0
                bag.Limit = tonumber(limit) or bag.Limit
                Farm.Bags[bagName] = bag
                Farm.BagsLive = true
            end)
        end

        -- Режим раунда: LoadingMap(mode) перед загрузкой карты, 5-й аргумент RoleSelect
        local loading = gameplay:FindFirstChild("LoadingMap")
        if loading then
            Core.Connect(loading.OnClientEvent, function(mode)
                if type(mode) == "string" then Farm.Mode = mode end
            end)
        end
        local roleSelect = gameplay:FindFirstChild("RoleSelect")
        if roleSelect then
            Core.Connect(roleSelect.OnClientEvent, function(...)
                local mode = select(5, ...)
                if type(mode) == "string" then Farm.Mode = mode end
            end)
        end

        -- Конец раунда: престиж и покупка тиров пасса (оба сами проверяют свои тумблеры)
        local gameOver = gameplay:FindFirstChild("GameOver")
        if gameOver then
            Core.Connect(gameOver.OnClientEvent, function()
                Farm.Mode = nil
                if State.Runtime.CheckAndPrestige then Core.Tasks.delay(3, State.Runtime.CheckAndPrestige) end
                if State.Runtime.BattlePassTick then Core.Tasks.delay(5, State.Runtime.BattlePassTick) end
            end)
        end

        -- Инжект посреди раунда: PlayerDataChanged уже пролетел — спрашиваем сервер
        local current = gameplay:FindFirstChild("GetCurrentPlayerData")
        if current and current:IsA("RemoteFunction") then
            local ok, data = pcall(function() return current:InvokeServer() end)
            if ok and type(data) == "table" and next(State.Cache.PlayerData or {}) == nil then
                State.Cache.PlayerData = data
            end
        end
    end

    -- ══════════════════════════════════════════════════════════════════════════════
    -- XP FARM SYSTEM
    -- ══════════════════════════════════════════════════════════════════════════════

    -- XP Farm — флаг для автофарма: он сам решает, что делать с полной сумкой
    local function StartXPFarm()
        State.Settings.XPFarmEnabled = true
    end

    local function StopXPFarm()
        State.Settings.XPFarmEnabled = false
        pcall(function()
            UnfloatCharacter()
        end)
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
        local spawnedNear = false   -- Spawn Knife Near Player нашёл цель — silent не нужен

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
                    spawnedNear = true
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

        -- Silent Knife: из руки в упреждённую точку цели у курсора. На бинде приоритет
        -- у Spawn Knife Near Player; без цели в FOV бросок остаётся по мыши
        if not spawnedNear and State.Settings.SilentKnifeEnabled then
            local ok, aimPoint = pcall(State.Runtime.SilentKnifeAim, spawnPosition, knife)
            if ok and aimPoint then targetPosition = aimPoint end
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
        -- Флаг: хук Silent Knife не трогает наш бросок (точку выбрали выше)
        State.Runtime.SilentKnifeOwnCall = true
        local success, err = pcall(function()
            LocalPlayer.Character.Knife.Events.KnifeThrown:FireServer(unpack(argsThrowRemote))
        end)
        State.Runtime.SilentKnifeOwnCall = false

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
    -- maxT — потолок упреждения: 0.25 с для хитскана (отсекаем выбросы пинга), у
    -- броска ножа больше — к пингу прибавляется время полёта снаряда
    local function predictAimPoint(hrp, thum, t, maxT)
        t = math.clamp(t, 0.03, maxT or 0.25)
        local pos = hrp.Position
        local vel = hrp.AssemblyLinearVelocity
        -- Вертикаль быстрее обычного прыжка вверх — Anti-Aim спуф или флинг: парабола
        -- по ней увела бы прицел в небо. Падение не трогаем (пол ниже его ограничит)
        if vel.Y > CONFIG.SilentKnife.MaxRiseSpeed then vel = Vector3.new(vel.X, 0, vel.Z) end
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
    local function computeAimPoint(char, hrp, thum, t, maxT)
        local predictedHRP = predictAimPoint(hrp, thum, t, maxT)
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
            -- Без extra параметры одинаковы для всех лучей кадра: собираем их не чаще
            -- MapParamsTTL (обход всего Workspace и новый RaycastParams на каждый луч дороги)
            local cache = Aim.MapParamsCache
            if not extra and cache and os.clock() - cache.Time < SA.MapParamsTTL then return cache.Params end
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
            if not extra then Aim.MapParamsCache = {Time = os.clock(), Params = params} end
            return params
        end

        local function resetTrack(target)
            if target ~= Aim.Target and Aim.ResetDiag then Aim.ResetDiag() end
            Aim.Target = target
            table.clear(Aim.Samples); table.clear(Aim.Segments); table.clear(Aim.Jumps)
            table.clear(Aim.Suspects)
            table.clear(Aim.SegTimes); table.clear(Aim.Checks); table.clear(Aim.Errors)
            Aim.ErrorsDirty, Aim.NextTrack = true, 0
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
                    Aim.ErrorsDirty = true
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
            while Aim.Errors[1] and now - Aim.Errors[1][1] > SC.Window do
                table.remove(Aim.Errors, 1)
                Aim.ErrorsDirty = true
            end
            -- Перцентили пересчитываем только при новых/устаревших ошибках, а не каждый кадр
            if Aim.ErrorsDirty then
                Aim.ErrorsDirty = false
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
        -- Список частей-хитбоксов персонажа живёт HitboxPartsTTL: обход всех потомков
        -- (аксессуары) на каждую оценку Auto Fire был самой частой работой. CFrame и
        -- размер читаем каждый раз заново — кэшируется только состав
        local HitboxPartsTTL = 0.5
        local function hitboxes(char)
            local cache = Aim.HitboxCache
            if not cache or cache.Char ~= char or os.clock() - cache.Time > HitboxPartsTTL then
                local parts = {}
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.CanQuery
                        and not part:FindFirstAncestorOfClass("Tool") then
                        table.insert(parts, part)
                    end
                end
                cache = {Char = char, Time = os.clock(), Parts = parts}
                Aim.HitboxCache = cache
            end
            local boxes = {}
            for _, part in ipairs(cache.Parts) do
                if part.Parent then
                    local half = part.Size / 2 - Vector3.one * SA.PartMargin
                    table.insert(boxes, {cf = part.CFrame,
                        half = Vector3.new(math.max(half.X, 0.05), math.max(half.Y, 0.05), math.max(half.Z, 0.05))})
                end
            end
            return boxes
        end

        -- Одна ось slab-метода: сужает [tmin, tmax]; nil — луч мимо
        local function slab(p, d, e, tmin, tmax)
            if math.abs(d) < 1e-8 then
                if math.abs(p) > e then return nil end
                return tmin, tmax
            end
            local t1, t2 = (-e - p) / d, (e - p) / d
            if t1 > t2 then t1, t2 = t2, t1 end
            if t1 > tmin then tmin = t1 end
            if t2 < tmax then tmax = t2 end
            if tmin > tmax then return nil end
            return tmin, tmax
        end

        -- Луч против OBB (slab-метод) в локальных координатах коробки: lo — начало луча,
        -- ld — единичное направление, maxT — длина. Без таблиц и строковых индексов:
        -- вызывается сотни раз на одну оценку Auto Fire
        local function rayHitsBox(lo, ld, maxT, half)
            local tmin, tmax = slab(lo.X, ld.X, half.X, 0, maxT)
            if not tmin then return false end
            tmin, tmax = slab(lo.Y, ld.Y, half.Y, tmin, tmax)
            if not tmin then return false end
            return slab(lo.Z, ld.Z, half.Z, tmin, tmax) ~= nil
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
            -- Сдвиг коробки на shift ≡ сдвиг начала луча на -shift: направление в
            -- локальных осях каждой коробки считаем один раз на вызов, без новых CFrame
            local localDirs = table.create(#boxes)
            for i, box in ipairs(boxes) do localDirs[i] = box.cf:VectorToObjectSpace(dir) end
            local chance = 0
            for _, s in ipairs(scenarios) do
                for k, offset in ipairs(offsets) do
                    local shift = s.disp + (offset ~= 0 and side * (offset * blur) or Vector3.zero)
                    local from = origin - shift
                    for i, box in ipairs(boxes) do
                        if rayHitsBox(box.cf:PointToObjectSpace(from), localDirs[i], maxT, box.half) then
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
                if rayHitsBox(box.cf:PointToObjectSpace(info.origin), box.cf:VectorToObjectSpace(dir), distance + 12, box.half) then obs.onTarget = true break end
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
                        if rayHitsBox(box.cf:PointToObjectSpace(info.origin), box.cf:VectorToObjectSpace(dir), distance, box.half) then obs.blocker = player.Name break end
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
            if now >= (Aim.NextTrack or 0) then
                Aim.NextTrack = now + SA.TrackInterval
                local ok, err = pcall(track, now)
                if not ok then warn("[Sheriff Aim] " .. tostring(err)) return end
                ok, err = pcall(selfCheck, now)
                if not ok then warn("[Sheriff Aim] " .. tostring(err)) end
            end
            settlePending(now)
            if armed then
                local ok, err = pcall(autoFire, now)
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


    InstantKillAll = function(quiet)
        -- В Infection нож у каждого зомби: бьём выживших, своих (зомби) пропускаем
        local myCharacter = LocalPlayer.Character
        local asZombie = myCharacter ~= nil and myCharacter:GetAttribute("Zombie") == true
        local murderer = getMurder()
        if murderer ~= LocalPlayer and not asZombie then
            if not quiet and State.Settings.NotificationsEnabled then
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
            if player ~= LocalPlayer and player.Character
                and not (asZombie and player.Character:GetAttribute("Zombie") == true) then
                local targetPart = player.Character:FindFirstChild("UpperTorso") or player.Character:FindFirstChild("Torso")
                if targetPart then
                    pcall(function() handleTouched:FireServer(targetPart) end)
                    killCount = killCount + 1
                    task.wait(0.05)
                end
            end
        end

        if not quiet and State.Settings.NotificationsEnabled then
            ShowNotification(
                "<font color=\"rgb(220,220,220)\">InstantKillAll:</font> <font color=\"rgb(168,228,160)\">Killed " .. killCount .. " players</font>",
                CONFIG.Colors.Green
            )
        end
    end

    -- ══════════════════════════════════════════════════════════════════════════════
    -- БЛОК 16: VIEW CLIP & TELEPORT
    -- ══════════════════════════════════════════════════════════════════════════════

    -- Пружина зума для Invisicam. Та же критически задемпфированная пружина, что
    -- ConstrainedSpring:Step в ZoomController. Двигаем камеру только вдоль взгляда,
    -- поэтому поворот (его CameraModule берёт из Camera.CFrame) не страдает
    do
        local VZ = CONFIG.ViewClipZoom
        local bound = false
        local zoomX, zoomV = nil, 0

        local function step(dt)
            local camera = Workspace.CurrentCamera
            if not camera or camera.CameraType ~= Enum.CameraType.Custom then
                zoomX, zoomV = nil, 0
                return
            end
            local cf = camera.CFrame
            local look = cf.LookVector
            -- Дистанция по оси взгляда, а не модуль: при shift-lock камера смещена вбок от Focus
            local goal = (camera.Focus.Position - cf.Position):Dot(look)
            if goal ~= goal or goal <= 0 then
                zoomX, zoomV = nil, 0
                return
            end
            if not zoomX then
                zoomX, zoomV = goal, 0
                return
            end
            local f = VZ.Stiffness * 2 * math.pi
            local offset = goal - zoomX
            local s = f * dt
            local decay = math.exp(-s)
            zoomX = goal + (zoomV * dt - offset * (s + 1)) * decay
            zoomV = ((offset * f - zoomV) * s + zoomV) * decay
            camera.CFrame = cf + look * (goal - zoomX)
        end

        local function unbind()
            if bound then
                pcall(function() RunService:UnbindFromRenderStep(VZ.BindName) end)
                bound = false
            end
            zoomX, zoomV = nil, 0
        end

        local function bind()
            if bound then return end
            -- Camera+1: после CameraModule, до Aspect Ratio (Camera+2), который сжимает матрицу
            bound = pcall(function()
                RunService:BindToRenderStep(VZ.BindName, Enum.RenderPriority.Camera.Value + 1, step)
            end)
            if not bound then warn("[Violite] ViewClip: BindToRenderStep недоступен, зум без сглаживания") end
        end

        -- EnableViewClip() - DevCameraOcclusionMode.Invisicam + своя пружина зума
        function Core.Movement.EnableViewClip()
            State.Settings.ViewClipEnabled = true
            LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
            bind()
        end

        -- DisableViewClip() - DevCameraOcclusionMode.Zoom (пружину снова ведёт Poppercam)
        function Core.Movement.DisableViewClip()
            State.Settings.ViewClipEnabled = false
            LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
            unbind()
        end
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

    -- Возврат корня из-под карты. Раньше шёл через RenderStepped:Wait() — уже после
    -- шагов на RenderStep (bhop на Camera+1, локальный Spin на Camera+2): они видели
    -- корень на 200000 studs ниже — bhop не находил пол, копия Spin улетала вниз.
    -- Теперь возврат первым на RenderStep и страховкой перед физикой
    Core.Invisibility.BindName = "MM2_InvisibilityRestore"
    function Core.Invisibility.Restore()
        local frame = Core.Invisibility.Frame
        if not frame then return end
        Core.Invisibility.Frame = nil
        if frame.Root.Parent then frame.Root.CFrame = frame.CFrame end
        if frame.Humanoid.Parent then frame.Humanoid.CameraOffset = frame.Offset end
    end

    ToggleInvisibility = function()
        State.Settings.IsInvisible = not State.Settings.IsInvisible

        if State.Settings.IsInvisible then
            if InvisibilityConnection then InvisibilityConnection:Disconnect() end
            if Core.Invisibility.PreSim then Core.Invisibility.PreSim:Disconnect() end
            pcall(function() RunService:UnbindFromRenderStep(Core.Invisibility.BindName) end)
            pcall(function()
                RunService:BindToRenderStep(Core.Invisibility.BindName, Enum.RenderPriority.First.Value, function()
                    pcall(Core.Invisibility.Restore)
                end)
            end)
            Core.Invisibility.PreSim = Core.Connect(RunService.PreSimulation, function()
                pcall(Core.Invisibility.Restore)
            end)

            InvisibilityConnection = Core.Connect(RunService.Heartbeat, function()
                if not State.Settings.IsInvisible then return end
                -- Флинг (кнопки Fun-вкладки, флинг мурдерера автофармом) идёт контактом:
                -- пока он работает, тело не прячем под карту
                if Fling.SessionActive then Core.Invisibility.Restore() return end

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

                -- Heartbeat может сработать дважды без отрисовки: сначала вернуть прошлый сдвиг
                Core.Invisibility.Restore()

                local OriginalCFrame       = RootPart.CFrame
                local OriginalCameraOffset = Humanoid.CameraOffset
                local NewCFrame            = OriginalCFrame * CFrame.new(0, -INVIS_DEPTH, 0)

                Core.Invisibility.Frame = {Root = RootPart, Humanoid = Humanoid, CFrame = OriginalCFrame, Offset = OriginalCameraOffset}
                RootPart.CFrame     = NewCFrame
                Humanoid.CameraOffset = NewCFrame:ToObjectSpace(CFrame.new(OriginalCFrame.Position)).Position
            end)

            if State.Settings.NotificationsEnabled then
                ShowNotification("<font color=\"rgb(220,220,220)\">Invisibility</font> <font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Text)
            end
        else
            if InvisibilityConnection then
                InvisibilityConnection:Disconnect()
                InvisibilityConnection = nil
            end

            if Core.Invisibility.PreSim then Core.Invisibility.PreSim:Disconnect(); Core.Invisibility.PreSim = nil end
            pcall(function() RunService:UnbindFromRenderStep(Core.Invisibility.BindName) end)
            Core.Invisibility.Character = nil
            if Core.Invisibility.Added then Core.Invisibility.Added:Disconnect(); Core.Invisibility.Added = nil end
            pcall(Core.Invisibility.Restore)
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
    -- Idled приходит через ~2 мин бездействия, кик — через 20: виртуальный клик на
    -- каждом Idled сбрасывает таймер бездействия, и до кика дело не доходит.
    -- Раньше вдобавок отключали все соединения Idled через getconnections + Disable():
    -- Disable() правит память соединения executor'ом и мог ронять клиент (см. Anti-Trap),
    -- а заодно гасил и наш собственный обработчик выше
    local function SetupAntiAFK()
        local VirtualUser = game:GetService("VirtualUser")
        Core.Connect(LocalPlayer.Idled, function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
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

    -- targetCFrame — куда поставить нового персонажа (Auto Vote: точка на паде);
    -- без него — туда, где стоял старый. Поворот всегда только по горизонтали:
    -- раньше копировался полный CFrame, и наклонённый/лежащий персонаж (или
    -- повёрнутая часть пада) возвращался лёжа и проваливался в пол
    local function respawn(plr, targetCFrame)
        local char = plr.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Защита от повторного вызова
        if respawning[plr.UserId] then
            return
        end
        respawning[plr.UserId] = true

        local source = targetCFrame or hrp.CFrame
        local look = Vector3.new(source.LookVector.X, 0, source.LookVector.Z)
        local ogpos = look.Magnitude > 1e-3
            and CFrame.lookAt(source.Position, source.Position + look)
            or CFrame.new(source.Position)
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
                newHrp.AssemblyLinearVelocity = Vector3.zero
                newHrp.AssemblyAngularVelocity = Vector3.zero
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
    -- БЛОК 18.5: FARM SYNC — координация серверов между аккаунтами (один ПК)
    -- ══════════════════════════════════════════════════════════════════════════════
    -- Задача: в реальном времени знать, какой аккаунт на каком сервере сидит, и не
    -- давать двум своим аккаунтам фармить на одном инстансе. Канал обмена — файлы в
    -- папке executor'а VioCFG/Violite/FarmSync (все инстансы на одном ПК видят одну ФС).
    --
    -- Модель без гонок записи: каждый аккаунт пишет ТОЛЬКО свой файл <userId>.json и
    -- читает чужие. Если у executor'а нет listfiles — мягкая деградация на единый
    -- файл farmsync.json (read-modify-write с прунингом протухших записей).
    --
    -- Разрешение конфликта: если на моём game.JobId есть другой свежий аккаунт — из
    -- всей группы уходит ровно один, «глобально худший» (пришёл на сервер позже;
    -- тай-брейк — больший userId). Так за тик хопает строго один, без разбегания.

    local FarmSync = {}
    State.Runtime.FarmSync = FarmSync
    do
        local FOLDERS   = {"VioCFG", "VioCFG/Violite"}   -- папка конфигов Violite
        local SYNC_DIR  = "VioCFG/Violite/FarmSync"
        local ONE_FILE  = "VioCFG/Violite/farmsync.json"   -- фолбэк без listfiles

        local HEARTBEAT_INTERVAL = 4    -- как часто пишем свой статус (сек)
        local STALE_TTL          = 15   -- запись старше — аккаунт считается ушедшим
        local HOP_COOLDOWN        = 25  -- не хопать по синку чаще, чем раз в N сек

        -- Фиче-детект executor-функций (набор отличается между исполнителями)
        local hasList = type(listfiles) == "function"
        local hasDel  = type(delfile) == "function"

        local myUserId = LocalPlayer.UserId
        local myName   = LocalPlayer.Name
        local myFile   = SYNC_DIR .. "/" .. tostring(myUserId) .. ".json"

        -- Момент, когда мы впервые оказались на текущем сервере (для тай-брейка).
        local currentJobId = nil
        local sinceOnJob   = os.time()

        -- Гарантируем наличие папок хранилища
        pcall(function()
            if type(makefolder) == "function" then
                for _, dir in ipairs(FOLDERS) do
                    if type(isfolder) ~= "function" or not isfolder(dir) then makefolder(dir) end
                end
                if hasList and (type(isfolder) ~= "function" or not isfolder(SYNC_DIR)) then
                    makefolder(SYNC_DIR)
                end
            end
        end)

        local function encode(t)
            local ok, s = pcall(function() return HttpService:JSONEncode(t) end)
            return ok and s or nil
        end

        local function decode(s)
            local ok, t = pcall(function() return HttpService:JSONDecode(s) end)
            return ok and t or nil
        end

        -- Прочитать все записи из стора в виде массива {userId,name,placeId,jobId,since,heartbeat}
        local function readAll()
            local out = {}
            if hasList then
                local ok, files = pcall(listfiles, SYNC_DIR)
                if ok and type(files) == "table" then
                    for _, path in ipairs(files) do
                        if type(path) == "string" and path:sub(-5) == ".json" then
                            local okr, content = pcall(readfile, path)
                            if okr and type(content) == "string" then
                                local rec = decode(content)
                                if type(rec) == "table" and rec.userId then
                                    out[#out + 1] = rec
                                end
                            end
                        end
                    end
                end
            else
                local okr, content = pcall(function()
                    return (type(isfile) == "function" and isfile(ONE_FILE)) and readfile(ONE_FILE) or nil
                end)
                if okr and type(content) == "string" then
                    local map = decode(content)
                    if type(map) == "table" then
                        for _, rec in pairs(map) do
                            if type(rec) == "table" and rec.userId then
                                out[#out + 1] = rec
                            end
                        end
                    end
                end
            end
            return out
        end

        -- Записать/обновить свою запись. В режиме listfiles — атомарно свой файл.
        -- В фолбэке — read-modify-write общего файла с прунингом протухших.
        local function writeRecord(rec)
            local now = os.time()
            if hasList then
                local s = encode(rec)
                if s then pcall(writefile, myFile, s) end
            else
                local map = {}
                local okr, content = pcall(function()
                    return (type(isfile) == "function" and isfile(ONE_FILE)) and readfile(ONE_FILE) or nil
                end)
                if okr and type(content) == "string" then map = decode(content) or {} end
                if type(map) ~= "table" then map = {} end
                for k, r in pairs(map) do
                    if type(r) ~= "table" or (now - (r.heartbeat or 0)) > STALE_TTL then
                        map[k] = nil
                    end
                end
                map[tostring(rec.userId)] = rec
                local s = encode(map)
                if s then pcall(writefile, ONE_FILE, s) end
            end
        end

        -- Удалить свою запись (при выключении синка или перед уходом с сервера)
        local function removeSelf()
            pcall(function()
                if hasList then
                    if hasDel and type(isfile) == "function" and isfile(myFile) then
                        delfile(myFile)
                    end
                else
                    local content = (type(isfile) == "function" and isfile(ONE_FILE)) and readfile(ONE_FILE) or nil
                    if type(content) == "string" then
                        local map = decode(content)
                        if type(map) == "table" then
                            map[tostring(myUserId)] = nil
                            local s = encode(map)
                            if s then writefile(ONE_FILE, s) end
                        end
                    end
                end
            end)
        end

        -- true, если запись r должна «остаться» приоритетнее нас (т.е. мы хуже неё).
        -- Хуже = пришли на сервер позже (больше since); тай-брейк — больший userId.
        local function iAmWorseThan(r)
            local rSince = r.since or 0
            if sinceOnJob ~= rSince then
                return sinceOnJob > rSince
            end
            return myUserId > (r.userId or 0)
        end

        -- Одна итерация: обновить свой статус, проверить коллизию, при нужде — хопнуть.
        local function step()
            local now   = os.time()
            local jobId = game.JobId

            -- Сменился сервер (после хопа/телепорта) — обновляем «время прихода»
            if jobId ~= currentJobId then
                currentJobId = jobId
                sinceOnJob   = now
            end

            writeRecord({
                userId    = myUserId,
                name      = myName,
                placeId   = game.PlaceId,
                jobId     = jobId,
                since     = sinceOnJob,
                heartbeat = now,
            })

            -- Ищем свежие чужие аккаунты на моём сервере. Уходим только если мы
            -- проигрываем ВСЕМ из группы — тогда за тик хопает ровно «худший».
            local othersOnJob = 0
            local loseToAll   = true

            for _, r in ipairs(readAll()) do
                if r.userId ~= myUserId
                    and r.placeId == game.PlaceId
                    and r.jobId == jobId
                    and (now - (r.heartbeat or 0)) <= STALE_TTL then

                    othersOnJob = othersOnJob + 1
                    if not iAmWorseThan(r) then
                        loseToAll = false
                    end
                end
            end

            if othersOnJob > 0 and loseToAll then
                if (now - (State.Runtime.FarmSyncLastHop or 0)) >= HOP_COOLDOWN then
                    State.Runtime.FarmSyncLastHop = now
                    if State.Settings.NotificationsEnabled then
                        ShowNotification(
                            "Farm Sync: <font color=\"rgb(255,170,50)\">сервер занят другим аккаунтом → hop</font>",
                            CONFIG.Colors.Text
                        )
                    end
                    removeSelf()      -- мы уходим — не мешаем остальным своей записью
                    ServerHop()       -- асинхронный v3: сам ждёт вердикт телепорта
                    return
                end
            end
        end

        function FarmSync.Start()
            if State.Runtime.FarmSyncThread then return end
            State.Settings.FarmSyncEnabled = true
            currentJobId = game.JobId
            sinceOnJob   = os.time()

            State.Runtime.FarmSyncThread = Core.Tasks.spawn(function()
                while State.Settings.FarmSyncEnabled do
                    pcall(step)
                    -- Джиттер разносит записи инстансов по времени (меньше гонок в
                    -- фолбэк-режиме единого файла).
                    task.wait(HEARTBEAT_INTERVAL + math.random() * 2)
                end
            end)

            if State.Settings.NotificationsEnabled then
                ShowNotification("Farm Sync: <font color=\"rgb(85,255,120)\">ON</font>", CONFIG.Colors.Text)
            end
        end

        function FarmSync.Stop()
            State.Settings.FarmSyncEnabled = false
            if State.Runtime.FarmSyncThread then
                pcall(task.cancel, State.Runtime.FarmSyncThread)
                State.Runtime.FarmSyncThread = nil
            end
            removeSelf()
            if State.Settings.NotificationsEnabled then
                ShowNotification("Farm Sync: <font color=\"rgb(255,85,85)\">OFF</font>", CONFIG.Colors.Text)
            end
        end
    end

    -- ══════════════════════════════════════════════════════════════════════════════
    -- БЛОК 18.6: AUTO VOTE SPAM — голосование за приоритетную карту
    -- ══════════════════════════════════════════════════════════════════════════════
    -- Лобби после ивент-апдейта: Workspace.Lobby.VotePads.VotePadN →
    --   VoteInfoGui.Container.MapName / .Votes ("Votes: N"), MapInfoGui.MapIcon (Image
    --   не пуст и VoteInfoGui.Enabled — идёт голосование), часть Pad — куда встать.
    -- Голос засчитывает сервер по стоянию на паде; респавн-цикл (respawn() кладёт
    -- нового персонажа на то же место) даёт голос заново на каждом заходе.
    do
        -- Ключи — имя карты в нижнем регистре без пробелов; меньше — приоритетнее
        -- (маленькие карты быстрее фармятся). Неизвестные карты — в конец списка
        local MAP_PRIORITY = {
            house2 = 1, bank2 = 2, factory = 3, hospital3 = 4, workplace = 5, mansion2 = 6,
            office3 = 7, policestation = 8, hotel2 = 9, researchfacility = 10, biolab = 11,
            milbase = 12, mineshaft = 13,
        }
        local Vote = {Thread = nil, Session = 0, Teleported = false, Reached = false, InvisWasOn = false}

        local function normalize(name)
            return (tostring(name):lower():gsub("[^%w]", ""))
        end

        local function readPads()
            local pads = {}
            local lobby = Workspace:FindFirstChild("Lobby")
            local folder = lobby and lobby:FindFirstChild("VotePads")
            if not folder then return pads end
            for _, pad in ipairs(folder:GetChildren()) do
                local voteGui = pad:FindFirstChild("VoteInfoGui")
                local mapGui = pad:FindFirstChild("MapInfoGui")
                local container = voteGui and voteGui:FindFirstChild("Container")
                local mapLabel = container and container:FindFirstChild("MapName")
                local votesLabel = container and container:FindFirstChild("Votes")
                local icon = mapGui and mapGui:FindFirstChild("MapIcon")
                local part = pad:FindFirstChild("Pad") or pad:FindFirstChildWhichIsA("BasePart", true)
                if mapLabel and votesLabel and part then
                    local active = voteGui.Enabled and (not icon or icon.Image ~= "")
                    pads[#pads + 1] = {
                        Name = mapLabel.Text,
                        Votes = tonumber(votesLabel.Text:match("(%d+)")) or 0,
                        Active = active,
                        Part = part,
                        Priority = MAP_PRIORITY[normalize(mapLabel.Text)] or 50,
                    }
                end
            end
            return pads
        end

        local function targetPad()
            local best = nil
            for _, pad in ipairs(readPads()) do
                if pad.Active and (not best or pad.Priority < best.Priority) then best = pad end
            end
            return best
        end

        -- Где стоять на паде. Часть Pad повёрнута на 90° по X (её «верх» смотрит
        -- вбок) и без коллизии, а пол лобби — ниже её центра. Раньше персонажа ставили
        -- в CFrame пада +3: он копировал поворот (лёжа) и проваливался в пол. Теперь
        -- луч вниз до настоящего пола (без падов и персонажей) и стоячий CFrame на
        -- высоте корня R15/R6: пол + HipHeight + половина корня
        local floorParams = RaycastParams.new()
        floorParams.FilterType = Enum.RaycastFilterType.Exclude

        local function standCFrame(part, character)
            local exclude = {part.Parent and part.Parent.Parent or part}
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then table.insert(exclude, player.Character) end
            end
            floorParams.FilterDescendantsInstances = exclude

            local center = part.Position
            local floorY = center.Y
            local hit = Workspace:Raycast(center + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0), floorParams)
            if hit then floorY = hit.Position.Y end

            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local hip = humanoid and humanoid.HipHeight or 2
            if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then hip = 2 end
            local rootHalf = root and root.Size.Y / 2 or 1
            return CFrame.new(center.X, floorY + hip + rootHalf + 0.1, center.Z)
        end

        -- Конец голосования (цель достигнута / пады погасли / выключили): инвиз — обратно
        local function releaseInvis()
            State.Runtime.AutoVoteSuppressInvis = false
            if Vote.InvisWasOn and State.Settings.AutoFarmEnabled and not State.Settings.IsInvisible then
                pcall(function() ToggleInvisibility() end)
            end
            Vote.InvisWasOn = false
        end

        local function loop()
            local waiting = true
            while State.Settings.VoteSpammerEnabled do
                local pad = targetPad()
                if not pad then
                    if not waiting then
                        waiting = true
                        Vote.Teleported, Vote.Reached = false, false
                        releaseInvis()
                    end
                    task.wait(2)
                    continue
                end

                if waiting then
                    -- Новое голосование: инвиз прячет нас под картой — сервер не увидит на паде
                    waiting = false
                    Vote.Session += 1
                    State.Runtime.AutoVoteSuppressInvis = true
                    if State.Settings.IsInvisible then
                        pcall(function() ToggleInvisibility() end)
                        Vote.InvisWasOn = true
                        task.wait(0.2)
                    end
                end

                if pad.Votes >= (State.Settings.VoteGoal or 8) then
                    if not Vote.Reached then
                        Vote.Reached = true
                        releaseInvis()
                    end
                    task.wait(2)
                    continue
                end

                local character = LocalPlayer.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if not hrp then task.wait(0.5); continue end

                local stand = standCFrame(pad.Part, character)
                if not Vote.Teleported then
                    hrp.CFrame = stand
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    Vote.Teleported = true
                    task.wait(0.4)
                end
                respawn(LocalPlayer, stand)
                task.wait(0.4)
            end
            releaseInvis()
        end

        State.Runtime.SetVoteSpammer = function(on)
            State.Settings.VoteSpammerEnabled = on and true or false
            if Vote.Thread then Core.Tasks.cancel(Vote.Thread); Vote.Thread = nil end
            Vote.Teleported, Vote.Reached = false, false
            if State.Settings.VoteSpammerEnabled then
                Vote.Thread = Core.Tasks.spawn(loop)
            else
                releaseInvis()
            end
            if State.Settings.NotificationsEnabled then
                ShowNotification("Vote Spammer: " .. (on and "<font color=\"rgb(168,228,160)\">ON</font>" or "<font color=\"rgb(255,85,85)\">OFF</font>"), CONFIG.Colors.Text)
            end
        end
    end

    -- ══════════════════════════════════════════════════════════════════════════════
    -- БЛОК 18.7: AUTO PRESTIGE (Level ≥ 100 → Remotes.Inventory.Prestige, реджоин)
    -- ══════════════════════════════════════════════════════════════════════════════
    do
        local busy = false
        State.Runtime.CheckAndPrestige = function()
            if not State.Settings.AutoPrestigeEnabled or busy then return end
            local remote = nil
            pcall(function()
                remote = ReplicatedStorage.Remotes.Inventory:FindFirstChild("Prestige")
            end)
            if not remote then return end
            local level = LocalPlayer:GetAttribute("Level")
            if not level or level < 100 then return end
            local prestige = LocalPlayer:GetAttribute("Prestige")
            if prestige and prestige >= 10 then return end -- максимальный престиж (X)
            busy = true
            if State.Settings.NotificationsEnabled then
                ShowNotification("<font color=\"rgb(255, 200, 50)\">Level 100 → Prestiging...</font>", CONFIG.Colors.Text)
            end
            if pcall(function() remote:FireServer() end) then
                task.wait(2)
                pcall(Rejoin)
            end
            task.wait(10)
            busy = false
        end
    end

    -- ══════════════════════════════════════════════════════════════════════════════
    -- БЛОК 18.8: AUTO BATTLE PASS — покупка тиров ивентового пасса за валюту ивента
    -- ══════════════════════════════════════════════════════════════════════════════
    -- Как в игре (CrossPlatform.<Event>.EventScript.BattlePassService):
    --   EventInfoService:GetMainEvent() → Title ("Halloween2026"), EventStartInfo
    --   {CurrencyName, BattlePass = {TierCost, TotalTiers, Rewards, FinalRewardCost}};
    --   прогресс — ProfileData[Title] {CurrentTier, ClaimedRewards}, баланс —
    --   ProfileData.Materials.Owned[CurrencyName]; ремоуты
    --   Remotes.Events[Title .. "Remotes"].{BuyBattlePassTiers(n), ClaimBattlePassReward(tier),
    --   BuyBattlePassFinalReward()}. Клиент игры сам правит ProfileData до ответа
    --   сервера — делаем так же, чтобы не купить дважды на одном балансе.
    do
        local Pass = {Thread = nil, Busy = false}

        -- Модули игры требуем только после того, как их загрузила сама игра. Ранний
        -- require(ProfileData) исполнял модуль раньше загрузки профиля — он падал
        -- ("Toys is not a valid member of GetProfileData"), Roblox кэширует ошибку,
        -- и ломались все скрипты игры, которым нужен ProfileData (монеты, инвентарь,
        -- ивент). Без getloadedmodules — по признакам загруженного профиля
        local function loadedByGame(module)
            if not module then return false end
            if type(getloadedmodules) == "function" then
                local ok, list = pcall(getloadedmodules)
                if ok and type(list) == "table" then
                    for _, loaded in ipairs(list) do
                        if loaded == module then return true end
                    end
                    return false
                end
            end
            local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            return LocalPlayer:GetAttribute("Level") ~= nil and gui ~= nil and gui:FindFirstChild("MainGUI") ~= nil
        end

        local function context()
            local shared = ReplicatedStorage:FindFirstChild("SharedServices")
            local modules = ReplicatedStorage:FindFirstChild("Modules")
            local serviceModule = shared and shared:FindFirstChild("EventInfoService")
            local profileModule = modules and modules:FindFirstChild("ProfileData")
            if not loadedByGame(serviceModule) or not loadedByGame(profileModule) then return nil end

            local service = require(serviceModule)
            local event = service:GetMainEvent()
            if not event or event.Status ~= "Started" then return nil end
            local info = event.EventStartInfo
            local pass = info and info.BattlePass
            local profile = require(profileModule)
            local progress = profile[event.Title]
            local events = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Events")
            local remotes = events:FindFirstChild(event.Title .. "Remotes")
            if not pass or type(progress) ~= "table" or not remotes then return nil end
            return {Pass = pass, Progress = progress, Profile = profile, Currency = info.CurrencyName, Remotes = remotes}
        end

        State.Runtime.BattlePassTick = function()
            if not (State.Settings.AutoBattlePassEnabled or State.Settings.BuyFinalRewardEnabled) then return end
            if Pass.Busy then return end
            Pass.Busy = true
            local ok, err = pcall(function()
                local ctx = context()
                if not ctx then return end
                local pass, progress, owned = ctx.Pass, ctx.Progress, ctx.Profile.Materials.Owned
                local balance = owned[ctx.Currency] or 0

                if State.Settings.AutoBattlePassEnabled then
                    local left = pass.TotalTiers - (progress.CurrentTier or 0)
                    local count = math.min(math.floor(balance / pass.TierCost), left)
                    if count > 0 then
                        ctx.Remotes.BuyBattlePassTiers:FireServer(count)
                        progress.CurrentTier += count
                        owned[ctx.Currency] = balance - count * pass.TierCost
                        balance = owned[ctx.Currency]
                        if State.Settings.NotificationsEnabled then
                            ShowNotification("<font color=\"rgb(168,228,160)\">Battle Pass: +" .. count .. " tier(s)</font>", CONFIG.Colors.Text)
                        end
                        task.wait(1)
                    end
                    -- Награды купленных тиров бесплатны; последний тир — финальная награда (отдельно)
                    local claimed = progress.ClaimedRewards or {}
                    for key in pairs(pass.Rewards or {}) do
                        local tier = tonumber(key)
                        if tier and tier <= progress.CurrentTier and tier ~= pass.TotalTiers and claimed[key] ~= true then
                            ctx.Remotes.ClaimBattlePassReward:FireServer(key)
                            claimed[key] = true
                            task.wait(CONFIG.BattlePass.ClaimDelay)
                        end
                    end
                end

                if State.Settings.BuyFinalRewardEnabled and progress.CurrentTier >= pass.TotalTiers
                    and pass.FinalRewardCost and balance >= pass.FinalRewardCost then
                    ctx.Remotes.BuyBattlePassFinalReward:FireServer()
                    owned[ctx.Currency] = balance - pass.FinalRewardCost
                    progress.FinalRewardClaimAmount = (progress.FinalRewardClaimAmount or 0) + 1
                    if State.Settings.NotificationsEnabled then
                        ShowNotification("<font color=\"rgb(168,228,160)\">Battle Pass: final reward bought</font>", CONFIG.Colors.Text)
                    end
                end
            end)
            if not ok then warn("[Battle Pass] " .. tostring(err)) end
            Pass.Busy = false
        end

        local function loop()
            task.wait(5) -- Даем профилю и ивенту полностью прогрузиться
            while State.Settings.AutoBattlePassEnabled or State.Settings.BuyFinalRewardEnabled do
                State.Runtime.BattlePassTick()
                task.wait(CONFIG.BattlePass.Interval)
            end
            Pass.Thread = nil
        end

        State.Runtime.SetAutoBattlePass = function(on)
            State.Settings.AutoBattlePassEnabled = on and true or false
            if (State.Settings.AutoBattlePassEnabled or State.Settings.BuyFinalRewardEnabled) and not Pass.Thread then
                Pass.Thread = Core.Tasks.spawn(loop)
            elseif not on and Pass.Thread and not State.Settings.BuyFinalRewardEnabled then
                Core.Tasks.cancel(Pass.Thread)
                Pass.Thread = nil
            end
        end
        -- Тумблер финальной награды тоже держит цикл живым
        State.Runtime.EnsureBattlePassLoop = function()
            if (State.Settings.AutoBattlePassEnabled or State.Settings.BuyFinalRewardEnabled) and not Pass.Thread then
                Pass.Thread = Core.Tasks.spawn(loop)
            end
        end
    end

    -- Все функции уже объявлены: ошибка одной системы не пропускает остальные.
    Core.StopFeatures = function()
        State.Settings.NotificationsEnabled = false
        for _, entry in ipairs({
            {"Invisibility", function() if State.Settings.IsInvisible then ToggleInvisibility() end end},
            {"AutoFarm", StopAutoFarm}, {"XP Farm", StopXPFarm},
            {"WalkFling", function() WalkFlingStop(false) end},
            {"Fling", State.Runtime.FlingCleanup},
            {"ViewClip", function() if State.Settings.ViewClipEnabled then Core.Movement.DisableViewClip() end end},
            {"NoClip", DisableNoClip}, {"AntiFling", DisableAntiFling},
            {"Pickup", DisableInstantPickup},
            {"AutoFire", function() State.Runtime.SheriffAim.SetAutoFire(false) end},
            {"AntiTrap", function() State.Runtime.SetAntiTrap(false) end},
            {"CoinTracer", RemoveCoinTracer},
            {"VoteSpammer", function() if State.Runtime.SetVoteSpammer then State.Runtime.SetVoteSpammer(false) end end},
            {"FarmSync", function() if State.Runtime.FarmSync then State.Runtime.FarmSync.Stop() end end},
            {"BattlePass", function() if State.Runtime.SetAutoBattlePass then State.Runtime.SetAutoBattlePass(false) end end},
            {"UI optimization", Core.Movement.DisableUIOnly},
        }) do
            Core.Try(entry[1], entry[2])
        end
    end

    -- GUI в лидерборде всегда с CDN: бандла (Kernel) у него нет
    local GUIFactory = loadstring(game:HttpGet("https://raw.githubusercontent.com/Yany1944/rbxmain/refs/heads/main/Libraryes/GUI.lua"))()
    local GUI = GUIFactory({
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
            ViewClip = function(on) if on then Core.Movement.EnableViewClip() else Core.Movement.DisableViewClip() end end,

            -- Notifications / role cards
            NotificationsEnabled = function(on) State.Settings.NotificationsEnabled = on end,
            AvatarDisplayEnabled = function(on)
                State.Settings.AvatarDisplayEnabled = on
                SetAvatarDisplayVisibility(on)
            end,

            -- ESP
            GunESP = function(on) State.Settings.GunESP = on UpdateGunESPVisibility() UpdateTrapESPVisibility() end,
            MurderESP = function(on) State.Settings.MurderESP = on end,
            SheriffESP = function(on) State.Settings.SheriffESP = on end,
            InnocentESP = function(on) State.Settings.InnocentESP = on end,
            UIOnly = function(on) State.Settings.UIOnlyEnabled = on if on then Core.Movement.EnableUIOnly() else Core.Movement.DisableUIOnly() end end,
            BulletTracers = ToggleBulletTracers,

            -- Combat
            SpawnAtPlayer = function(on) State.Settings.SpawnAtPlayer = on end,
            AutoFire = function(on) State.Runtime.SheriffAim.SetAutoFire(on) end,
            Resolver = function(on) State.Runtime.SheriffAim.SetResolver(on) end,
            InstantPickup = function(on) if on then EnableInstantPickup() else DisableInstantPickup() end end,
            AntiTrap = function(on) State.Runtime.SetAntiTrap(on) end,

            -- Farming
            AutoFarm = function(on)
                State.Settings.AutoFarmEnabled = on
                if on then
                    State.Cache.CoinBlacklist = {}
                    ShowNotification("Auto Farm: <font color=\"rgb(168,228,160)\">ON</font>", CONFIG.Colors.Text)
                    StartAutoFarm()
                else
                    StopAutoFarm()
                    ShowNotification("Auto Farm: <font color=\"rgb(255,85,85)\">OFF</font>", CONFIG.Colors.Text)
                end
            end,
            XPFarm = function(on) State.Settings.XPFarmEnabled = on if on then StartXPFarm() else StopXPFarm() end end,
            SmartCollect = function(on) State.Settings.SmartCollectEnabled = on end,
            AutoPrestige = function(on)
                State.Settings.AutoPrestigeEnabled = on
                if on and State.Runtime.CheckAndPrestige then Core.Tasks.spawn(State.Runtime.CheckAndPrestige) end
            end,
            AutoBattlePass = function(on) if State.Runtime.SetAutoBattlePass then State.Runtime.SetAutoBattlePass(on) end end,
            BuyFinalReward = function(on)
                State.Settings.BuyFinalRewardEnabled = on
                if on and State.Runtime.EnsureBattlePassLoop then State.Runtime.EnsureBattlePassLoop() end
            end,
            UndergroundMode = function(on) State.Settings.UndergroundMode = on end,
            CoinFarmFlySpeed = function(v) State.Settings.CoinFarmFlySpeed = v end,
            CoinFarmDelay = function(v) State.Settings.CoinFarmDelay = v end,
            VoteSpammer = function(on) if State.Runtime.SetVoteSpammer then State.Runtime.SetVoteSpammer(on) end end,
            VoteGoal = function(v) State.Settings.VoteGoal = math.clamp(math.floor(tonumber(v) or 8), 1, 50) end,

            -- Optimization (AFK Mode = No Render + Disable UI, как в старом лидерборде)
            AFKMode = function(on)
                State.Settings.AFKModeEnabled = on
                if on then
                    Core.Movement.EnableMaxOptimization()
                    Core.Movement.EnableUIOnly()
                else
                    Core.Movement.DisableMaxOptimization()
                    if not State.Settings.UIOnlyEnabled then Core.Movement.DisableUIOnly() end
                end
            end,
            FPSBoost = Core.Movement.EnableFPSBoost,
            FPSCap = function(v)
                State.Settings.FPSCap = math.clamp(math.floor(tonumber(v) or 30), 5, 9999)
                local module = State.Runtime.OptimizationModule
                if module and module.SetFPSCap then module.SetFPSCap(State.Settings.FPSCap) end
            end,

            -- AntiFling / WalkFling
            AntiFling = function(on) if on then EnableAntiFling() else DisableAntiFling() end end,
            WalkFling = function(on) if on then WalkFlingStart() else WalkFlingStop() end end,

            -- Fling
            FlingMethod = function(v) State.Settings.FlingMethod = Fling.NormalizeMethod(v) end,
            SkidLead = function(v) State.Settings.SkidLead = math.clamp(v, 0.6, 1.2) end,
            FlingMurderer = FlingMurderer,
            FlingSheriff  = FlingSheriff,

            -- Server
            Rejoin = Rejoin,
            ExecInf = ExecuteInf,
            ServerHop = ServerHop,
            FarmSync = function(on)
                if not State.Runtime.FarmSync then return end
                if on then State.Runtime.FarmSync.Start() else State.Runtime.FarmSync.Stop() end
            end,
            SpeedGlitchTool = SpeedGlitch,
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

            Shutdown = function() FullShutdown() end,

            AutoLoadOnTeleport = function(on)
                State.Settings.AutoLoadOnTeleport = on
            end,
        }, {__index = function(_, key)
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
    -- БЛОК 19: МОДУЛЬ ОПТИМИЗАЦИИ (Libraryes/Optimization.lua с CDN)
    -- ══════════════════════════════════════════════════════════════════════════════
    do
        -- Отдельная функция даёт загрузчику собственный бюджет регистров Luau.
        (function()
            local context = {
                GUI = GUI, CONFIG = CONFIG, State = State, ShowNotification = ShowNotification, Tasks = Core.Tasks,
                Connect = Core.Connect, Remember = Core.Remember,
                IsMovementBusy = function() return Fling.SessionActive == true end,
                -- Альтов на одном ПК много: FPS Unlocker поднимает кап не до 9999, а до своего
                FPSCap = State.Settings.FPSCap,
            }
            local ok, result = pcall(function()
                local source = game:HttpGet(CONFIG.Modules.Optimization, true)
                local chunk, compileError = loadstring(source)
                assert(chunk, compileError)
                local factory = chunk()
                assert(type(factory) == "function", "Invalid module factory")
                return factory(context)
            end)
            if ok then
                State.Runtime.OptimizationModule = result
                if result.SetFPSCap then result.SetFPSCap(State.Settings.FPSCap) end
            else
                warn("[Violite] Optimization: " .. tostring(result))
                ShowNotification("Optimization module failed to load", CONFIG.Colors.Accent)
            end
            if State.Runtime.UIElements.MainGui then
                table.insert(State.Runtime.Connections, Core.Connect(State.Runtime.UIElements.MainGui.Destroying, function()
                    Core.Shutdown()
                end))
            end
        end)()
    end

    ----------------------------------------------------------------
    -- СОЗДАНИЕ ВКЛАДОК И ПРИВЯЗКА К Handlers
    ----------------------------------------------------------------
    -- Дефолты тумблеров — пресет альта: всё фермерское включается само, если
    -- AUTOFARM_ENABLED (см. БЛОК 1). Тумблер с default=true сам дёргает свой handler
    local AUTO = CONFIG.AutoExec

    do
        local MainTab = GUI.CreateTab("Main")

            MainTab:CreateSection("CHARACTER SETTINGS")
            MainTab:CreateInputField("JumpPower", "Set custom jump power", State.Settings.JumpPower, "ApplyJumpPower")
            MainTab:CreateInputField("Max Camera Zoom", "Set maximum camera distance", State.Settings.MaxCameraZoom, "ApplyMaxCameraZoom")

            MainTab:CreateSection("CAMERA")
            MainTab:CreateInputField("Field of View", "Set custom camera FOV", State.Settings.CameraFOV, "ApplyFOV")
            MainTab:CreateToggle("ViewClip", "Camera clips through walls", "ViewClip", false)
            MainTab:CreateKeybindButton("Toggle Invisible", "invisibility", "Invisibility")

            MainTab:CreateSection("TELEPORT & OTHER", "right")
            MainTab:CreateKeybindButton("Click TP (Hold Key + LMB)", "clicktp", "ClickTP")
            MainTab:CreateKeybindButton("Toggle NoClip", "NoClip", "NoClip")
            MainTab:CreateSection(nil, "right")
            MainTab:CreateButton("", "Fast respawn", CONFIG.Colors.Accent, "RespawnPlr")
            MainTab:CreateButton("", "Speed Glitch Tool", CONFIG.Colors.Accent, "SpeedGlitchTool")
    end

    do
        local VisualsTab = GUI.CreateTab("Visuals")

            VisualsTab:CreateSection("ESP")
            VisualsTab:CreateToggle("Murder ESP", "Highlight murderer", "MurderESP", false)
            VisualsTab:CreateToggle("Sheriff ESP", "Highlight sheriff", "SheriffESP", false)
            VisualsTab:CreateToggle("Innocent ESP", "Highlight innocent players", "InnocentESP", false)
            VisualsTab:CreateToggle("Dropped Gun", "Highlight dropped gun", "GunESP", false)
            VisualsTab:CreateToggle("Tracers", "Show your bullet trajectory", "BulletTracers", false)

            VisualsTab:CreateSection("Misc", "right")
            VisualsTab:CreateToggle("Enable Notifications", "Show notifications", "NotificationsEnabled", false)
            VisualsTab:CreateToggle("Role Cards", "Show Murderer and Sheriff avatar", "AvatarDisplayEnabled", false)
            VisualsTab:CreateToggle("Disable UI", "Hide all UI except script GUI", "UIOnly", true)
    end

    do
        local CombatTab = GUI.CreateTab("Combat")

            CombatTab:CreateSection("MURDERER TOOLS")
            CombatTab:CreateKeybindButton("Fast throw", "knifeThrow", "knifeThrow")
            CombatTab:CreateToggle("Spawn Knife Near Player", "Spawns knife next to closest target", "SpawnAtPlayer", false)
            CombatTab:CreateKeybindButton("Instant Kill All", "instantkillall", "InstantKillAll")

            CombatTab:CreateSection("SHERIFF TOOLS", "right")
            CombatTab:CreateKeybindButton("Shoot Murderer", "shootmurderer", "ShootMurderer", "Silent shot with movement lead")
            CombatTab:CreateToggle("Auto Fire", "Shoots the murderer once the line to him is clear", "AutoFire", false)
            CombatTab:CreateToggle("Resolver", "Use only versus velocity spoofer", "Resolver", false)
            CombatTab:CreateKeybindButton("Wallbang", "wallbang", "Wallbang", "Wallbang shot from beside murderer")
            CombatTab:CreateKeybindButton("Pickup Dropped Gun", "pickupgun", "PickupGun", "Grabs the dropped gun from anywhere")
            CombatTab:CreateToggle("Instant Pickup Gun", "Auto pickup gun when dropped", "InstantPickup", AUTO)

            CombatTab:CreateSection("PROTECTION", "right")
            CombatTab:CreateToggle("Anti Trap", "Traps don't slow you or alert murderer", "AntiTrap", AUTO)
    end

    do
        local FarmTab = GUI.CreateTab("Farming")

            FarmTab:CreateSection("AUTO FARM")
            FarmTab:CreateToggle("Auto Farm", "Automatic coin farm", "AutoFarm", AUTO)
            FarmTab:CreateToggle("XP Farm", "Auto win rounds", "XPFarm", AUTO)
            FarmTab:CreateToggle("Smart Collect", "Far coins take 2-3 s of flight, like near ones", "SmartCollect", AUTO)
            FarmTab:CreateToggle("Auto Prestige", "Auto-prestige at level 100", "AutoPrestige", true)
            FarmTab:CreateToggle("Underground Mode", "Fly under the map (safer)", "UndergroundMode", true)

            FarmTab:CreateSection("EVENT", "right")
            FarmTab:CreateToggle("Auto Battle Pass", "Buy pass tiers with event currency and claim rewards", "AutoBattlePass", AUTO)
            FarmTab:CreateToggle("Buy Final Reward", "Spend currency on the repeatable final reward", "BuyFinalReward", false)

            FarmTab:CreateSection("FARM TUNING", "right")
            FarmTab:CreateSlider("Fly Speed", "Flying speed", 15, 30, State.Settings.CoinFarmFlySpeed, "CoinFarmFlySpeed", 0.5)
            FarmTab:CreateSlider("TP Delay", "Delay between first TP", 0.5, 5.0, State.Settings.CoinFarmDelay, "CoinFarmDelay", 0.5)
            FarmTab:CreateToggle("Auto Reconnect", "Reconnect on a timer to avoid AFK kick", "HandleAutoReconnect", false)
            FarmTab:CreateInputField("Reconnect interval", "Minutes, default 60", math.floor(State.Settings.ReconnectInterval / 60), "SetReconnectInterval")

            FarmTab:CreateSection("VOTE SPAM", "right")
            FarmTab:CreateToggle("Auto Vote Spam", "Automatically vote for priority maps", "VoteSpammer", true)
            FarmTab:CreateInputField("Vote Goal", "Target votes (default: 8)", State.Settings.VoteGoal, "VoteGoal")
    end

    do
        local FunTab = GUI.CreateTab("Fun")

            FunTab:CreateSection("ANIMATION KEYBINDS")
            FunTab:CreateKeybindButton("Sit Animation", "sit", "Sit")
            FunTab:CreateKeybindButton("Dab Animation", "dab", "Dab")
            FunTab:CreateKeybindButton("Zen Animation", "zen", "Zen")
            FunTab:CreateKeybindButton("Ninja Animation", "ninja", "Ninja")
            FunTab:CreateKeybindButton("Floss Animation", "floss", "Floss")

            FunTab:CreateSection("FLING SETTINGS")
            FunTab:CreateDropdown("Fling Method", "Vio: stronger; NaN: more precise", Fling.MethodChoices, Fling.MethodLabel(State.Settings.FlingMethod), "FlingMethod")
            FunTab:CreateSlider("Prediction Range", "Lead time", 0.6, 1.2, State.Settings.SkidLead, "SkidLead", 0.05)

            FunTab:CreateSection("ANTI-FLING", "right")
            FunTab:CreateToggle("Enable Anti-Fling", "Protect yourself from flingers", "AntiFling", true)
            FunTab:CreateToggle("Walk Fling", "Fling players by walking into them", "WalkFling", false)

            FunTab:CreateSection("FLING PLAYER", "right")
            FunTab:CreatePlayerDropdown("Select Target", "Choose target to fling", "SelectedPlayerForFling")
            FunTab:CreateKeybindButton("Fling Selected Target", "fling", "FlingPlayer")

            FunTab:CreateSection("FLING ROLE", "right")
            FunTab:CreateButton("", "Fling Murderer", Color3.fromRGB(255, 85, 85), "FlingMurderer")
            FunTab:CreateButton("", "Fling Sheriff", Color3.fromRGB(90, 140, 255), "FlingSheriff")
    end

    do
        local UtilityTab = GUI.CreateTab("Server")

            UtilityTab:CreateSection("SERVER MANAGEMENT")
            UtilityTab:CreateButton("", "Rejoin Server", CONFIG.Colors.Accent, "Rejoin")
            UtilityTab:CreateButton("", "Server Hop", Color3.fromRGB(100, 200, 100), "ServerHop")
            UtilityTab:CreateToggle("Farm Sync", "Auto server-hop if another of your accounts is on the same server", "FarmSync", AUTO)
            UtilityTab:CreateToggle("Auto Rejoin on Disconnect", "Rejoin automatically if kicked or dropped", "HandleAutoRejoin", true)
            UtilityTab:CreateButton("", "Execute Infinite Yield", CONFIG.Colors.Accent, "ExecInf")
            if UtilityTab.CreateThemeDropdown then
                UtilityTab:CreateThemeDropdown("Theme", "Interface color palette")
            end

            UtilityTab:CreateSection("PERFORMANCE", "right")
            UtilityTab:CreateInputField("FPS Cap", "FPS Unlocker limit for alts", State.Settings.FPSCap, "FPSCap")
            if State.Runtime.OptimizationModule then State.Runtime.OptimizationModule.BuildSection(UtilityTab) end
    end

    -- Связь registry с настройками: значения контролов читаются из State.Settings
    do
        (function()
            local aliases = {
                ApplyJumpPower = "JumpPower", ApplyMaxCameraZoom = "MaxCameraZoom", ApplyFOV = "CameraFOV",
                UIOnly = "UIOnlyEnabled", ViewClip = "ViewClipEnabled", AutoFarm = "AutoFarmEnabled", XPFarm = "XPFarmEnabled",
                AFKMode = "AFKModeEnabled", AntiFling = "AntiFlingEnabled", WalkFling = "WalkFlingEnabledByUser",
                InstantPickup = "InstantPickupEnabled", BulletTracers = "BulletTracersEnabled",
                AntiTrap = "AntiTrapEnabled", AutoFire = "AutoFireEnabled", Resolver = "ResolverEnabled",
                HandleAutoRejoin = "AutoRejoinEnabled", HandleAutoReconnect = "AutoReconnectEnabled",
                SmartCollect = "SmartCollectEnabled", AutoPrestige = "AutoPrestigeEnabled",
                AutoBattlePass = "AutoBattlePassEnabled", BuyFinalReward = "BuyFinalRewardEnabled",
                VoteSpammer = "VoteSpammerEnabled", FarmSync = "FarmSyncEnabled",
            }
            for flag, element in pairs(GUI.Flags) do
                local key = aliases[flag] or flag
                local source = State.Settings
                local scale = 1
                if flag == "SetReconnectInterval" then key = "ReconnectInterval"; scale = 1 / 60 end
                if type(source[key]) ~= "table" and source[key] ~= nil and not element.Get then
                    element.Get = function(self)
                        local value = source[key]
                        if type(value) == "number" then value *= scale end
                        if flag == "FlingMethod" then value = Fling.MethodLabel(value) end
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

    Core.Connect(LocalPlayer.CharacterAdded, function()
        CleanupMemory()
        task.wait(1)
        if State.Runtime.SettingsDirty then
            Core.Movement.ApplyCharacterSettings()
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
    SetupGunTracking()
    StartTrapTracking()
    SetupAntiAFK()
    Core.Tasks.spawn(State.Runtime.SetupRoundTracking)
    StartRoleChecking()
    -- Альт: после старта — все оптимизации, кроме No Render (рендер остаётся),
    -- затем меню прячется, как по клавише HideKey: всё уже включено пресетом.
    -- Тумблеры с default=true дёргают свои handler'ы через task.spawn — к этому
    -- моменту они отработали
    if AUTO then
        Core.Tasks.delay(2, function()
            local module = State.Runtime.OptimizationModule
            if module then
                pcall(module.Boost, {NoRender = true})
                -- Старый Optimization.lua с CDN не знает skip — снимаем No Render сами
                if module.State and module.State.Enabled and module.State.Enabled.NoRender then
                    pcall(module.Set, "NoRender", false)
                end
            end

            local gui = State.Runtime.UIElements.MainGui
            local frame = gui and gui:FindFirstChild("MainFrame")
            if frame then frame.Visible = false end
        end)
    end
    end, debug.traceback)
    if not startupOk then
        Core.Shutdown()
        warn("[Violite startup] " .. tostring(startupError))
    end