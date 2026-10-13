--[[
    WalkOnWalls — хождение по стенам и потолкам (клиент, executor).

    Как устроено:
      • Персонаж «парит» над поверхностью: высоту держит пружина по скорости
        (как обычный Humanoid), а не коллизия ног — поэтому нет дёрганий на стыках.
      • Своя гравитация вдоль -Up. Скорость разделена на две LinearVelocity:
        по плоскости поверхности (мягкий лимит силы — не таранит стены) и по
        нормали (жёсткий — мгновенно гасит падение при приземлении).
        Ориентация — AlignOrientation (современные констрейнты, без BodyMover'ов).
      • Up определяется рейкастами: земля под ногами (центр + кольцо),
        стена впереди (вогнутый переход), обход внешнего ребра (выпуклый переход
        с поворотом вокруг ребра), прилипание к поверхности в прыжке.
      • Камера и управление — игровой PlayerModule; камеру доворачиваем
        поверх него по гравитации, без второй копии модулей.

    Z — вкл/выкл.
    API: getgenv().WalkOnWalls.Enable / Disable / Toggle / IsEnabled / Unload
]]

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 1: INIT / GUARD
-- ══════════════════════════════════════════════════════════════════════════════

if not game:IsLoaded() then game.Loaded:Wait() end

local okEnv, genv = pcall(function() return getgenv() end)
if not okEnv or type(genv) ~= "table" then genv = _G end

if genv.WalkOnWalls then
    warn("[WalkOnWalls] Already running!")
    return
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 2: SERVICES
-- ══════════════════════════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 3: CONFIG
-- ══════════════════════════════════════════════════════════════════════════════

local CONFIG = {
    ToggleKey = Enum.KeyCode.Z,
    Notify    = true,

    -- Земля
    GroundProbeExtra = 1.6,   -- насколько глубже точки зависания ищем поверхность
    SnapTolerance    = 0.6,   -- допуск «стою на земле», пока уже стоим
    LandTolerance    = 0.15,  -- допуск приземления из воздуха
    RingRays         = 6,     -- лучей в кольце (сглаживание нормали)
    RingRadius       = 0.85,
    HoverStiffness   = 16,    -- 1/с: как быстро возвращаемся к высоте зависания
    MaxSnapSpeed     = 45,    -- макс. скорость прижатия к поверхности
    MaxRiseSpeed     = 10,    -- макс. скорость выталкивания (без «пинка» при заходе на стену)
    LandLookahead    = 1.0,   -- приземление засчитываем заранее: на столько кадров падения вперёд

    -- Движение
    GroundAccel  = 140,       -- studs/s² по плоскости
    AirAccel     = 55,
    MaxAccel       = 650,     -- лимит силы по плоскости (в единицах ускорения)
    NormalMaxAccel = 5000,    -- лимит силы по нормали: гасит падение за 1 кадр
    MaxFallSpeed = 160,
    TurnSpeed    = 14,        -- 1/с: разворот корпуса к направлению движения
    AlignResponsiveness = 120,

    -- Смена гравитации
    UpLerpSpeed       = 14,   -- 1/с: доворот Up физики
    CameraLerpSpeed   = 8,    -- 1/с: доворот Up камеры (мягче, чтобы не укачивало)
    TransitionMinAngle = 35,  -- °: меньше — склон, больше — новая «стена»
    TransitionLock    = 0.3,  -- с: после перехода нормаль земли не перебивает цель
    WallProbeLength   = 1.6,
    WallMinAbove      = 1.5,  -- стена должна быть выше центра HRP хотя бы на столько
    EdgeWrap          = true, -- обход внешних рёбер (сойти с крыши на стену)
    WrapProbeLength   = 3,
    WrapCooldown      = 0.12,
    CoyoteTime        = 0.12,
    StickOnImpact     = true, -- в прыжке прилипать к поверхности, в которую влетели
    AirResetTime      = 1.6,  -- с в воздухе без опоры → гравитация обратно вниз
    JumpGraceTime     = 0.25,
    TeleportResetDistance = 25, -- скачок позиции (телепорт игрой) → сброс в норму

    -- Камера
    CameraCollision       = true,
    CameraCollisionRadius = 0.4,

    -- Анимации
    AnimFade       = 0.15,
    RunThreshold   = 10,
    FilterRefresh  = 2,       -- с: обновление списка исключений рейкастов

    -- Фолбэк, если в персонаже нет Animate
    FallbackAnims = {
        R15 = { Idle = 507766388, Walk = 913402848, Run = 913376220, Jump = 507765000, Fall = 507767968 },
        R6  = { Idle = 180435571, Walk = 180426354, Run = 180426354, Jump = 125750702, Fall = 180436148 },
    },
    -- Где лежат анимации внутри Animate: { папка, имя Animation }
    AnimateMap = {
        Idle = { "idle", "Animation1" },
        Walk = { "walk", "WalkAnim" },
        Run  = { "run",  "RunAnim" },
        Jump = { "jump", "JumpAnim" },
        Fall = { "fall", "FallAnim" },
    },
}

local COS_MIN_TRANSITION = math.cos(math.rad(CONFIG.TransitionMinAngle))
local ZERO  = Vector3.zero
local UNIT_Y = Vector3.yAxis
local CAM_PRE_NAME  = "WalkOnWalls_CamPre"
local CAM_POST_NAME = "WalkOnWalls_CamPost"

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 4: STATE
-- ══════════════════════════════════════════════════════════════════════════════

local State = {
    Enabled = false,
    Active  = false,          -- физика навешана на текущего персонажа

    Character = nil, Humanoid = nil, Root = nil, Animator = nil,
    Attachment = nil, Align = nil, PlaneVelocity = nil, NormalVelocity = nil,

    Up = UNIT_Y, TargetUp = UNIT_Y, Facing = Vector3.new(0, 0, -1),
    Grounded = false, LastGroundTime = 0, LastJumpTime = -1, LastWrapTime = 0,
    AirTime = 0, TransitionUntil = 0,
    LastMoveDir = ZERO, LastPos = nil,

    CamUp = UNIT_Y, CamRot = CFrame.identity,
    RawCamCF = nil, RawCamFocus = nil, SavedOcclusion = nil, CameraBound = false,

    Tracks = {}, OwnAnimations = {}, CurrentAnim = nil,
    SavedStates = {},

    PlayerModule = nil, Controls = nil, Cameras = nil,
    RayParams = nil, LastFilterRefresh = 0,

    Connections = {},         -- глобальные (живут до Unload)
    CharConnections = {},     -- привязанные к персонажу
}

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 5: HELPERS
-- ══════════════════════════════════════════════════════════════════════════════

local function inst(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function notify(text)
    if not CONFIG.Notify then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "Walk On Walls", Text = text, Duration = 2 })
    end)
end

local function disconnectAll(list)
    for i = #list, 1, -1 do
        pcall(function() list[i]:Disconnect() end)
        list[i] = nil
    end
end

local function projectOnPlane(v, n)
    return v - n * v:Dot(n)
end

-- Частичный поворот от единичного a к единичному b (alpha = доля угла).
-- hintAxis задаёт ось для случая a ≈ -b, чтобы переворот был предсказуемым.
local function partialRot(a, b, alpha, hintAxis)
    local d = math.clamp(a:Dot(b), -1, 1)
    if d > 0.999999 then return CFrame.identity end
    local axis = a:Cross(b)
    if axis.Magnitude < 1e-4 then
        axis = hintAxis and projectOnPlane(hintAxis, a) or ZERO
        if axis.Magnitude < 1e-4 then
            axis = a:Cross(math.abs(a.X) < 0.9 and Vector3.xAxis or Vector3.zAxis)
        end
    end
    return CFrame.fromAxisAngle(axis.Unit, math.acos(d) * (alpha or 1))
end

-- Доля шага экспоненциального сглаживания, независимая от FPS
local function expAlpha(rate, dt)
    return 1 - math.exp(-rate * dt)
end

local function isAlive()
    local hum, root = State.Humanoid, State.Root
    return hum and root and hum.Parent and root.Parent and hum.Health > 0
end

local function getHoverHeight()
    local hum, root = State.Humanoid, State.Root
    local hip = hum.HipHeight
    if hum.RigType == Enum.HumanoidRigType.R6 then
        local leg = State.Character:FindFirstChild("Left Leg")
        hip = leg and leg.Size.Y or 2
    end
    return root.Size.Y / 2 + hip
end

local function getJumpVelocity()
    local hum = State.Humanoid
    if hum.UseJumpPower then return hum.JumpPower end
    return math.sqrt(2 * Workspace.Gravity * hum.JumpHeight)
end

-- Рейкасты: игнорируем всех персонажей, триггеры (CanCollide=false) и воду
local function refreshFilter()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then list[#list + 1] = plr.Character end
    end
    local cam = Workspace.CurrentCamera
    if cam then list[#list + 1] = cam end
    State.RayParams.FilterDescendantsInstances = list
    State.LastFilterRefresh = os.clock()
end

local function cast(origin, dir)
    return Workspace:Raycast(origin, dir, State.RayParams)
end

-- Игровой PlayerModule: ввод (Controls) и камера (Cameras)
local function resolvePlayerModule()
    if State.Controls and State.Cameras then return end
    pcall(function()
        local ps = LocalPlayer:FindFirstChildOfClass("PlayerScripts") or LocalPlayer:WaitForChild("PlayerScripts", 5)
        local pmScript = ps and ps:FindFirstChild("PlayerModule")
        if not pmScript then return end
        State.PlayerModule = require(pmScript)
        State.Controls = State.PlayerModule:GetControls()
        State.Cameras = State.PlayerModule:GetCameras()
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 6: INPUT
-- ══════════════════════════════════════════════════════════════════════════════

local function getMoveVector()
    local controls = State.Controls
    if controls then
        local ok, v = pcall(controls.GetMoveVector, controls)
        if ok and typeof(v) == "Vector3" then return v end
    end
    -- Фолбэк: WASD напрямую
    local v = ZERO
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then v += Vector3.new(0, 0, -1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then v += Vector3.new(0, 0, 1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then v += Vector3.new(-1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then v += Vector3.new(1, 0, 0) end
    return v.Magnitude > 1 and v.Unit or v
end

local function wantsJump()
    -- При PlatformStand ControlModule не пишет Humanoid.Jump — читаем активный
    -- контроллер ввода напрямую (клавиатура, тач-кнопка, геймпад)
    local controls = State.Controls
    local active = controls and controls.activeController
    if active and active.GetIsJumping then
        local ok, jumping = pcall(active.GetIsJumping, active)
        if ok and jumping then return true end
    end
    if State.Humanoid.Jump then return true end
    -- Фолбэк, если ControlModule недоступен; не прыгаем, пока печатают в чат
    return UserInputService:IsKeyDown(Enum.KeyCode.Space) and not UserInputService:GetFocusedTextBox()
end

-- Направление «вперёд» камеры в плоскости текущей гравитации
local function getCameraForward(up)
    local cf = Workspace.CurrentCamera.CFrame
    local fwd = projectOnPlane(cf.LookVector, up)
    if fwd.Magnitude < 0.15 then
        -- Смотрим почти вдоль Up — вперёд это «верх» экрана
        fwd = projectOnPlane(cf.UpVector * (cf.LookVector:Dot(up) < 0 and 1 or -1), up)
    end
    return fwd.Magnitude > 1e-3 and fwd.Unit or nil
end

local function getMoveDirection(up)
    local mv = getMoveVector()
    if mv.Magnitude < 0.01 then return ZERO end
    local fwd = getCameraForward(up)
    if not fwd then return ZERO end
    local right = fwd:Cross(up)
    local dir = right * mv.X - fwd * mv.Z
    return dir.Magnitude > 1 and dir.Unit or dir
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 7: ANIMATIONS
-- ══════════════════════════════════════════════════════════════════════════════

local function loadAnimations()
    local hum = State.Humanoid
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = inst("Animator", {}, hum)
    end
    State.Animator = animator

    local animate = State.Character:FindFirstChild("Animate")
    local fallback = CONFIG.FallbackAnims[hum.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15"]

    for name, path in pairs(CONFIG.AnimateMap) do
        local anim
        local folder = animate and animate:FindFirstChild(path[1])
        local obj = folder and folder:FindFirstChild(path[2])
        if obj and obj:IsA("Animation") then
            anim = obj
        else
            anim = inst("Animation", { AnimationId = "rbxassetid://" .. fallback[name] })
            table.insert(State.OwnAnimations, anim)
        end
        local ok, track = pcall(animator.LoadAnimation, animator, anim)
        if ok and track then
            track.Priority = Enum.AnimationPriority.Movement
            track.Looped = name ~= "Jump"
            State.Tracks[name] = track
        end
    end

    -- Гасим базовые треки Animate, чтобы не смешивались с нашими
    local ids = {}
    for _, track in pairs(State.Tracks) do ids[track.Animation.AnimationId] = true end
    pcall(function()
        for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
            if t.Animation and ids[t.Animation.AnimationId] then
                t:Stop(CONFIG.AnimFade)
            end
        end
    end)
end

local function playAnim(name, speed)
    local track = State.Tracks[name]
    if not track then return end
    if State.CurrentAnim ~= name then
        local prev = State.CurrentAnim and State.Tracks[State.CurrentAnim]
        if prev then prev:Stop(CONFIG.AnimFade) end
        track:Play(CONFIG.AnimFade)
        State.CurrentAnim = name
    end
    if speed then track:AdjustSpeed(speed) end
end

local function unloadAnimations()
    for name, track in pairs(State.Tracks) do
        pcall(function()
            track:Stop(CONFIG.AnimFade)
            track:Destroy()
        end)
        State.Tracks[name] = nil
    end
    for _, anim in ipairs(State.OwnAnimations) do pcall(function() anim:Destroy() end) end
    table.clear(State.OwnAnimations)
    State.CurrentAnim = nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 8: SURFACE PROBING
-- ══════════════════════════════════════════════════════════════════════════════

-- Земля под ногами: центр (вес 2) + кольцо лучей → расстояние и сглаженная нормаль
local function probeGround(pos, up, hover)
    local down = -up * (hover + CONFIG.GroundProbeExtra)
    local center = cast(pos, down)

    local sum, weight, minDist = ZERO, 0, nil
    if center then
        sum += center.Normal * 2
        weight += 2
    end

    local fwd = projectOnPlane(State.Facing, up)
    fwd = fwd.Magnitude > 1e-3 and fwd.Unit or partialRot(UNIT_Y, up, 1):VectorToWorldSpace(Vector3.zAxis)
    local right = fwd:Cross(up)
    local n = CONFIG.RingRays
    for i = 1, n do
        local a = (i - 1) / n * math.pi * 2
        local offset = (fwd * math.cos(a) + right * math.sin(a)) * CONFIG.RingRadius
        local hit = cast(pos + offset, down)
        if hit then
            sum += hit.Normal
            weight += 1
            minDist = minDist and math.min(minDist, hit.Distance) or hit.Distance
        end
    end

    if weight == 0 then return nil end
    local normal = sum.Magnitude > 1e-3 and sum.Unit or up
    return {
        Distance = center and center.Distance or minDist,
        Normal = normal,
    }
end

-- Стена впереди по ходу движения (вогнутый угол «пол → стена»).
-- Луч идёт из центра HRP: стена должна быть выше центра, иначе после поворота
-- луч «вниз» пройдёт над её краем и персонажа унесёт (бортики, ящики, перила).
-- Всё, что ниже, — ступенька/препятствие: перешагивает пружина или упираемся.
local function probeWall(pos, up, dir, speed, dt)
    local root = State.Root
    local length = CONFIG.WallProbeLength + root.Size.Z / 2 + speed * dt * 2
    local hit = cast(pos, dir * length)
    if not hit or hit.Normal:Dot(up) >= COS_MIN_TRANSITION or hit.Normal:Dot(dir) > -0.3 then
        return nil
    end
    -- Подтверждаем высоту стены: она должна продолжаться выше центра HRP,
    -- чтобы после поворота луч земли гарантированно в неё попадал
    local check = cast(pos + up * CONFIG.WallMinAbove, dir * (length + 0.5))
    if not check or check.Normal:Dot(hit.Normal) < 0.8 then return nil end
    return hit
end

-- Переход на поверхность (стена впереди / удар в прыжке). Делается мгновенно:
-- при плавном повороте персонаж продолжает лететь в стену, корпус врезается
-- в неё посреди поворота и физика выбрасывает его с огромной скоростью.
-- Здесь сразу ставим центр на высоту зависания от поверхности и поворачиваем
-- импульс вдоль неё; сам корпус доворачивает AlignOrientation, камера — плавно.
local function snapToSurface(hit, hover, now)
    local root = State.Root
    local up = State.Up
    local n = hit.Normal
    local pos = root.Position
    local rot = partialRot(up, n, 1, State.Facing:Cross(up))

    local newPos = pos + n * (hover - (pos - hit.Position):Dot(n))
    root.CFrame = CFrame.new(newPos) * root.CFrame.Rotation
    root.AssemblyLinearVelocity = rot:VectorToWorldSpace(root.AssemblyLinearVelocity)

    State.Up = n
    State.TargetUp = n
    State.Facing = rot:VectorToWorldSpace(State.Facing)
    State.LastMoveDir = rot:VectorToWorldSpace(State.LastMoveDir)
    State.TransitionUntil = now + CONFIG.TransitionLock
    State.LastGroundTime = now
    State.Grounded = true
    State.LastPos = newPos
end

-- Выпуклое ребро: под ногами пусто, ищем боковую грань позади-внизу
-- и поворачиваем персонажа вокруг ребра на неё
local function tryEdgeWrap(pos, up, hover, now)
    local dir = State.LastMoveDir
    if dir.Magnitude < 0.5 then return false end
    dir = projectOnPlane(dir, up)
    if dir.Magnitude < 1e-3 then return false end
    dir = dir.Unit

    for _, depth in ipairs({ hover + 0.15, hover + 0.6 }) do
        local origin = pos - up * depth + dir * 0.6
        local hit = cast(origin, -dir * CONFIG.WrapProbeLength)
        if hit and hit.Normal:Dot(up) < COS_MIN_TRANSITION and hit.Normal:Dot(dir) > 0.3 then
            local root = State.Root
            local n = hit.Normal
            -- Точка на ребре: проекция «ступней» на плоскость боковой грани
            local feet = pos - up * hover
            local edge = feet - n * (feet - hit.Position):Dot(n)
            local rot = partialRot(up, n, 1, dir:Cross(up))

            local newPos = edge + rot:VectorToWorldSpace(pos - edge)
            local newRot = rot * root.CFrame.Rotation
            local vel = root.AssemblyLinearVelocity

            root.CFrame = CFrame.new(newPos) * newRot
            root.AssemblyLinearVelocity = rot:VectorToWorldSpace(vel)
            State.Align.CFrame = newRot

            State.Up = n
            State.TargetUp = n
            State.Facing = rot:VectorToWorldSpace(State.Facing)
            State.LastMoveDir = rot:VectorToWorldSpace(State.LastMoveDir)
            State.LastWrapTime = now
            State.LastGroundTime = now
            State.TransitionUntil = now + 0.1
            State.LastPos = newPos
            return true
        end
    end
    return false
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 9: CHARACTER ATTACH / DETACH
-- ══════════════════════════════════════════════════════════════════════════════

local CONTROLLED_STATES = { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll }

local function resetGravityState()
    State.Up, State.TargetUp = UNIT_Y, UNIT_Y
    State.Grounded = false
    State.AirTime = 0
    State.TransitionUntil = 0
    State.LastMoveDir = ZERO
    State.LastPos = nil
end

local function detachCharacter(restoreUpright)
    if not State.Active then return end
    State.Active = false
    disconnectAll(State.CharConnections)
    unloadAnimations()

    for _, key in ipairs({ "PlaneVelocity", "NormalVelocity", "Align", "Attachment" }) do
        if State[key] then pcall(function() State[key]:Destroy() end) end
        State[key] = nil
    end

    local hum, root = State.Humanoid, State.Root
    if hum and hum.Parent then
        pcall(function()
            hum.PlatformStand = false
            for state, enabled in pairs(State.SavedStates) do hum:SetStateEnabled(state, enabled) end
        end)
    end
    table.clear(State.SavedStates)

    -- Ставим на ноги относительно мировой гравитации
    if restoreUpright and root and root.Parent and hum and hum.Health > 0 then
        pcall(function()
            local cf = root.CFrame
            local look = projectOnPlane(cf.LookVector, UNIT_Y)
            if look.Magnitude < 0.1 then look = projectOnPlane(-cf.UpVector, UNIT_Y) end
            if look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
            root.CFrame = CFrame.lookAt(cf.Position, cf.Position + look.Unit)
            root.AssemblyAngularVelocity = ZERO
            hum:ChangeState(Enum.HumanoidStateType.Freefall)
        end)
    end

    resetGravityState()
end

local function attachCharacter(char)
    if State.Active or not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return end

    State.Character, State.Humanoid, State.Root = char, hum, root
    resetGravityState()
    local look = projectOnPlane(root.CFrame.LookVector, UNIT_Y)
    State.Facing = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
    State.LastGroundTime = os.clock()

    local ok, err = pcall(function()
        State.Attachment = inst("Attachment", { Name = "WalkOnWalls_Attachment" }, root)
        State.Align = inst("AlignOrientation", {
            Name = "WalkOnWalls_Align",
            Mode = Enum.OrientationAlignmentMode.OneAttachment,
            Attachment0 = State.Attachment,
            Responsiveness = CONFIG.AlignResponsiveness,
            MaxTorque = math.huge,
            MaxAngularVelocity = math.huge,
            CFrame = CFrame.fromMatrix(ZERO, State.Facing:Cross(UNIT_Y), UNIT_Y, -State.Facing),
        }, root)
        -- Плоскость поверхности: ходьба
        State.PlaneVelocity = inst("LinearVelocity", {
            Name = "WalkOnWalls_PlaneVelocity",
            Attachment0 = State.Attachment,
            RelativeTo = Enum.ActuatorRelativeTo.World,
            VelocityConstraintMode = Enum.VelocityConstraintMode.Plane,
            PrimaryTangentAxis = State.Facing,
            SecondaryTangentAxis = State.Facing:Cross(UNIT_Y),
            PlaneVelocity = Vector2.zero,
            MaxForce = root.AssemblyMass * CONFIG.MaxAccel,
        }, root)
        -- Нормаль: гравитация, зависание, прыжок
        State.NormalVelocity = inst("LinearVelocity", {
            Name = "WalkOnWalls_NormalVelocity",
            Attachment0 = State.Attachment,
            RelativeTo = Enum.ActuatorRelativeTo.World,
            VelocityConstraintMode = Enum.VelocityConstraintMode.Line,
            LineDirection = UNIT_Y,
            LineVelocity = 0,
            MaxForce = root.AssemblyMass * CONFIG.NormalMaxAccel,
        }, root)

        for _, st in ipairs(CONTROLLED_STATES) do
            State.SavedStates[st] = hum:GetStateEnabled(st)
            hum:SetStateEnabled(st, false)
        end
        hum.PlatformStand = true
        loadAnimations()
    end)

    State.Active = true
    if not ok then
        warn("[WalkOnWalls] attach failed: " .. tostring(err))
        detachCharacter(true)
        return
    end

    table.insert(State.CharConnections, hum.Died:Connect(function()
        detachCharacter(false)
    end))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 10: PHYSICS STEP
-- ══════════════════════════════════════════════════════════════════════════════

local function physicsStep(dt)
    if not State.Active then return end
    if not isAlive() then
        detachCharacter(false)
        return
    end
    dt = math.clamp(dt, 1 / 240, 1 / 15)

    local hum, root = State.Humanoid, State.Root
    local now = os.clock()
    if now - State.LastFilterRefresh > CONFIG.FilterRefresh then refreshFilter() end

    -- Сидим — отдаём персонажа игре
    if hum.SeatPart then
        State.PlaneVelocity.Enabled = false
        State.NormalVelocity.Enabled = false
        State.Align.Enabled = false
        return
    end
    State.PlaneVelocity.Enabled = true
    State.NormalVelocity.Enabled = true
    State.Align.Enabled = true
    if not hum.PlatformStand then hum.PlatformStand = true end

    local pos = root.Position
    -- Игра телепортнула (смена раунда, лобби) — возвращаем нормальную гравитацию
    if State.LastPos and (pos - State.LastPos).Magnitude > CONFIG.TeleportResetDistance then
        State.Up, State.TargetUp = UNIT_Y, UNIT_Y
        State.TransitionUntil = 0
        local look = projectOnPlane(State.Facing, UNIT_Y)
        State.Facing = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
    end
    State.LastPos = pos

    local up = State.Up
    local hover = getHoverHeight()
    -- Скорость именно точки HRP (там висят констрейнты). AssemblyLinearVelocity —
    -- скорость центра масс: пока корпус доворачивается, в неё подмешивается
    -- вращение, и контроллер начинал «держать» лишние 10–15 studs/s
    local vel = root:GetVelocityAtPosition(root.Position)
    local moveDir = getMoveDirection(up)
    local moving = moveDir.Magnitude > 0.05

    -- ── Определение опоры ──────────────────────────────────────────────────
    local justJumped = now - State.LastJumpTime < CONFIG.JumpGraceTime
    local ground = probeGround(pos, up, hover)
    -- В воздухе допуск растёт со скоростью падения: ловим землю за кадр ДО
    -- пересечения высоты зависания, а не после (иначе персонаж «проседает»)
    local fallSpeed = math.max(0, -vel:Dot(up))
    local tolerance = State.Grounded and CONFIG.SnapTolerance
        or (CONFIG.LandTolerance + fallSpeed * dt * CONFIG.LandLookahead)
    local grounded = ground ~= nil and not justJumped and ground.Distance <= hover + tolerance

    -- Стена впереди → мгновенно переходим на неё (кадр пропускаем)
    if moving and now > State.TransitionUntil then
        local wall = probeWall(pos, up, moveDir.Unit, projectOnPlane(vel, up).Magnitude, dt)
        if wall then
            snapToSurface(wall, hover, now)
            return
        end
    end

    if grounded then
        if now > State.TransitionUntil then State.TargetUp = ground.Normal end
        State.LastGroundTime = now
        State.AirTime = 0
    else
        State.AirTime += dt

        -- Сошли с ребра — огибаем его (кадр пропускаем: позиция уже выставлена)
        if CONFIG.EdgeWrap and not justJumped
            and now - State.LastGroundTime < CONFIG.CoyoteTime
            and now - State.LastWrapTime > CONFIG.WrapCooldown
            and tryEdgeWrap(pos, up, hover, now) then
            State.Grounded = true
            return
        end

        -- Влетели в поверхность — прилипаем к ней
        if CONFIG.StickOnImpact and State.AirTime > 0.08 and now > State.TransitionUntil then
            local speed = vel.Magnitude
            if speed > 1 then
                local vdir = vel / speed
                local hit = cast(pos, vdir * (speed * dt * 2 + root.Size.Y))
                if hit and hit.Normal:Dot(up) < COS_MIN_TRANSITION and hit.Normal:Dot(vdir) < -0.2
                    and cast(pos, -hit.Normal * (hover + CONFIG.GroundProbeExtra + speed * dt * 2 + 1)) then
                    snapToSurface(hit, hover, now)
                    return
                end
            end
        end

        if State.AirTime > CONFIG.AirResetTime then State.TargetUp = UNIT_Y end
    end
    State.Grounded = grounded

    -- ── Доворот гравитации ─────────────────────────────────────────────────
    local rot = partialRot(up, State.TargetUp, expAlpha(CONFIG.UpLerpSpeed, dt), State.Facing:Cross(up))
    up = rot:VectorToWorldSpace(up).Unit
    State.Up = up
    State.Facing = rot:VectorToWorldSpace(State.Facing)
    -- Импульс поворачивается вместе с гравитацией: движение «в стену»
    -- плавно становится движением «вверх по стене», без рывка
    vel = rot:VectorToWorldSpace(vel)

    -- ── Ориентация корпуса ─────────────────────────────────────────────────
    local facing = projectOnPlane(State.Facing, up)
    if facing.Magnitude < 1e-3 then facing = getCameraForward(up) or partialRot(UNIT_Y, up, 1):VectorToWorldSpace(Vector3.new(0, 0, -1)) end
    facing = facing.Unit

    local desired
    if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
        desired = getCameraForward(up)    -- shift-lock / первое лицо: смотрим туда же, куда камера
    elseif moving then
        desired = moveDir.Unit
    end
    if desired then
        facing = partialRot(facing, desired, expAlpha(CONFIG.TurnSpeed, dt), up):VectorToWorldSpace(facing)
        facing = projectOnPlane(facing, up).Unit
    end
    State.Facing = facing
    State.Align.CFrame = CFrame.fromMatrix(ZERO, facing:Cross(up), up, -facing)

    -- ── Скорость ───────────────────────────────────────────────────────────
    if moving then
        State.LastMoveDir = moveDir.Unit
    else
        local vtNow = projectOnPlane(vel, up)
        if vtNow.Magnitude > 1 then State.LastMoveDir = vtNow.Unit end
    end

    local vn = vel:Dot(up)
    local vt = vel - up * vn
    local target = moveDir * hum.WalkSpeed
    local diff = target - vt
    local maxStep = (grounded and CONFIG.GroundAccel or CONFIG.AirAccel) * dt
    if diff.Magnitude > maxStep then diff = diff.Unit * maxStep end
    vt += diff

    if grounded then
        if wantsJump() then
            -- Импульсом: LinearVelocity с лимитом силы не наберёт скорость прыжка
            -- за один шаг, а со следующего кадра vn читается из реальной скорости
            vn = getJumpVelocity()
            root.AssemblyLinearVelocity = vt + up * vn
            State.LastJumpTime = now
            State.Grounded = false
        else
            -- Пружина по скорости: держим ровно hover над поверхностью
            -- Вниз прижимаем быстро, вверх выталкиваем ограниченно: после захода
            -- на стену до неё ближе hover, и без лимита персонажа отстреливает
            vn = math.clamp((hover - ground.Distance) * CONFIG.HoverStiffness, -CONFIG.MaxSnapSpeed, CONFIG.MaxRiseSpeed)
        end
    else
        vn = math.max(vn - Workspace.Gravity * dt, -CONFIG.MaxFallSpeed)
    end

    local mass = root.AssemblyMass
    local right = facing:Cross(up)
    State.PlaneVelocity.MaxForce = mass * CONFIG.MaxAccel
    State.PlaneVelocity.PrimaryTangentAxis = facing
    State.PlaneVelocity.SecondaryTangentAxis = right
    State.PlaneVelocity.PlaneVelocity = Vector2.new(vt:Dot(facing), vt:Dot(right))
    State.NormalVelocity.MaxForce = mass * CONFIG.NormalMaxAccel
    State.NormalVelocity.LineDirection = up
    State.NormalVelocity.LineVelocity = vn

    -- ── Анимации ───────────────────────────────────────────────────────────
    if not State.Grounded then
        playAnim(now - State.LastJumpTime < 0.35 and "Jump" or "Fall")
    else
        local speed = vt.Magnitude
        if speed > 0.75 then
            if speed >= CONFIG.RunThreshold then
                playAnim("Run", math.clamp(speed / 16, 0.4, 2.5))
            else
                playAnim("Walk", math.clamp(speed / 8, 0.4, 2))
            end
        else
            playAnim("Idle", 1)
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 11: CAMERA
-- ══════════════════════════════════════════════════════════════════════════════
-- Игровой CameraModule считает камеру в «мировой» гравитации и читает свой
-- прошлый Camera.CFrame. Поэтому: до него возвращаем «сырой» CFrame, после —
-- запоминаем сырой и поворачиваем вокруг фокуса на накопленный поворот гравитации.

local function cameraApplicable()
    local cam = Workspace.CurrentCamera
    return State.Active and cam and cam.CameraType == Enum.CameraType.Custom
        and cam.CameraSubject == State.Humanoid
end

local function suspendOcclusion()
    local cams = State.Cameras
    if not cams then return end
    local occ = cams.activeOcclusionModule
    if occ then
        State.SavedOcclusion = occ
        cams.activeOcclusionModule = nil
        pcall(occ.Enable, occ, false)
    end
end

local function restoreOcclusion()
    local cams, occ = State.Cameras, State.SavedOcclusion
    State.SavedOcclusion = nil
    if not cams or not occ then return end
    if cams.activeOcclusionModule == nil then
        cams.activeOcclusionModule = occ
        pcall(occ.Enable, occ, true)
    end
end

local function camPre()
    local cam = Workspace.CurrentCamera
    if State.RawCamCF and cam then
        cam.CFrame = State.RawCamCF
        cam.Focus = State.RawCamFocus
    end
end

local function camPost(dt)
    local cam = Workspace.CurrentCamera
    if not cameraApplicable() then
        State.RawCamCF, State.RawCamFocus = nil, nil
        return
    end
    -- Модуль мог пересоздать occlusion (смена режима/персонажа)
    if State.Cameras and State.Cameras.activeOcclusionModule then suspendOcclusion() end

    local raw, focus = cam.CFrame, cam.Focus
    State.RawCamCF, State.RawCamFocus = raw, focus

    local step = partialRot(State.CamUp, State.Up, expAlpha(CONFIG.CameraLerpSpeed, dt), raw.RightVector)
    State.CamUp = step:VectorToWorldSpace(State.CamUp).Unit
    State.CamRot = (step * State.CamRot):Orthonormalize()

    local rot = State.CamRot
    local f = focus.Position
    local camPos = f + rot:VectorToWorldSpace(raw.Position - f)

    -- Своя коллизия камеры (встроенная считает в неповёрнутом пространстве)
    if CONFIG.CameraCollision then
        local offset = camPos - f
        if offset.Magnitude > 0.6 then
            local ok, hit = pcall(Workspace.Spherecast, Workspace, f, CONFIG.CameraCollisionRadius, offset, State.RayParams)
            if not ok then hit = cast(f, offset) end
            if hit then
                camPos = f + offset.Unit * math.max(hit.Distance - 0.1, 0.5)
            end
        end
    end

    cam.CFrame = CFrame.new(camPos) * (rot * raw.Rotation)
end

local function bindCamera()
    if State.CameraBound then return end
    State.CamUp, State.CamRot = UNIT_Y, CFrame.identity
    State.RawCamCF, State.RawCamFocus = nil, nil
    RunService:BindToRenderStep(CAM_PRE_NAME, Enum.RenderPriority.Camera.Value - 1, camPre)
    RunService:BindToRenderStep(CAM_POST_NAME, Enum.RenderPriority.Camera.Value + 1, camPost)
    State.CameraBound = true
end

local function unbindCamera()
    if not State.CameraBound then return end
    pcall(RunService.UnbindFromRenderStep, RunService, CAM_PRE_NAME)
    pcall(RunService.UnbindFromRenderStep, RunService, CAM_POST_NAME)
    State.CameraBound = false
    local cam = Workspace.CurrentCamera
    if State.RawCamCF and cam then
        cam.CFrame = State.RawCamCF
        cam.Focus = State.RawCamFocus
    end
    State.RawCamCF, State.RawCamFocus = nil, nil
    State.CamUp, State.CamRot = UNIT_Y, CFrame.identity
    restoreOcclusion()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 12: PUBLIC API
-- ══════════════════════════════════════════════════════════════════════════════

local API = {}

function API.Enable()
    if State.Enabled then return end
    State.Enabled = true
    resolvePlayerModule()
    refreshFilter()
    attachCharacter(LocalPlayer.Character)
    bindCamera()
    notify("Включено (" .. CONFIG.ToggleKey.Name .. ")")
end

function API.Disable()
    if not State.Enabled then return end
    State.Enabled = false
    detachCharacter(true)
    unbindCamera()
    notify("Выключено")
end

function API.Toggle()
    if State.Enabled then API.Disable() else API.Enable() end
end

function API.IsEnabled()
    return State.Enabled
end

function API.Unload()
    API.Disable()
    disconnectAll(State.Connections)
    if genv.WalkOnWalls == API then genv.WalkOnWalls = nil end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 13: CONNECTIONS
-- ══════════════════════════════════════════════════════════════════════════════

State.RayParams = RaycastParams.new()
State.RayParams.FilterType = Enum.RaycastFilterType.Exclude
State.RayParams.IgnoreWater = true
pcall(function() State.RayParams.RespectCanCollide = true end)

local stepSignal = RunService.PreSimulation or RunService.Stepped
table.insert(State.Connections, stepSignal:Connect(function(a, b)
    -- PreSimulation(dt) / Stepped(time, dt)
    local dt = b or a
    local ok, err = pcall(physicsStep, dt)
    if not ok then
        warn("[WalkOnWalls] step error: " .. tostring(err))
    end
end))

table.insert(State.Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == CONFIG.ToggleKey then API.Toggle() end
end))

table.insert(State.Connections, LocalPlayer.CharacterAdded:Connect(function(char)
    detachCharacter(false)
    if not State.Enabled then return end
    char:WaitForChild("HumanoidRootPart", 10)
    char:WaitForChild("Humanoid", 10)
    task.wait() -- даём Animate и Animator появиться
    if State.Enabled and LocalPlayer.Character == char then
        refreshFilter()
        attachCharacter(char)
    end
end))

table.insert(State.Connections, Players.PlayerAdded:Connect(function(plr)
    table.insert(State.Connections, plr.CharacterAdded:Connect(refreshFilter))
end))
for _, plr in ipairs(Players:GetPlayers()) do
    table.insert(State.Connections, plr.CharacterAdded:Connect(refreshFilter))
end

genv.WalkOnWalls = API
notify("Загружено — нажми " .. CONFIG.ToggleKey.Name)
