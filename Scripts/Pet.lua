--[[
    ════════════════════════════════════════════════════════════════
    MM2 PET NAME ANIMATOR - NO NUMBERS VERSION
    ════════════════════════════════════════════════════════════════
]]

-- ✅ НАСТРОЙКИ
local PHRASES = {
    "Best scrpt",
    "Top dev",      -- ✅ ИЗМЕНЕНО: "#1dev" → "Topdev"
    "for mm2"
}

local MIN_INTERVAL = 2
local MAX_INTERVAL = 2.5

-- ══════════════════════════════════════════════════════════════

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("🎬 MM2 Pet Name - No Numbers Mode")

local RenamePetRemote = ReplicatedStorage:FindFirstChild("Remotes")
if RenamePetRemote then
    RenamePetRemote = RenamePetRemote:FindFirstChild("Inventory")
    if RenamePetRemote then
        RenamePetRemote = RenamePetRemote:FindFirstChild("RenamePet")
    end
end

if not RenamePetRemote then
    warn("❌ RenamePet not found!")
    return
end

-- ✅ ЭМОДЗИ
local emojis = {
    "⭐", "🔥", "💎", "⚡", "✨", "💫", "🌟", "👑", "🏆",    "💥", "💯"
}

-- ✅ КИРИЛЛИЦА
local function ReplaceWithCyrillic(text)
    local cyrillic = {
        ["a"] = "а", ["A"] = "А",
        ["e"] = "е", ["E"] = "Е",
        ["o"] = "о", ["O"] = "О",
        ["p"] = "р", ["P"] = "Р",
        ["c"] = "с", ["C"] = "С",
        ["t"] = "т", ["T"] = "Т",
        ["m"] = "м", ["M"] = "М",
        ["d"] = "д", ["D"] = "Д",
    }
    
    local result = text
    
    for eng, rus in pairs(cyrillic) do
        result = result:gsub(eng, function()
            if math.random(1, 2) == 1 then
                return rus
            else
                return eng
            end
        end)
    end
    
    return result
end

-- ✅ СЛУЧАЙНЫЙ РЕГИСТР
local function RandomCase(text)
    local result = ""
    
    for i = 1, #text do
        local char = text:sub(i, i)
        
        if char:match("%a") then
            if math.random(1, 2) == 1 then
                result = result .. char:upper()
            else
                result = result .. char:lower()
            end
        else
            result = result .. char
        end
    end
    
    return result
end

-- ✅ ТРАНСФОРМАЦИЯ
local function TransformPhrase(phrase)
    local transformed = RandomCase(phrase)
    transformed = ReplaceWithCyrillic(transformed)
    
    local emoji1 = emojis[math.random(1, #emojis)]
    local emoji2 = emojis[math.random(1, #emojis)]
    
    return emoji1 .. transformed .. emoji2
end

-- ✅ ОТПРАВКА
local function SetName(phrase)
    local transformed = TransformPhrase(phrase)
    
    print(string.format("📝 %s", transformed))
    
    pcall(function()
        RenamePetRemote:FireServer(transformed)
    end)
end

-- ✅ ОСНОВНОЙ ЦИКЛ
print(string.format("✅ Started | %d phrases | %d-%ds interval\n", #PHRASES, MIN_INTERVAL, MAX_INTERVAL))

local currentIndex = 1
local cycleCount = 0

task.spawn(function()
    while true do
        SetName(PHRASES[currentIndex])
        
        cycleCount = cycleCount + 1
        
        currentIndex = currentIndex + 1
        if currentIndex > #PHRASES then
            currentIndex = 1
        end
        
        local randomDelay = math.random(MIN_INTERVAL * 10, MAX_INTERVAL * 10) / 10
        
        if cycleCount % 3 == 0 then
            print(string.format("⏰ Cycle %d | Next: %.1fs", cycleCount, randomDelay))
        end
        
        task.wait(randomDelay)
    end
end)
