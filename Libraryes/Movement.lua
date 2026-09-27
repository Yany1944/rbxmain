-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 1: ИНИЦИАЛИЗАЦИЯ, CONFIG И СОСТОЯНИЕ
-- ══════════════════════════════════════════════════════════════════════════════
-- Movement: Source-bhop и направленный автострейфер (стиль CS2 rage movement).
-- Грузится из MainScript (БЛОК 19) как фабрика: return function(env) ... end.
--
-- Горизонтальная скорость персонажа считается здесь по модели Source
-- (Friction → Accelerate на земле, AirAccelerate в воздухе) с фиксированным шагом
-- TickRate. Симуляция включается только на время bhop (прыжок с зажатым Space)
-- и отдаёт ходьбу Roblox после приземления без Space; пока тоггл включён,
-- корпус всегда смотрит по yaw камеры. Humanoid не отключается: во время bhop
-- ему выставляется цель «идти ровно с нашей скоростью» (Move(dir) + WalkSpeed
-- = |v|), поэтому его контроллер не тормозит и не рулит, а стены, склоны и
-- анимации работают штатно. Вертикаль — физика Roblox, кроме импульса прыжка.
--
-- Математика стрейфа (AirAccelerate, как в CS:GO/CS2):
--   A = AirAccelerate · wishSpeed · dt   (разгон за тик, wishSpeed — полный)
--   C = AirSpeedCap                     (потолок проекции скорости на wishDir)
--   p = v·wishDir = s·cosθ,  add = min(A, C − p) при C − p > 0
--   |v'|² = s² + 2·p·add + add²
--   • без клипа (p ≤ C − A, add = A):  |v'|² = s² + 2pA + A²  — растёт с p;
--   • с клипом  (p ≥ C − A, add = C−p): |v'|² = s² + C² − p²   — падает с p.
--   Максимум на стыке: p* = C − A  →  θ* = acos((C − A) / s),
--   прирост за тик Δ(s²) = A·(2C − A), поворот за тик ≈ A·sinθ* / s ≈ A / s.
--   Поворот ограничен самой физикой (ω ≈ AirAccel·wishSpeed / s рад/с): любой угол
--   круче θ* поворачивает не быстрее, а только съедает скорость. Поэтому солвер
--   стрейфит под θ* со стороны желаемого направления — каждый тик и разгон,
--   и доворот траектории.
return function(env)
    if not game:IsLoaded() then game.Loaded:Wait() end
    local okEnv, shared = pcall(function() return getgenv() end)
    assert(okEnv and shared, "Movement: executor environment unavailable")
    if shared.MM2_MovementModule then return shared.MM2_MovementModule end

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer

    local Main = env.State            -- State из MainScript (Settings / Runtime)
    local MainConfig = env.CONFIG

    -- Значения — CS2 (sv_accelerate 5.5, sv_airaccelerate 12, sv_friction 5.2),
    -- скорости переведены масштабом WalkSpeed 16 / sv_maxspeed 250:
    -- air cap 30 → 1.92, stopspeed 80 → 5.12. Коэффициенты ускорения и трения
    -- безразмерные (1/с) и переносятся как есть.
    local CONFIG = {
        KeybindName = "Bhop",
        -- Key — поле State.Values, Flag — флаг контрола GUI, {min, max, step}
        Params = {
            {Key = "MaxSpeed",    Flag = "BhopMaxSpeed",    Default = 70,   Min = 16,  Max = 300, Step = 1,    Label = "Max Speed",         Hint = "Strafe acceleration limit (studs/s)"},
            {Key = "TickRate",    Flag = "BhopTickRate",    Default = 128,  Min = 64,  Max = 256, Step = 32,   Label = "Tick Rate",         Hint = "Movement simulation frequency (Hz)"},
            {Key = "AirAccel",    Flag = "BhopAirAccel",    Default = 12,   Min = 1,   Max = 100, Step = 0.5,  Label = "Air Accelerate",    Hint = "sv_airaccelerate: strafe gain and turn rate"},
            {Key = "AirCap",      Flag = "BhopAirCap",      Default = 1.92, Min = 0.5, Max = 8,   Step = 0.01, Label = "Air Speed Cap",     Hint = "Air wish speed cap (CS2 30u = 1.92)"},
            {Key = "GroundAccel", Flag = "BhopGroundAccel", Default = 5.5,  Min = 1,   Max = 20,  Step = 0.1,  Label = "Ground Accelerate", Hint = "sv_accelerate"},
            {Key = "Friction",    Flag = "BhopFriction",    Default = 5.2,  Min = 0,   Max = 15,  Step = 0.1,  Label = "Friction",          Hint = "sv_friction"},
            {Key = "StopSpeed",   Flag = "BhopStopSpeed",   Default = 5.12, Min = 0,   Max = 16,  Step = 0.01, Label = "Stop Speed",        Hint = "sv_stopspeed (studs/s)"},
            {Key = "JumpImpulse", Flag = "BhopJumpImpulse", Default = 50,   Min = 20,  Max = 120, Step = 1,    Label = "Jump Impulse",      Hint = "Upward speed of each hop"},
        },
        -- Параметры, которые живут в левой секции рядом с тогглами
        MainParams = {MaxSpeed = true, TickRate = true},
        JumpLockout = 0.12,       -- сек после прыжка, пока пол ещё «виден»
        GroundedMaxUp = 2,        -- вертикальная скорость, выше которой это не посадка
        MaxFrameTime = 0.1,       -- защита аккумулятора от спирали после фриза
        DisengageMargin = 0.5,    -- запас над скоростью ходьбы, при котором ещё скользим по Source
        StrafeModes = {"View", "Directional"},
        StepBindName = "MM2_BhopStep",
    }

    local State = {
        Enabled = false,
        Engaged = false,         -- идёт bhop: скорость считает Source-симуляция
        AutoStrafe = true,
        StrafeMode = "View",     -- View — как в CS (A/D вручную), Directional — WASD = направление
        Values = {},
        Connections = {},
        StepConnection = nil,
        RemovingConnection = nil,
        StepBound = false,       -- шаг привязан к RenderStep
        Controls = nil,          -- ControlModule (nil — ещё не искали, false — нет)
        Humanoid = nil,          -- Humanoid, у которого мы забрали управление
        SavedWalkSpeed = nil,
        SavedAutoRotate = nil,
        Accumulator = 0,
        PrevYaw = nil,
        LastSide = 1,            -- сторона последнего стрейфа (+1 / −1)
        LastJump = 0,
        Vx = 0, Vz = 0,          -- последняя отданная горизонтальная скорость
        Toggle = nil,
        Unloaded = false,
    }
    local Module = {State = State, CONFIG = CONFIG, Handlers = {}}

    local TAU = math.pi * 2
    local BAIL_STATES = {
        [Enum.HumanoidStateType.Seated] = true,
        [Enum.HumanoidStateType.Climbing] = true,
        [Enum.HumanoidStateType.Swimming] = true,
        [Enum.HumanoidStateType.Dead] = true,
        [Enum.HumanoidStateType.Ragdoll] = true,
        [Enum.HumanoidStateType.FallingDown] = true,
        [Enum.HumanoidStateType.PlatformStanding] = true,
        [Enum.HumanoidStateType.Physics] = true,
        [Enum.HumanoidStateType.GettingUp] = true,
    }

    local ParamByKey = {}
    for _, param in ipairs(CONFIG.Params) do
        ParamByKey[param.Key] = param
        State.Values[param.Key] = param.Default
    end

    -- Бинд хранится там же, где все бинды MainScript — его пишет чип GUI
    if Main.Settings.Keybinds and Main.Settings.Keybinds[CONFIG.KeybindName] == nil then
        Main.Settings.Keybinds[CONFIG.KeybindName] = Enum.KeyCode.Unknown
    end

    local function notify(richText)
        if Main.Settings.NotificationsEnabled then
            pcall(env.ShowNotification, richText, MainConfig.Colors.Text)
        end
    end

    local function disconnect(connection)
        if connection then pcall(function() connection:Disconnect() end) end
    end

    local function connect(signal, callback)
        local connection = env.Connect and env.Connect(signal, callback) or signal:Connect(callback)
        table.insert(State.Connections, connection)
        return connection
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 2: ПАРАМЕТРЫ И ВВОД
    -- ══════════════════════════════════════════════════════════════════════════
    local function setValue(key, value)
        local param = ParamByKey[key]
        State.Values[key] = math.clamp(tonumber(value) or param.Default, param.Min, param.Max)
    end

    -- wishSpeed Source (sv_maxspeed) = скорость ходьбы. Если WalkSpeed задан
    -- в меню MainScript — берём его, иначе родную скорость Humanoid'а
    local function groundSpeed()
        if Main.Runtime.SettingsDirty and tonumber(Main.Settings.WalkSpeed) then
            return math.max(Main.Settings.WalkSpeed, 1)
        end
        return math.max(State.SavedWalkSpeed or MainConfig.DefaultWalkSpeed or 16, 1)
    end

    local function getControls()
        if State.Controls == nil then
            local ok, controls = pcall(function()
                local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
                local module = scripts and scripts:FindFirstChild("PlayerModule")
                return module and require(module):GetControls()
            end)
            State.Controls = (ok and controls) or false
        end
        return State.Controls or nil
    end

    -- Локальный вектор движения (x — вправо, z — назад, как у ControlModule)
    local function readMoveVector()
        if UserInputService:GetFocusedTextBox() then return 0, 0 end
        local x, z = 0, 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then z -= 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then z += 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then x -= 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then x += 1 end
        if x == 0 and z == 0 then
            -- Геймпад / тач: вектор из ControlModule
            local controls = getControls()
            if controls then
                local ok, mv = pcall(function() return controls:GetMoveVector() end)
                if ok and typeof(mv) == "Vector3" then x, z = mv.X, mv.Z end
            end
        end
        return x, z
    end

    local function jumpHeld(humanoid)
        if UserInputService:GetFocusedTextBox() then return false end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then return true end
        local ok, pad = pcall(function()
            return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
        end)
        if ok and pad then return true end
        -- Тач-кнопка прыжка: ControlModule каждый кадр пишет её в Humanoid.Jump
        return humanoid.Jump == true
    end

    local function wrapAngle(a)
        return (a + math.pi) % TAU - math.pi
    end

    local function cameraYaw()
        local camera = Workspace.CurrentCamera
        if not camera then return State.PrevYaw or 0 end
        local look = camera.CFrame.LookVector
        if look.X * look.X + look.Z * look.Z < 1e-6 then
            -- Камера смотрит строго вверх/вниз — курс берём из UpVector
            local up = camera.CFrame.UpVector
            look = look.Y < 0 and up or -up
        end
        return math.atan2(-look.X, -look.Z)
    end

    -- Локальный ввод → желаемое мировое направление по yaw камеры.
    -- Возвращает единичный (dx, dz) и силу ввода 0..1 (аналоговый стик)
    local function desiredDirection(mx, mz, yaw)
        local mag = math.sqrt(mx * mx + mz * mz)
        if mag < 1e-3 then return 0, 0, 0 end
        mx, mz = mx / mag, mz / mag
        local sy, cy = math.sin(yaw), math.cos(yaw)
        -- forward = (−sin, −cos), right = (cos, −sin); z ввода смотрит назад
        return cy * mx + sy * mz, -sy * mx + cy * mz, math.min(mag, 1)
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 3: SOURCE-ПРИМИТИВЫ (PM_Friction / PM_Accelerate / PM_AirAccelerate)
    -- ══════════════════════════════════════════════════════════════════════════
    local function friction(vx, vz, p, dt)
        local speed = math.sqrt(vx * vx + vz * vz)
        if speed < 0.01 then return 0, 0 end
        local control = math.max(speed, p.StopSpeed)
        local k = math.max(speed - control * p.Friction * dt, 0) / speed
        return vx * k, vz * k
    end

    local function accelerate(vx, vz, wx, wz, wishSpeed, accel, dt)
        local add = wishSpeed - (vx * wx + vz * wz)
        if add <= 0 then return vx, vz end
        local acc = math.min(accel * wishSpeed * dt, add)
        return vx + wx * acc, vz + wz * acc
    end

    -- Отличие от Accelerate одно: потолок C на проекцию, а разгон A считается
    -- от полного wishSpeed — из этой асимметрии и берётся весь air-strafe
    local function airAccelerate(vx, vz, wx, wz, wishSpeed, accel, cap, dt)
        local add = math.min(wishSpeed, cap) - (vx * wx + vz * wz)
        if add <= 0 then return vx, vz end
        local acc = math.min(accel * wishSpeed * dt, add)
        return vx + wx * acc, vz + wz * acc
    end

    -- На сколько повернётся вектор скорости за тик при стрейфе под углом θ к нему
    local function turnFor(theta, speed, A, C)
        local add = math.min(A, C - speed * math.cos(theta))
        if add <= 0 then return 0 end
        return math.atan2(add * math.sin(theta), speed + add * math.cos(theta))
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 4: СОЛВЕР АВТОСТРЕЙФА
    -- ══════════════════════════════════════════════════════════════════════════
    -- (vx, vz) — текущая горизонтальная скорость; (dx, dz) — желаемое направление,
    -- нулевое — «держать текущий курс». Возвращает единичный wishDir или (0, 0).
    local function solveStrafe(vx, vz, dx, dz, wishSpeed, p, dt)
        local speed = math.sqrt(vx * vx + vz * vz)
        if speed < 0.5 then
            -- Импульса нет — сохранять нечего, ускоряемся прямо к цели
            return dx, dz
        end
        local ux, uz = vx / speed, vz / speed
        if dx == 0 and dz == 0 then dx, dz = ux, uz end

        local A = p.AirAccel * wishSpeed * dt
        local C = p.AirCap
        local cosOpt = (C - A) / speed
        if cosOpt >= 1 then
            -- Скорость ниже потолка проекции: прямой wishDir уже оптимален
            return dx, dz
        end
        local thetaOpt = math.acos(math.max(cosOpt, -1))

        -- Знаковый угол от текущего курса до желаемого
        local phi = math.atan2(ux * dz - uz * dx, ux * dx + uz * dz)
        local absPhi = math.abs(phi)

        local theta, side
        if speed >= p.MaxSpeed - 1e-3 then
            -- На лимите разгон не нужен, только доворот. Если цель ближе, чем
            -- даёт θ*, бисекцией подбираем θ ∈ [θc, θ*] с поворотом ровно на φ
            -- (θc — угол, где add обращается в 0; turnFor на отрезке монотонна)
            if absPhi < 1e-4 then return 0, 0 end
            side = phi >= 0 and 1 or -1
            if absPhi >= turnFor(thetaOpt, speed, A, C) then
                theta = thetaOpt
            else
                local lo, hi = math.acos(math.clamp(C / speed, -1, 1)), thetaOpt
                for _ = 1, 14 do
                    local mid = (lo + hi) * 0.5
                    if turnFor(mid, speed, A, C) < absPhi then lo = mid else hi = mid end
                end
                theta = (lo + hi) * 0.5
            end
        else
            -- Режим разгона: всегда θ*, сторона — к цели. Около цели сторона
            -- чередуется сама (курс перескакивает цель на ~A/s) — это и есть
            -- оптимальный «зигзаг» разгона по прямой. На развороте ровно назад
            -- держим прежнюю сторону, чтобы не метаться между ±π
            theta = thetaOpt
            if absPhi < 1e-4 then
                side = -State.LastSide
            elseif absPhi > math.pi - 0.05 then
                side = State.LastSide
            else
                side = phi >= 0 and 1 or -1
            end
        end
        State.LastSide = side

        local a = side * theta
        local ca, sa = math.cos(a), math.sin(a)
        return ux * ca - uz * sa, ux * sa + uz * ca
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 5: ЗАХВАТ HUMANOID И ШАГ СИМУЛЯЦИИ
    -- ══════════════════════════════════════════════════════════════════════════
    -- Два уровня владения персонажем:
    --   • Humanoid захвачен (тоггл включён) — только поворот корпуса за камерой;
    --     ходьба остаётся родной Roblox, играть можно как без скрипта.
    --   • Engaged (идёт bhop) — горизонтальную скорость считает Source-симуляция.
    --     Включается прыжком с зажатым Space, выключается после приземления без
    --     Space, когда трение опустило скорость до обычной ходьбы.
    local function disengage()
        local humanoid = State.Humanoid
        if State.Engaged and humanoid and humanoid.Parent then
            pcall(function()
                local restore = Main.Runtime.SettingsDirty and Main.Settings.WalkSpeed or State.SavedWalkSpeed
                if restore then humanoid.WalkSpeed = restore end
            end)
        end
        State.Engaged = false
        State.Accumulator = 0
    end

    local function release()
        disengage()
        local humanoid = State.Humanoid
        State.Humanoid = nil
        if humanoid and humanoid.Parent and State.SavedAutoRotate ~= nil then
            pcall(function() humanoid.AutoRotate = State.SavedAutoRotate end)
        end
        State.SavedWalkSpeed = nil
        State.SavedAutoRotate = nil
        State.PrevYaw = nil
    end

    local function takeover(humanoid)
        if State.Humanoid == humanoid then return end
        release()
        State.Humanoid = humanoid
        State.SavedAutoRotate = humanoid.AutoRotate
        if env.Remember then
            pcall(env.Remember, humanoid, "WalkSpeed")
            pcall(env.Remember, humanoid, "AutoRotate")
        end
        -- Корпус крутим сами, за камерой (как модель игрока в CS)
        humanoid.AutoRotate = false
    end

    local function engage(humanoid)
        if State.Engaged then return end
        -- Родная скорость снимается в момент захвата: до него WalkSpeed не наш
        State.SavedWalkSpeed = humanoid.WalkSpeed
        State.Engaged = true
        State.Accumulator = 0
    end

    -- Yaw корпуса = yaw камеры. Позиция и линейная скорость сборки не меняются
    local function faceCamera(root, yaw)
        root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
        local w = root.AssemblyAngularVelocity
        root.AssemblyAngularVelocity = Vector3.new(w.X, 0, w.Z)
    end

    -- Системы MainScript, которые сами двигают корень, имеют приоритет
    local function blocked(humanoid, root)
        local s, r = Main.Settings, Main.Runtime
        if s.FlyEnabled or s.AutoFarmEnabled then return true end
        if r.WalkFlingActive or r.IsFlingInProgress then return true end
        if env.IsMovementBusy and env.IsMovementBusy() then return true end
        if root.Anchored or humanoid.Health <= 0 or humanoid.Sit or humanoid.PlatformStand then return true end
        return BAIL_STATES[humanoid:GetState()] == true
    end

    -- wishDir одного воздушного тика по режиму стрейфа.
    --   View (как в CS): A/D — ручной стрейф, сырой wishDir от ввода, поворот
    --     даёт мышь (синхрон стрейфа с камерой = прирост скорости). Без A/D
    --     автостребфер ведёт траекторию вдоль камеры (W / ничего) или назад (S).
    --   Directional: WASD задаёт желаемое направление, солвер доворачивает к нему.
    local function airWish(vx, vz, mx, mz, yaw, wishSpeed, p, dt, auto)
        local dx, dz = desiredDirection(mx, mz, yaw)
        if not auto then return dx, dz end
        if State.StrafeMode == "Directional" then
            return solveStrafe(vx, vz, dx, dz, wishSpeed, p, dt)
        end
        if math.abs(mx) > 1e-3 then
            return dx, dz
        end
        local tx, tz = desiredDirection(0, mz > 1e-3 and 1 or -1, yaw)
        return solveStrafe(vx, vz, tx, tz, wishSpeed, p, dt)
    end

    -- Кадр: RenderStep после ControlModule и камеры, до физики
    local function step(frameDt)
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or blocked(humanoid, root) then
            release()
            return
        end
        takeover(humanoid)

        local yaw = cameraYaw()
        faceCamera(root, yaw)

        local p = State.Values
        local tickDt = 1 / p.TickRate

        -- Стартуем с реальной скорости: удары о стены, склоны и толчки игры уже
        -- в ней (аналог ClipVelocity в Source). Velocity Spoofer MainScript свою
        -- подмену к этому моменту снял, но читаем через его API на всякий случай
        local getReal = Main.Runtime.GetRealVelocity
        local velocity = getReal and getReal(root) or root.AssemblyLinearVelocity
        local vx, vy, vz = velocity.X, velocity.Y, velocity.Z

        local now = os.clock()
        local holdingJump = jumpHeld(humanoid)
        local grounded = humanoid.FloorMaterial ~= Enum.Material.Air and vy <= CONFIG.GroundedMaxUp
            and now - State.LastJump > CONFIG.JumpLockout
            and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping

        if not State.Engaged then
            -- Без Space персонажем управляет Roblox — трогаем только поворот
            if not holdingJump then
                State.PrevYaw = yaw
                return
            end
            engage(humanoid)
        end
        local wishSpeed = groundSpeed()

        -- Прыжок в тик приземления ДО трения (как CheckJumpButton → Friction
        -- в PM_WalkMove): тик на земле не успевает съесть скорость
        local jumped = false
        if grounded and holdingJump then
            vy = p.JumpImpulse
            grounded = false
            jumped = true
            State.LastJump = now
        end

        -- Фиксированный шаг: траектория скорости не зависит от FPS. Yaw камеры
        -- интерполируем по подшагам, чтобы wishDir менялся плавно внутри кадра
        State.Accumulator = math.min(State.Accumulator + frameDt, CONFIG.MaxFrameTime)
        local steps = math.floor(State.Accumulator / tickDt)
        State.Accumulator -= steps * tickDt

        local prevYaw = State.PrevYaw or yaw
        local yawDelta = wrapAngle(yaw - prevYaw)
        State.PrevYaw = yaw

        local mx, mz = readMoveVector()
        local autoStrafe = State.AutoStrafe and holdingJump

        for i = 1, steps do
            local subYaw = prevYaw + yawDelta * (i / steps)
            if grounded then
                local dx, dz, strength = desiredDirection(mx, mz, subYaw)
                vx, vz = friction(vx, vz, p, tickDt)
                if strength > 0 then
                    vx, vz = accelerate(vx, vz, dx, dz, wishSpeed * strength, p.GroundAccel, tickDt)
                end
            else
                local before = math.sqrt(vx * vx + vz * vz)
                local wx, wz = airWish(vx, vz, mx, mz, subYaw, wishSpeed, p, tickDt, autoStrafe)
                if wx ~= 0 or wz ~= 0 then
                    vx, vz = airAccelerate(vx, vz, wx, wz, wishSpeed, p.AirAccel, p.AirCap, tickDt)
                end
                -- Лимит разгона: стрейф не поднимает скорость выше MaxSpeed.
                -- Чужой импульс (флинг, батут) не срезаем — только не даём расти
                local after = math.sqrt(vx * vx + vz * vz)
                local cap = math.max(p.MaxSpeed, before)
                if after > cap then
                    vx, vz = vx * cap / after, vz * cap / after
                end
            end
        end

        State.Vx, State.Vz = vx, vz
        root.AssemblyLinearVelocity = Vector3.new(vx, vy, vz)
        humanoid.Jump = false

        local speed = math.sqrt(vx * vx + vz * vz)
        if grounded and not holdingJump and speed <= wishSpeed + CONFIG.DisengageMargin then
            -- Приземлились без Space и трение погасило разгон — отдаём ходьбу Roblox
            disengage()
            return
        end

        -- Цель Humanoid'а = наша скорость: его контроллер не тормозит и не рулит.
        -- Humanoid.Jump погашен выше — прыжками управляем сами, без landing-задержки
        if speed > 0.05 then
            humanoid.WalkSpeed = speed
            humanoid:Move(Vector3.new(vx / speed, 0, vz / speed), false)
        else
            humanoid.WalkSpeed = wishSpeed
            humanoid:Move(Vector3.zero, false)
        end
        if jumped then
            -- Freefall, а не Jumping: Jumping сам ставит Y = JumpPower и перетёр бы импульс
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 6: ПУБЛИЧНЫЙ API, GUI И ОЧИСТКА
    -- ══════════════════════════════════════════════════════════════════════════
    local function setToggleVisual(on)
        local control = State.Toggle or (env.GUI and env.GUI.Flags and env.GUI.Flags.Bhop)
        if control then pcall(function() control:Set(on, false) end) end
    end

    function Module.SetEnabled(enabled)
        State.Enabled = false
        disconnect(State.StepConnection); State.StepConnection = nil
        disconnect(State.RemovingConnection); State.RemovingConnection = nil
        if State.StepBound then
            pcall(function() RunService:UnbindFromRenderStep(CONFIG.StepBindName) end)
            State.StepBound = false
        end
        release()
        if not enabled or State.Unloaded then return end

        State.Enabled = true
        State.LastJump = 0
        State.RemovingConnection = connect(LocalPlayer.CharacterRemoving, function()
            State.Humanoid, State.SavedWalkSpeed, State.SavedAutoRotate = nil, nil, nil
            State.Accumulator, State.PrevYaw, State.Engaged = 0, nil, false
        end)
        local function runStep(dt)
            local ok, err = pcall(step, tonumber(dt) or 1 / 60)
            if not ok then
                warn("[Movement] " .. tostring(err))
                Module.SetEnabled(false)
                setToggleVisual(false)
            end
        end
        -- Шаг живёт на RenderStep после ControlModule (Input) и камеры (Camera).
        -- Проверено в клиенте: Humanoid:Move из PreSimulation действует лишь со
        -- следующего кадра, и в воздухе Humanoid тянет новую скорость к цели
        -- прошлого кадра — A/D разворачивали траекторию, а стрейф терял ~40%
        -- прироста. Здесь Move, скорость и поворот корпуса ставятся в одном кадре
        State.StepBound = pcall(function()
            RunService:BindToRenderStep(CONFIG.StepBindName, Enum.RenderPriority.Camera.Value + 1, runStep)
        end)
        if not State.StepBound then
            -- Фолбэк для executor'ов без BindToRenderStep: PreSimulation (dt) / Stepped (time, dt)
            local usePreSim = pcall(function() return RunService.PreSimulation end)
            local signal = usePreSim and RunService.PreSimulation or RunService.Stepped
            State.StepConnection = connect(signal, function(a, b) runStep(usePreSim and a or b) end)
        end
    end

    function Module.Toggle()
        local on = not State.Enabled
        Module.SetEnabled(on)
        setToggleVisual(on)
        notify("<font color=\"rgb(220,220,220)\">Bunnyhop</font>: " .. (on
            and "<font color=\"rgb(168,228,160)\">ON</font>"
            or "<font color=\"rgb(255, 85, 85)\">OFF</font>"))
    end

    -- Вызывается из OnInputActions MainScript (GUI уже отсёк processed и выбор бинда)
    function Module.OnInput(input)
        local bind = Main.Settings.Keybinds and Main.Settings.Keybinds[CONFIG.KeybindName]
        if bind and bind ~= Enum.KeyCode.Unknown and input.KeyCode == bind then
            Module.Toggle()
        end
    end

    function Module.ResetPhysics()
        for _, param in ipairs(CONFIG.Params) do
            State.Values[param.Key] = param.Default
            local control = env.GUI and env.GUI.Flags and env.GUI.Flags[param.Flag]
            if control then pcall(function() control:Set(param.Default, false) end) end
        end
    end

    Module.Handlers.Bhop = function(on) Module.SetEnabled(on) end
    Module.Handlers.BhopAutoStrafe = function(on) State.AutoStrafe = on and true or false end
    Module.Handlers.BhopStrafeMode = function(v)
        if table.find(CONFIG.StrafeModes, v) then State.StrafeMode = v end
    end
    Module.Handlers.BhopResetPhysics = Module.ResetPhysics
    for _, param in ipairs(CONFIG.Params) do
        Module.Handlers[param.Flag] = function(v) setValue(param.Key, v) end
    end

    -- Две секции на вкладке: управление слева, физика Source справа
    -- Управление bhop (левая колонка вкладки)
    function Module.BuildMainSection(tab)
        tab:CreateSection("BHOP & AUTOSTRAFE")
        State.Toggle = tab:CreateToggle("Bunnyhop", "Hold Space to bhop, body follows camera", "Bhop", false, CONFIG.KeybindName)
        tab:CreateToggle("Autostrafe", "Strafes are computed while Space is held", "BhopAutoStrafe", State.AutoStrafe)
        tab:CreateDropdown("Strafe Mode", "View: A/D strafe like CS, Directional: WASD = direction", CONFIG.StrafeModes, State.StrafeMode, "BhopStrafeMode")
        for _, param in ipairs(CONFIG.Params) do
            if CONFIG.MainParams[param.Key] then
                tab:CreateSlider(param.Label, param.Hint, param.Min, param.Max, State.Values[param.Key], param.Flag, param.Step)
            end
        end
    end

    -- Физика Source (правая колонка; MainScript ставит её под FLY SETTINGS)
    function Module.BuildPhysicsSection(tab)
        tab:CreateSection("SOURCE PHYSICS", "right")
        for _, param in ipairs(CONFIG.Params) do
            if not CONFIG.MainParams[param.Key] then
                tab:CreateSlider(param.Label, param.Hint, param.Min, param.Max, State.Values[param.Key], param.Flag, param.Step)
            end
        end
        tab:CreateButton("", "Reset Physics (CS2)", MainConfig.Colors.Accent, "BhopResetPhysics")
    end

    -- Совместимость со старым MainScript: обе секции подряд
    function Module.BuildSections(tab)
        Module.BuildMainSection(tab)
        Module.BuildPhysicsSection(tab)
    end

    function Module.Destroy()
        if State.Unloaded then return end
        Module.SetEnabled(false)
        State.Unloaded = true
        for _, connection in ipairs(State.Connections) do disconnect(connection) end
        table.clear(State.Connections)
        if shared.MM2_MovementModule == Module then shared.MM2_MovementModule = nil end
    end

    shared.MM2_MovementModule = Module
    return Module
end
