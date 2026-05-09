-- RecvResearch.lua
-- Shift+F3 -> смотри In Data KB/s пока идёт MONITOR-фаза.
-- Лог сохраняется после КАЖДОГО шага, не ждёт конца скрипта.

local RS  = game:GetService("ReplicatedStorage")

local BURST_SIZE    = 50   -- задач за один burst-тест
local MONITOR_SECS  = 10   -- сколько секунд длится фаза мониторинга
local SPAWN_RATE    = 50   -- макс задач в секунду в MONITOR (защита от OOM)
local LOG_FILE      = "recv_research_log.txt"

-- ─────────────────────────────────────────────────────────────
-- ЛОГ: пишем в буфер + сразу сохраняем файл после каждого шага
-- ─────────────────────────────────────────────────────────────

local logLines  = {}
local startTime = tick()
local wf        = _G["writefile"]

local function flush()
    if wf then
        pcall(wf, LOG_FILE, table.concat(logLines, "\n") .. "\n")
    end
end

local function entry(section, msg)
    local line = string.format("[%.2fs][%s] %s", tick() - startTime, section, msg)
    table.insert(logLines, line)
    print(line)
end

local function checkpoint(label)
    entry("SAVE", "checkpoint: " .. label)
    flush()
end

-- ─────────────────────────────────────────────────────────────
-- УТИЛИТЫ
-- ─────────────────────────────────────────────────────────────

local function tryEncode(v)
    if v == nil then return "(nil)", 0 end
    local s = tostring(v)
    if type(v) == "table" then
        local ok, json = pcall(function()
            return game:GetService("HttpService"):JSONEncode(v)
        end)
        if ok then s = json end
    end
    return s, #s
end

local function scanRFs(parent, list, path)
    list = list or {}
    path = path or "RS"
    for _, child in ipairs(parent:GetChildren()) do
        local p = path .. "/" .. child.Name
        if child:IsA("RemoteFunction") then
            table.insert(list, { rf = child, path = p })
        end
        pcall(scanRFs, child, list, p)
    end
    return list
end

-- ─────────────────────────────────────────────────────────────
-- ШАГ 1 — сканирование
-- ─────────────────────────────────────────────────────────────

entry("SCAN", "Сканируем ReplicatedStorage...")
local allRFs = scanRFs(RS)
entry("SCAN", "Найдено RemoteFunction: " .. #allRFs)
for _, e in ipairs(allRFs) do
    entry("SCAN", "  " .. e.path)
end

if #allRFs == 0 then
    entry("SCAN", "Нет RemoteFunction — завершаем.")
    flush()
    return
end

checkpoint("after SCAN")
task.wait(0.5)

-- ─────────────────────────────────────────────────────────────
-- ШАГ 2 — одиночный вызов каждого RF
-- ─────────────────────────────────────────────────────────────

entry("SINGLE", string.format("%-40s  %-7s  %-10s  %s", "path", "ok", "rtt", "resp_bytes"))
entry("SINGLE", string.rep("-", 75))

local singleDone = 0
for _, e in ipairs(allRFs) do
    task.spawn(function()
        local t0 = tick()
        local ok, result = pcall(function() return e.rf:InvokeServer() end)
        local rtt = tick() - t0
        local _, sz = tryEncode(result)
        entry("SINGLE", string.format(
            "%-40s  %-7s  rtt=%.3fs  resp_bytes=%d",
            e.path, tostring(ok), rtt, sz
        ))
        singleDone += 1
    end)
end

local waited = 0
repeat task.wait(0.2); waited += 0.2 until singleDone >= #allRFs or waited >= 8

checkpoint("after SINGLE")

-- ─────────────────────────────────────────────────────────────
-- ШАГ 3 — burst-тест
-- pending_0.1s > 0  →  задача ждёт ответа сервера  →  recv накапливается
-- pending_0.1s = 0  →  сервер отвечает мгновенно   →  recv не растёт
-- ─────────────────────────────────────────────────────────────

entry("BURST", string.format("Burst-тест: %d задач на каждый RF", BURST_SIZE))
entry("BURST", string.format("%-40s  %-14s  %-10s  %s", "path", "pending_0.1s", "done", "errors"))
entry("BURST", string.rep("-", 82))

local burstResults = {}

for _, e in ipairs(allRFs) do
    local pending = 0
    local done    = 0
    local errors  = 0

    for _ = 1, BURST_SIZE do
        task.spawn(function()
            pending += 1
            local ok = pcall(function() e.rf:InvokeServer() end)
            pending -= 1
            done    += 1
            if not ok then errors += 1 end
        end)
    end

    task.wait(0.1)
    local snap = pending

    task.wait(5)
    entry("BURST", string.format(
        "%-40s  pending=%-3d           done=%d/%d  errors=%d",
        e.path, snap, done, BURST_SIZE, errors
    ))
    table.insert(burstResults, { path = e.path, rf = e.rf, snap = snap, errors = errors })

    -- сохраняем после каждого RF чтобы не потерять при таймауте
    flush()
end

table.sort(burstResults, function(a, b) return a.snap > b.snap end)

entry("BURST", "")
entry("BURST", "=== Рейтинг по pending_0.1s (больше = лучше для recv) ===")
for i, r in ipairs(burstResults) do
    entry("BURST", string.format("#%d  %-40s  pending=%d  errors=%d", i, r.path, r.snap, r.errors))
end

checkpoint("after BURST")

-- ─────────────────────────────────────────────────────────────
-- ШАГ 4 — мониторинг лучшего кандидата
-- SPAWN_RATE ограничивает кол-во новых задач в секунду → нет OOM
-- ─────────────────────────────────────────────────────────────

local best   = burstResults[1]
local target = (best and best.errors < BURST_SIZE) and best.rf
    or RS:FindFirstChild("GetData2", true)
    or RS:FindFirstChild("GetSyncData")
    or (allRFs[1] and allRFs[1].rf)

if not target then
    entry("MONITOR", "Нет кандидата — завершаем.")
    flush()
    return
end

entry("MONITOR", "Лучший кандидат: " .. target.Name)
entry("MONITOR", string.format(
    "Стресс %ds, лимит %d задач/с — смотри Shift+F3 -> In Data KB/s",
    MONITOR_SECS, SPAWN_RATE
))

local totalSpawned = 0
local totalPending = 0
local monitorDone  = false

-- спавним по SPAWN_RATE задач в секунду (task.wait(1/SPAWN_RATE) между спавнами)
task.spawn(function()
    local interval = 1 / SPAWN_RATE
    while not monitorDone do
        task.spawn(function()
            totalPending += 1
            totalSpawned += 1
            pcall(function() target:InvokeServer() end)
            totalPending -= 1
        end)
        task.wait(interval)
    end
end)

entry("MONITOR", string.format("%-6s  %-14s  %s", "t(s)", "spawned_total", "pending_now"))
entry("MONITOR", string.rep("-", 40))

for i = 1, MONITOR_SECS do
    task.wait(1)
    entry("MONITOR", string.format("%-6d  %-14d  %d", i, totalSpawned, totalPending))
    flush()
end

monitorDone = true
task.wait(0.5)

-- ─────────────────────────────────────────────────────────────
-- ИТОГ
-- ─────────────────────────────────────────────────────────────

entry("RESULT", "")
entry("RESULT", "=== ИТОГ ===")
entry("RESULT", string.format(
    "Лучший RF: %s  (pending_0.1s=%d)",
    best and best.path or "?", best and best.snap or 0
))
entry("RESULT", string.format(
    "За %ds: spawned=%d  last_pending=%d",
    MONITOR_SECS, totalSpawned, totalPending
))

if best and best.snap == 0 then
    entry("RESULT", "ВЫВОД: все RF мгновенны -> recv не растёт через InvokeServer")
else
    entry("RESULT", "ВЫВОД: использовать " .. (best and best.path or "?") .. " в ServerLagger")
end

flush()
print("\n========== FULL LOG ==========")
print(table.concat(logLines, "\n"))
print("==============================")
if wf then
    print("[LOG] Файл: workspace\\" .. LOG_FILE)
    print("[LOG] Xeno: %localappdata%\\Xeno\\workspace\\" .. LOG_FILE)
else
    print("[LOG] writefile недоступен — скопируй лог выше")
end
