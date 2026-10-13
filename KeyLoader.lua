-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 1: ЛОАДЕР UI SOURCE — ЖИЗНЕННЫЙ ЦИКЛ И ИЗОЛЯЦИЯ
-- ══════════════════════════════════════════════════════════════════════════════

return function(createStyle, createPrompt, options)
    if not game:IsLoaded() then game.Loaded:Wait() end
    local ok, shared = pcall(function() return getgenv() end)
    if not ok or type(shared) ~= "table" then
        warn("Violite: executor не предоставляет getgenv.")
        return nil
    end
    if shared.VioliteKeyLoader then
        warn("Violite: окно ввода ключа уже открыто.")
        return nil
    end

    local Services = {
        Players = game:GetService("Players"), CoreGui = game:GetService("CoreGui"),
        RunService = game:GetService("RunService"), Workspace = game:GetService("Workspace"),
        UserInputService = game:GetService("UserInputService"), Lighting = game:GetService("Lighting"),
        LocalizationService = game:GetService("LocalizationService"), TweenService = game:GetService("TweenService"),
    }
    local CONFIG = {
        Preview = options.Preview == true,
        KeyUrl = options.KeyUrl or "",
        GuiName = "Violite_KeyLoader", DisplayOrder = 1000,
        Width = 640, Height = 460, MaxKeyLength = 512, CopyNoticeSeconds = 5,
        Motion = {Hover = 0.14, Pulse = 0.32, PressDelay = 0.12, Toggle = 0.16},
        ValidPlaces = {[142823291] = true, [335132309] = true},
        Folders = {"VioCFG", "VioCFG/Violite"}, KeyPath = "VioCFG/Violite/loader-key.txt",
        -- Исходный акцент темы Violite совпадает с CONFIG.Colors.Accent MainScript.
        -- Остальную палитру и сохранённую тему возвращает сама GUI-библиотека.
        Colors = {Accent = Color3.fromRGB(220, 145, 230)},
    }
    local State = {
        Done = false, Busy = false, Remember = false, InitialKey = "",
        Connections = {}, UIElements = {}, SubmittedCount = 0, Tweens = {}, LanguageMode = "Auto",
        CanPersist = type(isfile) == "function"
            and type(readfile) == "function" and type(writefile) == "function"
            and type(makefolder) == "function" and type(isfolder) == "function",
    }
    -- Game Language Roblox; системная локаль на выбор языка не влияет.
    local english = {
        ["Доступ к скрипту"] = "Script access",
        ["Нажми на кнопку, чтобы получить ключ."] = "Click the button to get a key.",
        ["Вставь ссылку в браузер."] = "Paste the link into your browser.",
        ["Получить ключ"] = "Get key",
        ["Ссылка скопирована"] = "Link copied",
        ["Авторизация"] = "Authentication",
        ["Добро пожаловать в Violite"] = "Welcome to Violite",
        ["Введите ключ доступа, чтобы продолжить."] = "Enter your access key to continue.",
        ["Ключ доступа"] = "Access key",
        ["Вставьте ваш ключ"] = "Paste your key",
        ["Запомнить ключ на устройстве"] = "Remember key on this device",
        ["Запустить Violite"] = "Launch Violite",
        ["Предпросмотр"] = "Preview",
        ["Авторизация через Jnkie"] = "Authentication via Jnkie",
        ["Этот executor не поддерживает сохранение ключа."] = "This executor cannot save keys.",
        ["Вставьте ключ доступа."] = "Enter your access key.",
        ["Проверьте ключ: в нём не должно быть пробелов и переносов строк."] = "Check your key: spaces and line breaks are not allowed.",
        ["Ввод принят в предпросмотре. Проверка ключа и запуск не выполнялись."] = "Preview input accepted. No authentication or launch performed.",
        ["Не удалось сохранить ключ. Снимите галочку и повторите запуск."] = "Could not save the key. Uncheck Remember and try again.",
        ["Не удалось удалить сохранённый ключ. Проверьте доступ к файлам executor'а."] = "Could not clear the saved key. Check executor file access.",
        ["Не удалось скопировать ссылку. Буфер обмена недоступен."] = "Could not copy the link. Clipboard is unavailable.",
    }
    local function translate(text)
        local locale = "en-us"
        pcall(function() locale = Services.LocalizationService.RobloxLocaleId end)
        State.Language = State.LanguageMode == "Ru" and "ru"
            or State.LanguageMode == "En" and "en"
            or (string.lower(locale):sub(1, 2) == "ru" and "ru" or "en")
        return State.Language == "ru" and text or (english[text] or text)
    end
    local UI, submittedKey
    shared.VioliteKeyLoader = State

    local function cleanup()
        State.Done = true
        State.DragInput = nil
        if State.SubmitThread then pcall(task.cancel, State.SubmitThread); State.SubmitThread = nil end
        for _, tween in pairs(State.Tweens) do pcall(function() tween:Cancel() end) end
        table.clear(State.Tweens)
        if State.CopyResetThread then pcall(task.cancel, State.CopyResetThread); State.CopyResetThread = nil end
        for _, connection in ipairs(State.Connections) do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(State.Connections)
        if State.Acrylic then pcall(State.Acrylic.Destroy); State.Acrylic = nil end
        if State.Blur then pcall(function() State.Blur:Destroy() end); State.Blur = nil end
        if State.Screen then
            pcall(function() State.Screen:Destroy() end)
            State.Screen = nil
        end
        State.KeyBox, State.Panel, State.StatusLabel, State.InitialKey = nil, nil, nil, nil
        if shared.VioliteKeyLoader == State then shared.VioliteKeyLoader = nil end
    end

    local function cancel()
        if State.Done then return end
        submittedKey = nil
        if not CONFIG.Preview then
            shared.SCRIPT_KEY = nil
            shared.UI_CLOSED = true
        end
        cleanup()
    end
    State.Close = cancel

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 2: ЛОКАЛЬНОЕ ХРАНИЛИЩЕ ТОЛЬКО ПО ВЫБОРУ ПОЛЬЗОВАТЕЛЯ
    -- ══════════════════════════════════════════════════════════════════════════

    local function trimKey(value)
        return tostring(value or ""):match("^%s*(.-)%s*$")
    end

    local function readSavedKey()
        if CONFIG.Preview or not State.CanPersist then return end
        local loaded, value = pcall(function()
            if not isfile(CONFIG.KeyPath) then return nil end
            return readfile(CONFIG.KeyPath)
        end)
        if loaded and type(value) == "string" then
            value = trimKey(value)
            if #value > 0 and #value <= CONFIG.MaxKeyLength and not value:find("%s") and not value:find("%c") then
                State.InitialKey, State.Remember = value, true
            end
        end
    end

    local function saveSubmittedKey(key)
        if not State.CanPersist then return true end
        return pcall(function()
            if not State.Remember then
                -- Пустой файл убирает прошлый ключ без зависимости от delfile.
                if isfile(CONFIG.KeyPath) then writefile(CONFIG.KeyPath, "") end
                return
            end
            for _, path in ipairs(CONFIG.Folders) do
                if not isfolder(path) then makefolder(path) end
            end
            if not isfile(CONFIG.KeyPath) then
                writefile(CONFIG.KeyPath, key)
            elseif readfile(CONFIG.KeyPath) ~= key then
                writefile(CONFIG.KeyPath, key)
            end
        end)
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 3: ПЕРЕДАЧА КЛЮЧА, БЕЗ ПОДМЕНЫ ПРОВЕРКИ JNKIE
    -- ══════════════════════════════════════════════════════════════════════════

    local function submit(value)
        if State.Done or State.Busy then return end
        local key = trimKey(value)
        if key == "" then UI.SetStatus("Вставьте ключ доступа.", true); return end
        if #key > CONFIG.MaxKeyLength or key:find("%s") or key:find("%c") then
            UI.SetStatus("Проверьте ключ: в нём не должно быть пробелов и переносов строк.", true)
            return
        end
        if CONFIG.Preview then
            State.SubmittedCount += 1
            UI.ClearKey()
            UI.SetStatus("Ввод принят в предпросмотре. Проверка ключа и запуск не выполнялись.")
            return
        end
        State.Busy = true
        if not saveSubmittedKey(key) then
            State.Busy = false
            UI.SetStatus(State.Remember
                and "Не удалось сохранить ключ. Снимите галочку и повторите запуск."
                or "Не удалось удалить сохранённый ключ. Проверьте доступ к файлам executor'а.", true)
            return
        end
        -- Только Jnkie решает, валиден ли ключ. Повторный check_key здесь может
        -- израсходовать одноразовый ключ ещё до защищённой авторизации.
        submittedKey = key
        shared.SCRIPT_KEY, shared.UI_CLOSED = key, false
        cleanup()
    end

    local function getKeyLink()
        if State.Done or CONFIG.KeyUrl == "" then return end
        local copied = false
        if type(setclipboard) == "function" then
            copied = pcall(setclipboard, CONFIG.KeyUrl)
        end
        if copied then UI.ShowLinkCopied()
        else UI.SetStatus("Не удалось скопировать ссылку. Буфер обмена недоступен.", true) end
    end

    local function run()
        if Services.RunService:IsStudio() or not CONFIG.ValidPlaces[game.PlaceId] or not Services.Players.LocalPlayer then
            warn("Violite: лоадер доступен только в поддерживаемой игре Murder Mystery 2.")
            cancel()
            return nil
        end
        if not CONFIG.Preview then
            -- Сохранённый или старый глобальный ключ не должен запускать код без
            -- явного нажатия пользователем кнопки в текущем окне.
            shared.SCRIPT_KEY, shared.UI_CLOSED = nil, false
        end
        readSavedKey()
        local style = createStyle({LoaderOnly = true, CONFIG = CONFIG, State = State})
        local T = style.Theme.T
        CONFIG.Colors = {
            Canvas = T.Canvas, Surface = T.Surface1, Input = T.Canvas, Border = T.Border,
            Text = T.Text, Muted = T.TextDark, Accent = T.Accent,
            AccentInk = style.ButtonInk, Danger = T.Danger,
        }
        State.ThemeName = style.Name
        UI = createPrompt({CONFIG = CONFIG, State = State, Style = style, Services = Services, Text = translate,
            OnClose = cancel, OnSubmit = submit, OnGetKey = getKeyLink})
        local parent = Services.CoreGui
        if type(gethui) == "function" then
            local found, container = pcall(gethui)
            if found and typeof(container) == "Instance" then parent = container end
        end
        local built = pcall(UI.Build, parent)
        if not built and parent ~= Services.CoreGui then
            -- Сначала удаляем частичное окно, но не завершаем ожидание ключа.
            for _, connection in ipairs(State.Connections) do pcall(function() connection:Disconnect() end) end
            table.clear(State.Connections)
            if State.Screen then pcall(function() State.Screen:Destroy() end) end
            State.Screen = nil
            UI.Build(Services.CoreGui)
        elseif not built then
            error("Не удалось построить окно лоадера")
        end
        State.InitialKey = nil
        -- В UI Source необходимо дождаться результата на верхнем уровне.
        -- Фоновый task.spawn позволил бы Jnkie начать авторизацию раньше ввода.
        while not State.Done do task.wait(0.1) end
        return submittedKey
    end

    local success, result = pcall(run)
    if not success then
        -- Ошибку не печатаем целиком: ответ executor'а может содержать ввод.
        warn("Violite: ошибка создания лоадера. Основной скрипт не запущен.")
        cancel()
        return nil
    end
    cleanup()
    return result
end
