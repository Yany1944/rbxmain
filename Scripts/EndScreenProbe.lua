-- EndScreenProbe.lua — фаза 0: разведка экрана конца раунда MM2 (откуда игра берёт аватары игроков).
-- Диагностика, не фича: ничего в игре не меняет, только наблюдает. Работает в фоне 1–2 раунда.
-- Отчёт: VioCFG/Violite/Probe/EndScreenProbe_<дата>.log + дубль в print (префикс [EndScreenProbe]).
-- Управление: End — снимок видимого GUI; getgenv().EndScreenProbe.Stop() — остановка и итоговая сводка.

if not game:IsLoaded() then game.Loaded:Wait() end
local env = getgenv and getgenv() or _G
if env.EndScreenProbe and env.EndScreenProbe.Alive then
    warn("[EndScreenProbe] Already running! Остановить: getgenv().EndScreenProbe.Stop()")
    return
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 1: SERVICES
-- ══════════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local MyId = LocalPlayer.UserId

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 2: CONFIG
-- ══════════════════════════════════════════════════════════════════════════════

local CONFIG = {
    Folder = "VioCFG/Violite/Probe",
    Prefix = "[EndScreenProbe]",
    MaxDuration = 1200,             -- авто-стоп через 20 минут, даже если раунды не закончились
    RoundsToWatch = 2,              -- после стольких концов раунда…
    TailAfterRound = 45,            -- …и стольких секунд хвоста — авто-стоп
    FlushInterval = 3,
    SnapshotKey = Enum.KeyCode.End,
    RoundEndDumpDelays = {0.3, 2, 5},

    -- Лимиты, чтобы лог не утонул в шуме HUD'а
    ImageChangeLimit = 6,           -- подробных логов смены Image на один лейбл
    VisibleChangeLimit = 8,         -- подробных логов смены Visible на один объект
    SetLogLimit = 4,                -- подробных логов __newindex на (объект, свойство)
    VisDepth = 4,                   -- следим за Visible у объектов не глубже N от ScreenGui
    TreeLineLimit = 700,
    TreeDumpCooldown = 3,
    MaxTreeDumps = 60,
    MaxViewportDumps = 6,           -- на один ViewportFrame
    QueueLimit = 5000,
    RemoteBurstLimit = 3,           -- логов на ремоут за окно RemoteWindow
    RemoteWindow = 10,

    -- Хуки. hookfunction по умолчанию выключен: на части executor'ов обёртка yield'ящей
    -- C-функции ломает её, и игра перестаёт получать миниатюры — лог станет недостоверным.
    HookNamecall = true,
    HookNewIndex = true,
    HookFunctions = false,

    ScanScripts = true,             -- декомпиляция и grep клиентских скриптов игры
    ScanScriptLimit = 400,
    ScanHitsPerScript = 6,
    ScanPatterns = {"GetUserThumbnailAsync", "rbxthumb", "ThumbnailType", "ViewportFrame",
        "HumanoidDescription", "CreateHumanoidModel", "rbxcdn", "AvatarBust", "HeadShot"},

    WatchedMethods = {
        GetUserThumbnailAsync = true,
        GetHumanoidDescriptionFromUserId = true,
        GetHumanoidDescriptionFromUserIdAsync = true,
        GetHumanoidDescriptionFromOutfitId = true,
        GetCharacterAppearanceInfoAsync = true,
        GetCharacterAppearanceAsync = true,
        CreateHumanoidModelFromDescription = true,
        CreateHumanoidModelFromDescriptionAsync = true,
        CreateHumanoidModelFromUserId = true,
        CreateHumanoidModelFromUserIdAsync = true,
    },
    WatchedProps = {Image = true, Visible = true, Enabled = true},
    Capabilities = {"identifyexecutor", "request", "http_request", "syn.request", "http.request",
        "fluxus.request", "writefile", "readfile", "isfile", "appendfile", "makefolder", "isfolder",
        "getcustomasset", "getsynasset", "hookfunction", "hookmetamethod", "newcclosure", "checkcaller",
        "getconnections", "getcallingscript", "getnamecallmethod", "decompile", "getscripts",
        "restorefunction", "cloneref", "gethui"},
}

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 3: STATE
-- ══════════════════════════════════════════════════════════════════════════════

local State = {
    Alive = true,
    StartClock = os.clock(),
    File = nil,
    All = {},
    Pending = {},
    Connections = {},
    Threads = {},
    Queue = {},
    Dropped = 0,
    Watched = setmetatable({}, {__mode = "k"}),
    VisWatched = setmetatable({}, {__mode = "k"}),
    ImageStats = setmetatable({}, {__mode = "k"}),
    VisStats = setmetatable({}, {__mode = "k"}),
    SetStats = setmetatable({}, {__mode = "k"}),
    TreeDumpAt = setmetatable({}, {__mode = "k"}),
    Viewports = setmetatable({}, {__mode = "k"}),
    Remotes = setmetatable({}, {__mode = "k"}),
    Calls = {},
    Counters = {ImagesWatched = 0, ImageChanges = 0, MineHits = 0, TreeDumps = 0, Viewports = 0},
    Map = nil,
    RoundEnds = 0,
}

local Probe = {Alive = true, State = State, CONFIG = CONFIG}
env.EndScreenProbe = Probe

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 4: HELPERS — лог, форматирование, фиче-детект
-- ══════════════════════════════════════════════════════════════════════════════

-- Ищем глобаль executor'а, в том числе вложенную ("syn.request")
local function resolve(name)
    local ok, value = pcall(function()
        local cur
        for part in string.gmatch(name, "[^%.]+") do
            if cur == nil then
                cur = env[part]
                if cur == nil and getfenv then cur = getfenv(0)[part] end
            else
                cur = type(cur) == "table" and cur[part] or nil
            end
            if cur == nil then return nil end
        end
        return cur
    end)
    return ok and value or nil
end

local newcc = resolve("newcclosure") or function(f) return f end
local isCaller = resolve("checkcaller") or function() return false end
local getCalling = resolve("getcallingscript")
local fs = {
    write = resolve("writefile"), append = resolve("appendfile"),
    isfolder = resolve("isfolder"), makefolder = resolve("makefolder"),
}

local function elapsed()
    return string.format("%7.2f", os.clock() - State.StartClock)
end

local function log(tag, msg)
    local line = string.format("[%s] %-11s %s", elapsed(), tag, msg)
    table.insert(State.All, line)
    table.insert(State.Pending, line)
    print(CONFIG.Prefix .. " " .. line)
end

local function flush()
    if not State.File or not fs.write or #State.Pending == 0 then return end
    local chunk = table.concat(State.Pending, "\n") .. "\n"
    table.clear(State.Pending)
    local ok = fs.append and pcall(fs.append, State.File, chunk)
    if not ok then pcall(fs.write, State.File, table.concat(State.All, "\n") .. "\n") end
end

local function track(conn)
    table.insert(State.Connections, conn)
    return conn
end

local function short(s, n)
    s = tostring(s)
    return #s > n and (string.sub(s, 1, n) .. "…") or s
end

local function fmt(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then return string.format("%q", short(v, 120)) end
    if t == "Instance" then
        local ok, name = pcall(v.GetFullName, v)
        return "<" .. v.ClassName .. " " .. (ok and name or "?") .. ">"
    end
    if t == "table" then
        if depth >= 2 then return "{…}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n += 1
            if n > 8 then table.insert(parts, "…"); break end
            table.insert(parts, tostring(k) .. "=" .. fmt(x, depth + 1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function fmtArgs(packed)
    local parts = {}
    for i = 1, packed.n do table.insert(parts, fmt(packed[i])) end
    return "(" .. table.concat(parts, ", ") .. ")"
end

local function v2(v) return string.format("%dx%d", v.X, v.Y) end
local function v2pos(v) return string.format("%d,%d", v.X, v.Y) end
local function v3(v) return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) end

local function fullName(o)
    local ok, name = pcall(o.GetFullName, o)
    return ok and name or "?"
end

local function callerName()
    if not getCalling then return "?" end
    local ok, s = pcall(getCalling)
    if ok and typeof(s) == "Instance" then return fullName(s) end
    return ok and "nil" or "?"
end

-- Мой UserId в строке как отдельное число (не часть чужого id)
local function isMine(str)
    return type(str) == "string" and string.find(str, "%f[%d]" .. MyId .. "%f[%D]") ~= nil
end

local function looksLikeThumb(str)
    if type(str) ~= "string" then return false end
    local s = string.lower(str)
    return s:find("rbxthumb", 1, true) or s:find("rbxcdn", 1, true) or s:find("thumbnail", 1, true)
end

-- Путь от PlayerGui с пометкой ✗ у скрытых звеньев + итоговая видимость
local function visibility(obj)
    local chain, shown, cur = {}, true, obj
    while cur and cur ~= PlayerGui and cur ~= game do
        local mark = ""
        if cur:IsA("GuiObject") and not cur.Visible then shown = false; mark = "✗" end
        if cur:IsA("LayerCollector") and not cur.Enabled then shown = false; mark = "✗" end
        table.insert(chain, 1, cur.Name .. mark)
        cur = cur.Parent
    end
    local root = cur == PlayerGui and "PlayerGui/" or ("<" .. tostring(cur and cur.Name or "nil") .. ">/")
    return shown, root .. table.concat(chain, "/")
end

-- Рядом с лейблом есть текст с моим ником — вероятно, это моя карточка
local function nearMyName(obj)
    local box = obj.Parent and obj.Parent.Parent or obj.Parent
    if not box then return false end
    local names = {string.lower(LocalPlayer.Name), string.lower(LocalPlayer.DisplayName)}
    local n = 0
    for _, d in ipairs(box:GetDescendants()) do
        n += 1
        if n > 80 then break end
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local text = string.lower(d.Text)
            for _, name in ipairs(names) do
                if name ~= "" and text:find(name, 1, true) then return true end
            end
        end
    end
    return false
end

local function guiDepth(o)
    local d, cur = 0, o
    while cur and not cur:IsA("LayerCollector") do
        d += 1
        cur = cur.Parent
    end
    return cur and d or math.huge
end

local function countImages(o)
    local n = 0
    for _, d in ipairs(o:GetDescendants()) do
        if d:IsA("ImageLabel") or d:IsA("ImageButton") or d:IsA("ViewportFrame") then n += 1 end
    end
    return n
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 5: ОПИСАНИЕ ОБЪЕКТОВ — лейблы, деревья GUI, ViewportFrame
-- ══════════════════════════════════════════════════════════════════════════════

local function mineFlag(obj)
    local ok, image = pcall(function() return obj.Image end)
    if ok and isMine(image) then return " ★MY-USERID" end
    local okName, near = pcall(nearMyName, obj)
    if okName and near then return " ☆MY-NAME-NEARBY" end
    return ""
end

local function describeImage(obj)
    local shown, path = visibility(obj)
    local parts = {path, shown and " [shown]" or " [hidden]", mineFlag(obj)}
    local ok = pcall(function()
        table.insert(parts, string.format("\n      Image=%q Thumb=%s", obj.Image, tostring(looksLikeThumb(obj.Image) and true or false)))
        local okC, content = pcall(function() return obj.ImageContent end)
        if okC and content ~= nil then
            local okU, uri = pcall(function() return content.Uri end)
            table.insert(parts, " ImageContent=" .. short(okU and uri or tostring(content), 90))
        end
        table.insert(parts, string.format("\n      Abs=%s @%s Size=%s Anchor=%s Z=%d ScaleType=%s RectOff=%s RectSize=%s BgT=%.2f ImgT=%.2f",
            v2(obj.AbsoluteSize), v2pos(obj.AbsolutePosition), tostring(obj.Size), tostring(obj.AnchorPoint),
            obj.ZIndex, obj.ScaleType.Name, v2pos(obj.ImageRectOffset), v2(obj.ImageRectSize),
            obj.BackgroundTransparency, obj.ImageTransparency))
    end)
    if not ok then table.insert(parts, " <свойства недоступны>") end
    return table.concat(parts)
end

local function nodeLine(o, depth)
    local p = {string.rep("  ", depth), o.ClassName, ' "', o.Name, '"'}
    if o:IsA("LayerCollector") then
        table.insert(p, o.Enabled and " on" or " OFF")
        if o:IsA("ScreenGui") then
            table.insert(p, string.format(" DisplayOrder=%d IgnoreInset=%s ZBehavior=%s ResetOnSpawn=%s",
                o.DisplayOrder, tostring(o.IgnoreGuiInset), o.ZIndexBehavior.Name, tostring(o.ResetOnSpawn)))
        end
    end
    if o:IsA("GuiObject") then
        table.insert(p, string.format(" %s %s @%s Z=%d", o.Visible and "V" or "hid",
            v2(o.AbsoluteSize), v2pos(o.AbsolutePosition), o.ZIndex))
        if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.Image ~= "" then
            table.insert(p, " Img=" .. short(o.Image, 90))
            if isMine(o.Image) then table.insert(p, " ★MY-USERID") end
        end
        if (o:IsA("TextLabel") or o:IsA("TextButton")) and o.Text ~= "" then
            table.insert(p, string.format(" Text=%q", short(o.Text, 40)))
        end
        if o:IsA("ViewportFrame") then
            table.insert(p, " VPF children=" .. #o:GetChildren())
        end
    end
    return table.concat(p)
end

local function dumpTree(root, reason, force)
    if not root or not root.Parent then return end
    local t = os.clock()
    if not force then
        if State.Counters.TreeDumps >= CONFIG.MaxTreeDumps then return end
        if State.TreeDumpAt[root] and t - State.TreeDumpAt[root] < CONFIG.TreeDumpCooldown then return end
    end
    State.TreeDumpAt[root] = t
    State.Counters.TreeDumps += 1

    local lines, count = {}, 0
    local function walk(o, depth)
        if count >= CONFIG.TreeLineLimit then return end
        count += 1
        table.insert(lines, nodeLine(o, depth))
        local kids = o:GetChildren()
        local hidden = (o:IsA("GuiObject") and not o.Visible) or (o:IsA("LayerCollector") and not o.Enabled)
        if hidden and depth > 0 and #kids > 0 then
            table.insert(lines, string.rep("  ", depth + 1) .. "… скрыто, потомков: " .. #o:GetDescendants())
            return
        end
        if o:IsA("ViewportFrame") then return end -- 3D-содержимое описывает dumpViewport
        for _, c in ipairs(kids) do
            if c:IsA("GuiBase2d") or c:IsA("Folder") or c:IsA("LuaSourceContainer") then walk(c, depth + 1) end
        end
    end
    local ok, err = pcall(walk, root, 0)
    local _, path = visibility(root)
    log("TREE", string.format("%s — %s (%d строк%s)\n%s", path, reason, count,
        count >= CONFIG.TreeLineLimit and ", обрезано" or "", table.concat(lines, "\n")))
    if not ok then log("TREE", "ошибка обхода: " .. tostring(err)) end
end

local function describeModel(m, indent, lines, cameraCF)
    local parts, accessories, tools = 0, 0, 0
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then parts += 1 end
        if d:IsA("Accessory") then accessories += 1 end
        if d:IsA("Tool") then tools += 1 end
    end
    local hum = m:FindFirstChildOfClass("Humanoid")
    local owner = Players:FindFirstChild(m.Name)
    table.insert(lines, string.format("%sModel %q parts=%d accessories=%d tools=%d humanoid=%s owner=%s",
        indent, m.Name, parts, accessories, tools, hum and hum.RigType.Name or "нет",
        owner and (owner.Name .. (owner == LocalPlayer and " ★ME" or "")) or "?"))
    local okBox, cf, size = pcall(m.GetBoundingBox, m)
    if okBox then
        table.insert(lines, string.format("%s  bbox center=%s size=%s look=%s", indent, v3(cf.Position), v3(size), v3(cf.LookVector)))
        if cameraCF then
            -- Камера в пространстве модели: отсюда для фазы 1.3 берутся дистанция и yaw
            local rel = cf:ToObjectSpace(cameraCF)
            local rx, ry, rz = rel:ToEulerAnglesYXZ()
            table.insert(lines, string.format("%s  camera rel pos=%s dist=%.2f euler(YXZ)=(%.1f, %.1f, %.1f)°",
                indent, v3(rel.Position), rel.Position.Magnitude, math.deg(rx), math.deg(ry), math.deg(rz)))
        end
    end
    if hum then
        local desc = hum:FindFirstChildOfClass("HumanoidDescription")
        table.insert(lines, indent .. "  HumanoidDescription=" .. (desc and "есть" or "нет"))
        local animator = hum:FindFirstChildOfClass("Animator") or hum
        local okT, tracks = pcall(animator.GetPlayingAnimationTracks, animator)
        if okT then
            for _, tr in ipairs(tracks) do
                table.insert(lines, string.format("%s  anim %s t=%.3f/%.3f speed=%.2f playing=%s", indent,
                    tr.Animation and tr.Animation.AnimationId or "?", tr.TimePosition, tr.Length, tr.Speed, tostring(tr.IsPlaying)))
            end
        end
    end
end

local function dumpViewport(vpf, reason)
    local info = State.Viewports[vpf]
    if not info then
        info = {Dumps = 0}
        State.Viewports[vpf] = info
        State.Counters.Viewports += 1
    end
    if info.Dumps >= CONFIG.MaxViewportDumps then return end
    info.Dumps += 1

    local lines = {}
    local ok, err = pcall(function()
        local shown, path = visibility(vpf)
        table.insert(lines, string.format("%s [%s] — %s", path, shown and "shown" or "hidden", reason))
        table.insert(lines, string.format("  Abs=%s @%s Z=%d Ambient=%s LightColor=%s LightDir=%s BgT=%.2f Bg=%s ImgColor=%s ImgT=%.2f",
            v2(vpf.AbsoluteSize), v2pos(vpf.AbsolutePosition), vpf.ZIndex, tostring(vpf.Ambient), tostring(vpf.LightColor),
            v3(vpf.LightDirection), vpf.BackgroundTransparency, tostring(vpf.BackgroundColor3), tostring(vpf.ImageColor3), vpf.ImageTransparency))
        local cam = vpf.CurrentCamera
        local camCF = cam and cam.CFrame
        if cam then
            table.insert(lines, string.format("  Camera %s pos=%s look=%s FOV=%.2f", fullName(cam), v3(camCF.Position), v3(camCF.LookVector), cam.FieldOfView))
        else
            table.insert(lines, "  Camera: нет CurrentCamera")
        end
        for _, c in ipairs(vpf:GetChildren()) do
            if c:IsA("Model") and not c:IsA("WorldModel") then
                describeModel(c, "  ", lines, camCF)
            elseif c:IsA("WorldModel") then
                table.insert(lines, "  WorldModel " .. c.Name)
                for _, m in ipairs(c:GetChildren()) do
                    if m:IsA("Model") then describeModel(m, "    ", lines, camCF) else table.insert(lines, "    " .. m.ClassName .. " " .. m.Name) end
                end
            else
                table.insert(lines, "  " .. c.ClassName .. " " .. c.Name)
            end
        end
    end)
    if not ok then table.insert(lines, "  ошибка: " .. tostring(err)) end
    log("VIEWPORT", table.concat(lines, "\n"))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 6: НАБЛЮДАТЕЛИ GUI — Image, Visible/Enabled, ViewportFrame
-- ══════════════════════════════════════════════════════════════════════════════

local function logImage(tag, obj)
    local text = describeImage(obj)
    log(tag, text)
    if text:find("★MY-USERID", 1, true) then
        State.Counters.MineHits += 1
        -- Контекст моей миниатюры: контейнер на 3 уровня выше — там обычно вся карточка игрока
        local box = obj
        for _ = 1, 3 do if box.Parent and box.Parent ~= PlayerGui then box = box.Parent end end
        dumpTree(box, "контекст миниатюры с моим UserId")
    end
end

local function watchImage(obj, isNew)
    if State.Watched[obj] then return end
    State.Watched[obj] = true
    State.Counters.ImagesWatched += 1
    local stat = {Changes = 0}
    State.ImageStats[obj] = stat
    track(obj:GetPropertyChangedSignal("Image"):Connect(function()
        if not State.Alive then return end
        stat.Changes += 1
        State.Counters.ImageChanges += 1
        local mine = isMine(obj.Image)
        if stat.Changes <= CONFIG.ImageChangeLimit or mine or looksLikeThumb(obj.Image) then
            logImage("IMG-CHANGE", obj)
        elseif stat.Changes == CONFIG.ImageChangeLimit + 1 then
            local _, path = visibility(obj)
            log("IMG-CHANGE", path .. " — меняется часто, дальше только счётчик")
        end
    end))
    if isNew and obj.Image ~= "" then logImage("IMG-NEW", obj) end
end

local function watchVisibility(obj)
    if State.VisWatched[obj] then return end
    State.VisWatched[obj] = true
    local isLayer = obj:IsA("LayerCollector")
    local prop = isLayer and "Enabled" or "Visible"
    local stat = {Changes = 0}
    State.VisStats[obj] = stat
    track(obj:GetPropertyChangedSignal(prop):Connect(function()
        if not State.Alive then return end
        stat.Changes += 1
        local on = obj[prop]
        local _, path = visibility(obj)
        if stat.Changes <= CONFIG.VisibleChangeLimit then
            log("VIS", string.format("%s.%s = %s", path, prop, tostring(on)))
        elseif stat.Changes == CONFIG.VisibleChangeLimit + 1 then
            log("VIS", path .. " — переключается часто, дальше только счётчик")
        end
        -- Появился контейнер с картинками — кандидат на экран конца раунда, снимаем дерево
        if on and (isLayer or countImages(obj) >= 2) then
            task.delay(0.25, function()
                if State.Alive then dumpTree(obj, prop .. "=true, внутри есть картинки") end
            end)
        end
    end))
end

local function watchViewport(vpf)
    if State.Viewports[vpf] then return end
    local pending = false
    local function schedule(reason)
        if pending then return end
        pending = true
        task.delay(1, function()
            pending = false
            if State.Alive and vpf.Parent then dumpViewport(vpf, reason) end
        end)
    end
    dumpViewport(vpf, "обнаружен")
    track(vpf.DescendantAdded:Connect(function() schedule("изменилось содержимое") end))
    track(vpf:GetPropertyChangedSignal("CurrentCamera"):Connect(function() schedule("сменилась камера") end))
end

local function consider(o, isNew)
    if not State.Alive then return end
    if o:IsA("ImageLabel") or o:IsA("ImageButton") then
        watchImage(o, isNew)
    elseif o:IsA("ViewportFrame") then
        task.defer(watchViewport, o)
    elseif o:IsA("LayerCollector") then
        watchVisibility(o)
        if isNew then log("GUI-NEW", string.format("%s %s Enabled=%s", o.ClassName, fullName(o), tostring(o.Enabled))) end
    end
    if o:IsA("GuiObject") and guiDepth(o) <= CONFIG.VisDepth then
        watchVisibility(o)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 7: ХУКИ — кто запрашивает миниатюры и кто ставит Image/Visible
-- ══════════════════════════════════════════════════════════════════════════════

local function queuePush(e)
    if #State.Queue >= CONFIG.QueueLimit then State.Dropped += 1; return end
    table.insert(State.Queue, e)
end

local function processEvent(e)
    if e.Kind == "call" then
        local key = e.Method .. " ← " .. e.Script
        State.Calls[key] = (State.Calls[key] or 0) + 1
        local mine = e.Args.n >= 1 and e.Args[1] == MyId
        log("CALL", string.format("%s via %s ← %s args=%s%s", e.Method, e.Via, e.Script, fmtArgs(e.Args), mine and " ★MY-USERID" or ""))
        return
    end
    -- __newindex: e.Target, e.Key, e.Value
    local target = e.Target
    if typeof(target) ~= "Instance" then return end
    local inGui = select(2, pcall(target.IsDescendantOf, target, PlayerGui)) == true
    if e.Key == "Image" then
        if not inGui and not looksLikeThumb(e.Value) then return end
        local stats = State.SetStats[target] or {}
        State.SetStats[target] = stats
        stats.Image = (stats.Image or 0) + 1
        if stats.Image <= CONFIG.SetLogLimit or isMine(e.Value) or looksLikeThumb(e.Value) then
            local _, path = visibility(target)
            log("SET-IMAGE", string.format("%s = %q ← %s%s", path, short(e.Value, 120), e.Script, isMine(e.Value) and " ★MY-USERID" or ""))
        end
    elseif inGui then
        local stats = State.SetStats[target] or {}
        State.SetStats[target] = stats
        stats[e.Key] = (stats[e.Key] or 0) + 1
        if stats[e.Key] <= CONFIG.SetLogLimit then
            local _, path = visibility(target)
            log("SET-" .. string.upper(e.Key), string.format("%s = %s ← %s", path, tostring(e.Value), e.Script))
        end
    end
end

local Hooks = {}

local function installHooks()
    local hookmeta = resolve("hookmetamethod")
    local getMethod = resolve("getnamecallmethod")

    if CONFIG.HookNamecall and hookmeta and getMethod then
        local ok, err = pcall(function()
            local old
            old = hookmeta(game, "__namecall", newcc(function(self, ...)
                local method = getMethod()
                if State.Alive and CONFIG.WatchedMethods[method] and not isCaller() then
                    queuePush({Kind = "call", Via = "namecall", Method = method, Args = table.pack(...), Script = callerName()})
                end
                return old(self, ...)
            end))
            Hooks.Namecall = old
        end)
        log("HOOK", "__namecall: " .. (ok and "установлен" or ("ошибка " .. tostring(err))))
    else
        log("HOOK", "__namecall: пропущен (нет hookmetamethod/getnamecallmethod или выключен)")
    end

    if CONFIG.HookNewIndex and hookmeta then
        local ok, err = pcall(function()
            local old
            old = hookmeta(game, "__newindex", newcc(function(self, key, value)
                if State.Alive and CONFIG.WatchedProps[key] and not isCaller() then
                    -- Visible/Enabled ставят каждый кадр одним и тем же значением — такое пропускаем
                    local same = false
                    if key ~= "Image" then
                        local okCur, cur = pcall(function() return self[key] end)
                        same = okCur and cur == value
                    end
                    if not same then
                        queuePush({Kind = "set", Target = self, Key = key, Value = value, Script = callerName()})
                    end
                end
                return old(self, key, value)
            end))
            Hooks.NewIndex = old
        end)
        log("HOOK", "__newindex: " .. (ok and "установлен" or ("ошибка " .. tostring(err))))
    end

    local hookfn = resolve("hookfunction")
    if CONFIG.HookFunctions and hookfn then
        for method in pairs(CONFIG.WatchedMethods) do
            local okGet, fn = pcall(function() return Players[method] end)
            if okGet and type(fn) == "function" then
                local ok, err = pcall(function()
                    local old
                    old = hookfn(fn, newcc(function(self, ...)
                        if State.Alive and not isCaller() then
                            queuePush({Kind = "call", Via = "direct", Method = method, Args = table.pack(...), Script = callerName()})
                        end
                        return old(self, ...)
                    end))
                end)
                log("HOOK", "hookfunction Players." .. method .. ": " .. (ok and "ok" or tostring(err)))
            end
        end
    end
end

-- Самопроверка: yield'ящий вызов проходит через наш namecall-хук без ошибок?
-- Если нет — хук ломает игре миниатюры, снимаем его, иначе лог будет врать.
local function selfTestThumbnails()
    local types = {"AvatarBust", "HeadShot", "AvatarThumbnail"}
    for _, name in ipairs(types) do
        local ok, res = pcall(function()
            return Players:GetUserThumbnailAsync(MyId, Enum.ThumbnailType[name], Enum.ThumbnailSize.Size420x420)
        end)
        log("BASELINE", string.format("GetUserThumbnailAsync(me, %s, 420) → %s %s", name, ok and "ok" or "FAIL", tostring(res)))
        if not ok and Hooks.Namecall and tostring(res):lower():find("yield", 1, true) then
            local hookmeta = resolve("hookmetamethod")
            pcall(hookmeta, game, "__namecall", Hooks.Namecall)
            Hooks.Namecall = nil
            log("HOOK", "!!! namecall-хук ломает yield на этом executor'е — хук снят, CALL-строк не будет")
            break
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 8: РАЗОВЫЕ ПРОВЕРКИ — возможности executor'а, HTTP, скрипты игры
-- ══════════════════════════════════════════════════════════════════════════════

local function checkCapabilities()
    local have, missing = {}, {}
    for _, name in ipairs(CONFIG.Capabilities) do
        local value = resolve(name)
        if value ~= nil then table.insert(have, name) else table.insert(missing, name) end
    end
    local ident = resolve("identifyexecutor")
    local okId, a, b = false, nil, nil
    if ident then okId, a, b = pcall(ident) end
    log("EXECUTOR", okId and (tostring(a) .. " " .. tostring(b or "")) or "identifyexecutor недоступен")
    log("CAPS", "есть: " .. table.concat(have, ", "))
    log("CAPS", "нет: " .. (#missing > 0 and table.concat(missing, ", ") or "—"))
end

-- HTTP нужен фазе 1: уходит ли cookie с request, и эталонная PNG моего реального аватара
local function checkHttp()
    local req = resolve("request") or resolve("http_request") or resolve("syn.request") or resolve("http.request") or resolve("fluxus.request")
    if not req then log("HTTP", "request-функции нет — серверный рендер через API недоступен"); return end
    local function get(url)
        local ok, res = pcall(req, {Url = url, Method = "GET"})
        if not ok then return nil, tostring(res) end
        if type(res) ~= "table" then return nil, "ответ не таблица: " .. typeof(res) end
        return res
    end

    local res, err = get("https://users.roblox.com/v1/users/authenticated")
    if res then
        local okJ, data = pcall(HttpService.JSONDecode, HttpService, res.Body or "")
        local same = okJ and type(data) == "table" and data.id == MyId
        log("HTTP", string.format("users/authenticated → %s, id совпал с моим: %s (200+совпал = cookie уходит с request)",
            tostring(res.StatusCode), tostring(same)))
    else
        log("HTTP", "users/authenticated → ошибка " .. tostring(err))
    end

    local url = string.format("https://thumbnails.roblox.com/v1/users/avatar-bust?userIds=%d&size=420x420&format=Png&isCircular=false", MyId)
    res, err = get(url)
    if not res then log("HTTP", "thumbnails avatar-bust → ошибка " .. tostring(err)); return end
    log("HTTP", string.format("thumbnails avatar-bust → %s %s", tostring(res.StatusCode), short(res.Body or "", 300)))
    local okJ, data = pcall(HttpService.JSONDecode, HttpService, res.Body or "")
    local entry = okJ and type(data) == "table" and type(data.data) == "table" and data.data[1]
    if not entry or not entry.imageUrl then return end

    local png, perr = get(entry.imageUrl)
    if not png then log("HTTP", "скачивание PNG → ошибка " .. tostring(perr)); return end
    local headers = png.Headers or {}
    log("HTTP", string.format("PNG %s: status=%s bytes=%d type=%s", short(entry.imageUrl, 100), tostring(png.StatusCode),
        #(png.Body or ""), tostring(headers["Content-Type"] or headers["content-type"])))
    if fs.write and png.Body and #png.Body > 0 then
        local path = CONFIG.Folder .. "/real_avatarbust_420.png"
        local okW = pcall(fs.write, path, png.Body)
        local getAsset = resolve("getcustomasset") or resolve("getsynasset")
        local okA, asset = false, nil
        if okW and getAsset then okA, asset = pcall(getAsset, path) end
        log("HTTP", string.format("writefile %s: %s; getcustomasset → %s", path, tostring(okW), okA and tostring(asset) or "недоступен/ошибка"))
    end
end

local function scanScripts()
    local decompile = resolve("decompile")
    if not CONFIG.ScanScripts or not decompile then
        log("SCAN", "пропущено: " .. (decompile and "выключено в CONFIG" or "нет decompile"))
        return
    end
    local list, seen = {}, {}
    local function add(s)
        if seen[s] then return end
        seen[s] = true
        table.insert(list, s)
    end
    -- Сначала скрипты из PlayerGui: экран конца раунда почти наверняка там
    for _, d in ipairs(PlayerGui:GetDescendants()) do if d:IsA("LocalScript") or d:IsA("ModuleScript") then add(d) end end
    local getscripts = resolve("getscripts")
    if getscripts then
        local ok, all = pcall(getscripts)
        if ok and type(all) == "table" then
            for _, s in ipairs(all) do
                local okCore, inCore = pcall(function() return s:IsDescendantOf(game:GetService("CoreGui")) or s:IsDescendantOf(game:GetService("CorePackages")) end)
                if typeof(s) == "Instance" and not (okCore and inCore) then add(s) end
            end
        end
    else
        for _, root in ipairs({ReplicatedStorage, game:GetService("ReplicatedFirst"), LocalPlayer:FindFirstChild("PlayerScripts")}) do
            if root then for _, d in ipairs(root:GetDescendants()) do if d:IsA("LocalScript") or d:IsA("ModuleScript") then add(d) end end end
        end
    end
    log("SCAN", string.format("скриптов к декомпиляции: %d (лимит %d)", #list, CONFIG.ScanScriptLimit))

    local done, hitsTotal = 0, 0
    for i, s in ipairs(list) do
        if not State.Alive or i > CONFIG.ScanScriptLimit then break end
        local ok, source = pcall(decompile, s)
        done += 1
        if ok and type(source) == "string" then
            local hits, lineNo = {}, 0
            for line in string.gmatch(source .. "\n", "(.-)\n") do
                lineNo += 1
                for _, pattern in ipairs(CONFIG.ScanPatterns) do
                    if line:find(pattern, 1, true) then
                        table.insert(hits, string.format("    L%d [%s] %s", lineNo, pattern, short(line:gsub("^%s+", ""), 160)))
                        break
                    end
                end
                if #hits >= CONFIG.ScanHitsPerScript then break end
            end
            if #hits > 0 then
                hitsTotal += #hits
                log("SCAN", fullName(s) .. " (" .. s.ClassName .. ")\n" .. table.concat(hits, "\n"))
            end
        end
        if i % 5 == 0 then task.wait() end
    end
    log("SCAN", string.format("готово: декомпилировано %d, совпадений %d", done, hitsTotal))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 9: РАУНДЫ, РЕМОУТЫ, СНИМКИ
-- ══════════════════════════════════════════════════════════════════════════════

function Probe.Snapshot(reason)
    reason = reason or "ручной снимок"
    local list = {}
    for _, g in ipairs(PlayerGui:GetChildren()) do
        if g:IsA("LayerCollector") then table.insert(list, string.format("%s(%s)", g.Name, g.Enabled and "on" or "off")) end
    end
    log("SNAPSHOT", reason .. " — ScreenGui: " .. table.concat(list, ", "))
    for _, g in ipairs(PlayerGui:GetChildren()) do
        if g:IsA("LayerCollector") and g.Enabled then dumpTree(g, reason, true) end
    end
    for vpf in pairs(State.Viewports) do
        if vpf.Parent then
            local shown = visibility(vpf)
            if shown then dumpViewport(vpf, reason) end
        end
    end
    flush()
end

function Probe.Dump(obj)
    dumpTree(obj, "ручной дамп", true)
end

local function watchRemote(r)
    if State.Remotes[r] or not (r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent")) then return end
    local st = {Count = 0, WindowStart = 0, InWindow = 0}
    State.Remotes[r] = st
    track(r.OnClientEvent:Connect(function(...)
        if not State.Alive then return end
        st.Count += 1
        local t = os.clock()
        if t - st.WindowStart > CONFIG.RemoteWindow then st.WindowStart = t; st.InWindow = 0 end
        st.InWindow += 1
        if st.InWindow <= CONFIG.RemoteBurstLimit then
            log("REMOTE", fullName(r) .. " " .. fmtArgs(table.pack(...)))
        end
    end))
end

local Stop

local function onRoundEnd()
    State.RoundEnds += 1
    log("ROUND", string.format("конец #%d: карта удалена из Workspace", State.RoundEnds))
    for _, d in ipairs(CONFIG.RoundEndDumpDelays) do
        task.delay(d, function()
            if State.Alive then Probe.Snapshot(string.format("конец раунда #%d +%.1fs", State.RoundEnds, d)) end
        end)
    end
    if State.RoundEnds >= CONFIG.RoundsToWatch then
        log("ROUND", string.format("набрано %d раунд(а) — авто-стоп через %d с", State.RoundEnds, CONFIG.TailAfterRound))
        task.delay(CONFIG.TailAfterRound, function() if State.Alive then Stop("наблюдено раундов: " .. State.RoundEnds) end end)
    end
end

-- Карта MM2 — дочерний Model Workspace с CoinContainer (так же ищет getMap() в MainScript)
local function checkMap(child)
    task.spawn(function()
        for _ = 1, 30 do
            if not State.Alive or child.Parent ~= Workspace then return end
            if child:FindFirstChild("CoinContainer") then
                if State.Map ~= child then
                    State.Map = child
                    log("ROUND", "старт: карта " .. child.Name)
                end
                return
            end
            task.wait(0.5)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 10: ЗАПУСК И ОСТАНОВКА
-- ══════════════════════════════════════════════════════════════════════════════

Stop = function(reason)
    if not State.Alive then return end
    log("STOP", tostring(reason or "вручную"))
    -- Хуки не снимаем: поверх них могли встать хуки MainScript, откат сломал бы чужие.
    -- После Alive=false они просто пропускают вызовы дальше.
    State.Alive = false
    Probe.Alive = false
    for _, c in ipairs(State.Connections) do pcall(function() c:Disconnect() end) end
    table.clear(State.Connections)
    for _, th in ipairs(State.Threads) do
        if th ~= coroutine.running() then pcall(task.cancel, th) end
    end

    -- Итоговая сводка
    local c = State.Counters
    local lines = {string.format("лейблов под наблюдением=%d, смен Image=%d, попаданий моего UserId=%d, ViewportFrame=%d, дампов дерева=%d, потеряно событий=%d",
        c.ImagesWatched, c.ImageChanges, c.MineHits, c.Viewports, c.TreeDumps, State.Dropped)}
    table.insert(lines, "вызовы методов (метод ← скрипт: раз):")
    for key, n in pairs(State.Calls) do table.insert(lines, string.format("  %s: %d", key, n)) end
    local remotes = {}
    for r, st in pairs(State.Remotes) do if st.Count > 0 then table.insert(remotes, {fullName(r), st.Count}) end end
    table.sort(remotes, function(a, b) return a[2] > b[2] end)
    table.insert(lines, "ремоуты OnClientEvent (топ-20):")
    for i = 1, math.min(20, #remotes) do table.insert(lines, string.format("  %s: %d", remotes[i][1], remotes[i][2])) end
    local busy = {}
    for obj, st in pairs(State.ImageStats) do if st.Changes > 0 then table.insert(busy, {obj, st.Changes}) end end
    table.sort(busy, function(a, b) return a[2] > b[2] end)
    table.insert(lines, "лейблы с наибольшим числом смен Image (топ-25):")
    for i = 1, math.min(25, #busy) do
        local _, path = visibility(busy[i][1])
        table.insert(lines, string.format("  %s: %d", path, busy[i][2]))
    end
    log("SUMMARY", table.concat(lines, "\n"))
    flush()
    print(CONFIG.Prefix .. " отчёт сохранён: " .. tostring(State.File))
end
Probe.Stop = Stop

local function start()
    -- Файл отчёта
    if fs.write then
        for _, p in ipairs({"VioCFG", "VioCFG/Violite", CONFIG.Folder}) do
            pcall(function() if fs.isfolder and not fs.isfolder(p) then fs.makefolder(p) end end)
        end
        State.File = CONFIG.Folder .. "/EndScreenProbe_" .. os.date("%Y%m%d_%H%M%S") .. ".log"
        pcall(fs.write, State.File, "")
    end
    Probe.File = State.File
    log("START", string.format("PlaceId=%d JobId=%s me=%s (%d) display=%s файл=%s", game.PlaceId, game.JobId,
        LocalPlayer.Name, MyId, LocalPlayer.DisplayName, tostring(State.File or "нет writefile — только print")))

    checkCapabilities()
    installHooks()

    -- Слив очереди хуков и периодический flush
    table.insert(State.Threads, task.spawn(function()
        local lastFlush = os.clock()
        while State.Alive do
            local queue = State.Queue
            if #queue > 0 then
                State.Queue = {}
                for _, e in ipairs(queue) do
                    local ok, err = pcall(processEvent, e)
                    if not ok then log("ERROR", "processEvent: " .. tostring(err)) end
                end
            end
            if os.clock() - lastFlush >= CONFIG.FlushInterval then flush(); lastFlush = os.clock() end
            if os.clock() - State.StartClock > CONFIG.MaxDuration then Stop("истёк MaxDuration"); break end
            task.wait(0.1)
        end
    end))

    selfTestThumbnails()

    -- Базовая линия: что уже есть в PlayerGui
    local total, thumbs = 0, 0
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        consider(d, false)
        if d:IsA("ImageLabel") or d:IsA("ImageButton") then
            total += 1
            if looksLikeThumb(d.Image) or isMine(d.Image) then thumbs += 1; logImage("IMG-BASE", d) end
        end
    end
    log("BASELINE", string.format("картинок в PlayerGui: %d, из них миниатюр/с моим UserId: %d", total, thumbs))
    for _, g in ipairs(PlayerGui:GetChildren()) do
        if g:IsA("LayerCollector") then log("BASELINE", nodeLine(g, 0)) end
    end

    track(PlayerGui.DescendantAdded:Connect(function(d)
        local ok, err = pcall(consider, d, true)
        if not ok then log("ERROR", "consider: " .. tostring(err)) end
    end))

    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do watchRemote(d) end
    track(ReplicatedStorage.DescendantAdded:Connect(function(d) pcall(watchRemote, d) end))

    for _, child in ipairs(Workspace:GetChildren()) do checkMap(child) end
    track(Workspace.ChildAdded:Connect(checkMap))
    track(Workspace.ChildRemoved:Connect(function(child)
        if child == State.Map then
            State.Map = nil
            onRoundEnd()
        end
    end))

    track(UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == CONFIG.SnapshotKey then task.spawn(Probe.Snapshot, "клавиша " .. CONFIG.SnapshotKey.Name) end
    end))

    table.insert(State.Threads, task.spawn(function()
        local ok, err = pcall(checkHttp)
        if not ok then log("ERROR", "checkHttp: " .. tostring(err)) end
        ok, err = pcall(scanScripts)
        if not ok then log("ERROR", "scanScripts: " .. tostring(err)) end
    end))

    log("START", string.format("наблюдаю. Сыграй %d раунд(а); End — снимок GUI; стоп: getgenv().EndScreenProbe.Stop()", CONFIG.RoundsToWatch))
    flush()
end

local ok, err = pcall(start)
if not ok then
    log("ERROR", "start: " .. tostring(err))
    flush()
end
