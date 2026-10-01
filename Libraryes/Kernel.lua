-- ══════════════════════════════════════════════════════════════════════════════
-- VIOLITE KERNEL — ядро бандла: сессия, рубильник, связь модулей
-- ══════════════════════════════════════════════════════════════════════════════
-- Живёт только внутри бандла (Violite.bundle.lua), первым модулем. Модули получают
-- ядро аргументом, а не через getgenv: чужой скрипт его не видит и подменить не может.
-- Сессию выдаёт наш сервер (VDS). В релизе запросы идут через JD_SECURE_REQUEST:
-- Junkie пропускает их только с валидным ключом, сам подставляет ключ и прячет адрес
-- и секрет в сборке. Ответ сервера подписан HMAC — подставить свой ответ нельзя,
-- не вскрыв обфускацию. Без живой сессии GUI не строится, данные эффектов и relay
-- синхронизации не отвечают, а рубильник выгружает всё.
-- Плейсхолдеры __VIOLITE_*__ подставляет build/bundle.js из build/secrets.json.

return function(options)
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local StarterGui = game:GetService("StarterGui")
    local LocalPlayer = Players.LocalPlayer

    local CONFIG = {
        Version = tonumber(options.Version) or 0,
        Release = options.Release == true,
        BeatInterval = 60,         -- сек между продлениями сессии
        BeatJitter = 10,           -- разброс, чтобы клиенты не били сервер разом
        MaxBeatFailures = 3,       -- подряд без ответа → выгрузка (~3 мин)
        ResponseSecret = "__VIOLITE_RESPONSE_SECRET__",
        --#dev
        DevUrl = "__VIOLITE_DEV_URL__",
        DevSecret = "__VIOLITE_DEV_SECRET__",
        DevOffline = "__VIOLITE_DEV_OFFLINE__" == "1",
        --#end
    }

    local Kernel = {
        Version = CONFIG.Version,
        Shared = {},               -- межмодульные каналы вместо getgenv-мостов
        Session = nil,             -- {Token, Role, ExpiresAt, DataUrl, Message}
    }
    local State = {
        Alive = true, Killed = false, KillReason = nil,
        Modules = options.Modules or {}, Loaded = {},
        KillHandlers = {}, Failures = 0, BeatThread = nil, DevApi = nil,
    }

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 1: КРИПТО (SHA-256 / HMAC на чистом Luau — одинаково во всех executor'ах)
    -- ══════════════════════════════════════════════════════════════════════════
    local K = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    }

    -- Сырые 32 байта дайджеста (для HMAC)
    local function sha256Raw(msg)
        local band, bxor, bnot, rrotate, rshift = bit32.band, bit32.bxor, bit32.bnot, bit32.rrotate, bit32.rshift
        local M = 0x100000000
        local len = #msg
        msg = msg .. "\128" .. string.rep("\0", (55 - len) % 64) .. string.pack(">I4I4", math.floor(len / 0x20000000), (len * 8) % M)
        local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
        local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        local w = table.create(64, 0)
        for chunk = 1, #msg, 64 do
            for i = 1, 16 do w[i] = string.unpack(">I4", msg, chunk + (i - 1) * 4) end
            for i = 17, 64 do
                local x, y = w[i - 15], w[i - 2]
                local s0 = bxor(rrotate(x, 7), rrotate(x, 18), rshift(x, 3))
                local s1 = bxor(rrotate(y, 17), rrotate(y, 19), rshift(y, 10))
                w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % M
            end
            local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
            for i = 1, 64 do
                local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
                local ch = bxor(band(e, f), band(bnot(e), g))
                local t1 = (h + S1 + ch + K[i] + w[i]) % M
                local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
                local maj = bxor(band(a, b), band(a, c), band(b, c))
                h, g, f, e, d, c, b, a = g, f, e, (d + t1) % M, c, b, a, (t1 + (S0 + maj) % M) % M
            end
            h0, h1, h2, h3 = (h0 + a) % M, (h1 + b) % M, (h2 + c) % M, (h3 + d) % M
            h4, h5, h6, h7 = (h4 + e) % M, (h5 + f) % M, (h6 + g) % M, (h7 + h) % M
        end
        return string.pack(">I4I4I4I4I4I4I4I4", h0, h1, h2, h3, h4, h5, h6, h7)
    end

    local function toHex(raw)
        return (raw:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
    end

    local function hmacHex(key, msg)
        if #key > 64 then key = sha256Raw(key) end
        key = key .. string.rep("\0", 64 - #key)
        local inner = key:gsub(".", function(c) return string.char(bit32.bxor(string.byte(c), 0x36)) end)
        local outer = key:gsub(".", function(c) return string.char(bit32.bxor(string.byte(c), 0x5c)) end)
        return toHex(sha256Raw(outer .. sha256Raw(inner .. msg)))
    end

    -- Сравнение без раннего выхода: время не выдаёт, сколько символов совпало
    local function safeEqual(a, b)
        if type(a) ~= "string" or type(b) ~= "string" or #a ~= #b then return false end
        local diff = 0
        for i = 1, #a do diff = bit32.bor(diff, bit32.bxor(string.byte(a, i), string.byte(b, i))) end
        return diff == 0
    end

    local function newNonce()
        return (HttpService:GenerateGUID(false):gsub("-", ""):lower())
    end

    Kernel.Sha256 = function(msg) return toHex(sha256Raw(msg)) end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 2: ВЫГРУЗКА
    -- ══════════════════════════════════════════════════════════════════════════
    local function notify(text)
        pcall(function()
            StarterGui:SetCore("SendNotification", {Title = "Violite", Text = text, Duration = 8})
        end)
    end

    -- Модули подписываются на выгрузку (MainScript → Core.Shutdown, спавнер → свой Shutdown)
    function Kernel.OnKill(fn)
        if type(fn) ~= "function" then return end
        if State.Killed then task.spawn(pcall, fn, State.KillReason); return end
        table.insert(State.KillHandlers, fn)
    end

    -- silent — штатная выгрузка (пользователь закрыл скрипт): без уведомления
    local function shutdown(reason, kick, silent)
        if State.Killed then return end
        State.Killed, State.Alive, State.KillReason = true, false, tostring(reason or "Session ended")
        Kernel.Session = nil
        -- Поток продления может сам вызвать Kill — себя не отменяем, он выйдет сам
        local beat = State.BeatThread
        State.BeatThread = nil
        if beat and beat ~= coroutine.running() then pcall(task.cancel, beat) end
        local handlers = State.KillHandlers
        State.KillHandlers = {}
        for _, fn in ipairs(handlers) do pcall(fn, State.KillReason) end
        pcall(function() getgenv().VioliteDev = nil end)
        if not silent then notify(State.KillReason) end
        if kick then pcall(function() LocalPlayer:Kick(State.KillReason) end) end
    end

    function Kernel.Kill(reason, kick)
        shutdown(reason, kick, false)
    end

    -- Пользователь сам выгрузил скрипт: останавливаем продление сессии, без сообщений
    function Kernel.Stop()
        shutdown("Unloaded", false, true)
    end

    -- Сессия жива: не выгружены и срок токена не истёк. Модули зовут это в своих
    -- петлях; при провале — Kill (вырезать одну проверку мало, их много)
    function Kernel.Check()
        local session = Kernel.Session
        if not State.Alive or not session then return false end
        if os.clock() > session.ExpiresAt then
            Kernel.Kill("Session expired")
            return false
        end
        return true
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 3: МОДУЛИ БАНДЛА
    -- ══════════════════════════════════════════════════════════════════════════
    function Kernel.Require(name)
        local cached = State.Loaded[name]
        if cached ~= nil then return cached.Value end
        local factory = State.Modules[name]
        assert(type(factory) == "function", "Unknown module: " .. tostring(name))
        local value = factory(Kernel)
        State.Loaded[name] = {Value = value}
        return value
    end

    -- API владельца (OwnerTools): наружу только при роли owner, которую выдаёт сервер
    function Kernel.ExposeDev(name, value)
        local session = Kernel.Session
        if not session or session.Role ~= "owner" then return end
        State.DevApi = State.DevApi or {Kernel = {Check = Kernel.Check, Shared = Kernel.Shared}}
        State.DevApi[name] = value
        pcall(function() getgenv().VioliteDev = State.DevApi end)
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 4: СЕТЬ
    -- ══════════════════════════════════════════════════════════════════════════
    local httpRequest = (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
        or nil

    local function fingerprint()
        local value
        pcall(function() value = JD_FINGERPRINT end)
        if type(value) ~= "string" or value == "" then
            pcall(function() value = gethwid and gethwid() end)
        end
        value = type(value) == "string" and value:gsub("[^%w_%-]", ""):sub(1, 128) or ""
        return value ~= "" and value or "none"
    end

    -- Ответ сервера: {payload = "<json>", sig = hmac(secret, nonce|payload)}.
    -- Проверяем подпись, чтобы перехваченный ответ нельзя было заменить на «всё ок».
    local function openResponse(response, nonce)
        if type(response) ~= "table" then return nil, "no response" end
        local status = tonumber(response.StatusCode) or 0
        if status ~= 200 then return nil, "http " .. status end
        local ok, outer = pcall(HttpService.JSONDecode, HttpService, response.Body)
        if not ok or type(outer) ~= "table" or type(outer.payload) ~= "string" then return nil, "bad body" end
        -- В релизе подпись обязательна: без секрета сборка не должна работать вовсе
        if CONFIG.Release or CONFIG.ResponseSecret ~= "" then
            if CONFIG.ResponseSecret == "" then return nil, "unsigned build" end
            local expected = hmacHex(CONFIG.ResponseSecret, nonce .. "|" .. outer.payload)
            if not safeEqual(expected, tostring(outer.sig or "")) then return nil, "bad signature" end
        end
        local parsed, data = pcall(HttpService.JSONDecode, HttpService, outer.payload)
        if not parsed or type(data) ~= "table" then return nil, "bad payload" end
        return data
    end

    -- Запрос к нашему серверу. В релизе — через JD_SECURE_REQUEST (адрес и секрет
    -- прячет сборка Junkie, запрос проходит только с валидным ключом, ключ ставит
    -- сервер Junkie). В dev — прямой request со своим заголовком-секретом.
    -- Запрос к нашему серверу. Возвращает (data, err, verified): verified = ответ
    -- подписан сервером (а не сбой сети) — только такому «нет» верим как отказу.
    -- JD_SECURE_REQUEST — макрос компилятора Junkie: опции пишутся литералом прямо в
    -- вызове, динамика — только через JD_SANITIZE, ключ подставляет сам сервер Junkie
    -- (JD_SERVER_VALUE). Поэтому два запроса записаны целиком, а не собираются из таблицы.
    local function callServer(kind, token)
        local nonce = newNonce()
        local hwid, user = fingerprint(), tostring(LocalPlayer.UserId)
        local version = tostring(math.floor(CONFIG.Version))
        local response
        if CONFIG.Release then
            local ok, result = pcall(function()
                if kind == "session" then
                    return JD_SECURE_REQUEST({
                        Url = "__VIOLITE_CONTROL_URL__/session",
                        Method = "POST",
                        Headers = {["X-Violite-Proxy"] = "__VIOLITE_PROXY_SECRET__"},
                        Body = {
                            key = JD_SERVER_VALUE("JD_KEY"),
                            hwid = JD_SANITIZE(hwid, "[A-Za-z0-9_-]{1,128}"),
                            user = JD_SANITIZE(user, "[0-9]{1,20}"),
                            v = JD_SANITIZE(version, "[0-9]{1,12}"),
                            nonce = JD_SANITIZE(nonce, "[a-f0-9]{32}"),
                        },
                        Limits = {PerKey = 20, PerIp = 40},
                    })
                end
                return JD_SECURE_REQUEST({
                    Url = "__VIOLITE_CONTROL_URL__/beat",
                    Method = "POST",
                    Headers = {["X-Violite-Proxy"] = "__VIOLITE_PROXY_SECRET__"},
                    Body = {
                        key = JD_SERVER_VALUE("JD_KEY"),
                        token = JD_SANITIZE(token or "none", "[A-Za-z0-9]{1,128}"),
                        hwid = JD_SANITIZE(hwid, "[A-Za-z0-9_-]{1,128}"),
                        v = JD_SANITIZE(version, "[0-9]{1,12}"),
                        nonce = JD_SANITIZE(nonce, "[a-f0-9]{32}"),
                    },
                    Limits = {PerKey = 10, PerIp = 30},
                })
            end)
            if not ok then return nil, "request failed", false end
            response = result
        end
        --#dev
        -- dev-ветка (в релизной сборке вырезается целиком вместе с dev-секретом)
        if not CONFIG.Release then
            if CONFIG.DevOffline then
                return {ok = true, token = "dev", role = "owner", ttl = 600, dataUrl = CONFIG.DevUrl}, nil, true
            end
            if not httpRequest then return nil, "no http", false end
            local ok, result = pcall(httpRequest, {
                Url = CONFIG.DevUrl .. "/" .. kind,
                Method = "POST",
                Headers = {["content-type"] = "application/json", ["x-violite-dev"] = CONFIG.DevSecret},
                Body = HttpService:JSONEncode({token = token, hwid = hwid, user = user, v = version, nonce = nonce}),
            })
            if not ok then return nil, "request failed", false end
            response = result
        end
        --#end
        local data, err = openResponse(response, nonce)
        return data, err, data ~= nil
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 5: СЕССИЯ И ПРОДЛЕНИЕ
    -- ══════════════════════════════════════════════════════════════════════════
    local function adopt(data)
        if type(data) ~= "table" or data.ok ~= true then return false end
        local ttl = tonumber(data.ttl) or 180
        Kernel.Session = {
            Token = tostring(data.token or ""),
            Role = (data.role == "owner") and "owner" or "user",
            ExpiresAt = os.clock() + ttl,
            DataUrl = type(data.dataUrl) == "string" and data.dataUrl or nil,
            Message = type(data.message) == "string" and data.message or nil,
        }
        State.Failures = 0
        return true
    end

    -- Регулярное продление; сервер в ответе может приказать выгрузку или потребовать
    -- версию новее. Пропущенные ответы копятся — три подряд и выгружаемся.
    local function outdated(data)
        local minimum = tonumber(data.minVersion)
        return minimum ~= nil and CONFIG.Version < minimum
    end

    -- Подписанный ответ сервера: отказ, рубильник или устаревшая версия → выгрузка с
    -- причиной от сервера. true — сессия продолжается
    local function judge(data)
        if data.kill == true or data.ok ~= true then
            Kernel.Kill(type(data.message) == "string" and data.message or "Access denied", data.kick == true)
            return false
        end
        if outdated(data) then
            Kernel.Kill("Update required", true)
            return false
        end
        return adopt(data)
    end

    local function beatLoop()
        while State.Alive do
            task.wait(CONFIG.BeatInterval + math.random() * CONFIG.BeatJitter)
            if not State.Alive then return end
            local session = Kernel.Session
            local data, _, verified = callServer("beat", session and session.Token)
            if verified then
                if not judge(data) then return end
            else
                -- Сбой сети — не отказ: терпим несколько раз подряд
                State.Failures += 1
                if State.Failures >= CONFIG.MaxBeatFailures then
                    Kernel.Kill("Lost connection to server"); return
                end
            end
        end
    end

    -- Старт: открываем сессию. Нет сессии — модули не грузим вовсе. Кик — только по
    -- подписанному решению сервера; сбой сети на старте просто не запускает скрипт
    function Kernel.Start()
        local data, err, verified = callServer("session", nil)
        if not verified then
            Kernel.Kill("Server unavailable" .. (err and (": " .. err) or ""))
            return false
        end
        if not judge(data) then return false end
        State.BeatThread = task.spawn(beatLoop)
        return true
    end

    return Kernel
end
